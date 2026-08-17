Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "..\core\Config.psm1") -Force

function Get-HashtableValue {
    param([hashtable]$Hashtable, [string]$Key, $DefaultValue = $null)

    if ($null -eq $Hashtable -or -not $Hashtable.ContainsKey($Key)) { return $DefaultValue }
    return $Hashtable[$Key]
}

function Get-ObjectPropertyValue {
    param($Object, [Parameter(Mandatory)] [string]$PropertyName, $DefaultValue = $null)

    if ($null -eq $Object) { return $DefaultValue }
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($PropertyName)) { return $Object[$PropertyName] }
        return $DefaultValue
    }

    $property = $Object.PSObject.Properties[$PropertyName]
    if ($null -eq $property) { return $DefaultValue }
    return $property.Value
}

function Resolve-SqlProviderSettings {
    $config = Get-McpProviderConfig
    $sqlConfig = Get-HashtableValue -Hashtable $config -Key "sql"
    if ($null -eq $sqlConfig) { throw "SQL provider configuration is missing." }

    return @{
        DefaultServer = [string](Get-HashtableValue -Hashtable $sqlConfig -Key "defaultServer" -DefaultValue "")
        Aliases = [hashtable](Get-HashtableValue -Hashtable $sqlConfig -Key "aliases" -DefaultValue @{})
        # Empty pattern lists intentionally mean unrestricted access. Database
        # permissions remain enforced by the current Windows identity.
        AllowedServerPatterns = @(Get-HashtableValue -Hashtable $sqlConfig -Key "allowedServerPatterns" -DefaultValue @())
        AllowedDatabasePatterns = @(Get-HashtableValue -Hashtable $sqlConfig -Key "allowedDatabasePatterns" -DefaultValue @())
        TimeoutSec = [int](Get-HashtableValue -Hashtable $sqlConfig -Key "timeoutSec" -DefaultValue 30)
        MaxTimeoutSec = [int](Get-HashtableValue -Hashtable $sqlConfig -Key "maxTimeoutSec" -DefaultValue 45)
        MaxRows = [int](Get-HashtableValue -Hashtable $sqlConfig -Key "maxRows" -DefaultValue 200)
        MaxRequestedRows = [int](Get-HashtableValue -Hashtable $sqlConfig -Key "maxRequestedRows" -DefaultValue 1000)
        MaxCharLength = [int](Get-HashtableValue -Hashtable $sqlConfig -Key "maxCharLength" -DefaultValue 4000)
    }
}

function Resolve-SqlServerName {
    param([string]$Server, [Parameter(Mandatory)] [hashtable]$Settings)

    if ([string]::IsNullOrWhiteSpace($Server)) { return $Settings.DefaultServer }
    if ($Settings.Aliases.ContainsKey($Server)) { return [string]$Settings.Aliases[$Server] }
    return $Server
}

function Test-ValueMatchesAllowedPatterns {
    param([Parameter(Mandatory)] [string]$Value, [object[]]$Patterns, [Parameter(Mandatory)] [string]$ValueName)

    if (@($Patterns).Count -eq 0) { return }
    foreach ($pattern in @($Patterns)) {
        if ($Value -match [string]$pattern) { return }
    }

    throw ("{0} '{1}' is not allowed by provider configuration." -f $ValueName, $Value)
}

function Resolve-SqlExecutionLimits {
    param([Parameter(Mandatory)] [hashtable]$Settings, [int]$MaxRows, [int]$TimeoutSec)

    $resolvedMaxRows = if ($MaxRows -gt 0) { $MaxRows } else { $Settings.MaxRows }
    if ($resolvedMaxRows -le 0 -or $resolvedMaxRows -gt $Settings.MaxRequestedRows) {
        throw ("maxRows must be between 1 and {0}." -f $Settings.MaxRequestedRows)
    }

    $resolvedTimeoutSec = if ($TimeoutSec -gt 0) { $TimeoutSec } else { $Settings.TimeoutSec }
    if ($resolvedTimeoutSec -le 0 -or $resolvedTimeoutSec -gt $Settings.MaxTimeoutSec) {
        throw ("timeoutSec must be between 1 and {0}." -f $Settings.MaxTimeoutSec)
    }

    return [ordered]@{ maxRows = $resolvedMaxRows; timeoutSec = $resolvedTimeoutSec }
}

