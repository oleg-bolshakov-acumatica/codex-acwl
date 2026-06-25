---
name: acumatica-feature-development
description: Use this skill when Codex must implement or continue an Acumatica ERP feature from a Jira item and functional specification. Trigger on requests to develop a feature, continue feature work, implement a spec slice, maintain scope/coverage, trace Acumatica data paths, or make iterative code changes from Jira/Wiki requirements.
---

# Acumatica Feature Development

## Purpose

Implement features iteratively from an explicit functional specification. Keep scope, requirement coverage, validation, and residual risk visible.

## Context Sources

Use repository-approved paths only:

- Use `jira-access` for Jira requirements, acceptance criteria, comments, linked issues, and development metadata.
- Use `wiki-access` for linked `wiki.acumatica.com` functional specifications, including comments and resolution state.
- Use `local-change-access` when an existing change set must be inspected, via git over the local `code/` repository (branch name or commit/ref range; a bare PR id/URL must be mapped to a branch via Jira Development data first).
- Use `database-access` only for read-only diagnostics that can change interpretation, implementation risk, branch choice, or validation.
- Use `system-diagnostics-analysis` when version/build, customization, upgrade chronology, schema discovery, or source-branch selection can materially affect implementation or validation.
- Use `jira-similar-search` only when explicit context is insufficient and prior issues can change the plan.
- Use `acumatica-knowledge-access` as optional reference discovery for DAC fields/relationships, OData, Contract-Based REST API, Generic Inquiry examples, and Help Wiki behavior when those facts can change interpretation, design, data-path coverage, or validation.

Do not use direct REST, provider modules, browser access, or ad hoc scripts for Jira, Wiki, source changes, or SQL when the approved path is available (Jira->jira-internal, Wiki->wiki-internal, source changes->git over local `code/`, SQL->sql.select facade).
If `acumatica-knowledge` is unavailable, continue feature work and mention the limitation only when the missing reference context could materially affect design, scope, or validation.

## Required Local Context

Read and follow:

- `docs/FEATURE_DEVELOPMENT_WORKFLOW.md`
- `docs/ARCHITECTURE_RULES.md`
- `docs/REFACTORINGS.md`

Read `docs/FEATURE_IMPLEMENTATION_PATTERNS.md` when the iteration includes business logic, posting/recalculation paths, reports, projections, currency/base amounts, UI computed values, or customization-sensitive placement.

Read domain, database, and source references only when they can change interpretation, design, branch choice, or validation.

If a required workflow doc is missing, continue with this skill and report the limitation.

## Specification Source

The functional specification is the primary source of requirements. When Jira links to a Wiki functional specification, retrieve the Wiki page and treat it as authoritative. Jira context, PRs, comments, related issues, local docs, Acumatica Knowledge reference facts, existing code, tests, and read-only diagnostics are supporting evidence.

Do not implement ambiguous, contradictory, obsolete, or explicitly deferred requirements without user confirmation.

## Working Artifacts

Maintain a concise scope ledger during feature work:

- **In scope** - requirements selected for the current iteration.
- **Out of scope** - requirements explicitly excluded.
- **Deferred** - valid requirements postponed.
- **Ambiguous** - requirements needing clarification.
- **Validation pending** - behavior implemented but not yet validated.

Maintain a lightweight coverage matrix for substantial features: requirement, source, affected paths, status, code evidence, validation scenario, and residual risk.

Use `acumatica-session-notes` for iterative work when session notes need to be created, refreshed, or updated. Keep notes focused on handoff context such as source, scope, implemented slices, files changed, decisions, validation, open questions, deferred items, and known risks.

## Iteration Workflow

1. Refresh Jira, Wiki specification, comments, local docs, branch/PR context, and existing session notes when needed.
2. Inventory and classify requirements as ready, ambiguous, contradictory, deferred, or rejected for the current phase.
3. Use `acumatica-knowledge-access` only when exact DAC/API/GI/OData/Help Wiki reference facts can improve data-path tracing, design, or validation. Open exact objects/pages after search before relying on them; do not block if unavailable.
4. Trace relevant Acumatica data paths: entry/defaulting, validation, persist, release/posting, application/adjustment, reversal/void/delete, long operations, mass processing, recalculation/rebuild, reports/projections/inquiries, workflow, imports, API, copy/template behavior, and UI refresh.
5. Plan a coherent business slice before editing: selected behavior, excluded scope, central extension points, affected paths, customization impact, and validation.
6. Implement the minimal slice using existing Acumatica patterns.
7. Validate with focused builds/checks, `git diff --check` or equivalent, path parity review, and manual scenarios when tests are not in scope.
8. Recheck requirement coverage and use `acumatica-session-notes` to update relevant notes at phase boundaries.

## Implementation Rules

- Prefer existing Acumatica patterns, graph extension points, DAC attributes, accumulator patterns, workflow conventions, and report data-source patterns.
- Prefer graph-owned `protected virtual` methods for behavior that may need customization.
- Keep normal processing and recalculation/rebuild behavior aligned.
- Avoid database queries in frequent UI events such as `RowSelected`.
- For reports, trace `rpx -> subreport -> report table -> DAC/projection -> source tables` before changing layout.
- Keep report layout, migration scripts, broad workflow redesign, and automated test expansion out of scope unless explicitly included.
- Preserve existing user changes and unrelated dirty worktree state.

## Stop Conditions

Stop and report instead of implementing when:

- requirement meaning is unclear and likely interpretations produce different persisted data or accounting results;
- spec comments contradict normative text and no later clarification resolves the conflict;
- the slice requires schema redesign, broad workflow changes, report layout work, migration, or large refactoring that was not approved;
- a high-risk accounting, posting, or recalculation change cannot be validated meaningfully;
- local architecture rules would be violated;
- branch, baseline, or repository context cannot be identified confidently.

## Validation Methodology

Validation of a feature slice is case-specific. Propose concrete steps proportional to the slice's risk rather than following a fixed script, and agree with the user which steps the agent runs and which the user performs in their environment (see the Environment Interaction Principle in `AGENTS.md`).

- Validate per implemented slice against its requirement, not the whole feature at once. Keep **Validation pending** items in the scope ledger until covered.
- Trace the Acumatica data paths the slice touches (entry/defaulting, validation, persist, release/posting, recalculation/rebuild, reports/inquiries, import/API, reversal/void) and cover the ones carrying real data or accounting risk. Verify normal-processing and recalculation/rebuild parity when both maintain the same values.
- Choose validation means by need: a build/compile check, a focused automated test (only when tests are in scope), a manual UI/process scenario, or a read-only SQL/diagnostic check. Use the lightest means that can confirm the behavior.
- Builds, test runs, and write/git steps are environment-specific. Propose them and let the user execute when that fits their setup. Never report an unobserved result.
- Record the validation outcome and residual risk per slice using the coverage statuses below. A high-risk accounting, posting, or recalculation change that cannot be validated meaningfully is a stop condition.

## Output

For regular implementation updates, report:

1. current scope and excluded scope;
2. business behavior implemented;
3. key files or paths changed;
4. validation run;
5. known limitations;
6. next recommended slice when useful.

For coverage reviews, use statuses consistently: **Implemented**, **Partially implemented**, **Missing**, **Unclear**, **Deferred**, and **Not applicable**.
