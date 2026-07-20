---
name: database-root-cause-analysis
description: Perform high-level read-only database analysis for Acumatica Support Requests when SQL evidence can confirm, refute, or narrow root-cause hypotheses. Extract environment/version/tenant context, build tenant-scoped SELECT plans, trace document chains, and interpret evidence through database-access.
---

# Database Root-Cause Analysis Skill

## Purpose

Use this skill to turn support-case facts and hypotheses into safe, targeted SQL evidence.

This is a high-level diagnostic workflow. It uses the lower-level `database-access` skill for actual read-only SQL retrieval and relies on `docs/DATABASE_MODEL.md`, local source, and linked Wiki pages when Projects/Construction table relationships, join patterns, or documented behavior matter.

## Trigger Point

Run this skill when:

- the root cause is not confirmed and database evidence can confirm/refute a hypothesis;
- the Jira request asks for a data check, fix confirmation, or customer-backup validation;
- a workaround depends on persisted flags, statuses, setup values, or document links;
- related items suggest a data pattern that must be validated in the current backup.

Skip or keep it minimal when:

- no database/server/schema/tenant context is available and SQL cannot be run;
- Jira/related/code evidence already answers the request and DB evidence cannot change confidence;
- the issue is purely UI/spec/doc discussion with no data-state dependency.

## Access Rules

Use `database-access` for all SQL reads.
Do not use direct SQL clients, provider modules, ad hoc scripts, or direct database connections when the MCP facade path is available.
Do not request approval for read-only SQL needed for diagnosis.

Allowed SQL:

```sql
SELECT ...
```

Do not run or propose executing state-changing SQL as analysis:

```text
UPDATE, DELETE, INSERT, MERGE, TRUNCATE, ALTER, DROP, EXEC, jobs, triggers, procedures, functions
```

Workaround/remediation SQL can be described only as a proposal for human review and execution, never executed by the agent.

## Environment Extraction

Before querying, extract and report the available environment context:

- database server;
- database/schema name;
- backup path;
- URL/site files;
- tenant name;
- `COMPANYID`;
- Jira `Found in` version and patch suffix;
- database `[Version]` when available.

Common Jira/comment patterns:

- server often appears after `was restored to`;
- database often starts with `case...`;
- database can also appear after `DATABASE:`;
- tenant or `COMPANYID` may appear in backup comments, support notes, screenshots, or restored-site details.

Distinguish:

- database availability: server + database are known and accessible;
- tenant-scoped readiness: `COMPANYID` or reliable tenant identification is known;
- version readiness: Jira and/or DB version is known.

If any part is missing, continue with the maximum safe analysis and state the limitation.

## Version Check

When database access is available and version context matters, run:

```sql
SELECT DatabaseID, ComponentName, ComponentType, [Version], [Date], Hash, Altered
FROM [Version]
ORDER BY ComponentType, ComponentName;
```

Interpretation:

- Jira values like `25.201.0213-2` mean base version `25.201.0213` plus patch `2`.
- DB `[Version].[Version]` often stores only the base version.
- Treat Jira and DB versions as matching when base versions match after ignoring the patch suffix.
- Report mismatches explicitly.
- Derive expected source branch for later source analysis as `YY.RRR.xxxx` or `YY.RRR.xxxx-n` -> `20YYrRRR`; for example `25.201.0213-2` -> `2025r201`.

If Jira and DB base versions differ, use the DB version for backup-specific validation and report the inconsistency.

## Tenant Scope

For tenant-partitioned tables, use `COMPANYID` in `WHERE` clauses and joins.

Rules:

- if a table contains `COMPANYID`, include it unless there is a documented reason not to;
- never treat cross-tenant matches as confirmation;
- if `COMPANYID` is unknown, first identify tenant context through safe metadata or `COMPANY` queries;
- do not force tenant scoping onto shared/service tables that do not contain `COMPANYID`.

Example tenant discovery:

```sql
SELECT *
FROM COMPANY
ORDER BY CompanyID;
```

