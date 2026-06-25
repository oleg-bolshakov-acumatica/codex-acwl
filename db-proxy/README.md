# db-proxy - read-only SQL backend for the MCP facade

A light, SQL-only backend for the `powershell-mcp-facade` stdio MCP server in this
workspace. It is the trimmed successor of the full resource proxy backend: it keeps the
exact same HTTP contract the facade expects, but exposes **only** read-only SQL.

## What it is

The facade (`core/BackendClient.psm1`) forwards the `sql.select` tool call to this proxy
over localhost HTTP. This proxy executes a read-only `SELECT` via `Invoke-Sqlcmd` and
returns structured rows. Jira/Wiki/Bitbucket providers from the full proxy
are intentionally absent.

## HTTP contract

- `GET /health` -> `{ ok: true, status: "ok" }`
- `GET /status` -> `{ ok: true, result: { status, mode, backendAvailable, backendVersion } }`
- `POST /invoke` with `{ "operation": "sql.select", "arguments": { "server", "schema", "query" } }`
  -> `{ ok: true, result: { columns, rows, rowCount } }` or `{ ok: false, error: { code, message, source } }`

Supported operations: `ping`, `get_status`, `sql.select`. Any other operation returns
`unknown_operation`.

The bind address is `http://127.0.0.1:8765`, matching the workspace
`config/server.config.json`
(`backend.http.baseUrl`) so the facade connects with no further changes.

## Layout

```text
db-proxy/
  Start.ps1                       # foreground wrapper -> scripts/Start-DbProxyServer.ps1
  config/
    db-proxy.config.json          # http { baseUrl, requestTimeoutSec } + resourceProxy { serverName, logRequests }
    providers.config.json         # sql { defaultServer, aliases, timeoutSec, maxRows, maxCharLength }
  core/
    Config.psm1                   # config loaders
    ResourceProxyTransport.psm1   # Get-ResourceProxySettings
  providers/
    Sql.Provider.psm1             # Invoke-SqlSelect (read-only SELECT)
  scripts/
    Start-DbProxyServer.ps1       # HTTP listener (ping / get_status / sql.select)
    Smoke-Test-DbProxy.ps1        # direct POST /invoke sql.select smoke test
```

## Read-only enforcement

`Sql.Provider.psm1` (`Test-SqlSelectSafety`) allows a single `SELECT` statement only and
rejects multiple statements and `INSERT/UPDATE/DELETE/MERGE/DROP/ALTER/TRUNCATE/EXEC`.
SQL runs under the current Windows identity (integrated auth); no credentials are stored
here.

## Running

Manually (foreground, logs on stderr; Ctrl+C to stop):

```powershell
db-proxy/Start.ps1
```

Automatically: `scripts/Start-Codex.ps1` probes `/status` and, if the proxy is not
already running, launches `scripts/Start-DbProxyServer.ps1` as a background process before
starting Codex. Use `scripts/Start-Codex.ps1 -SkipProxy` to skip auto-start and
`-ProxyOnly` to only start the proxy.

Smoke test (proxy must be running):

```powershell
db-proxy/scripts/Smoke-Test-DbProxy.ps1                 # SELECT 1
db-proxy/scripts/Smoke-Test-DbProxy.ps1 -Schema MyDb -Query "SELECT TOP 1 * FROM COMPANY"
```

## Notes

- Only one process can bind `127.0.0.1:8765`. The light `db-proxy` and any other local
  proxy using that port are mutually exclusive; the auto-start logic does not start a second
  one if `/status` already responds.
- Configuration knobs live in `db-proxy/config/providers.config.json` (`sql` block): change
  `defaultServer`, add `aliases`, or adjust `maxRows` / `maxCharLength` / `timeoutSec`.
- Requires the `SQLPS` module / `Invoke-Sqlcmd`. A future stage may modernize this to
  `SqlServer`/`Microsoft.Data.SqlClient`.
