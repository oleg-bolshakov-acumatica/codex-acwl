---
name: acumatica-support-request-analysis
description: Use this skill when Codex must analyze Acumatica ERP Support Requests for the Projects/Construction team, including Jira title/description/comments, related Bugs and Support Requests, read-only SQL diagnostics, source-code analysis, root cause, workaround assessment, iteration gate, and Jira comment draft. Trigger on Support Request analysis, workaround/root-cause requests, data-check requests, fix-lineage checks, customer-impact diagnosis, or support handoff preparation.
---

# Acumatica Support Request Analysis

## Repository-Local MCP

The project-local MCP servers are declared in `.codex/config.toml` and loaded by Codex when the workspace is trusted:

- `jira-internal`, `wiki-internal`.

`jira-internal` and `wiki-internal` are the Acumatica-hosted HTTP MCP servers with OAuth and read-only scope; they are the primary Jira and Wiki context path for Support Request analysis. If `/mcp` does not show all expected servers, treat it as an MCP configuration or backend-availability problem first: run `scripts/Check-Mcp.ps1` and confirm the db-proxy (`127.0.0.1:8765`) backend is running. Do not bypass these servers with REST, provider modules, or ad hoc scripts.

## Highest-Priority Context Access Rule

Use only the designated repository skills or MCP paths for external context. `jira-internal` and `wiki-internal` are the primary read-only paths for Jira and Wiki. Ask the user for explicit approval only before genuinely broad or expensive searches, such as wide Jira JQL sweeps or full Confluence searches; state the intended scope. No approval is needed for ordinary read-only issue/page reads.

- `jira-access` for Jira issue reads through `jira-internal` (`jira_get_issue`, `jira_search`).
- `jira-similar-search` for likely similar Bugs or Support Requests through `jira-internal` JQL search.
- `wiki-access` for `wiki.acumatica.com` pages through `wiki-internal` Confluence tools, including page reads, search, comments, labels, attachments, page history, diffs, images, or view statistics.
- `database-access` for read-only SQL evidence.
- `local-change-access` to inspect changes via git over the local `code/` repository when change/PR context is explicitly needed: resolve a branch name or commit/ref range, and map a PR to a branch via Jira Development data.
- `database-root-cause-analysis` for applied, tenant-scoped SQL diagnosis and backup/environment/version extraction when database evidence can confirm or refute root-cause hypotheses.
- `system-diagnostics-analysis` for targeted version/build, customization, upgrade chronology, schema, and branch-selection diagnostics.
- `related-items-analysis` for explicit linked Jira items, mentioned issue keys, Wiki/PR references, and heuristic similar issue analysis.
- `jira-comment-drafting` for end-of-analysis Jira comment proposals that answer explicit questions from Jira comments or summarize findings, workarounds, SQL detection/correction proposals, related known issues, fix-lineage, or missing validation; do not post comments automatically.
- `source-code-analysis` for static analysis of the local `code` source repository when Jira, related/similar items, and database analysis do not establish root cause.

Do not bypass these paths with direct REST, provider modules, ad hoc scripts, or browser access when the designated MCP/skill path is available.
Do not request approval for read-only SQL needed for diagnosis.
Do not perform Jira, Wiki, git, or database actions beyond the read-only actions described by the corresponding skills.

## Purpose and Scope

Use this skill to analyze Acumatica ERP Support Requests related to Projects and Construction. The workspace is intentionally tailored for the Projects/Construction team, so PM/CN/PJ domain context is the default unless the Support Request clearly belongs elsewhere.

Primary goals:

- find a practical workaround when Jira asks for one or when a workaround is needed to unblock the customer;
- find the most likely or confirmed root cause.

Supporting goals: understand the issue, identify facts and symptoms, validate hypotheses, build a safe read-only database analysis plan when needed, and answer any explicit Jira request such as fix confirmation or data check.

Use this instruction for Support Requests, defect descriptions, case comments, related items, linked Wiki pages, database backup/restore parameters, local source analysis, and useful docs from `docs`.

All stages, searches, SQL checks, docs reads, diagnostics, and code-path checks are means to the current Jira request, workaround, or root-cause goal. Skip low-value steps when they cannot affect the conclusion, and mention skipped normally-useful steps only when the omission affects confidence.

## Repository and Local Sources

### Git Repository

