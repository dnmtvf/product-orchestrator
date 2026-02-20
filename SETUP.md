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

## Install / relink skills to this repo
Run:

```bash
set -e
mkdir -p "$HOME/.claude/skills" "$HOME/.codex/skills"
for s in pm pm-discovery pm-create-prd pm-beads-plan pm-implement agent-browser; do
  rm -f "$HOME/.claude/skills/$s"
  rm -f "$HOME/.codex/skills/$s"
  ln -s "$HOME/product-orchestrator/skills/$s" "$HOME/.claude/skills/$s"
  ln -s "$HOME/product-orchestrator/skills/$s" "$HOME/.codex/skills/$s"
done
```

## Verify links

```bash
for s in pm pm-discovery pm-create-prd pm-beads-plan pm-implement agent-browser; do
  echo "$s"
  readlink "$HOME/.claude/skills/$s"
  readlink "$HOME/.codex/skills/$s"
done
```

Expected target for each link:
`$HOME/product-orchestrator/skills/<skill-name>`

## Runtime reload
After linking/updating skills, restart Codex/Claude session so the skill index reloads.

## Backups and rollback
If setup scripts moved previous skill folders aside, restore by moving directories back from the timestamped backup folders:
- `~/.claude/skills/.backup-product-orchestrator-<timestamp>/`
- `~/.codex/skills/.backup-product-orchestrator-<timestamp>/`

Then remove the symlinks and restart the session.
