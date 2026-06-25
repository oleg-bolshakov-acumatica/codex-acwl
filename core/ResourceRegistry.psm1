Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "BackendClient.psm1") -Force

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

function ConvertTo-CompactJson {
    param(
        [Parameter(Mandatory)] $Value
    )

    return $Value | ConvertTo-Json -Depth 20 -Compress
}

function Normalize-BackendPayloadForResource {
    param(
        [Parameter(Mandatory)] $BackendResponse
    )

    $isOk = [bool](Get-ObjectPropertyValue -Object $BackendResponse -PropertyName "ok" -DefaultValue $false)
    if ($isOk) {
        return (Get-ObjectPropertyValue -Object $BackendResponse -PropertyName "result")
    }

    return [ordered]@{
        isError = $true
        error = Get-ObjectPropertyValue -Object $BackendResponse -PropertyName "error"
    }
}

function Get-McpRegisteredResources {
    [CmdletBinding()]
    param()

    return ,@(
        [ordered]@{
            uri = "server://status"
            name = "Server Status"
            title = "Server Status"
            description = "Current MCP backend status exposed through the facade."
            mimeType = "application/json"
            annotations = [ordered]@{
                audience = @("assistant")
                priority = 0.7
            }
        }
    )
}

function Get-McpResourceTemplates {
    [CmdletBinding()]
    param()

    return ,@(
        [ordered]@{
            uriTemplate = "sql://select/{schema}?query={query}&server={server}"
            name = "SQL Select"
            title = "SQL Select"
            description = "Read-only SQL SELECT result retrieved through the MCP facade. Query string must include query=... and may include server=..."
            mimeType = "application/json"
            annotations = [ordered]@{
                audience = @("assistant")
                priority = 0.5
            }
        }
    )
}

function New-McpResourceContents {
    param(
        [Parameter(Mandatory)] [string]$Uri,
        [Parameter(Mandatory)] $Payload
    )

    return [ordered]@{
        contents = @(
            [ordered]@{
                uri = $Uri
                mimeType = "application/json"
                text = (ConvertTo-CompactJson -Value $Payload)
            }
        )
    }
}

function Parse-ResourceUri {
    param(
        [Parameter(Mandatory)] [string]$Uri
    )

    try {
        return [System.Uri]$Uri
    }
    catch {
        throw "Invalid resource URI: $Uri"
    }
}

function Invoke-McpResourceRead {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Uri
    )

    $parsedUri = Parse-ResourceUri -Uri $Uri

    if ($parsedUri.Scheme -eq "server" -and $parsedUri.Host -eq "status") {
        $backendStatus = Get-McpBackendStatus
        return New-McpResourceContents -Uri $Uri -Payload (Normalize-BackendPayloadForResource -BackendResponse $backendStatus)
    }

    if ($parsedUri.Scheme -eq "sql" -and $parsedUri.Host -eq "select") {
        $schema = $parsedUri.AbsolutePath.Trim("/")
        if ([string]::IsNullOrWhiteSpace($schema)) {
            throw "Missing schema in SQL resource URI."
        }

        $query = [System.Web.HttpUtility]::ParseQueryString($parsedUri.Query)
        $sqlQuery = $query["query"]
        $server = $query["server"]

        if ([string]::IsNullOrWhiteSpace($sqlQuery)) {
            throw "Missing query in SQL resource URI."
        }

        $backendResponse = Invoke-McpBackendRequest -Operation "sql.select" -Arguments ([ordered]@{
            server = $server
            schema = $schema
            query = $sqlQuery
        })

        return New-McpResourceContents -Uri $Uri -Payload (Normalize-BackendPayloadForResource -BackendResponse $backendResponse)
    }

    throw "Unknown resource URI: $Uri"
}

Export-ModuleMember -Function Get-McpRegisteredResources, Get-McpResourceTemplates, Invoke-McpResourceRead
