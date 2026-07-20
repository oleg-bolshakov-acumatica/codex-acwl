---
name: migration-script-consistency-review
description: Review Acumatica migration scripts under WebSites/Pure/DB/MSSQL/*.sql for execution-metadata, cross-database, data-integrity, and customer-upgrade risks. Use during PR/spec review when migration SQL changes or interacts with DatabaseModel.sqlproj constraints.
---

# Migration Script Consistency Review Skill

## Purpose

Use this skill to review Acumatica migration scripts for upgrade-safety risks before merge.

The directory name `WebSites/Pure/DB/MSSQL` is historical. Do not assume that scripts in this folder apply only to Microsoft SQL Server. Determine database applicability from script tags such as:

- `--[mssql: Native]`
- `--[mysql: Native]`
- `--[pgsql: Native]`
- `--[mssql: Skip]`
- `--[mysql: Skip]`
- `--[pgsql: Skip]`

This skill is a manual static-analysis checklist. Do not create or run custom helper scripts, Python analyzers, parsers, or generated tooling for this review.

## Scope

Focus on data-migration logic:

- `INSERT`
- `INSERT ... SELECT`
- `UPDATE`
- `DELETE`
- data copy, backfill, remapping, cleanup, deduplication, and defaulting blocks

Treat `ALTER`, `CREATE`, and `DROP` inside migration scripts as a separate suspicious signal. Structure changes are outside the normal migration-script data-processing stage and should be reviewed against the database schema/model flow, not accepted as ordinary migration DML.

## Schema Source

Use the database model as the source of table structure and constraints:

- `DatabaseModel/DatabaseModel.sqlproj`
- table `.sql` files included by that project under `DatabaseModel/**`

When a migration block writes to a table, manually inspect the target table definition and relevant source table definitions. Check columns, nullability, defaults, identity/timestamp behavior, primary keys, unique constraints, foreign keys, and check constraints.

## Workflow

1. Identify changed files under `WebSites/Pure/DB/MSSQL/*.sql`.
2. Split the changed content into migration blocks using nearby `GO` separators and tags such as `MinVersion`, `OldHash`, `IfExists`, `SmartExecute`, and DB-specific `Native`/`Skip` tags.
3. Compare each changed block with the baseline and classify it as new or as a modification of an existing block.
4. For each changed block, identify the database engines to which it applies. Compare parallel `mssql`, `mysql`, and `pgsql` branches when more than one branch is changed.
5. Identify target tables and columns for each `INSERT`, `UPDATE`, and `DELETE`.
6. Open the relevant `DatabaseModel` table files and inspect target constraints manually.
7. Trace each target value back to its source expression. Treat source data as arbitrary valid customer data unless the script itself proves a narrower invariant.
8. Check execution metadata, retry behavior, operational impact, and schema-order assumptions.
9. Report concrete upgrade risks as review findings. If the script may be safe only under an unstated data invariant, mark that as a risk or limitation rather than assuming it.

## Required Checks

For `INSERT INTO target (...) SELECT ...`:

- every target `NOT NULL` column receives a value that is guaranteed non-null;
- nullable source columns are protected with `ISNULL`, `COALESCE`, or a complete `CASE` fallback before reaching non-nullable targets;
- `CASE` expressions that feed non-nullable targets have safe `ELSE` branches;
- `LEFT JOIN` or scalar subqueries cannot produce nulls for required target columns;
- all required target columns without defaults are explicitly populated;
- identity, timestamp, computed, and defaulted columns are handled consistently with the table definition.

For uniqueness and key safety:

- `INSERT` cannot duplicate primary key or unique key values for existing rows;
- source joins cannot multiply rows unexpectedly;
- `DISTINCT` or `GROUP BY` is only accepted when it matches the exact target key semantics;
- anti-duplicate protection uses a correct `NOT EXISTS`, anti-join, or equivalent guard;
- tenant-partitioned tables include `CompanyID` in joins, filters, and duplicate checks when the table schema requires it.

For `UPDATE`:

- assignments to non-nullable, key, unique, foreign-key, and check-constrained columns cannot produce invalid values;
- joins cannot update the same target row ambiguously from multiple source rows;
- DB-specific syntax branches preserve the same business behavior across engines.

For `DELETE`:

- deletion criteria are narrowly scoped and tenant-aware when applicable;
- deletes do not orphan related data or violate expected follow-up inserts/updates;
- cleanup scripts are idempotent or guarded well enough for the intended migration path.

For DB-specific tags:

- do not analyze only the branch matching the directory name;
- check whether changed `mssql`, `mysql`, and `pgsql` branches are equivalent where they should be;
- treat missing or mismatched `Skip`/`Native` coverage as a possible portability or upgrade risk.

For migration metadata:

- distinguish a new block from a modified existing block before evaluating `MinVersion` and `OldHash`;
- for a modified block, preserve the previous `MinVersion.Hash` as `OldHash` only when the current block must be treated as already applied on databases where the previous block ran;
- if databases that ran the previous block still require correction, do not suppress the current work with that `OldHash`; prefer a separate idempotent corrective block with its own execution metadata;
- keep the current `MinVersion` hash aligned with the current block instead of leaving the previous hash as its current identity;
- verify that `IfExists`, `SmartExecute`, and database-specific guards match the intended installation and upgrade paths;
- remember that `OldHash` suppresses execution when its hash is already recorded; it is not a request to rerun the changed block;
- do not treat these tags as substitutes for checking nullability, uniqueness, tenant keys, or referential validity.

For operational safety:

- `INSERT`, `UPDATE`, and `DELETE` blocks are safe to retry or are deliberately protected from duplicate or partial effects;
- destructive changes, narrowing conversions, truncation, overflow, and loss of historical values are prevented or explicitly justified;
- required tables and columns exist at the migration stage where the block runs, including clean installation and supported upgrade paths;
- full-table writes, large joins, and long transactions do not create an unreasonable lock, timeout, or transaction-log risk;
- important migration joins, lookups, and anti-joins are supported by existing keys or indexes when expected data volume makes that necessary; add index findings only with query-path and schema evidence.

## Finding Guidance

Use normal review severities:

- **S0 Blocker**: the script is guaranteed to break upgrade or corrupt data.
- **S1 High**: valid customer data can realistically cause constraint violations, duplicate rows, or failed upgrade.
- **S2 Medium**: meaningful static risk exists but requires additional data evidence to prove impact.
- **S3 Low**: minor maintainability, readability, or guard clarity issue.

In review output, mention that migration scripts were checked and name the changed script files. If no migration scripts changed, state that explicitly in the review limitations or checklist.
