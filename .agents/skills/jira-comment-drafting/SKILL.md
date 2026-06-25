---
name: jira-comment-drafting
description: Use this skill at the end of Acumatica Support Request analysis to propose ready-to-post Jira comment options that summarize confirmed findings, answer explicit questions already asked in Jira comments, explain likely root cause, related known issues, fix-lineage evidence, workaround steps, SQL detection/correction proposals, or missing validation. It must never post comments automatically.
---

# Jira Comment Drafting Skill

## Purpose

Use this skill after the Support Request analysis is complete to propose one or more Jira comment options for the user.

The goal is to turn the analysis into a concise, practical Jira-facing update without performing any Jira write action.

## Hard Gate

Do not post, update, or otherwise write Jira comments automatically.

Only draft comment text. The user decides whether to post it, edit it, or ignore it.

## Inputs

Use only facts already gathered during the analysis:

- current Jira title, description, comments, status, version, and request;
- explicit questions asked in Jira comments, including who asked, what they asked, and whether the analysis can answer it fully or partially;
- confirmed or likely root cause;
- related and similar Jira items;
- linked fixing Bugs, `Fixed In`, `Fix Version/s`, PR target branches, QA verification builds, and successor/reverting Bugs;
- SQL detection results or proposed SQL checks;
- confirmed workaround or proposed workaround;
- known uncertainty, missing evidence, or validation plan.

Do not introduce new claims while drafting a comment.

## Workflow

1. Identify whether the latest or most important unanswered Jira comment contains an explicit question. If yes, make the recommended draft a direct answer to that question.
2. Identify the comment goal: answer existing Jira question, same known issue, possible regression, confirmed workaround, SQL workaround, confirmed root cause, likely root cause, data request, customization/configuration impact, or no safe conclusion.
3. Produce one recommended ready-to-post Jira comment.
4. Add 1 to 2 alternatives only when materially different comments would be useful, for example "short customer-facing update" vs "technical internal update".
5. Keep comments concise enough for Jira. Prefer bullets over long paragraphs.
6. Separate confirmed facts from hypotheses.
7. Include issue keys, Bug keys, fixed versions/builds, and PR branches when they affect the conclusion.
8. For SQL workarounds, provide both detection and correction scripts when correction is proposed, but mark correction as proposal-only and require review, backup, and tenant scoping.
9. End the analysis report with the draft comment options. Do not ask for permission to post them unless the user explicitly asked for Jira write operations.

## General Comment Rules

- Write in clear support/dev handoff language.
- If answering an existing Jira question, start by directly answering it before adding evidence or context.
- Cite the source Jira item, Bug, SQL evidence, code path, PR, Wiki, or version evidence.
- Do not overstate confidence. Use "confirmed", "appears", "likely", or "requires validation" consistently with the analysis.
- If the root cause is unclear, say what is known and what validation is needed.
- If a workaround is risky, state review/approval requirements.
- If correction SQL is included, make it safe-by-default: tenant scoped, wrapped in a transaction, with validation queries and commented `COMMIT`.

## Template Selection

Use the most specific template that matches the analysis result.

### Answer Existing Jira Question

Use when a Jira comment asks a concrete question and the analysis can answer it fully or partially.

```text
Answering the question from <author/date or comment reference>:

<direct answer: yes/no/partially/not confirmed yet>

Basis:
- <evidence 1>
- <evidence 2>
- <related item / Bug / SQL / version evidence, if relevant>

Conclusion:
<what this means for the current case>

Next step:
<workaround / validation / fix version / data request / escalation>
```

If the answer is partial, say exactly what is confirmed and what still needs validation.

### Same Known Issue / Same Root Cause

Use when a prior Jira item or linked Bug matches the current symptom and root cause.

```text
I reviewed the case and found that the symptoms match <AC-XXXXX>.

Relevant match:
- Same scenario: <short scenario>
- Same symptom: <current symptom>
- Same affected entity/process: <PMTran/AP Bill/Project Billing/etc.>
- Prior root cause: <root cause from related item or linked Bug>
- Fix reference: <Bug AC-YYYYYY>, fixed in <versions/builds>

Based on the current evidence, this appears to be the same known issue rather than a new unrelated defect.

Current version/build: <current version>
Fix availability: <fixed version/build or PR target branch>

Recommendation:
<upgrade/hotfix/backport/regression check/validation step>
```