A Git repository is available under a configurable path.

Default repository location:

- `code`

Use the `source-code-analysis` skill for source-code inspection. Resolve the repository path before relying on local code evidence; use `code` only when it exists and contains `.git`.

### Local Documentation

Use `docs` when it can materially improve the analysis:

- `docs/BUSINESS_MODEL.md` for domain concepts, process semantics, and terminology.
- `docs/DATABASE_MODEL.md` for Projects/Construction tables, keys, relationships, and document-flow navigation.

Use `system-diagnostics-analysis` instead of a local docs file for version/build checks, source-branch derivation, customization packages, upgrade history, and schema-discovery guidance.

Do not read broad documentation just for formality when Jira, SQL, Wiki, or code evidence already answers the question or when the issue is outside the documented domain. When referencing docs in the report, state which document mattered and how.

## Core Rules

- Do not invent facts. Base conclusions on Jira text, comments, related items, Wiki pages/comments, docs, code, tests, or read-only SQL.
- Analyze Jira comments chronologically, earliest to latest.
- Treat explicit linked issues and issue keys as important context for recurrence, known workarounds, prior root cause, fixes, or regression patterns.
- When a relevant `Closed`, `Resolved`, or eligible `Awaiting Fix` Support Request or similar-search candidate references a Bug that fixes, implements, causes, reverts, or materially explains the same defect, open and analyze that Bug as primary fix-lineage evidence. Extract reproduction steps, actual/expected behavior, root cause or fix description, `Fixed In`, `Fix Version/s`, merged/open/declined PRs, target branches, QA verification builds, and successor/reverting Bugs.
- When root cause appears to come from a prior product change, feature, ChangeRequest, migration, workflow change, selector/restrictor change, report/query change, validation rule, or PR/commit, search for the root-cause origin item. A root-cause origin item is the Jira issue, PR, branch, commit, Wiki/spec page, or related development artifact that introduced or materially explains the behavior causing the current Support Request. It is different from a fixing Bug: the origin item explains where the behavior came from; the fixing Bug explains where it was or will be corrected.
- If a root-cause origin item is found, include it in the report with its evidence and relationship confidence. Do not treat a commit message, branch name, or Jira key as proof by itself; confirm the link by comparing the changed code, requirement, PR, spec, or Jira text with the current symptom.
- Separate facts from hypotheses.
  - Fact = explicitly confirmed by text, data, code, docs, related case, Wiki, or SQL.
  - Hypothesis = likely explanation that still requires validation.
- Use root-cause confidence: **Confirmed**, **Likely**, or **Unclear**.
- If root cause is unclear, do not pretend it is confirmed; provide hypotheses and validation plan.
- Stage 9 is a mandatory stop/go gate in every final Support Request analysis report. Always make its result explicit before Jira comment drafting.
- If root cause, workaround, or an explicit Jira answer remains unresolved after the main pass, use Stage 9 to propose a focused next iteration instead of continuing automatically or repeating broad searches. The proposed iteration must require explicit user approval before it starts.
- Do not write Jira comments automatically. At the end of analysis, use `jira-comment-drafting` to propose ready-to-post Jira comment text only.
- Use only read-only `SELECT` statements for database analysis through `database-access` or the higher-level DB/diagnostics skills. Do not run or propose executing state-changing SQL as analysis.
- Keep database validation tenant-scoped when table design requires it. Use `COMPANYID` for tenant-partitioned tables when identified; do not treat cross-tenant matches as confirmation.
- Root-cause analysis is read-only. Workaround/remediation proposals may describe non-read-only actions only as recommendations for human review and execution.
- If data is insufficient, list what is missing, perform the maximum useful analysis, state hypotheses clearly, and provide a validation plan.

## Session Notes

Use `acumatica-session-notes` whenever a substantial investigation needs a resume or handoff note, or when an existing note should be refreshed.

When Stage 9 proposes another iteration and a note is created or updated, include the unresolved goal, checks already completed, remaining hypotheses, proposed focus, any extended-context request, and a ready-to-run continuation prompt.

## Default Analysis Flow

Follow the stages in order unless earlier evidence already answers the Jira request. Perform a stage when it can change the root-cause conclusion, workaround, validation plan, or answer to an explicit request.

### Stage 1. Title and Description

