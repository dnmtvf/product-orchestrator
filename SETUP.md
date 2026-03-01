# Product Orchestrator Setup

This repository is the source of truth for PM orchestration skills and workflow files.

## What this repo contains
- `skills/pm`
- `skills/pm-discovery`
- `skills/pm-create-prd`
- `skills/pm-beads-plan`
- `skills/pm-implement`
- `skills/agent-browser`
- `instructions/pm_workflow.md`
- `skills/pm/scripts/pm-command.sh` (manual self-update + deterministic `$pm help` output helper)

## Why symlinks are required
The runtime `Skill` loader resolves skills from runtime skill directories (for this machine: `~/.claude/skills`).

Referencing a path from `AGENTS.md` is not enough to make `/skill` invocable. The skill must be discoverable from runtime skill directories.

## Prerequisites
- MCP requirements: `docs/MCP_PREREQUISITES.md`

## Hybrid Architecture: Droid Worker Setup
The PM workflow runs Claude Code (Opus 4.6) for lead roles and Droid CLI + MiniMax-M2.5 for cost-effective workers.

1. Install Droid CLI and ensure it is in PATH.
2. Set environment variables:
   ```bash
   export ANTHROPIC_BASE_URL="https://api.minimax.io/anthropic"
   export ANTHROPIC_AUTH_TOKEN="your-minimax-api-key"
   ```
3. Register Droid as an MCP server:
   ```bash
   claude mcp add droid-worker -- ./scripts/droid-mcp-server --mcp
   ```
4. Start Claude Code with Opus 4.6 for lead role quality:
   ```bash
   claude --model claude-opus-4-6
   ```

See `docs/MCP_PREREQUISITES.md` for the full role-to-model table.

## Installation modes

1. Direct injection (no submodule, no symlink):
- See `docs/INSTALL_INJECT_WORKFLOW.md`
- Script: `scripts/inject-workflow.sh`

2. Submodule + copy (independent fetch + copied runtime skills):
- See `docs/INSTALL_SUBMODULE_WORKFLOW.md`
- Script: `scripts/install-workflow.sh`

## Runtime reload
After any install/update, restart Claude session so skill indexes reload.
