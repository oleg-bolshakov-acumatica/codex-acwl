---
name: source-code-analysis
description: Perform static Acumatica source analysis when a Support Request root cause remains unclear after Jira, related-item, and available database evidence. Resolve and verify the version-specific product branch, trace relevant code paths, and propose evidence-backed causes or reproduction scenarios.
---

# Source Code Analysis Skill

## Purpose

Use this skill to perform static source-code analysis for an Acumatica Support Request when higher-signal evidence did not establish the root cause.

The goal is to identify likely product code paths, safeguards, state transitions, missing checks, version-specific behavior, and plausible reproduction sequences. Code analysis can strongly support a hypothesis, but it does not prove the current customer's data state unless paired with Jira, SQL, Wiki, PR, or other direct evidence.

Use Jira, local docs, code search, SQL evidence, related items, linked Wiki pages, endpoint definitions, Generic Inquiry definitions, and reports to identify likely source entry points or affected paths.

Use `acumatica-git-workflow` for read-only branch/commit/PR discovery and its approval boundary for any Git operation needed to inspect the correct version.

When static analysis identifies a concrete defect anchor and the analysis needs to know which prior feature, ChangeRequest, PR, or commit introduced it, use `root-cause-origin-analysis` for the git archaeology. Do not treat the last `git blame` touch as origin without checking whether it actually introduced the defective logic.

## Trigger Point

Run this skill only after the main issue context has been exhausted or cannot be used:

- Jira title, description, and comments do not establish root cause;
- explicit linked issues and `jira-similar-search` do not provide a validated cause or workaround;
- database analysis is impossible, unavailable, too incomplete, or does not confirm/refute the hypotheses;
- standard product logic is still a plausible cause.

Skip this skill when:

- the issue is already confirmed as setup/customer data/customization and code cannot change the conclusion;
- the request only asks for a simple data check or workaround already supported by evidence;
- the local product repository or required branch cannot be safely resolved and the limitation is enough to answer the user.

## Repository Resolution

Default repository path:

```text
code
```

Before any Git or source-code evidence:

1. Verify that `code` exists and contains `.git`.
2. If `code` is missing or is not a Git repository, ask the user for the correct repository path.
3. Do not run Git commands from the agent workspace root unless that root is itself the product repository.
4. Use `git -C code ...` or set the shell working directory to `code`.

For Support Request investigation, treat the local product repository as an analysis checkout. Do not edit, stage, commit, or push product code. Any Git mutation needed to reach an item-specific branch requires explicit user confirmation.

Useful checks:

```powershell
Test-Path -LiteralPath code\.git
git -C code status --short --branch
git -C code branch --show-current
```

If the worktree has uncommitted changes, inspect and preserve them. Do not switch, stash, restore, reset, or clean without explicit user confirmation.

## Branch Selection

Use the system diagnostics branch-derivation rule when version-specific source analysis is needed. Use `system-diagnostics-analysis` first when DB version, customization, upgrade chronology, or schema discovery can materially affect branch selection or confidence.

Branch derivation rule:

```text
YY.RRR.xxxx or YY.RRR.xxxx-n -> 20YYrRRR
```

Example:

```text
25.201.0213-2 -> 2025r201
25.201.0213   -> 2025r201
```

Version source priority:

1. If a customer backup is available and the DB `[Version]` value was retrieved, use the database version for backup-specific code verification.
2. If DB version is unavailable, use Jira `Found in`.
3. If Jira and DB base versions differ, report the mismatch and use the DB version for backup-specific code paths.
4. If neither version is available, inspect the current branch only as general product-code context and report the limitation.

Before relying on code evidence:

- verify the current local branch;
- check whether the derived branch exists locally or remotely;
- inspect the derived ref, or switch to a branch proven by Jira/DB/PR evidence only after explicit user confirmation;
- report branch mismatch or unavailable branch in the analysis.

Static analysis on the wrong branch can still be useful for orientation, but must not be presented as version-specific evidence. Do not stop at the current branch just because Git needs additional local setup; request the needed Git operation and continue unless the branch cannot be resolved.

## Git Safety

Use `acumatica-git-workflow`. Run read-only status, ref, log, diff, worktree, and remote discovery automatically. Fetch, switch, checkout, stash, restore, reset, clean, or Git configuration writes require explicit user confirmation even in the analysis checkout; a generic request to analyze the Support Request is not confirmation.

Prefer inspecting refs without changing the checkout. If `safe.directory` or ownership prevents read-only inspection, request user-context execution. Do not change Git configuration without explicit confirmation. Never edit, stage, commit, merge, or push product code during this analysis.

## Static Analysis Entry Points

Start from the strongest clues already collected:

- screen ID: `PM301000`, `AP301000`, `AR301000`, etc.;
- exact error message or UI text;
- graph, DAC, table, field, action, event handler, workflow state, or report name;
- process name: billing, allocation, release, reverse, reclassify, retainage, transfer, import, recognition;
- document chain: AP bill, AR invoice, GL batch, PMTran, INTran, PO receipt, SO shipment;
- setup values and flags: billable, released, reversed, hold, non-project, account group, cost code, project task;
- customization names only as context unless custom source is available.

When those clues are incomplete, search local source, local definitions, linked Wiki pages, endpoint definitions, Generic Inquiry definitions, and reports to discover exact DACs, fields, related DACs, API/GI entities, and Help Wiki behavior before deeper source inspection.

