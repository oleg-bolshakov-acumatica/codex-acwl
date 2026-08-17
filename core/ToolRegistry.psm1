Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "BackendClient.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Errors.psm1") -Force

# Light workspace (codex-acwl): this facade exposes only read-only SQL tools.
# Jira/Wiki access has moved to the corporate jira-internal / wiki-internal MCP
# servers, and pull-request inspection moved to git over the local code/ repo.

function Get-ObjectPropertyValue {
    param(
        $Object,
        [Parameter(Mandatory)] [string]$PropertyName,
        $DefaultValue = $null
    )

    if ($null -eq $Object) {
        return $DefaultValue
    }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($PropertyName)) {
            return $Object[$PropertyName]
        }

        return $DefaultValue
    }

    $property = $Object.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $DefaultValue
    }

    return $property.Value
}

function New-OpenObjectSchema {
    param(
        [hashtable]$Properties = @{},
        [string[]]$Required = @()
    )

    $schema = [ordered]@{
        type = "object"
        properties = [ordered]@{}
        additionalProperties = $true
    }

    foreach ($key in $Properties.Keys) {
        $schema.properties[$key] = $Properties[$key]
    }

    if ($Required.Count -gt 0) {
        $schema.required = @($Required)
    }

    return $schema
}

function New-ArraySchema {
    param(
        $Items = ([ordered]@{ type = "object"; additionalProperties = $true })
    )

    return [ordered]@{
        type = "array"
        items = $Items
    }
}

function New-StringSchema {
    param(
        [string]$Description = ""
    )

    $schema = [ordered]@{ type = "string" }
    if (-not [string]::IsNullOrWhiteSpace($Description)) {
        $schema.description = $Description
    }

    return $schema
}

function New-IntegerSchema {
    param(
        [string]$Description = ""
    )

    $schema = [ordered]@{ type = "integer" }
    if (-not [string]::IsNullOrWhiteSpace($Description)) {
        $schema.description = $Description
    }

    return $schema
}

function Get-SqlSelectOutputSchema {
    return New-OpenObjectSchema -Required @("server", "database", "columns", "rows", "rowCount", "truncated") -Properties @{
        server = New-StringSchema
        database = New-StringSchema
        columns = New-ArraySchema -Items (New-StringSchema)
        columnMetadata = New-ArraySchema
        rows = New-ArraySchema
        rowCount = New-IntegerSchema "Number of rows returned."
        truncated = [ordered]@{ type = "boolean" }
        limit = New-IntegerSchema
        truncatedCellCount = New-IntegerSchema
        durationMs = New-IntegerSchema
        warnings = New-ArraySchema -Items (New-StringSchema)
    }
}

function Get-SqlDiscoveryOutputSchema {
    param([string]$ItemName, [string]$CountName)

    $properties = @{
        server = New-StringSchema
        truncated = [ordered]@{ type = "boolean" }
        limit = New-IntegerSchema
        durationMs = New-IntegerSchema
        warnings = New-ArraySchema -Items (New-StringSchema)
    }
    $properties[$ItemName] = New-ArraySchema
    $properties[$CountName] = New-IntegerSchema
    return New-OpenObjectSchema -Required @("server", $ItemName, $CountName, "truncated") -Properties $properties
}

function Get-DescribeCapabilitiesOutputSchema {
    return New-OpenObjectSchema -Required @("server", "tools", "resourceTemplates", "backend") -Properties @{
        server = [ordered]@{ type = "object"; additionalProperties = $true }
        tools = New-ArraySchema
        resourceTemplates = New-ArraySchema
        backend = [ordered]@{ type = "object"; additionalProperties = $true }
        guidance = New-ArraySchema -Items (New-StringSchema)
    }
}

function New-McpToolSuccessResult {
    param(
        [Parameter(Mandatory)] $StructuredContent,
        [string]$Text = "Tool call succeeded."
    )

    return [ordered]@{
        content = @(
            [ordered]@{
                type = "text"
                text = $Text
            }
        )
        structuredContent = $StructuredContent
        isError = $false
    }
}

