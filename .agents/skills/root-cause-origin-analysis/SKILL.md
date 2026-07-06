---
name: root-cause-origin-analysis
description: Use this skill to establish the origin of a bug: which prior feature, ChangeRequest, PR, or commit (and its Jira item) introduced the defective behavior, using read-only git history (blame, log -S/-G, show) over the local code/ repository, mapped to Jira through jira-access. Trigger on direct root-cause-origin / "which feature caused this bug" / regression-origin requests, and as the origin step of bug analysis before a fix plan. Always report an explicit result, including "origin not established" with the reason when it cannot be determined.
---

# Root-Cause Origin Analysis Skill

## Purpose

Establish where a defect came from: the introducing commit, the pull request that carried it, and the Jira item (feature, ChangeRequest, or Bug) behind that change, plus a concrete code link (`path:line@commit`) to the introducing change.

This skill answers "which feature/ticket caused this bug"; it does not propose or implement the fix. It is different from a fixing Bug: the origin item explains where the behavior came from; a fixing Bug explains where it was or will be corrected.

This skill is strictly read-only: read-only git and read-only Jira only. It never edits code, commits, pushes, switches branches in a dirty worktree, or discards user changes.

## Relationship to Other Skills

This is the shared, reusable methodology for origin analysis. Other skills delegate to it instead of duplicating the mechanics:

- `acumatica-support-request-analysis` - its "Root-Cause Origin Item Search" stage and the `## 6.5. Root-Cause Origin Item` report section use this skill's methodology.
- `acumatica-small-bugfix` - runs this skill to establish origin before the fix plan, and reports the result (or "not established").
- `source-code-analysis` - can identify the defect anchor and version branch used by this skill.

Dependencies used from here:

- `source-code-analysis` for repository/branch resolution and version-branch derivation.
- `jira-access` through `jira-internal` to confirm the origin Jira item's summary, type, status/resolution, and fix version.
- `local-change-access` to resolve the introducing PR or branch/ref range and produce the concrete change link when a PR is identified.
- `related-items-analysis` when the origin item connects to a broader chain of linked issues.

Do not bypass these paths with direct REST, provider modules, browser access, or ad hoc scripts.

## Trigger Point

Use this skill when:

- the user directly asks for root-cause origin, "which feature/ticket introduced this", or regression-origin analysis;
- a bug is being analyzed and the origin must be established before a fix plan, as invoked by `acumatica-small-bugfix`;
- source-code, git history, related Jira, Wiki/spec, PR context, or system diagnostics suggest the current behavior was introduced or materially shaped by a prior Jira item, feature, ChangeRequest, Bug, PR, migration, commit, or spec.

Skip or keep minimal when:

- the cause is confirmed to be customer data, configuration, or a customization, so no product-code origin applies; state origin as **Not applicable**;
- there is no concrete defect anchor to blame and one cannot be derived; state origin as **Not established - no anchor**;
- the origin cannot change root cause, workaround, fix applicability, regression assessment, or the answer, and searching would only add noise.

## Precondition: Defect Anchor

Origin analysis needs a concrete code anchor: the file, line(s), condition, BQL, DAC attribute, event handler, migration statement, or logic that produces the symptom. This normally comes from prior diagnosis (`source-code-analysis` or the bugfix diagnosis step).

If no anchor exists and cannot be derived, do not guess an origin. Report **Not established - no defect anchor** and state what would be needed, such as a reproduced code path, a stack frame, or an exact failing line.

## Repository and Branch Resolution

Resolve the repository first: use `code` only when it exists and contains `.git`; otherwise report the repository as unavailable and stop. Use `git -C code ...`; never run product git from the workspace root.

Blame reflects the version lineage of the branch it runs on, so establish the correct version branch before trusting results. Reuse the derivation rule from `source-code-analysis`:

```text
YY.RRR.xxxx or YY.RRR.xxxx-n -> 20YYrRRR   (e.g. 25.201.0213-2 -> 2025r201)
```

Version source priority: DB `[Version]` when a backup is analyzed > Jira `Found in` > current branch as orientation only. Report any branch/version mismatch as a limitation. Origin found on the wrong branch is orientation, not version-specific evidence.

The introducing change may predate the current branch, for example merged from an earlier release or mainline. When blame on the version branch bottoms out at a merge or branch point, follow history across the parent lineage rather than stopping at the branch tip.

