[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Url,

    [int]$TimeoutSec = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sessionId = $null

function Write-ProxyError {
    param([Parameter(Mandatory = $true)][string]$Message)
    [Console]::Error.WriteLine("[streamable-http-mcp-proxy] $Message")
}

function ConvertFrom-SseContent {
    param([AllowEmptyString()][string]$Content)

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return @()
    }

    $messages = New-Object System.Collections.Generic.List[string]
    $dataLines = New-Object System.Collections.Generic.List[string]

    foreach ($line in ($Content -split "\r?\n")) {
        if ($line.StartsWith("data:")) {
            $dataLines.Add($line.Substring(5).TrimStart())
            continue
        }

        if ($line.Length -eq 0 -and $dataLines.Count -gt 0) {
            $messages.Add(($dataLines -join [Environment]::NewLine))
            $dataLines.Clear()
        }
    }

    if ($dataLines.Count -gt 0) {
        $messages.Add(($dataLines -join [Environment]::NewLine))
    }

    return @($messages)
}

function Get-RequestId {
    param([Parameter(Mandatory = $true)][string]$JsonLine)

    try {
        $request = $JsonLine | ConvertFrom-Json
        if ($request.PSObject.Properties.Name -contains "id") {
            return $request.id
        }
    }
    catch {
        return $null
    }

    return $null
}

function Write-JsonRpcError {
    param(
        $Id,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if ($null -eq $Id) {
        return
    }

    $errorResponse = [ordered]@{
        jsonrpc = "2.0"
        id = $Id
        error = [ordered]@{
            code = -32000
            message = $Message
        }
    }

    [Console]::Out.WriteLine(($errorResponse | ConvertTo-Json -Compress -Depth 20))
    [Console]::Out.Flush()
}

function Invoke-RemoteMcp {
    param([Parameter(Mandatory = $true)][string]$JsonLine)

    $headers = @{
        Accept = "application/json, text/event-stream"
    }

    if (-not [string]::IsNullOrWhiteSpace($script:sessionId)) {
        $headers["Mcp-Session-Id"] = $script:sessionId
    }

    $response = Invoke-WebRequest `
        -Uri $Url `
        -Method Post `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $JsonLine `
        -TimeoutSec $TimeoutSec `
        -UseBasicParsing

    $responseSessionId = $response.Headers["Mcp-Session-Id"]
    if ([string]::IsNullOrWhiteSpace($responseSessionId)) {
        $responseSessionId = $response.Headers["mcp-session-id"]
    }
    if (-not [string]::IsNullOrWhiteSpace($responseSessionId)) {
        $script:sessionId = [string]$responseSessionId
    }

    foreach ($message in (ConvertFrom-SseContent -Content $response.Content)) {
        if ([string]::IsNullOrWhiteSpace($message)) {
            continue
        }

        [Console]::Out.WriteLine($message)
        [Console]::Out.Flush()
    }
}

while ($true) {
    $line = [Console]::In.ReadLine()
    if ($null -eq $line) {
        break
    }

    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }

    try {
        Invoke-RemoteMcp -JsonLine $line
    }
    catch {
        $message = $_.Exception.Message
        Write-ProxyError $message
        Write-JsonRpcError -Id (Get-RequestId -JsonLine $line) -Message $message
    }
}