function New-McpToolErrorResult {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [string]$Code = "tool_error",
        [string]$Source = "mcp_facade",
        [string]$RecoveryHint = "",
        $Details = $null
    )

    $payload = New-McpToolErrorPayload -Message $Message -Code $Code -Source $Source -RecoveryHint $RecoveryHint -Details $Details

    return [ordered]@{
        content = @(
            [ordered]@{
                type = "text"
                text = $Message
            }
        )
        structuredContent = $payload
        isError = $true
    }
}

function Convert-BackendResponseToToolResult {
    param(
        [Parameter(Mandatory)] $BackendResponse,
        [Parameter(Mandatory)] [string]$SuccessText
    )

    $isOk = Get-ObjectPropertyValue -Object $BackendResponse -PropertyName "ok" -DefaultValue $false
    if ($isOk) {
        $result = Get-ObjectPropertyValue -Object $BackendResponse -PropertyName "result"
        return New-McpToolSuccessResult -StructuredContent $result -Text $SuccessText
    }

    $errorPayload = Get-ObjectPropertyValue -Object $BackendResponse -PropertyName "error"
    $message = [string](Get-ObjectPropertyValue -Object $errorPayload -PropertyName "message" -DefaultValue "Backend request failed.")
    $code = [string](Get-ObjectPropertyValue -Object $errorPayload -PropertyName "code" -DefaultValue "backend_error")
    $source = [string](Get-ObjectPropertyValue -Object $errorPayload -PropertyName "source" -DefaultValue "resource_proxy")
    $details = Get-ObjectPropertyValue -Object $errorPayload -PropertyName "details"
    $recoveryHint = switch ($code) {
        "backend_unavailable" { "Start db-proxy/scripts/Start-DbProxyServer.ps1 in a separate PowerShell window." }
        "inprocess_disabled" { "Switch backend.mode to http with the external proxy running, or explicitly enable dev/test fallback." }
        default { "" }
    }

    return New-McpToolErrorResult -Message $message -Code $code -Source $source -RecoveryHint $recoveryHint -Details $details
}

