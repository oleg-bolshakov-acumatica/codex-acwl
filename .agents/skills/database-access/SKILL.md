---
name: database-access
description: Use this skill when the user asks to retrieve or inspect SQL data through the current PowerShell MCP facade server. Use it for read-only SELECT access only.
---

# Database Access Skill

## Purpose and Safety

Retrieve Microsoft SQL Server data through `powershell-mcp-facade` tool `sql.select`. The query must be one read-only `SELECT`; never use `INSERT`, `UPDATE`, `DELETE`, `MERGE`, `DROP`, `ALTER`, `TRUNCATE`, `EXEC`, schema changes, or administrative operations.

Call `sql.select` without extra user confirmation when the current identity has access. The facade is the only approved SQL path; do not substitute provider modules, direct SQL cmdlets, ADO.NET, or ad hoc scripts.

## Query Rules

- Select only fields and rows needed to answer the question.
- Use deterministic filters and avoid broad scans when a narrower query can answer it.
- For tenant-partitioned tables, filter by `COMPANYID` when known.
- If `COMPANYID` is unknown, establish tenant context safely before treating matches as evidence.
- Do not treat cross-tenant matches as confirmation.
- Do not force `COMPANYID` onto shared/service tables that do not contain it.

When schema details are uncertain, inspect metadata with read-only `SELECT` queries or use version-appropriate local source/docs before querying business data.

## Support Analysis Output

Show the query, summarize the returned rows, and state whether the result supports, weakens, or does not affect the current hypothesis. Keep secrets and unrelated customer data out of the response.

## Failure Handling

If access is unavailable, report the missing server/schema/credential context or backend failure and its effect. If the facade is missing or `db-proxy` is unavailable, treat it as MCP/backend availability; run `scripts/Check-Mcp.ps1` when useful. Do not auto-start or bypass the configured path unless the user explicitly requests the startup action.
