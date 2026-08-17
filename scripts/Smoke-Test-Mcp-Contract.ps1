[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$serverScript = Join-Path $PSScriptRoot "Start-McpServer.ps1"
$requests = @(
    [ordered]@{ jsonrpc = "2.0"; id = 1; method = "initialize"; params = [ordered]@{ protocolVersion = "2024-11-05"; capabilities = [ordered]@{}; clientInfo = [ordered]@{ name = "sql-contract-smoke"; version = "0.7" } } },
    [ordered]@{ jsonrpc = "2.0"; method = "notifications/initialized"; params = [ordered]@{} },
    [ordered]@{ jsonrpc = "2.0"; id = 2; method = "tools/list"; params = [ordered]@{} },
    [ordered]@{ jsonrpc = "2.0"; id = 3; method = "resources/templates/list"; params = [ordered]@{} }
) | ForEach-Object { $_ | ConvertTo-Json -Depth 12 -Compress }

$responses = @((($requests -join [Environment]::NewLine) + [Environment]::NewLine) | powershell -NoProfile -ExecutionPolicy Bypass -File $serverScript | Where-Object { $_ -match '^\s*\{' } | ForEach-Object { $_ | ConvertFrom-Json })
$toolsResponse = $responses | Where-Object { $_.id -eq 2 } | Select-Object -First 1
$templatesResponse = $responses | Where-Object { $_.id -eq 3 } | Select-Object -First 1
if ($null -eq $toolsResponse -or $null -eq $templatesResponse) { throw "MCP contract smoke did not receive all expected responses." }

$expectedTools = @("server.describe_capabilities", "sql.describe_table", "sql.list_databases", "sql.search_schema", "sql.select")
$actualTools = @($toolsResponse.result.tools | ForEach-Object { [string]$_.name } | Sort-Object)
if (@(Compare-Object -ReferenceObject $expectedTools -DifferenceObject $actualTools).Count -gt 0) { throw ("Unexpected SQL tool catalog: {0}" -f ($actualTools -join ", ")) }

$templates = @($templatesResponse.result.resourceTemplates | ForEach-Object { [string]$_.uriTemplate })
if ($templates -notcontains "sql://select/{database}?query={query}&server={server}") { throw "SQL resource template is missing." }

Write-Host ("[smoke] MCP SQL contract OK -> {0}" -f ($actualTools -join ", "))
