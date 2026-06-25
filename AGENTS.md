# Acumatica Application Engineer Workspace (Light)

This is a Codex workspace tailored for Acumatica ERP application engineering on the Projects/Construction team. It is the **light** variant: external context comes from the corporate `jira-internal` and `wiki-internal` MCP servers, optional `acumatica-knowledge`, read-only SQL through a local PowerShell facade, and git over a local product checkout. It provides workflow skills for support analysis, code review, spec verification, bugfixing, and feature development.

## Repository-Local MCP

The project-local MCP servers are supplied by the Codex plugin declared in:

- `.codex-mcp.json`
- `.agents/plugins/marketplace.json`
- `plugins/acumatica-mcp-facade/.codex-plugin/plugin.json`
- `plugins/acumatica-mcp-facade/.mcp.template.json`

Prefer starting Codex through `scripts/Start-Codex.ps1`, which starts the local SQL backend when needed and runs the project MCP registration preflight before launching Codex. The fixed project MCP server set for this workspace is:

- `powershell-mcp-facade` - read-only **SQL only** facade (`sql.select`) over the local `db-proxy` backend (stdio). It exposes no Jira/Wiki/Bitbucket tools.
- `jira-internal` - internal Jira HTTP MCP server; the primary path for Jira reads (`jira_get_issue`, `jira_search`).
- `wiki-internal` - internal Confluence/Wiki HTTP MCP server; the primary path for Wiki reads (`confluence_get_page`, `confluence_get_comments`, and related read tools).
- `acumatica-knowledge` - Acumatica DAC/OData/REST/Generic Inquiry/Help Wiki reference lookup (remote streamable HTTP).

If `/mcp` does not show all expected servers, treat it as an MCP configuration or backend-availability problem, not a reason to bypass the approved paths:

- `powershell-mcp-facade` is a stdio facade over the local `db-proxy` backend at `http://127.0.0.1:8765` (see `db-proxy/`). `scripts/Start-Codex.ps1` auto-starts `db-proxy` before the session. The server can fail SQL tool calls when that backend is not running; handle such failures as backend availability issues.
- `jira-internal`, `wiki-internal`, and `acumatica-knowledge` are remote HTTP MCP servers that require OAuth on first use and are only reachable from the Acumatica corporate network with private access enabled.

Run `scripts/Check-Mcp.ps1` to validate the MCP configuration, smoke-test the local SQL facade, and probe the `db-proxy` backend. Do not manually launch the facade as a bootstrap step; let Codex manage the registered plugin servers. The `db-proxy` backend is started automatically by `scripts/Start-Codex.ps1`.

This workspace is read-only by design (the only write-capable work is local source edits in the bugfix/feature modes). Codex approvals and the SQL guardrails are a convenience, not a substitute for the safety rules below.

## Highest-Priority Context Access Rule

Use only the designated repository skills for external context:

- `jira-access` for Jira issue reads through `jira-internal`.
- `jira-similar-search` for likely similar Bugs or Support Requests (agent-driven JQL through `jira-internal`, ranked locally).
- `wiki-access` for `wiki.acumatica.com` pages through `wiki-internal`, including footer and inline comments.
- `local-change-access` for a specific change set (branch or commit/ref range) inspected with git over the local `code/` repository.
- `database-access` for read-only SQL evidence through the `powershell-mcp-facade` `sql.select` tool.
- `acumatica-knowledge-access` for DAC, OData, Contract-Based REST API, Generic Inquiry, and Help Wiki reference lookup through `acumatica-knowledge`.

`acumatica-knowledge` is an optional reference enrichment source. Use it when exact DAC/API/GI/OData/Help Wiki facts can improve diagnosis, review, implementation planning, or validation. If it is unavailable, continue with Jira, Wiki, local git changes, local docs, source code, and read-only SQL as applicable; do not treat its absence as a blocker unless the user explicitly asked for that source and no substitute can answer the question.

Do not bypass these paths with direct REST, provider modules, ad hoc scripts, browser scraping, or direct SQL tooling when the repository skill path is available.
Do not request approval for read-only SQL needed for diagnosis.
Do not perform Jira, Wiki, or database actions beyond the read-only actions described by the corresponding skills. Local source edits are allowed only within the write-capable modes (`acumatica-small-bugfix`, `acumatica-feature-development`) and follow their approval rules.

There is no Bitbucket/PR service and no RAG Memory in this workspace. A pull request is inspected as a git branch or commit range in `code/`; map a PR id/URL to a branch using Jira Development data first.

## Mode Router

Use high-level workflow skills for task-specific context. Load only the relevant mode skill:

- `acumatica-support-request-analysis` - Support Request analysis for the Projects/Construction team: Jira title/description/comments, related items, read-only SQL diagnostics, source-code analysis, root cause, workaround, iteration gate, and Jira comment draft.
- `acumatica-code-review` - read-only review of a branch, change set, or diff against Jira intent, architecture, domain, migration, database, test, and maintainability risk.
- `acumatica-spec-verification` - read-only verification that an implementation covers a functional specification from Jira and/or Wiki before QA.
- `acumatica-small-bugfix` - minimal low-risk correction for a narrow defect when expected behavior, base branch, and validation are sufficiently clear.
- `acumatica-feature-development` - iterative feature implementation from a Jira item and functional specification, with scope ledger and requirement coverage.
- `functional-spec-risk-analysis` - read-only analysis of a functional specification before implementation for contradictions, ambiguity, lifecycle gaps, persistence/source-of-truth risk, and Acumatica implementability.

If the user's task does not fit one of these modes, perform the maximum safe analysis, state what is missing, and avoid guessing or implementing unsafely.

## Inputs

Accepted inputs include Jira ticket ID, Support Request ID, functional specification source or Wiki URL, branch name, commit/ref range, bug description, failing test name, exception message, stack trace, database backup/environment details, or Acumatica screen/table/API references.

When Jira context is available, use it. For code review, a specific branch or commit range in `code/` is sufficient input; derive the linked Jira item from branch naming or commit messages when available instead of asking the user. A bare PR id/URL is not directly resolvable here - map it to a branch via Jira Development data.
For specification verification and feature development, a functional specification is required. Use Jira requirements when they are complete enough; otherwise use a linked/provided Wiki specification or ask the user for the specification source.

## Repository and Local Sources

Default source repository location:

- `code`

The `code` directory is not part of this workspace scaffold and should not be copied from older workspaces as part of setup. Before running Git commands or code-path verification, resolve the repository path first. Use `code` only when it exists and contains `.git`. If `code` is missing or is not a Git repository, ask for the correct repository path before relying on local Git state or source-code evidence. Do not run Git commands from the workspace root unless that root is itself the configured Git repository.

Local docs are authoritative context. Mode skills decide which docs must be loaded, but these are the standard sources:

- `docs/ARCHITECTURE_RULES.md`
- `docs/REFACTORINGS.md`
- `docs/BUSINESS_MODEL.md`
- `docs/DATABASE_MODEL.md`
- `docs/FEATURE_DEVELOPMENT_WORKFLOW.md`
- `docs/FEATURE_IMPLEMENTATION_PATTERNS.md`

This workspace is intentionally tailored for the Projects/Construction team. PM/CN/PJ domain context is expected and should be used when relevant rather than hidden.

Mention missing relevant docs in the final result and continue with available sources.

## Shared Evidence and Safety Rules

- Never invent facts, business requirements, or code behavior.
- Separate facts from hypotheses. Fact means confirmed by Jira, Wiki, docs, code, tests, Acumatica Knowledge lookup, local git change set, or read-only SQL.
- Treat Acumatica Knowledge as supporting context unless current Jira, SQL, code, change-set, or runtime evidence confirms applicability.
- Treat Acumatica Knowledge search results as discovery. Open the exact DAC/entity/schema/page/example before relying on details, and state the limitation when a conclusion is based on reference knowledge rather than the current branch, tenant data, change set, or Jira evidence.
- Use root-cause confidence when useful: **Confirmed**, **Likely**, or **Unclear**.
- Do not call a root cause confirmed without direct supporting evidence.
- Never contradict local docs silently; call out docs/code/data discrepancies.
- Never discard user changes or silently clean the working tree.
- Never switch branches blindly in a dirty working tree.
- Prefer git branch/range inspection in `code/` when a local checkout is unnecessary for deeper work.
- Never execute state-changing SQL or administrative database operations.
- If requirements, branch/range, baseline, repository path, or validation path cannot be identified confidently, stop and report the missing prerequisite.
- If the task exceeds the selected mode's safe scope, stop and explain why.

If data is insufficient, still perform the maximum useful analysis, list what is missing, state hypotheses as hypotheses, and provide a validation plan instead of guessing.

## Environment Interaction Principle

Git topology, build/validation execution, and write-operation execution are properties of the individual user's environment, not fixed procedures owned by the workflow.

