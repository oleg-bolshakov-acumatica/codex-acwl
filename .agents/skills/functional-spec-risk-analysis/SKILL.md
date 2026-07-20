---
name: functional-spec-risk-analysis
description: Analyze an Acumatica Jira/Wiki functional specification before implementation for contradictions, ambiguity, lifecycle gaps, source-of-truth conflicts, and architecture feasibility. Use for spec risk review, data-model challenge, implementability assessment, or clarification questions before development or QA planning.
---

# Functional Spec Risk Analysis

## Purpose

Use this read-only workflow to evaluate a functional specification as a product/architecture artifact, not to verify an existing PR and not to implement code.

The goal is to decide whether the spec is internally consistent, technically implementable in Acumatica, and specific enough for development and QA.

## Required Context

Use repository-approved context paths:

- Use `wiki-access` for `wiki.acumatica.com` specifications, including footer comments, inline comments, and resolved comments.
- Use `jira-access` when a Jira key is present or discoverable from the spec.
- Pick the source-specific path directly: `jira-access` for Jira, `wiki-access` for Wiki, and `local-change-access` for a change set.
- Read `docs/ARCHITECTURE_RULES.md` and `docs/REFACTORINGS.md`.
- Read `docs/BUSINESS_MODEL.md`, `docs/DATABASE_MODEL.md`, `docs/FEATURE_IMPLEMENTATION_PATTERNS.md`, or source code only when they can change the implementability conclusion.
- Use read-only SQL only when concrete data evidence is necessary; do not use SQL for speculative design.

Do not use direct REST, browser scraping, ad hoc provider scripts, or write operations for Jira/Wiki/DB context.

## Workflow

1. Identify the spec source, Jira issue, product version, status, update date, and whether the page is draft/approved.
2. Extract normative requirements from examples, discussion, UI mockups, and comments. Treat unresolved comments as first-class ambiguity.
3. Restate the task in business terms: what user-visible behavior changes, what source-of-truth data is involved, and what is explicitly out of scope.
4. Use local source, endpoint definitions, Generic Inquiry definitions, reports, and linked Wiki documentation when exact DAC/API/GI/OData/Help Wiki facts can test whether the proposed model or behavior conflicts with existing Acumatica structures or documented behavior.
5. Check internal consistency:
   - undefined states or terms, such as "approved", "released", "current", "historical", or "reliable";
   - conflicting inclusion/exclusion rules;
   - requirements that imply persistence while another section says no referential integrity or no database impact;
   - future-extensibility statements that conflict with the proposed current data model;
   - upgrade, correction, reversal, deletion, import, API, and rebalancing behavior that is omitted or inconsistent.
6. Check Acumatica implementability:
   - prefer source-of-truth data over duplicated persisted state;
   - avoid DB queries and heavy business evaluation in `RowSelected`;
   - place validation in field events, row persisting, workflow actions, release/posting, or processing flows as appropriate;
   - use BQL/Fluent BQL and PXCache patterns, not direct SQL;
   - preserve graph extensibility with virtual methods or graph extensions where customization may be needed;
   - check normal processing and recalculation/rebuild parity;
   - check API, import, correction, reversal, delete, and long-operation paths when the spec creates derived values or relationships.
7. Separate facts from hypotheses. Do not call a concern confirmed unless it is supported by the spec, comments, docs, code, or read-only data.
8. Produce concrete clarification questions or spec wording changes when a concern can be resolved by tightening the spec.

## Risk Heuristics

Escalate concern severity when a requirement:

- creates new persisted state only for visibility and would need broad lifecycle maintenance;
- requires multi-record or database analysis on display events;
- introduces a source of truth parallel to AR/AP/PM/pro forma/budget data;
- cannot define a stable key, uniqueness rule, or delete/correction behavior;
- depends on ambiguous workflow states;
- requires future split/multiple ownership but proposes a single-reference field;
- changes project, budget, pro forma, AR, or workflow totals despite claiming non-regression;
- omits recalculation/rebuild behavior for values also maintained during normal processing.

Use severity labels when useful:

- **High**: likely to cause wrong implementation, data inconsistency, upgrade/recalculation defects, or expensive redesign.
- **Medium**: unclear or incomplete enough to affect development or QA scope.
- **Low**: wording, naming, or test-coverage clarification with limited implementation risk.

## Output

Use the user's language unless they request otherwise.

Recommended structure:

1. **Task Understanding** - spec/Jira source, status, goal, and confidence.
2. **What Is Being Proposed** - concise business and technical restatement.
3. **Consistency Risks** - requirement contradictions or ambiguities, each with evidence, risk, and comment.
4. **Implementability Risks** - Acumatica architecture concerns and preferred implementation direction.
5. **Clarification Questions / Suggested Spec Changes** - concrete wording or decisions needed.
6. **Verdict** - one of: **Ready for implementation**, **Needs clarification before implementation**, **Technically risky as written**, or **Cannot assess fully**.

When the user asks for controversial fragments, include short exact quotes from the spec and keep each quote tied to one risk and one recommendation.