## Methodology

### 1. Blame the anchor

```powershell
git -C code blame -L <start>,<end> -- <path>
```

This identifies the commit that last touched each line. It is the starting point, not necessarily the origin.

### 2. Distinguish "last touched" from "introduced"

The last-touch commit is often a reformat, rename, or unrelated edit. Escalate to find where the defective logic actually appeared:

- pickaxe by content: `git -C code log -S'<token>' -- <path>` when the token/string was added or removed;
- pickaxe by pattern: `git -C code log -G'<regex>' -- <path>` when a condition/expression changed;
- walk blame backward past a non-substantive commit: `git -C code blame <commit>^ -L <start>,<end> -- <path>`;
- handle moves/renames: add `-C -C -C` to `blame`, use `git -C code log --follow -- <path>`, and `git -C code log -M -C` to trace across file splits.

Converge on the earliest commit whose diff introduces the specific defective logic, such as a missing guard, wrong condition, wrong flag, broken link, or unsafe migration.

### 3. Read the introducing commit

```powershell
git -C code show <commit>
```

Capture the commit hash, author, date, and message. Acumatica commit messages and branch names usually reference a Jira key, for example `AC-######` or `PJ-####`. Extract the key(s).

### 4. Map commit -> Jira -> PR

- Confirm the Jira item with `jira-access`: summary, type (feature / ChangeRequest / Bug), status/resolution, and fix version. Verify the item's intent actually matches the introducing diff. Do not treat a bare key in a message as proof.
- Locate the introducing PR with `local-change-access` when a PR can be resolved, and produce the concrete change link: `path:line` at the introducing commit.
- If the commit has no Jira key, try the Jira development panel of the current issue and `git log` around the commit for an associated PR/branch. If still nothing is found, record the commit as the origin at code level and mark the Jira link **Unclear**.

### 5. Classify origin type

- **Regression** - the code worked before commit X and broke at commit X; blame plus `git show <commit>^:<path>` confirms the prior-correct state.
- **Latent since inception** - the introducing feature never handled this case; the defect existed from the feature's first commit.
- **Not code origin** - the cause is data, configuration, or a customization; product-code origin is **Not applicable**.

### 6. Classify confidence

- **Confirmed** - the introducing commit/PR/Jira diff directly contains the defective logic that produces the current symptom.
- **Likely** - git/Jira/PR evidence strongly points to the item, but the PR/spec details are incomplete or the mapping is indirect.
- **Unclear** - only a weak key, branch name, nearby-code, or generic requirement match exists.

## Output

Produce a self-contained, source-backed result. When origin is established:

- **Origin Jira item**: `<key>` - type, summary, status/resolution, fix version when available.
- **Introducing change**: commit `<hash>` (author, date); PR `<id/branch>` when resolved.
- **Code link**: `path:line@<commit>` with a short verbatim excerpt (about 3-10 lines) of the introducing diff/logic.
- **Origin type**: Regression | Latent since inception | Not applicable (data/config/customization).
- **Confidence**: Confirmed | Likely | Unclear.
- **Evidence trail**: the blame/pickaxe/show steps that connect the anchor to the introducing change, and how the introducing diff maps to the symptom.
- **Distinction from fixing Bug**: name the fixing Bug separately if one exists; never present the origin item as the fix.

When origin cannot be established, say so explicitly. This is a required output, not silence. State the reason and what was tried:

- **Not established - no defect anchor** (no concrete code location to blame);
- **Not established - history unavailable** (shallow clone, squashed/imported history, change predates available history, repository/branch unavailable);
- **Not established - no Jira link** (introducing commit identified but carries no resolvable Jira key/PR);
- **Not applicable** (cause is data/config/customization, not product code).

Never assert a Jira ticket as the origin from a commit-message match alone. The introducing change must actually contain the defective logic.

## Safety

- Read-only git only: `blame`, `log`, `log -S`/`-G`, `show`, `diff`, `merge-base`, `rev-parse`, `cat-file`, `for-each-ref`, and `fetch` for read-only ref discovery. No commit, reset, clean, push, or branch switch in a dirty worktree.
- Read-only Jira only, through `jira-access`.
- Keep facts and hypotheses separate; mark confidence honestly.
- Origin evidence explains where behavior came from; it does not by itself prove the current customer's data state.
