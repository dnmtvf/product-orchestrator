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

## Beads Repository

- `.beads/` directory should be committed to git
- Use `bd init` to initialize (not in git worktrees)
- Use `bd graph <epic-id> --compact` to visualize execution
- Use `bd list --parent <epic-id> --pretty` for task view

## Git Worktree Note

Do not run `bd init` in git worktrees. Initialize in the main repository first.