function ConvertTo-SqlCodeOnlyText {
    param([Parameter(Mandatory)] [string]$Query)

    $builder = New-Object System.Text.StringBuilder
    $state = "code"
    $index = 0
    while ($index -lt $Query.Length) {
        $character = $Query[$index]
        $nextCharacter = if (($index + 1) -lt $Query.Length) { $Query[$index + 1] } else { [char]0 }

        switch ($state) {
            "code" {
                if ($character -eq "'") { [void]$builder.Append(" "); $state = "string" }
                elseif ($character -eq "-" -and $nextCharacter -eq "-") { [void]$builder.Append("  "); $index += 1; $state = "lineComment" }
                elseif ($character -eq "/" -and $nextCharacter -eq "*") { [void]$builder.Append("  "); $index += 1; $state = "blockComment" }
                else { [void]$builder.Append($character) }
            }
            "string" {
                [void]$builder.Append(" ")
                if ($character -eq "'" -and $nextCharacter -eq "'") { [void]$builder.Append(" "); $index += 1 }
                elseif ($character -eq "'") { $state = "code" }
            }
            "lineComment" {
                if ($character -eq "`r" -or $character -eq "`n") { [void]$builder.Append($character); $state = "code" }
                else { [void]$builder.Append(" ") }
            }
            "blockComment" {
                if ($character -eq "*" -and $nextCharacter -eq "/") { [void]$builder.Append("  "); $index += 1; $state = "code" }
                else { [void]$builder.Append($(if ($character -eq "`r" -or $character -eq "`n") { $character } else { " " })) }
            }
        }
        $index += 1
    }

    if ($state -eq "string") { throw "SQL query contains an unterminated string literal." }
    if ($state -eq "blockComment") { throw "SQL query contains an unterminated block comment." }
    return $builder.ToString()
}

function Test-SqlSelectSafety {
    param([Parameter(Mandatory)] [string]$Query)

    $code = (ConvertTo-SqlCodeOnlyText -Query $Query).Trim()
    if ($code -notmatch '^(?is)select\b') { throw "Only SELECT statements are allowed." }

    $withoutTrailingSemicolon = $code -replace ';+\s*$', ''
    if ($withoutTrailingSemicolon -match ';') { throw "Multiple SQL statements are not allowed." }
    if ($withoutTrailingSemicolon -match '(?is)\b(insert|update|delete|merge|drop|alter|truncate|exec(?:ute)?|into|backup|restore|dbcc|kill|grant|revoke|deny|waitfor|use)\b') {
        throw "Only side-effect-free SELECT statements are allowed."
    }
}

function New-SqlConnection {
    param([Parameter(Mandatory)] [string]$Server, [Parameter(Mandatory)] [string]$Database, [Parameter(Mandatory)] [int]$TimeoutSec)

    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder["Data Source"] = $Server
    $builder["Initial Catalog"] = $Database
    $builder["Integrated Security"] = $true
    $builder["Application Name"] = "PowerShell DB Proxy"
    $builder["Connect Timeout"] = $TimeoutSec
    return New-Object System.Data.SqlClient.SqlConnection($builder.ConnectionString)
}

function Get-SqlParameterEntries {
    param($Parameters)

    if ($null -eq $Parameters) { return @() }
    if ($Parameters -is [System.Collections.IDictionary]) {
        return @($Parameters.Keys | ForEach-Object { [ordered]@{ name = [string]$_; value = $Parameters[$_] } })
    }

    return @($Parameters.PSObject.Properties | ForEach-Object { [ordered]@{ name = [string]$_.Name; value = $_.Value } })
}

