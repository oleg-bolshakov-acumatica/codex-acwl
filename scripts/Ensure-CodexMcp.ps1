[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$CodexHome,
    [switch]$Apply,
    [switch]$Yes,
    [switch]$SkipSmokeTest,
    [switch]$KeepOtherProjectMarketplaces
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-AbsolutePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $Path))
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function ConvertTo-PrettyJson {
    param([Parameter(Mandatory = $true)]$Value)
    return ($Value | ConvertTo-Json -Depth 50) + [Environment]::NewLine
}

function Replace-Tokens {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][hashtable]$Tokens
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [string]) {
        $result = $Value
        foreach ($key in $Tokens.Keys) {
            $result = $result.Replace($key, [string]$Tokens[$key])
        }
        return $result
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string]) -and -not ($Value -is [pscustomobject])) {
        $items = @()
        foreach ($item in $Value) {
            $items += Replace-Tokens -Value $item -Tokens $Tokens
        }
        return $items
    }

    if ($Value -is [pscustomobject]) {
        $hash = [ordered]@{}
        foreach ($property in $Value.PSObject.Properties) {
            $hash[$property.Name] = Replace-Tokens -Value $property.Value -Tokens $Tokens
        }
        return [pscustomobject]$hash
    }

    return $Value
}

function Write-TextIfChanged {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text
    )

    $existing = $null
    if (Test-Path -LiteralPath $Path) {
        $existing = Get-Content -LiteralPath $Path -Raw
    }

    if ($existing -eq $Text) {
        return $false
    }

    $parent = Split-Path -Parent $Path
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Set-Content -LiteralPath $Path -Value $Text -NoNewline
    return $true
}

function Escape-Regex {
    param([Parameter(Mandatory = $true)][string]$Value)
    return [regex]::Escape($Value)
}

function Upsert-TomlSection {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory = $true)][string]$Header,
        [Parameter(Mandatory = $true)][string]$Body
    )

    $section = $Header + [Environment]::NewLine + $Body.TrimEnd() + [Environment]::NewLine
    $pattern = "(?ms)^" + (Escape-Regex $Header) + "\r?\n.*?(?=^\[|\z)"

    if ([regex]::IsMatch($Text, $pattern)) {
        return [regex]::Replace($Text, $pattern, $section, 1)
    }

    $prefix = $Text.TrimEnd()
    if ($prefix.Length -eq 0) {
        return $section
    }

    return $prefix + [Environment]::NewLine + [Environment]::NewLine + $section
}

function Get-TomlPathLiteral {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not $fullPath.StartsWith("\\?\")) {
        $fullPath = "\\?\" + $fullPath
    }
    return "'" + $fullPath.Replace("'", "''") + "'"
}

