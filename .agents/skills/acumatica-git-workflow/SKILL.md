---
name: acumatica-git-workflow
description: Manage Jira-based Git workflows for Acumatica repositories. Use for read-only discovery of Jira-related branches, commits, and pull-request candidates, or to prepare, create, resume, stage, commit, or push feature and bugfix work. All non-read-only Git operations require explicit user confirmation.
---

# Acumatica Git Workflow

## Purpose

Provide one safe workflow for Jira-based Git discovery and task delivery. Keep read-only investigation automatic, but require explicit user confirmation before every Git state change.

## Approval Boundary

Classify the intended commands before running them.

Read-only Git operations do not require workflow confirmation. Examples include `status`, `diff`, `log`, `show`, `branch --show-current`, branch/ref listing, `rev-parse`, `merge-base`, `worktree list`, `remote -v`, and `ls-remote`.

Every non-read-only Git operation requires explicit user confirmation. This includes:

- `fetch`, `pull`, `switch`, `checkout`, and branch creation, deletion, or rename;
- `add`, `restore`, `reset`, `stash`, `clean`, `commit`, and `commit --amend`;
- `merge`, `rebase`, `cherry-pick`, and revert operations;
- `push`, worktree mutations, Git configuration writes, and history rewrites.

Apply these rules to local-only mutations too. A generic request such as "implement the fix" is not confirmation to change Git state. A request that explicitly names an operation, such as "create the branch" or "commit and push", is confirmation for that bounded operation.

One confirmation may cover a clearly enumerated batch, for example a targeted fetch followed by creation of one named branch. Ask again if the target, scope, or operation set changes. Runtime or sandbox approval is separate from workflow confirmation.

## Resolve Inputs

Before changing Git state, establish:

- repository path and remote;
- Jira key matching `[A-Z][A-Z0-9]+-\d+`;
- work type: `feature` or `bugfix`;
- target stable branch;
- whether an existing task branch should be resumed;
- the exact requested Git outcome.

Resolve the repository before Git commands. Use `code` only when it is a Git working tree; `.git` may be either a directory or a worktree pointer file. Otherwise ask for the correct path. Do not infer the stable branch from an arbitrary checkout or detached `HEAD`. Prefer explicit user input, then clear Jira target/fix-version or existing branch/PR evidence. Ask when evidence conflicts or remains insufficient.

## Read-Only Discovery

Start with read-only checks:

1. Inspect worktree status, current branch or detached state, remotes, worktrees, and relevant local/remote-tracking refs.
2. Search refs and commit subjects for the Jira key.
3. Use `jira-access` to retrieve Jira Development data, including branches, commits, PR identifiers, target branches, and states when available.
4. Map a bare PR id/URL to its branch or commit range through Jira Development data before code inspection. Do not derive a PR diff from provider-specific PR refs.
5. Use `local-change-access` for each selected branch, commit, or ref range. If required refs are absent locally, propose the exact targeted fetch and obtain confirmation before running it.
6. When current remote branch discovery matters, use `git ls-remote --heads <remote> "*<JIRA-KEY>*"`; it does not update local refs.

For review or fix-lineage analysis, consider material `open`, `merged`, and `declined` PRs exposed by Jira Development data. A declined or open PR does not prove delivery. Look for replacement or successor work when the history suggests one. If only a branch is found and no PR state can be resolved, report `branch found; PR state unknown` rather than guessing.

Summarize substantial discovery as:

| Branch | Evidence | Stable/base | PR | State | Relevance |
|---|---|---|---|---|---|

Omit the table when one sentence is clearer.

## Create or Resume a Task Branch

Prefer resuming a verified existing task branch over creating a duplicate. Do not invent a collision suffix or rename an existing branch without explicit user direction. If the branch is checked out in another worktree, report that before proposing a switch.

Use these branch forms:

```text
feature/<JIRA-KEY>-<stable>[-short-slug]
bugfix/<JIRA-KEY>-<stable>[-short-slug]
```

The optional slug may clarify the task but is not required. Keep the stable segment immediately after the Jira key.

For a new branch:

1. Confirm the target stable branch and proposed task-branch name.
2. Inspect dirty state and existing local, remote, and worktree refs.
3. Ask for explicit confirmation of the exact fetch and branch-creation operations.
4. Fetch the stable branch after confirmation. Prefer a targeted fetch in large repositories:

   ```text
   git fetch <remote> refs/heads/<stable>:refs/remotes/<remote>/<stable>
   ```

5. Verify the fetched remote-tracking ref and SHA. Do not create the task branch if the fetch fails, is declined, or cannot establish that stable is current.
6. Create the branch directly from `<remote>/<stable>` after confirmation:

   ```text
   git switch --no-track -c <task-branch> <remote>/<stable>
   ```

Do not create from the current branch merely because it is checked out. Do not set a task branch to track stable; set upstream only when pushing the same task branch.

## File Format Preservation

Preserve each existing file's character encoding and BOM, line-ending style, final-newline behavior, indentation, and unrelated whitespace. Inspect applicable `.gitattributes` and `.editorconfig` rules before editing. For new files, follow repository-controlled rules first, then nearby tracked files of the same type.

Before proposing a commit, inspect normal and staged diffs and run `git diff --check`. Treat a whole-file or disproportionate diff as likely formatting damage and correct unintended churn before staging or committing.

## Stage and Commit

Use this commit subject form:

```text
<JIRA-KEY>: <Task Description> - <Changes Description>
```

Before asking to stage or commit:

1. Inspect status and task diff read-only.
2. Separate task changes from unrelated user changes.
3. Run relevant validation and `git diff --check` when applicable.
4. Propose exact paths or hunks to stage and the full commit subject.

After explicit confirmation, stage only the approved task changes, verify the staged diff, and commit with the approved message. If staged scope or the message must materially change, ask again. Use the implementation Jira key that owns the code change. Do not use generic or WIP messages.

If Git identity is missing, stop and report it. Do not write local or global Git configuration without explicit confirmation.

## Push

Treat push as a separate mutation unless the user's confirmation already covered the exact branch and remote. Before pushing, verify branch, upstream, outgoing commits, and validation state read-only.

Push only the task branch. Never push stable. Do not force-push or rewrite history unless the user separately requests the exact operation and understands the risk. For the first approved push, set upstream to the same remote task branch when needed.

## Safety and Stop Conditions

- Preserve unrelated user changes; never silently discard, stash, reset, restore, or clean them.
- Do not switch in a dirty worktree when changes may conflict or ownership is unclear.
- Do not use destructive or history-rewriting Git operations as an implicit recovery step.
- Stop when repository, Jira key, stable branch, branch ownership, or requested mutation cannot be identified confidently.
- Prefer branch/ref inspection over changing the checkout when read-only evidence is sufficient.

## Report

Keep the result concise. Report only applicable fields: repository and baseline; discovered branches, commits, and PR states; approved and executed mutations; stable ref and fetched SHA; task branch and commit; validation and push state; unresolved ambiguity or blocked operations.
