---
name: bitbucket-pr-access
description: Inspect one specific Bitbucket/Stash pull request through the read-only bitbucket-internal MCP server. Use for pull-request metadata, changed files, bounded per-file diffs, comments and activities, commits, reviewer/task/merge evidence, or Jira fix-lineage evidence.
---

# Bitbucket Pull Request Access

## Safety and Access

Use only `bitbucket-internal`. Do not call Bitbucket REST directly, import provider modules, or use shell fallbacks. Never approve, comment on, merge, decline, or otherwise modify a pull request.

Read-only calls need no extra user confirmation when credentials are available.

## Resolve Pull Request Identity

The MCP calls require all three coordinates:

- `project_key`
- `repository_slug`
- `pull_request_id`

Parse them from a conventional Bitbucket pull-request URL when one is supplied. When Jira Development data exposes a PR URL or its coordinates, use that evidence. A numeric PR ID alone is insufficient unless the repository is already known; ask for a PR URL, repository coordinates, or a related Jira key rather than guessing.

## Workflow

1. Retrieve metadata with `get_pull_request` and record state, source and target refs, latest commit, author, and URL.
2. Retrieve `get_pull_request_changes` before loading diffs. Page changed files when the response indicates more results.
3. Retrieve `get_pull_request_file_diff` only for relevant files. Use `get_pull_request_diff` only when the whole capped diff is needed and report truncation or masking.
4. Retrieve `list_pull_request_comments` with bounded paging for discussion evidence. Use `list_pull_request_activities` when approval, resolution, or non-comment activity matters.
5. Retrieve `list_pull_request_commits` when exact fix lineage, backport candidates, or commit-level validation matters.
6. Retrieve `get_pull_request_jira_issues`, `get_pull_request_merge_status`, `list_pull_request_participants`, `list_pull_request_tasks`, or commit builds only when they can change the conclusion.

## Analysis Rules

- Treat changed files and per-file diff hunks as the primary code-change evidence.
- Keep remote PR evidence separate from local Git history. Use `local-change-access` or `root-cause-origin-analysis` when a local range, `path:line@commit`, or git archaeology is required.
- Treat pagination, response caps, truncation, warnings, and secret masking as evidence limits. Fetch a narrower page or file, or state the limitation.
- For fix lineage, record PR state, source branch, target branch, included commits, and changed files. A merged target branch indicates a fix train, not an exact released build.
- Open, declined, or abandoned pull requests are not delivered-fix evidence without separate confirmation.
