---
name: acumatica-development-guidance
description: Retrieve read-only repository-specific Acumatica development guidance for architecture, repository layout, conventions, pitfalls, build/startup, testing, validation, code review, Modern UI, and TestSDK work. Use before or during Acumatica feature development, small bugfixes, code or test review, specification verification, source analysis, backport validation, or other work where indexed guidance for the `code` or `tests` repository can improve implementation or validation.
---

# Acumatica Development Guidance

## Purpose and Authority

Use the `acumatica-development-guidance` MCP server as optional repository guidance. It complements local instructions, source code, Jira/Wiki requirements, SQL evidence, and tests; it does not replace them.

Apply this precedence:

1. user instructions and repository `AGENTS.md`;
2. current Jira/Wiki requirements and approved local docs;
3. current branch code, tests, build files, and runtime evidence;
4. development-guidance articles.

When guidance conflicts with a higher-priority source, follow the higher-priority source and report the conflict. Do not treat an indexed article as proof of current-branch behavior, customer data, a product requirement, or fix lineage.

## Access

Use only the configured `acumatica-development-guidance` MCP server:

- `list_acumatica_knowledge_repositories` to discover canonical repository, project, area, and article counts.
- `list_acumatica_knowledge_articles` to inspect article metadata and obtain exact `resource_uri` values.
- `search_acumatica_knowledge` for semantic retrieval by task or risk.
- Read the exact returned MCP resource before relying on a guide's detailed instructions.

The server and its tools are read-only. Do not call ingestion, validation, or reindexing endpoints. Do not bypass the configured MCP path with direct HTTP or ad hoc scripts.

If the server is unavailable, continue with local docs, source code, tests, and the active workflow. Mention the limitation only when missing repository guidance materially affects implementation, review, or validation confidence.

## Retrieval Workflow

1. Identify the target repository and project from the task and local checkout: product work normally uses `repository = code`, `project = acumatica`.
2. Use `list_acumatica_knowledge_repositories` when the repository or project is uncertain.
3. Use lowercase canonical repository, project, and area values. Pass `target_branch` with exact case only when the branch is known.
4. Search with a narrow task-oriented query and appropriate areas: `architecture`, `conventions`, `pitfalls`, `testing`, `review`, or `limitations`.
5. Inspect several plausible results; do not assume the first semantic match is best.
6. Read each selected `resource_uri` in full. Consider `updated`, `confidence`, `owner`, `branch_masks`, `canonical_for`, `extends`, and `related_guides`.
7. Compare the guidance with current local instructions, code, build files, and branch-specific behavior before applying it.

## Workflow Routing

- For feature development and small bugfixes, retrieve guidance after task/spec and local context are resolved, before the implementation plan, and again when selecting validation.
- For code review and specification verification, retrieve only guidance relevant to the classified change shape and changed subsystems. Use it as review criteria, not as requirement evidence.
- For source-code analysis, use architecture, repository-layout, terminology, screen, or startup guidance only when it can narrow entry points or a reproduction path.
- For backports, use conventions and testing guidance only after the exact target and source fix are resolved. `acumatica-bug-backport` and `acumatica-git-workflow` remain authoritative for branch and approval rules.
- For Support Request analysis, use this skill only in source-analysis, reproduction, or fix-validation stages. It does not replace Jira, related items, SQL, or fix-lineage evidence.

## Safety and Result Use

- Do not execute Git mutations, stop processes, publish customizations, start services, or perform other state changes merely because a guide recommends them. Follow the active workflow's authorization boundary.
- Prefer the narrowest reliable validation recommended by both local context and applicable guidance.
- Treat missing or empty `branch_masks`, unknown owners, stale dates, low confidence, and mismatched subsystems as applicability limitations.
- When guidance materially influences the work, record the guide title/path and explain the implementation, review, or validation decision it informed.
- Report conflicts or material gaps; do not silently reconcile them by guessing.