function Normalize-PathForCompare {
    param([Parameter(Mandatory = $true)][string]$Path)

    $value = $Path.Trim().Trim("'").Trim('"')
    if ($value.StartsWith("\\?\")) {
        $value = $value.Substring(4)
    }
    return [System.IO.Path]::GetFullPath($value).TrimEnd('\')
}

function Get-McpServerNames {
    param([Parameter(Mandatory = $true)]$McpConfig)

    if ($null -eq $McpConfig.mcpServers) {
        return @()
    }

    return @($McpConfig.mcpServers.PSObject.Properties | ForEach-Object { [string]$_.Name })
}

function Assert-ExpectedMcpServers {
    param(
        [Parameter(Mandatory = $true)][string]$PluginName,
        [Parameter(Mandatory = $true)]$PluginSpec,
        [Parameter(Mandatory = $true)]$McpConfig
    )

    if ($PluginSpec.PSObject.Properties.Name -notcontains "expectedServers") {
        return
    }

    $expected = @()
    foreach ($serverName in $PluginSpec.expectedServers) {
        $value = [string]$serverName
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $expected += $value
        }
    }

    $expected = @($expected | Sort-Object -Unique)
    $actual = @(Get-McpServerNames -McpConfig $McpConfig | Sort-Object -Unique)
    $diff = @(Compare-Object -ReferenceObject $expected -DifferenceObject $actual)

    if ($diff.Count -ne 0) {
        throw ("MCP server set for plugin '{0}' does not match .codex-mcp.json expectedServers. Expected: [{1}]. Actual: [{2}]." -f $PluginName, ($expected -join ", "), ($actual -join ", "))
    }
}

function Disable-StalePluginSections {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$TargetMarketplace,
        [Parameter(Mandatory = $true)][string[]]$PluginNames,
        [switch]$OnlyDisableSameProjectRoot
    )

    $normalizedRoot = $null
    if ($OnlyDisableSameProjectRoot) {
        $normalizedRoot = Normalize-PathForCompare $ProjectRoot
    }

    $marketplacePattern = "(?ms)^\[marketplaces\.([A-Za-z0-9_-]+)\]\r?\n(.*?)(?=^\[|\z)"
    $matches = [regex]::Matches($Text, $marketplacePattern)
    $result = $Text

    foreach ($match in $matches) {
        $name = $match.Groups[1].Value
        if ($name -eq $TargetMarketplace) {
            continue
        }

        $body = $match.Groups[2].Value
        if ($OnlyDisableSameProjectRoot) {
            $sourceMatch = [regex]::Match($body, "(?m)^\s*source\s*=\s*(.+?)\s*$")
            if (-not $sourceMatch.Success) {
                continue
            }

            $sourcePath = Normalize-PathForCompare $sourceMatch.Groups[1].Value
            if (-not [string]::Equals($sourcePath, $normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                continue
            }
        }

        foreach ($pluginName in $PluginNames) {
            $pluginHeader = '[plugins."' + $pluginName + '@' + $name + '"]'
            $result = Upsert-TomlSection -Text $result -Header $pluginHeader -Body "enabled = false"
        }
    }

    return $result
}

function Get-ExistingMarketplaceTimestamp {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory = $true)][string]$MarketplaceName
    )

    $header = "[marketplaces." + $MarketplaceName + "]"
    $pattern = "(?ms)^" + (Escape-Regex $header) + "\r?\n(.*?)(?=^\[|\z)"
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) {
        return $null
    }

    $timestamp = [regex]::Match($match.Groups[1].Value, 'last_updated\s*=\s*"([^"]+)"')
    if (-not $timestamp.Success) {
        return $null
    }

    return $timestamp.Groups[1].Value
}

function Invoke-McpSmokeTest {
    param(
        [Parameter(Mandatory = $true)]$McpConfig
    )

    $serverProperty = $McpConfig.mcpServers.PSObject.Properties | Select-Object -First 1
    if ($null -eq $serverProperty) {
        throw "No MCP servers are declared in generated MCP config."
    }

    $server = $serverProperty.Value
    $command = [string]$server.command
    $arguments = @()
    foreach ($arg in $server.args) {
        $arguments += [string]$arg
    }
    $cwd = [string]$server.cwd

    $request = @(
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"codex-mcp-bootstrap","version":"0"}}}',
        '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}',
        '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
    ) -join [Environment]::NewLine

    Push-Location $cwd
    try {
        $output = $request | & $command @arguments
    }
    finally {
        Pop-Location
    }

    foreach ($line in $output) {
        if ($line -notmatch '^\s*\{') {
            continue
        }

        $message = $line | ConvertFrom-Json
        if ($message.id -eq 2 -and $null -ne $message.result.tools) {
            return @($message.result.tools).Count
        }
    }

    throw "MCP smoke test did not return tools/list."
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}
else {
    $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
}

if ([string]::IsNullOrWhiteSpace($CodexHome)) {
    if ($env:CODEX_HOME) {
        $CodexHome = $env:CODEX_HOME
    }
    else {
        $CodexHome = Join-Path $HOME ".codex"
    }
}
$CodexHome = [System.IO.Path]::GetFullPath($CodexHome)