Identify the explicit Jira request, symptom, expected and actual behavior, business impact, reproduction steps, workaround mentions, expected dev action, affected scenario, visible level (UI, financial logic, distribution logic, Projects/Construction logic, other module logic, data inconsistency, setup/configuration), and `Found in` version when available.

### Stage 2. Comments

Read comments from earliest to latest. Track new facts, reproduction clarifications, discovered patterns, intermediate hypotheses, related case links, Wiki/spec links, development data (`pullRequests`, `branches`, `commits`), workaround details, and signs that the issue is already localized.

Collect relevant Wiki, PR, branch, commit, and related issue references for later related-item analysis.

If root cause or workaround is clear after title/description/comments, related/similar analysis is optional. If still unclear, search related or similar Jira issues unless a higher-signal path exists.

### Stage 3. Related and Similar Items

Use the `related-items-analysis` skill when Jira content does not fully answer the request, or when explicit links, mentioned issue keys, Wiki/PR references, or similar-search candidates can affect root cause, workaround, fix version, recurrence pattern, or the explicit Jira request.

For `Resolved`, `Closed`, or eligible `Awaiting Fix` related Support Requests and strong similar candidates, inspect linked issues for Bugs through Binding/Binds, Cause/Is Caused by, Duplicate, Related, regression, or comments such as "bug created", "bound", "fixed by", "fixed in", or "PR". Open likely fixing Bugs before using the related item as evidence for a known issue, fix, duplicate, or regression.

For each relevant fixing Bug:

- derive fix availability from `Fixed In` and `Fix Version/s` first;
- if fixed-build fields are missing or ambiguous, use merged PR target branches as fix-train evidence;
- use PR target branch as branch/train evidence, not as an exact released build unless release/build data confirms it;
- compare the current Jira `Found in`, database version/build, patch suffix, and expected source branch with the Bug's fixed builds and PR target branches;
- if the current version is before the fix, classify the pattern as a likely known fixed issue when symptoms match;
- if the current version is at or after the fix, consider regression, missing backport, customization impact, data issue, or a successor/reverting Bug.

### Stage 4. Root-Cause Hypotheses

Form 1 to 3 hypotheses from Jira, comments, related items, Wiki body/comments, docs, data model, SQL evidence, and source-code evidence when available.

For each useful hypothesis, identify the affected entity, process point, and likely class of problem: incorrect flag, broken document link, incorrect attribute propagation, business logic defect, GL/PM/AP/IN/PO/etc. inconsistency, setup/configuration issue, customization impact, data issue, or known version defect.

Mark indirect conclusions as hypotheses, not confirmed root cause.

Use local source, local docs, linked Wiki pages, endpoint definitions, Generic Inquiry definitions, and reports when exact DAC fields, relationships, API/GI surfaces, or Help Wiki behavior can refine the hypotheses or SQL/source-code validation plan.

### Stage 5. Database Root-Cause Analysis

Use the `database-root-cause-analysis` skill when root cause is not confirmed and read-only SQL can answer the Jira request, confirm/refute a hypothesis, validate a workaround, or extract backup/environment/version context needed for later analysis.

### Stage 5.5. System Diagnostics

Use the `system-diagnostics-analysis` skill only when version/build context, customization packages, upgrade chronology, schema discovery, or source-branch selection can materially affect root cause, workaround, or confidence.

### Stage 6. Source Code Analysis

Use the `source-code-analysis` skill when root cause remains unclear after Jira title/description/comments, explicit/heuristic similar items, and database analysis is unavailable, impossible, or inconclusive.

Use local source to inspect potential standard-product code paths and propose likely root causes or reproduction scenarios. Treat code evidence as hypothesis support unless current-case evidence confirms that the inspected path occurred.

For every source-code finding, present code evidence as self-contained citations:

- inspected repository branch or commit;
- full repository-relative file path;
- class, method, action, event handler, or workflow element when applicable;
- exact line number or compact line range;
- short verbatim code excerpt in a fenced block, with `...` for omitted lines;
- explanation of what the excerpt proves or only suggests;
- limitations such as branch mismatch, missing runtime data, uninspected customization, or unvalidated database state.

Keep excerpts short, usually 5-25 lines. Use several focused excerpts instead of pasting long methods. Avoid source-only links without code excerpts.

### Stage 6.5. Root-Cause Origin Item Search

