[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$jsonRpcModule = Import-Module (Join-Path $PSScriptRoot "..\core\JsonRpc.psm1") -Force -PassThru
$lifecycleModule = Import-Module (Join-Path $PSScriptRoot "..\core\Lifecycle.psm1") -Force -PassThru
$loggingModule = Import-Module (Join-Path $PSScriptRoot "..\core\Logging.psm1") -Force -PassThru
$toolRegistryModule = Import-Module (Join-Path $PSScriptRoot "..\core\ToolRegistry.psm1") -Force -PassThru
$resourceRegistryModule = Import-Module (Join-Path $PSScriptRoot "..\core\ResourceRegistry.psm1") -Force -PassThru
$validationModule = Import-Module (Join-Path $PSScriptRoot "..\core\Validation.psm1") -Force -PassThru
$null = Import-Module (Join-Path $PSScriptRoot "..\core\Errors.psm1") -Force -PassThru
$backendClientModule = Import-Module (Join-Path $PSScriptRoot "..\core\BackendClient.psm1") -Force -PassThru

$script:WriteMcpLogCommand = $loggingModule.ExportedCommands["Write-McpLog"]
$script:ConvertFromJsonRpcMessageCommand = $jsonRpcModule.ExportedCommands["ConvertFrom-JsonRpcMessage"]
$script:WriteJsonRpcMessageCommand = $jsonRpcModule.ExportedCommands["Write-JsonRpcMessage"]
$script:NewJsonRpcErrorResponseCommand = $jsonRpcModule.ExportedCommands["New-JsonRpcErrorResponse"]
$script:NewJsonRpcSuccessResponseCommand = $jsonRpcModule.ExportedCommands["New-JsonRpcSuccessResponse"]
$script:NewMcpInitializeResultCommand = $lifecycleModule.ExportedCommands["New-McpInitializeResult"]
$script:GetMcpToolCatalogCommand = $lifecycleModule.ExportedCommands["Get-McpToolCatalog"]
$script:GetMcpResourceCatalogCommand = $lifecycleModule.ExportedCommands["Get-McpResourceCatalog"]
$script:GetMcpResourceTemplateCatalogCommand = $lifecycleModule.ExportedCommands["Get-McpResourceTemplateCatalog"]
$script:TestMcpRequestShapeCommand = $validationModule.ExportedCommands["Test-McpRequestShape"]
$script:GetObjectPropertyValueCommand = $validationModule.ExportedCommands["Get-ObjectPropertyValue"]
$script:TestMcpToolCallParamsCommand = $validationModule.ExportedCommands["Test-McpToolCallParams"]
$script:InvokeMcpToolCallCommand = $toolRegistryModule.ExportedCommands["Invoke-McpToolCall"]
$script:InvokeMcpResourceReadCommand = $resourceRegistryModule.ExportedCommands["Invoke-McpResourceRead"]
$script:GetMcpBackendStatusCommand = $backendClientModule.ExportedCommands["Get-McpBackendStatus"]

function Write-McpLog { param([string]$Level, [string]$Message) & $script:WriteMcpLogCommand -Level $Level -Message $Message }
function ConvertFrom-JsonRpcMessage { param([string]$Line) & $script:ConvertFromJsonRpcMessageCommand -Line $Line }
function Write-JsonRpcMessage { param($Message) & $script:WriteJsonRpcMessageCommand -Message $Message }
function New-JsonRpcErrorResponse { param($Id, [int]$Code, [string]$Message, $Data = $null) & $script:NewJsonRpcErrorResponseCommand -Id $Id -Code $Code -Message $Message -Data $Data }
function New-JsonRpcSuccessResponse { param($Id, $Result) & $script:NewJsonRpcSuccessResponseCommand -Id $Id -Result $Result }
function New-McpInitializeResult { param($ParamsObject = $null) & $script:NewMcpInitializeResultCommand -ParamsObject $ParamsObject }
function Get-McpToolCatalog { param() & $script:GetMcpToolCatalogCommand }
function Get-McpResourceCatalog { param() & $script:GetMcpResourceCatalogCommand }
function Get-McpResourceTemplateCatalog { param() & $script:GetMcpResourceTemplateCatalogCommand }
function Test-McpRequestShape { param($Request) & $script:TestMcpRequestShapeCommand -Request $Request }
function Get-ObjectPropertyValue { param($Object, [string]$PropertyName, $DefaultValue = $null) & $script:GetObjectPropertyValueCommand -Object $Object -PropertyName $PropertyName -DefaultValue $DefaultValue }
function Test-McpToolCallParams { param($ParamsObject) & $script:TestMcpToolCallParamsCommand -ParamsObject $ParamsObject }
function Invoke-McpToolCall { param([string]$ToolName, $Arguments) & $script:InvokeMcpToolCallCommand -ToolName $ToolName -Arguments $Arguments }
function Invoke-McpResourceRead { param([string]$Uri) & $script:InvokeMcpResourceReadCommand -Uri $Uri }
function Get-McpBackendStatus { param() & $script:GetMcpBackendStatusCommand }

$serverState = [ordered]@{
    initialized = $false
    ready = $false
}

function Test-JsonRpcMessageHasId {
    param(
        $Request
    )

    if ($null -eq $Request) {
        return $false
    }

    return ($null -ne $Request.PSObject.Properties["id"])
}

function Get-McpProtocolErrorFromErrorRecord {
    param(
        [Parameter(Mandatory)] $ErrorRecord
    )

    foreach ($candidate in @($ErrorRecord.TargetObject, $ErrorRecord.Exception)) {
        if ($null -eq $candidate) {
            continue
        }

        if ($null -ne $candidate.PSObject.Properties["Code"]) {
            return $candidate
        }

        if ($candidate.Data -and $candidate.Data.Contains("Code")) {
            return [ordered]@{
                Code = [int]$candidate.Data["Code"]
                Message = [string]$candidate.Message
                Data = $candidate.Data["Data"]
            }
        }
    }

    return $null
}

Write-McpLog -Level INFO -Message "MCP stdio server started."

try {
    $backendStatus = Get-McpBackendStatus
    if (-not (Get-ObjectPropertyValue -Object $backendStatus -PropertyName "ok" -DefaultValue $false)) {
        $backendError = Get-ObjectPropertyValue -Object $backendStatus -PropertyName "error"
        $backendMessage = Get-ObjectPropertyValue -Object $backendError -PropertyName "message" -DefaultValue "Backend status check failed."
        Write-McpLog -Level WARN -Message ("Backend unavailable during startup: {0}" -f $backendMessage)
    }
    else {
        $statusResult = Get-ObjectPropertyValue -Object $backendStatus -PropertyName "result"
        $statusMode = Get-ObjectPropertyValue -Object $statusResult -PropertyName "mode" -DefaultValue "unknown"
        $statusVersion = Get-ObjectPropertyValue -Object $statusResult -PropertyName "backendVersion" -DefaultValue "unknown"
        $fallbackMode = [bool](Get-ObjectPropertyValue -Object $statusResult -PropertyName "fallbackMode" -DefaultValue $false)
        $level = if ($fallbackMode) { "WARN" } else { "INFO" }
        Write-McpLog -Level $level -Message ("Backend status: mode={0}; version={1}; fallbackMode={2}" -f $statusMode, $statusVersion, $fallbackMode)
    }
}
catch {
    Write-McpLog -Level WARN -Message ("Backend status check failed during startup: {0}" -f $_.Exception.Message)
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
        $request = ConvertFrom-JsonRpcMessage -Line $line
        Test-McpRequestShape -Request $request
    }
    catch {
        $protocolError = Get-McpProtocolErrorFromErrorRecord -ErrorRecord $_
        if ($null -ne $protocolError) {
            $errorId = $null
            if ($null -ne $request -and (Test-JsonRpcMessageHasId -Request $request)) {
                $errorId = Get-ObjectPropertyValue -Object $request -PropertyName "id"
            }

            Write-JsonRpcMessage -Message (New-JsonRpcErrorResponse -Id $errorId -Code $protocolError.Code -Message $protocolError.Message -Data $protocolError.Data)
        }
        else {
            Write-McpLog -Level ERROR -Message ("Failed to parse JSON-RPC message: {0}" -f $_.Exception.Message)
            Write-JsonRpcMessage -Message (New-JsonRpcErrorResponse -Code -32700 -Message "Parse error")
        }
        continue
    }

    $method = Get-ObjectPropertyValue -Object $request -PropertyName "method"
    $requestId = Get-ObjectPropertyValue -Object $request -PropertyName "id"
    $hasRequestId = Test-JsonRpcMessageHasId -Request $request
    $isNotification = -not $hasRequestId

    try {
        if (-not $serverState.initialized -and $method -notin @("initialize", "ping")) {
            if (-not $isNotification) {
                Write-JsonRpcMessage -Message (New-JsonRpcErrorResponse -Id $requestId -Code -32002 -Message "Server not initialized")
            }
            continue
        }

        switch ($method) {
            "initialize" {
                $paramsObject = Get-ObjectPropertyValue -Object $request -PropertyName "params"
                $serverState.initialized = $true
                $result = New-McpInitializeResult -ParamsObject $paramsObject
                if (-not $isNotification) {
                    Write-JsonRpcMessage -Message (New-JsonRpcSuccessResponse -Id $requestId -Result $result)
                }
            }

            "notifications/initialized" {
                $serverState.ready = $true
                Write-McpLog -Level INFO -Message "Received notifications/initialized."
            }

            "notifications/cancelled" {
                Write-McpLog -Level INFO -Message "Received notifications/cancelled."
            }

            "ping" {
                if (-not $isNotification) {
                    Write-JsonRpcMessage -Message (New-JsonRpcSuccessResponse -Id $requestId -Result ([ordered]@{}))
                }
            }

            "tools/list" {
                $result = [ordered]@{
                    tools = Get-McpToolCatalog
                }
                if (-not $isNotification) {
                    Write-JsonRpcMessage -Message (New-JsonRpcSuccessResponse -Id $requestId -Result $result)
                }
            }

            "resources/list" {
                $result = [ordered]@{
                    resources = Get-McpResourceCatalog
                }
                if (-not $isNotification) {
                    Write-JsonRpcMessage -Message (New-JsonRpcSuccessResponse -Id $requestId -Result $result)
                }
            }

            "resources/templates/list" {
                $result = [ordered]@{
                    resourceTemplates = Get-McpResourceTemplateCatalog
                }
                if (-not $isNotification) {
                    Write-JsonRpcMessage -Message (New-JsonRpcSuccessResponse -Id $requestId -Result $result)
                }
            }

            "resources/read" {
                $paramsObject = Get-ObjectPropertyValue -Object $request -PropertyName "params"
                $uri = Get-ObjectPropertyValue -Object $paramsObject -PropertyName "uri"
                if ([string]::IsNullOrWhiteSpace($uri)) {
                    if (-not $isNotification) {
                        Write-JsonRpcMessage -Message (New-JsonRpcErrorResponse -Id $requestId -Code -32602 -Message "Missing required parameter: uri")
                    }
                }
                else {
                    $result = Invoke-McpResourceRead -Uri $uri
                    if (-not $isNotification) {
                        Write-JsonRpcMessage -Message (New-JsonRpcSuccessResponse -Id $requestId -Result $result)
                    }
                }
            }

            "tools/call" {
                $paramsObject = Get-ObjectPropertyValue -Object $request -PropertyName "params"
                $validationError = Test-McpToolCallParams -ParamsObject $paramsObject

                if ($null -ne $validationError) {
                    $toolResult = [ordered]@{
                        content = @([ordered]@{ type = "text"; text = $validationError.error })
                        structuredContent = $validationError
                        isError = $true
                    }
                }
                else {
                    $toolName = Get-ObjectPropertyValue -Object $paramsObject -PropertyName "name"
                    $arguments = Get-ObjectPropertyValue -Object $paramsObject -PropertyName "arguments"
                    $toolResult = Invoke-McpToolCall -ToolName $toolName -Arguments $arguments
                }

                if (-not $isNotification) {
                    Write-JsonRpcMessage -Message (New-JsonRpcSuccessResponse -Id $requestId -Result $toolResult)
                }
            }

            default {
                if (-not $isNotification) {
                    Write-JsonRpcMessage -Message (New-JsonRpcErrorResponse -Id $requestId -Code -32601 -Message "Method not found")
                }
                else {
                    Write-McpLog -Level DEBUG -Message ("Ignored unknown notification: {0}" -f $method)
                }
            }
        }
    }
    catch {
        Write-McpLog -Level ERROR -Message ("Request failed: method={0}; error={1}" -f $method, $_.Exception.Message)
        if (-not $isNotification) {
            $errorCode = -32603
            $errorMessage = "Internal error"
            if ($method -eq "resources/read") {
                if ($_.Exception.Message -match '^(Missing|Invalid) ') {
                    $errorCode = -32602
                    $errorMessage = $_.Exception.Message
                }
                elseif ($_.Exception.Message -match '^Unknown resource URI') {
                    $errorCode = -32002
                    $errorMessage = $_.Exception.Message
                }
            }

            Write-JsonRpcMessage -Message (New-JsonRpcErrorResponse -Id $requestId -Code $errorCode -Message $errorMessage)
        }
    }
}

Write-McpLog -Level INFO -Message "MCP stdio server stopped."
