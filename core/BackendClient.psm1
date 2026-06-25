Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "Config.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Logging.psm1") -Force

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

function Get-McpBackendClientSettings {
    [CmdletBinding()]
    param()

    $config = Get-McpServerConfig
    $backend = Get-ObjectPropertyValue -Object $config -PropertyName "backend"

    if ($null -eq $backend) {
        return [ordered]@{
            mode = "inProcess"
            allowInProcessFallback = $true
            http = [ordered]@{
                baseUrl = "http://127.0.0.1:8765"
                requestTimeoutSec = 45
            }
        }
    }

    $http = Get-ObjectPropertyValue -Object $backend -PropertyName "http"

    return [ordered]@{
        mode = [string](Get-ObjectPropertyValue -Object $backend -PropertyName "mode" -DefaultValue "inProcess")
        allowInProcessFallback = [bool](Get-ObjectPropertyValue -Object $backend -PropertyName "allowInProcessFallback" -DefaultValue $false)
        http = [ordered]@{
            baseUrl = [string](Get-ObjectPropertyValue -Object $http -PropertyName "baseUrl" -DefaultValue "http://127.0.0.1:8765")
            requestTimeoutSec = [int](Get-ObjectPropertyValue -Object $http -PropertyName "requestTimeoutSec" -DefaultValue 45)
        }
    }
}

function New-BackendRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Operation,
        $Arguments
    )

    return [ordered]@{
        requestId = [guid]::NewGuid().ToString()
        operation = $Operation
        arguments = if ($null -eq $Arguments) { [ordered]@{} } else { $Arguments }
    }
}

function New-BackendError {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [string]$Code = "backend_unavailable",
        $Details = $null
    )

    $errorPayload = [ordered]@{
        ok = $false
        error = [ordered]@{
            code = $Code
            message = $Message
            source = "resource_proxy"
        }
    }

    if ($null -ne $Details) {
        $errorPayload.error.details = $Details
    }

    return $errorPayload
}

function Invoke-HttpBackendRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Request,
        [Parameter(Mandatory)] [string]$BaseUrl,
        [Parameter(Mandatory)] [int]$RequestTimeoutSec
    )

    try {
        $invokeUrl = "{0}/invoke" -f $BaseUrl.TrimEnd("/")
        $body = $Request | ConvertTo-Json -Depth 20 -Compress
        $response = Invoke-RestMethod `
            -Uri $invokeUrl `
            -Method Post `
            -ContentType "application/json" `
            -Body $body `
            -TimeoutSec $RequestTimeoutSec `
            -ErrorAction Stop

        if ($null -eq $response) {
            return New-BackendError -Message "Resource proxy returned an empty response." -Code "empty_response"
        }

        return $response
    }
    catch {
        $details = [ordered]@{ baseUrl = $BaseUrl }
        if ($_.Exception.PSObject.Properties["Response"] -and $null -ne $_.Exception.Response) {
            $details.statusCode = [int]$_.Exception.Response.StatusCode
            return New-BackendError `
                -Message ("Resource proxy HTTP error on '{0}': status={1}" -f $BaseUrl, $details.statusCode) `
                -Code "backend_http_error" `
                -Details $details
        }

        return New-BackendError `
            -Message ("Resource proxy is unavailable on '{0}': {1}" -f $BaseUrl, $_.Exception.Message) `
            -Code "backend_unavailable" `
            -Details $details
    }
}

function Invoke-InProcessBackendRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Request
    )

    $operation = Get-ObjectPropertyValue -Object $Request -PropertyName "operation"
    $arguments = Get-ObjectPropertyValue -Object $Request -PropertyName "arguments" -DefaultValue ([ordered]@{})

    try {
        switch ($operation) {
            "sql.select" {
                Import-Module (Join-Path $PSScriptRoot "..\db-proxy\providers\Sql.Provider.psm1") -Force
                $server = [string](Get-ObjectPropertyValue -Object $arguments -PropertyName "server")
                $schema = [string](Get-ObjectPropertyValue -Object $arguments -PropertyName "schema")
                $query = [string](Get-ObjectPropertyValue -Object $arguments -PropertyName "query")
                $result = Invoke-SqlSelect -Server $server -Schema $schema -Query $query
            }

            "ping" {
                $result = [ordered]@{
                    status = "ok"
                    mode = "inProcess"
                    fallbackMode = $true
                }
            }

            "get_status" {
                $result = [ordered]@{
                    status = "ok"
                    mode = "inProcess"
                    fallbackMode = $true
                    backendAvailable = $true
                    backendVersion = "local-dev"
                }
            }

            default {
                return [ordered]@{
                    ok = $false
                    error = [ordered]@{
                        code = "unknown_operation"
                        message = ("Unknown backend operation: {0}" -f $operation)
                        source = "resource_proxy"
                    }
                }
            }
        }

        return [ordered]@{
            ok = $true
            result = $result
        }
    }
    catch {
        return [ordered]@{
            ok = $false
            error = [ordered]@{
                code = "provider_error"
                message = $_.Exception.Message
                source = "resource_proxy"
            }
        }
    }
}

function Invoke-McpBackendRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Operation,
        $Arguments
    )

    $settings = Get-McpBackendClientSettings
    $request = New-BackendRequest -Operation $Operation -Arguments $Arguments

    switch ($settings.mode) {
        "http" {
            return Invoke-HttpBackendRequest `
                -Request $request `
                -BaseUrl $settings.http.baseUrl `
                -RequestTimeoutSec $settings.http.requestTimeoutSec
        }

        "inProcess" {
            if (-not $settings.allowInProcessFallback) {
                return New-BackendError `
                    -Message "In-process backend mode is disabled. Start the external resource proxy or enable dev/test fallback in config." `
                    -Code "inprocess_disabled" `
                    -Details ([ordered]@{
                        configuredMode = $settings.mode
                        allowInProcessFallback = $settings.allowInProcessFallback
                    })
            }

            Write-McpLog -Level WARN -Message "Using in-process backend mode for dev/test only. Resource proxy bypassed."
            return Invoke-InProcessBackendRequest -Request $request
        }

        default {
            return New-BackendError -Message ("Unsupported backend mode '{0}'." -f $settings.mode) -Code "invalid_backend_mode"
        }
    }
}

function Get-McpBackendStatus {
    [CmdletBinding()]
    param()

    $settings = Get-McpBackendClientSettings
    if ($settings.mode -eq "http") {
        try {
            $statusUrl = "{0}/status" -f $settings.http.baseUrl.TrimEnd("/")
            $response = Invoke-RestMethod -Uri $statusUrl -Method Get -TimeoutSec $settings.http.requestTimeoutSec -ErrorAction Stop
            if ($null -ne $response) {
                return $response
            }
        }
        catch {
            return New-BackendError `
                -Message ("Resource proxy status endpoint is unavailable on '{0}': {1}" -f $settings.http.baseUrl, $_.Exception.Message) `
                -Code "backend_unavailable" `
                -Details ([ordered]@{ baseUrl = $settings.http.baseUrl })
        }
    }

    return Invoke-McpBackendRequest -Operation "get_status" -Arguments ([ordered]@{})
}

Export-ModuleMember -Function Get-McpBackendClientSettings, Invoke-McpBackendRequest, Get-McpBackendStatus
