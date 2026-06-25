---
name: wiki-access
description: Use this skill when the user asks to retrieve, inspect, or interpret Acumatica Wiki pages or wiki.acumatica.com links. In this light workspace Wiki is read through the corporate wiki-internal (Confluence) HTTP MCP server.
---

# Acumatica Wiki Access Skill

## Purpose

Use this skill when the user wants to retrieve or inspect Acumatica Wiki content from a `wiki.acumatica.com` page URL.

This skill is for read-only Wiki/Confluence access through the approved `wiki-internal` MCP server only. Do not use it for:

- page edits
- comment creation
- comment resolution changes
- attachment uploads
- permission changes
- direct Confluence/Wiki REST calls

## Access Path

In this light workspace Wiki access goes through the corporate `wiki-internal` (Confluence) HTTP MCP server. There is no PowerShell-facade Wiki tool here; the facade is read-only SQL only.

Call the `wiki-internal` Confluence tools directly. Do not ask the user for an extra confirmation step for the read-only tool call itself. Do not bypass the approved MCP path with Confluence REST or ad hoc shell-based access. If `/mcp` does not list `wiki-internal` or the call fails, treat it as an MCP configuration or authentication issue (OAuth on first use; Acumatica corporate network with private access enabled) and report degraded availability rather than bypassing the approved path.

Primary tool calls:

```json
{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"confluence_get_page","arguments":{"page_id":"259663876"}}}
```

```json
{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"confluence_get_comments","arguments":{"page_id":"259663876"}}}
```

Primary tool names:

```text
confluence_get_page
confluence_get_comments
```

Broader Confluence tools are available when the analysis needs them: `confluence_search`, `confluence_get_page_children`, `confluence_get_space_page_tree`, `confluence_get_labels`, `confluence_get_attachments`.

> Verify tool/argument names against the live `wiki-internal` server; adjust if the deployed Confluence MCP schema differs.

## Resolving a Wiki URL to a page id

`confluence_get_page` takes a `page_id`, but users usually provide a `wiki.acumatica.com` URL. Resolve the id before fetching:

1. Parse the numeric id from a canonical URL such as `https://wiki.acumatica.com/spaces/PC/pages/244409646/Title` - the id is the path segment after `/pages/` (here `244409646`).
2. If the URL has no embedded id (for example a vanity/short link), use `confluence_search` with the page title and space key (the `/spaces/<KEY>/...` segment) to resolve the id.
3. Then call `confluence_get_page` (and `confluence_get_comments`) with the resolved `page_id`.

## Workflow

1. Take the full Wiki page URL as input and resolve it to a `page_id` (see above).
2. Retrieve the page body and metadata with `confluence_get_page`.
3. Retrieve comments with `confluence_get_comments` when comments can affect interpretation; include footer and inline comments and their resolution state.
4. If the analysis needs broader Confluence capabilities (search across a space, page tree/children, history, labels, attachments), use the corresponding `confluence_*` tool.
5. Review page metadata and body first, then review comments.
6. Interpret inline comments together with their anchored selection and resolution status when the response supplies them.
7. Interpret footer comments in chronological order when discussion history matters.

## Important Rules

- Use this skill for Acumatica Wiki page retrieval, not for arbitrary web fetching.
- Only use approved Acumatica Wiki/Confluence hosts.
- Do not echo full page bodies or full comment payloads unless the user explicitly needs them.
- Prefer concise summaries with page title, relevant sections, comments, and unresolved/open context.
- Treat comments and resolution state as first-class context, not as optional decoration.

## Output Shape

The `wiki-internal` response follows the internal Confluence MCP tool schema. Depending on the tool, expect:

- page metadata (id, type, status, title, space key, version, updated/updatedBy, url);
- page body (storage and/or text representation, possibly truncated);
- comments (footer and inline), each with id, status, author, created/updated, body, anchored selection, and resolution status;
- and, for the broader tools, labels, attachments, page children/tree, or history.

## Server Coordinates

Wiki MCP server:

```text
wiki-internal -> https://wmcp.acumatica.com/mcp
```

All project MCP servers are declared at the workspace root in:

```text
.codex-mcp.json
```

The internal Wiki server uses streamable HTTP and requires OAuth on first use. It is only reachable from the Acumatica corporate network with private access enabled.

## Notes

- `wiki-internal` uses OAuth with the current user's Acumatica identity and inherits normal Confluence permissions. Do not use PATs.
- The MCP tool metadata marks `confluence_*` read tools as read-only. Ignore Confluence write tools if they appear but are not enabled by scope.
- Technical contact: `oleg.bolshakov@acumatica.com`.
- Prefer one concise status update before the lookup and one concise result summary after the lookup.
