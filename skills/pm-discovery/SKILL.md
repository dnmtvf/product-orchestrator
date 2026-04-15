---
name: pm-discovery
description: Strict PM Discovery Mode. Trigger on $pm-discovery for clarification-first discovery using a four-PM swarm, two tech leads for bounded implementable-option challenge, and automatic handoff to $pm-technical-planning when discovery is complete.
---

# PM Discovery (Strict)

## Current Phase
- **DISCOVERY** (always until handoff starts)

## Core Rules
- Ask **clarifying questions only** in user-facing discovery output.
- Do not skip ambiguous or unanswered areas.
- Discovery may use bounded technical-option input from discovery tech leads to sharpen questions and feasibility checks, but it must not produce the final technical implementation plan.

## Phase Entry Gate (mandatory)
- Discovery may start only if the preceding `plan gate` returned `PLAN_ROUTE_READY` and `discovery_can_start=1`.
- If the active execution mode is `dynamic-cross-runtime` with Codex outer runtime and the gate blocks on Claude availability, do not proceed in degraded mode. Return control to PM and ask whether to switch to `Main Runtime Only`.
- If the active execution mode is `dynamic-cross-runtime` with Claude outer runtime and the gate blocks on `codex-worker` availability, stop and ask PM/user to fix the secondary Codex runtime or choose `Main Runtime Only`.

## PM Helper Path Resolution
- preferred machine-level Codex runtime: `~/.codex/skills/pm/scripts/pm-command.sh`
- preferred machine-level Claude runtime: `~/.claude/skills/pm/scripts/pm-command.sh`
- source repo or submodule checkout: `./skills/pm/scripts/pm-command.sh`
- installed target repo from Codex (compatibility path): `./.codex/skills/pm/scripts/pm-command.sh`
- installed target repo from Claude (compatibility path): `./.claude/skills/pm/scripts/pm-command.sh`

## Subagent Launcher Compatibility (mandatory)
- Spawn only supported generic agent types: `default`, `explorer`, `worker`.
- Launch discovery subagents by default whenever the current runtime/tool policy permits delegation.
- If delegation is not allowed in the current session, complete the equivalent discovery intake locally and report skipped delegations as warnings with mitigation and status.
- Any later `spawn`, subagent, or handoff instruction in this file is conditional on this delegation gate; otherwise continue the same step locally/in-line and report the skipped delegation as a warning with mitigation and status.
- Encode role in prompt payload for every spawned subagent (for example: `[Role: Senior Engineer]`).
- Do not rely on custom named subagent launchers.
- Recommended launcher mapping for discovery:
  - `explorer`: Senior Engineer codebase analysis.
  - `default`: Project Manager swarm, Tech Lead pair, Librarian, Researcher, Alternative PM, and handoff helper agents.
- For Researcher and Alternative PM Claude runs:
  - spawn generic `default` first
  - then invoke `claude-code` MCP
  - do not treat `claude-code` as a launcher type
  - do not use `mcp__claude-code__Agent` / implicit `general-purpose` agent launching as the Discovery Claude path

## Claude MCP Contract (mandatory for external Claude agents)
- Use Claude through MCP server `claude-code` (not direct CLI/app invocation).
- Required environment setup (once):
  - run `~/.codex/skills/pm/scripts/setup-global-orchestrator.sh` (or `./scripts/setup-global-orchestrator.sh` from a checkout before bootstrap) so `claude-code` points at the stable user-level dispatcher
- `codex mcp list` only verifies that `claude-code` is configured/enabled; it does not prove the current environment exposes a usable Claude launcher.
- Only use a `claude-code` MCP tool that explicitly provides prompt/session semantics in the current environment. `mcp__claude-code__Agent` with implicit `general-purpose` is not the Discovery contract.
- If the launcher reports `Agent type 'general-purpose' not found`, `no supported agent type`, or equivalent, treat `claude-code` runtime as unavailable for that step.
- Do not auto-fallback to `codex-native` inside Discovery. Treat this as a critical phase block and return control to PM.
- Remediation split:
  - server missing/not configured -> run the machine-level bootstrap helper so `claude-code` is re-registered to the stable user-level dispatcher
  - server enabled but launcher unusable -> report the launcher limitation, block Discovery, and do not loop on reinstall instructions
- For Claude MCP agents, prompt must start with:
  - `use agent swarm for <objective>`
- Before each external-Claude call, validate a context-pack JSON with:
  - `<pm-helper> claude-contract validate-context --context-file <json> --role <role>`