$specPath = Join-Path $ProjectRoot ".codex-mcp.json"
if (-not (Test-Path -LiteralPath $specPath)) {
    throw "Missing project MCP declaration: $specPath"
}

$spec = Read-JsonFile $specPath
$folderName = Split-Path -Leaf $ProjectRoot
$marketplaceName = $folderName
if ($spec.PSObject.Properties.Name -contains "marketplaceName") {
    $configuredMarketplace = [string]$spec.marketplaceName
    if (-not [string]::IsNullOrWhiteSpace($configuredMarketplace) -and $configuredMarketplace -ne '${PROJECT_FOLDER_NAME}') {
        $marketplaceName = $configuredMarketplace
    }
}

$tokens = @{
    '${PROJECT_DIR}' = $ProjectRoot
    '${PROJECT_ROOT}' = $ProjectRoot
    '${PROJECT_FOLDER_NAME}' = $folderName
}

$planned = New-Object System.Collections.Generic.List[string]
$pluginNames = @()
$generatedConfigs = @()

$marketplacePath = Join-Path $ProjectRoot ".agents\plugins\marketplace.json"
$marketplace = Read-JsonFile $marketplacePath
if ($marketplace.name -ne $marketplaceName) {
    $planned.Add("Update marketplace name in $marketplacePath to '$marketplaceName'.")
    $marketplace.name = $marketplaceName
}
$marketplaceJson = ConvertTo-PrettyJson $marketplace

