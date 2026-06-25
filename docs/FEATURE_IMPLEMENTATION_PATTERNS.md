# Feature Implementation Patterns

This document captures reusable implementation patterns for Acumatica ERP feature work. It supplements [FEATURE_DEVELOPMENT_WORKFLOW.md](FEATURE_DEVELOPMENT_WORKFLOW.md) and does not replace the framework-level rules in [ARCHITECTURE_RULES.md](ARCHITECTURE_RULES.md).

## Purpose

Use this document when a feature requirement is clear enough to implement and the next risk is incomplete data-path coverage, inconsistent recalculation behavior, report-source leakage, or customization-hostile code placement.

## 1. Feature Slice Architecture

Implement a feature as a coherent business slice, not as isolated field or screen changes.

For each slice, identify:

- the business result that must change;
- the owning module and primary graph;
- affected DAC fields, projections, accumulators, reports, and processes;
- normal processing paths and rebuild/recalculation paths;
- UI surfaces that display or edit the result;
- extension points that should remain customizable.

Keep shared helpers narrow. Prefer graph or graph-extension `protected virtual` methods for feature behavior that may need customization. Use static methods only for pure utilities or framework-neutral calculations that do not depend on graph state.

## 2. Stored vs Derived Values and Source of Truth

Before adding or changing a field, aggregate, status, or displayed amount, identify the canonical source of truth.

Classify the value as one of:

- persisted business state;
- derived projection or formula value;
- recalculated summary or accumulator value;
- display-only UI value;
- report-only or inquiry-only read model value.

Guidelines:

- prefer an existing canonical source over introducing a parallel field;
- do not persist a value only to simplify UI or report code unless every update path can be identified and maintained;
- when a value is persisted, trace document entry, release/posting, import/API, correction, reversal, deletion, and recalculation paths that must update it;
- when a value is derived, verify that reports, projections, inquiries, APIs, and UI surfaces derive it from equivalent source data;
- record a non-obvious source-of-truth decision in the scope ledger, a session note handled through `acumatica-session-notes`, or the final implementation summary.

If two sources can disagree after normal processing, rebuild, or import, treat that as a feature design risk until the intended precedence is confirmed.

## 3. Data-Path Parity

Do not assume that implementing the entry screen covers the feature. Trace every relevant path that can create, change, reverse, rebuild, or display the same business value.

Typical paths to check:

- document entry, defaulting, and field events;
- persist logic;
- release and posting;
- application, adjustment, reversal, voiding, deletion, and correction flows;
- long operations and mass-processing screens;
- recalculation, rebuild, validation, and integrity-check processes;
- inquiry screens, side panels, dashboards, selectors, and GI/report sources;
- templates, copy actions, import scenarios, API/service entry points, and workflows.

When a value exists after recalculation but not after release, or exists after release but not after rebuild, treat that as a parity bug until proven otherwise.

## 4. Processing and Recalculation Consistency

Posting/release logic and recalculation/rebuild logic often use different queries and different source tables. Implement both intentionally.

Recommended checks:

- locate the primary transaction source for normal processing;
- locate the source used by recalculation or validation processes;
- verify that filters, grouping keys, sign handling, currency handling, and release-state logic match the business requirement;
- run or describe a scenario that compares normal processing against recalculation.

Do not copy a filter mechanically. Confirm that the source DACs represent the same business state.

## 5. Aggregations and Discriminator Fields

When a query aggregates amounts, preserve enough discriminator fields to avoid merging values that belong to different business buckets.

Common discriminator fields include:

- source module;
- document type or transaction type;
- released state;
- project, task, account group, account, inventory, cost code, and branch;
- currency information;
- original transaction references when reversal or adjustment logic depends on them.

If the requirement separates draft vs released, invoice vs payment, original vs adjustment, or AR vs non-AR behavior, the grouping and filtering must carry the fields that define those buckets.

## 6. Currency and Base Amount Fields

Follow existing Acumatica currency patterns before adding conversion logic.

Guidelines:

- inspect nearby DAC, accumulator, and projection fields for `Cury*` and base-amount pairing;
- map currency fields in accumulators when that is the established local pattern;
- let framework currency conversion populate base fields when existing attributes and accumulators are designed for it;
- avoid hand-rolled conversion unless the existing pattern cannot support the requirement;
- validate both normal processing and recalculation paths for currency and base values.

When a feature adds an amount, look for every place where equivalent amount fields are accumulated, projected, displayed, and recalculated.

## 7. Reports and Projections

For report-related requirements, trace the data source before changing report layout.

Use this path:

`rpx -> subreport -> report table -> DAC/projection -> source query/source tables`

Prefer fixing the report source query or projection when the business problem is that the report includes or excludes the wrong records. Edit report layout only when the requirement is about presentation, grouping, columns, labels, or formatting.

When a report uses a projection, check whether the same projection also feeds inquiries or other reports before changing it.

## 8. Exposed Surface Impact

Changes to DAC fields, projections, selectors, statuses, workflow actions, or server-side action behavior can affect consumers outside the screen being edited.

For material changes, check the likely exposed surfaces:

- reports, inquiries, side panels, dashboards, and Generic Inquiries;
- Contract-Based REST API, OData, import/export scenarios, and automation schedules;
- workflow action availability and server-side action preconditions;
- customizations that may override graph methods or depend on public fields and projections.

Use Acumatica Knowledge as optional reference discovery for OData, Contract-Based REST API, Generic Inquiry, and Help Wiki facts when local source does not show the exposed surface clearly. If that reference source is unavailable, document the limitation only when the missing exposure information can affect design or validation.

Do not expand the implementation slice merely to update every possible consumer. Separate confirmed required changes from exposed-surface risks, deferred validation, and out-of-scope compatibility work.

## 9. UI Computed Values and Cache Strategy

Avoid database queries in frequently fired UI events such as `RowSelected`.

Preferred options:

- use field attributes or formulas for invariant values;
- use `FieldSelecting` for display-only computed values;
- cache computed values when they depend on a small stable input set;
- persist the value only when many update points can be identified and maintained reliably;
- invalidate cache entries on field updates, row changes, and actions that can change the computed value.

Persisting a value can be correct, but it increases the number of release, adjustment, recalculation, import, and correction paths that must update it.

## 10. Customization-Friendly Business Logic

Business behavior should be placed where Acumatica customization can override it predictably.

Prefer:

- graph extensions for complete feature-specific behavior on a screen or process;
- `protected virtual` methods for behavior that may need replacement;
- `[PXOverride]` with a delegate parameter for base graph methods;
- local methods inside the graph/extension when the logic is used only there.

Avoid extracting behavior into static helpers or service classes just to reduce file size. Shared helpers are useful only when reuse is real and customization points remain available.

## 11. Validation Checklist

For each implemented feature slice, validate the paths that can prove the business behavior:

1. [ ] Build or run focused checks for changed code.
2. [ ] Run whitespace or diff validation for changed files.
3. [ ] Search for equivalent processing paths that may still miss the requirement.
4. [ ] Compare normal processing with recalculation/rebuild behavior.
5. [ ] Verify UI behavior on all relevant screens.
6. [ ] Verify report or inquiry data sources when the feature changes what users see.
7. [ ] Record skipped validation and residual risk in a session note handled through `acumatica-session-notes` or in the final report.
