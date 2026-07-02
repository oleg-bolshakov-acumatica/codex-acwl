[CmdletBinding()]
param(
    [switch]$SkipSmokeTest
)

# Validates the Codex project MCP configuration and smoke-tests the local SQL
# facade. This script does not mutate Codex user config.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$configPath = Join-Path $projectRoot ".codex/config.toml"
$expectedServers = @("jira-internal", "powershell-mcp-facade", "wiki-internal")
$expectedFacadeTools = @("sql.select", "server.describe_capabilities")
$expectedDbProxyBackendVersion = "db-proxy-0.1.0"

if (-not (Test-Path -LiteralPath $configPath)) {
    Write-Error "Missing Codex project config: .codex/config.toml was not found at the workspace root."
    exit 1
}

function Get-TomlStringValue {
    param(
        [Parameter(Mandatory)] [string]$Block,
        [Parameter(Mandatory)] [string]$Key
    )

    $pattern = '(?m)^\s*' + [regex]::Escape($Key) + '\s*=\s*"([^"]*)"\s*$'
    if ($Block -match $pattern) {
        return [string]$Matches[1]
    }

    return $null
}

function Get-TomlStringArrayValue {
    param(
        [Parameter(Mandatory)] [string]$Block,
        [Parameter(Mandatory)] [string]$Key
    )

    $pattern = '(?m)^\s*' + [regex]::Escape($Key) + '\s*=\s*\[(.*?)\]\s*$'
    if ($Block -notmatch $pattern) {
        return @()
    }

    return @([regex]::Matches($Matches[1], '"([^"]*)"') | ForEach-Object { [string]$_.Groups[1].Value })
}

function Get-McpServerBlocks {
    param([Parameter(Mandatory)] [string]$Toml)

    $blocks = @{}
    $pattern = '(?ms)^\[mcp_servers\.([^\]]+)\]\s*\r?\n(.*?)(?=^\[|\z)'
    foreach ($match in [regex]::Matches($Toml, $pattern)) {
        $blocks[[string]$match.Groups[1].Value] = [string]$match.Groups[2].Value
    }

    return $blocks
}

function Get-DbProxyBaseUrl {
    param([Parameter(Mandatory)] [string]$ProjectRoot)

    $dbProxyConfigPath = Join-Path $ProjectRoot "db-proxy/config/db-proxy.config.json"
    if (-not (Test-Path -LiteralPath $dbProxyConfigPath)) {
        return "http://127.0.0.1:8765"
    }

    $dbProxyConfig = Get-Content -LiteralPath $dbProxyConfigPath -Raw | ConvertFrom-Json
    if ($null -ne $dbProxyConfig.http -and -not [string]::IsNullOrWhiteSpace([string]$dbProxyConfig.http.baseUrl)) {
        return ([string]$dbProxyConfig.http.baseUrl).TrimEnd("/")
    }

    return "http://127.0.0.1:8765"
}

