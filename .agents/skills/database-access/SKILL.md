---
name: database-access
description: Use this skill when the user asks to retrieve or inspect SQL data through the current PowerShell MCP facade server. Use it for read-only SELECT access only.
---

# Database Access Skill

## Purpose and Safety

Retrieve Microsoft SQL Server data and metadata through `powershell-mcp-facade`. `sql.select` accepts one read-only `SELECT`; never use `INSERT`, `UPDATE`, `DELETE`, `MERGE`, `DROP`, `ALTER`, `TRUNCATE`, `EXEC`, `SELECT INTO`, schema changes, or administrative operations.

Call the SQL tools without extra user confirmation when the current identity has access. The facade is the only approved SQL path; do not substitute provider modules, direct SQL cmdlets, ADO.NET, or ad hoc scripts.

## Discovery Workflow

1. Use `sql.list_databases` when the database is unknown; narrow `namePattern` when possible.
2. Use `sql.search_schema` when table or column names are uncertain.
3. Use `sql.describe_table` before relying on version-specific columns, primary keys, or `COMPANYID` presence.
4. Use `sql.select` for bounded evidence. Pass external values as named `parameters` instead of concatenating them into SQL.

## Query Rules

- Select only fields and rows needed to answer the question.
- Use deterministic filters and avoid broad scans when a narrower query can answer it.
- For tenant-partitioned tables, filter by `COMPANYID` when known.
- If `COMPANYID` is unknown, establish tenant context safely before treating matches as evidence.
- Do not treat cross-tenant matches as confirmation.
- Do not force `COMPANYID` onto shared/service tables that do not contain it.

The facade accepts arbitrary SQL Server/database names subject to the current Windows identity's SQL permissions. Provider allowlists can be configured later; an empty allowlist means unrestricted selection.

## Support Analysis Output

Show the query, summarize the returned rows, and state whether the result supports, weakens, or does not affect the current hypothesis. Keep secrets and unrelated customer data out of the response.

## Failure Handling

If access is unavailable, report the missing server/database/credential context or backend failure and its effect. If the facade is missing or `db-proxy` is unavailable, treat it as MCP/backend availability; run `scripts/Check-Mcp.ps1` when useful. Do not auto-start or bypass the configured path unless the user explicitly requests the startup action.
