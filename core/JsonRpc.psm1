Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Web.Extensions

function ConvertTo-JsonSafeValue {
    param(
        $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [string]) {
        $normalized = $Value.Replace("`r`n", "`n").Replace("`r", "`n")
        $normalized = [regex]::Replace($normalized, '[\x00-\x08\x0B\x0C\x0E-\x1F]', ' ')
        return $normalized
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $result[$key] = ConvertTo-JsonSafeValue -Value $Value[$key]
        }

        return $result
    }

    if (($Value -is [System.Collections.IEnumerable]) -and ($Value -isnot [string])) {
        $items = @()
        foreach ($item in $Value) {
            $items += ,(ConvertTo-JsonSafeValue -Value $item)
        }

        return ,$items
    }

    if ($Value -is [psobject]) {
        $properties = @(
            $Value.PSObject.Properties | Where-Object {
                $_.MemberType -in @("NoteProperty", "Property", "AliasProperty", "ScriptProperty")
            }
        )
        $hasProperties = $false
        foreach ($property in $properties) {
            $hasProperties = $true
            break
        }

        if ($hasProperties) {
            $result = [ordered]@{}
            foreach ($property in $properties) {
                if ($property.Value -is [System.Management.Automation.PSMethod] -or
                    $property.Value -is [System.Management.Automation.PSMethodInfo]) {
                    continue
                }

                $result[$property.Name] = ConvertTo-JsonSafeValue -Value $property.Value
            }

            return $result
        }
    }

    return $Value
}

function ConvertFrom-JsonRpcMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Line
    )

    return $Line | ConvertFrom-Json
}

function New-JsonRpcSuccessResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Id,
        [Parameter(Mandatory)] $Result
    )

    return [ordered]@{
        jsonrpc = "2.0"
        id = $Id
        result = $Result
    }
}

function New-JsonRpcErrorResponse {
    [CmdletBinding()]
    param(
        $Id = $null,
        [Parameter(Mandatory)] [int]$Code,
        [Parameter(Mandatory)] [string]$Message,
        $Data = $null
    )

    $errorObject = [ordered]@{
        code = $Code
        message = $Message
    }

    if ($null -ne $Data) {
        $errorObject.data = $Data
    }

    return [ordered]@{
        jsonrpc = "2.0"
        id = $Id
        error = $errorObject
    }
}

function Write-JsonRpcMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Message
    )

    $json = (ConvertTo-JsonSafeValue -Value $Message) | ConvertTo-Json -Depth 32 -Compress
    [Console]::Out.WriteLine($json)
    [Console]::Out.Flush()
}

Export-ModuleMember -Function ConvertFrom-JsonRpcMessage, New-JsonRpcSuccessResponse, New-JsonRpcErrorResponse, Write-JsonRpcMessage
