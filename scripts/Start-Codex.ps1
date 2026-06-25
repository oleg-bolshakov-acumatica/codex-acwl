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
$ensureScript = Join-Path $PSScriptRoot "Ensure-CodexMcp.ps1"

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

function Test-DbProxyUp {
    param([Parameter(Mandatory)] [string]$BaseUrl)

    try {
        $status = Invoke-RestMethod -Uri ("{0}/status" -f $BaseUrl) -Method Get -TimeoutSec 3 -ErrorAction Stop
        return ($null -ne $status -and [bool]$status.ok)
    }
    catch {
        return $false
    }
}

function Ensure-DbProxy {
    param(
        [Parameter(Mandatory)] [string]$ProjectRoot,
        [int]$TimeoutSec = 15
    )

    $baseUrl = Get-DbProxyBaseUrl -ProjectRoot $ProjectRoot

    if (Test-DbProxyUp -BaseUrl $baseUrl) {
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
        if (Test-DbProxyUp -BaseUrl $baseUrl) {
            Write-Host ("[db-proxy] is up on {0}." -f $baseUrl)
            return
        }
    }

    Write-Warning ("[db-proxy] did not report healthy on {0} within {1}s. SQL tools may fail until it is up." -f $baseUrl, $TimeoutSec)
}

if (-not $SkipProxy) {
    Ensure-DbProxy -ProjectRoot $projectRoot
}

if ($ProxyOnly) {
    return
}

& powershell -NoProfile -ExecutionPolicy Bypass -File $ensureScript -ProjectRoot $projectRoot -Apply
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$codexCommand = Get-Command codex.cmd -ErrorAction SilentlyContinue
if ($null -eq $codexCommand) {
    $codexCommand = Get-Command codex -ErrorAction Stop
}

& $codexCommand.Source -C $projectRoot @CodexArgs
