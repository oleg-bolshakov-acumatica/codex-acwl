# Technical Specification Structure

Use this as the default structure; the user's reference and requested sections take precedence. Keep paragraphs and component comments short. Remove authoring instructions and empty scaffolding from the delivered document, while leaving approval cells empty.

## Header and navigation

| Field | Content |
| --- | --- |
| JIRA | Link to the owning issue |
| Author | Known author; do not infer from an unrelated example |
| Status | DRAFT for a new draft, or preserve the current status |
| Func. Spec. | Direct link to the authoritative functional specification |
| Pull Request | Relevant implementation PR; include test PR only when useful |
| Approval | Leave for the reviewers |

Retain a requested Internal Team Approval table with empty approval/date/comment cells. On Wiki, use the existing details/status macros and an automatic Table of Contents; a maximum heading depth of two usually keeps navigation useful.

## Overview

One short paragraph explaining the capability and its purpose. Link the functional specification for business rules and detailed screen behavior. Add scope boundaries only when needed to understand the technical design.

## Database Design

### New table definitions

Summarize each new physical table with:

| Table / source link | Purpose and significant stored data | Key |
| --- | --- | --- |
| Actual table | Its role and data ownership | Actual primary key |

Add a data-relationship diagram when it explains the model more clearly than the table alone. Identify logical references, ownership and selection/transfer relationships accurately; do not draw every relationship as a physical foreign key.

Provide each complete SQL definition in a collapsed `sql` Code Block with the table name as title. Include associated indexes and constraints from the actual source. Standard columns can remain in the full source block without a separate explanation of platform audit/concurrency mechanics.

### Adjusting existing tables

Use a compact table of physical table, changed fields/constraints, SQL type/default and purpose. Verify DAC-to-table mapping rather than assuming their names match. Explain currency/base amount pairs when that distinction matters to the design.

A new discriminator value in an existing column is a semantic change, not automatically a new schema column or migration script. Record upgrade-specific design only when supported and relevant.

## Solution Architecture

Place a compact component diagram before the detailed inventory when it helps readers see host graphs, feature-owned extensions and shared mechanisms. Use dependency arrows here; processing order belongs in Solution Design.

| Component / source link | Type or host graph | Purpose |
| --- | --- | --- |
| Actual component | Graph, extension, DAC, projection or helper | One concise responsibility |

Group the inventory when useful:

- Graphs and graph extensions, including shared bases and their concrete uses.
- Persistent DACs, virtual DACs, projections, cache extensions and helpers.
- Significant changes to existing components and reports.

Provide complete C# source for persistent DACs corresponding to new tables in collapsed `csharp` Code Blocks. Keep these near their component descriptions or in a short Persistent DAC Definitions subsection.

For other components, place selected member signatures or a small meaningful algorithm beside the description. Preserve actual names, visibility, generic parameters, attributes and argument types. Mark signature-only excerpts explicitly. Nested BQL field classes do not need separate component-inventory rows.

## Customization Support

Briefly identify the actual feature-specific virtual methods, PXOverride hooks or injected contracts needed to understand extension boundaries. Avoid a generic explanation of Acumatica customization.

## Integration Support

Describe material integration boundaries and exposed contracts. Link relevant endpoint/schema definitions when they exist; do not invent request/response examples for a feature with no new API contract. Standard platform behavior needs detail only where this design changes or constrains it.

## Solution Design

Add a readable main-flow diagram when it clarifies processing. Choose activity or sequence notation according to the question; avoid repeating the data and component diagrams.

Use a few feature-specific subsections to explain:

- Which component owns an operation and the authoritative data.
- How significant data or control passes between components.
- Where calculation, transfer, release, application or rebuild boundaries matter.
- Any non-obvious algorithm or integration choice necessary to understand the implementation.

Prefer a short explanation plus a meaningful source excerpt over a transcript of methods, events, UI clicks or functional acceptance cases.

## Quality Attributes

Use only meaningful ratings with feature-specific rationale. Reliability, Performance, Security, Customizability and Integration are useful defaults; the requested template determines whether to retain all rows. A rating should explain a design consequence, not restate a platform guarantee.

## Unit Tests

Summarize actual unit-test coverage or confirmed plans, with links where useful. Distinguish unit tests, automated regression changes and manual QA evidence. A test PR link does not establish that unit tests exist or that a test run passed. Omit speculative test inventories and stale statements copied from the reference feature.

## Keep outside the published specification

Use the conversation or working notes for open questions, QA disputes, requirement coverage audits, build logs, pending validation, review findings and session history. Resolve a material design ambiguity before describing a contract as settled. The technical specification should remain a readable design document.
