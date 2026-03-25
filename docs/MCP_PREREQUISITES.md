# MCP Prerequisites For PM Workflow

This PM workflow requires specific MCP servers. Missing optional doc/research servers can reduce evidence quality, but routed cross-runtime phases must not continue in degraded mode when the required opposite-provider runtime is unavailable.

## Required MCP servers (required for full behavior)
From the PM skill contract, these are required for full behavior:
- `claude-code`
- `exa`
- `context7`
- `deepwiki`
- `firecrawl`

Claude availability policy:
- `Main Runtime Only` remains usable without Claude MCP when the outer runtime is Codex.
- `Dynamic Cross-Runtime` with Codex outer runtime blocks before Discovery when Claude is unavailable and offers remediation to fix `claude-code` or switch to `Main Runtime Only`.
- `Dynamic Cross-Runtime` with Claude outer runtime keeps Claude-native roles as the outer runtime and blocks before Discovery until `codex-worker` is available or the user chooses `Main Runtime Only`.
- `codex mcp list` only proves `claude-code` is configured/enabled. It does not prove the current Codex runtime exposes a usable Claude launcher.
- PM launcher health is defined by the repo-owned contract file at `skills/pm/agents/claude-launcher-contract.json`.
- Dynamic Claude readiness requires a live `claude mcp serve` probe that completes `initialize`, `tools/list`, and a real `tools/call` to the configured `Agent` launcher candidates.
- If the launcher reports `Agent type 'general-purpose' not found`, `no supported agent type`, or equivalent, treat Claude runtime as unavailable for that session.
- If a required Claude-routed phase step later loses launcher availability, stop that phase and return control to PM. Do not continue with codex-native fallback.

Codex secondary-runtime policy for Claude outer-runtime sessions:
- Register `codex-worker` in the Claude runtime with `claude mcp add codex-worker -- codex mcp-server`.
- `claude mcp list` must show `codex-worker` enabled for the active Claude runtime.
- The Claude runtime must also be able to execute `codex` (for example via runtime `PATH` or an absolute command path).
- If `codex-worker` is enabled but `codex` is not executable, treat `dynamic-cross-runtime` in Claude as unavailable and block before Discovery instead of continuing.

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

For `claude-code`, also require a usable Claude launch path in the current runtime. Do not treat direct `mcp__claude-code__Agent` / implicit `general-purpose` agent launching as the PM contract. The helper uses the explicit candidates from `skills/pm/agents/claude-launcher-contract.json` and only reports Claude healthy when one candidate returns the exact deterministic probe token.

## Authentication / env notes
- `firecrawl` requires `FIRECRAWL_API_KEY`.
- `exa` may require org/account authorization depending your setup.
- `claude-code` requires the configured `command` to be executable in the runtime that launches it.
- That executability can come from an absolute command path, from `[shell_environment_policy.set].PATH`, or from `[mcp_servers.claude-code.env].PATH`.
- If `claude-code` is enabled but PM still reports launcher failure, the MCP server is present but the current runtime does not expose a usable Claude launcher for the candidates in `skills/pm/agents/claude-launcher-contract.json`. In that case, block the Claude-dependent phase rather than repeating the install command.

## Optional but recommended MCP servers
Not hard-required by PM contract, but commonly useful in real runs:
- `github` (PR/issues/reviews)
- `clickup` (task operations)
- `chrome-devtools` or `playwright` (browser validation outside `agent-browser` usage)

Legacy cleanup note:
- `droid-worker` is obsolete and is not part of current PM runtimes.
- If it still exists in user-scope Claude config, remove it with `claude mcp remove droid-worker -s user`.

## For workspace images
MCP config is runtime-level; ensure the workspace image/session has the same MCP entries before running `$pm`.