function Add-SqlCommandParameters {
    param([Parameter(Mandatory)] [System.Data.SqlClient.SqlCommand]$Command, $Parameters)

    $seen = @{}
    foreach ($entry in @(Get-SqlParameterEntries -Parameters $Parameters)) {
        $parameterName = [string]$entry.name
        if (-not $parameterName.StartsWith("@")) { $parameterName = "@$parameterName" }
        if ($parameterName -notmatch '^@[A-Za-z_][A-Za-z0-9_]*$') { throw "Invalid SQL parameter name '$parameterName'." }
        if ($seen.ContainsKey($parameterName)) { throw "Duplicate SQL parameter '$parameterName'." }
        $seen[$parameterName] = $true

        $value = $entry.value
        $declaredSqlType = [string](Get-ObjectPropertyValue -Object $value -PropertyName "sqlType")
        $parameterValue = if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace($declaredSqlType)) { Get-ObjectPropertyValue -Object $value -PropertyName "value" } else { $value }
        if (-not [string]::IsNullOrWhiteSpace($declaredSqlType)) {
            try { $sqlType = [System.Data.SqlDbType]::$declaredSqlType }
            catch { throw "Unsupported sqlType '$declaredSqlType' for parameter '$parameterName'." }
            $parameter = $Command.Parameters.Add($parameterName, $sqlType)
            $size = Get-ObjectPropertyValue -Object $value -PropertyName "size"
            if ($null -ne $size) { $parameter.Size = [int]$size }
            $parameter.Value = if ($null -eq $parameterValue) { [DBNull]::Value } else { $parameterValue }
            continue
        }

        if ($null -eq $parameterValue) { throw "Parameter '$parameterName' with null value must specify sqlType." }
        $parameter = switch ($parameterValue.GetType().FullName) {
            "System.String" { $p = $Command.Parameters.Add($parameterName, [System.Data.SqlDbType]::NVarChar); $p.Size = if ($parameterValue.Length -gt 4000) { -1 } else { [Math]::Max(1, $parameterValue.Length) }; $p }
            "System.Boolean" { $Command.Parameters.Add($parameterName, [System.Data.SqlDbType]::Bit) }
            "System.Byte" { $Command.Parameters.Add($parameterName, [System.Data.SqlDbType]::TinyInt) }
            "System.Int16" { $Command.Parameters.Add($parameterName, [System.Data.SqlDbType]::SmallInt) }
            "System.Int32" { $Command.Parameters.Add($parameterName, [System.Data.SqlDbType]::Int) }
            "System.Int64" { $Command.Parameters.Add($parameterName, [System.Data.SqlDbType]::BigInt) }
            "System.Single" { $Command.Parameters.Add($parameterName, [System.Data.SqlDbType]::Real) }
            "System.Double" { $Command.Parameters.Add($parameterName, [System.Data.SqlDbType]::Float) }
            "System.Decimal" { $Command.Parameters.Add($parameterName, [System.Data.SqlDbType]::Decimal) }
            "System.DateTime" { $Command.Parameters.Add($parameterName, [System.Data.SqlDbType]::DateTime2) }
            "System.DateTimeOffset" { $Command.Parameters.Add($parameterName, [System.Data.SqlDbType]::DateTimeOffset) }
            "System.Guid" { $Command.Parameters.Add($parameterName, [System.Data.SqlDbType]::UniqueIdentifier) }
            "System.Byte[]" { $p = $Command.Parameters.Add($parameterName, [System.Data.SqlDbType]::VarBinary); $p.Size = if ($parameterValue.Length -gt 8000) { -1 } else { [Math]::Max(1, $parameterValue.Length) }; $p }
            default { throw "Unsupported value type '$($parameterValue.GetType().FullName)' for parameter '$parameterName'. Specify sqlType explicitly." }
        }
        $parameter.Value = $parameterValue
    }
}

function Convert-SqlReaderValue {
    param($Value, [Parameter(Mandatory)] [int]$MaxCharLength, [ref]$WasTruncated)

    if ($Value -is [DBNull] -or $null -eq $Value) { return $null }
    if ($Value -is [byte[]]) {
        $encoded = [Convert]::ToBase64String($Value)
        if ($encoded.Length -gt $MaxCharLength) { $WasTruncated.Value = $true; return $encoded.Substring(0, $MaxCharLength) }
        return $encoded
    }
    if ($Value -is [string] -and $Value.Length -gt $MaxCharLength) { $WasTruncated.Value = $true; return $Value.Substring(0, $MaxCharLength) }
    return $Value
}

