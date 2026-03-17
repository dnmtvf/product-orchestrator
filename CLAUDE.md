# Project Instructions

## Overview

This is the **PM Orchestrator** source repo. It provides a strict Discovery -> PRD -> Beads Planning -> Implementation -> Review -> QA workflow with mandatory approval gates and paired support coverage, using subagents when runtime policy permits and equivalent local work otherwise.

## Architecture

- **Public subagent contract**: only generic launcher types are supported: `default`, `explorer`, and `worker`
- **Runtime policy**:
  - `full-codex`: all roles stay Codex-native
  - `codex-main`: main roles stay Codex-native and Claude-routed roles use `claude-code` MCP
  - `claude-main`: main roles stay Claude-native and Codex-routed roles use `codex-worker` MCP
- **Claude integration**: Claude is an external MCP runtime, not a public launcher type
- **Wrapper boundary**: if a Codex-side Claude wrapper exists, it is internal-only and must not become the public PM contract
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
- Spawn only generic launcher types: `default`, `explorer`, `worker`
- Only delegate when the current runtime/tool policy permits it and the user explicitly requested subagents, delegation, or parallel agent work; otherwise do the equivalent work locally and report the skipped delegation plus mitigation.
- Encode the functional role in prompt payloads instead of relying on named agents or runtime-specific launcher APIs
- Do not depend on `mcp__claude-code__Agent` or implicit `general-purpose` launching for PM orchestration

## Git Policy

- Do NOT commit or push unless explicitly asked by the user, unless running inside a Ralph orchestration loop (which has its own landing-the-plane protocol).

## Restrictions

- Do NOT use any other skills or agents
- Do NOT invoke other MCP servers for general tasks
- The PM workflow handles all project management through its defined phases