Use this stage when source code, related Jira, Wiki/spec, git history, PR context, or system diagnostics suggest that the current behavior was introduced or materially shaped by a prior Jira item, feature, ChangeRequest, Bug, PR, migration, commit, or spec.

Search order:

- use local git history first for source-code findings: `git blame`, `git log -S`, `git log -G`, and targeted `git show` on the exact line, method, selector, workflow state, report, query, or migration that causes the symptom;
- extract Jira keys, PR ids, branch names, and commit messages from git history and the Jira development panel;
- open only candidate Jira items or PRs that can materially explain the current behavior;
- use `local-change-access` to inspect a specific change exposed by Jira, git history, or comments, resolving its branch/commit/ref range over the local `code/` repository and mapping a PR to a branch via Jira Development data;
- use `wiki-access` for linked specs only when they clarify the intended behavior or scope of the origin item.

For each candidate origin item, determine:

- key or identifier, type, summary, status/resolution, and release/fix version if available;
- whether it introduced the relevant behavior, only touched nearby code, or is unrelated;
- exact evidence connecting it to the current symptom: Jira requirement, Wiki/spec, PR title/description, commit diff, code blame, or changed test/spec;
- whether the behavior was intended, too broad, missing an exception, later reverted/superseded, or only indirectly related;
- distinction from any fixing Bug or workaround item.

Classify the origin relationship:

- **Confirmed**: Jira/spec/PR/code diff directly introduced the behavior that causes the current symptom.
- **Likely**: git/Jira/PR evidence strongly points to the item, but the PR/spec details are incomplete or indirect.
- **Unclear**: only a weak key, branch, nearby-code, or generic requirement match exists.

Include only meaningful origin items in the final report. If no origin item is found and this affects confidence, state that it was searched but not found. Do not run broad Jira/Wiki searches for origin hunting unless the origin could materially change root cause, workaround, fix applicability, regression assessment, or the Jira answer.

### Stage 7. Root Cause

State the confirmed or most likely root cause with confidence: **Confirmed**, **Likely**, or **Unclear**. Classify the issue where possible as logic defect, incorrect configuration, data issue, side effect of another process, known regression, duplicate pattern, or customization impact.

### Stage 8. Workaround

If a workaround is provided, assess applicability and risk. If not, propose one only when supported by related items, comments, business process understanding, or safe data/configuration logic.

Allowed workaround types: settings change, correct user-action order, alternative business process, or SQL script proposal. SQL scripts may be described only as workaround/remediation proposals for human review; do not execute them.

For each workaround, state source, risk, whether temporary/permanent, and whether support/developer/business analyst oversight is needed.

### Stage 9. Iteration Gate and Extended Context

Use this stage after root-cause and workaround assessment, before Jira comment drafting.

This stage is mandatory output. Every final report must include a visible `## 9. Iteration Gate` section. Do not leave the gate implicit in the summary, Jira comment draft, or next-step wording.

Before proceeding to Stage 10, Stage 9 must explicitly state:

- `Outcome`: `Resolved`, `Partially Resolved`, `Unresolved`, or `Blocked`;
- whether another iteration is needed;
- whether a broad or expensive `jira-internal` / `wiki-internal` search is needed, not needed, or proposed for user approval;
- for `Partially Resolved`, `Unresolved`, or `Blocked` outcomes with remaining material uncertainty, a ready-to-run continuation prompt and a statement that the next iteration requires user approval.

If the current pass resolves the Jira request well enough, state that no additional iteration is needed and continue to Stage 10.

If the current pass does not resolve the Jira request, do not automatically continue into another broad investigation. Classify the outcome:

- `Resolved`: root cause is **Confirmed**, or a practical workaround is confirmed and answers the Jira request.
- `Partially Resolved`: root cause is **Likely**, or a workaround exists but needs validation, risk review, or version/applicability confirmation.
- `Unresolved`: root cause or workaround remains **Unclear**, but specific additional checks could materially improve the conclusion.
- `Blocked`: required data, backup access, attachment, environment detail, or business clarification is missing.

Trigger an iteration proposal when any of these remain true:

- root cause is **Unclear**;
- workaround is missing, unsafe, or not validated when a workaround is needed;
- an explicit Jira question is still unanswered;
- fix-lineage, version applicability, customization impact, or data evidence is contradictory or incomplete;
- one to three concrete hypotheses remain and a focused check can confirm or refute them.

