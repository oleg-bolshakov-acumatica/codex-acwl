[CmdletBinding()]
param(
    [switch]$SkipProxy,
    [switch]$ProxyOnly,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CodexArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$expectedDbProxyBackendVersion = "db-proxy-0.1.0"

function Get-DbProxyBaseUrl {
    param([Parameter(Mandatory)] [string]$ProjectRoot)

    $configPath = Join-Path $ProjectRoot "db-proxy/config/db-proxy.config.json"
    if (-not (Test-Path -LiteralPath $configPath)) {
        return "http://127.0.0.1:8765"
    }

    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    if ($null -ne $config.http -and -not [string]::IsNullOrWhiteSpace([string]$config.http.baseUrl)) {
        return ([string]$config.http.baseUrl).TrimEnd("/")
    }

    return "http://127.0.0.1:8765"
}

function Get-DbProxyStatus {
    param([Parameter(Mandatory)] [string]$BaseUrl)

    try {
        $status = Invoke-RestMethod -Uri ("{0}/status" -f $BaseUrl) -Method Get -TimeoutSec 3 -ErrorAction Stop
        if ($null -ne $status -and [bool]$status.ok) {
            return $status
        }

        return $null
    }
    catch {
        return $null
    }
}

function Assert-ExpectedDbProxy {
    param(
        [Parameter(Mandatory)] $Status,
        [Parameter(Mandatory)] [string]$BaseUrl,
        [Parameter(Mandatory)] [string]$ExpectedBackendVersion
    )

    $backendVersion = ""
    if ($null -ne $Status.result -and $null -ne $Status.result.backendVersion) {
        $backendVersion = [string]$Status.result.backendVersion
    }

    if ($backendVersion -ne $ExpectedBackendVersion) {
        throw ("[db-proxy] {0}/status reports backendVersion='{1}', expected '{2}'. Stop the process using that endpoint or update db-proxy/config/db-proxy.config.json before starting Codex." -f $BaseUrl, $backendVersion, $ExpectedBackendVersion)
    }
}

function Ensure-DbProxy {
    param(
        [Parameter(Mandatory)] [string]$ProjectRoot,
        [int]$TimeoutSec = 15
    )

    $baseUrl = Get-DbProxyBaseUrl -ProjectRoot $ProjectRoot

    $status = Get-DbProxyStatus -BaseUrl $baseUrl
    if ($null -ne $status) {
        Assert-ExpectedDbProxy -Status $status -BaseUrl $baseUrl -ExpectedBackendVersion $expectedDbProxyBackendVersion
        Write-Host ("[db-proxy] already running on {0}." -f $baseUrl)
        return
    }

    $serverScript = Join-Path $ProjectRoot "db-proxy/scripts/Start-DbProxyServer.ps1"
    if (-not (Test-Path -LiteralPath $serverScript)) {
        throw "Cannot find db-proxy server script at $serverScript."
    }

    Write-Host ("[db-proxy] not responding on {0}; starting it..." -f $baseUrl)
    Start-Process powershell -WindowStyle Hidden -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $serverScript
    ) | Out-Null

    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 500
        $status = Get-DbProxyStatus -BaseUrl $baseUrl
        if ($null -ne $status) {
            Assert-ExpectedDbProxy -Status $status -BaseUrl $baseUrl -ExpectedBackendVersion $expectedDbProxyBackendVersion
            Write-Host ("[db-proxy] is up on {0}." -f $baseUrl)
            return
        }
    }

    Write-Warning ("[db-proxy] did not report healthy on {0} within {1}s. SQL tools may fail until it is up." -f $baseUrl, $TimeoutSec)
}

try {
    if (-not $SkipProxy) {
        Ensure-DbProxy -ProjectRoot $projectRoot
    }

    if ($ProxyOnly) {
        exit 0
    }

    $projectConfigPath = Join-Path $projectRoot ".codex\config.toml"
    if (-not (Test-Path -LiteralPath $projectConfigPath)) {
        throw "Cannot find Codex project config at $projectConfigPath."
    }

    $codexCommand = Get-Command codex.cmd -ErrorAction SilentlyContinue
    if ($null -eq $codexCommand) {
        $codexCommand = Get-Command codex -ErrorAction Stop
    }

    & $codexCommand.Source -C $projectRoot @CodexArgs
    exit $LASTEXITCODE
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