### Known Fixed Issue / Possible Regression

Use when the current environment appears to be at or after the fixed build or branch.

```text
The issue is similar to <AC-XXXXX> / <Bug AC-YYYYYY>, which was fixed in <fixed builds/versions>.

However, the current environment appears to be on <current version/build>, which is at or after the fixed build. Because of that, this should not be treated as the original pre-fix issue without additional validation.

Possible explanations:
- regression of the same logic;
- missing backport or patch difference;
- customization impact;
- data state not covered by the original fix;
- related successor issue: <AC-ZZZZZZ>, if applicable.

Recommended next step:
<specific validation: SQL check, code path check, reproduction on clean build, customization review, etc.>
```

### Confirmed Workaround

Use when a functional workaround was confirmed from Jira, related items, SQL/code evidence, or current-case analysis.

```text
A workaround was identified and appears applicable to this case.

Scenario:
<short condition where the workaround applies>

Workaround:
1. <step>
2. <step>
3. <step>

Expected result:
<what the workaround changes or avoids>

Risk/notes:
- <manual correction / business review / support oversight>
- <temporary until fixed in version X>
- <not applicable if condition Y is present>
```

### SQL Detection And Correction Workaround

Use when the workaround is a proposed data repair. Do not imply that the correction was executed.

````text
A data repair workaround can be considered, subject to review and approval.

Detection script:
```sql
-- Read-only validation. Scope by COMPANYID / tenant.
SELECT ...
FROM ...
WHERE ...
```

Expected detection result:
<what rows indicate the issue>

Correction script proposal:
```sql
-- Proposal only. Do not execute without backup, tenant validation, and approval.
BEGIN TRAN;

UPDATE ...
SET ...
WHERE ...

-- Validation after update
SELECT ...

-- COMMIT TRAN; -- enable only after review
-- ROLLBACK TRAN;
```

Notes:
- The script must be reviewed by support/dev before execution.
- Run against the affected tenant only: COMPANYID = <id>.
- Take a database backup before correction.
- This is a workaround/data repair, not the root-cause fix unless stated separately.
````

### Confirmed Root Cause / No Workaround

Use when the root cause is confirmed but no safe workaround is available.

```text
Root cause was confirmed.

Evidence:
- <Jira fact / SQL result / code path / linked Bug>
- <specific field/table/document chain>

Conclusion:
<confirmed root cause>

There is no safe functional workaround identified from the current evidence.

Recommended next step:
<create/link Bug, request fix, apply version with fix, prepare reviewed data repair proposal, etc.>
```

### Likely Root Cause / Needs Validation

Use when the analysis supports a likely cause but does not confirm it.

```text
The current evidence points to a likely root cause, but it is not fully confirmed yet.

Likely cause:
<short hypothesis>

Supporting evidence:
- <fact 1>
- <fact 2>
- Similar/related item: <AC-XXXXX>, relevance: <why>

Validation needed:
1. <SQL check / reproduction / log / setup check>
2. <version/fix-lineage check>

Until this is validated, I would not mark the case as a confirmed duplicate or confirmed product defect.
```

### Request For More Data

Use when the current facts are insufficient to confirm the cause or workaround.

```text
The current data is not sufficient to confirm the root cause.

Please provide/check:
- <backup/site URL/build>
- <document numbers>
- <screen/process steps>
- <customization packages>
- <logs/screenshots>

Why this is needed:
<short explanation tied to the current hypothesis>
```

### Customization Or Configuration Impact

Use when evidence points to setup or customization rather than a confirmed standard-product defect.

```text
The issue appears to be related to customization/configuration rather than a confirmed standard-product defect.

Evidence:
- <customization package / setup difference / SQL result>
- <expected standard behavior>
- <comparison with related item or clean environment>

Recommendation:
<disable customization for test / verify setup / reproduce in clean tenant / involve customization owner>
```

## Output Shape

In the final analysis report, add a section:

```text
## 11. Jira Comment Proposal

Recommended comment:
<ready-to-post comment>

Alternative comment, if useful:
<optional alternate version>
```

If no useful comment can be drafted, state why and provide the missing input needed to draft one.
