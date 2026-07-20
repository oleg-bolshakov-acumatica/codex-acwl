---
name: acumatica-support-request-analysis
description: Analyze Acumatica Projects/Construction Support Requests for root cause, workaround, data checks, fix lineage, and support handoff. Use for Support Request investigation, customer-impact diagnosis, or Jira answers. Always finish with an explicit Iteration Gate and ready-to-post Jira comment proposal.
---

# Acumatica Support Request Analysis

## Purpose and Scope

Analyze Projects/Construction Support Requests to find a practical workaround and the most likely or confirmed root cause. Also answer explicit Jira requests such as fix confirmation or data checks. PM/CN/PJ context is the default unless the item clearly belongs elsewhere.

All searches, diagnostics, and code checks must serve the current Jira question, workaround, or root-cause goal. Skip work that cannot change the conclusion; disclose a skipped normally-useful step only when it affects confidence.

## Approved Context Paths

Use the repository skills for external context:

- `jira-access` for issue details; `jira-similar-search` for heuristic similarity.
- `related-items-analysis` for linked/mentioned issues, fixing Bugs, Wiki/PR references, and similar candidates.
- `wiki-access` for Wiki pages and comments.
- `database-root-cause-analysis` for tenant-scoped SQL diagnosis; `database-access` for individual read-only queries.
- `system-diagnostics-analysis` for version/build, customization, upgrade, schema, and branch context.
- `source-code-analysis` for static product-code analysis.
- `local-change-access` for a Jira-mapped branch or commit/ref range in local `code/`; map a bare PR id/URL through Jira Development data first.
- `root-cause-origin-analysis` for the git-archaeology methodology that identifies the introducing feature/ChangeRequest/PR/commit and its Jira item; it backs Stage 6.5.
- `jira-comment-drafting` only at the end; it drafts but never posts.

Jira and Wiki reads go through `jira-internal` and `wiki-internal`; SQL uses only `powershell-mcp-facade` `sql.select`. Do not bypass designated access skills with REST, provider modules, browser scraping, direct SQL tooling, or ad hoc scripts.

## Local Sources

- Product repository: `code`, only when it is a Git working tree; use `source-code-analysis` before relying on it.
- `docs/BUSINESS_MODEL.md` for process semantics and terminology.
- `docs/DATABASE_MODEL.md` for Projects/Construction tables and document flows.

Read local docs only when they can change the analysis. Use `system-diagnostics-analysis` rather than broad doc reading for version, customization, upgrade, schema, or branch questions.

## Non-Negotiable Rules

- Never invent facts. Separate confirmed evidence from hypotheses.
- Read Jira comments chronologically.
- Use root-cause confidence: **Confirmed**, **Likely**, or **Unclear**.
- Analyze meaningful fixing Bugs for reproduction, cause/fix description, `Fixed In`, `Fix Version/s`, PR state/target branch, QA build, and successor/reverting Bugs. A PR target is fix-train evidence, not proof of an exact released build.
- Distinguish a fixing Bug from a root-cause origin item. Confirm origin from requirements, spec, change diff, git history, or code; a Jira key or branch name alone is not proof.
- Use only read-only `SELECT` through approved database skills. Scope tenant-partitioned tables by `COMPANYID`; never treat cross-tenant matches as confirmation.
- Do not request user approval for diagnostic read-only SQL; ask only for missing connection or tenant context.
- Root-cause analysis is read-only. Remediation may be proposed for human review but not executed.
- Do not post Jira comments. Stage 10 produces draft text only.
- **Stage 9 is a mandatory stop/go gate in every final report.** It must precede Jira comment drafting, and another investigation iteration requires explicit user approval.
- When evidence is insufficient, provide the strongest supported conclusion, missing evidence, and a focused validation plan.

## Session Notes

Use `acumatica-session-notes` when a substantial investigation needs resume or handoff state. For a proposed iteration, preserve the unresolved goal, known facts, completed checks, remaining hypotheses, next focus, and continuation prompt.

## Workflow

