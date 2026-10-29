---
name: acumatica-feature-final-review
description: Perform a read-only final review of an Acumatica ERP Projects/Construction feature after iterative development. Reconcile the final functional specification with delivered behavior, architectural consistency, and unnecessary complexity before handoff or merge.
---

# Acumatica Feature Final Review

## Purpose and Boundaries

Assess whether a Projects/Construction feature satisfies its latest functional specification and expresses one coherent, maintainable design after repeated implementation and requirement changes. Perform two required, independent passes: functional coverage and technical/architectural reconciliation. The technical pass must also examine whether the final design is proportionate to actual use and risk. A finding or limitation in one pass does not replace the other.

Derive business rules, invariants, data ownership, and lifecycle expectations from the current requirements and accepted design. Choose checks according to the feature's actual mechanisms. A previous feature's fields, states, defaults, storage choices, or fixes do not establish requirements for another feature.

Produce evidence-backed findings and a bounded remediation plan. This workflow is read-only for product code. Subsequent implementation follows `acumatica-feature-development` and the applicable approval boundaries, including approvals already given by the user.

Use `acumatica-code-review` for its baseline, severity, finding-evidence, and targeted Acuminator conventions; consult the relevant sections as supporting guidance. This skill owns both final-review passes. Use `acumatica-spec-verification` for detailed coverage methodology when useful, without treating it as a substitute for the architectural pass.

## Establish the Review Target

1. Resolve the final feature branch or PR, effective baseline, and intended review state. Distinguish a committed PR from the current local implementation. For a local feature review, account for its staged, unstaged, and new files while separating unrelated user changes.
2. Identify the feature's complete implementation across the relevant commits or PRs. Use history when it explains a design change, incomplete replacement, or abandoned approach; distinguish historical attempts from delivered behavior.
3. Retrieve the latest complete functional specification, accepted amendments, and material comments. When a QA Acceptance issue list or equivalent artifact is available or supplied, inspect the complete relevant set, including dispositions and material discussion. Its absence is not a prerequisite failure: review the specification and final implementation without inventing QA history. Separate approved, superseded, deferred, and unresolved decisions. Use session notes for navigation, then confirm their conclusions against current sources.
4. Read `docs/ARCHITECTURE_RULES.md` and `docs/REFACTORINGS.md`. Use `docs/CODE_NAVIGATION.md` before broad source discovery. Consult business, database, and feature implementation guidance when it affects a conclusion.

Follow the repository's approved context-access paths: `jira-access`, `wiki-access`, `bitbucket-pr-access`, and `acumatica-git-workflow` for their respective evidence. Use `acumatica-development-guidance` when indexed guidance can improve the review, and read the exact returned articles before relying on them. Use `database-access` only when data evidence would materially affect a conclusion; a temporary test database is not a routine input to this review.

Exclude temporary databases, backups, intermediate files, and earlier experiment results when they add no material context. They do not define requirements or delivered behavior. Preserve relevant runtime or validation evidence when it does materially affect a conclusion, and identify its environment and limits.

Report missing prerequisites and restrict conclusions to the evidence-supported scope. Without a sufficient final specification or a resolved implementation/baseline, provide only a clearly labeled partial review, not a final coverage verdict. Missing QA issues alone do not prevent a final review. Missing functional detail does not establish a defect or justify inventing expected behavior.

## Pass 1: Reconcile Functional Requirements and QA Feedback

Build a requirement-by-requirement coverage map from the latest specification. Trace each requirement through the relevant creation, editing, validation, persistence, release, inquiry/report, UI, and exposed-contract paths. Verify behavior rather than the mere presence of code; distinguish implemented, partial, missing, ambiguous, superseded, and explicitly deferred scope.

When QA Acceptance issues or an equivalent artifact exist, map each relevant issue to its accepted resolution and final code path. Check related paths that implement the same operation or business rule, not only the originally reported screen or condition. Treat QA reports as evidence of observed behavior and accepted changes, not as independent authority to redefine the specification. Keep external dependencies and user-approved deferrals visible without repeatedly proposing them as new fixes.

