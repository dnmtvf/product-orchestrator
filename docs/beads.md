# Beads Convention

This document defines the Beads tracking conventions used in this project.

## PRD Slugs

PRD slugs follow the format: `YYYY-MM-DD--kebab-slug`

Example: `2025-03-02--mcp-config-sync`

## Epic Naming

Each PRD gets an epic named: `<prd-slug> - <prd-path>`

Example: `2025-03-02--mcp-config-sync - docs/prd/2025-03-02--mcp-config-sync.md`

## Task Guidelines

- Tasks must be **atomic** - single-purpose with clear definition of done
- Each task must have explicit **DoD (Definition of Done)**
- Dependencies between tasks must be declared with `bd dep`
- Task titles should be imperative verbs (e.g., "Implement X", "Add Y")
- Beads planning must follow the approved PRD `Technical Implementation Plan` verbatim
- Manual QA tasks must consume the approved PRD `Smoke Test Plan`

## Beads Repository

- `.beads/` directory should be committed to git
- Run `./skills/pm/scripts/pm-command.sh beads preflight --phase beads-planning` before PM/orchestrator `bd` usage
- Shared preflight upgrades `bd`, repairs stale runtime state, rebuilds from tracked backup JSONL when needed, and migrates legacy server-mode repos to embedded mode
- Use `bd graph <epic-id> --compact` to visualize execution
- Use `bd list --parent <epic-id> --pretty` for task view

## Git Worktree Note

Do not improvise `bd init` in git worktrees. Let shared preflight decide whether the main repository store is usable; if not, fail closed and repair the main repo first.
