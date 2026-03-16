# MCP Prerequisites For PM Workflow

This PM workflow requires specific MCP servers. Missing optional doc/research servers can reduce evidence quality, but Claude-dependent orchestration modes must not continue in degraded mode when Claude is unavailable.

## Required MCP servers (required for full behavior)
From the PM skill contract, these are required for full behavior:
- `claude-code`
- `exa`
- `context7`
- `deepwiki`
- `firecrawl`

Claude availability policy:
- `Full Codex Orchestration` remains usable without Claude MCP.
- `Codex as Main Agent` blocks before Discovery when Claude is unavailable and offers explicit fallback to `Full Codex Orchestration`.
- `Claude as Main Orchestrator` blocks before Discovery until Claude MCP is fixed or the user chooses a supported mode.
- `codex mcp list` only proves `claude-code` is configured/enabled. It does not prove the current Codex runtime exposes a usable Claude launcher.
- If the launcher reports `Agent type 'general-purpose' not found`, `no supported agent type`, or equivalent, treat Claude runtime as unavailable for that session.
- If a required Claude-routed phase step later loses launcher availability, stop that phase and return control to PM. Do not continue with codex-native fallback.

## Install commands (Codex CLI)

```bash
codex mcp add claude-code -- claude mcp serve
codex mcp add context7 -- npx -y @upstash/context7-mcp
codex mcp add firecrawl --env FIRECRAWL_API_KEY=YOUR_KEY -- npx -y firecrawl-mcp
codex mcp add deepwiki --url https://mcp.deepwiki.com/mcp
codex mcp add exa --url https://mcp.exa.ai/mcp
```

## Verify configuration

```bash
codex mcp list
```

You should see all five names above in `enabled` state. That is necessary but not sufficient for `claude-code`.

For `claude-code`, also require a usable Claude launch path in the current runtime. Do not treat direct `mcp__claude-code__Agent` / implicit `general-purpose` agent launching as the PM contract.

## Authentication / env notes
- `firecrawl` requires `FIRECRAWL_API_KEY`.
- `exa` may require org/account authorization depending your setup.
- `claude-code` requires the configured `command` to be executable in the runtime that launches it.
- That executability can come from an absolute command path, from `[shell_environment_policy.set].PATH`, or from `[mcp_servers.claude-code.env].PATH`.
- If `claude-code` is enabled but PM still reports `no supported agent type`, the MCP server is present but the current runtime does not expose a usable Claude launcher for PM. In that case, block the Claude-dependent phase rather than repeating the install command.

## Optional but recommended MCP servers
Not hard-required by PM contract, but commonly useful in real runs:
- `github` (PR/issues/reviews)
- `clickup` (task operations)
- `chrome-devtools` or `playwright` (browser validation outside `agent-browser` usage)

## For workspace images
MCP config is runtime-level; ensure the workspace image/session has the same MCP entries before running `$pm`.
