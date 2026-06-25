Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "..\core\Config.psm1") -Force

function Get-HashtableValue {
    param(
        [hashtable]$Hashtable,
        [string]$Key,
        $DefaultValue = $null
    )

    if ($null -eq $Hashtable -or -not $Hashtable.ContainsKey($Key)) {
        return $DefaultValue
    }

    return $Hashtable[$Key]
}

function Resolve-SqlProviderSettings {
    $config = Get-McpProviderConfig
    $sqlConfig = Get-HashtableValue -Hashtable $config -Key "sql"

    if ($null -eq $sqlConfig) {
        throw "SQL provider configuration is missing."
    }

    return @{
        DefaultServer = [string](Get-HashtableValue -Hashtable $sqlConfig -Key "defaultServer" -DefaultValue "")
        Aliases = [hashtable](Get-HashtableValue -Hashtable $sqlConfig -Key "aliases" -DefaultValue @{})
        TimeoutSec = [int](Get-HashtableValue -Hashtable $sqlConfig -Key "timeoutSec" -DefaultValue 30)
        MaxRows = [int](Get-HashtableValue -Hashtable $sqlConfig -Key "maxRows" -DefaultValue 200)
        MaxCharLength = [int](Get-HashtableValue -Hashtable $sqlConfig -Key "maxCharLength" -DefaultValue 4000)
    }
}

function Resolve-SqlServerName {
    param(
        [string]$Server,
        [Parameter(Mandatory)] [hashtable]$Settings
    )

    if ([string]::IsNullOrWhiteSpace($Server)) {
        return $Settings.DefaultServer
    }

    if ($Settings.Aliases.ContainsKey($Server)) {
        return [string]$Settings.Aliases[$Server]
    }

    return $Server
}

function Test-SqlSelectSafety {
    param(
        [Parameter(Mandatory)] [string]$Query
    )

    $trimmed = $Query.Trim()
    if ($trimmed -notmatch '^(?is)select\b') {
        throw "Only SELECT statements are allowed."
    }

    $withoutTrailingSemicolon = $trimmed -replace ';+\s*$', ''
    if ($withoutTrailingSemicolon -match ';') {
        throw "Multiple SQL statements are not allowed."
    }

    if ($withoutTrailingSemicolon -match '(?is)\b(insert|update|delete|merge|drop|alter|truncate|exec(?:ute)?)\b') {
        throw "Only read-only SELECT statements are allowed."
    }
}

function Convert-SqlValue {
    param(
        $Value
    )

    if ($Value -is [DBNull] -or $null -eq $Value) {
        return $null
    }

    return $Value
}

function Convert-DataRowToHashtable {
    param(
        [Parameter(Mandatory)] $Row,
        [Parameter(Mandatory)] [string[]]$ColumnNames
    )

    $result = [ordered]@{}

    foreach ($columnName in $ColumnNames) {
        $result[$columnName] = Convert-SqlValue -Value $Row.$columnName
    }

    return $result
}

function Get-SqlColumnNames {
    param(
        [Parameter(Mandatory)] $Row
    )

    $excludedNames = @("RowError", "RowState", "Table", "ItemArray", "HasErrors")
    $columnNames = @()

    foreach ($property in $Row.PSObject.Properties) {
        if ($excludedNames -contains $property.Name) {
            continue
        }

        $columnNames += $property.Name
    }

    return $columnNames
}

function Invoke-SqlSelect {
    <#
    .SYNOPSIS
    Executes a read-only SELECT query and returns a structured result.
    #>
    [CmdletBinding()]
    param(
        [string]$Server,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$Schema,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string]$Query
    )

    Test-SqlSelectSafety -Query $Query

    $settings = Resolve-SqlProviderSettings
    $resolvedServer = Resolve-SqlServerName -Server $Server -Settings $settings

    if ([string]::IsNullOrWhiteSpace($resolvedServer)) {
        throw "SQL server was not provided and no default server is configured."
    }

    Import-Module SQLPS -DisableNameChecking -ErrorAction Stop | Out-Null

    $rows = @(Invoke-Sqlcmd `
        -ServerInstance $resolvedServer `
        -Database $Schema `
        -Query $Query `
        -QueryTimeout $settings.TimeoutSec `
        -ConnectionTimeout $settings.TimeoutSec `
        -MaxCharLength $settings.MaxCharLength `
        -ErrorAction Stop)

    [object[]]$limitedRows = @($rows | Select-Object -First $settings.MaxRows)
    [object[]]$columns = if ($limitedRows.Count -gt 0) {
        ,@(Get-SqlColumnNames -Row $limitedRows[0])
    }
    else {
        ,@()
    }
    [object[]]$resultRows = @($limitedRows | ForEach-Object { Convert-DataRowToHashtable -Row $_ -ColumnNames $columns })

    return [ordered]@{
        columns = $columns
        rows = $resultRows
        rowCount = $limitedRows.Count
    }
}

Export-ModuleMember -Function Invoke-SqlSelect
