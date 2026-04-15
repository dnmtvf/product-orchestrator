---
name: pm-technical-planning
description: Strict PM Technical Planning Mode. Trigger on $pm-technical-planning for four-tech-lead consensus planning after Discovery, then automatically hand off to $pm-create-prd.
---

# PM Technical Planning (Strict)

## Current Phase
- **TECHNICAL PLANNING**

## Purpose
Turn a completed Discovery Summary into one consensus technical implementation plan before PRD creation starts.

## Inputs (required)
- Discovery Summary (structured and complete)
- Discovery Technical Handoff Notes
- Intended scope for this planning run

If discovery clarification is incomplete, stop and ask only targeted clarification questions.

## Subagent Launcher Compatibility (mandatory)
- Spawn only supported generic agent types: `default`, `explorer`, `worker`.
- Launch technical-planning subagents by default whenever the current runtime/tool policy permits delegation.
- If delegation is not allowed in the current session, complete the equivalent technical-planning work locally and report skipped delegations as warnings with mitigation and status.
- Any later `spawn`, subagent, or handoff instruction in this file is conditional on this delegation gate; otherwise continue the same step locally/in-line and report the skipped delegation as a warning with mitigation and status.
- Encode role in prompt payload for every spawned subagent (for example: `[Role: Tech Lead Agent]`).
- Do not rely on custom named subagent launchers.
- Recommended launcher mapping for technical planning:
  - `default`: Tech Lead, Librarian, Researcher, and handoff helper agents.
  - `explorer`: Senior Engineer read/analyze spot checks when a local codebase decision needs escalation.

## Preconditions (hard gate)
Before technical planning starts, verify all of the following:
1. Discovery is complete.
2. Discovery clarification questions are exhausted.
3. The workflow is not blocked on runtime-routing availability.

If any precondition fails:
- **STOP**.
- State exactly what is missing.
- Ask only for the missing prerequisite(s).

## Tech Lead Swarm (mandatory)
- Load prompt from `../pm/references/tech-lead.md`.
- Spawn exactly four generic `default` subagents with role-labeled prompt context (`[Role: Tech Lead Agent]`).
- All four tech leads work as one swarm:
  - help each other
  - challenge each other
  - compare materially different implementation approaches
  - converge on one technical implementation plan by consensus
- If consensus is not reached, technical planning is not complete.
- If delegation is blocked by current policy, produce the same consensus-seeking technical-planning artifacts locally and report the skipped delegation as a warning with mitigation and status.
- Runner: use active execution-mode routing from `model-routing.yaml`:
  - `main-runtime-only`: run on the detected outer runtime.
  - `dynamic-cross-runtime` with Codex outer runtime: invoke via `claude-code` MCP using the Claude MCP Contract.
  - `dynamic-cross-runtime` with Claude outer runtime: invoke via `codex-worker` MCP in the Claude runtime.

## Research And Documentation Support (as needed)
- **Librarian** (`default`) may be consulted for standards, docs, external platform constraints, and compatibility facts.
- **Researcher** (`default`) may be consulted for complex/no-straight-answer technical questions.
- Use the same active execution-mode routing and delegation/fallback rules already defined in the PM orchestrator.

## Technical Planning Rules
1. Produce one consensus technical implementation plan, not multiple unmerged plans.
2. The plan must stay within the approved discovery scope and non-goals.
3. The plan must cover:
   - architecture boundaries
   - file/module ownership expectations
   - dependency order
   - migration/rollout implications
   - risk hotspots and fallback paths
   - what the later smoke-test plan must validate
4. Do not generate the final `Smoke Test Plan` in this phase.
5. Do not create Beads tasks in this phase.
6. The output of this phase must be ready to become the PRD's `Technical Implementation Plan` section.

## Completion Check
When you believe technical planning may be complete, do not create Beads tasks.
Output exactly this structure:

1. `Technical Planning Complete: YES` or `Technical Planning Complete: NO`
2. If `NO`: list numbered consensus blockers or targeted clarification questions (with "Why this matters").
3. If `YES`: provide a structured **Technical Planning Summary** in bullets, ready to paste into the PRD.
4. Include `Consensus Record` with:
   - selected technical approach
   - rejected alternatives
   - why consensus was reached
5. Include `Smoke-Test Planning Inputs` with:
   - behaviors the later smoke plan must cover
   - high-risk unhappy paths
   - required regression-sensitive areas
6. `Automatic handoff: STARTED` or `Automatic handoff: BLOCKED (<reason>)`.

## Automatic Handoff (mandatory when Technical Planning Complete is YES)
- Immediately invoke: `$pm-create-prd Use the Discovery Summary and Technical Planning Summary above`.
- Do not ask the user to manually type the next command.
- Pass the full Discovery Summary, Discovery Technical Handoff Notes, Technical Planning Summary, and any proposed slug notes.
- Preferred orchestration path: if delegation is permitted, create a generic `default` sub-agent with role-labeled context (`[Role: PM Create PRD Handoff]`) for the `$pm-create-prd` step and wait for completion; otherwise continue directly into PRD creation flow in the same interaction and report the skipped delegation as a warning with mitigation and status.
- If direct skill invocation is unavailable, continue directly into PRD creation flow in the same interaction and mark handoff as blocked with the concrete reason.

## Response Contract (every run)
Always include:
- `Current phase: TECHNICAL PLANNING`
- Technical planning questions or completion check output per rules above
- `What I need from you next`
- `Phase Error Summary` (`none` or issue list with status)

Issue reporting rules:
- Report any step issue explicitly when it occurs (severity, impact, next action).
- Non-critical issues do not stop technical planning; continue while tracking mitigation.
- If technical planning is blocked by a critical error, state exact blocker and remediation.

## Invocation
- Trigger strongly on explicit `$pm-technical-planning ...`.
- Also trigger on automatic handoff from `$pm-discovery`.
