# Project Instructions

## Overview

This is the **PM Orchestrator** — a strict project management skill set for Claude Code. It provides a complete Discovery → PRD → Beads Planning → Implementation → Review → QA workflow with mandatory approval gates and paired support agents.

## Architecture

- **Claude-code roles** (via Claude Code native Task tool, model not pinned): PM, Team Lead, Librarian, Researcher, Backend/Frontend/Security Engineers, AGENTS Compliance Reviewer, Codex Reviewer, Manual QA, Task Verification
- **Codex-native roles** (gpt-5.3-codex xhigh via `codex-worker` MCP): Senior Engineer, Smoke Test Planner, Alternative PM, Jazz Reviewer
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
- `scripts/` — Injection, installation, self-update helpers
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
- Worker subagents are spawned via Claude Code Task tool with structured context blocks

## Git Policy

- Do NOT commit or push unless explicitly asked by the user, unless running inside a Ralph orchestration loop (which has its own landing-the-plane protocol).

## Restrictions

- Do NOT use any other skills or agents
- Do NOT invoke other MCP servers for general tasks
- The PM workflow handles all project management through its defined phases
