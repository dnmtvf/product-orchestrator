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

## Droid Worker Setup (hybrid architecture)

The PM workflow uses a hybrid model: Claude Code (Opus 4.6) for lead roles, Droid CLI + MiniMax-M2.5 for cost-effective worker tasks.

### Prerequisites
- Droid CLI installed and available in PATH
- A MiniMax API key (or compatible provider)

### Environment variables
```bash
export ANTHROPIC_BASE_URL="https://api.minimax.io/anthropic"
export ANTHROPIC_AUTH_TOKEN="your-minimax-api-key"
```

### Register Droid as MCP worker

**Option A: Project-level registration (recommended for team sharing)**

Add to your project's `.mcp.json`:
```json
{
  "mcpServers": {
    "droid-worker": {
      "type": "stdio",
      "command": "./scripts/droid-mcp-server",
      "args": ["--mcp"]
    }
  }
}
```

**Option B: User-level registration (personal use only)**
```bash
claude mcp add droid-worker -s user -- ./scripts/droid-mcp-server --mcp
```

**Conductor Note**: Project-level `.mcp.json` servers require interactive approval in native Claude Code. In Conductor's non-interactive workspaces, you **must** enable auto-approval for project MCP servers:

```bash
# Option 1: Run the configuration script
./scripts/configure-conductor.sh

# Option 2: Manual configuration
claude config set -g enableAllProjectMcpServers true
```

The `install-workflow.sh` and `inject-workflow.sh` scripts call `configure-conductor.sh` automatically during installation.

### Model enforcement for lead roles
Start your orchestrator session with `--model claude-opus-4-6` to ensure lead roles (PM, Team Lead, Senior Engineer, Researcher, Jazz) run on Opus 4.6. The `claude mcp serve` command inherits the ambient session model — no per-call override is available.

```bash
claude --model claude-opus-4-6
```

### Role-to-model table
| Role | Model | Runtime |
|---|---|---|
| Project Manager | claude-opus-4-6 | Claude Code |
| Team Lead | claude-opus-4-6 | Claude Code |
| Senior Engineer | claude-opus-4-6 | Claude Code |
| Researcher | claude-opus-4-6 | Claude Code |
| Jazz Reviewer | claude-opus-4-6 | Claude Code |
| Backend/Frontend/Security Engineers | MiniMax-M2.5 | Droid CLI |
| Librarian | MiniMax-M2.5 | Droid CLI |
| Smoke Test Planner | MiniMax-M2.5 | Droid CLI |
| Alternative PM | MiniMax-M2.5 | Droid CLI |
| AGENTS Compliance Reviewer | MiniMax-M2.5 | Droid CLI |
| Manual QA | MiniMax-M2.5 | Droid CLI |

## Optional but recommended MCP servers
Not hard-required by PM contract, but commonly useful in real runs:
- `github` (PR/issues/reviews)
- `clickup` (task operations)
- `chrome-devtools` or `playwright` (browser validation outside `agent-browser` usage)

## For workspace images
MCP config is runtime-level; ensure the workspace image/session has the same MCP entries before running `$pm`.
