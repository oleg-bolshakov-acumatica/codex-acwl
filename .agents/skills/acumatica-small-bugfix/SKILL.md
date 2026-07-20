---
name: acumatica-small-bugfix
description: Use this skill when Codex must diagnose and implement a minimal low-risk Acumatica ERP bugfix for a narrow defect, focused failing test, null/empty handling issue, mapping mistake, validation gap, query/filter correction, small regression, exception, or data-dependent support bug where expected behavior and validation can be established.
---

# Acumatica Small Bugfix

## Purpose

Diagnose a narrow defect, confirm the fix remains small and safely validatable, implement the minimal correction, and run focused validation.

## Context Sources

Use repository-approved paths only:

- Use `jira-access` for Jira bugs, support requests, comments, linked issues, and development metadata.
- Use `acumatica-git-workflow` to discover Jira-related branches/PRs and to prepare or resume the `bugfix` branch.
- Use `wiki-access` for linked Wiki context.
- Use `jira-similar-search` only when explicit context is insufficient and similar issues can change diagnosis or scope.
- Use `database-access` for read-only SQL evidence when customer data, backup data, tenant state, or version context can confirm or refute a hypothesis.
- Use `system-diagnostics-analysis` when version/build, customization, upgrade chronology, schema discovery, or source-branch selection can materially affect diagnosis, branch choice, or validation.
- Use `local-change-access` when a related change set exists and its diff matters, via git over the local `code/` repository (branch name or commit/ref range; a bare PR id/URL must be mapped to a branch via Jira Development data first).
- Use `root-cause-origin-analysis` to establish which prior feature/ChangeRequest/PR/commit (and its Jira item) introduced the defect, before proposing the fix.

Do not use direct REST, provider modules, browser access, or ad hoc scripts for Jira, Wiki, source changes, or SQL when the approved path is available (Jira->jira-internal, Wiki->wiki-internal, source changes->git over local `code/`, SQL->sql.select facade).

## Required Local Context

Read and apply:

- `docs/ARCHITECTURE_RULES.md`
- `docs/REFACTORINGS.md`

Read these only when they can affect branch choice, diagnosis, implementation risk, or validation:

- `docs/BUSINESS_MODEL.md`
- `docs/DATABASE_MODEL.md`

## Repository and Branch Rules

Use `acumatica-git-workflow` to resolve the repository, discover existing task branches and PR context, and prepare or resume a `bugfix` branch. Base branch is mandatory. A new branch must use the defined bugfix naming rule and a freshly fetched stable remote ref. Fetch, switch, branch creation, staging, commit, push, and every other non-read-only Git operation require explicit user confirmation.

When version-specific behavior matters:

1. Parse `YY.RRR.xxxx-n` as base version `YY.RRR.xxxx` plus patch `n`.
2. Compare Jira `Found in` with database `[Version]` when database evidence is used.
3. Derive source branch as `YY.RRR.xxxx` to `20YYrRRR`, for example `25.201.0213-2` to `2025r201`.
4. Verify the inspected branch/baseline before relying on version-specific code evidence.

## Workflow

1. Read the bug report, Jira context, relevant chronological comments, explicit linked issues, and similar issues only when needed.
2. Resolve repository, branch/PR, baseline, and version context with `acumatica-git-workflow`; obtain explicit confirmation before any required Git mutation.
3. Retrieve relevant Wiki links and read required local docs.
4. Use read-only SQL or diagnostics only when they can confirm/refute a hypothesis or affect branch choice, root cause, or risk.
5. Diagnose root cause from Jira, Wiki, docs, code, tests, and optional SQL evidence.
6. Establish root-cause origin via `root-cause-origin-analysis` before the fix plan: identify the introducing feature/ChangeRequest/PR/commit and its Jira item with a concrete `path:line@commit` link. This is mandatory to attempt and mandatory to report; if the origin cannot be established, state that explicitly with the reason (see the skill's "Not established" / "Not applicable" outcomes). Inability to establish origin does not block the fix.
7. Confirm the fix remains small, clear, and safely validatable.
8. Implement the minimal change.
9. Run focused validation.
10. Report root cause, root-cause origin (or why it is not established), fix, validation, and limitations.

For customer-backup or data-dependent bugs, capture database/server/backup/tenant/`COMPANYID` when present. Use tenant-scoped SQL for tenant-partitioned tables and do not treat cross-tenant matches as confirmation.

## Stop Conditions

Stop and report instead of implementing when:

- expected behavior remains ambiguous;
- validation is not possible;
- the fix requires schema redesign, API contract changes, broad workflow redesign, or a cross-cutting refactor;
- the change fans out across many modules;
- local architecture rules would be violated;
- branch, baseline, or repository context cannot be identified confidently.

Use root-cause confidence:

- **Confirmed** - direct evidence supports the cause.
- **Likely** - strong evidence supports the cause but validation is incomplete.
- **Unclear** - evidence is insufficient or contradictory.

## Validation Methodology

Validation is case-specific; there is no fixed script. Design a focused validation plan proportional to the fix's risk, propose its concrete steps yourself, then agree with the user which steps the agent runs and which the user performs in their environment (see the Environment Interaction Principle in `AGENTS.md`).

- Start from the failure: the plan must show the original defect would now be caught. Establish the broken behavior first, then show the fix changes it.
- Reason about regression scope explicitly. Identify the shared code paths, callers, and data paths the change can affect, and cover the ones that carry real risk rather than only the changed lines.
- Choose validation means by what the evidence needs: a build/compile check, an existing or focused automated test, a manual UI/process scenario, a read-only SQL check against affected data, or path-parity review of normal vs recalculation/rebuild behavior. Use the lightest means that can actually confirm the fix.
- Builds, test runs, and any write/git steps are environment-specific. Propose them and let the user run them when that fits their setup. Never report a result you did not observe.
- State the validation outcome with confidence (**Confirmed** / **Likely** / **Unclear**) and name what remains unverified. If meaningful validation is not possible, treat it as a stop condition and report it instead of implying the fix is verified.

## Session Notes

Use `acumatica-session-notes` when a bugfix investigation is substantial or may resume or hand off (root cause still **Likely** or **Unclear**, validation pending, or environment/branch context worth preserving). Record the diagnosis state, the established repository/branch/version context, the fix slice, and remaining validation so the next pass does not re-derive them.

## Output

Use this final structure:

1. **Task understanding**
2. **Root cause** with confidence: Confirmed, Likely, or Unclear
3. **Root cause origin** - introducing Jira item + PR + `path:line@commit`, with confidence; or an explicit "not established / not applicable" statement with the reason
4. **Fix summary**
5. **Validation**
6. **Risks or limitations**