function Invoke-SqlReaderQuery {
    param(
        [Parameter(Mandatory)] [string]$Server,
        [Parameter(Mandatory)] [string]$Database,
        [Parameter(Mandatory)] [string]$Query,
        $Parameters,
        [Parameter(Mandatory)] [int]$TimeoutSec,
        [Parameter(Mandatory)] [int]$MaxRows,
        [Parameter(Mandatory)] [int]$MaxCharLength
    )

    $connection = New-SqlConnection -Server $Server -Database $Database -TimeoutSec $TimeoutSec
    $command = $null
    $reader = $null
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $Query
        $command.CommandTimeout = $TimeoutSec
        Add-SqlCommandParameters -Command $command -Parameters $Parameters
        $reader = $command.ExecuteReader([System.Data.CommandBehavior]::SequentialAccess)

        $columns = @()
        $columnMetadata = @()
        for ($ordinal = 0; $ordinal -lt $reader.FieldCount; $ordinal++) {
            $columnName = $reader.GetName($ordinal)
            $columns += $columnName
            $columnMetadata += [ordered]@{ name = $columnName; ordinal = $ordinal; sqlType = $reader.GetDataTypeName($ordinal); dotNetType = $reader.GetFieldType($ordinal).FullName }
        }

        $rows = @()
        $resultTruncated = $false
        $truncatedCellCount = 0
        while ($reader.Read()) {
            if ($rows.Count -ge $MaxRows) { $resultTruncated = $true; break }
            $row = [ordered]@{}
            for ($ordinal = 0; $ordinal -lt $reader.FieldCount; $ordinal++) {
                $cellTruncated = $false
                $row[$columns[$ordinal]] = Convert-SqlReaderValue -Value $reader.GetValue($ordinal) -MaxCharLength $MaxCharLength -WasTruncated ([ref]$cellTruncated)
                if ($cellTruncated) { $truncatedCellCount += 1 }
            }
            $rows += ,$row
        }

        $warnings = @()
        if ($resultTruncated) { $warnings += ("Result was truncated at {0} rows." -f $MaxRows) }
        if ($truncatedCellCount -gt 0) { $warnings += ("{0} value(s) were truncated at {1} characters." -f $truncatedCellCount, $MaxCharLength) }
        return [ordered]@{
            server = $Server; database = $Database; columns = @($columns); columnMetadata = @($columnMetadata)
            rows = @($rows); rowCount = $rows.Count; truncated = $resultTruncated; limit = $MaxRows
            truncatedCellCount = $truncatedCellCount; durationMs = [int]$stopwatch.ElapsedMilliseconds; warnings = @($warnings)
        }
    }
    finally {
        if ($null -ne $reader) { $reader.Dispose() }
        if ($null -ne $command) { $command.Dispose() }
        $connection.Dispose()
        $stopwatch.Stop()
    }
}

function Invoke-SqlSelect {
    [CmdletBinding()]
    param(
        [string]$Server,
        [string]$Database,
        [string]$Schema,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$Query,
        $Parameters,
        [int]$MaxRows = 0,
        [int]$TimeoutSec = 0
    )

    Test-SqlSelectSafety -Query $Query
    $settings = Resolve-SqlProviderSettings
    $resolvedServer = Resolve-SqlServerName -Server $Server -Settings $settings
    $resolvedDatabase = if (-not [string]::IsNullOrWhiteSpace($Database)) { $Database } else { $Schema }
    if ([string]::IsNullOrWhiteSpace($resolvedServer)) { throw "SQL server was not provided and no default server is configured." }
    if ([string]::IsNullOrWhiteSpace($resolvedDatabase)) { throw "database is required. The legacy schema argument is also accepted." }

    Test-ValueMatchesAllowedPatterns -Value $resolvedServer -Patterns $settings.AllowedServerPatterns -ValueName "SQL server"
    Test-ValueMatchesAllowedPatterns -Value $resolvedDatabase -Patterns $settings.AllowedDatabasePatterns -ValueName "SQL database"
    $limits = Resolve-SqlExecutionLimits -Settings $settings -MaxRows $MaxRows -TimeoutSec $TimeoutSec
    return Invoke-SqlReaderQuery -Server $resolvedServer -Database $resolvedDatabase -Query $Query -Parameters $Parameters -TimeoutSec $limits.timeoutSec -MaxRows $limits.maxRows -MaxCharLength $settings.MaxCharLength
}