- Required context-pack fields:
  - `feature_objective, prd_context, task_id, acceptance_criteria, implementation_status, changed_files, constraints, evidence, clarifying_instruction`
- Claude missing-context handshake marker must be:
  - `CONTEXT_REQUEST|needed_fields=<csv>|questions=<numbered items>`
- After each Claude response, parse handshake status with:
  - `<pm-helper> claude-contract evaluate-response --response-file <txt> --session-id <id> --role <role>`
- Optional wrapper for multi-step sessions:
  - `<pm-helper> claude-contract run-loop --context-file <json> --response-file <txt> [--response-file <txt> ...] --session-id <id> --role <role>`
- If parser/wrapper returns `status=context_needed` or `status=awaiting_context`, Discovery must gather requested info and continue in the same Claude session.

## Paired Support Coverage (recommended)
Before asking user follow-ups, proactively gather equivalent coverage from:
1. **Project Manager swarm** (`default`, 4 instances) for parallel clarification framing.
2. **Tech Lead pair** (`default`, 2 instances) for bounded implementable-option challenge and feasibility pressure.
3. **Senior Engineer** (`explorer`) for codebase-derived clarifications.
4. **Librarian** (`default`) for external doc/API clarifications via MCP/browser (`exa`, `context7`, `deepwiki`, `firecrawl`, and `$agent-browser` when needed).
5. **Researcher** (`default`) for complex questions that need deeper investigation.
6. **Alternative PM** (`default`) for critical alternative-solution analysis on every discovery step.

- Preferred path: use subagents for these roles whenever current policy permits it.
- Fallback path: if delegation is blocked, do the same clarification framing, bounded technical-option analysis, codebase analysis, official-doc research, deep research, and alternatives analysis locally and report the skipped delegations as warnings with mitigation and status.

Only ask the user questions that remain unresolved after those checks.

## Project Manager Swarm (mandatory)
- Load prompt from `../pm/references/project-manager.md`.
- Spawn exactly four generic `default` subagents with role-labeled prompt context (`[Role: Project Manager Agent]`).
- Partition their focus so they challenge and help each other instead of duplicating work:
  - problem framing and user outcomes
  - scope/non-goals and acceptance criteria
  - constraints/risks/dependencies
  - rollout/success metrics/failure handling
- Keep final user-facing discovery output clarification-first; the PM swarm exists to sharpen questions and reduce avoidable user loops.

## Discovery Tech Lead Pair (mandatory)
- Load prompt from `../pm/references/tech-lead.md`.
- Spawn exactly two generic `default` subagents with role-labeled prompt context (`[Role: Tech Lead Agent]`).
- Discovery tech leads may:
  - challenge feasibility assumptions
  - propose bounded implementation options that are actually buildable
  - highlight integration, migration, and dependency risks
- Discovery tech leads must not:
  - produce the final technical implementation plan
  - replace PM ownership of clarification and scope

## Researcher (mandatory for complex questions)
- Load prompt from `../pm/references/researcher.md`.
- Launcher type: spawn as generic `default` with role-labeled prompt context (`[Role: Researcher Agent]`).
- If delegation is blocked by current policy, generate the same research artifacts locally and report the skipped delegation as a warning with mitigation and status.
- Runner: use active execution-mode routing from `model-routing.yaml`:
  - `main-runtime-only`: run on the detected outer runtime.
  - `dynamic-cross-runtime` with Codex outer runtime: invoke via `claude-code` MCP using the Claude MCP Contract.
  - `dynamic-cross-runtime` with Claude outer runtime: keep the role Claude-native in the outer runtime.
- For deep investigations, prompt must start with:
  - `use agent swarm for <research objective>`

## Alternative PM (mandatory every discovery step)
- Load prompt from `../pm/references/alternative-pm.md`.
- Launcher type: spawn as generic `default` with role-labeled prompt context (`[Role: Alternative PM Agent]`).
- If delegation is blocked by current policy, generate the same alternatives analysis locally and report the skipped delegation as a warning with mitigation and status.
- Runner: use active execution-mode routing from `model-routing.yaml`:
  - `main-runtime-only`: run on the detected outer runtime.
  - `dynamic-cross-runtime` with Codex outer runtime: invoke via `claude-code` MCP using the Claude MCP Contract.
  - `dynamic-cross-runtime` with Claude outer runtime: invoke via `codex-worker` MCP in the Claude runtime.
- Do not treat `claude-code` as a subagent launcher type.
- Prompt must start with:
  - `use agent swarm for <problem statement and constraints>`
