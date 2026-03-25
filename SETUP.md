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
- `scripts/setup-global-orchestrator.sh` (preferred machine-level bootstrap entrypoint)
- `skills/pm/scripts/pm-command.sh` (source-repo helper; installed copies land under `.codex/skills/pm/scripts/pm-command.sh` and `.claude/skills/pm/scripts/pm-command.sh`)
- `skills/pm/scripts/claude-code-mcp` (repo-aware Claude MCP dispatcher)
- `skills/pm/scripts/sync-claude-agents.py` (deterministic `.claude/agents` sync)
- generated project agents under `.claude/agents/pm-*.md`

## Runtime layout
Preferred machine-level runtime layout:

- `~/.codex/skills/...` for Codex sessions
- `~/.claude/skills/...` for Claude sessions
- user-level `claude-code` registered at `~/.codex/skills/pm/scripts/claude-code-mcp`
- lazy repo-local `.claude/agents/pm-*.md` materialized in the current git repo on first Claude-routed use

Compatibility runtime layout for explicit repo installs:

- `.codex/skills/...` for Codex sessions
- `.claude/skills/...` for Claude sessions
- `.claude/agents/pm-*.md` for Claude project-agent materialization

Referencing a path from `AGENTS.md` is not enough to make `/skill` invocable. The skill must be discoverable from the runtime skill directory used by the active session.

## Prerequisites
- MCP requirements: `docs/MCP_PREREQUISITES.md`

## Preferred machine-level bootstrap

1. Install Codex CLI: `npm install -g @openai/codex` or `brew install --cask codex`
2. Ensure Claude Code is installed and `claude` is executable in your shell.
3. Authenticate: `codex login`
4. Run the one-time bootstrap from this repo:
   ```bash
   ./scripts/setup-global-orchestrator.sh
   ```

That bootstrap links global skills for both runtimes, registers the stable user-level `claude-code` dispatcher, and ensures `codex-worker` exists in Claude.

Legacy fallback:
- `./scripts/setup-codex-user.sh` still works when only `codex-worker` registration is missing.

See `docs/MCP_PREREQUISITES.md` for the full role-to-model table.

## Installation modes

1. Preferred machine-level bootstrap:
- Script: `scripts/setup-global-orchestrator.sh`
- Works across arbitrary git repos on the same machine without repo-local orchestrator installation.

2. Direct injection (compatibility, no submodule, no symlink):
- See `docs/INSTALL_INJECT_WORKFLOW.md`
- Script: `scripts/inject-workflow.sh`

3. Submodule + copy (compatibility, independent fetch + copied runtime skills):
- See `docs/INSTALL_SUBMODULE_WORKFLOW.md`
- Script: `scripts/install-workflow.sh`

## Runtime reload
After any bootstrap/install/update, restart the matching runtime session so skill indexes reload. To verify the machine-level setup, run `./scripts/setup-global-orchestrator.sh --verify`. To re-check the managed Claude agent layer directly, run `~/.codex/skills/pm/scripts/sync-claude-agents.py --check` from the target repo after machine-level bootstrap, or use `./skills/pm/scripts/sync-claude-agents.py --check` / `./.codex/skills/pm/scripts/sync-claude-agents.py --check` in source and compatibility repo-install layouts.