### Trace Implemented Restrictions and Messages Back to Requirements

Review coverage in the reverse direction as well: inventory feature-added or materially changed validations and restrictions, including attribute bounds/requiredness, selectors, eligibility filters, action availability, exceptions, warnings, and confirmation prompts. Include reused standard messages and implicit platform validation, not only new constants in `Messages.cs`. Group repeated enforcement of the same rule while checking that its conditions and outcome agree across entry points.

For each rule, establish its trigger, affected operations, rejection or warning behavior, and authority: an explicit current requirement; an identifiable accepted user/Product amendment; a necessary existing platform contract or data-integrity invariant; or an unsupported restriction. Confirm that a recorded stage proposal was actually accepted before using it as authority. When an accepted amendment is absent from or conflicts with the final specification, report the discrepancy and preserve its decision/deferment status; do not silently treat it as either a specification requirement or an invented check.

Audit message wording separately from rule validity. Locate the exact approved text in the requirement section or UI Strings table; distinguish approved wording from draft/review columns and superseded comments. Check field names, placeholders, document types, severity, and recovery instructions against the actual trigger. A valid check can have an incorrect message, and one shared message can misdescribe some of its call sites. Do not infer a business rule merely because a string appears in the UI table.

Flag restrictions that reject an otherwise supported scenario without a confirmed basis. Do not introduce stricter limits, new mandatory inputs, additional date/currency/status rules, or bespoke messages merely for convenience. Prefer existing platform validation and messages when they express the required rule; identify duplicate or unused validation/message code. Missing literal wording in the specification alone does not justify deleting referential-integrity, stale-data, retry, or internal-contract safeguards: explain their necessity, check available standard behavior, and separate technical diagnostics from additional business policy.

Keep a compact validation/message trace in the review notes: code location, condition, message identity/text, rule source, wording source, and disposition (keep, reuse standard behavior, correct text/trigger, remove, or resolve requirements). Summarize actionable gaps in the report; a full constant dump is not required.

## Pass 2: Reconstruct and Review the Technical Design

Build a lightweight internal map of the material business facts and responsibilities:

- authoritative entities and values, their owners, and relationships;
- stored values, derived values, snapshots, and the events that invalidate or refresh them;
- creation, update, validation, and persistence entry points;
- downstream processes, projections, queries, screens, and exposed contracts;
- applicable feature combinations, access boundaries, and lifecycle transitions.

Use this map to compare independently developed parts of the feature. Check that they agree on the meaning, timing, and ownership of the same data. Keep confirmed requirements, architectural constraints, implementation facts, and hypotheses distinguishable. Resolve contradictions from authoritative evidence or report an open decision.

## Apply the Relevant Acumatica Checks

Trace applicable paths beyond changed lines. Select checks from the feature map; do not require every feature to implement every mechanism below.

