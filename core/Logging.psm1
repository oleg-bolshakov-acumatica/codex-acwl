Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-McpLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")] [string]$Level,
        [Parameter(Mandatory)] [string]$Message
    )

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    [Console]::Error.WriteLine(("[{0}] [{1}] {2}" -f $timestamp, $Level, $Message))
}

Export-ModuleMember -Function Write-McpLog
