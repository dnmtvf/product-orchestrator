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
- `skills/pm/scripts/pm-command.sh` (source-repo helper; installed copies land under `.codex/skills/pm/scripts/pm-command.sh` and `.claude/skills/pm/scripts/pm-command.sh`)
- `skills/pm/scripts/claude-code-mcp` (repo-owned Claude MCP wrapper)
- `skills/pm/scripts/sync-claude-agents.py` (deterministic `.claude/agents` sync)
- generated project agents under `.claude/agents/pm-*.md`

## Runtime layout
The installer and injector manage dual runtime copies in target repos:

- `.codex/skills/...` for Codex sessions
- `.claude/skills/...` for Claude sessions
- `.claude/agents/pm-*.md` for Claude project-agent materialization

Referencing a path from `AGENTS.md` is not enough to make `/skill` invocable. The skill must be discoverable from the runtime skill directory used by the active session.

## Prerequisites
- MCP requirements: `docs/MCP_PREREQUISITES.md`

## Codex Worker Setup
The PM workflow uses `codex-worker` only for Codex-routed roles that run inside Claude sessions under `dynamic-cross-runtime`, and for any explicit Claude-side Codex checks.

1. Install Codex CLI: `npm install -g @openai/codex` or `brew install --cask codex`
2. Authenticate: `codex login`
3. Register Codex as an MCP server (one-time user-level setup):
   ```bash
   ./scripts/setup-codex-user.sh
   ```
   This registers `codex-worker` MCP via `claude mcp add codex-worker -- codex mcp-server`.

See `docs/MCP_PREREQUISITES.md` for the full role-to-model table.

## Installation modes

1. Direct injection (no submodule, no symlink):
- See `docs/INSTALL_INJECT_WORKFLOW.md`
- Script: `scripts/inject-workflow.sh`

2. Submodule + copy (independent fetch + copied runtime skills):
- See `docs/INSTALL_SUBMODULE_WORKFLOW.md`
- Script: `scripts/install-workflow.sh`

## Runtime reload
After any install/update, restart the matching runtime session so skill indexes reload. To re-check the managed Claude agent layer directly, run `./skills/pm/scripts/sync-claude-agents.py --check` in the source repo or `./.codex/skills/pm/scripts/sync-claude-agents.py --check` in an installed target repo.
