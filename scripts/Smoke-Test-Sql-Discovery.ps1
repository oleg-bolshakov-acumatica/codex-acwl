[CmdletBinding()]
param(
    [string]$Server = "",
    [string]$Database = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$serverScript = Join-Path $PSScriptRoot "Start-McpServer.ps1"
function New-JsonRpcRequest {
    param([int]$Id, [string]$Method, $Params)
    return ([ordered]@{ jsonrpc = "2.0"; id = $Id; method = $Method; params = $Params } | ConvertTo-Json -Depth 12 -Compress)
}

$requests = @(
    (New-JsonRpcRequest -Id 1 -Method "initialize" -Params ([ordered]@{ protocolVersion = "2024-11-05"; capabilities = [ordered]@{}; clientInfo = [ordered]@{ name = "sql-discovery-smoke"; version = "0.7" } }))
    ([ordered]@{ jsonrpc = "2.0"; method = "notifications/initialized"; params = [ordered]@{} } | ConvertTo-Json -Compress)
    (New-JsonRpcRequest -Id 2 -Method "tools/call" -Params ([ordered]@{ name = "sql.list_databases"; arguments = [ordered]@{ server = $Server; namePattern = "*"; maxResults = 100 } }))
)
$responses = @((($requests -join [Environment]::NewLine) + [Environment]::NewLine) | powershell -NoProfile -ExecutionPolicy Bypass -File $serverScript | Where-Object { $_ -match '^\s*\{' } | ForEach-Object { $_ | ConvertFrom-Json })
$listResult = ($responses | Where-Object { $_.id -eq 2 } | Select-Object -First 1).result
if ($null -eq $listResult -or $listResult.isError) { throw "sql.list_databases failed: $($listResult.content[0].text)" }

$databases = @($listResult.structuredContent.databases)
if ($databases.Count -eq 0) { throw "sql.list_databases returned no accessible database." }
$selectedDatabase = if ([string]::IsNullOrWhiteSpace($Database)) { [string]$databases[0].name } else { $Database }

$requests = @(
    (New-JsonRpcRequest -Id 1 -Method "initialize" -Params ([ordered]@{ protocolVersion = "2024-11-05"; capabilities = [ordered]@{}; clientInfo = [ordered]@{ name = "sql-schema-smoke"; version = "0.7" } }))
    ([ordered]@{ jsonrpc = "2.0"; method = "notifications/initialized"; params = [ordered]@{} } | ConvertTo-Json -Compress)
    (New-JsonRpcRequest -Id 3 -Method "tools/call" -Params ([ordered]@{ name = "sql.search_schema"; arguments = [ordered]@{ server = $Server; database = $selectedDatabase; maxResults = 1 } }))
)
$responses = @((($requests -join [Environment]::NewLine) + [Environment]::NewLine) | powershell -NoProfile -ExecutionPolicy Bypass -File $serverScript | Where-Object { $_ -match '^\s*\{' } | ForEach-Object { $_ | ConvertFrom-Json })
$searchResult = ($responses | Where-Object { $_.id -eq 3 } | Select-Object -First 1).result
if ($null -eq $searchResult -or $searchResult.isError) { throw "sql.search_schema failed: $($searchResult.content[0].text)" }

$match = @($searchResult.structuredContent.matches | Select-Object -First 1)
if ($match.Count -eq 0) { throw "sql.search_schema returned no tables in '$selectedDatabase'." }

$requests = @(
    (New-JsonRpcRequest -Id 1 -Method "initialize" -Params ([ordered]@{ protocolVersion = "2024-11-05"; capabilities = [ordered]@{}; clientInfo = [ordered]@{ name = "sql-table-smoke"; version = "0.7" } }))
    ([ordered]@{ jsonrpc = "2.0"; method = "notifications/initialized"; params = [ordered]@{} } | ConvertTo-Json -Compress)
    (New-JsonRpcRequest -Id 4 -Method "tools/call" -Params ([ordered]@{ name = "sql.describe_table"; arguments = [ordered]@{ server = $Server; database = $selectedDatabase; schemaName = [string]$match[0].schema_name; tableName = [string]$match[0].table_name } }))
)
$responses = @((($requests -join [Environment]::NewLine) + [Environment]::NewLine) | powershell -NoProfile -ExecutionPolicy Bypass -File $serverScript | Where-Object { $_ -match '^\s*\{' } | ForEach-Object { $_ | ConvertFrom-Json })
$describeResult = ($responses | Where-Object { $_.id -eq 4 } | Select-Object -First 1).result
if ($null -eq $describeResult -or $describeResult.isError) { throw "sql.describe_table failed: $($describeResult.content[0].text)" }

Write-Host ("[smoke] SQL discovery OK -> database={0}; table={1}.{2}; columns={3}." -f $selectedDatabase, $match[0].schema_name, $match[0].table_name, $describeResult.structuredContent.columnCount)
