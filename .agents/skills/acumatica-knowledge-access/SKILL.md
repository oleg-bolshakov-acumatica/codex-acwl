---
name: acumatica-knowledge-access
description: "Use this skill when Codex needs read-only Acumatica reference knowledge through the acumatica-knowledge MCP server: DAC fields and relationships, related DAC discovery, OData entities and navigation, Contract-Based REST API entities/schemas, Generic Inquiry XML/examples, and Help Wiki documentation search. Trigger on schema/API/GI/doc lookup, field relationship questions, data model discovery, endpoint shape questions, or when local docs/source are insufficient for Acumatica reference facts."
---

# Acumatica Knowledge Access

## Purpose

Use the `acumatica-knowledge` MCP server for read-only Acumatica reference lookup. Treat this as a reference source, not as current-case evidence by itself.

Prefer local source code and local docs when they directly answer the question for the inspected branch. Use Acumatica Knowledge when you need broader indexed reference context, fast schema discovery, API shape lookup, OData navigation paths, Generic Inquiry examples, or Help Wiki pages.

This resource enriches analysis when available. If the server or a specific lookup is unavailable, continue with the remaining approved context sources and state the limitation only when the missing reference fact could materially change the conclusion.

## Access Rules

- Use the `mcp__acumatica_knowledge__*` tools only for read-only lookup.
- Do not use this server to replace Jira, Wiki, source-change, or SQL workflows when a task-specific skill already provides a stronger evidence path.
- Treat search results as discovery. Open the exact DAC/entity/schema/page/example before relying on details.
- State when a conclusion is inferred from indexed knowledge rather than confirmed by current branch code, Jira, SQL, or runtime data.
- Do not treat an unavailable `acumatica-knowledge` lookup as a blocker unless the user explicitly requested this source and no alternate approved source can answer the question.

## When It Adds Value

Use Acumatica Knowledge as an optional preflight or cross-check when it can materially improve the active task:

- schema preflight before SQL or source-code analysis: DAC fields, keys, foreign references, and related DACs;
- API surface discovery: Contract-Based REST entity properties, actions, nested schemas, OData properties, entity sets, and navigation constraints;
- Generic Inquiry and report-source discovery: reusable GI examples, joins, filters, grouping, and navigation patterns;
- Help Wiki behavior lookup: product behavior, setup prerequisites, lifecycle rules, limitations, and screen-level guidance;
- requirement or review coverage: data paths that may be affected beyond the changed lines, such as import/API, inquiry/report/projection, billing, allocation, release, reversal, and rebuild paths.

## Lookup Guide

Use DAC tools for product data model questions:

- `search_dacs` for business concepts or table purpose.
- `get_dac` for exact DAC fields and references.
- `get_related_dacs` for foreign-key join paths.
- `search_by_field` when a field name is known but the owning DAC is not.
- `list_dacs_in_namespace` for module-scoped exploration.

Use OData tools for inquiry and navigation questions:

- `search_odata` or `search_odata_by_property` to find entities.
- `get_odata_entity` for properties and navigation.
- `get_odata_navigation` for `$expand` paths and referential constraints.

Use Contract-Based REST API tools for endpoint questions:

- `search_swagger` or `search_swagger_by_property` to find entities.
- `get_swagger_entity` for properties, endpoints, actions, nested objects, and detail collections.
- `get_swagger_schema` for nested/detail/shared schema definitions.

Use Generic Inquiry tools for GI design and XML examples:

- `search_generic_inquiry_examples`, `list_generic_inquiry_examples`, `search_generic_inquiries_by_dac`, or `search_generic_inquiries_by_field` to find examples.
- `get_generic_inquiry_example` to inspect a selected example.
- `explain_generic_inquiry_xml` to summarize a provided GI XML string.

Use documentation tools for Help Wiki reference:

- `search_docs` to find candidate pages.
- `get_doc_page` to open the selected page before citing it.
- `get_doc_image` only when an image reference from a doc page is materially needed.

## Output Guidance

Report only the facts needed for the active task. Include the exact DAC/entity/schema/page/example names used, and explain confidence limits when branch, version, customization, or tenant data could differ.
