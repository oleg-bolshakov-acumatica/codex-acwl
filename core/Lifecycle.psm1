Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "Config.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "ToolRegistry.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "ResourceRegistry.psm1") -Force

function Get-McpServerInfo {
    [CmdletBinding()]
    param()

    $serverConfig = Get-McpServerConfig

    return [ordered]@{
        name = $serverConfig.server.id
        version = $serverConfig.server.version
    }
}

function Get-McpToolCatalog {
    [CmdletBinding()]
    param()

    return Get-McpRegisteredTools
}

function Get-McpResourceCatalog {
    [CmdletBinding()]
    param()

    return Get-McpRegisteredResources
}

function Get-McpResourceTemplateCatalog {
    [CmdletBinding()]
    param()

    return Get-McpResourceTemplates
}

function New-McpInitializeResult {
    [CmdletBinding()]
    param(
        $ParamsObject = $null
    )

    $serverConfig = Get-McpServerConfig
    $requestedProtocolVersion = $null
    if ($null -ne $ParamsObject) {
        if ($ParamsObject -is [System.Collections.IDictionary]) {
            if ($ParamsObject.Contains("protocolVersion")) {
                $requestedProtocolVersion = [string]$ParamsObject["protocolVersion"]
            }
        }
        elseif ($null -ne $ParamsObject.PSObject.Properties["protocolVersion"]) {
            $requestedProtocolVersion = [string]$ParamsObject.protocolVersion
        }
    }

    $defaultProtocolVersion = [string]$serverConfig.server.protocolVersion
    $supportedProtocolVersions = @($serverConfig.server.supportedProtocolVersions | ForEach-Object { [string]$_ })
    if ($supportedProtocolVersions.Count -eq 0) {
        $supportedProtocolVersions = @($defaultProtocolVersion)
    }

    $negotiatedProtocolVersion = if (-not [string]::IsNullOrWhiteSpace($requestedProtocolVersion) -and ($supportedProtocolVersions -contains $requestedProtocolVersion)) {
        $requestedProtocolVersion
    }
    else {
        $supportedProtocolVersions[-1]
    }

    return [ordered]@{
        protocolVersion = $negotiatedProtocolVersion
        capabilities = [ordered]@{
            tools = [ordered]@{
                listChanged = $false
            }
            resources = [ordered]@{
                subscribe = $false
                listChanged = $false
            }
        }
        serverInfo = Get-McpServerInfo
        instructions = "Use this MCP facade for read-only SQL context only (sql.select). Prefer tools/call for agent-driven retrieval. Use server.describe_capabilities to inspect available tools, resource templates, output shapes, defaults, and backend status. For Jira use the jira-internal MCP server, for Wiki use the wiki-internal MCP server, and for pull-request / branch diffs use git over the local code/ repository. Backend/provider details are intentionally hidden behind this facade."
    }
}

Export-ModuleMember -Function Get-McpServerInfo, Get-McpToolCatalog, Get-McpResourceCatalog, Get-McpResourceTemplateCatalog, New-McpInitializeResult
