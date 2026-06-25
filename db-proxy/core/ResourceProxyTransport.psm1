Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "Config.psm1") -Force

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

function Get-ResourceProxySettings {
    [CmdletBinding()]
    param()

    $config = Get-McpServerConfig
    $resourceProxy = Get-ObjectPropertyValue -Object $config -PropertyName "resourceProxy"
    $http = Get-ObjectPropertyValue -Object $config -PropertyName "http"

    return [ordered]@{
        baseUrl = [string](Get-ObjectPropertyValue -Object $http -PropertyName "baseUrl" -DefaultValue "http://127.0.0.1:8765")
        requestTimeoutSec = [int](Get-ObjectPropertyValue -Object $http -PropertyName "requestTimeoutSec" -DefaultValue 45)
        serverName = [string](Get-ObjectPropertyValue -Object $resourceProxy -PropertyName "serverName" -DefaultValue "PowerShell Resource Proxy Server")
        logRequests = [bool](Get-ObjectPropertyValue -Object $resourceProxy -PropertyName "logRequests" -DefaultValue $true)
    }
}

Export-ModuleMember -Function Get-ResourceProxySettings