- Git topology varies: some users have the original product repository, others a worktree, others a non-default path. Do not assume a single layout. Establish the effective layout through dialogue with the user, then reuse it for the rest of the session.
- The goal is not to remove the user's manual git/build/test work. Propose concrete options, and let the user decide which steps the agent runs through approved read-only paths and which the user performs manually (for example interactive logins, builds, branch creation, commits, or pushes).
- When an environment-specific action is needed (resolve a repo path, fetch a ref, build, run a test, create a branch, commit), state the options and the trade-offs, ask when the choice is genuinely the user's, and proceed with a sensible default only when one clearly exists and is read-only/safe.
- Treat a resolved environment choice as session context: record it in session notes when the work may resume or hand off, so the next pass does not re-ask.

This principle governs the secondary mechanics of git, build, and write execution so the mode skills can stay focused on methodology. The write-capable modes (`acumatica-small-bugfix`, `acumatica-feature-development`) still follow their own approval and stop rules for any change to source.

## Shared Review and Diagnosis Rules

- For change-set reviews, classify the review shape before deep inspection: small bugfix/change, spec-backed feature, architecture-first, migration/schema-heavy, or a deliberate combination.
- For spec-backed feature changes, keep functional requirement coverage separate from architecture/docs compliance. Use a coverage-oriented pass across relevant Acumatica data paths instead of reviewing only the changed lines.
- For small bugfix/change reviews, keep the review focused on root cause, fix minimality, targeted edge cases, regression risk, and validation unless the evidence shows broader feature scope.
- Review explicit Jira linked issues and issue keys from descriptions/comments before heuristic similarity search when they can affect expected behavior, branch selection, regression history, root cause, workaround, or fix scope.
- Run `jira-similar-search` only when explicit context is insufficient and likely similar Bugs or Support Requests can change the diagnosis or conclusion.
- Retrieve relevant Wiki links through `wiki-access`; treat footer comments, inline comments, and comment resolution state as first-class context.
- Use `database-access` only for read-only diagnosis or verification. Use `SELECT` only. Use `COMPANYID` for tenant-partitioned tables when identified. Do not treat cross-tenant matches as confirmation.
- Use `acumatica-knowledge-access` for reference discovery when exact DAC/API/GI/OData/doc facts can change the diagnosis, review, implementation plan, or validation.
- If `acumatica-knowledge` is unavailable, continue without it and mention the limitation only when the missing reference context could materially affect confidence.
- Use `system-diagnostics-analysis` only when environment, product version, branch choice, customizations, upgrade history, or schema discovery can change the conclusion, implementation plan, or validation.
- When changed files include `WebSites/Pure/DB/MSSQL/*.sql`, use `migration-script-consistency-review`. The `MSSQL` directory name is historical; determine database applicability from script tags. Treat `ALTER`, `CREATE`, and `DROP` in migration scripts as suspicious.

## Finding Evidence Format

Every review/analysis finding should be written as a self-contained, source-backed claim that a reviewer or developer can verify quickly.

- Always cite code as `path/to/File.ext:line`. Include the file name and exact line number for every decisive code reference.
- Include a short source-code excerpt when the defect is not obvious from one line, especially for conditions, exception handling, BQL queries, DAC attributes, schema definitions, migration SQL, and persistence logic. Keep excerpts minimal, normally 3-10 lines.
- For spec mismatches, cite the exact Jira or Wiki source with the section, subsection, heading path, acceptance criterion, or requirement ID when available.
- Quote the shortest useful spec fragment, usually one sentence or a key phrase, so the author can find it quickly in the source document. Do not paste large spec sections.
- Separate what the source says from what the implementation does. Prefer labels such as `Spec evidence`, `Code evidence`, `Problem`, `Impact`, and `Recommendation` for non-trivial findings.
- For architecture findings, cite the local rule document and the decisive implementation line. Quote a short rule fragment only when it clarifies the finding.
- If the finding relies on an inferred requirement rather than an explicit spec line, say that clearly and lower confidence accordingly.

## Session Notes

Use `acumatica-session-notes` whenever session notes are created, updated, refreshed, or considered for substantial Support Request analyses, reviews, bugfix investigations, specification verification, or iterative feature-development work.

Session notes are grouped by Jira item under `.session-notes/<JiraItemId>/` with meaningful file names.

## Final Checklist

Before finalizing:

- correct high-level mode skill selected;
- Jira/branch/range/repository/spec context resolved or limitation stated;
- required low-level skills used for Jira, Wiki, local change set, SQL, Acumatica Knowledge, migration scripts, and similarity search when those sources are used;
- Acumatica Knowledge unavailability did not block the workflow, or a material limitation was stated;
- explicit links considered before similarity search;
- changed migration scripts reviewed with `migration-script-consistency-review`, or absence stated when relevant to review/verification;
- facts and hypotheses separated;
- branch/version context verified when it matters;
- SQL remained read-only and tenant-scoped when needed;
- scope remained within the selected mode or stop reason was reported;
- validation and residual uncertainty are clear.