| Area | Questions to resolve |
| --- | --- |
| Architecture and responsibility | Are product-owned data and behavior placed consistently in DACs, graphs, and extensions? Are extension points and feature activation appropriate? Do multiple components implement competing versions of one rule? |
| Attribute and cache behavior | Do defaults, validation, formulas, currency precision, and recalculation use suitable platform mechanisms? Does field-level validation depend only on data reliable at that event, and are cross-field rules checked after the complete row is available? Do insertion and update preserve explicitly supplied editable values while copy/template paths reset the appropriate transactional state? Do supported writes invoke the necessary cache/attribute pipeline? Check event ordering, reentrancy, and side effects before recommending a different assignment method. |
| Persistence and schema | Reconcile physical DACs, projections, logical keys, SQL keys, foreign keys, types, lengths, precision, nullability, and relevant indexes. Distinguish physical DDL defaults for non-null columns from application/business defaulting in DAC attributes. Verify intentional exceptions. |
| Lifecycle and relationships | Follow applicable creation, modification, save, release/posting, cancellation, reversal, deletion, copying, repeated processing, and rebuild paths. Include reactivation/reopening when supported: do retained relationships remain valid and do checks still run after the status changes, including before the next save? Check reference ownership, stale results, transactional consistency, duplicate processing, and concurrent updates. |
| Background processing | Verify the keys and context crossing processing or long-operation boundaries, their persistence timing, and freshness checks. Determine what happens if source data changes before execution or processing is retried. |
| Queries and financial meaning | Compare sources and outputs in BQL, projections, GI, inquiries, and reports. Check units, currency context, signs, precision, joins, aggregation grain, and filter semantics. Derive the required monetary context from the feature; verify existing field semantics before introducing conversion. |
| Actions and selectors | Reconcile selection eligibility, action availability, and execution behavior for the complete selected set. Verify selector scope, substitute keys, descriptions, navigation, and access restrictions. Derive required server enforcement from business rules and supported entry paths. |
| UI and exposed contracts | Check relevant Classic/Modern UI definitions, import/export, Copy/Paste, APIs, OData, mobile, automation, and query consumers. Trace compatibility effects of changed names, codes, captions, references, and metadata. |
| Localization and lists | Verify user-facing captions, errors, action labels, list labels, and calculated values, including GI/projection outputs. Preserve the distinction between technical codes, localizable labels, and user-authored content. For changed DAC string lists, check whether the supported code-label `Pair` constructor expresses each mapping more safely than parallel arrays. |
| Features and permissions | Reconcile feature checks, FieldClass, workflow, screen/cache/action rights, role seeds, and entry points. Verify the intended access model across the feature's related artifacts. |

When migration SQL under `WebSites/Pure/DB/MSSQL/*.sql` is part of the change, use `migration-script-consistency-review`. Reconcile clean-install DDL, upgrade behavior, execution metadata, database applicability, and existing-data assumptions. Determine migration needs from delivery/version evidence; do not infer them from the feature's size or local database state. Record when no migration changes are present.

## Check Current Technical Conventions