function Get-SqlDatabases {
    [CmdletBinding()]
    param([string]$Server, [string]$NamePattern = "", [int]$MaxResults = 200, [int]$TimeoutSec = 0)

    $settings = Resolve-SqlProviderSettings
    $resolvedServer = Resolve-SqlServerName -Server $Server -Settings $settings
    if ([string]::IsNullOrWhiteSpace($resolvedServer)) { throw "SQL server was not provided and no default server is configured." }
    Test-ValueMatchesAllowedPatterns -Value $resolvedServer -Patterns $settings.AllowedServerPatterns -ValueName "SQL server"
    $limits = Resolve-SqlExecutionLimits -Settings $settings -MaxRows $MaxResults -TimeoutSec $TimeoutSec
    $query = @"
SELECT name, state_desc, user_access_desc, is_read_only, compatibility_level, create_date
FROM sys.databases
WHERE state_desc = 'ONLINE'
  AND HAS_DBACCESS(name) = 1
  AND (@namePattern = '' OR name LIKE @namePattern)
ORDER BY name
"@
    $likePattern = if ([string]::IsNullOrWhiteSpace($NamePattern)) { "" } else { $NamePattern.Replace("*", "%") }
    $raw = Invoke-SqlReaderQuery -Server $resolvedServer -Database "master" -Query $query -Parameters @{ namePattern = $likePattern } -TimeoutSec $limits.timeoutSec -MaxRows $limits.maxRows -MaxCharLength $settings.MaxCharLength
    $databases = @()
    foreach ($row in @($raw.rows)) {
        $databaseName = [string](Get-ObjectPropertyValue -Object $row -PropertyName "name")
        try { Test-ValueMatchesAllowedPatterns -Value $databaseName -Patterns $settings.AllowedDatabasePatterns -ValueName "SQL database"; $databases += ,$row }
        catch { continue }
    }
    return [ordered]@{ server = $resolvedServer; databases = @($databases); databaseCount = $databases.Count; truncated = [bool]$raw.truncated; limit = $limits.maxRows; durationMs = $raw.durationMs; warnings = @($raw.warnings) }
}

function Find-SqlSchemaObjects {
    [CmdletBinding()]
    param(
        [string]$Server,
        [Parameter(Mandatory)] [string]$Database,
        [string]$SchemaName = "",
        [string]$TablePattern = "",
        [string]$ColumnPattern = "",
        [int]$MaxResults = 200,
        [int]$TimeoutSec = 0
    )

    $settings = Resolve-SqlProviderSettings
    $resolvedServer = Resolve-SqlServerName -Server $Server -Settings $settings
    if ([string]::IsNullOrWhiteSpace($resolvedServer)) { throw "SQL server was not provided and no default server is configured." }
    Test-ValueMatchesAllowedPatterns -Value $resolvedServer -Patterns $settings.AllowedServerPatterns -ValueName "SQL server"
    Test-ValueMatchesAllowedPatterns -Value $Database -Patterns $settings.AllowedDatabasePatterns -ValueName "SQL database"
    $limits = Resolve-SqlExecutionLimits -Settings $settings -MaxRows $MaxResults -TimeoutSec $TimeoutSec
    $query = @"
SELECT TABLE_SCHEMA AS schema_name, TABLE_NAME AS table_name, COLUMN_NAME AS column_name,
       ORDINAL_POSITION AS ordinal_position, DATA_TYPE AS data_type,
       CHARACTER_MAXIMUM_LENGTH AS max_length, IS_NULLABLE AS is_nullable
FROM INFORMATION_SCHEMA.COLUMNS
WHERE (@schemaName = '' OR TABLE_SCHEMA = @schemaName)
  AND (@tablePattern = '' OR TABLE_NAME LIKE @tablePattern)
  AND (@columnPattern = '' OR COLUMN_NAME LIKE @columnPattern)
ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION
"@
    $parameters = @{ schemaName = $SchemaName; tablePattern = $(if ([string]::IsNullOrWhiteSpace($TablePattern)) { "" } else { $TablePattern.Replace("*", "%") }); columnPattern = $(if ([string]::IsNullOrWhiteSpace($ColumnPattern)) { "" } else { $ColumnPattern.Replace("*", "%") }) }
    $raw = Invoke-SqlReaderQuery -Server $resolvedServer -Database $Database -Query $query -Parameters $parameters -TimeoutSec $limits.timeoutSec -MaxRows $limits.maxRows -MaxCharLength $settings.MaxCharLength
    return [ordered]@{ server = $resolvedServer; database = $Database; matches = @($raw.rows); matchCount = $raw.rowCount; truncated = $raw.truncated; limit = $raw.limit; durationMs = $raw.durationMs; warnings = @($raw.warnings) }
}

