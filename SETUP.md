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

## Why symlinks are required
The runtime `Skill` loader resolves skills from runtime skill directories (for this machine: `~/.claude/skills` and `~/.codex/skills`).

Referencing a path from `AGENTS.md` is not enough to make `/skill` invocable. The skill must be discoverable from runtime skill directories.

## Prerequisites
- MCP requirements: `docs/MCP_PREREQUISITES.md`

## Installation modes

1. Direct injection (no submodule, no symlink):
- See `docs/INSTALL_INJECT_WORKFLOW.md`
- Script: `scripts/inject-workflow.sh`

2. Submodule + copy (independent fetch + copied runtime skills):
- See `docs/INSTALL_SUBMODULE_WORKFLOW.md`
- Script: `scripts/install-workflow.sh`

## Runtime reload
After any install/update, restart Codex/Claude session so skill indexes reload.
