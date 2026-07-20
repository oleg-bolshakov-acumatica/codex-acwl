---
name: related-items-analysis
description: Analyze linked or mentioned Jira items, fixing Bugs, Wiki/PR references, and heuristic similar issues during Support Request analysis. Use to validate prior causes, workarounds, fix lineage, version applicability, duplicates, regression boundaries, and recurrence without treating weak matches as proof.
---

# Related Items Analysis Skill

## Purpose

Use this skill to evaluate external-but-related issue context after the current Jira issue has been reviewed.

The goal is to find prior confirmed causes, workarounds, fixes, duplicate patterns, regression clues, and explicit development context while keeping noisy similarity results out of the final analysis.

## Dependencies

Use these low-level skills as needed:

- `jira-access` for explicit Jira issue reads;
- `jira-similar-search` for heuristic Bug/SupportRequest similarity search;
- `wiki-access` for relevant `wiki.acumatica.com` links found in issues, comments, or change-set context;
- `local-change-access` to inspect a change set via git over the local `code/` repository when Jira development data or comments expose a PR/branch/commit reference. Map a PR to a branch via Jira Development data, then inspect that branch with read-only git.

`jira-access` and `jira-similar-search` read Jira through the corporate `jira-internal` MCP server, and `wiki-access` reads Wiki through the corporate `wiki-internal` MCP server. These internal servers are the primary path for Jira/Wiki access, including capabilities such as direct JQL search, Confluence search, page tree, history/diff, labels, attachments, images, downloads, and view statistics.

Do not use direct REST, provider modules, browser access, or ad hoc scripts when the approved internal MCP path is available.

## Trigger Point

Run this skill when:

- current Jira title/description/comments do not fully answer root cause or workaround;
- the current issue has explicit `linkedIssues`;
- Jira text/comments mention issue keys;
- comments mention Wiki pages, PRs, commits, branches, or known defects;
- heuristic similar-item search can plausibly reveal prior resolved/closed diagnosis.
- a similar-search candidate is closed/resolved/awaiting fix and may have a linked fixing Bug that defines reproduction, fix version, PR branch, or regression boundary.

Skip or keep minimal when current Jira content already has a confirmed root cause and no related context can change the answer.

## Priority Order

Follow this order:

1. Explicit `linkedIssues` from the Jira issue snapshot.
2. Linked fixing Bugs from relevant closed/resolved/awaiting-fix Support Requests or similar-search candidates.
3. Issue keys mentioned in description/comments.
4. Wiki/spec links from description/comments when they clarify expected behavior, implementation, QA notes, reproduction, or workaround.
5. Development data: PRs, branches, commits when fix context or code changes matter.
6. Heuristic `jira-similar-search` only when explicit context is insufficient.

Explicit relationships are more important than heuristic search candidates.

## Explicit Jira Links

Open only linked issues that can affect:

- root cause;
- workaround;
- duplicate status;
- fix version;
- recurrence pattern;
- regression evidence;
- expected behavior;
- the user's explicit Jira request.

Do not recursively expand every linked issue.

For each opened issue, extract:

- status/resolution;
- summary and relevant description/comment facts;
- relationship to current issue;
- confirmed root cause or workaround;
- fix version/PR/development references;
- whether it is a duplicate, predecessor, regression, or only superficially related.

If the opened issue is a closed/resolved/awaiting-fix Support Request and it has linked Bugs, comments such as "bug created", "bug bound", "fixed by", or development data pointing to a Bug, open the likely fixing Bug before using the Support Request as evidence for a known issue, fix version, duplicate, or regression.

## Mentioned Issue Keys

Treat issue keys in comments/description as important clues.

Open mentioned keys when the surrounding text suggests relevance:

- "related to";
- "same as";
- "caused by";
- "fixed by";
- "workaround from";
- "reproduced in";
- "regression from";
- "see AC-...";

Do not open keys that are clearly incidental, quoted in unrelated logs, or part of broad noise.

## Wiki And PR Context

Open relevant Wiki links through `wiki-access` when they may clarify:

- expected behavior;
- spec or design notes;
- QA/reproduction details;
- workaround interpretation;
- implementation constraints;
- unresolved inline/footer comments.

Use `local-change-access` when Jira development data, related issues, or comments expose a specific PR/branch and the change set can affect root cause, fix confirmation, or workaround. Map the PR to a branch via Jira Development data, then inspect that branch with read-only git over the local `code/` repository.