function Get-McpRegisteredTools {
    [CmdletBinding()]
    param()

    $sqlSelectInput = [ordered]@{
        type = "object"
        properties = [ordered]@{
            server = New-StringSchema "SQL Server host or configured alias."
            database = New-StringSchema "Database name."
            schema = New-StringSchema "Deprecated alias for database."
            query = New-StringSchema "One side-effect-free SELECT statement."
            parameters = [ordered]@{ type = "object"; additionalProperties = $true; description = "Named SQL parameter values. Null values require { value: null, sqlType: '...' }." }
            maxRows = New-IntegerSchema "Requested row limit, bounded by provider configuration."
            timeoutSec = New-IntegerSchema "Requested timeout, bounded by provider configuration."
        }
        required = @("query")
        additionalProperties = $false
    }
    $listDatabasesInput = [ordered]@{ type = "object"; properties = [ordered]@{
        server = New-StringSchema "SQL Server host or configured alias."
        namePattern = New-StringSchema "Optional SQL LIKE pattern; '*' is converted to '%'."
        maxResults = New-IntegerSchema "Requested result limit, bounded by provider configuration."
        timeoutSec = New-IntegerSchema "Requested timeout, bounded by provider configuration."
    }; additionalProperties = $false }
    $searchSchemaInput = [ordered]@{ type = "object"; required = @("database"); properties = [ordered]@{
        server = New-StringSchema "SQL Server host or configured alias."
        database = New-StringSchema "Database name."
        schemaName = New-StringSchema "Optional SQL schema name."
        tablePattern = New-StringSchema "Optional table-name LIKE pattern; '*' is converted to '%'."
        columnPattern = New-StringSchema "Optional column-name LIKE pattern; '*' is converted to '%'."
        maxResults = New-IntegerSchema "Requested result limit, bounded by provider configuration."
        timeoutSec = New-IntegerSchema "Requested timeout, bounded by provider configuration."
    }; additionalProperties = $false }
    $describeTableInput = [ordered]@{ type = "object"; required = @("database", "tableName"); properties = [ordered]@{
        server = New-StringSchema "SQL Server host or configured alias."
        database = New-StringSchema "Database name."
        schemaName = [ordered]@{ type = "string"; default = "dbo"; description = "SQL schema name." }
        tableName = New-StringSchema "Table name."
        timeoutSec = New-IntegerSchema "Requested timeout, bounded by provider configuration."
    }; additionalProperties = $false }

    return @(
        [ordered]@{
            name = "sql.select"
            title = "Run SQL Select"
            description = "Execute one bounded, side-effect-free SQL SELECT and return structured rows."
            annotations = [ordered]@{
                title = "Run SQL Select"
                readOnlyHint = $true
                destructiveHint = $false
                openWorldHint = $true
                idempotentHint = $true
            }
            inputSchema = $sqlSelectInput
            outputSchema = Get-SqlSelectOutputSchema
        },
        [ordered]@{
            name = "sql.list_databases"; title = "List SQL Databases"
            description = "List online databases accessible to the current Windows identity."
            annotations = [ordered]@{ title = "List SQL Databases"; readOnlyHint = $true; destructiveHint = $false; openWorldHint = $true; idempotentHint = $true }
            inputSchema = $listDatabasesInput
            outputSchema = Get-SqlDiscoveryOutputSchema -ItemName "databases" -CountName "databaseCount"
        },
        [ordered]@{
            name = "sql.search_schema"; title = "Search SQL Schema"
            description = "Search table and column metadata in one database."
            annotations = [ordered]@{ title = "Search SQL Schema"; readOnlyHint = $true; destructiveHint = $false; openWorldHint = $true; idempotentHint = $true }
            inputSchema = $searchSchemaInput
            outputSchema = Get-SqlDiscoveryOutputSchema -ItemName "matches" -CountName "matchCount"
        },
        [ordered]@{
            name = "sql.describe_table"; title = "Describe SQL Table"
            description = "Return columns, primary-key flags, and CompanyID presence for one table."
            annotations = [ordered]@{ title = "Describe SQL Table"; readOnlyHint = $true; destructiveHint = $false; openWorldHint = $true; idempotentHint = $true }
            inputSchema = $describeTableInput
            outputSchema = New-OpenObjectSchema -Required @("server", "database", "schemaName", "tableName", "columns", "columnCount", "hasCompanyId") -Properties @{ server = New-StringSchema; database = New-StringSchema; schemaName = New-StringSchema; tableName = New-StringSchema; columns = New-ArraySchema; columnCount = New-IntegerSchema; hasCompanyId = [ordered]@{ type = "boolean" }; durationMs = New-IntegerSchema; warnings = New-ArraySchema -Items (New-StringSchema) }
        },
        [ordered]@{
            name = "server.describe_capabilities"
            title = "Describe MCP Capabilities"
            description = "Return a machine-readable catalog of this facade's tools, resource templates, expected output shapes, defaults, and backend status."
            annotations = [ordered]@{
                title = "Describe MCP Capabilities"
                readOnlyHint = $true
                destructiveHint = $false
                openWorldHint = $false
                idempotentHint = $true
            }
            inputSchema = [ordered]@{
                type = "object"
                properties = [ordered]@{}
                additionalProperties = $false
            }
            outputSchema = Get-DescribeCapabilitiesOutputSchema
        }
    )
}

function Get-McpKnownResourceTemplatesForTools {
    return @(
        [ordered]@{
            uriTemplate = "sql://select/{database}?query={query}&server={server}"
            name = "SQL Select"
            description = "Read-only SQL SELECT result. Use tools/call for parameters and bounded limits."
            mimeType = "application/json"
        }
    )
}

function Get-McpCapabilityDescription {
    $backendStatus = Get-McpBackendStatus

    return [ordered]@{
        server = [ordered]@{
            name = "powershell-mcp-facade"
            transport = "stdio"
            protocol = "JSON-RPC 2.0 / MCP"
            scope = @("sql-read-only")
        }
        tools = Get-McpRegisteredTools
        resourceTemplates = Get-McpKnownResourceTemplatesForTools
        backend = $backendStatus
        guidance = @(
            "This facade is read-only SQL only. Use sql.list_databases when the target database is unknown.",
            "Use sql.search_schema and sql.describe_table before relying on uncertain metadata.",
            "Use sql.select for one bounded side-effect-free SELECT query; prefer named parameters for external values.",
            "For Jira use the jira-internal MCP server; for Wiki use the wiki-internal MCP server.",
            "For pull-request / branch diffs use git over the local code/ repository."
        )
    }
}

