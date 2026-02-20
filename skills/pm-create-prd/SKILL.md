---
name: pm-create-prd
description: Create or update a PRD from a completed Discovery Summary, run the PRD approval gate, and automatically hand off approved PRDs to $pm-beads-plan.
---

# PM Create PRD (Strict)

## Current Phase
- **PRD** (then **AWAITING PRD APPROVAL**)

## Purpose
Turn a completed Discovery Summary into a production-ready PRD with zero ambiguity and a hard approval gate.

## Subagent Launcher Compatibility (mandatory)
- Spawn only supported generic agent types: `default`, `explorer`, `worker`.
- Encode role in prompt payload for spawned subagents (for example: `[Role: Senior Engineer]`).
- Do not rely on custom named subagent launchers.
- Recommended launcher mapping for this phase:
  - `explorer`: Senior Engineer feasibility and architecture checks.
  - `default`: Librarian and handoff helper agents.

## Paired Support Agents (recommended)
Before finalizing PRD content, proactively consult:
1. **Senior Engineer** (`explorer`) for codebase/architecture feasibility checks.
2. **Librarian** (`default`) for external documentation and platform constraints.
3. **Smoke Test Planner** output from discovery for testability and QA execution readiness.

Use their findings to reduce avoidable user clarification loops.

## Inputs (required)
- Discovery Summary (structured and complete)
- Intended scope for this PRD

If Discovery Summary is incomplete, stop and ask only targeted clarification questions.

## PRD Creation Rules
1. Propose slug format: `YYYY-MM-DD--kebab-slug`.
2. Create/update `docs/prd/<slug>.md` using `docs/prd/_template.md`.
3. Ensure all required sections are filled.
4. Include `Open Questions`.
5. Do not request approval until `Open Questions` is empty.
6. Include a smoke-test subsection covering happy path, unhappy path, regression, and post-implementation QA execution notes.

## Approval Gate
- Move to `Current phase: AWAITING PRD APPROVAL`.
- Require exact user response: `approved`.
- If user requests edits, apply edits and stay in approval phase.

## Automatic Handoff to Beads Planning
When PRD is approved:
- Automatically invoke:
  - `$pm-beads-plan Use PRD docs/prd/<slug>.md and treat PRD approval as confirmed`
- Do not ask user to manually type the next command.
- Preferred orchestration path: invoke via generic `default` `spawn_agent` with role-labeled context (`[Role: PM Beads Plan Handoff]`) and wait for completion.

## Bootstrap (if missing)
Ensure:
- `docs/prd/`
- `docs/prd/_template.md`
- `docs/beads.md`
- `AGENTS.md`

## Output Requirements (every run)
Always include:
1. `Current phase: PRD` or `Current phase: AWAITING PRD APPROVAL`
2. `PRD slug`
3. `PRD path`
4. `Open Questions status` (must be empty before approval request)
5. `What I need from you next`

## Invocation
- Trigger strongly on `$pm-create-prd ...`.
- Also trigger on automatic handoff from `$pm-discovery`.
