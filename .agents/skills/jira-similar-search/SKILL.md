---
name: jira-similar-search
description: Use this skill when the user wants to find similar Bug or SupportRequest issues in Jira. In this light workspace similarity is agent-driven JQL search through the corporate jira-internal HTTP MCP server, ranked locally by the agent.
---

# Jira Similar Search Skill

## Purpose

Use this skill when the user gives you a Jira issue key and you need to find likely similar Jira items before the root cause is clear.

This skill is read-only and uses the approved `jira-internal` MCP server only.

## Access Path

In this light workspace there is no server-side similarity planner. Similarity search is performed by the agent: derive signals from the source issue, build a narrow JQL query, run it through `jira-internal` `jira_search`, then rank the candidates locally.

Call `jira-internal` `jira_search` directly with your JQL. Do not ask the user for an extra confirmation step for the read-only tool call itself. Do not bypass the approved MCP path with Jira REST, provider modules, or ad hoc shell-based access. If `/mcp` does not list `jira-internal` or the call fails, treat it as an MCP configuration or authentication issue and report degraded availability rather than bypassing the approved path.

JQL search tool call:

```json
{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"jira_search","arguments":{"jql":"project = AC AND issuetype in (Bug, \"Support Request\") AND text ~ \"The document is out of balance\" AND key != AC-371841 AND updated >= \"2025-01-01\"","fields":["summary","status","resolution","fixVersions","components","labels","updated","issuetype"],"limit":25}}}
```

The search tool name is:

```text
jira_search
```

> Verify against the live server: confirm that `jira_search` accepts raw JQL and check its `limit`/pagination parameters and field-selection argument names. Adjust the argument names if the deployed `jira-internal` schema differs.

## Workflow

1. Retrieve the source issue with `jira-access` (`jira_get_issue`).
2. Extract similarity signals from the source issue:
   - exact UI messages, exception fragments, and stack-trace signatures (as quoted phrases);
   - Acumatica screen ids (for example `SO301000`);
   - explicit related issue keys mentioned in the description/comments (for example `AC-294673`);
   - narrow diagnostic nouns: table names, field names, process names, code terms;
   - specific components and labels;
   - issue types to search (normally `Bug` and `Support Request`).
3. Build a narrow JQL query yourself:
   - constrain `project` and `issuetype in (Bug, "Support Request")`;
   - match text with `text ~ "<exact phrase>"` (combine alternatives with `OR`, keep the query narrow);
   - add `component`, `labels` constraints only as supporting narrowing, not as the sole filter;
   - exclude the source issue with `key != <sourceKey>`;
   - add `updated >= "YYYY-MM-DD"` only when older items are unlikely to matter;
   - request only the fields needed for ranking and shortlisting.
4. Run `jira_search` with that JQL.
5. Rank candidates locally by signal overlap (exact-phrase hits > screen id / explicit key > component/label). Down-weight matches driven only by broad/structural words.
6. If the first query is too noisy or too empty, retry with a refined JQL: tighten to the exact error text and internal identifiers, or broaden one signal at a time. Suppress known false positives by adding `AND key not in (...)`.
7. Open the most relevant candidates separately with `jira-access`.
8. For strong resolved/closed/awaiting-fix SupportRequest candidates, inspect linked Bugs through `related-items-analysis` before using the candidate as resolved prior evidence.
9. Use the similar issues as supporting context, not as automatic proof.

## Signal heuristics

- Use exact UI messages, exception fragments, stack-trace signatures, and quoted domain phrases as the strongest `text ~` terms.
- Use explicit related issue keys (for example `AC-294673`) as direct terms when the source issue says it is related to or based on another item.
- Use screen ids when an Acumatica screen id is present.
- Use narrow diagnostic nouns (table names, field names, process names, code terms) as secondary text terms.
- Avoid broad or structural words as the primary filter, including `error`, `issue`, `screen`, `cannot`, `exception`, `related`, `description`, `project`, `from`, and `keys`.
- Use components and labels as narrowing hints, not as proof of relevance. Prefer specific components such as `Projects - Allocation`; broad components such as `Projects` amplify noise unless paired with exact phrases.
- Include comment text in the signal extraction when support discussion contains the best clue.
- Include resolved issues when looking for fixes, workarounds, or prior diagnosis; restrict to active items when only open candidates are useful.
- When a resolved/closed/awaiting-fix candidate looks relevant, treat its linked fixing Bug as the higher-value source for reproduction, fixed builds, branch, and regression boundary. The SupportRequest status alone is not enough to conclude fix availability.

Worked retry examples:

- Report/UI cases: combine the screen id, exact report or UI text, document identifiers, and the narrow component. Example terms: `SC644000`, `Subcontract Audit`, `Bill 07-0001956`, `Construction - Reports`.
- Configuration/error cases: prioritize the exact error message and internal identifiers over module names. Example terms: `Segment is not overridden and cannot be deleted`, `TMCONTRACT`, `TMPROJECT`, `segmentvalue`, `DimensionID`.
- Allocation/accounting calculation cases: prioritize explicit related issue keys, workaround references, and business-rule phrases. Example terms: `AC-294673`, `AC-304559`, `Project Allocations can exceed 100% of the Revenue Budget`, `actual cost exceeds budgeted cost`.

## Shortlist format

For user-facing support analysis, present only a short shortlist of the most relevant candidates, normally the top 3 to top 5 items:

```text
IssueKey | Description
```

`Description` should normally be the issue summary.

## Important Rules

- A `jira_search` call should only search for likely matches. It must not recursively expand all returned issues in the same response.
- If a candidate looks useful, fetch it separately with `jira-access`.
- If a fetched SupportRequest candidate is resolved/closed/awaiting fix and has linked Bugs or comments saying a Bug was created/bound/fixed, open the likely Bug through the related-items workflow before using the candidate as known-issue evidence.
- Treat returned candidates as heuristic hypotheses and supporting evidence, not as confirmed duplicates or proof of the same root cause.
- Keep the user-facing explanation concise: mention why each candidate is relevant.
- After reviewing the shortlist, open only the most relevant 1-3 candidates for deeper review, not every returned item.

## Notes

- Search normally among `Bug` and `Support Request` issue types unless the analysis needs others.
- The search is JQL-based on `jira-internal` and then ranked locally by the agent (there is no server-side ranking in this workspace).
- The goal is fast discovery of likely duplicates, related defects, or tickets with a known workaround.
- `jira-internal` uses OAuth with the current user's Acumatica identity; do not use PATs.
- Technical contact: `oleg.bolshakov@acumatica.com`.