function Get-SqlTableDescription {
    [CmdletBinding()]
    param([string]$Server, [Parameter(Mandatory)] [string]$Database, [string]$SchemaName = "dbo", [Parameter(Mandatory)] [string]$TableName, [int]$TimeoutSec = 0)

    $settings = Resolve-SqlProviderSettings
    $resolvedServer = Resolve-SqlServerName -Server $Server -Settings $settings
    if ([string]::IsNullOrWhiteSpace($resolvedServer)) { throw "SQL server was not provided and no default server is configured." }
    Test-ValueMatchesAllowedPatterns -Value $resolvedServer -Patterns $settings.AllowedServerPatterns -ValueName "SQL server"
    Test-ValueMatchesAllowedPatterns -Value $Database -Patterns $settings.AllowedDatabasePatterns -ValueName "SQL database"
    $limits = Resolve-SqlExecutionLimits -Settings $settings -MaxRows $settings.MaxRows -TimeoutSec $TimeoutSec
    $query = @"
SELECT c.name AS column_name, c.column_id AS ordinal_position, ty.name AS data_type,
       c.max_length, c.precision, c.scale, c.is_nullable, c.is_identity,
       CAST(CASE WHEN pk.column_id IS NULL THEN 0 ELSE 1 END AS bit) AS is_primary_key
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
LEFT JOIN (
    SELECT ic.object_id, ic.column_id
    FROM sys.indexes i
    JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
    WHERE i.is_primary_key = 1
) pk ON pk.object_id = c.object_id AND pk.column_id = c.column_id
WHERE s.name = @schemaName AND t.name = @tableName
ORDER BY c.column_id
"@
    $raw = Invoke-SqlReaderQuery -Server $resolvedServer -Database $Database -Query $query -Parameters @{ schemaName = $SchemaName; tableName = $TableName } -TimeoutSec $limits.timeoutSec -MaxRows $limits.maxRows -MaxCharLength $settings.MaxCharLength
    if ($raw.rowCount -eq 0) { throw ("Table '{0}.{1}' was not found in database '{2}'." -f $SchemaName, $TableName, $Database) }
    $hasCompanyId = @($raw.rows | Where-Object { [string](Get-ObjectPropertyValue -Object $_ -PropertyName "column_name") -ieq "CompanyID" }).Count -gt 0
    return [ordered]@{ server = $resolvedServer; database = $Database; schemaName = $SchemaName; tableName = $TableName; columns = @($raw.rows); columnCount = $raw.rowCount; hasCompanyId = $hasCompanyId; durationMs = $raw.durationMs; warnings = @($raw.warnings) }
}

Export-ModuleMember -Function Invoke-SqlSelect, Get-SqlDatabases, Find-SqlSchemaObjects, Get-SqlTableDescription