function Invoke-StdioSmokeTest {
    param(
        [Parameter(Mandatory)] [string]$Command,
        [Parameter(Mandatory)] [string[]]$Arguments,
        [Parameter(Mandatory)] [string]$WorkingDirectory
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

$failures = 0
$toml = Get-Content -LiteralPath $configPath -Raw
$blocks = Get-McpServerBlocks -Toml $toml

$actualServers = @($blocks.Keys | ForEach-Object { [string]$_ } | Sort-Object -Unique)
$missingServers = @($expectedServers | Where-Object { $_ -notin $actualServers })
$unexpectedServers = @($actualServers | Where-Object { $_ -notin $expectedServers })

if ($missingServers.Count -gt 0 -or $unexpectedServers.Count -gt 0) {
    $failures++
    Write-Host ("[mcp  ] .codex/config.toml -> FAILED: expected servers [{0}], got [{1}]." -f ($expectedServers -join ", "), ($actualServers -join ", "))
    if ($missingServers.Count -gt 0) {
        Write-Host ("         Missing: {0}" -f ($missingServers -join ", "))
    }
    if ($unexpectedServers.Count -gt 0) {
        Write-Host ("         Unexpected: {0}" -f ($unexpectedServers -join ", "))
    }
}
else {
    Write-Host ("[mcp  ] .codex/config.toml -> OK, servers: {0}." -f ($actualServers -join ", "))
}

if ($blocks.ContainsKey("powershell-mcp-facade")) {
    $facadeBlock = [string]$blocks["powershell-mcp-facade"]
    $facadeErrors = @()

    if ((Get-TomlStringValue -Block $facadeBlock -Key "command") -ne "powershell") {
        $facadeErrors += "command must be powershell"
    }

    if ((Get-TomlStringValue -Block $facadeBlock -Key "cwd") -ne ".") {
        $facadeErrors += "cwd must be ."
    }

    $args = @(Get-TomlStringArrayValue -Block $facadeBlock -Key "args")
    if ("scripts/Start-McpServer.ps1" -notin $args) {
        $facadeErrors += "args must include scripts/Start-McpServer.ps1"
    }

    $enabledTools = @(Get-TomlStringArrayValue -Block $facadeBlock -Key "enabled_tools")
    $missingTools = @($expectedFacadeTools | Where-Object { $_ -notin $enabledTools })
    if ($missingTools.Count -gt 0) {
        $facadeErrors += ("enabled_tools is missing {0}" -f ($missingTools -join ", "))
    }

    if ($facadeErrors.Count -gt 0) {
        $failures++
        Write-Host ("[stdio] powershell-mcp-facade -> FAILED: {0}." -f ($facadeErrors -join "; "))
    }
    elseif ($SkipSmokeTest) {
        Write-Host "[stdio] powershell-mcp-facade -> config OK (smoke test skipped)."
    }
    else {
        try {
            $scriptPath = Join-Path $projectRoot "scripts/Start-McpServer.ps1"
            $smokeArgs = @("-NoProfile", "-ExecutionPolicy", "RemoteSigned", "-File", $scriptPath)
            $toolNames = @(Invoke-StdioSmokeTest -Command "powershell" -Arguments $smokeArgs -WorkingDirectory $projectRoot)
            $missingTools = @($expectedFacadeTools | Where-Object { $_ -notin $toolNames })
            $unexpectedTools = @($toolNames | Where-Object { $_ -notin $expectedFacadeTools })

            if ($missingTools.Count -gt 0 -or $unexpectedTools.Count -gt 0) {
                $failures++
                Write-Host ("[stdio] powershell-mcp-facade -> FAILED: expected tools [{0}], got [{1}]." -f ($expectedFacadeTools -join ", "), ($toolNames -join ", "))
                if ($missingTools.Count -gt 0) {
                    Write-Host ("         Missing: {0}" -f ($missingTools -join ", "))
                }
                if ($unexpectedTools.Count -gt 0) {
                    Write-Host ("         Unexpected: {0}" -f ($unexpectedTools -join ", "))
                }
            }
            else {
                Write-Host ("[stdio] powershell-mcp-facade -> OK, tools/list returned {0} tool(s): {1}." -f $toolNames.Count, ($toolNames -join ", "))
            }
        }
        catch {
            $failures++
            Write-Host ("[stdio] powershell-mcp-facade -> FAILED: {0}" -f $_.Exception.Message)
        }
    }
}

if ($blocks.ContainsKey("jira-internal")) {
    $url = Get-TomlStringValue -Block ([string]$blocks["jira-internal"]) -Key "url"
    if ($url -eq "https://jmcp.acumatica.com/mcp") {
        Write-Host ("[http ] jira-internal        -> {0}" -f $url)
    }
    else {
        $failures++
        Write-Host ("[http ] jira-internal        -> FAILED: expected https://jmcp.acumatica.com/mcp, got {0}" -f $url)
    }
}

if ($blocks.ContainsKey("wiki-internal")) {
    $url = Get-TomlStringValue -Block ([string]$blocks["wiki-internal"]) -Key "url"
    if ($url -eq "https://wmcp.acumatica.com/mcp") {
        Write-Host ("[http ] wiki-internal        -> {0}" -f $url)
    }
    else {
        $failures++
        Write-Host ("[http ] wiki-internal        -> FAILED: expected https://wmcp.acumatica.com/mcp, got {0}" -f $url)
    }
}

$dbProxyBaseUrl = Get-DbProxyBaseUrl -ProjectRoot $projectRoot
try {
    $dbStatus = Invoke-RestMethod -Uri ("{0}/status" -f $dbProxyBaseUrl) -Method Get -TimeoutSec 3 -ErrorAction Stop
    $backendVersion = ""
    if ($null -ne $dbStatus.result -and $null -ne $dbStatus.result.backendVersion) {
        $backendVersion = [string]$dbStatus.result.backendVersion
    }

    if ($backendVersion -eq $expectedDbProxyBackendVersion) {
        Write-Host ("[db   ] db-proxy              -> /status OK (backendVersion={0})" -f $backendVersion)
    }
    else {
        $failures++
        Write-Host ("[db   ] db-proxy              -> FAILED: {0}/status reports backendVersion={1}; expected {2}." -f $dbProxyBaseUrl, $backendVersion, $expectedDbProxyBackendVersion)
    }
}
catch {
    Write-Host ("[db   ] db-proxy              -> /status not reachable on {0} (use scripts/Start-Codex.ps1 -ProxyOnly to start it)" -f $dbProxyBaseUrl)
}

if ($failures -gt 0) {
    Write-Host ""
    Write-Host "$failures MCP check(s) failed."
    exit 1
}

Write-Host ""
Write-Host "Codex MCP project configuration looks healthy. Run scripts/Start-Codex.ps1 and check /mcp after Codex starts."
exit 0
