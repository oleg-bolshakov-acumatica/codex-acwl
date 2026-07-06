# codex-acwl - Acumatica Application Engineer Workspace, Light (Codex)

A self-contained Codex workspace for Acumatica ERP application engineering on the
Projects/Construction team. This is the light variant: external context comes
from the corporate `jira-internal` and `wiki-internal` MCP servers, read-only
SQL through a local PowerShell facade, and git over a local product checkout.

The operating contract for the agent lives in `AGENTS.md`. This README is for
humans setting up and maintaining the workspace.

## What Light Changes Vs. `codex-acw`

- `powershell-mcp-facade` is trimmed to read-only SQL only: `sql.select` plus
  `server.describe_capabilities`.
- Jira and Wiki are read through the corporate `jira-internal` and
  `wiki-internal` HTTP MCP servers.
- RAG Memory is removed: no `rag-memory` server, no `mcp-rag`, no RAG skills.
- Bitbucket/PR MCP access is removed. Change sets are inspected with git over
  the local `code/` repository via the `local-change-access` skill.
- The local SQL backend is `db-proxy` on `http://127.0.0.1:8765`.

## Layout

```text
codex-acwl/
  AGENTS.md                               Always-on operating contract.
  .codex/config.toml                      Codex project MCP configuration.
  .agents/
    skills/                              Workflow and access skills.
  core/                                  PowerShell modules for the SQL-only facade.
  config/server.config.json              Facade server and backend configuration.
  db-proxy/                              Local read-only SQL backend.
  scripts/                               Startup, health-check, and smoke tests.
  docs/                                  Architecture/business/database/reference docs.
  code/                                  Local product checkout placeholder (git-ignored).
```

`code/` is intentionally empty in this scaffold. Populate it separately with a
local Acumatica product checkout when a workflow needs source-code evidence.

## MCP Servers

Codex receives the fixed MCP server set from `.codex/config.toml` when the
workspace is trusted. `scripts/Start-Codex.ps1` launches Codex with
`-C <workspace-root>` so the project config is in scope.

This workspace does not use a project-local Codex plugin or patch
`~/.codex/config.toml`. The repository-local MCP configuration is the only
workspace-owned source for these servers.

| Server | Transport | Purpose |
| --- | --- | --- |
| `powershell-mcp-facade` | stdio | Read-only SQL only. Backend: local `db-proxy` at `127.0.0.1:8765`. |
| `jira-internal` | http | Internal Jira read path. |
| `wiki-internal` | http | Internal Confluence/Wiki read path. |

The two remote HTTP services require the Acumatica corporate network and any
OAuth flow they request on first use. The SQL facade can list its tools even when
`db-proxy` is down, but `sql.select` calls require the backend.

## MCP Authorization Troubleshooting

First confirm that the project MCP config is loaded. Start Codex through the
workspace launcher and check `/mcp`, or run `scripts/Check-Mcp.ps1`. On a clean
machine, Codex must trust the workspace before it loads `.codex/config.toml`.

Use explicit MCP login when Jira or Wiki tool calls fail with an authentication
or authorization error, when the first-use OAuth prompt was missed or expired,
or when `/mcp` shows `jira-internal` or `wiki-internal` but the service cannot
be used. Run these commands from the workspace root so Codex can see the
project-scoped server definitions.

```powershell
codex mcp login jira-internal
codex mcp login wiki-internal
```

Complete the browser OAuth flow with the Acumatica account that has the needed
Jira and Confluence permissions. The commands must be run from a machine on the
Acumatica corporate network with private access enabled.

After logging in, restart Codex through the workspace launcher and check `/mcp`:

```powershell
scripts/Start-Codex.ps1
```

## MCP Availability Checks

If `/mcp` does not list all three expected workspace servers, treat that as
configuration or service availability first, not as a reason to bypass the
approved MCP paths. Codex may also show globally installed servers that are not
owned by this workspace.

```powershell
scripts/Check-Mcp.ps1
scripts/Check-Mcp.ps1 -SkipSmokeTest
```

Use these checks to separate the failure mode:

- If `jira-internal` or `wiki-internal` is missing, confirm that Codex trusts
  the workspace and that `.codex/config.toml` contains the expected servers.
- If `jira-internal` or `wiki-internal` is present but returns an OAuth,
  unauthorized, or forbidden error, run the matching `codex mcp login` command.
