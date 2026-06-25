---
name: database-access
description: Use this skill when the user asks to retrieve or inspect SQL data through the current PowerShell MCP facade server. Use it for read-only SELECT access only.
---

# Database Access Skill

## Purpose

Use this skill when the user wants to retrieve data from Microsoft SQL Server with a read-only `SELECT` query.

This skill is for read-only access through the main MCP server only. Do not use it for:

- `INSERT`
- `UPDATE`
- `DELETE`
- `MERGE`
- `DROP`
- `ALTER`
- `TRUNCATE`
- `EXEC`
- schema changes

## Preferred Access Path

Use the MCP tool exposed by the PowerShell MCP facade server.
For read-only SQL retrieval, call the tool directly when the current Windows identity already has access. Do not ask the user for an extra confirmation step for the `sql.select` tool call itself.
Treat this tool as read-only and safe for automatic approval after the server is trusted.
The `powershell-mcp-facade` server is declared in `.codex-mcp.json` at the workspace root and connected by Codex; call its `sql.select` tool directly.
Do not auto-start `db-proxy` from an analysis workflow unless the user explicitly asks for that action; `scripts/Start-Codex.ps1` owns session startup.
Do not bypass the facade by importing `db-proxy/providers/Sql.Provider.psm1`, calling `Invoke-SqlSelect` directly, or using ad hoc shell-based SQL access when the MCP server for this repository is available.
If `resources/list` or `resources/templates/list` returns empty or incomplete data, continue with MCP `tools/list` and `tools/call` instead of switching to provider modules.
If the repo-local MCP startup contract is present, do not use direct SQL commandlets, ADO.NET snippets, provider modules, or custom shell scripts as a substitute for `sql.select`.

If `/mcp` does not list the facade or the `sql.select` call fails, treat it as an MCP configuration or backend-availability issue: run `scripts/Check-Mcp.ps1` and confirm the db-proxy backend at `127.0.0.1:8765` is running. An unavailable facade is not permission to bypass it.

Preferred tool call:

```json
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"sql.select","arguments":{"server":"bel-sql-009","schema":"case494270","query":"SELECT * FROM COMPANY;"}}}
```

The tool name is:

```text
sql.select
```

## Server Coordinates

All project MCP servers, including the facade, are declared at the workspace root in:

```text
.codex-mcp.json
```

The facade is a `stdio` MCP server (`scripts/Start-McpServer.ps1`, configuration in `config/server.config.json`); its internal facade-to-db-proxy transport uses localhost HTTP, but that is an implementation detail behind the MCP server. Use the facade as the only supported path for SQL reads. Keep commentary short and avoid narrating transport steps unless the user explicitly asks for protocol details.

## Output Shape

The current SQL tool returns:

- `columns`
- `rows`
- `rowCount`

## Tenant Scope Guidance

When the support case belongs to a specific tenant and `COMPANYID` is known, use tenant-scoped filters for tenant-partitioned tables.

Important rules:

- if a table contains `COMPANYID` and is tenant-partitioned, use `COMPANYID` in `WHERE` clauses unless there is a documented reason not to;
- do not treat cross-tenant matches as reliable confirmation of a hypothesis;
- if `COMPANYID` is not known yet, first try to identify the tenant context through safe read-only queries such as `COMPANY`;
- if a table is a shared or service table and does not contain `COMPANYID`, do not force tenant scoping artificially.

The goal is not just to run technically valid SQL, but to produce analytically valid results.
For tenant-partitioned tables, non-scoped queries can create false positives or misleading comparisons.

## Preconditions

Make sure:

- the query is a single `SELECT`
- the selected database is correct

If access is missing, ask only for the missing server, schema, or credential context. Do not ask for permission to perform the read-only query itself.

## User-Facing Output Guidance

When the query is part of support analysis:

- show the SQL query first;
- then show the query result;
- then briefly explain whether the result supports, weakens, or does not affect the current hypothesis.

## Notes

- The current implementation is PowerShell-only.
- The MCP server runs over stdio.
- `db-proxy` should already be running before the MCP facade tries to execute SQL tools. If it is unavailable, report degraded backend availability rather than bypassing the facade.
- The server version is published through MCP `serverInfo.version`.
- The SQL path is intentionally read-only.
- The MCP tool metadata marks `sql.select` as read-only.
- Technical contact: `oleg.bolshakov@acumatica.com`.
- Prefer one concise status update before the query and one concise result summary after the query.
- If execution policy or sandbox restrictions block the declared startup command, request approval for that exact command. This approval is for MCP startup only, not for the read-only `sql.select` tool call itself.
