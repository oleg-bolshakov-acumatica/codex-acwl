[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$sqlModule = Import-Module (Join-Path $projectRoot "db-proxy/providers/Sql.Provider.psm1") -Force -PassThru

$safetyCases = @(
    @{ name = "simple"; query = "SELECT 1;"; valid = $true },
    @{ name = "literal-keyword"; query = "SELECT 'update; into';"; valid = $true },
    @{ name = "comment-keyword"; query = "SELECT 1 /* DROP TABLE X */;"; valid = $true },
    @{ name = "select-into"; query = "SELECT * INTO Copy FROM Source"; valid = $false },
    @{ name = "multiple-statements"; query = "SELECT 1; SELECT 2"; valid = $false },
    @{ name = "write-statement"; query = "UPDATE T SET C = 1"; valid = $false },
    @{ name = "unterminated-string"; query = "SELECT 'x"; valid = $false }
)

$safetyResults = foreach ($case in $safetyCases) {
    $actualValid = $true
    $errorText = $null
    try { & $sqlModule { param($query) Test-SqlSelectSafety -Query $query } $case.query }
    catch { $actualValid = $false; $errorText = $_.Exception.Message }
    [ordered]@{ name = $case.name; expectedValid = $case.valid; actualValid = $actualValid; passed = ($case.valid -eq $actualValid); error = $errorText }
}

$parameterCheck = & $sqlModule {
    $connection = New-Object System.Data.SqlClient.SqlConnection
    $command = $connection.CreateCommand()
    try {
        Add-SqlCommandParameters -Command $command -Parameters @{ projectId = 42; documentDate = [datetime]"2026-08-17"; nullableCompany = @{ value = $null; sqlType = "Int" } }
        return [ordered]@{
            count = $command.Parameters.Count
            projectIdType = $command.Parameters["@projectId"].SqlDbType.ToString()
            documentDateType = $command.Parameters["@documentDate"].SqlDbType.ToString()
            nullableCompanyType = $command.Parameters["@nullableCompany"].SqlDbType.ToString()
            nullableCompanyIsDbNull = ($command.Parameters["@nullableCompany"].Value -is [DBNull])
        }
    }
    finally { $command.Dispose(); $connection.Dispose() }
}

$settingsCheck = & $sqlModule {
    $settings = Resolve-SqlProviderSettings
    Test-ValueMatchesAllowedPatterns -Value "arbitrary-sql-host" -Patterns $settings.AllowedServerPatterns -ValueName "SQL server"
    Test-ValueMatchesAllowedPatterns -Value "arbitrary_database" -Patterns $settings.AllowedDatabasePatterns -ValueName "SQL database"
    return [ordered]@{ serverPatternCount = @($settings.AllowedServerPatterns).Count; databasePatternCount = @($settings.AllowedDatabasePatterns).Count }
}

$result = [ordered]@{
    safety = @($safetyResults)
    parameters = $parameterCheck
    unrestrictedAllowLists = $settingsCheck
}
$result | ConvertTo-Json -Depth 8

if (@($safetyResults | Where-Object { -not $_.passed }).Count -gt 0 -or $parameterCheck.count -ne 3 -or $parameterCheck.projectIdType -ne "Int" -or $parameterCheck.documentDateType -ne "DateTime2" -or $parameterCheck.nullableCompanyType -ne "Int" -or -not $parameterCheck.nullableCompanyIsDbNull -or $settingsCheck.serverPatternCount -ne 0 -or $settingsCheck.databasePatternCount -ne 0) {
    throw "SQL provider regression checks failed."
}