Follow the stages in order unless earlier evidence makes a stage immaterial. Perform a stage only when it can change root cause, workaround, validation plan, or the explicit Jira answer.

### Stage 1. Title and Description

Identify the Jira request, symptom, expected/actual behavior, impact, reproduction, workaround mentions, affected process/module, visible failure level, and `Found in` version.

### Stage 2. Comments

Read earliest to latest. Track new facts, contradictions, reproduction details, hypotheses, workarounds, linked issues, Wiki/spec references, and Jira Development data such as PRs, branches, and commits.

### Stage 3. Related and Similar Items

Use `related-items-analysis` when explicit links, mentioned keys, Wiki/PR references, or similar candidates can affect the result. Review explicit context before heuristic search.

For relevant `Resolved`, `Closed`, or eligible `Awaiting Fix` Support Requests, inspect linked fixing Bugs before claiming a known issue, fix, duplicate, or regression. Compare current `Found in`/DB version with fixed builds and PR target branches. At or after the stated fix, consider regression, missing backport, customization, data state, or a successor/reverting Bug.

### Stage 4. Root-Cause Hypotheses

Form one to three evidence-based hypotheses. For each, identify the affected entity/process point, defect class, supporting facts, and the check that would confirm or refute it.

### Stage 5. Database Root-Cause Analysis

Use `database-root-cause-analysis` when SQL can answer the Jira request, distinguish hypotheses, validate a workaround, or supply version/tenant context. Keep queries read-only and tenant-scoped.

### Stage 5.5. System Diagnostics

Use `system-diagnostics-analysis` only when version/build, customization, upgrade chronology, schema, or branch choice can change the conclusion.

### Stage 6. Source Code Analysis

Use `source-code-analysis` when the cause remains unclear and standard product logic is plausible. Code-only evidence normally supports **Likely**, not **Confirmed**, until current-case evidence proves that path occurred.

Every material code finding must include the inspected branch/commit, repository-relative `path:line`, code element, focused verbatim excerpt, what it proves or suggests, and material limitations. Use several focused excerpts instead of long methods.

### Stage 6.5. Root-Cause Origin Item Search

When a concrete defect anchor or other evidence suggests a prior feature, ChangeRequest, Bug, PR, migration, commit, or spec introduced the behavior, use `root-cause-origin-analysis` for the complete methodology: verify the version branch; use `blame`, then `log -S`/`-G` to distinguish introduction from last touch; inspect candidates with `show`; map commits to Jira and PR context through Jira Development data; and use `local-change-access` for the resolved branch/ref range.

Classify the origin relationship as **Confirmed**, **Likely**, or **Unclear** and cite the requirement, diff, blame/history, spec, test, or other direct link. State how the origin item differs from any fixing Bug. It is mandatory to attempt and report origin when a defect anchor exists; if not established, say why. Inability to establish origin does not block the analysis.

### Stage 7. Root Cause

State the confirmed or most likely cause and confidence. Classify it where possible as logic defect, configuration, data issue, process side effect, regression/duplicate, or customization impact.

### Stage 8. Workaround

Assess existing workarounds. Propose one only when supported by evidence or safe process/data logic. State applicability, source, risk, temporary/permanent status, and required support/dev/business oversight. SQL correction is proposal-only and must never be executed during analysis.

### Stage 9. Iteration Gate — Mandatory

Always emit a visible `## 9. Iteration Gate` before Stage 10. State:

- `Outcome`: **Resolved**, **Partially Resolved**, **Unresolved**, or **Blocked**;
- whether another iteration is needed;
- the decisive reason;
- whether retrieved Jira/Wiki context was sufficient and any missing context that affected confidence.

Use **Resolved** for a confirmed cause or confirmed practical workaround that answers Jira; **Partially Resolved** for a likely cause/useful workaround needing validation; **Unresolved** when a focused check can improve an unclear material answer; and **Blocked** when required data, access, attachment, environment detail, or clarification is missing.

Do not continue automatically or repeat broad searches. For material uncertainty, include a compact gap analysis and ready-to-run continuation prompt:

```md
Continue analysis for <JiraKey>.

Outcome: <Partially Resolved | Unresolved | Blocked>
Unresolved goal: <goal>
Known facts: <decisive facts>
Already checked; do not repeat without new evidence: <sources/checks>
Remaining hypotheses: <hypothesis + confirm/refute condition>
Focus and tasks: <one narrow focus + concrete tasks>
Jira/Wiki context: <retrieved sources and material gap>
Success criteria: <decision this iteration must enable>
Constraints: approved repository paths; SELECT-only SQL; no Jira writes.
```

Explicitly state that starting another iteration requires user approval. If approved, run a focused continuation and merge new evidence into the existing report/note. If declined, keep the current confidence and blockers and still complete Stage 10.

### Stage 10. Jira Comment Proposal — Mandatory

Always use `jira-comment-drafting` after the iteration decision to produce one ready-to-post recommended comment. Never post it automatically.

If a Jira comment contains an unanswered explicit question, answer it directly first. Otherwise match the draft to the result: known issue/fix lineage, regression, root-cause origin, workaround, SQL proposal, confirmed/likely cause, missing data, or customization/configuration impact. Cite underlying Jira, Bug, SQL, code, change-set, Wiki, or version evidence. Include alternatives only when they serve materially different audiences.

## Optional Narrow Follow-Up

When the user asks a narrow business/data question, translate it into read-only SQL, show the query, then results and their effect on the hypothesis. Use Stage 9 for agent-proposed repeated investigation.

## Report Format

Keep the report concise and evidence-led. Omit unused source sections instead of narrating every skipped stage; Stage 9 and Stage 10 are mandatory.

```md
# Support Request Analysis: <ID / Title>

## Request
- Jira question, symptom, impact, version.

## Evidence
- Only material Jira/comment, related/fix-lineage, Wiki, SQL/diagnostic, and code/origin evidence actually used.
- For material code evidence: branch/commit, `path:line`, short excerpt, finding, and limitation.

## 6.5. Root-Cause Origin Item
- Origin Jira item / PR / commit / spec; relationship confidence and direct evidence.
- Distinction from the fixing Bug.
Or: Not established / not applicable because ...

## 7. Root Cause
- Confidence: Confirmed | Likely | Unclear
- Cause, evidence, and remaining uncertainty.

## 8. Workaround
- Applicability, steps, source, risk, and oversight; or no safe workaround found.

## 9. Iteration Gate
- Outcome: Resolved | Partially Resolved | Unresolved | Blocked
- Another iteration: yes | no
- Reason and Jira/Wiki path status.
- If material uncertainty remains: gap analysis + continuation prompt + explicit approval requirement.

## 10. Jira Comment Proposal
Recommended comment:
<ready-to-post text>

Alternative, only if materially useful:
<optional text>
```

## Domain Guidance

For Projects/Construction cases, check AP/AR/GL/PM/IN/PO/SO document relationships, original/reversal/reclass symmetry, billing flags, account groups, project/task/cost code/inventory propagation, billing selection, and recurring related-case patterns. In project billing, specifically test whether reversing/reclass PM transactions or net-to-zero logic diverge from the original path.

## Final Checks

Before finalizing, verify:

- the explicit Jira request was answered or its blocker is clear;
- comments were read chronologically and facts remain separate from hypotheses;
- explicit links preceded heuristic similarity search;
- meaningful fixing Bugs and version applicability were checked when relevant;
- SQL remained SELECT-only and tenant-scoped; branch/version context matches code evidence;
- material code findings contain branch, `path:line`, excerpt, interpretation, and limitation;
- root-cause origin was attempted and reported when a defect anchor existed, or the reason it was not established/not applicable is explicit;
- workaround applicability and risk are stated;
- `## 9. Iteration Gate` is explicit and any continuation awaits approval;
- `## 10. Jira Comment Proposal` contains ready-to-post text but performs no Jira write;
- substantial investigation notes were handled through `acumatica-session-notes` when needed;
- omitted steps that materially reduce confidence are disclosed.