function Invoke-McpToolCall {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ToolName,
        $Arguments
    )

    try {
        switch ($ToolName) {
            "sql.select" {
                $database = [string](Get-ObjectPropertyValue -Object $Arguments -PropertyName "database")
                $schema = [string](Get-ObjectPropertyValue -Object $Arguments -PropertyName "schema")
                $query = Get-ObjectPropertyValue -Object $Arguments -PropertyName "query"
                $server = Get-ObjectPropertyValue -Object $Arguments -PropertyName "server"

                if ([string]::IsNullOrWhiteSpace($database) -and [string]::IsNullOrWhiteSpace($schema)) {
                    return New-McpToolErrorResult -Message "Missing required argument: database" -Code "validation_error"
                }

                if ([string]::IsNullOrWhiteSpace($query)) {
                    return New-McpToolErrorResult -Message "Missing required argument: query" -Code "validation_error"
                }

                $backendResponse = Invoke-McpBackendRequest -Operation "sql.select" -Arguments ([ordered]@{
                    server = $server
                    database = $database
                    schema = $schema
                    query = $query
                    parameters = Get-ObjectPropertyValue -Object $Arguments -PropertyName "parameters"
                    maxRows = Get-ObjectPropertyValue -Object $Arguments -PropertyName "maxRows" -DefaultValue 0
                    timeoutSec = Get-ObjectPropertyValue -Object $Arguments -PropertyName "timeoutSec" -DefaultValue 0
                })
                $result = Get-ObjectPropertyValue -Object $backendResponse -PropertyName "result"
                $rowCount = Get-ObjectPropertyValue -Object $result -PropertyName "rowCount" -DefaultValue 0
                return Convert-BackendResponseToToolResult -BackendResponse $backendResponse -SuccessText ("Returned {0} SQL rows." -f $rowCount)
            }

            "sql.list_databases" {
                $backendResponse = Invoke-McpBackendRequest -Operation $ToolName -Arguments $Arguments
                return Convert-BackendResponseToToolResult -BackendResponse $backendResponse -SuccessText "Returned accessible SQL databases."
            }

            "sql.search_schema" {
                if ([string]::IsNullOrWhiteSpace([string](Get-ObjectPropertyValue -Object $Arguments -PropertyName "database"))) { return New-McpToolErrorResult -Message "Missing required argument: database" -Code "validation_error" }
                $backendResponse = Invoke-McpBackendRequest -Operation $ToolName -Arguments $Arguments
                return Convert-BackendResponseToToolResult -BackendResponse $backendResponse -SuccessText "Returned SQL schema matches."
            }

            "sql.describe_table" {
                if ([string]::IsNullOrWhiteSpace([string](Get-ObjectPropertyValue -Object $Arguments -PropertyName "database"))) { return New-McpToolErrorResult -Message "Missing required argument: database" -Code "validation_error" }
                if ([string]::IsNullOrWhiteSpace([string](Get-ObjectPropertyValue -Object $Arguments -PropertyName "tableName"))) { return New-McpToolErrorResult -Message "Missing required argument: tableName" -Code "validation_error" }
                $backendResponse = Invoke-McpBackendRequest -Operation $ToolName -Arguments $Arguments
                return Convert-BackendResponseToToolResult -BackendResponse $backendResponse -SuccessText "Returned SQL table description."
            }

            "server.describe_capabilities" {
                $description = Get-McpCapabilityDescription
                return New-McpToolSuccessResult -StructuredContent $description -Text "Returned MCP facade capability catalog."
            }

            default {
                return New-McpToolErrorResult -Message ("Unknown tool: {0}" -f $ToolName) -Code "unknown_tool"
            }
        }
    }
    catch {
        return New-McpToolErrorResult -Message $_.Exception.Message -Code "tool_execution_error"
    }
}

Export-ModuleMember -Function Get-McpRegisteredTools, Invoke-McpToolCall
