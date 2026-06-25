Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "Errors.psm1") -Force

function Get-ObjectPropertyValue {
    param(
        $Object,
        [Parameter(Mandatory)] [string]$PropertyName,
        $DefaultValue = $null
    )

    if ($null -eq $Object) {
        return $DefaultValue
    }

    $property = $Object.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $DefaultValue
    }

    return $property.Value
}

function Test-McpRequestShape {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Request
    )

    $jsonrpc = Get-ObjectPropertyValue -Object $Request -PropertyName "jsonrpc"
    $method = Get-ObjectPropertyValue -Object $Request -PropertyName "method"

    if ($jsonrpc -ne "2.0") {
        throw (New-McpProtocolError -Code -32600 -Message "Invalid Request" -Data "jsonrpc must be '2.0'.")
    }

    if ([string]::IsNullOrWhiteSpace($method)) {
        throw (New-McpProtocolError -Code -32600 -Message "Invalid Request" -Data "method is required.")
    }
}

function Test-McpToolCallParams {
    [CmdletBinding()]
    param(
        $ParamsObject
    )

    $name = Get-ObjectPropertyValue -Object $ParamsObject -PropertyName "name"
    if ([string]::IsNullOrWhiteSpace($name)) {
        return New-McpToolErrorPayload -Message "Missing required parameter: name"
    }

    return $null
}

Export-ModuleMember -Function Get-ObjectPropertyValue, Test-McpRequestShape, Test-McpToolCallParams
