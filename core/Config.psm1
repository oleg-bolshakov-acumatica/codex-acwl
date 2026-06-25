Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-Hashtable {
    param(
        [Parameter(Mandatory)] $InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = @{}
        foreach ($key in $InputObject.Keys) {
            $result[$key] = ConvertTo-Hashtable -InputObject $InputObject[$key]
        }

        return $result
    }

    if (($InputObject -is [System.Collections.IEnumerable]) -and ($InputObject -isnot [string])) {
        $items = @()
        foreach ($item in $InputObject) {
            $items += ,(ConvertTo-Hashtable -InputObject $item)
        }

        return $items
    }

    if ($InputObject -is [psobject]) {
        $properties = $InputObject.PSObject.Properties
        $hasProperties = $false
        foreach ($property in $properties) {
            $hasProperties = $true
            break
        }

        if ($hasProperties) {
            $result = @{}
            foreach ($property in $properties) {
                $result[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
            }

            return $result
        }
    }

    return $InputObject
}

function Get-McpServerConfig {
    [CmdletBinding()]
    param(
        [string]$Path = (Join-Path (Split-Path -Parent $PSScriptRoot) "config/server.config.json")
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Server configuration file was not found: $Path"
    }

    $configObject = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    $config = ConvertTo-Hashtable -InputObject $configObject
    if ($null -eq $config) {
        throw "Server configuration file is empty: $Path"
    }

    return $config
}

Export-ModuleMember -Function Get-McpServerConfig