Use `rg` first:

```powershell
rg -n "PM301000|Project Transactions|exact error text" code
rg -n "class .*Entry|PXAction|PXOverride|RowPersisting|FieldDefaulting" code\WebSites code\Pure code\DatabaseModel
rg -n "PMTran|AccountGroupID|Billable|CostCodeID|TaskID" code\WebSites code\Pure code\DatabaseModel
```

Prefer exact strings before broad class or table searches. If exact strings are localized or generated, search resource files, constants, exception keys, and UI labels.

## Acumatica Code-Path Heuristics

Follow the product flow from UI entry point to persisted data:

1. Screen or report definition: identify graph, primary DAC/view, actions, and visible fields.
2. Graph and graph extensions: inspect action handlers, release/reverse/reclass methods, delegates, PXLongOperation usage, and extension override order.
3. DAC and DAC extensions: inspect defaults, formulas, selectors, attributes, persisted fields, and projections.
4. Event handlers: inspect `FieldDefaulting`, `FieldUpdated`, `RowSelected`, `RowPersisting`, `RowUpdated`, and `RowPersisted`.
5. Workflow: inspect state transitions, action availability, and guards when the issue depends on status or action order.
6. Services/helpers: inspect shared methods that generate related documents or transactions.
7. Schema reference: use `DatabaseModel` / `Pure/DatabaseModel` for version-specific tables and columns when docs are insufficient.
8. Tests/specs: inspect tests when they exist for the suspected flow, especially around regressions and edge cases.

For Projects/Construction cases, pay special attention to:

- AP/AR/GL/PM/IN/PO/SO document-chain creation;
- original vs reversing transaction symmetry;
- reclassification and reversal paths;
- billable/non-billable propagation;
- account and account-group derivation;
- project, task, cost code, inventory item propagation;
- retainage, commitment, billing, allocation, and revenue-budget logic;
- release-time vs entry-time defaults;
- feature flags and setup conditions.

## Analysis Method

Use a narrow, evidence-driven loop:

1. Name the current hypothesis and the fact that would make it true.
2. Identify the likely entry point from screen/action/process/document flow.
3. Trace the write path to the affected field, status, relation, or generated document.
4. Trace reversal/reclass/release paths separately from original creation paths.
5. Inspect guard conditions, defaults, null handling, feature checks, and branch-specific behavior.
6. Look for asymmetry: a value set in original creation but not in reversal, correction, import, mass process, or long operation path.
7. Compare expected behavior from Jira/docs with actual code branches.
8. Stop when code can no longer change the hypothesis or when the next required evidence is data/runtime-only.

Do not read broad directories without a concrete clue. Use small targeted searches, then open the relevant files.

## Reproduction Scenario Output

When code suggests a plausible reproduction path, state it as a hypothesis unless already validated.

Include:

- screen/process/action;
- setup preconditions;
- required document state;
- action order;
- field values that trigger the branch;
- expected incorrect code path;
- what SQL/Jira/customer data would confirm it.

Example shape:

```text
Hypothesized reproduction:
1. Create an AP bill linked to a project task with <setup condition>.
2. Release it so PMTran is generated through <method/class>.
3. Reverse or reclassify through <action>.
4. The reversal path copies <field A> but does not recompute <field B>, so billing selection later treats the line as <state>.
Validation: compare original/reversal PMTran rows for <fields>.
```

## Root-Cause Confidence From Code

Use confidence carefully:

- **Confirmed**: code evidence plus current-case evidence proves the same path occurred.
- **Likely**: code contains a clear defect or missing branch matching the Jira symptom, but current-case data/runtime evidence is incomplete.
- **Unclear**: code search found possible paths but no decisive defect or the branch/version/source is uncertain.

Static code evidence alone normally supports **Likely**, not **Confirmed**, unless the Jira item itself provides a deterministic reproduction that the code directly explains.

## Source-Code Evidence and Report Format

Make each material code finding self-contained enough to verify without reconstructing the investigation.

Include for each finding:

- inspected branch or commit; if all findings use the same branch, state it once at the start of the section;
- full repository-relative file path;
- class, method, action, event handler, workflow element, or helper name when applicable;
- exact line number or compact line range from the inspected branch;
- short verbatim code excerpt in a fenced code block;
- concise explanation of what the excerpt proves or only suggests;
- limitations, especially branch mismatch, missing runtime data, uninspected customization code, or unvalidated database state.

Keep excerpts focused, usually 5-25 lines. Use several excerpts for a larger method. Preserve code verbatim; mark omissions with `...`.

Do not cite only a source link or file path when source code is material evidence for the conclusion.

Example shape:

````md
Code evidence: `code/PX.Objects/PM/PMRegisterEntry.cs`, `ReleaseDocument`, lines 421-438, branch `2025r201`.

```csharp
protected virtual void ReleaseDocument(PMRegister doc)
{
    ...
    tran.Billable = source.Billable;
    tran.AccountGroupID = source.AccountGroupID;
}
```

Finding: the release path copies `Billable` instead of recalculating it.

Impact on hypothesis: supports the proposed cause.

Limitation: SQL or a Jira reproduction is still needed to prove that the customer document used this path.
````

If source analysis is skipped, state the material reason, such as confirmed database evidence, unavailable required branch, or confirmed customization-only scope.
