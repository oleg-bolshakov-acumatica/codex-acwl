[CmdletBinding()]
param(
    [string]$Server = "",
    [string]$Schema = "master",
    [string]$Query = "SELECT 1 AS one"
)

# Smoke test for the powershell-mcp-facade `sql.select` tool.
#
# Drives the stdio MCP server (scripts/Start-McpServer.ps1) over a single
# JSON-RPC session: initialize -> notifications/initialized -> tools/call for
# sql.select with { server, schema, query }, then asserts that the returned
# structuredContent carries `columns`, `rows`, and `rowCount`.
#
# REQUIRES the db-proxy backend running at http://127.0.0.1:8765; the
# facade forwards sql.select to it. If the backend is down this test fails with
# a backend_unavailable error from the facade.
#
# The default query (SELECT 1 AS one) is harmless and read-only. Override
# -Server / -Schema / -Query to point at, e.g., a COMPANY table:
#   .\Smoke-Test-Sql.ps1 -Schema MyDb -Query "SELECT TOP 1 * FROM COMPANY"

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$serverScript = Join-Path $PSScriptRoot "Start-McpServer.ps1"

if (-not (Test-Path -LiteralPath $serverScript)) {
    Write-Error "Cannot find the MCP server script at $serverScript."
    exit 1
}

function ConvertTo-JsonLine {
    param([Parameter(Mandatory = $true)] $Object)
    return ($Object | ConvertTo-Json -Compress -Depth 20)
}

$arguments = [ordered]@{
    server = $Server
    schema = $Schema
    query  = $Query
}

$requests = @(
    ConvertTo-JsonLine ([ordered]@{
        jsonrpc = "2.0"
        id = 1
        method = "initialize"
        params = [ordered]@{
            protocolVersion = "2024-11-05"
            capabilities = [ordered]@{}
            clientInfo = [ordered]@{ name = "codex-acwl-smoke-sql"; version = "0" }
        }
    }),
    ConvertTo-JsonLine ([ordered]@{
        jsonrpc = "2.0"
        method = "notifications/initialized"
        params = [ordered]@{}
    }),
    ConvertTo-JsonLine ([ordered]@{
        jsonrpc = "2.0"
        id = 2
        method = "tools/call"
        params = [ordered]@{
            name = "sql.select"
            arguments = $arguments
        }
    })
) -join [Environment]::NewLine

Push-Location $projectRoot
try {
    $output = $requests | & powershell -NoProfile -ExecutionPolicy Bypass -File $serverScript
}
finally {
    Pop-Location
}

$response = $null
foreach ($line in $output) {
    if ($line -notmatch '^\s*\{') {
        continue
    }
    $message = $line | ConvertFrom-Json
    if ($null -ne $message.PSObject.Properties["id"] -and $message.id -eq 2) {
        $response = $message
        break
    }
}

if ($null -eq $response) {
    Write-Error "sql.select did not return a response for request id 2. Is the db-proxy backend running at 127.0.0.1:8765?"
    exit 1
}

if ($null -ne $response.PSObject.Properties["error"] -and $null -ne $response.error) {
    Write-Error ("sql.select returned a JSON-RPC error: {0}" -f $response.error.message)
    exit 1
}

$result = $response.result
if ($null -eq $result) {
    Write-Error "sql.select response had no result payload."
    exit 1
}

if ($null -ne $result.PSObject.Properties["isError"] -and $result.isError) {
    $detail = if ($null -ne $result.PSObject.Properties["content"] -and @($result.content).Count -gt 0) { @($result.content)[0].text } else { "unknown error" }
    Write-Error ("sql.select reported a tool error: {0} (confirm the db-proxy backend at 127.0.0.1:8765 is running)." -f $detail)
    exit 1
}

$structured = $result.structuredContent
if ($null -eq $structured) {
    Write-Error "sql.select result is missing structuredContent."
    exit 1
}

$missing = @("columns", "rows", "rowCount") | Where-Object { $null -eq $structured.PSObject.Properties[$_] }
if (@($missing).Count -gt 0) {
    Write-Error ("sql.select structuredContent is missing expected field(s): {0}." -f (@($missing) -join ", "))
    exit 1
}

$columnCount = @($structured.columns).Count
$rowCount = $structured.rowCount
Write-Host ("[smoke] sql.select OK -> {0} column(s), rowCount={1}." -f $columnCount, $rowCount)
Write-Host "[smoke] structuredContent contains columns, rows, and rowCount as expected."
exit 0
