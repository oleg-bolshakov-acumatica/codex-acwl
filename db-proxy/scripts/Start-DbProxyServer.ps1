[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Light DB proxy: a read-only SQL-only backend for the powershell-mcp-facade.
# It speaks the same HTTP contract the facade expects (POST /invoke with
# {operation, arguments}; GET /status; GET /health) but exposes only the
# sql.select operation. Jira/Wiki/Bitbucket providers are intentionally absent.

Import-Module (Join-Path $PSScriptRoot "..\core\ResourceProxyTransport.psm1") -Force -Global
Import-Module (Join-Path $PSScriptRoot "..\providers\Sql.Provider.psm1") -Force -Global

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

function Write-ResourceProxyLog {
    param(
        [Parameter(Mandatory)] [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")] [string]$Level,
        [Parameter(Mandatory)] [string]$Message
    )

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    [Console]::Error.WriteLine(("[{0}] [{1}] {2}" -f $timestamp, $Level, $Message))
}

function Test-ClientDisconnectException {
    param(
        [Parameter(Mandatory)] [System.Exception]$Exception
    )

    $current = $Exception
    while ($null -ne $current) {
        if ($current -is [System.InvalidOperationException]) {
            if ($current.Message -match "non-connected sockets") {
                return $true
            }
        }

        if ($current -is [System.IO.IOException]) {
            if ($current.Message -match "transport connection" -or $current.Message -match "forcibly closed") {
                return $true
            }
        }

        if ($current -is [System.Net.Sockets.SocketException]) {
            return $true
        }

        $current = $current.InnerException
    }

    return $false
}

function ConvertTo-LogSafeValue {
    param(
        $Value,
        [int]$MaxStringLength = 240
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [string]) {
        $normalized = $Value.Replace("`r`n", " ").Replace("`n", " ").Replace("`r", " ")
        if ($normalized.Length -gt $MaxStringLength) {
            return ("{0}..." -f $normalized.Substring(0, $MaxStringLength))
        }

        return $normalized
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in $Value.Keys) {
            if ($key -match '(?i)(token|password|secret|authorization|cookie)') {
                $result[$key] = "***"
            }
            else {
                $result[$key] = ConvertTo-LogSafeValue -Value $Value[$key] -MaxStringLength $MaxStringLength
            }
        }

        return $result
    }

    if (($Value -is [System.Collections.IEnumerable]) -and ($Value -isnot [string])) {
        $items = @()
        foreach ($item in $Value) {
            $items += ,(ConvertTo-LogSafeValue -Value $item -MaxStringLength $MaxStringLength)
        }

        return $items
    }

    if ($Value -is [psobject]) {
        $properties = $Value.PSObject.Properties
        $hasProperties = $false
        foreach ($property in $properties) {
            $hasProperties = $true
            break
        }

        if ($hasProperties) {
            $result = [ordered]@{}
            foreach ($property in $properties) {
                if ($property.Name -match '(?i)(token|password|secret|authorization|cookie)') {
                    $result[$property.Name] = "***"
                }
                else {
                    $result[$property.Name] = ConvertTo-LogSafeValue -Value $property.Value -MaxStringLength $MaxStringLength
                }
            }

            return $result
        }
    }

    return $Value
}

function ConvertTo-LogJson {
    param(
        $Value
    )

    if ($null -eq $Value) {
        return "null"
    }

    return (ConvertTo-LogSafeValue -Value $Value) | ConvertTo-Json -Depth 12 -Compress
}

function Get-OperationDisplayName {
    param(
        [string]$Operation,
        [string]$Path
    )

    if (-not [string]::IsNullOrWhiteSpace($Operation)) {
        return $Operation
    }

    switch ($Path) {
        "/health" { return "health.check" }
        "/status" { return "server.status" }
        default { return "unknown" }
    }
}

function Get-ResponseSummary {
    param(
        $Response
    )

    if ($null -eq $Response) {
        return [ordered]@{ summary = "null" }
    }

    $ok = [bool](Get-ObjectPropertyValue -Object $Response -PropertyName "ok" -DefaultValue $false)
    if (-not $ok) {
        $errorPayload = Get-ObjectPropertyValue -Object $Response -PropertyName "error"
        return [ordered]@{
            ok = $false
            code = [string](Get-ObjectPropertyValue -Object $errorPayload -PropertyName "code")
            message = [string](Get-ObjectPropertyValue -Object $errorPayload -PropertyName "message")
        }
    }

    $result = Get-ObjectPropertyValue -Object $Response -PropertyName "result"

    $rowCount = Get-ObjectPropertyValue -Object $result -PropertyName "rowCount"
    if ($null -ne $rowCount) {
        $columns = @(Get-ObjectPropertyValue -Object $result -PropertyName "columns" -DefaultValue @())
        return [ordered]@{
            ok = $true
            rowCount = [int]$rowCount
            columnCount = $columns.Count
        }
    }

    $status = Get-ObjectPropertyValue -Object $result -PropertyName "status"
    if (-not [string]::IsNullOrWhiteSpace([string]$status)) {
        return [ordered]@{
            ok = $true
            status = [string]$status
            mode = [string](Get-ObjectPropertyValue -Object $result -PropertyName "mode")
            backendVersion = [string](Get-ObjectPropertyValue -Object $result -PropertyName "backendVersion")
        }
    }

    return [ordered]@{ ok = $true }
}

function Write-RequestStartedLog {
    param(
        [Parameter(Mandatory)] [string]$HttpMethod,
        [Parameter(Mandatory)] [string]$Path,
        [string]$Operation,
        $Arguments
    )

    $skill = Get-OperationDisplayName -Operation $Operation -Path $Path
    $parametersJson = ConvertTo-LogJson -Value $(if ($null -eq $Arguments) { [ordered]@{} } else { $Arguments })
    Write-ResourceProxyLog -Level INFO -Message ("request started: method={0}; path={1}; skill={2}; parameters={3}" -f $HttpMethod, $Path, $skill, $parametersJson)
}

function Write-RequestCompletedLog {
    param(
        [Parameter(Mandatory)] [string]$HttpMethod,
        [Parameter(Mandatory)] [string]$Path,
        [string]$Operation,
        [Parameter(Mandatory)] [int]$StatusCode,
        [Parameter(Mandatory)] [datetime]$StartedAt,
        $Response
    )

    $skill = Get-OperationDisplayName -Operation $Operation -Path $Path
    $durationMs = [int]((Get-Date) - $StartedAt).TotalMilliseconds
    $resultJson = ConvertTo-LogJson -Value (Get-ResponseSummary -Response $Response)
    $status = if ($null -ne $Response -and [bool](Get-ObjectPropertyValue -Object $Response -PropertyName "ok" -DefaultValue $false)) { "ok" } else { "error" }
    $level = if ($StatusCode -ge 400 -or $status -eq "error") { "WARN" } else { "INFO" }
    Write-ResourceProxyLog -Level $level -Message ("request completed: method={0}; path={1}; skill={2}; status={3}; httpStatus={4}; durationMs={5}; result={6}" -f $HttpMethod, $Path, $skill, $status, $StatusCode, $durationMs, $resultJson)
}

function Read-HttpBody {
    param(
        [Parameter(Mandatory)] [System.IO.Stream]$Stream,
        [int]$ContentLength = 0
    )

    if ($ContentLength -le 0) {
        return ""
    }

    $buffer = New-Object byte[] $ContentLength
    $totalBytesRead = 0

    while ($totalBytesRead -lt $ContentLength) {
        $bytesRead = $Stream.Read($buffer, $totalBytesRead, $ContentLength - $totalBytesRead)
        if ($bytesRead -le 0) {
            break
        }

        $totalBytesRead += $bytesRead
    }

    if ($totalBytesRead -lt $ContentLength) {
        throw "Request body ended before the declared Content-Length was read."
    }

    return [System.Text.Encoding]::UTF8.GetString($buffer, 0, $totalBytesRead)
}

function Read-HttpHeaderSection {
    param(
        [Parameter(Mandatory)] [System.IO.Stream]$Stream
    )

    $buffer = New-Object System.Collections.Generic.List[byte]
    $matched = 0
    $terminator = [byte[]](13, 10, 13, 10)

    while ($true) {
        $currentByte = $Stream.ReadByte()
        if ($currentByte -lt 0) {
            if ($buffer.Count -eq 0) {
                return $null
            }

            throw "HTTP request ended before headers were fully read."
        }

        $byteValue = [byte]$currentByte
        $buffer.Add($byteValue)

        if ($byteValue -eq $terminator[$matched]) {
            $matched += 1
            if ($matched -eq $terminator.Length) {
                break
            }
        }
        else {
            $matched = if ($byteValue -eq $terminator[0]) { 1 } else { 0 }
        }
    }

    return [System.Text.Encoding]::ASCII.GetString($buffer.ToArray())
}

function Read-HttpRequest {
    param(
        [Parameter(Mandatory)] [System.Net.Sockets.TcpClient]$Client
    )

    $stream = $Client.GetStream()
    $headerText = Read-HttpHeaderSection -Stream $stream
    if ([string]::IsNullOrWhiteSpace($headerText)) {
        return $null
    }

    $headerLines = $headerText -split "`r`n"
    $requestLine = $headerLines[0]
    if ([string]::IsNullOrWhiteSpace($requestLine)) {
        return $null
    }

    $requestLineParts = $requestLine.Split(" ", 3, [System.StringSplitOptions]::RemoveEmptyEntries)
    if ($requestLineParts.Count -lt 2) {
        throw "Malformed HTTP request line."
    }

    $headers = [ordered]@{}
    foreach ($headerLine in $headerLines | Select-Object -Skip 1) {
        if ([string]::IsNullOrEmpty($headerLine)) {
            continue
        }

        $separatorIndex = $headerLine.IndexOf(":")
        if ($separatorIndex -lt 0) {
            continue
        }

        $headerName = $headerLine.Substring(0, $separatorIndex).Trim()
        $headerValue = $headerLine.Substring($separatorIndex + 1).Trim()
        $headers[$headerName] = $headerValue
    }

    $contentLength = 0
    if ($headers.Contains("Content-Length")) {
        $null = [int]::TryParse([string]$headers["Content-Length"], [ref]$contentLength)
    }

    $body = Read-HttpBody -Stream $stream -ContentLength $contentLength
    $pathAndQuery = [string]$requestLineParts[1]
    $uri = [System.Uri]::new("http://localhost{0}" -f $pathAndQuery)

    return [ordered]@{
        method = [string]$requestLineParts[0]
        rawTarget = $pathAndQuery
        path = $uri.AbsolutePath
        query = $uri.Query
        httpVersion = if ($requestLineParts.Count -ge 3) { [string]$requestLineParts[2] } else { "HTTP/1.1" }
        headers = $headers
        body = $body
    }
}

function Write-HttpResponse {
    param(
        [Parameter(Mandatory)] [System.Net.Sockets.TcpClient]$Client,
        [Parameter(Mandatory)] $Payload,
        [int]$StatusCode = 200,
        [string]$ReasonPhrase = "OK"
    )

    $json = $Payload | ConvertTo-Json -Depth 20 -Compress
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $responseLines = @(
        ("HTTP/1.1 {0} {1}" -f $StatusCode, $ReasonPhrase),
        "Content-Type: application/json; charset=utf-8",
        ("Content-Length: {0}" -f $bodyBytes.Length),
        "Connection: close",
        ""
    )

    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes(($responseLines -join "`r`n") + "`r`n")
    $stream = $Client.GetStream()
    $stream.Write($headerBytes, 0, $headerBytes.Length)
    $stream.Write($bodyBytes, 0, $bodyBytes.Length)
    $stream.Flush()
}

function Try-WriteHttpResponse {
    param(
        [Parameter(Mandatory)] [System.Net.Sockets.TcpClient]$Client,
        [Parameter(Mandatory)] $Payload,
        [int]$StatusCode = 200,
        [string]$ReasonPhrase = "OK",
        [string]$RequestMethod = "",
        [string]$RequestPath = "",
        [string]$FailureContext = "response"
    )

    try {
        Write-HttpResponse -Client $Client -Payload $Payload -StatusCode $StatusCode -ReasonPhrase $ReasonPhrase
        return $true
    }
    catch {
        if (Test-ClientDisconnectException -Exception $_.Exception) {
            $methodText = if ([string]::IsNullOrWhiteSpace($RequestMethod)) { "unknown" } else { $RequestMethod }
            $pathText = if ([string]::IsNullOrWhiteSpace($RequestPath)) { "unknown" } else { $RequestPath }
            Write-ResourceProxyLog -Level WARN -Message ("client disconnected before {0} could be written: method={1}; path={2}; statusCode={3}; detail={4}" -f $FailureContext, $methodText, $pathText, $StatusCode, $_.Exception.Message)
            return $false
        }

        throw
    }
}

function Invoke-ResourceProxyOperation {
    param(
        [Parameter(Mandatory)] [string]$Operation,
        $Arguments
    )

    switch ($Operation) {
        "ping" {
            return [ordered]@{
                ok = $true
                result = [ordered]@{
                    status = "ok"
                    mode = "http"
                    backendAvailable = $true
                }
            }
        }

        "get_status" {
            return [ordered]@{
                ok = $true
                result = [ordered]@{
                    status = "ok"
                    mode = "http"
                    backendAvailable = $true
                    backendVersion = "db-proxy-0.1.0"
                }
            }
        }

        "sql.select" {
            $server = [string](Get-ObjectPropertyValue -Object $Arguments -PropertyName "server")
            $schema = [string](Get-ObjectPropertyValue -Object $Arguments -PropertyName "schema")
            $query = [string](Get-ObjectPropertyValue -Object $Arguments -PropertyName "query")
            $result = Invoke-SqlSelect -Server $server -Schema $schema -Query $query
            return [ordered]@{
                ok = $true
                result = $result
            }
        }

        default {
            return [ordered]@{
                ok = $false
                error = [ordered]@{
                    code = "unknown_operation"
                    message = ("Unknown operation: {0}" -f $Operation)
                    source = "db_proxy"
                }
            }
        }
    }
}

function Resolve-ReasonPhrase {
    param(
        [int]$StatusCode
    )

    switch ($StatusCode) {
        200 { return "OK" }
        400 { return "Bad Request" }
        404 { return "Not Found" }
        405 { return "Method Not Allowed" }
        500 { return "Internal Server Error" }
        default { return "OK" }
    }
}

function Process-ResourceProxyRequest {
    param(
        [Parameter(Mandatory)] $Request,
        [Parameter(Mandatory)] $Settings
    )

    $startedAt = Get-Date
    $path = [string]$Request.path
    if ([string]::IsNullOrWhiteSpace($path)) {
        $path = "/"
    }

    $httpMethod = [string]$Request.method

    switch ($path.TrimEnd("/")) {
        "" {
            $path = "/"
        }

        "/health" {
            $response = [ordered]@{ ok = $true; status = "ok" }
            if ($Settings.logRequests) {
                Write-RequestStartedLog -HttpMethod $httpMethod -Path $path -Arguments ([ordered]@{})
                Write-RequestCompletedLog -HttpMethod $httpMethod -Path $path -StatusCode 200 -StartedAt $startedAt -Response $response
            }

            return [ordered]@{
                statusCode = 200
                payload = $response
            }
        }

        "/status" {
            if ($Settings.logRequests) {
                Write-RequestStartedLog -HttpMethod $httpMethod -Path $path -Operation "get_status" -Arguments ([ordered]@{})
            }

            $response = Invoke-ResourceProxyOperation -Operation "get_status" -Arguments ([ordered]@{})
            if ($Settings.logRequests) {
                Write-RequestCompletedLog -HttpMethod $httpMethod -Path $path -Operation "get_status" -StatusCode 200 -StartedAt $startedAt -Response $response
            }

            return [ordered]@{
                statusCode = 200
                payload = $response
            }
        }

        "/invoke" {
            if ($httpMethod -ne "POST") {
                $response = [ordered]@{
                    ok = $false
                    error = [ordered]@{
                        code = "method_not_allowed"
                        message = "Use POST for /invoke."
                        source = "db_proxy"
                    }
                }

                if ($Settings.logRequests) {
                    Write-RequestStartedLog -HttpMethod $httpMethod -Path $path -Arguments ([ordered]@{})
                    Write-RequestCompletedLog -HttpMethod $httpMethod -Path $path -StatusCode 405 -StartedAt $startedAt -Response $response
                }

                return [ordered]@{
                    statusCode = 405
                    payload = $response
                }
            }

            if ([string]::IsNullOrWhiteSpace($Request.body)) {
                $response = [ordered]@{
                    ok = $false
                    error = [ordered]@{
                        code = "invalid_request"
                        message = "Empty request."
                        source = "db_proxy"
                    }
                }

                if ($Settings.logRequests) {
                    Write-RequestStartedLog -HttpMethod $httpMethod -Path $path -Arguments ([ordered]@{})
                    Write-RequestCompletedLog -HttpMethod $httpMethod -Path $path -StatusCode 400 -StartedAt $startedAt -Response $response
                }

                return [ordered]@{
                    statusCode = 400
                    payload = $response
                }
            }

            $payload = $Request.body | ConvertFrom-Json
            $operation = [string](Get-ObjectPropertyValue -Object $payload -PropertyName "operation")
            $arguments = Get-ObjectPropertyValue -Object $payload -PropertyName "arguments" -DefaultValue ([ordered]@{})

            if ($Settings.logRequests) {
                Write-RequestStartedLog -HttpMethod $httpMethod -Path $path -Operation $operation -Arguments $arguments
            }

            try {
                $response = Invoke-ResourceProxyOperation -Operation $operation -Arguments $arguments
            }
            catch {
                $response = [ordered]@{
                    ok = $false
                    error = [ordered]@{
                        code = "provider_error"
                        message = $_.Exception.Message
                        source = "db_proxy"
                    }
                }
            }

            if ($Settings.logRequests) {
                Write-RequestCompletedLog -HttpMethod $httpMethod -Path $path -Operation $operation -StatusCode 200 -StartedAt $startedAt -Response $response
            }

            return [ordered]@{
                statusCode = 200
                payload = $response
            }
        }

        default {
            $response = [ordered]@{
                ok = $false
                error = [ordered]@{
                    code = "not_found"
                    message = ("Unknown path: {0}" -f $Request.path)
                    source = "db_proxy"
                }
            }

            if ($Settings.logRequests) {
                Write-RequestStartedLog -HttpMethod $httpMethod -Path $path -Arguments ([ordered]@{})
                Write-RequestCompletedLog -HttpMethod $httpMethod -Path $path -StatusCode 404 -StartedAt $startedAt -Response $response
            }

            return [ordered]@{
                statusCode = 404
                payload = $response
            }
        }
    }
}

$settings = Get-ResourceProxySettings
$baseUri = [System.Uri]::new(("{0}/" -f $settings.baseUrl.TrimEnd("/")))
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse($baseUri.Host), $baseUri.Port)
$listener.Start()