- If only `powershell-mcp-facade` or `sql.select` fails, check script execution
  policy and the local `db-proxy` backend. The SQL facade does not use
  `codex mcp login`.
- If `http://127.0.0.1:8765/status` responds with a backend other than
  `db-proxy-0.1.0`, stop the process using that endpoint or change
  `db-proxy/config/db-proxy.config.json` before starting Codex.

Do not use Jira personal access tokens, direct Jira or Confluence REST calls, or
browser scraping as a workaround for MCP authorization problems in this
workspace.

## Clean Machine Prerequisites and Risks

- Codex must trust the workspace. Project-scoped `.codex/config.toml` is ignored
  in untrusted projects.
- Run setup from Windows PowerShell where local `.ps1` scripts are allowed by
  corporate policy. The MCP facade startup uses PowerShell with
  `-ExecutionPolicy RemoteSigned`.
- If PowerShell blocks script execution on a clean computer, use the approved
  IT process for trusted local scripts instead of bypassing policy in the
  command line.
- Codex starts the local SQL MCP facade through a PowerShell `.ps1` file. If
  script execution is blocked, `/mcp` will not show a healthy
  `powershell-mcp-facade` until the workspace scripts are allowed by policy.
- `codex` must be installed and available in `PATH`.
- Jira and Wiki MCP access requires the Acumatica corporate network and the
  OAuth flow requested by Codex on first use.
- SQL diagnostics require the `SQLPS` module / `Invoke-Sqlcmd` and access to the
  target SQL Server. MCP configuration and Jira/Wiki usage do not require SQLPS.
- The product source checkout is not included. Place a clone, worktree,
  junction, or symlink under `code/`, or provide another path when source-code
  workflows need it.

## Getting Started

Start Codex through the workspace launcher:

```powershell
scripts/Start-Codex.ps1
```

The launcher:

1. Starts `db-proxy` if `http://127.0.0.1:8765/status` is not responding.
2. Fails fast if that endpoint is already occupied by a backend other than
   `db-proxy-0.1.0`.
3. Verifies that `.codex/config.toml` exists.
4. Launches `codex -C <workspace-root>`, letting Codex load the trusted project
   MCP configuration.

Useful launcher switches:

```powershell
scripts/Start-Codex.ps1 -SkipProxy   # assume db-proxy is managed elsewhere
scripts/Start-Codex.ps1 -ProxyOnly   # start/probe db-proxy and exit
```

Validate the MCP configuration without launching Codex:

```powershell
scripts/Check-Mcp.ps1
scripts/Check-Mcp.ps1 -SkipSmokeTest
```

Exercise SQL end to end after `db-proxy` is running:

```powershell
scripts/Smoke-Test-Sql.ps1
scripts/Smoke-Test-Sql.ps1 -Schema MyDb -Query "SELECT TOP 1 * FROM COMPANY"
```

## Product Source Checkout

The Acumatica ERP product sources are not part of this workspace and are not
copied from `codex-acw`.

Place a local clone, worktree, junction, or symlink under `code/` so that
`code/.git` resolves when source workflows need it. If the source lives
somewhere else, tell the agent the path. Pull requests are inspected as git
branches or commit ranges; there is no Bitbucket/PR MCP service in this light
workspace.

## Workflow Skills

High-level workflow skills:

- `acumatica-support-request-analysis`
- `acumatica-code-review`
- `acumatica-spec-verification`
- `acumatica-small-bugfix`
- `acumatica-feature-development`
- `functional-spec-risk-analysis`

Lower-level access and analysis skills include `jira-access`, `wiki-access`,
`local-change-access`, `database-access`, `jira-similar-search`,
`related-items-analysis`, `source-code-analysis`,
`migration-script-consistency-review`, `system-diagnostics-analysis`,
`database-root-cause-analysis`, `root-cause-origin-analysis`,
`jira-comment-drafting`, and `acumatica-session-notes`.

## Safety Model

The workspace is read-only by default. Jira, Wiki, and SQL access
must go through the declared MCP servers and repository skills. SQL is limited
to read-only `SELECT` through `powershell-mcp-facade`; `db-proxy` enforces this
at the backend.

The write-capable workflows are limited to local source edits in
`acumatica-small-bugfix` and `acumatica-feature-development`, and they follow
their own scope and validation rules in `AGENTS.md` and the corresponding
skills.