For an iteration proposal, provide a compact gap analysis:

- unresolved goal: root cause, workaround, Jira answer, fix applicability, data validation, or customization/system impact;
- evidence already checked and not worth repeating unless new evidence appears;
- remaining hypotheses and what would confirm or refute each one;
- the highest-value next investigation focus, such as SQL/data validation, source-code path inspection, related/fix-lineage review, system diagnostics, workaround validation, Wiki/spec review, or broader Jira/Wiki context search;
- success criteria for the next iteration.

Always include the continuation prompt when proposing another iteration. Do not replace it with prose next steps. The prompt must be specific enough that the next pass can start without repeating completed checks, and constrained enough to prevent a new broad investigation unless the user explicitly asks for one.

When a broad or expensive Jira or Wiki search could materially change the result, include an optional extended-context request. Ordinary `jira-internal` / `wiki-internal` reads need no approval; propose a broad or expensive search only when it is needed for the current gap, for example:

- `jira-internal`: wide JQL sweeps across rare error text, screen ID, table/field name, status/version/project combinations, or issue mentions beyond targeted similarity results;
- `wiki-internal`: full Confluence search across spaces, large page tree/children walks, bulk attachments/images, or wide page history/diff review needed to interpret specs or behavior changes.

Before running a broad or expensive search, ask for explicit user confirmation and state:

- which server is proposed: `jira-internal`, `wiki-internal`, or both;
- why a broad search is needed;
- exact intended scope;
- what the extra context could confirm or refute;
- what already-checked areas will not be repeated.

No approval is needed for ordinary targeted read-only issue/page reads, or when the user explicitly requests the broad search.

Prepare a ready-to-run continuation prompt for the next iteration and stop for user approval before starting it. The prompt should preserve state and constrain the next pass:

```md
Continue analysis for <JiraKey>.

Current outcome:
- Root cause confidence: <Confirmed | Likely | Unclear>
- Workaround status: <confirmed | likely | none | unsafe | unknown>
- Main unresolved goal: <root cause | workaround | Jira question | fix applicability | data validation | customization/system impact>

Known facts:
- <fact 1>
- <fact 2>
- <fact 3>

Already checked, do not repeat unless new evidence appears:
- <Jira comments / related issues / SQL / source paths / Wiki / local changes / diagnostics>

Remaining hypotheses:
1. <hypothesis> - why it is plausible, what would confirm/refute it.
2. <hypothesis> - why it is plausible, what would confirm/refute it.

Focus for this iteration:
- <SQL validation | source-code inspection | fix-lineage review | system diagnostics | workaround validation | Wiki/spec review | broader Jira/Wiki context search>

Specific tasks:
- <task 1>
- <task 2>
- <task 3>

Optional extended context request:
- Proposed server: <jira-internal | wiki-internal | both | none>
- Reason a broad/expensive search is needed: <reason>
- Intended scope: <specific JQL/search/page-history/attachments/comments/diff/etc.>
- Expected value: <what this can confirm/refute>
- Approval required before use: <yes | already requested by user | not needed (targeted read)>

Success criteria:
- Confirm/refute <hypothesis>.
- Determine whether <workaround> is safe/applicable.
- Upgrade conclusion from Unclear to Likely/Confirmed, answer the Jira request, or state why it remains blocked.

Constraints:
- Use repository skills/MCP paths only.
- Use read-only SQL only.
- Do not post Jira comments.
```

If the user approves the continuation prompt, run the next iteration as a focused pass rather than restarting the entire workflow blindly. Merge new findings into the current report/session note. Propose a further iteration only when new evidence creates a concrete next check that can materially change the conclusion.

If the user does not approve the continuation prompt, stop after Stage 10 with the current confidence level and blockers stated. Do not begin the proposed iteration speculatively.

### Stage 10. Jira Comment Proposal

Use the `jira-comment-drafting` skill at the end of the workflow, after the iteration decision is settled, to propose one ready-to-post Jira comment that reflects the analysis result. Do not post it automatically.

If Jira comments contain an explicit unanswered question, prioritize drafting a direct answer to that question over a generic summary comment. The draft may then add evidence, context, workaround, or next validation steps.

The proposed comment should match the conclusion:

- answer to an existing Jira comment question, with direct answer first and evidence after it;
- same known issue / same root cause, with related item or fixing Bug and evidence;
- known fixed issue / possible regression, with fixed builds, PR branch, and current version comparison;
- root-cause origin item, when it helps explain why the current behavior exists; clearly state whether it is the originating feature/change or only supporting evidence, and do not present it as a fixing Bug unless it actually contains the fix;
- confirmed workaround, including applicability and risk;
- SQL detection and correction workaround proposal, with read-only detection SQL, correction script proposal, backup/review/tenant-scope warnings, and no execution;
- confirmed root cause with no safe workaround;
- likely root cause requiring validation;
- request for more data;
- customization or configuration impact.

Cite the underlying Jira item, Bug, SQL evidence, code path, local change, Wiki, or version evidence used in the analysis.

Provide alternatives only when materially useful, for example a short customer-facing update and a more technical internal comment.

### Optional Follow-Up Mode

Use when the user asks for additional validation or a narrow business question can clarify an unclear workaround. Ask the user for the business question if needed, translate it into read-only SQL, show the SQL first, then results, then how results affect hypothesis/root cause/workaround. For agent-proposed repeated investigation cycles, use Stage 9 instead.

## Wiki Rules

Use `wiki-access` for Wiki links in Jira descriptions, comments, related items, or local notes. Include footer and inline comments by default. Use `inline.originalSelection`, `inline.markerRef`, and `resolution.status` to understand comment scope. Do not use `doc-sanitizer` or direct Wiki REST/browser access. Cite Wiki facts separately from Jira and SQL facts.

## Report Format

Prepare a brief structured report focused on the Jira request, workaround, root cause, and evidence. Omit low-value sections or mark them `Not applicable` when intentionally skipped.

```md
# Support Request Analysis: <ID / Title>

## 1. Title and Description Analysis
- Problem statement, scenario, impact, Found in/version.

## 2. Comment Analysis
- What comments add, contradictions, useful facts, relevant Wiki/development references.

## 3. Related Items
- Useful explicit links, mentioned keys, Wiki/PR references, and similar-search candidates; what they prove or do not prove.
- Similarity search queries when run.

## 3.1. Fix Lineage
- Linked fixing Bugs from current, related, or similar items; status/resolution; `Fixed In` / `Fix Version/s`; merged PRs and target branches; QA verification builds; successor/reverting Bugs; version comparison against the current item.

## 4. Root Cause Hypothesis
- Primary hypothesis, alternatives, basis, diagnostics impact if checked.

## 5. Database Root-Cause Analysis
- Server, Database, Backup, URL/site files, tenant/COMPANYID.
- Jira Found in, Jira patch, DB version, version match, expected source branch.
- SQL checks run, key results, and impact on hypotheses.

## 5.5. System Diagnostics
- Version/build, customization, upgrade chronology, schema, or branch-selection diagnostics that affected the conclusion.
Or: Not needed because ...

## 6. Source Code Analysis
- Branch/repository/commit checked; for each finding include the full repository-relative file path, class/method/action/event when applicable, exact lines, short code excerpt, finding, impact on the hypothesis, reproduction hypotheses, and limitations.
Or: Not needed / not possible because ...

## 6.5. Root-Cause Origin Item
- Root-cause origin item: <Jira key / PR / commit / Wiki/spec>, type/status/resolution, release/fix version when available.
- Why it matters: <behavior, restriction, migration, workflow, selector, report/query, or validation it introduced>.
- Evidence: <Jira requirement, PR/commit diff, code blame, Wiki/spec, changed test, or related development data>.
- Relationship to current issue: Confirmed | Likely | Unclear.
- Distinction from fixing Bug: <origin item vs fix item, if both exist>.
Or: Not found / not applicable because ...

## 7. Root Cause
- Status: Confirmed | Likely | Unclear
- Root cause and evidence.

## 8. Workaround
- Existing/proposed workaround, source, risks, oversight needed.

## 9. Iteration Gate
- Outcome: Resolved | Partially Resolved | Unresolved | Blocked.
- No additional iteration needed because ...
Or:
- Unresolved goal, gap analysis, next investigation focus, success criteria, and ready-to-run continuation prompt requiring user approval.
- Optional extended context request for a broad/expensive `jira-internal` / `wiki-internal` search, with reason, scope, expected value, and approval status.

## 10. Jira Comment Proposal
- One ready-to-post recommended Jira comment, plus alternatives only when useful.
- Include SQL detection/correction scripts when a SQL workaround is proposed. Mark correction as proposal-only and requiring review/backup/tenant scoping.

## Summary
- Brief conclusion and next steps.
```

