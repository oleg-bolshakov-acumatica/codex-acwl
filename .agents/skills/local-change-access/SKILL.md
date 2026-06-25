---
name: local-change-access
description: Use this skill when you need the changed-file list, target branch, change state, and per-file diff hunks for a set of changes, using git over the local code/ repository. This replaces Bitbucket/PR access in the light workspace; a bare PR id/URL must first be mapped to a branch or commit range.
---

# Local Change Access Skill

## Purpose

Use this skill when the user wants to inspect a set of source changes - the equivalent of a pull request - as the changed-file list, base/target relationship, and per-file diff hunks.

In this light workspace there is no Bitbucket/Stash MCP path. Changes are inspected with read-only git over the local repository in `code/`.

This skill is read-only: it never commits, resets, cleans, pushes, or switches branches in a dirty working tree.

## Input contract

There is no Bitbucket MCP/facade service. Resolve the change to one of these git-addressable forms:

- a Stash pull-request id, via the remote's PR refs (preferred when only a PR id/URL is given - see "Resolve a PR id through Stash PR refs");
- a feature/topic branch name (for example `bugfix/AC-367880-2024r1`);
- a commit range or two refs (`<base>..<head>`, or `merge-base(base, head)..head`);
- a single commit id.

A bare PR id/URL is git-addressable in this workspace: the Stash remote of `code/` publishes per-PR refs (`refs/pull-requests/<id>/from`, `refs/pull-requests/<id>/merge`), so a PR id maps to a diff through git alone, without Jira. Use Jira Development panel data (via `jira-access`) only as a fallback to obtain the target branch when a PR exposes only `/from` (conflicting PR, no `/merge`). If neither a PR id, branch, nor range can be determined, ask the user for the branch name or ref range before proceeding.

## Resolve a PR id through Stash PR refs

The `origin` of `code/` is a Stash/Bitbucket-Server remote that publishes, per pull request:

- `refs/pull-requests/<id>/from` - the source-branch head;
- `refs/pull-requests/<id>/merge` - a merge-preview commit (present only for conflict-free PRs), whose first parent (`^1`) is the target-branch tip and second parent (`^2`) is the source tip.

Fetch both refs into a local `refs/pr/<id>/*` namespace (read-only with respect to the working tree; no branch switch, no commit):

```
git -C code fetch --no-tags origin \
  "refs/pull-requests/<id>/from:refs/pr/<id>/from" \
  "refs/pull-requests/<id>/merge:refs/pr/<id>/merge"
```

Then derive the diff:

- **If `/merge` exists**: the PR diff is `git -C code diff refs/pr/<id>/merge^1...refs/pr/<id>/merge^2`. The target branch need not be known separately.
- **If only `/from` exists**: obtain the target branch from the Jira Development panel or from the source-branch name (often visible in a merge commit subject such as `feature/AC-166093-2020r203-...`, which yields the source train), then `git -C code diff <target>...refs/pr/<id>/from`.

Derive the Jira key from the PR itself for intent/spec context: `git -C code log --format=%s refs/pr/<id>/merge^1..refs/pr/<id>/merge^2` (or `<target>..refs/pr/<id>/from`). Acumatica commit subjects carry the key (for example `AC-159830: ...`). A PR may touch several keys; prefer the key in the source-branch name as the primary one. If no key is recoverable, proceed without confirmed intent and state that limitation.

Map a branch-named "PR" (no PR id) to a branch/range using Jira Development panel data (via `jira-access`): take the source branch name, then `git fetch` and diff it locally.

## Resolve the repository first

The default repository location is `code`. Confirm it is a working tree with `git -C code rev-parse --is-inside-work-tree` rather than testing for a `.git` directory: `code/` may be a git worktree whose `.git` is a file pointing at the main repo, so a `test -d code/.git` check gives a false negative. If `code` is missing or is not a Git repository, ask for the correct repository path before relying on local Git state. Do not run Git commands from the workspace root unless that root is itself the configured Git repository.

Git topology is user-specific (original repository, worktree, or non-default path). Per the workspace **Environment Interaction Principle** (see `AGENTS.md`), establish the effective layout through dialogue once, reuse it for the session, and record it in session notes when the work may resume. Do not assume a fixed layout.

Run git with explicit `-C code` (or the resolved path), for example `git -C code status`.

## Workflow

1. Resolve the repository path and confirm it is a Git repo (`git -C code rev-parse --is-inside-work-tree`).
2. Resolve the change to git refs: for a PR id, fetch the Stash PR refs (see "Resolve a PR id through Stash PR refs"); for a branch/range, `git -C code fetch` the relevant remote/branch when needed (read-only with respect to the working tree).
3. Establish the baseline: for a PR with `/merge`, use `refs/pr/<id>/merge^1` as the target tip; otherwise `git -C code merge-base <base> <head>` to find the effective fork point.
4. List changed files: `git -C code diff --name-status <base>...<head>` (three-dot to compare against the merge-base).
5. Inspect per-file hunks: `git -C code diff <base>...<head> -- <path>`; prefer minimal, targeted hunks over full file dumps.
6. Read change metadata: `git -C code log <base>..<head>` for commit messages, authors, and dates; `git -C code show <commit>` for a single commit.
7. When a change is used as fix-lineage evidence for a Jira Bug, record the branch name, the base/target relationship, and the changed files. Use the target/base branch as fix-train evidence only; prefer Jira `Fixed In`, `Fix Version/s`, and QA verification comments for exact build availability.

## Important Rules

- Use this skill for a specific change set (branch or ref range), not for change discovery by Jira key.
- Treat the git diff hunks as the primary source for code-change analysis.
- Prefer normalized diff hunks over full raw file content.
- A merged target branch can help identify the version train where a Bug fix landed. It does not by itself prove a specific released build; do not replace explicit `Fixed In` or QA verification build evidence with branch inference.
- Open or in-progress branches that are not merged are not delivered-fix evidence unless a merge or Jira field confirms delivery.
- Never commit, reset, clean, push, or switch branches in a dirty working tree. Never discard user changes.

## Allowed git commands

Read-only inspection only, for example: `git status`, `git log`, `git show`, `git diff`, `git blame`, `git branch`, `git rev-parse`, `git merge-base`, `git ls-files`, `git remote`, `git fetch`, `git worktree list`, `git cat-file`, `git describe`. Follow the active Codex approval policy for command execution.

## Notes

- All git operations target the local `code/` repository, not the workspace root.
- This skill pairs with `source-code-analysis` (static analysis and git archaeology) and `jira-access` (to obtain branch names from Jira Development data).
- Technical contact: `oleg.bolshakov@acumatica.com`.
