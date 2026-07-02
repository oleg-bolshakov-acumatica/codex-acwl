[CmdletBinding()]
param(
    [switch]$SkipSmokeTest
)

# Validates the Codex project MCP declaration and smoke-tests the local SQL
# facade. This does not mutate Codex user config; registration is handled by
# scripts/Ensure-CodexMcp.ps1 and scripts/Start-Codex.ps1.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$specPath = Join-Path $projectRoot ".codex-mcp.json"

if (-not (Test-Path -LiteralPath $specPath)) {
    Write-Error "Missing Codex MCP declaration: .codex-mcp.json was not found at the workspace root."
    exit 1
}

function Resolve-WorkspacePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $Path))
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

function Invoke-StdioSmokeTest {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory
    )

    $request = @(
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"codex-acwl-check","version":"0"}}}',
        '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}',
        '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
    ) -join [Environment]::NewLine

    Push-Location $WorkingDirectory
    try {
        $output = $request | & $Command @Arguments
    }
    finally {
        Pop-Location
    }

    foreach ($line in $output) {
        if ($line -notmatch '^\s*\{') {
            continue
        }
        $message = $line | ConvertFrom-Json
        if ($message.id -eq 2 -and $null -ne $message.result -and $null -ne $message.result.tools) {
            return @(@($message.result.tools) | ForEach-Object { [string]$_.name })
        }
    }

    throw "tools/list did not return a tool catalog."
}

$dbProxyConfigPath = Join-Path $projectRoot "db-proxy/config/db-proxy.config.json"
if (Test-Path -LiteralPath $dbProxyConfigPath) {
    $dbProxyConfig = Get-Content -LiteralPath $dbProxyConfigPath -Raw | ConvertFrom-Json
    $dbProxyBaseUrl = if ($null -ne $dbProxyConfig.http -and -not [string]::IsNullOrWhiteSpace([string]$dbProxyConfig.http.baseUrl)) {
        ([string]$dbProxyConfig.http.baseUrl).TrimEnd("/")
    } else {
        "http://127.0.0.1:8765"
    }

    try {
        $dbStatus = Invoke-RestMethod -Uri ("{0}/status" -f $dbProxyBaseUrl) -Method Get -TimeoutSec 3 -ErrorAction Stop
        Write-Host ("[db   ] {0,-22} -> /status OK (backendVersion={1})" -f "db-proxy", $dbStatus.result.backendVersion)
    }
    catch {
        Write-Host ("[db   ] {0,-22} -> /status not reachable on {1} (start db-proxy/Start.ps1 or use scripts/Start-Codex.ps1 -ProxyOnly)" -f "db-proxy", $dbProxyBaseUrl)
    }
}

$spec = Get-Content -LiteralPath $specPath -Raw | ConvertFrom-Json
if ($null -eq $spec.plugins -or @($spec.plugins).Count -eq 0) {
    Write-Error ".codex-mcp.json does not declare any plugins."
    exit 1
}

$tokens = @{
    '${PROJECT_DIR}' = $projectRoot
    '${PROJECT_ROOT}' = $projectRoot
    '${PROJECT_FOLDER_NAME}' = Split-Path -Leaf $projectRoot
}

$expectedFacadeTools = @("sql.select", "server.describe_capabilities")
$failures = 0

foreach ($plugin in @($spec.plugins)) {
    $pluginName = [string]$plugin.name
    $templatePath = Resolve-WorkspacePath -BasePath $projectRoot -Path ([string]$plugin.mcpTemplate)
    if (-not (Test-Path -LiteralPath $templatePath)) {
        Write-Host ("[mcp  ] {0,-22} -> FAILED: missing template {1}" -f $pluginName, $templatePath)
        $failures++
        continue
    }

    $template = Get-Content -LiteralPath $templatePath -Raw | ConvertFrom-Json
    $config = Replace-Tokens -Value $template -Tokens $tokens
    if ($null -eq $config.mcpServers) {
        Write-Host ("[mcp  ] {0,-22} -> FAILED: template does not declare mcpServers." -f $pluginName)
        $failures++
        continue
    }

    $actualServers = @($config.mcpServers.PSObject.Properties | ForEach-Object { [string]$_.Name } | Sort-Object -Unique)
    $expectedServers = @($plugin.expectedServers | ForEach-Object { [string]$_ } | Sort-Object -Unique)
    $diff = @(Compare-Object -ReferenceObject $expectedServers -DifferenceObject $actualServers)
    if ($diff.Count -ne 0) {
        Write-Host ("[mcp  ] {0,-22} -> FAILED: expected servers [{1}], got [{2}]." -f $pluginName, ($expectedServers -join ", "), ($actualServers -join ", "))
        $failures++
    }
    else {
        Write-Host ("[mcp  ] {0,-22} -> OK, servers: {1}." -f $pluginName, ($actualServers -join ", "))
    }

    foreach ($property in $config.mcpServers.PSObject.Properties) {
        $name = $property.Name
        $server = $property.Value
        $type = if ($server.PSObject.Properties.Name -contains "type") { [string]$server.type } else { "stdio" }

        if ($type -eq "http") {
            Write-Host ("[http ] {0,-22} -> {1}" -f $name, $server.url)
            continue
        }

        if ($name -ne "powershell-mcp-facade") {
            Write-Host ("[stdio] {0,-22} -> {1} (smoke test skipped)" -f $name, $server.command)
            continue
        }

        if ($SkipSmokeTest) {
            Write-Host ("[stdio] {0,-22} -> {1} (smoke test skipped)" -f $name, $server.command)
            continue
        }

        $arguments = @()
        foreach ($arg in $server.args) { $arguments += [string]$arg }
        $cwd = if ($server.PSObject.Properties.Name -contains "cwd" -and -not [string]::IsNullOrWhiteSpace([string]$server.cwd)) {
            [string]$server.cwd
        } else {
            $projectRoot
        }

        try {
            $toolNames = @(Invoke-StdioSmokeTest -Command ([string]$server.command) -Arguments $arguments -WorkingDirectory $cwd)
            $missing = @($expectedFacadeTools | Where-Object { $_ -notin $toolNames })
            $unexpected = @($toolNames | Where-Object { $_ -notin $expectedFacadeTools })

            if ($missing.Count -gt 0 -or $unexpected.Count -gt 0) {
                $failures++
                Write-Host ("[stdio] {0,-22} -> FAILED: expected tools [{1}], got [{2}]." -f $name, ($expectedFacadeTools -join ", "), ($toolNames -join ", "))
                if ($missing.Count -gt 0) {
                    Write-Host ("         Missing: {0}" -f ($missing -join ", "))
                }
                if ($unexpected.Count -gt 0) {
                    Write-Host ("         Unexpected: {0}" -f ($unexpected -join ", "))
                }
            }
            else {
                Write-Host ("[stdio] {0,-22} -> OK, tools/list returned {1} tool(s): {2}." -f $name, $toolNames.Count, ($toolNames -join ", "))
            }
        }
        catch {
            $failures++
            Write-Host ("[stdio] {0,-22} -> FAILED: {1}" -f $name, $_.Exception.Message)
        }
    }
}

if ($failures -gt 0) {
    Write-Host ""
    Write-Host "$failures MCP check(s) failed."
    exit 1
}

Write-Host ""
Write-Host "Codex MCP configuration looks healthy. Run scripts/Start-Codex.ps1 and check /mcp after Codex starts."
exit 0
