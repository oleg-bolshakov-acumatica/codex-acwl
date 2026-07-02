---
name: jira-access
description: Use this skill when the user asks to retrieve or inspect Jira issue data. In this light workspace Jira is read through the corporate jira-internal HTTP MCP server.
---

# Jira Access Skill

## Purpose

Use this skill when the user wants to retrieve or inspect Jira issue data by issue key.

This skill is for read-only Jira access through the approved `jira-internal` MCP server only. Do not use it for:

- issue updates
- transitions
- comment creation
- workflow changes
- any other write operation

## Access Path

In this light workspace Jira access goes through the corporate `jira-internal` HTTP MCP server. There is no PowerShell-facade Jira tool here; the facade is read-only SQL only.

Call the `jira-internal` `jira_get_issue` tool directly. Do not ask the user for an extra confirmation step for the read-only tool call itself.

Do not bypass the approved MCP path by using Jira REST, importing provider modules, or using ad hoc shell-based Jira access. If `/mcp` does not list `jira-internal` or the tool call fails, treat it as an MCP configuration or authentication issue (the server requires OAuth on first use and the Acumatica corporate network with private access enabled); run `scripts/Check-Mcp.ps1` and report degraded availability rather than bypassing the approved path.

Primary tool call:

```json
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"jira_get_issue","arguments":{"issue_key":"AC-367880","comment_limit":100}}}
```

The primary tool name is:

```text
jira_get_issue
```

Request explicit `fields`, `expand`, and a sufficient `comment_limit` so a single call extracts the most complete possible snapshot for exactly one Jira issue. That single response should include all useful information available for that issue, especially:

- description
- full comment history
- attachments
- labels
- status and resolution data
- linked issue references
- additional issue fields that may help the analysis

For issue analysis, interpret comments in chronological order from the earliest to the latest.

If the response lists related Jira issues, do not recursively expand them inside the same request. Instead, issue additional `jira_get_issue` calls for the linked issue keys that are relevant to the analysis. Treat linked issues as explicit Jira relationships and discovery context, not as a command to expand every linked ticket automatically.

If the root cause or workaround is still unclear after reviewing the issue snapshot, hand off to the `jira-similar-search` skill to find likely similar `Bug` and `SupportRequest` items.

## Pull request / branch discovery

`jira-internal` may expose Jira Development panel data (linked branches, commits, pull requests) through `jira_get_issue` fields/expand, or through development-related fields in the raw issue. When such data is present:

- Extract the branch name(s), commit ids, and repository names.
- Use those branch names with git over the local `code/` repository (see the `local-change-access` skill) to inspect the actual change set. There is no Bitbucket MCP path in this workspace.
- A bare pull-request id/URL alone cannot be resolved here; map it to a branch or commit range in `code/` to inspect the diff.

## Server Coordinates

Jira MCP server:

```text
jira-internal -> https://jmcp.acumatica.com/mcp
```

All project MCP servers are declared at the workspace root in:

```text
.codex/config.toml
```

The internal Jira server uses streamable HTTP and requires OAuth on first use. It is only reachable from the Acumatica corporate network with private access enabled.

## Output Shape

The `jira-internal` response follows the internal Jira MCP tool schema and may be close to raw Jira fields. Request explicit `fields`, `expand`, and sufficient `comment_limit` to retrieve at least:

- key
- summary
- description
- environment
- status / status category
- issue type
- priority
- project
- assignee / reporter / creator
- created / updated / due date
- resolution / resolution date
- labels
- components
- fix versions / affected versions
- parent / subtasks
- attachments
- comments
- linked issues
- development data (branches, commits, pull requests) when exposed

## Notes

- `jira-internal` uses OAuth with the current user's Acumatica identity and inherits normal Jira permissions. Do not use PATs.
- The MCP tool metadata marks `jira_get_issue` and `jira_search` as read-only.
- Prefer a sufficient `comment_limit` for issue analysis; the intended behavior is to retrieve the full comment history for the current issue in a single request.
- Use linked issues as discovery context for follow-up requests, not as a trigger to recursively expand other tickets inside the same response.
- Prefer one full snapshot per issue key, then make explicit follow-up calls only for the most relevant linked issues.
- Prefer one concise status update before the lookup and one concise result summary after the lookup.
- Technical contact: `oleg.bolshakov@acumatica.com`.
