[CmdletBinding()]
param(
    [string]$Server = "",
    [string]$Schema = "master",
    [string]$Query = "SELECT 1 AS one"
)

# Smoke test for the DB proxy itself (NOT through the MCP facade).
#
# Sends a single POST /invoke with operation=sql.select directly to the proxy
# and asserts the response is { ok: true, result: { columns, rows, rowCount } }.
# Also probes GET /status first.
#
# REQUIRES the DB proxy running (start it with db-proxy/Start.ps1 or let
# scripts/Start-Codex.ps1 auto-start it). The default query (SELECT 1 AS one)
# is harmless and read-only; override -Server/-Schema/-Query to hit a real DB:
#   .\Smoke-Test-DbProxy.ps1 -Schema MyDb -Query "SELECT TOP 1 * FROM COMPANY"

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "..\core\ResourceProxyTransport.psm1") -Force
$settings = Get-ResourceProxySettings
$baseUrl = $settings.baseUrl.TrimEnd("/")

# 1) /status probe
try {
    $status = Invoke-RestMethod -Uri ("{0}/status" -f $baseUrl) -Method Get -TimeoutSec 10 -ErrorAction Stop
    Write-Host ("[smoke] /status OK -> backendVersion={0}" -f $status.result.backendVersion)
}
catch {
    Write-Error ("DB proxy /status is unreachable on {0}: {1}. Is the proxy running (db-proxy/Start.ps1)?" -f $baseUrl, $_.Exception.Message)
    exit 1
}

# 2) /invoke sql.select
$body = [ordered]@{
    requestId = [guid]::NewGuid().ToString()
    operation = "sql.select"
    arguments = [ordered]@{
        server = $Server
        schema = $Schema
        query  = $Query
    }
} | ConvertTo-Json -Depth 10 -Compress

try {
    $response = Invoke-RestMethod -Uri ("{0}/invoke" -f $baseUrl) -Method Post -ContentType "application/json" -Body $body -TimeoutSec $settings.requestTimeoutSec -ErrorAction Stop
}
catch {
    Write-Error ("sql.select request failed against {0}/invoke: {1}" -f $baseUrl, $_.Exception.Message)
    exit 1
}

if (-not $response.ok) {
    Write-Error ("sql.select returned an error: {0} ({1})" -f $response.error.message, $response.error.code)
    exit 1
}

$result = $response.result
$missing = @("columns", "rows", "rowCount") | Where-Object { $null -eq $result.PSObject.Properties[$_] }
if (@($missing).Count -gt 0) {
    Write-Error ("sql.select result is missing expected field(s): {0}." -f (@($missing) -join ", "))
    exit 1
}

$columnCount = @($result.columns).Count
Write-Host ("[smoke] sql.select OK -> {0} column(s), rowCount={1}." -f $columnCount, $result.rowCount)
Write-Host "[smoke] DB proxy responded with columns, rows, and rowCount as expected."
exit 0
