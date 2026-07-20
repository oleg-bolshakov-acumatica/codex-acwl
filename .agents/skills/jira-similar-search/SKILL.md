---
name: jira-similar-search
description: Use this skill when the user wants to find similar Bug or SupportRequest issues in Jira. In this light workspace similarity is agent-driven JQL search through the corporate jira-internal HTTP MCP server, ranked locally by the agent.
---

# Jira Similar Search Skill

## Purpose and Access

Find likely similar Jira items when explicit context does not establish root cause, workaround, or fix lineage. This skill is read-only.

Use `jira-internal` `jira_search` with narrow task-specific JQL, then rank candidates locally. There is no server-side similarity planner and no Jira search tool in `powershell-mcp-facade`. Do not use REST, provider modules, browser access, or ad hoc scripts. Read-only searches need no extra confirmation.

## Workflow

1. Retrieve the source issue with `jira-access`.
2. Extract strong signals: exact UI/error text, exception/stack fragments, screen ids, mentioned Jira keys, table/field/process/code terms, components, labels, and relevant versions.
3. Build narrow JQL over likely `Bug` and `Support Request` items. Exclude the source key, use exact phrases/internal identifiers first, and request only fields needed for ranking.
4. Run `jira_search` and rank locally: exact phrase > explicit key or screen id > narrow technical/domain terms > component/label. Down-rank broad structural words.
5. If results are noisy or empty, refine the exact phrase, add/remove one supporting constraint, or suppress known false positives. Do not broaden indiscriminately.
6. Open only the most relevant candidates separately through `jira-access`.
7. For strong resolved/closed/awaiting-fix Support Request candidates, inspect linked fixing Bugs through `related-items-analysis` before using them as resolved prior evidence.
8. Treat similarity as supporting context, never automatic proof of a duplicate or common root cause.

## Search Heuristics

- Prefer exact user-facing messages, exception fragments, stack signatures, screen ids, Jira keys, table/field names, and precise business-rule phrases.
- Avoid broad or structural words as the primary filter, including `error`, `issue`, `screen`, `cannot`, `exception`, `related`, `description`, `project`, `from`, and `keys`.
- Use components and labels only as supporting constraints.
- Include resolved issues when looking for fixes, workarounds, or prior diagnosis; restrict to active items when only open candidates are useful.
- A linked fixing Bug is better evidence for reproduction, fixed builds, branch, and regression boundary than Support Request status alone.

## Output and Failure Handling

Return a concise shortlist, normally 3-5 items, with issue key, summary, and relevance. Open only the most relevant 1-3 candidates for deeper review. Mention search attempts only when they explain coverage, a retry, or a no-result conclusion.

If `jira-internal` search is unavailable or insufficient, report the missing coverage and its effect. Do not bypass the approved path.
