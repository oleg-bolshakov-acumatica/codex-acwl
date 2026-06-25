# Feature Development from Specification Workflow

This document defines the detailed workflow for iterative Acumatica ERP feature development from a functional specification. It supplements the `Feature Development from Specification` mode in `AGENTS.md`.

Use [FEATURE_IMPLEMENTATION_PATTERNS.md](FEATURE_IMPLEMENTATION_PATTERNS.md) as the companion implementation guide for Acumatica data-path tracing, recalculation parity, report-source analysis, currency/base amount handling, UI computed values, and customization-friendly placement.

## Goals

- Use the functional specification as the primary source of business requirements.
- Keep implementation iterations small, explicit, and verifiable.
- Make scope, ambiguity, validation, and residual risk visible to the user.
- Preserve enough session state for reliable resume, handoff, and later verification.

## Core Principles

- Do not invent requirements. Separate confirmed facts from hypotheses.
- Do not implement ambiguous, contradictory, obsolete, or explicitly deferred requirements without user confirmation.
- Prefer existing Acumatica patterns, graph extension points, DAC attributes, accumulator patterns, workflow conventions, and report data-source patterns over new abstractions.
- Prefer graph-owned `protected virtual` methods for business logic that may need customization. Avoid static helper methods for feature behavior unless the logic is genuinely shared and no graph-level customization point is appropriate.
- Treat normal processing and recalculation/rebuild paths as separate implementation targets that must stay consistent.
- Treat report layout changes, data migrations, broad workflow redesign, and automated test expansion as separate scope items unless explicitly included in the current iteration.

## Context Source Selection

The functional specification remains the primary source of business requirements. Local documentation and reference lookups provide implementation context; they should not silently override the specification.

- Always use `docs/ARCHITECTURE_RULES.md` and `docs/REFACTORINGS.md` as the implementation guardrails for feature work.
- Use `docs/BUSINESS_MODEL.md` when PM/CN/PJ domain meaning, process semantics, terminology, or expected product behavior can change interpretation of the requirement.
- Use `docs/DATABASE_MODEL.md` when table ownership, keys, relationships, projections, or physical join paths can change design or validation.
- Use `system-diagnostics-analysis` when version, branch choice, customization state, upgrade history, or schema discovery can change the implementation or validation plan.
- Use Acumatica Knowledge as optional reference discovery for exact DAC fields and relationships, OData, Contract-Based REST API, Generic Inquiry, and Help Wiki facts when those facts can change data-path tracing, design, exposed-surface risk, or validation.

If Acumatica Knowledge is unavailable, continue feature work. Mention the limitation only when the missing reference fact could materially affect scope, design, or validation confidence.

## Required Working Artifacts

### Scope Ledger

Maintain a concise scope ledger during feature work:

- **In scope** - requirements selected for the current iteration.
- **Out of scope** - requirements explicitly excluded by the user or by mode limits.
- **Deferred** - valid requirements postponed to a later iteration.
- **Ambiguous** - requirements that need user, analyst, or specification clarification.
- **Validation pending** - behavior implemented but not yet validated by a focused scenario.

Update this ledger whenever the specification changes, the user narrows or expands scope, or implementation reveals a hidden dependency.

### Requirement Coverage Matrix

For substantial features, maintain a lightweight coverage matrix. It can be in the session note or in the response when requested.

Recommended columns:

- requirement or business behavior;
- source of the requirement: Jira, Wiki section, comment, user instruction, or code evidence;
- affected screens, graphs, DACs, reports, projections, and processes;
- status: implemented, partially implemented, missing, unclear, deferred, or not applicable;
- code evidence;
- validation scenario;
- residual risk or open question.

Do not mark a requirement implemented only because a similar path is implemented. Confirm the relevant paths for that requirement.

### Session Note

Use `acumatica-session-notes` when iterative feature work needs session notes created, refreshed, or updated.

For feature work, keep notes focused on handoff context: specification source, branch or PR context, current scope, implemented slices, files changed, important design decisions, validation, unresolved questions, deferred items, and known risks.

## Iteration Workflow

Each iteration should be a coherent business slice that can be validated independently.

### 1. Refresh Context

1. Re-read the relevant Jira, Wiki specification, and comments when the user says they changed, when resuming after a long gap, or when a new slice depends on unexplored requirements.
2. Read `docs/ARCHITECTURE_RULES.md` and `docs/REFACTORINGS.md`; read `docs/BUSINESS_MODEL.md` and `docs/DATABASE_MODEL.md` only when they affect interpretation, design, branch choice, or validation.
3. Read `docs/FEATURE_IMPLEMENTATION_PATTERNS.md` when the iteration includes business logic, posting/recalculation paths, reports, projections, currency/base amounts, UI computed values, or customization-sensitive placement.
4. Use `system-diagnostics-analysis` when environment, version, customization, upgrade, schema, or branch-selection context can materially affect the slice.
5. Resolve repository, branch, PR, and baseline context before relying on code evidence.
6. Use `acumatica-session-notes` to update relevant notes if the source of truth, scope, or known risks changed.