Treat the change set as evidence of what was changed, not as proof that the current customer's data followed that path unless current-case evidence supports it.

Use PR target branch as fix-train evidence when `Fixed In` or `Fix Version/s` are missing or ambiguous. Prefer explicit fixed-build fields and QA verification comments for exact build availability. Report PR state; declined/open PRs do not prove delivered fixes.

## Heuristic Similar Search

Use `jira-similar-search` only after explicit links and mentioned keys are insufficient.

Search strategy:

- start with exact phrases, screen IDs, document numbers, error text, table/field names, and narrow process terms;
- include resolved items when looking for prior diagnosis, fixes, or workarounds;
- retry with guided hints if baseline results are driven by weak terms;
- stop after repeated noisy results unless new evidence gives a better query.

After opening a strong resolved/closed/awaiting-fix similar candidate, inspect its linked Bugs before treating the candidate as resolved prior evidence. A similar Support Request can be useful mainly because its linked Bug contains the reproducible defect, fixed builds, PR branch, or successor regression context.

Good hints:

- exact UI messages or exception fragments;
- screen IDs;
- issue keys explicitly referenced by current Jira;
- table names, DAC names, field names;
- report names;
- narrow component names;
- business-rule phrases.

Avoid broad tokens like:

```text
project, issue, error, screen, document, description, related, customer, cannot
```

## Fix-Lineage Bug Analysis

Open a linked Bug when a relevant current, related, or similar item points to a defect that may have been fixed, reverted, or superseded.

Common signals:

- Jira link types such as Binding/Binds, Cause/Is Caused by, Duplicate, Related, regression, predecessor, or successor;
- comments saying "bug created", "bound", "fixed by", "caused by", "regression from", "reverted", or "fixed in";
- development data that names a Bug key, PR, branch, or commit tied to the defect.

For each opened Bug, extract:

- status, resolution, `Fixed In`, and `Fix Version/s`;
- reproduction steps, actual behavior, and expected behavior;
- root cause, fix description, public description, and useful QA comments;
- PR ids, PR state, source branch, target branch, and changed files when available;
- QA verification builds and comments;
- successor, reverting, or related Bugs that change the interpretation of the original fix.

Compare fix availability with the current item:

- current Jira `Found in`, database version/build, patch suffix, and expected source branch;
- Bug fixed builds and fix versions;
- merged PR target branch as fix-train evidence when exact builds are absent;
- verification builds as stronger evidence than branch naming alone.

Classify the relationship:

- same known issue before fix;
- fixed issue but current item may be regression, missed backport, customization impact, or data issue;
- successor/reverting issue changed the original fix behavior;
- weak or unrelated match.

## Relevance Rules

Report a candidate only when it has a meaningful connection:

- same symptom and same process;
- same screen/report/error;
- same document chain or table/field;
- same root cause or workaround pattern;
- same version/regression/fix context;
- explicit current-case relationship.

Filter out weak matches that share only generic module words.

Distinguish:

- explicit Jira links;
- mentioned issue keys;
- heuristic similar-search candidates.

Do not call a candidate a duplicate unless Jira relationship/status or strong evidence supports that conclusion.

## Output Guidance

Report only the top 3-5 meaningful candidates.

Suggested section:

```text
Key | Source | Why
AC-123456 | explicit link | Resolved duplicate; same AP bill release error; workaround confirmed in comments.
AC-234567 | similar search | Same PMTran billable flag asymmetry; useful hypothesis only, not proof.
```

When linked fixing Bugs are relevant, add a compact fix-lineage table:

```text
Bug | Fix | PR branch | Applies? | Why
AC-123457 | 25.200.0170 / 2025R2RC | 2025r200 | Current build is before fix | Same known defect; bound to AC-123456.
```

Report search attempts only when they explain coverage, a retry, or a no-result conclusion:

```text
Similarity Search Queries:
- exact_phrase | "The document is out of balance"
- screen_id | PM301000
- keywords | PMTran billable reversal
```

If nothing meaningful was found:

```text
No meaningful related/similar items found. Explicit links checked: <keys>. Similarity queries used: <short list>.
```

## Impact On Analysis

For each useful related item, state how it changes the current analysis:

- confirms a known workaround;
- supports a root-cause hypothesis;
- suggests a database validation check;
- identifies a fixed version or PR;
- rules out a false lead;
- shows that the current item is likely unrelated despite superficial similarity.

Related items support the analysis but do not replace current-case validation when the current data state matters.
