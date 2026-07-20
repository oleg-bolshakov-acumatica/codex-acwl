---
name: acumatica-bug-backport
description: Create a local Acumatica Maintenance Bug backport branch and commit from an already-fixed source Bug and an existing backport Bug. Use when asked to backport known commits into a Service Pack or Patch branch, including resolving the exact target, refreshing its remote ref, applying commits with cherry-pick, adapting conflicts safely, validating restrictions, and creating the final local commit. Stop after the local commit; do not change Jira workflow state, push, create pull requests, or manage cascade merges. All non-read-only Git operations require explicit user confirmation.
---

# Acumatica Bug Backport

## Purpose and Scope

Create one validated local backport commit for an existing backport Bug. Assume the source Bug is fixed, its commits exist, the backport Bug exists, and inclusion in a Service Pack or Patch has already been decided.

Finish with a local backport branch and commit. Do not create or modify Jira items, push, create or update a pull request, manage cascade merges, or independently redesign the source fix.

Use `jira-access` only to read the two Bug keys, summaries, links, target/fix version, and source Jira Development data. Map a source PR id/URL to its branch or commit range through Jira Development data, then use `local-change-access` to inspect the exact source change set. Use `acumatica-git-workflow` for all Git discovery, branch creation, formatting preservation, staging, commit, and approval rules.

## Resolve Inputs

Establish before changing Git state:

- repository path and remote;
- source Bug key;
- backport Bug key and concise summary;
- backport type: `Service Pack` or `Patch`;
- exact ordered source commit set, or a Jira-mapped branch/ref range from which to derive it;
- exact target remote branch;
- relevant build and test commands.

Prefer explicit user input, then Jira links and Development data, then verified Git evidence. Do not infer the target from the current checkout or derive a branch from a version string without confirming that the remote ref exists.

Stop when the backport type, source commits, target branch, repository, or ownership of existing worktree changes remains ambiguous.

## Select the Backport Type

### Service Pack

Use the exact release or Service Pack branch for the affected version. Check that the transferred change:

- introduces no breaking change to APIs, end-user workflows, or third-party integrations;
- contains no schema change beyond new fields, new tables, or field extensions;
- uses APIs and dependencies available in the older target version;
- does not depend on unrelated newer-version changes.

### Patch

Use the exact Patch branch, not a general release branch merely because its version looks related. Apply all Service Pack checks and additionally check that:

- upgrade scripts remain safe if applied without the corresponding library update and cannot corrupt the database or instance;
- the change avoids unjustified mass updates and expensive joins or subselects, especially over `GLTran`, `SOLine`, and `ARTran`;
- changes to Workflow Engine, critical or derived workflows, Multicurrency Graph, and Lot/Serial attributes receive explicit risk attention;
- risky behavior is protected by an appropriate feature flag and remains disabled by default when required;
- the backport contains only the minimum target-specific adaptation of the approved fix.

When changed files include `WebSites/Pure/DB/MSSQL/*.sql`, use `migration-script-consistency-review` before committing.

## Build the Read-Only Plan

Perform safe discovery before requesting confirmation:

1. Inspect worktree status, current branch, remotes, worktrees, refs, and existing task branches. Stop before switching when the worktree is dirty or ownership is unclear.
2. Resolve the source commits from explicit input, Jira Development data, and the Jira-mapped source branch/ref range. Verify that each commit belongs to the delivered source fix and order commits from oldest dependency to newest.
3. For a source merge commit, identify the underlying fix commits. Do not use `cherry-pick -m` unless the mainline parent and consequences are explicit and separately approved.
4. Inspect source diffs and dependencies with `local-change-access`. Include required companion changes and exclude unrelated changes.
5. Verify that every source commit object is available locally. If not, identify the exact source remote ref for a targeted fetch.
6. Resolve the exact target branch and query its current remote SHA with read-only remote inspection.
7. Check ancestry, history, and stable patch identity to avoid applying an equivalent change twice.
8. Propose `bugfix/<BACKPORT-JIRA-KEY>-<target-branch>[-short-slug]`.
9. Propose `<BACKPORT-JIRA-KEY>: <Task Description> - <Changes Description>`.
10. Present the repository, backport type, source commits, required fetches, target branch and observed SHA, task branch, commit message, validation plan, and exact state-changing commands.

The default result is one commit per backport Bug. Preserve multiple target commits only when a technical dependency or review requirement justifies it and the user approves the changed plan.

## Approval Gate

Request explicit confirmation after presenting the exact plan. A generic request to perform a backport is intent, not confirmation for unresolved Git mutations.

One confirmation may cover a fixed batch containing targeted source/target fetches, creation of one named local branch, `cherry-pick --no-commit` of the listed commits, and creation of the proposed local commit after successful validation. Ask again if the source commits, target, branch name, staged scope, commit message, or required operations change.

## Create the Branch

After confirmation:

1. Fetch any approved exact source ref needed to obtain the planned source SHAs and verify the fetched objects.
2. Fetch the exact target branch:

   ```text
   git fetch <remote> refs/heads/<target>:refs/remotes/<remote>/<target>
   ```

3. Verify and record the fetched target SHA.
4. Create the branch directly from the fetched ref:

   ```text
   git switch --no-track -c <backport-branch> <remote>/<target>
   ```

Do not create the branch from the current checkout or a stale local target branch. Prefer resuming a verified existing backport branch over creating a duplicate.

## Transfer the Fix

Apply the ordered source commits without creating their original commits:

```text
git cherry-pick --no-commit <sha1> <sha2> ...
```

Then compare the combined target diff with the source intent, confirm required and unrelated changes, check target-version compatibility and backport restrictions, and preserve formatting according to `acumatica-git-workflow`.

If a target-specific adaptation is necessary, stop before expanding scope. Explain the incompatibility, affected files, proposed minimal adaptation, and validation, then obtain confirmation for the revised plan.

## Handle Conflicts

Never resolve a conflict by blindly choosing `ours`, `theirs`, or a whole-file version.

1. Stop and inspect unmerged paths, source intent, target behavior, and nearby history.
2. Propose a minimal semantic resolution or abort, with affected files and validation.
3. Obtain explicit confirmation for the new state-changing operations.
4. Stage only approved resolved files and continue, or run an approved `cherry-pick --abort`.

Cascade processing is outside this skill.

## Validate and Commit

Before committing:

1. Inspect normal and staged status/diffs and exclude unrelated changes.
2. Run `git diff --check` and `git diff --cached --check`.
3. Treat disproportionate diffs as likely encoding, EOF, line-ending, BOM, or whitespace damage.
4. Run relevant target-version tests and build checks.
5. Run the applicable Service Pack/Patch checks and migration review.

Stop on failed validation, unresolved behavior, or an unsafe policy violation.

Create the approved local commit with source provenance in the body:

```text
<BACKPORT-JIRA-KEY>: <Task Description> - <Changes Description>

Source-Bug: <SOURCE-JIRA-KEY>
Backport-of: <source-sha-1>
Backport-of: <source-sha-2>
```

If Git identity is missing, stop; do not write Git configuration automatically.

## Stop Conditions

Stop when a required input is uncertain, worktree changes have unclear ownership, the target cannot be refreshed, an equivalent patch already exists, a merge commit lacks a safe interpretation, dependencies expand scope materially, a conflict/adaptation lacks approval, restrictions are violated, or validation fails.

## Report

Report the backport type and Bugs, source commits, target branch and fetched base SHA, local branch, final commit, adaptations, validation, residual limits, and explicit confirmation that no push, pull request, Jira workflow change, or cascade action was performed.
