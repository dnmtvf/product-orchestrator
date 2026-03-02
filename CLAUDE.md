# Project Instructions

## Overview

This is the **PM Orchestrator** — a strict project management skill set for Claude Code. It provides a complete Discovery → PRD → Beads Planning → Implementation → Review → QA workflow with mandatory approval gates and paired support agents.

## Architecture

- **Lead roles** (Claude Opus 4.6 via Claude Code native Task tool): PM, Team Lead, Senior Engineer, Researcher, Jazz Reviewer
- **Worker roles** (MiniMax-M2.5 via Droid MCP): Backend/Frontend/Security Engineers, Librarian, Smoke Test Planner, Alternative PM, Manual QA
- **Execution tracking**: Beads CLI (`bd`) with `.beads/` committed to git
- **Workflow spec**: `instructions/pm_workflow.md` is the source of truth

## Directory Structure

- `skills/` — Claude Code skill definitions (SKILL.md + references + agents)
  - `pm/` — Main orchestrator
  - `pm-discovery/` — Discovery phase
  - `pm-create-prd/` — PRD creation
  - `pm-beads-plan/` — Beads task planning
  - `pm-implement/` — Team Lead orchestration and implementation
  - `agent-browser/` — Browser automation for smoke tests
- `instructions/` — Workflow specification (source of truth)
- `docs/` — PRDs, templates, beads conventions, install guides
- `scripts/` — Injection, installation, Droid MCP server, self-update helpers
- `.beads/` — Beads issue tracking database (committed to git)

## Available Skills

Only these skills are available:
- `/pm` — Main PM workflow orchestrator
- `/pm-discovery` — Discovery phase
- `/pm-create-prd` — PRD creation
- `/pm-beads-plan` — Beads planning
- `/pm-implement` — Implementation and review

## Key Conventions

- Two hard approval gates require the exact reply `approved`: PRD approval and Beads approval
- PRD `Open Questions` must be empty before execution starts
- Beads (`bd`) is the execution source of truth
- Claude Code Task tool `subagent_type` values: `default`, `Explore`, `Plan`
- Droid workers are spawned via `droid-worker` MCP tool call with structured context blocks

## Git Policy

- Do NOT commit or push unless explicitly asked by the user, unless running inside a Ralph orchestration loop (which has its own landing-the-plane protocol).

## Restrictions

- Do NOT use any other skills or agents
- Do NOT invoke other MCP servers for general tasks
- The PM workflow handles all project management through its defined phases
