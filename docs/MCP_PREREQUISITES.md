# MCP Prerequisites For PM Workflow

This PM workflow requires specific MCP servers. If they are missing, parts of the flow will enter blocked/manual fallback mode.

## Required MCP servers (hard requirements)
From the PM skill contract, these are required:
- `claude-code`
- `exa`
- `context7`
- `deepwiki`
- `firecrawl`

## Install commands (Codex CLI)

```bash
claude mcp add claude-code -- claude mcp serve
claude mcp add context7 -- npx -y @upstash/context7-mcp
claude mcp add firecrawl --env FIRECRAWL_API_KEY=YOUR_KEY -- npx -y firecrawl-mcp
claude mcp add deepwiki --url https://mcp.deepwiki.com/mcp
claude mcp add exa --url https://mcp.exa.ai/mcp
```

## Verify configuration

```bash
claude mcp list
```

You should see all five names above in `enabled` state.

## Authentication / env notes
- `firecrawl` requires `FIRECRAWL_API_KEY`.
- `exa` may require org/account authorization depending your setup.
- `claude-code` requires `claude` CLI available in PATH and usable by the runtime.

## Optional but recommended MCP servers
Not hard-required by PM contract, but commonly useful in real runs:
- `github` (PR/issues/reviews)
- `clickup` (task operations)
- `chrome-devtools` or `playwright` (browser validation outside `agent-browser` usage)

## For workspace images
MCP config is runtime-level; ensure the workspace image/session has the same MCP entries before running `$pm`.
