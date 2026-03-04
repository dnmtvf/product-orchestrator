# MCP Prerequisites For PM Workflow

This PM workflow requires specific MCP servers. If they are missing, parts of the flow will enter blocked/manual fallback mode.

## Required MCP servers (hard requirements)
From the PM skill contract, these are required:
- `claude-code`
- `exa`
- `context7`
- `deepwiki`
- `firecrawl`

## Install commands (Claude Code CLI)

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

## Codex Worker Setup

The PM workflow uses Claude Code for most roles and Codex CLI (gpt-5.3-codex xhigh) for specialized analysis/review tasks.

### Prerequisites
- Codex CLI installed: `npm install -g @openai/codex` or `brew install --cask codex`
- Authenticated: `codex login`

### Register Codex worker MCP

Run the setup script (one-time user-level setup):
```bash
./scripts/setup-codex-user.sh
```

This registers `codex-worker` MCP via `claude mcp add codex-worker -- codex mcp-server`.

### Role-to-model table
| Role | Model | Runtime |
|---|---|---|
| Project Manager | Not pinned | Claude Code (Task tool) |
| Team Lead | Not pinned | Claude Code (Task tool) |
| Librarian | Not pinned | Claude Code (Task tool) |
| Researcher | Not pinned | Claude Code (Task tool) |
| Backend Engineer | Not pinned | Claude Code (Task tool) |
| Frontend Engineer | Not pinned | Claude Code (Task tool) |
| Security Engineer | Not pinned | Claude Code (Task tool) |
| AGENTS Compliance Reviewer | Not pinned | Claude Code (Task tool) |
| Codex Reviewer | Not pinned | Claude Code (Task tool) |
| Manual QA | Not pinned | Claude Code (Task tool) |
| Task Verification | Not pinned | Claude Code (Task tool) |
| Senior Engineer | gpt-5.3-codex xhigh | Codex CLI (codex-worker MCP) |
| Smoke Test Planner | gpt-5.3-codex xhigh | Codex CLI (codex-worker MCP) |
| Alternative PM | gpt-5.3-codex xhigh | Codex CLI (codex-worker MCP) |
| Jazz Reviewer | gpt-5.3-codex xhigh | Codex CLI (codex-worker MCP) |

## Optional but recommended MCP servers
Not hard-required by PM contract, but commonly useful in real runs:
- `github` (PR/issues/reviews)
- `clickup` (task operations)
- `chrome-devtools` or `playwright` (browser validation outside `agent-browser` usage)

## For workspace images
MCP config is runtime-level; ensure the workspace image/session has the same MCP entries before running `$pm`.