- On every discovery step, request alternatives matrix:
  - multiple solution options
  - tradeoffs/risks
  - recommended option with reasoning

## Discovery Objective
Eliminate ambiguity completely before technical planning begins.

You must make all of these explicit and testable:
- Problem statement (what is wrong/opportunity)
- Target user/persona
- Goals (outcomes)
- Non-goals / out of scope
- Scope (in/out)
- Constraints (time, tech, legal/compliance, budget)
- Acceptance criteria (testable)
- Success metrics (measurable)
- User flows (happy + failure)
- Edge cases / risks
- Rollout expectations
- Dependencies / integrations
- Bounded implementation-option notes that Technical Planning should evaluate next

## Conflict-Aware Decomposition (mandatory for big-feature route)
When route is `$pm plan big feature:` and mode is `conflict-aware`:
- Decompose into PRDs with explicit anti-conflict boundaries.
- For every proposed PRD, record:
  - intended ownership boundary
  - expected file/module touch boundary
  - dependency boundary (what it can and cannot block)
  - known overlap risks with sibling PRDs
- If overlap risk is high, either:
  - re-scope PRDs to reduce overlap, or
  - document a required dependency/sequence contract explicitly.
- Do not mark discovery complete until each PRD has conflict notes sufficient for independent technical planning.

## Worktree-Isolated Decomposition (mandatory for big-feature route)
When route is `$pm plan big feature:` and mode is `worktree-isolated`:
- Decompose PRDs so each can be executed in isolated git worktree context.
- For every proposed PRD, record:
  - target worktree execution boundary
  - cross-PRD merge/integration order expectations
  - files or modules with expected merge-pressure
  - cleanup and rollback considerations for isolated worktrees
- Prefer Ralph-native worktree execution semantics for planning assumptions.
- Do not mark discovery complete until each PRD has worktree execution notes sufficient for independent technical planning.

## Questioning Rules
- Group questions by section (for example: Problem, Scope, UX, Data, Security, Integrations, Rollout).
- Use **numbered questions**.
- After each question add: **Why this matters:** one short sentence.
- Stop after questions and wait for user answers.
- If any answer is ambiguous, follow up with more questions only.

## Completion Check (still in discovery mode)
When you believe discovery may be complete, do not create a PRD or final technical plan.
Output exactly this structure:

1. `Discovery Complete: YES` or `Discovery Complete: NO`
2. If `NO`: list missing clarifications as numbered questions (with "Why this matters").
3. If `YES`: provide a structured **Discovery Summary** in bullets, ready to hand to technical planning.
4. Include `Discovery Technical Handoff Notes` with:
   - bounded implementable options surfaced by discovery tech leads
   - feasibility constraints
   - integration risks
   - technical questions that technical planning must resolve next
5. Include `Alternatives Matrix` and recommended option from Alternative PM.
6. For big-feature conflict-aware mode, include `PRD Conflict Boundaries` section with per-PRD ownership/file/dependency constraints.
7. For big-feature worktree-isolated mode, include `PRD Worktree Execution Notes` section with per-PRD worktree boundaries and merge-order constraints.
8. `Automatic handoff: STARTED` or `Automatic handoff: BLOCKED (<reason>)`.

## Automatic Handoff (mandatory when Discovery Complete is YES)
- Immediately invoke: `$pm-technical-planning Use the Discovery Summary above`.
- Do not ask the user to manually type the next command.
- Pass the full Discovery Summary, discovery technical handoff notes, and proposed PRD slug if available.
- Preferred orchestration path: if delegation is permitted, create a generic `default` sub-agent with role-labeled context (`[Role: PM Technical Planning Handoff]`) for the `$pm-technical-planning` step and wait for completion; otherwise continue directly into technical-planning flow in the same interaction and report the skipped delegation as a warning with mitigation and status.
- If direct skill invocation is unavailable, continue directly into technical-planning flow in the same interaction and mark handoff as blocked with the concrete reason.

## Response Contract (every run)
Always include:
- `Current phase: DISCOVERY`
- Discovery questions or completion check output per rules above
- `What I need from you next`
- `Phase Error Summary` (`none` or issue list with status)

Issue reporting rules:
- Report any step issue explicitly when it occurs (severity, impact, next action).
- Non-critical issues do not stop discovery; continue while tracking mitigation.
- If discovery is blocked by a critical error, state exact blocker and remediation.

## Invocation
- Trigger strongly on explicit `$pm-discovery ...`.
- If user asks for ideas/solutions during this mode, redirect to clarification-first discovery while using the tech-lead pair to tighten feasibility and option quality in the background.
