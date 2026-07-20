---
name: jira-comment-drafting
description: Draft a concise, ready-to-post Jira comment at the end of Support Request analysis. Use for direct answers, causes, known issues, fix lineage, workarounds, SQL proposals, or missing validation. Never post comments automatically.
---

# Jira Comment Drafting Skill

## Purpose

Use this skill after Support Request analysis to turn established facts into one concise Jira-facing update without performing any Jira write.

## Hard Gate

Never post, update, or otherwise write Jira comments. Draft text only; the user decides whether to post, edit, or ignore it.

## Inputs

Use only facts already gathered during the analysis:

- current Jira context and explicit questions in its comments;
- confirmed or likely root cause and root-cause origin;
- related/similar items and fixing Bugs;
- fixed versions/builds, PR target branches, and successor/reverting Bugs;
- SQL/code evidence, detection checks, and correction proposals;
- confirmed/proposed workarounds, uncertainty, and validation needs.

Do not introduce new claims while drafting.

## Workflow

1. If a Jira comment contains an unanswered explicit question, make the recommended draft a direct answer.
2. Select the goal: direct answer, same issue, possible regression, workaround, SQL repair proposal, cause, data request, configuration/customization impact, or no safe conclusion.
3. Produce one recommended ready-to-post comment; add 1-2 alternatives only when they serve materially different audiences or goals.
4. Keep it concise, separate facts from hypotheses, and include issue keys, versions/builds, and PR branches only when they affect the conclusion.
5. For correction SQL, include a read-only detection query and a proposal-only correction script with backup, review, tenant scope, validation, and commented `COMMIT` safeguards.
6. End the analysis report with the draft; never imply it was posted.

## Comment Rules

- Start with the direct answer or conclusion.
- Cite underlying Jira, Bug, SQL, code, Wiki, change-set, and version evidence.
- Match confidence language to the analysis: confirmed, likely, appears, or requires validation.
- State material workaround risk and missing validation.
- For known issues/regressions, compare the current version with `Fixed In`/`Fix Version/s`; use the PR target only as fix-train evidence.

## Template Selection

| Goal | Required emphasis |
|---|---|
| Answer an existing question | Direct answer first; confirmed and missing parts |
| Same known issue | Related item/Bug, matching symptom/cause, current-vs-fixed version |
| Possible regression | Original fix/build, current build, regression/backport/customization/data alternatives |
| Workaround | Applicability, steps, expected result, risk |
| Confirmed cause | Decisive evidence and next action; say when no safe workaround exists |
| Likely cause | Hypothesis, supporting facts, validation needed |
| More data needed | Exact data and why it distinguishes hypotheses |
| Customization/configuration | Evidence, expected standard behavior, clean-environment/setup check |

Use only relevant blocks:

```text
<Direct answer or conclusion>

Evidence:
- <decisive fact, source, issue key, version, SQL result, or code path>

Action:
- <workaround, validation, fix/version action, or requested data>

Risk/limits:
- <only when material>
```

For an explicit Jira question, identify its author/date or comment reference and state `Yes`, `No`, `Partially`, or `Not confirmed` before the evidence.

### SQL Detection and Correction Workaround

Do not imply that correction was executed.

````text
A data repair workaround can be considered, subject to review and approval.

Detection script:
```sql
-- Read-only validation. Scope by COMPANYID / tenant.
SELECT ...
```

Expected result:
<rows that indicate the issue>

Correction script proposal:
```sql
-- Proposal only. Do not execute without backup, tenant validation, and approval.
BEGIN TRAN;

UPDATE ...
WHERE ...

-- Validation after update
SELECT ...

-- COMMIT TRAN; -- enable only after review
-- ROLLBACK TRAN;
```

Notes:
- Review with support/dev before execution.
- Scope to the affected tenant: COMPANYID = <id>.
- Take a database backup.
- This repairs data; it is not the root-cause fix unless stated separately.
````

## Output

```text
## 11. Jira Comment Proposal

Recommended comment:
<ready-to-post comment>

Alternative comment, if useful:
<optional alternate version>
```

If no useful comment can be drafted, state why and list the missing input.
