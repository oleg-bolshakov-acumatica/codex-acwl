---
name: jira-access
description: Use this skill when the user asks to retrieve or inspect Jira issue data. In this light workspace Jira is read through the corporate jira-internal HTTP MCP server.
---

# Jira Access Skill

## Purpose and Safety

Retrieve one Jira issue by key through the approved read-only `jira-internal` MCP server. Never update issues, transition workflow state, create comments, or perform any other write.

Call `jira_get_issue` directly without extra user confirmation when credentials are available. Request the fields, expansions, and comment limit needed for a complete task-specific snapshot. There is no Jira tool in `powershell-mcp-facade`; do not substitute REST, provider modules, browser access, or ad hoc scripts.

## Workflow

1. Retrieve one issue with description, full relevant comment history, status/resolution, links, attachments, labels, development data, and other fields that can affect the task.
2. Read comments chronologically.
3. Treat linked issues as discovery context. Open only relevant keys in separate calls; do not recursively expand every link.
4. If cause or workaround remains unclear, use `jira-similar-search`.

Use the live MCP schema rather than duplicating its field catalog. Confirm that the response contains the context the current task needs; make a focused follow-up read when it does not.

## Development Data

When Jira Development data exposes branches, commits, PR identifiers, targets, or states:

- extract the branch names, commit ids, repository, target, and state that matter;
- map a bare PR id/URL to its branch or commit range through this data;
- use `local-change-access` to inspect the resolved change set over the local `code/` repository;
- do not claim delivery from an open or declined PR.

If Jira does not map a bare PR to a branch/range, ask for that branch/range rather than guessing or using provider-specific PR refs.

## Failure Handling

If `jira-internal` is unavailable or incomplete, report the missing context and its effect on confidence. Treat absence from `/mcp`, OAuth failure, or network failure as MCP configuration/authentication/private-network availability issues. Run `scripts/Check-Mcp.ps1` when useful; do not bypass the approved path.
