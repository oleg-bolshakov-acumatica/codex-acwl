[CmdletBinding()]
param()

# Thin wrapper: run the DB proxy HTTP server in the current process (foreground).
# Logs go to stderr. Stop with Ctrl+C. For auto-start before a Codex session,
# scripts/Start-Codex.ps1 launches this server as a background process.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "scripts\Start-DbProxyServer.ps1")