### 2. Inventory and Classify Requirements

Identify normative requirements, examples, comments, unresolved comments, UI rules, data rules, edge cases, and acceptance criteria.

Classify each important requirement as:

- **Ready** - clear enough to implement.
- **Ambiguous** - multiple valid interpretations affect behavior or data.
- **Contradictory** - spec sections or comments conflict.
- **Deferred** - valid but outside current user-approved scope.
- **Rejected for current phase** - not appropriate for the current mode or risk level.

Ask for clarification only when implementation would be materially different depending on the answer. Otherwise make a conservative assumption and state it.

### 3. Trace Acumatica Data Paths

Before implementation, trace every requirement through the paths that can change the result. Use this checklist selectively, based on feature scope:

- document entry and defaulting;
- field events and validation;
- persist logic;
- release and posting;
- application, adjustment, reversal, voiding, and deletion;
- long operations and mass processing;
- recalculation, rebuild, and integrity-check processes;
- accumulators, project/base currency fields, and currency conversion paths;
- inquiry screens, side panels, dashboards, and selectors;
- reports, subreports, report DAC projections, and report data-source queries;
- workflow states and action availability;
- template/copy behavior;
- import scenarios and API/service entry points;
- cache invalidation and UI refresh behavior.

For report requirements, trace `rpx -> subreport -> report table -> DAC/projection -> source tables` before deciding whether to edit report layout or source queries.

Use [FEATURE_IMPLEMENTATION_PATTERNS.md](FEATURE_IMPLEMENTATION_PATTERNS.md) to structure this tracing and to identify parity risks between normal processing, recalculation, reports, projections, and UI computed values.

### 4. Plan the Slice

Before editing files:

1. State the selected business slice.
2. State what will not be touched in this iteration.
3. Identify the central extension points and affected data paths.
4. Identify customization impact and prefer overridable graph-level methods where useful.
5. Identify focused validation commands and manual scenarios.

Keep the slice small enough that a build and a manual acceptance scenario can give meaningful confidence.

### 5. Implement

Implementation should follow these Acumatica-specific rules:

- Keep normal processing and recalculation behavior aligned.
- For currency/base field pairs, follow existing DAC and accumulator patterns. Do not hand-roll conversion when framework currency logic should populate base fields.
- Prefer stable persisted flags, such as `Released`, over fragile status-string interpretation when business behavior allows it.
- Avoid DB queries in frequent UI events such as `RowSelected`; prefer `FieldSelecting`, cached values, persisted fields, or existing view data depending on behavior.
- Keep report layout unchanged unless layout work is explicitly in scope.
- Avoid broad refactors while implementing a requirement slice.
- Preserve existing user changes and unrelated dirty worktree state.

### 6. Validate

After each slice:

1. Run focused builds or checks that are meaningful for the changed files.
2. Run `git diff --check` or equivalent whitespace validation for code changes.
3. Search for equivalent code paths that may still miss the requirement.
4. Compare normal processing with recalculation/rebuild paths.
5. Recheck report/projection sources, UI computed values, and currency/base amount behavior when the slice touches those areas.
6. Provide manual validation scenarios when automated tests are not in scope.
7. Report any validation that could not be run.

### 7. Recheck Coverage

At phase boundaries or before declaring a feature phase complete:

1. Re-read the current specification source if it may have changed.
2. Update the requirement coverage matrix.
3. List implemented, partial, missing, deferred, unclear, and not-applicable requirements.
4. Identify whether missing items are true business gaps, test gaps, report-layout gaps, migration gaps, or intentionally deferred scope.
5. Use `acumatica-session-notes` to update relevant notes when needed.

## Stop Conditions

Stop and report instead of implementing when:

- requirement meaning is unclear and likely interpretations produce different persisted data or accounting results;
- specification comments contradict normative text and no later clarification resolves the conflict;
- the slice requires schema redesign, broad workflow changes, report layout work, migration, or large refactoring that was not approved;
- a high-risk accounting, posting, or recalculation change cannot be validated meaningfully;
- local architecture rules would be violated;
- branch, baseline, or repository context cannot be identified confidently.

## Recommended User-Facing Reports

During feature development, responses should be concise but explicit:

- current scope and excluded scope;
- business behavior implemented;
- key files or paths changed;
- validation run;
- known limitations;
- next recommended slice when useful.

For coverage reviews, use statuses consistently:

- **Implemented** - requirement is covered in relevant paths with code evidence.
- **Partially implemented** - core behavior exists but one or more relevant paths are missing.
- **Missing** - no implementation evidence found.
- **Unclear** - requirement or implementation mapping is ambiguous.
- **Deferred** - intentionally postponed by user or phase scope.
- **Not applicable** - confirmed not relevant to the current product mode, feature flag, branch, or scope.
