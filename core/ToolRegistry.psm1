Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "BackendClient.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Errors.psm1") -Force

# Light workspace (codex-acwl): this facade exposes ONLY read-only SQL select.
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
    return New-OpenObjectSchema -Required @("columns", "rows", "rowCount") -Properties @{
        columns = New-ArraySchema -Items (New-StringSchema)
        rows = New-ArraySchema
        rowCount = New-IntegerSchema "Number of rows returned."
    }
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

    return @(
        [ordered]@{
            name = "sql.select"
            title = "Run SQL Select"
            description = "Execute a read-only SQL SELECT query and return structured rows."
            annotations = [ordered]@{
                title = "Run SQL Select"
                readOnlyHint = $true
                destructiveHint = $false
                openWorldHint = $false
                idempotentHint = $true
            }
            inputSchema = [ordered]@{
                type = "object"
                properties = [ordered]@{
                    server = [ordered]@{
                        type = "string"
                        description = "SQL Server host or configured alias."
                    }
                    schema = [ordered]@{
                        type = "string"
                        description = "Database name."
                    }
                    query = [ordered]@{
                        type = "string"
                        description = "Read-only SELECT statement."
                    }
                }
                required = @("schema", "query")
                additionalProperties = $false
            }
            outputSchema = Get-SqlSelectOutputSchema
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
            uriTemplate = "sql://select/{schema}?query={query}&server={server}"
            name = "SQL Select"
            description = "Read-only SQL SELECT result. Query string must include query=... and may include server=..."
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
            scope = @("sql-select")
        }
        tools = Get-McpRegisteredTools
        resourceTemplates = Get-McpKnownResourceTemplatesForTools
        backend = $backendStatus
        guidance = @(
            "This facade is read-only SQL only. Use sql.select for read-only SELECT queries.",
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
                $schema = Get-ObjectPropertyValue -Object $Arguments -PropertyName "schema"
                $query = Get-ObjectPropertyValue -Object $Arguments -PropertyName "query"
                $server = Get-ObjectPropertyValue -Object $Arguments -PropertyName "server"

                if ([string]::IsNullOrWhiteSpace($schema)) {
                    return New-McpToolErrorResult -Message "Missing required argument: schema" -Code "validation_error"
                }

                if ([string]::IsNullOrWhiteSpace($query)) {
                    return New-McpToolErrorResult -Message "Missing required argument: query" -Code "validation_error"
                }

                $backendResponse = Invoke-McpBackendRequest -Operation "sql.select" -Arguments ([ordered]@{
                    server = $server
                    schema = $schema
                    query = $query
                })
                $result = Get-ObjectPropertyValue -Object $backendResponse -PropertyName "result"
                $rowCount = Get-ObjectPropertyValue -Object $result -PropertyName "rowCount" -DefaultValue 0
                return Convert-BackendResponseToToolResult -BackendResponse $backendResponse -SuccessText ("Returned {0} SQL rows." -f $rowCount)
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
