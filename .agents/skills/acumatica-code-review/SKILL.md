---
name: acumatica-code-review
description: Use this skill when Codex must perform a read-only Acumatica ERP code review of a pull request, branch, or diff. Trigger on requests to review code, review a PR, inspect implementation quality, check architecture compliance, assess Jira/spec alignment, or evaluate migration-script, database, test, reliability, performance, and maintainability risk before merge.
---

# Acumatica Code Review

## Purpose

Review Acumatica ERP changes without modifying code. Prioritize bugs, regressions, requirement gaps, architecture violations, upgrade risks, and missing tests.

## Context Sources

Use repository-approved paths only:

- Use `local-change-access` to inspect a change set via git over the local `code/` repository. Accepted inputs: a Stash PR id/URL (resolved directly through the remote's PR refs - Jira is not required to obtain the diff), a branch name, or a commit/ref range.
- Use `jira-access` when a Jira key is provided or discoverable from change-set metadata.
- Use `wiki-access` for linked `wiki.acumatica.com` requirements.
- Use `jira-similar-search` only when explicit context is insufficient and similar issues can change the review conclusion.
- Use `database-access` only for read-only SQL evidence that can change the conclusion.
- Use `system-diagnostics-analysis` when version/build, customization, upgrade chronology, schema discovery, or source-branch selection can materially affect review confidence.
- Use `migration-script-consistency-review` when changed files include `WebSites/Pure/DB/MSSQL/*.sql`.

Do not use direct REST, provider modules, browser access, or ad hoc scripts for Jira, Wiki, source changes, or SQL when the approved path is available (Jira->jira-internal, Wiki->wiki-internal, source changes->git over local `code/`, SQL->sql.select facade).

## Required Local Context

Read and apply:

- `docs/ARCHITECTURE_RULES.md`
- `docs/REFACTORINGS.md`

Read these only when they can affect the review:

- `docs/BUSINESS_MODEL.md`
- `docs/DATABASE_MODEL.md`
- source files outside the git diff hunks

Use `docs/acuminator` as an on-demand diagnostic reference during the Acuminator diagnostic pass. Do not bulk-load the directory. Open only the exact `PX####.md` files that match suspicious changed-code patterns, and open `docs/acuminator/DiagnosticSuppression.md` only when reviewing or proposing Acuminator suppressions.

## Baseline Rules

Prefer `local-change-access` inspection when a change set is provided. Treat git diff hunks (over the resolved branch/ref range in `code/`) as the primary review source.

Resolve the input to a diff based on what was given:

- **Bare PR id/URL** - resolve through Stash PR refs (see `local-change-access`): fetch `refs/pull-requests/<id>/from` and `/merge`. When `/merge` exists, the diff is `merge^1...merge^2` and no Jira lookup is needed for the code. When only `/from` exists, get the target branch from the Jira Development panel or the source-branch name, then diff `<target>...from`. Derive the Jira key from PR commit subjects for intent/spec; if none is recoverable, review as **A2 Architecture-First** and state the missing intent as a limitation.
- **Jira key** - read the issue first (`jira-access`), take the PR id or branch from its Development panel, then resolve as above.
- **Branch name or commit/ref range** - inspect directly via `local-change-access`; derive the Jira key from the branch name/commits for intent.

If reviewing a branch or local diff:

1. Resolve the repository path first. The default path is `code`; confirm it with `git -C code rev-parse --is-inside-work-tree` (do not test for a `.git` directory - `code/` may be a worktree whose `.git` is a file).
2. Establish the effective baseline from merge-base to `HEAD`, from `merge^1` for a `/merge` PR ref, or from the user-provided branch relationship.
3. Do not switch branches in a dirty worktree unless the user explicitly approves.

When version-specific behavior matters, compare Jira `Found in`, database `[Version]` when used, and the inspected branch. Report branch/version mismatches as limitations.

## Review Depth

- **A1 Full Task-and-Code Review**: Jira or spec gives enough expected behavior, scope, and constraints. Review functional and architectural correctness.
- **A2 Architecture-First Review**: requirements are vague, business-domain confidence is limited, or the user asks mainly for architecture. Do not overstate functional correctness.

## Review Classification

Classify the PR before deep inspection. Use the classification to choose review shape and evidence depth:

- **Small Bugfix/Change Review**: narrow bugfix, support issue, low-risk change request, focused failing test, null/empty handling, mapping correction, validation gap, query/filter fix, or small regression. Keep the review root-cause, scope, edge-case, regression, and focused-validation oriented. Verify that the fix stays minimal and does not fan out into feature or architecture redesign.
- **Spec-Backed Feature Review**: large feature implementation or PR tied to a Jira/Wiki functional specification. Use coverage-oriented review: extract requirements, scenarios, edge cases, UI/data/process rules, and acceptance criteria; verify relevant implementation paths rather than only changed lines.
- **Architecture-First Review**: unclear or insufficient requirements, broad refactoring, or user request focused on architecture. Emphasize local architecture rules, Acumatica patterns, layering, extensibility, persistence boundaries, and maintainability. State functional limitations clearly.
- **Migration/Schema-Heavy Review**: PR where migration scripts or schema files can affect upgrade safety or data integrity. Treat migration/schema analysis as a first-class review track.

For spec-backed feature PRs, check coverage across the data paths that matter for the feature: entry/defaulting, validation, persist, release/posting, recalculation/rebuild, inquiry/report/projection sources, workflow, import/API, migration/upgrade, and tests. Do not mark a requirement covered only because a similar path is implemented.

For small bugfix/change PRs, do not expand the review into full feature verification unless Jira/Wiki evidence shows the PR is actually feature-sized or the implementation changes shared behavior broadly.

## Parallel Review Tracks

After change-set/Jira/spec context, changed files, baseline, and required local docs are resolved, independent read-only review tracks may run in parallel when this improves coverage without losing shared context.

Recommended parallel tracks:

- **Spec Compliance Track**: verify implementation against Jira/Wiki requirements, acceptance criteria, edge cases, and explicit linked issues.
- **Architecture Track**: verify compliance with `ARCHITECTURE_RULES.md`, `REFACTORINGS.md`, Acumatica extension patterns, persistence boundaries, and customization-sensitive placement.
- **Migration/Schema Track**: when migration or schema files changed, verify upgrade safety, tenant/data consistency, DAC/schema alignment, and DB-specific script consistency.
- **Test/Regression Track**: inspect test coverage, validation evidence, likely regression paths, and missing manual scenarios.
- **Domain/Data Track**: when domain docs, local source definitions, source-of-truth tables, or read-only SQL can change the conclusion, verify data relationships, API/GI/report surfaces, and version/tenant assumptions.

Do not parallelize unresolved prerequisites, branch/baseline selection, spec discovery, or final severity synthesis. The final pass must merge all tracks, remove duplicates, resolve contradictions, separate facts from hypotheses, and order findings by severity.

## Acuminator Diagnostic Pass

During code review, perform a targeted Acuminator diagnostic pass over changed Acumatica C# code. This pass is a manual static-pattern review using `docs/acuminator` as a reference; it must not depend on analyzer output already being available.

Focus the pass on changed code shapes that Acuminator commonly validates: graphs and graph extensions, DACs and DAC extensions, actions, views and delegates, event handlers, long operations and processing delegates, `PXOverride`, BQL/Fluent BQL usage, localization strings, custom exceptions, processing views, async/`Task` usage, and existing suppression comments or `.acuminator` suppression files.

When a suspicious pattern is found, open the matching `docs/acuminator/PX####.md` file for the exact rule, severity, exceptions, and suppression guidance. If the exact diagnostic cannot be identified quickly, rely on `ARCHITECTURE_RULES.md`, `REFACTORINGS.md`, and code evidence instead of scanning the entire Acuminator catalog.

Treat Acuminator diagnostics as supporting framework-rule evidence, not as a replacement for architecture or requirement review. If real analyzer output is available, use it as validation evidence. If analyzer output or the Acuminator documentation is unavailable, continue the review and mention the limitation only when it materially affects confidence.

Do not require cleanup of unchanged legacy diagnostics unless the PR touches the affected code path, the legacy pattern directly affects the changed behavior, or CI/static analysis would fail for the PR.

## Workflow

1. Read change-set/Jira context and relevant chronological comments.
2. Review explicit linked issues when they can affect expected behavior, branch selection, regression history, root cause, workaround, or scope.
3. Resolve change set/branch and baseline.
4. Retrieve relevant Wiki links through `wiki-access`.
5. Read required local docs and any optional docs that can change the conclusion.
6. Classify the review as Small Bugfix/Change, Spec-Backed Feature, Architecture-First, Migration/Schema-Heavy, or a deliberate combination.
7. Check whether migration or schema files changed. If `WebSites/Pure/DB/MSSQL/*.sql` changed, use `migration-script-consistency-review`; if `DatabaseModel/Application/**/*.sql` changed, manually verify DAC/schema consistency and upgrade risk against the local docs. If no migration or schema files changed, record that.
8. When a Jira/Wiki spec is available or the user asks for requirement verification, perform a two-stage review:
   - Stage 1: verify implementation against Jira/Wiki functional requirements.
   - Stage 2: verify implementation against architecture/docs constraints.
   Keep requirement gaps separate from architecture/style issues.
9. For spec-backed feature PRs, build a lightweight requirement coverage map before declaring coverage complete. For small bugfix/change PRs, focus on root cause, minimality, targeted edge cases, and validation.
10. Use parallel review tracks when applicable and safe; otherwise perform the tracks sequentially.
11. Perform a targeted Acuminator diagnostic pass over changed Acumatica C# code, opening only exact `docs/acuminator/PX####.md` files when a matching pattern or suppression needs precise interpretation.
12. Inspect functional correctness, architecture, refactoring/design quality, domain/database correctness, upgrade safety, reliability, performance, tests, and maintainability.
13. Synthesize all tracks into findings ordered by severity.

## Session Notes

Use `acumatica-session-notes` when a review is substantial and may resume or hand off (large or spec-backed feature PR, multi-track review left incomplete, or findings awaiting author response). Record the reviewed PR/branch and resolved baseline, the established environment/git layout, per-track status, and open findings so the next pass does not re-resolve context.

## Severity

- **S0 Blocker**: must fix before merge; clear requirement violation, data corruption, broken invariant, major architectural violation, security-sensitive flaw, guaranteed important regression, or incorrect persistence relationship.
- **S1 High**: serious issue; missing critical edge case, incomplete clear requirement, risky layering violation, fragile production logic, mandatory architecture conflict, or important-path performance issue.
- **S2 Medium**: meaningful maintainability, design, or correctness concern; refactoring smell, weak abstraction, avoidable complexity, limited domain mismatch, or non-critical inefficiency.
- **S3 Low**: minor readability, naming, small refactor, low-risk test, or documentation/comment improvement.

Use the lowest accurate severity.

## Finding Evidence Format

Write each finding as a self-contained, source-backed claim that the PR author can verify without reconstructing the investigation from scratch.

For non-trivial findings, prefer this structure:

~~~text
[Sx] Short problem title

Code evidence:
- path/to/File.cs:123
```csharp
minimal relevant code excerpt
```

Spec evidence:
- Functional Spec > Section heading > Requirement or acceptance criterion
> "Short quote from the source requirement."

Problem:
Explain the mismatch or defect.

Impact:
Explain the user, data, upgrade, or maintainability risk.

Recommendation:
State the concrete fix and the validation scenario.
~~~

- Every decisive code reference must include both file path and line number, formatted as `path/to/File.ext:line`.
- Include a short code excerpt when the problem depends on surrounding context, such as a condition, catch block, BQL query, DAC attribute stack, schema definition, migration SQL block, or persistence sequence. Keep excerpts minimal, normally 3-10 lines.
- For functional/spec findings, cite the exact Jira/Wiki requirement source: section number, subsection, heading path, acceptance criterion, requirement ID, or visible title. If no stable numbering exists, use the heading path and page version/date when relevant.
- Quote the shortest useful Jira/Wiki/spec fragment, usually one sentence or key phrase, so the author can find the source quickly. Do not paste large spec sections.
- For architecture findings, cite the local rule document and the decisive implementation line. Quote a short rule fragment only when it materially improves clarity.
- Separate `Spec evidence` from `Code evidence`; do not merge requirements, implementation facts, and interpretation into one paragraph when the finding is complex.
- If a requirement is inferred rather than explicit, say so and mark the confidence accordingly.
- Omit the spec block for pure code, schema, migration, or architecture findings that do not rely on Jira/Wiki behavior.

## Output

Write the final review using this structure:

1. **Task Understanding** - ticket/PR purpose, changed behavior, reviewed branch/PR, baseline, review mode, and business-validation confidence.
2. **Findings** - highest severity first. For each finding: `[Sx] Title`, evidence, why it matters, recommendation, and references.
   - Follow the Finding Evidence Format above for each non-trivial finding.
   - Include exact source links with file and line number for every code finding.
   - Add short code excerpts when surrounding context is needed to make the defect easy to find and verify.
   - For functional findings, cite the exact Jira/Wiki requirement source, quote the shortest useful source fragment, and cite the decisive implementation line.
   - For architecture findings, cite the local doc rule and the decisive implementation line.
3. **Review Classification and Coverage** - state the classification. For spec-backed feature PRs, summarize requirement coverage and important missing/partial/unclear areas. For small bugfix/change PRs, summarize root-cause confidence, scope minimality, and validation coverage.
4. **Two-Stage Coverage** - when Stage 1/Stage 2 review was used, summarize spec compliance separately from architecture/docs compliance. If one stage is limited, say why.
5. **Review Limitations** - missing requirements/docs, branch/version mismatch, skipped checks that affect confidence, unclear baseline/domain behavior, or review tracks that could not be completed.
6. **Positive Notes** - only if useful.
7. **Final Verdict** - one of: **Needs changes**, **Looks good with minor improvements**, **Looks good**. If there are no findings, say that explicitly.