For mechanisms changed by the feature, identify the current applicable technical standards before judging implementation style. Consult local architecture and database docs, current-branch analogues, and relevant Wiki guidance through `wiki-access`. For `DatabaseModel.sqlproj` DDL, check the current [SQL Formatting Standards](https://wiki.acumatica.com/pages/viewpage.action?pageId=278115719) and [Database Model Definition](https://wiki.acumatica.com/pages/viewpage.action?pageId=237967697), including their version and applicability; link to the guidance rather than copying its rules into this skill. Compare DAC field types, attribute stacks, list constructors, validation event placement, and other changed mechanisms with supported current-branch patterns.

If sources disagree, identify the exact rule, version, scope, and code behavior. Do not silently choose a broader or older rule over a current mechanism-specific standard, and do not turn a formatting preference into a correctness defect. Report a documentation conflict separately from a product finding when appropriate.

## Look for Accumulated Design Drift

Review the completed feature for artifacts left by earlier iterations:

- obsolete action declarations, handlers, view delegates, workflow/UI bindings, fields, or seed entries;
- duplicated validation, calculations, mappings, defaults, and inconsistent helper use;
- divergent state transitions for the same operation across screens, graphs, APIs, or lifecycle paths, especially after a narrow QA fix;
- edits that replace an explicitly supplied value with a default, or validation that observes a partly updated row;
- parallel sources of truth or incomplete replacements of a former implementation;
- temporary workarounds whose original constraint no longer applies;
- repeated queries in hot events, unnecessary cache scans, and unjustified persistence or abstractions;
- stale comments, names, and configuration that describe a previous design.

Verify references and the relevant framework mechanism before calling an artifact unused. For each simplification, explain the concrete reduction in risk or maintenance cost and how required behavior, extensibility, concurrency, and upgrade compatibility are preserved. Keep unrelated legacy cleanup and personal formatting preferences outside the remediation scope.

## Test Complexity Against Its Purpose

Make a separate proportionality pass over the final feature, including code added during QA fixes. Look for local solutions whose layers, generalization, defensive branches, stored state, or optimization exceed the demonstrated need. Examine abstractions with a single caller or implementation, configurable mechanisms used in one fixed way, repeated reconciliation or fallback paths, and caches or precomputation intended for rare workloads. These are prompts for investigation, not automatic defects.

For each candidate, establish its actual call sites and execution context, distinguish measured frequency from an inferred rare case, and identify the requirement or platform constraint it serves and the failure mode it prevents. Include Acumatica cache/event ordering, extension points, persistence, concurrent processing, and supported integrations when assessing whether apparent complexity is necessary. Compare the simplest viable implementation with the current one and state what would be removed, what behavior must remain, and what validation would establish equivalence. Do not demand benchmark data for a simple static conclusion, but do not claim an optimization is unnecessary solely because a rare case was not observed.

Classify the result as a warranted safeguard, a concrete simplification opportunity, or an unresolved tradeoff. Give a simplification finding only when its maintenance or behavioral cost is identifiable and a smaller design preserves the known requirements and constraints. Do not turn single use, line count, or personal style into a defect, and do not replace a platform-compatible solution with a shorter but unsafe one. Keep optional refactoring separate from correctness findings and prioritize it by expected benefit and change risk.

## Ground Recommendations in Existing Practice

For proposed framework or structural corrections, seek a verified analogue in the current branch's PM, CN, or PJ code. Use Distribution when a suitable P&C example is unavailable.

Cite the exact implementation and explain why its mechanism applies to this scenario. Similar names or shapes alone are insufficient. Compare relevant lifecycle, persistence, currency, and access assumptions. If no suitable analogue is verified, say so and support the finding with direct code, requirement, or framework evidence.

Reuse platform behavior where it satisfies the required semantics. Evaluate added fields, services, overrides, event handlers, and defensive branches by their demonstrated need; simplicity alone is not grounds to remove a necessary safeguard.

## Synthesize and Validate

Complete both passes before forming the verdict. For each applicable technical area, reach an evidence-supported conclusion or record a material limitation; do not mistake silence for a completed check. Group symptoms that share a cause, reconcile findings across surfaces, and order corrections by severity and dependency. Separate functional defects, architectural inconsistencies, current-guideline style gaps, accepted deferrals, and optional improvements. Recommend the smallest coherent correction for each cause.

On a repeat review, revalidate previous findings and pending corrections against the current tree and accepted decisions. State which corrections are valid, incomplete, or need revision, withdraw disproved findings, and provide one consolidated remaining remediation list rather than stacking successive reports.

Use targeted validation appropriate to the risk and the user's constraints. Distinguish static inspection, syntax parsing, semantic compilation, automated tests, and runtime evidence. Never present one as proof of another. Identify material unverified scenarios without requiring broad builds or speculative tests merely to complete a checklist.

Use `acumatica-session-notes` for substantial review handoff: preserve scope, accepted decisions, decisive evidence, remaining questions, and validation limits in the appropriate existing workstream.

## Report

Write in the user's requested language. Keep the report compact and actionable:

1. **Scope:** feature, final specification/version, available QA issue source or its absence, baseline, reviewed branch/PR state, and material exclusions.
2. **Functional pass:** summarize requirement coverage, validation/restriction and message traceability, QA issue reconciliation when available, accepted amendments/deferrals, and functional findings. Separate unsupported rules from wording mismatches and justified safeguards whose text is absent from the specification.
3. **Technical pass:** summarize the design/ownership assessment, applicable standards checked and their versions, architectural and guideline findings, the proportionality assessment (including justified complexity and concrete simplification candidates), and material areas checked without findings.
4. **Validation and limits:** report actual checks and uncertainties that affect confidence.
5. **Verdict and remediation order:** give distinct functional and technical conclusions, then an overall assessment and the corrections that belong together. Say explicitly when there are no findings; do not claim full readiness when material scope or requirements remain unresolved.

Order actionable findings by severity within their pass and follow `acumatica-code-review` evidence conventions. Include decisive `path/to/File.ext:line` references, a short excerpt where needed, the applicable requirement or rule, impact, a bounded correction, a verified analogue where applicable, and a validation scenario.

Report design questions as questions requiring resolution, and optional simplifications as optional. Review completion requires an evidence-supported conclusion for the agreed scope; the number of findings is not a completion criterion.
