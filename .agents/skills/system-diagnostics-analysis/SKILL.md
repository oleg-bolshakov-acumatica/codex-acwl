---
name: system-diagnostics-analysis
description: Run targeted Acumatica system diagnostics when version/build, customization, upgrade chronology, schema, or source-branch context can change the cause, workaround, branch choice, or confidence. Use read-only database checks and local source/schema evidence.
---

# System Diagnostics Analysis Skill

## Purpose

Use this skill for system-level diagnostics that explain the environment around a support issue.

This skill covers version/build interpretation, source-branch derivation, customization package checks, upgrade chronology, and schema discovery. It complements `database-root-cause-analysis`; it should run only when these diagnostics can change the conclusion or confidence.

Keep this skill separate from `docs/DATABASE_MODEL.md`. `DATABASE_MODEL.md` describes Projects/Construction application entities, relationships, document flows, and domain-specific tables. This skill describes environment, version, customization, upgrade, source-branch, and schema-discovery checks.

Use local docs, source `DatabaseModel`, and database metadata checks when DAC/schema or Help Wiki facts can reduce ambiguity. Treat the current backup metadata and version-specific source `DatabaseModel` as high-confidence evidence for exact system table shape.

## Trigger Point

Run this skill when any of the following can materially affect the answer:

- source-code branch selection depends on Jira/DB version;
- Jira `Found in` and DB version may differ;
- custom screens, graph/DAC extensions, workflows, imports/exports, reports, or DB objects could affect the scenario;
- upgrade timing could explain when records became invalid;
- table/column existence varies by version or customization;
- root cause classification depends on standard product vs customization vs upgrade/data chronology.

Skip it when diagnostics cannot change the conclusion, such as a fully confirmed current-case data issue with no customization/timing/version dependency.

## Access And References

Use `database-access` for read-only SQL.
Do not bypass MCP with direct SQL clients or provider modules.

Only use `SELECT` statements. Do not run jobs, procedures, functions, or state-changing SQL.

## Version And Branch Diagnostics

When version context matters, check the database version:

```sql
SELECT DatabaseID, ComponentName, ComponentType, [Version], [Date], Hash, Altered
FROM [Version]
ORDER BY ComponentType, ComponentName;
```

Interpret Jira `Found in` and DB versions:

- `YY.RRR.xxxx-n` has base `YY.RRR.xxxx` and patch suffix `n`;
- DB version often stores only the base;
- record the Jira patch suffix separately when it exists;
- matching base versions are compatible for support analysis;
- mismatches must be reported.

Derive source branch:

```text
YY.RRR.xxxx or YY.RRR.xxxx-n -> 20YYrRRR
```

Example:

```text
25.201.0213-2 -> 2025r201
```

Use DB version for backup-specific source-code analysis when Jira and DB versions differ.

## Customization Diagnostics

Run customization checks when the issue could be affected by custom:

- screens;
- graph or DAC extensions;
- workflows;
- import/export scenarios;
- reports;
- GI/screens;
- database objects;
- custom package files touching the suspected process.

Start by discovering available customization tables:

```sql
SELECT t.name
FROM sys.tables t
WHERE t.name LIKE 'Customization%'
   OR t.name LIKE 'Cust%'
ORDER BY t.name;
```

Then inspect columns for only the tables that exist:

```sql
SELECT t.name AS table_name, c.name AS column_name, ty.name AS system_type_name, c.max_length, c.is_nullable
FROM sys.columns c
JOIN sys.tables t ON t.object_id = c.object_id
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
WHERE t.name IN ('CustProject', 'CustObject', 'CustomizationStorage', 'CustomizationPublished', 'CustomizationDesign', 'CustProjectRevision', 'CustAzureStorage')
ORDER BY t.name, c.column_id;
```

Common customization-related tables vary by version and backup state. Examples include:

- `CustProject` and `CustObject` in the product `DatabaseModel`;
- `CustomizationStorage`, `CustPublishideScripts`, and `SMCustomizationPublishProgress` in some versions;
- `CustomizationDesign`, `CustomizationPublished`, `CustProjectRevision`, and `CustAzureStorage` when present in the backup.

Inspect only existing tables. If a table contains `CompanyID`, apply tenant/company scope before treating rows as relevant. For example:

```sql
SELECT CompanyID, ProjID, Name, IsWorking, DevelopedBy, CreatedDateTime, LastModifiedDateTime
FROM CustProject
ORDER BY CompanyID, Name;
```

```sql
SELECT *
FROM CustObject
ORDER BY CompanyID, Name;
```

Look for package names, publication state, publish/modified timestamps, file names, screen IDs, graph/DAC names, workflow names, reports, SQL objects, and import/export objects that overlap the suspected scenario.

Interpretation:

- custom package directly touching the screen/graph/DAC/process is a potential root-cause contributor;
- custom package unrelated to the affected path should be ruled out explicitly;
- customizations can weaken confidence in standard-product code conclusions unless shown unrelated.
- customization metadata table names and columns are version-specific; prefer discovered backup metadata over remembered table names.

## Upgrade Chronology Diagnostics

Run upgrade chronology checks when timing matters:

- issue started after upgrade;
- affected records may predate current build;
- data could have been created before a fix or migration;
- current version differs from record creation/modification timing.

Starting queries:

```sql
SELECT *
FROM UPHistory;
```

```sql
SELECT *
FROM UPHistoryComponents;
```

Compare upgrade timestamps with affected records:

- `CreatedDateTime`;
- `LastModifiedDateTime`;
- `Created*` fields;
- `LastModified*` fields;
- release/posting dates where business timing matters.

Interpret whether the data/configuration:

- existed before the upgrade;
- was created after upgrade;
- was modified during/after upgrade;
- spans multiple version periods.

Do not infer causation from timing alone. Treat chronology as support for or against a hypothesis.

## Schema Discovery

Use schema discovery when:

- docs do not mention a table/column;
- version-specific schema matters;
- a suspected table may be absent in the backup;
- customization may have added columns/tables.

When the suspected object is a standard DAC, check local source for fields and relationships, then confirm version- or tenant-specific shape with SQL metadata when it matters.

Examples:

```sql
SELECT t.name
FROM sys.tables t
WHERE t.name LIKE '%PMTran%' OR t.name LIKE '%Project%'
ORDER BY t.name;
```

```sql
SELECT c.name, ty.name AS system_type_name, c.max_length, c.is_nullable
FROM sys.columns c
JOIN sys.tables t ON t.object_id = c.object_id
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
WHERE t.name = '<TableName>'
ORDER BY c.column_id;
```

For full version-specific schema references during source analysis, use `source-code-analysis` and inspect `DatabaseModel` / `Pure/DatabaseModel` on the derived branch. Do not use schema information from an unrelated branch without reporting the branch mismatch. Treat source `DatabaseModel` as schema reference, not as proof of runtime data state in the customer backup.

## Output Guidance

Report only diagnostics that affect interpretation.

Suggested shape:

```text
Diagnostics checked: version/build, customization, upgrade chronology, schema.
Finding: <specific evidence>.
Impact: supports / weakens / rules out <hypothesis>; changes branch selection to <branch>; or no material effect.
Limitation: <missing table, no tenant, inaccessible backup, version mismatch>.
```

If skipped:

```text
System diagnostics skipped because no customization/version/upgrade/schema factor could change the conclusion.
```

## Confidence Rules

Diagnostics can:

- confirm environment context;
- support customization impact;
- support upgrade chronology hypotheses;
- determine the correct source branch.

Diagnostics alone rarely confirm business root cause unless they directly prove a customization or upgrade changed the affected object/state.
