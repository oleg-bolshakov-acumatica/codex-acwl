---
name: wiki-access
description: Use this skill when the user asks to retrieve, inspect, or interpret Acumatica Wiki pages or wiki.acumatica.com links. In this light workspace Wiki is read through the corporate wiki-internal (Confluence) HTTP MCP server.
---

# Acumatica Wiki Access Skill

## Purpose and Safety

Retrieve and interpret Acumatica Wiki content through the approved read-only `wiki-internal` MCP server. Never edit pages, create or resolve comments, upload attachments, change permissions, or call direct Confluence/Wiki REST.

Call the `confluence_*` read tools directly without extra user confirmation when credentials are available. There is no Wiki tool in `powershell-mcp-facade`; do not substitute browser scraping, provider modules, or ad hoc scripts.

## Workflow

1. Prefer the full Wiki page URL.
2. Extract `page_id` from canonical `/pages/<id>/...` URLs. When no id is present, resolve it with `confluence_search` using the title and space key.
3. Retrieve body and metadata with `confluence_get_page`.
4. Retrieve comments with `confluence_get_comments` when comments can affect interpretation.
5. Use other read-only Confluence tools for space search, page tree, history/diffs, labels, attachments, images, downloads, or views only when those facts can change the answer.
6. Review metadata/body first, then footer and inline comments. Interpret inline selection and resolution state together when supplied.

Use the live MCP schema rather than duplicating its response catalog. Confirm that the result contains the required page body, metadata, and relevant comments.

## Rules and Failure Handling

- Use this skill only for approved Acumatica Wiki/Confluence hosts.
- Treat unresolved comments and their anchors as first-class specification context.
- Do not echo full pages or comment payloads unless the user explicitly needs them.
- If `wiki-internal` is unavailable or incomplete, report the missing context and effect on interpretation. Treat absence from `/mcp`, OAuth failure, or network failure as MCP configuration/authentication/private-network availability issues; do not bypass the approved path.