Write-ResourceProxyLog -Level INFO -Message ("{0} started on {1}" -f $settings.serverName, $baseUri.AbsoluteUri)

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        $request = $null

        try {
            $request = Read-HttpRequest -Client $client
            if ($null -eq $request) {
                continue
            }

            try {
                $result = Process-ResourceProxyRequest -Request $request -Settings $settings
                $statusCode = [int](Get-ObjectPropertyValue -Object $result -PropertyName "statusCode" -DefaultValue 200)
                $payload = Get-ObjectPropertyValue -Object $result -PropertyName "payload"
                [void](Try-WriteHttpResponse `
                    -Client $client `
                    -Payload $payload `
                    -StatusCode $statusCode `
                    -ReasonPhrase (Resolve-ReasonPhrase -StatusCode $statusCode) `
                    -RequestMethod $request.method `
                    -RequestPath $request.path `
                    -FailureContext "response")
            }
            catch {
                Write-ResourceProxyLog -Level ERROR -Message $_.Exception.Message
                $response = [ordered]@{
                    ok = $false
                    error = [ordered]@{
                        code = "internal_error"
                        message = $_.Exception.Message
                        source = "db_proxy"
                    }
                }
                $requestMethod = ""
                $requestPath = ""
                if ($null -ne $request) {
                    $requestMethod = $request.method
                    $requestPath = $request.path
                }

                [void](Try-WriteHttpResponse `
                    -Client $client `
                    -Payload $response `
                    -StatusCode 500 `
                    -ReasonPhrase (Resolve-ReasonPhrase -StatusCode 500) `
                    -RequestMethod $requestMethod `
                    -RequestPath $requestPath `
                    -FailureContext "error response")
            }
        }
        finally {
            $client.Dispose()
        }
    }
}
finally {
    $listener.Stop()
}
