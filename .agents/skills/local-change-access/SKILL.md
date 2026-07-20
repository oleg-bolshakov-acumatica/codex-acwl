---
name: local-change-access
description: Use this skill when you need the changed-file list, target branch, change state, and per-file diff hunks for a set of changes, using git over the local code/ repository. This replaces remote PR access in the light workspace; a bare PR id/URL must first be mapped to a branch or commit range through Jira Development data.
---

# Local Change Access Skill

## Purpose

Inspect a specific source change as a changed-file list, base/target relationship, commit metadata, and per-file diff hunks. This skill is read-only and uses git over the local `code/` repository.

## Input Contract

Resolve the change to one of these git-addressable forms:

- a feature/topic branch name;
- a commit range or two refs;
- a single commit id.

When the user supplies only a PR id/URL, use `jira-access` first and map it through Jira Development data to the source branch and target branch or commit range. Do not resolve a bare PR through provider-specific PR refs. If Jira Development data cannot establish the branch/range, ask the user for it before inspecting code.

## Resolve the Repository

The default repository is `code`. Confirm it with `git -C code rev-parse --is-inside-work-tree`; do not require `.git` to be a directory because `code/` may be a worktree. If `code` is unavailable, ask for the correct repository path. Do not run product Git commands from the workspace root.

Git topology is user-specific. Establish the effective repository/worktree layout once, reuse it for the session, and record it in session notes when the work may resume.

## Workflow

1. Resolve the repository and change-set refs. For a PR id/URL, retrieve Jira Development data first.
2. Inspect status, current branch, worktrees, remotes, and available refs without changing state.
3. If required refs are absent locally, use `git ls-remote` for discovery. Route any proposed `fetch` through `acumatica-git-workflow` and obtain explicit confirmation before updating refs.
4. Establish the baseline with the Jira target branch, explicit user baseline, or `git merge-base <base> <head>`.
5. List changed files with `git diff --name-status <base>...<head>`.
6. Inspect targeted hunks with `git diff <base>...<head> -- <path>`.
7. Read commit metadata with `git log <base>..<head>` and inspect individual commits with `git show <commit>`.
8. Record the branch, base/target relationship, change state from Jira when available, and changed files when the change is used as fix-lineage evidence.

## Rules

- Use this skill for a specific branch/ref range, not for unconstrained discovery by Jira key.
- Treat diff hunks as the primary source for code-change analysis.
- Prefer targeted hunks over full file dumps.
- A target branch identifies a delivery train, not an exact released build; prefer Jira `Fixed In`, `Fix Version/s`, and QA verification comments for availability.
- Open or declined work does not prove delivery.
- Never commit, reset, clean, push, switch, fetch, or otherwise mutate Git state under this read-only skill. Use `acumatica-git-workflow` when a mutation is required.

## Read-Only Git Commands

Examples: `status`, `log`, `show`, `diff`, `blame`, `branch`, `rev-parse`, `merge-base`, `ls-files`, `remote`, `worktree list`, `cat-file`, `describe`, and `ls-remote`.

All commands target the resolved product repository, normally `code/`.
