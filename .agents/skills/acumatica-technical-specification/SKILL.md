---
name: acumatica-technical-specification
description: Create or update concise Acumatica ERP technical specifications from functional requirements and verified source or PR evidence. Use for technical design documents covering database changes, DACs, graph extensions, component dependencies and implementation flows, including authorized publication to Acumatica Wiki. Not for writing business functional specifications or performing a code review.
---

# Acumatica Technical Specification

## Purpose and depth

Explain the technical design so another engineer can understand data ownership, component responsibilities and significant interactions. Write in English unless the user requests another language.

Follow the user's reference document and explicit depth preferences. Clear content constraints already establish depth; do not require an abstract XS/L/XL classification before proceeding. For a plan-only request, present the proposed outline and wait for the requested approval.

Read [the document template](references/document-template.md) when drafting a specification or restructuring a substantial section. Read [Wiki formatting and diagrams](references/wiki-formatting-and-diagrams.md) when adding macros, diagrams or publishing content.

## Establish the design basis

1. Resolve the Jira item, functional specification, relevant implementation/PR or proposed design, destination and any supplied reference page. Reuse session context rather than asking again for known inputs.
2. Follow the repository's context-access routes: `jira-access`, `wiki-access` for reads, `bitbucket-pr-access`, and `acumatica-git-workflow` for local Git discovery. Resolve the source repository before relying on its branch or files. Use development guidance when it can clarify architecture; verify behavior in actual source.
3. Identify whether the document describes an implementation or a proposed design. Source code establishes existing classes, signatures and schema; the functional specification establishes business requirements. Clearly identify proposed technical artifacts instead of presenting them as existing code.
4. Inspect the reference's structure and native formatting, not only its prose. Check copied attachments and macros before reusing them; a copied diagram may belong to the original feature.

Resolve material contradictions with the user outside the published document. Continue independent drafting where possible, but do not turn an unresolved question into a settled technical contract. Keep investigation history and remaining questions in working notes, using `acumatica-session-notes` when appropriate.

## Sufficient detail, without excess

- Focus the document on Database Design, Solution Architecture and Solution Design. Link the functional specification instead of repeating its business scenarios, field-by-field UI behavior or acceptance criteria.
- Explain feature-specific decisions, boundaries and departures from standard Acumatica behavior. Omit tutorials about PXCache, BQL, routine persistence, standard UI controls and platform-owned behavior unless a specific design depends on a nonstandard use.
- Keep component descriptions short: name, type or host graph, purpose, and source link. Separate persistent DACs, virtual DACs, projections, cache extensions and graph extensions. Include existing components only where the feature changes them or relies on an important integration point.
- Distinguish physical table ownership from DAC names and logical relationships from physical SQL foreign keys. Capture meaningful keys, amount ownership and currency context without narrating standard audit attributes.
- Keep QA discussions, unresolved issues, abandoned approaches, session chronology and speculative improvements out of the specification. Do not imply that known contradictory behavior is resolved; obtain a decision or narrow the documented scope.
- Include customization, integration, quality and testing details only to the depth justified by the feature and requested template. Do not invent endpoints, extension hooks, tests or validation results to fill a heading.

## Code and diagrams

- For each new physical table, include its complete source SQL definition, including keys, constraints and associated indexes, in a titled, collapsed SQL Code Block. Include the complete corresponding persistent DAC source in a titled, collapsed C# Code Block. Preserve attributes, keys and members; a full definition must not contain omission markers introduced by the author.
- For existing tables, show the relevant schema additions or changes and link their source. Do not turn column declarations into an invented migration script or imply that documentation SQL should be executed.
- For other components, show selected significant members or non-obvious logic. Short signature-only excerpts are appropriate when implementation is routine; label them as signatures, not complete compilable definitions. Do not paste entire graphs merely because they are new.
- Link to the actual files in the relevant PR or verified source revision. Recheck that a linked file exists and that a copied block matches the stated source.
- Add a diagram only when it answers a distinct reading question. A data diagram explains relationships; a component diagram explains responsibilities and dependencies; a workflow diagram explains processing order. Group components at the level needed for the overview rather than duplicating the full component inventory.
- Prefer an editable native PlantUML macro when supported by the target Wiki. Use the practical examples and soft contrasting palette in the formatting reference. Treat those examples as adaptable patterns, not mandatory diagram counts, class counts or product designs.

## Publication workflow and authorization

This is a bounded, approval-gated Wiki publication workflow for technical specifications. The skill itself grants no write permission.

- A user request or approval to publish/update the identified specification page authorizes edits within that scope. Reuse that authorization across ordinary revisions; do not ask for generic permission again. A request for a plan, assessment or draft alone does not authorize a Wiki write.
- Use only the designated `wiki-internal` MCP tools for Wiki access and authorized writes. Honor repository restrictions and server policy; never use direct REST, browser scraping or another provider to bypass a rejected write. Documentation work does not authorize product edits, Git mutations or unrelated page changes.
- Before writing, reread the current page/version and comments. Use storage XHTML for macro-bearing pages. Prefer a targeted section update and preserve its nested headings, existing macro IDs, inline-comment anchors and unrelated content.
- If the page changed while drafting, reconcile the intended edits with that version rather than overwriting another author's work. Keep approvals unfilled and preserve the document's review status unless the user explicitly requests a status change.
- Read back the saved page, compare its diff and retrieve comments again. Check source blocks and diagram bodies as well as headings and links. Preserve a local source copy when the established workflow or user requires one; do not create unrelated artifacts or a second publication destination.

## Completion checks

Confirm that the document's schema, component roles, selected signatures and relationships agree with its stated design basis. For copied full definitions, compare the complete stored macro bodies with source, allowing only intentional newline normalization.

Check that macros remain native, source languages and collapse settings are correct, and diagram labels, arrows and colors are readable. A change confined to diagram styling must not alter document prose, code blocks, relationships or other diagrams.

Report the destination, saved version and meaningful changes. Distinguish saved-content verification from actual visual rendering or runtime validation; do not claim checks that the available tools did not perform.