When uncertain whether a table has `COMPANYID`, inspect metadata:

```sql
SELECT c.name
FROM sys.columns c
JOIN sys.tables t ON t.object_id = c.object_id
WHERE t.name = '<TableName>'
ORDER BY c.column_id;
```

## Analysis Workflow

Start from hypotheses, not from broad table browsing.

1. Name the current hypothesis and the fact that would confirm or refute it.
2. Identify primary documents, entities, or setup records from Jira/comments/related items.
3. Use `docs/DATABASE_MODEL.md` for Projects/Construction table relationships, join keys, and process flows when useful.
4. Use local source, metadata queries, local docs, and linked Wiki pages as schema preflight when exact DAC fields, keys, relationships, or documented behavior can reduce guesswork.
5. Query the smallest reliable record set first.
6. Trace related records outward only when each step changes the conclusion.
7. Compare expected vs actual persisted values.
8. If possible, compare with a known-good document or earlier/later related transaction.
9. After every query, state whether the result supports, weakens, refutes, or does not affect the hypothesis.

Show the SQL query first, then summarize the result and interpretation.

## Diagnostic Query Plan

For unresolved root-cause analysis, move from general to specific:

1. Find original and related documents.
2. Find generated GL batch, PM transaction, AP bill, AR document, IN/PO/SO records, or other related records.
3. Validate statuses, boolean flags, setup values, and release/hold/closed/open state.
4. Validate links between original, reversing, reclassified, corrected, or generated transactions.
5. Identify where the value first became incorrect or asymmetric.
6. Compare with a correct case when available.

Useful query types:

- exact document lookup;
- related-record extraction;
- flag/status validation;
- setup value validation;
- document-chain extraction;
- aggregates and reconciliation;
- metadata discovery for table/column existence;
- comparison between original and reversing/reclassified/generated rows.

Avoid `SELECT *` for final evidence. It is acceptable only for tiny exploratory metadata-like tables when column shape is unknown and result size is controlled.

## Projects/Construction Focus

Pay special attention to these relationships and failure patterns:

- AP/AR/GL/PM/IN/PO/SO document chains;
- original vs reversing transaction symmetry;
- reclassification and reversal paths;
- billable/non-billable propagation;
- account group and account-to-account-group mapping;
- project, project task, cost code, inventory item propagation;
- billing pipeline inclusion/exclusion;
- retainage, commitment, pro forma, allocation, and revenue-budget state;
- release-time values vs entry-time defaults;
- feature, setup, branch, and currency context.

For project billing scenarios, verify whether:

- original/reversing PM transactions are asymmetric;
- reversal/reclass PM transactions have incorrect billing flags;
- PM transfer during reclass/reverse is wrong;
- billing exclusion is incorrect;
- net-to-zero logic is broken by related PM transaction state.

## Confirmation Rules

Database evidence can confirm a current-case root cause when it directly proves:

- the affected record has the wrong value/link/status/setup;
- the wrong value is present at the process point identified by the hypothesis;
- related records show the expected asymmetry or missing relationship;
- no competing data/setup explanation remains plausible.

If SQL only shows symptoms but not cause, mark the root cause as **Likely** or **Unclear** and provide the next validation step.

## Inconclusive Or Unavailable SQL

If SQL cannot be run or does not answer the question:

- state what was missing: server, database, tenant, `COMPANYID`, document number, access, table, or reliable hypothesis;
- report the maximum useful findings already obtained;
- provide the next best validation plan;
- consider `source-code-analysis` when standard product logic remains plausible.

## Output Shape

For the support report, include:

```text
Database context: server, database, tenant/COMPANYID, Jira version, DB version, match/mismatch, expected source branch.
SQL checks: query purpose, key result, impact on hypothesis.
Conclusion: confirmed / likely / unclear database finding.
Limitations: missing data, no tenant scope, inaccessible backup, version mismatch, or query not decisive.
```

Keep raw result tables small and focused. Summarize large result sets instead of dumping them.