foreach ($plugin in $spec.plugins) {
    $pluginName = [string]$plugin.name
    $pluginNames += $pluginName
    $pluginRoot = Resolve-AbsolutePath -BasePath $ProjectRoot -Path ([string]$plugin.source)
    $manifestPath = Join-Path $pluginRoot ".codex-plugin\plugin.json"
    $manifest = Read-JsonFile $manifestPath
    $version = [string]$manifest.version

    $templatePath = Resolve-AbsolutePath -BasePath $ProjectRoot -Path ([string]$plugin.mcpTemplate)
    $outputPath = Resolve-AbsolutePath -BasePath $ProjectRoot -Path ([string]$plugin.mcpOutput)
    $template = Read-JsonFile $templatePath
    $templateJson = ConvertTo-PrettyJson $template
    $generatedConfig = Replace-Tokens -Value $template -Tokens $tokens
    Assert-ExpectedMcpServers -PluginName $pluginName -PluginSpec $plugin -McpConfig $generatedConfig
    $generatedJson = ConvertTo-PrettyJson $generatedConfig

    $cachePath = Join-Path $CodexHome ("plugins\cache\" + $marketplaceName + "\" + $pluginName + "\" + $version)

    $currentOutput = $null
    if (Test-Path -LiteralPath $outputPath) {
        $currentOutput = Get-Content -LiteralPath $outputPath -Raw
    }
    if ($currentOutput -ne $templateJson) {
        $planned.Add("Sync portable $outputPath from $templatePath.")
    }

    $cacheManifestPath = Join-Path $cachePath ".codex-plugin\plugin.json"
    $cacheMcpPath = Join-Path $cachePath ".mcp.json"
    if (-not (Test-Path -LiteralPath $cacheManifestPath)) {
        $planned.Add("Install plugin cache at $cachePath.")
    }
    else {
        $sourceManifest = Get-Content -LiteralPath $manifestPath -Raw
        $cacheManifest = Get-Content -LiteralPath $cacheManifestPath -Raw
        $cacheMcp = $null
        if (Test-Path -LiteralPath $cacheMcpPath) {
            $cacheMcp = Get-Content -LiteralPath $cacheMcpPath -Raw
        }
        if ($sourceManifest -ne $cacheManifest -or $cacheMcp -ne $generatedJson) {
            $planned.Add("Refresh plugin cache at $cachePath.")
        }
    }

    $generatedConfigs += [pscustomobject]@{
        PluginName = $pluginName
        PluginRoot = $pluginRoot
        Version = $version
        OutputPath = $outputPath
        TemplateJson = $templateJson
        GeneratedJson = $generatedJson
        GeneratedConfig = $generatedConfig
        CachePath = $cachePath
    }
}

$configPath = Join-Path $CodexHome "config.toml"
$configText = ""
if (Test-Path -LiteralPath $configPath) {
    $configText = Get-Content -LiteralPath $configPath -Raw
}
$originalConfigText = $configText

$marketplaceHeader = "[marketplaces." + $marketplaceName + "]"
$timestamp = Get-ExistingMarketplaceTimestamp -Text $configText -MarketplaceName $marketplaceName
if ([string]::IsNullOrWhiteSpace($timestamp)) {
    $timestamp = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
}
$marketplaceBodyLines = @(
    ('last_updated = "' + $timestamp + '"')
    'source_type = "local"'
    ('source = ' + (Get-TomlPathLiteral $ProjectRoot))
)
$marketplaceBody = ($marketplaceBodyLines -join [Environment]::NewLine)
$configText = Upsert-TomlSection -Text $configText -Header $marketplaceHeader -Body $marketplaceBody

foreach ($pluginName in $pluginNames) {
    $pluginHeader = '[plugins."' + $pluginName + '@' + $marketplaceName + '"]'
    $configText = Upsert-TomlSection -Text $configText -Header $pluginHeader -Body "enabled = true"
}

$configText = Disable-StalePluginSections -Text $configText -ProjectRoot $ProjectRoot -TargetMarketplace $marketplaceName -PluginNames $pluginNames -OnlyDisableSameProjectRoot:$KeepOtherProjectMarketplaces
$configText = $configText.TrimEnd() + [Environment]::NewLine
$normalizedOriginalConfigText = $originalConfigText.TrimEnd() + [Environment]::NewLine
if ($normalizedOriginalConfigText -ne $configText) {
    $planned.Add("Update Codex user config at $configPath.")
}

if (-not $Apply) {
    Write-Host "Codex MCP preflight for marketplace '$marketplaceName'."
    if ($planned.Count -eq 0) {
        Write-Host "No changes are required."
    }
    else {
        Write-Host "No changes were written. Planned actions:"
        foreach ($item in $planned) {
            Write-Host " - $item"
        }
        Write-Host "Run with -Apply to register/update the project MCP facade."
    }
    exit 0
}

if (-not $Yes) {
    if ($planned.Count -eq 0) {
        Write-Host "No registration changes are required for marketplace '$marketplaceName'."
    }
    else {
        Write-Host "The script will update Codex MCP registration for marketplace '$marketplaceName':"
        foreach ($item in $planned) {
            Write-Host " - $item"
        }
        $answer = Read-Host "Apply these changes? [y/N]"
        if ($answer -notin @("y", "Y", "yes", "YES")) {
            Write-Host "Canceled."
            exit 1
        }
    }
}

Write-TextIfChanged -Path $marketplacePath -Text $marketplaceJson | Out-Null
Write-TextIfChanged -Path $configPath -Text $configText | Out-Null

foreach ($generated in $generatedConfigs) {
    Write-TextIfChanged -Path $generated.OutputPath -Text $generated.TemplateJson | Out-Null
    New-Item -ItemType Directory -Force -Path $generated.CachePath | Out-Null
    Get-ChildItem -LiteralPath $generated.PluginRoot -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $generated.CachePath -Recurse -Force
    }
    Write-TextIfChanged -Path (Join-Path $generated.CachePath ".mcp.json") -Text $generated.GeneratedJson | Out-Null
}

if (-not $SkipSmokeTest -and $generatedConfigs.Count -gt 0) {
    $toolCount = Invoke-McpSmokeTest -McpConfig $generatedConfigs[0].GeneratedConfig
    Write-Host "MCP smoke test OK: tools/list returned $toolCount tool(s)."
}

Write-Host "Codex MCP registration is ready for marketplace '$marketplaceName'."
Write-Host "Restart Codex and check /mcp."
