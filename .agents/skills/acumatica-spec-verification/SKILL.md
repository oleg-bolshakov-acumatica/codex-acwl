---
name: acumatica-spec-verification
description: Use this skill when Codex must perform read-only verification that an Acumatica ERP pull request, branch, or implementation satisfies a functional specification. Trigger on requests to verify implementation against Jira or Wiki requirements, build a requirement coverage matrix, find defects before QA, or check whether code fully implements a functional spec.
---

# Acumatica Specification Verification

## Purpose

Verify implementation coverage against the most complete explicit functional specification. Do not modify code.

## Context Sources

Use repository-approved paths only:

- Use `jira-access` for Jira requirements, acceptance criteria, comments, and development metadata.
- Use `wiki-access` for linked `wiki.acumatica.com` functional specifications, including footer comments, inline comments, resolved comments, and resolution state.
- Use `bitbucket-pr-access` for implementation evidence in a specific pull request. Use `local-change-access` for a branch or commit/ref range via git over the local `code/` repository.
- Use `migration-script-consistency-review` when changed files include `WebSites/Pure/DB/MSSQL/*.sql`.
- Use `database-access` only when read-only SQL evidence can change requirement interpretation or verification risk.
- Use `acumatica-development-guidance` for repository-specific architecture, conventions, testing, validation, and review guidance that can improve coverage or risk assessment.

Do not use direct REST, provider modules, browser access, or ad hoc scripts for Jira, Wiki, Bitbucket, source changes, or SQL when the approved path is available.

## Specification Source

Jira requirements are sufficient only when Jira contains enough functional detail to verify implementation. If Jira is incomplete and a Wiki spec is linked or provided, use the Wiki spec as the primary requirements source. Jira acceptance criteria and PR descriptions supplement the spec but do not replace missing requirements.

If no sufficient specification source is available, ask the user for it before attempting requirement coverage verification.

Treat unresolved or contradicting Wiki comments as requirement ambiguity unless later context clearly resolves them.

## Required Local Context

Read and apply:

- `docs/ARCHITECTURE_RULES.md`
- `docs/REFACTORINGS.md`

Read domain, database, diagnostics, or source files outside the git diff hunks only when they affect requirement interpretation or implementation risk.

Use `docs/CODE_NAVIGATION.md` when coverage verification needs paths outside the diff hunks: it maps where affected-module data paths live -- entry, release/posting, inquiry/report, API/GI, workflow, migration, and tests. Verify these paths on the reviewed branch.

## Verification Scope Classification

Classify the verification before deep inspection and size the coverage effort accordingly:

- **Focused spec slice**: a small or narrow spec, a single requirement cluster, or a slice-sized PR. Verify the affected requirements and their directly related data paths; do not expand into full-feature coverage unless evidence shows broader scope.
- **Full feature spec**: a large or multi-area functional specification. Use coverage-oriented verification: decompose requirements into clusters and verify the relevant Acumatica data paths for each, not only the changed lines.

Keep functional requirement coverage separate from architecture/docs compliance regardless of classification.

## Workflow

1. Read Jira and PR context; derive missing Jira/PR references from development metadata when available.
2. Identify the specification source. Use Jira requirements when sufficient; otherwise locate and retrieve a Wiki spec.
3. Extract normative requirements, scenarios, constraints, UI/data/process rules, edge cases, and acceptance criteria. Distinguish requirements from examples, discussion, obsolete comments, and resolved comments.
4. Resolve PR/change set/branch and baseline. Treat PR file changes and per-file hunks as primary implementation evidence for a pull request; treat Git diff hunks as primary evidence for a branch/range. Use local files only when hunks are insufficient.
5. Check whether migration scripts changed. If yes, use `migration-script-consistency-review`; if no, record that no migration scripts were changed.
6. Read required local docs and optional docs only when useful. Use `acumatica-development-guidance` for exact repository articles relevant to the affected architecture, conventions, testing, review, or validation paths; do not treat guidance as specification evidence.
7. Build a requirement-by-requirement coverage matrix.
8. For implemented requirements, verify correctness, not just presence of code. Check edge cases, data flow, persistence, UI behavior, permissions/workflow impact, migration-script upgrade safety, tests, API/GI/inquiry/report surfaces, and regression risk to the degree supported by evidence.
9. For a full feature spec, use parallel verification tracks when they improve coverage; otherwise verify sequentially.
10. Produce findings for missing, partial, incorrect, ambiguous, or risky implementation.

## Parallel Verification Tracks

After the specification, requirement extraction, change set, baseline, and required local docs are resolved, independent read-only tracks may run in parallel (one `acumatica-review-track` subagent per track) when this improves coverage without losing shared context. This is most useful for a full feature spec; a focused spec slice is usually verified in a single pass.

Recommended tracks:

- **Spec Compliance**: verify a requirement cluster against the spec across its relevant data paths (entry/defaulting, validation, persist, release/posting, recalculation/rebuild, inquiry/report/projection, workflow, import/API, migration/upgrade, tests).
- **Architecture/Docs**: compliance with `ARCHITECTURE_RULES.md` and `REFACTORINGS.md`, kept separate from requirement coverage.
- **Migration/Schema**: when migration or schema files changed, via `migration-script-consistency-review`.
- **Domain/Data**: source-of-truth tables, API/GI/report surfaces, and version/tenant assumptions when they change the conclusion.

Do not parallelize unresolved prerequisites: specification discovery, requirement extraction, change set/baseline selection, or the final coverage synthesis. The final pass must merge all tracks into one requirement coverage matrix, remove duplicates, resolve contradictions, separate facts from hypotheses, and order findings by severity.

## Session Notes

Use `acumatica-session-notes` when verification is substantial and may resume or hand off (large feature spec, partial coverage pending re-check, or unresolved spec ambiguity). Record the specification source and version, the coverage matrix state, open ambiguities, and the established environment/branch context so the next pass does not re-derive them.

## Coverage Statuses

- **Implemented** - covered in relevant paths with code evidence.
- **Partially implemented** - core behavior exists but one or more relevant paths are missing or risky.
- **Missing** - no implementation evidence found.
- **Unclear** - requirement meaning or implementation mapping is ambiguous.
- **Not applicable** - confirmed irrelevant to the product mode, feature flag, branch, or scope.

Do not mark a requirement implemented without code evidence.

## Severity

Use normal review severities for correctness findings:

- **S0 Blocker**: clear specification violation, data corruption, broken invariant, guaranteed important regression, or unsafe persistence relationship.
- **S1 High**: missing critical requirement or edge case, risky production logic, mandatory architecture conflict, or important-path performance issue.
- **S2 Medium**: meaningful partial coverage, maintainability risk, limited domain mismatch, or non-critical inefficiency.
- **S3 Low**: minor test, naming, readability, or documentation gap.

## Output

Write the final verification report in English using this structure:

1. **Task Understanding** - Jira, PR, specification source, reviewed baseline, and verification confidence.
2. **Specification Coverage** - requirement, status, code evidence, and notes/risk.
3. **Correctness Findings** - highest severity first, using S0-S3 when a gap or defect is found.
4. **Architecture and Maintainability Notes** - only issues tied to `ARCHITECTURE_RULES.md`, `REFACTORINGS.md`, or implementation risk.
5. **Verification Limitations** - missing/ambiguous spec, unresolved Wiki comments, truncated Jira/Wiki/PR content, inability to map requirement to code, missing tests, or baseline uncertainty.
6. **Final Verdict** - one of: **Meets specification**, **Mostly meets specification with gaps**, **Does not meet specification**, **Cannot verify fully**.