## Output Quality and Domain Guidance

Keep reports brief, fact-based, and useful for support/dev handoff. Avoid long retellings without conclusions, unsupported claims, and vague phrases like "something is wrong with the data."

For Projects/Construction cases, pay attention to AP/AR/GL/PM/IN/PO/SO relationships; reclassification/reversal symmetry; billable/non-billable flags; account groups; project, project task, cost code, inventory item; account-to-account-group connection; billing pipeline entry; original vs reversing discrepancies; and recurring patterns from related cases.

For project billing scenarios, verify whether original/reversing transactions are asymmetric, reversal/reclass PM transactions have incorrect billing flags, PM transfer during reclass/reverse is wrong, billing exclusion is incorrect, or net-to-zero logic is broken by related PM transaction state.

## Final Checklist

Before finalizing, verify:

- explicit Jira request identified: workaround, root cause, fix confirmation, data check, or other goal;
- title, description, and comments analyzed chronologically;
- related items analyzed through `related-items-analysis` when explicit links, mentioned keys, Wiki/PR references, or similar search could affect the conclusion;
- `Resolved`, `Closed`, or eligible `Awaiting Fix` related Support Requests and strong similar candidates were checked for linked fixing Bugs when fix/version/regression context could matter;
- linked fixing Bugs were analyzed for reproduction, expected/actual behavior, `Fixed In`, `Fix Version/s`, PR status, PR target branch, QA verification builds, and successor/reverting Bugs;
- database root-cause analysis used `database-root-cause-analysis` when SQL evidence could answer the request, or skipped with a clear reason;
- Jira `Found in`, DB version, patch suffix, tenant context, `COMPANYID`, and expected source branch considered when database/source analysis depends on them;
- current `Found in` / DB version was compared with relevant Bug fixed builds and PR target branches before concluding same known issue, already-fixed regression, backport gap, customization/data issue, or unrelated issue;
- system diagnostics used `system-diagnostics-analysis` when customization, upgrade chronology, schema, version/build, or branch selection could affect the conclusion;
- hypotheses and root cause use confidence: Confirmed, Likely, or Unclear;
- SQL validation used only `SELECT` and only where it can confirm/refute a hypothesis or answer Jira;
- source-code analysis used the `source-code-analysis` skill when Jira/similar/DB evidence did not establish root cause, or was skipped with a clear reason;
- source-code evidence includes self-contained citations: branch/commit, full file path, exact lines, short code excerpt, finding impact, and limitations;
- root-cause origin item search performed when code/git/Jira/spec evidence suggests the current behavior came from a prior feature, ChangeRequest, migration, workflow, selector/restrictor, report/query, validation, PR, or commit; meaningful origin items are included in `## 6.5. Root-Cause Origin Item` with relationship confidence and evidence;
- broad or expensive `jira-internal` / `wiki-internal` searches were run only after explicit user approval, unless the user directly requested them; ordinary targeted reads needed no approval;
- workaround assessed when requested or needed;
- final report contains an explicit `## 9. Iteration Gate` section before the Jira Comment Proposal;
- Stage 9 classified the outcome as Resolved, Partially Resolved, Unresolved, or Blocked and stated whether another iteration is needed;
- when root cause/workaround/Jira answer remained unresolved or materially uncertain, Stage 9 included a gap analysis, highest-value next investigation focus, success criteria, and ready-to-run continuation prompt;
- any proposed repeated iteration requires explicit user approval before it starts; the continuation prompt is included in the report and avoids repeating checks already completed unless new evidence appears;
- any broad or expensive `jira-internal` / `wiki-internal` search in repeated iterations is scoped, justified, and approval-gated unless explicitly requested;
- Jira comment proposal drafted through `jira-comment-drafting`: one ready-to-post recommended comment, no automatic Jira write, SQL corrections marked proposal-only when included;
- substantial investigation notes handled through `acumatica-session-notes` when needed;
- skipped steps are not hidden when they affect trust in the conclusion.
