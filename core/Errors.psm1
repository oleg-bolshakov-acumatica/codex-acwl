Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-McpProtocolError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [int]$Code,
        [Parameter(Mandatory)] [string]$Message,
        $Data = $null
    )

    return [PSCustomObject]@{
        Code = $Code
        Message = $Message
        Data = $Data
    }
}

function New-McpToolErrorPayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Message,
        [string]$Code = "tool_error",
        [string]$Source = "mcp_facade",
        [string]$RecoveryHint = "",
        $Details = $null
    )

    $payload = [ordered]@{
        code = $Code
        error = $Message
        source = $Source
    }

    if (-not [string]::IsNullOrWhiteSpace($RecoveryHint)) {
        $payload.recoveryHint = $RecoveryHint
    }

    if ($null -ne $Details) {
        $payload.details = $Details
    }

    return $payload
}

Export-ModuleMember -Function New-McpProtocolError, New-McpToolErrorPayload
