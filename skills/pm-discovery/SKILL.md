---
name: pm-discovery
description: Strict PM Discovery Mode. Trigger on $pm-discovery for questions-only clarification, including smoke-test planning and second-PM alternatives analysis, then automatically hand off to $pm-create-prd when discovery is complete.
---

# PM Discovery (Strict)

## Current Phase
- **DISCOVERY** (always until handoff starts)

## Core Rules
- Ask **clarifying questions only**.
- Never provide solutions, implementation ideas, PRD drafts, task breakdowns, or code.
- Do not skip ambiguous or unanswered areas.

## Phase Entry Gate (mandatory)
- Discovery may start only if the preceding `plan gate` returned `PLAN_ROUTE_READY` and `discovery_can_start=1`.
- If the active execution mode is `dynamic-cross-runtime` with Codex outer runtime and the gate blocks on Claude availability, do not proceed in degraded mode. Return control to PM and ask whether to switch to `Main Runtime Only`.
- If the active execution mode is `dynamic-cross-runtime` with Claude outer runtime and the gate blocks on `codex-worker` availability, stop and ask PM/user to fix the secondary Codex runtime or choose `Main Runtime Only`.

## PM Helper Path Resolution
- source repo or submodule checkout: `./skills/pm/scripts/pm-command.sh`
- installed target repo from Codex: `./.codex/skills/pm/scripts/pm-command.sh`
- installed target repo from Claude: `./.claude/skills/pm/scripts/pm-command.sh`

## Subagent Launcher Compatibility (mandatory)
- Spawn only supported generic agent types: `default`, `explorer`, `worker`.
- Launch discovery subagents by default whenever the current runtime/tool policy permits delegation.
- If delegation is not allowed in the current session, complete the equivalent discovery intake locally and report skipped delegations as warnings with mitigation and status.
- Any later `spawn`, subagent, or handoff instruction in this file is conditional on this delegation gate; otherwise continue the same step locally/in-line and report the skipped delegation as a warning with mitigation and status.
- Encode role in prompt payload for every spawned subagent (for example: `[Role: Senior Engineer]`).
- Do not rely on custom named subagent launchers.
- Recommended launcher mapping for discovery:
  - `explorer`: Senior Engineer codebase analysis.
  - `default`: Librarian, Smoke Test Planner, Alternative PM, and handoff helper agents.
- For Smoke Test Planner and Alternative PM Claude runs:
  - spawn generic `default` first
  - then invoke `claude-code` MCP
  - do not treat `claude-code` as a launcher type
  - use the repo-owned `claude-code-mcp` wrapper `Agent` tool with generic launcher types instead of the raw upstream `claude mcp serve` Agent path

## Claude MCP Contract (mandatory for external Claude agents)
- Use Claude through MCP server `claude-code` (not direct CLI/app invocation).
- Required environment setup (once):
  - `codex mcp add claude-code -- ./skills/pm/scripts/claude-code-mcp`
- `codex mcp list` only verifies that `claude-code` is configured/enabled; it does not prove the current environment exposes a usable Claude launcher.
- Use the repo-owned `claude-code-mcp` wrapper `Agent` tool with generic launcher types. Do not depend on the raw upstream `claude mcp serve` Agent path or implicit `general-purpose` launching.
- If the launcher reports `Agent type 'general-purpose' not found`, `no supported agent type`, or equivalent, treat `claude-code` runtime as unavailable for that step.
- Do not auto-fallback to `codex-native` inside Discovery. Treat this as a critical phase block and return control to PM.
- Remediation split:
  - server missing/not configured -> `codex mcp add claude-code -- ./skills/pm/scripts/claude-code-mcp`
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
1. **Senior Engineer** (`explorer`) for codebase-derived clarifications.
2. **Librarian** (`default`) for external doc/API clarifications via MCP/browser (`exa`, `context7`, `deepwiki`, `firecrawl`, and `$agent-browser` when needed).
3. **Smoke Test Planner** (`default`) for discovery-phase smoke-test planning (happy/unhappy/regression) and post-implementation QA plan.
4. **Alternative PM** (`default`) for critical alternative-solution analysis on every discovery step.

- Preferred path: use subagents for these roles whenever current policy permits it.
- Fallback path: if delegation is blocked, do the same codebase analysis, official-doc research, smoke planning, and alternatives analysis locally and report the skipped delegations as warnings with mitigation and status.

Only ask the user questions that remain unresolved after those checks.

## Smoke Test Planner (mandatory)
- Load prompt from `references/smoke-test-planner.md`.
- Launcher type: spawn as generic `default` with role-labeled prompt context (`[Role: Smoke Test Planner Agent]`).
- If delegation is blocked by current policy, generate the same smoke-test artifacts locally and report the skipped delegation as a warning with mitigation and status.
- Runner: use active execution-mode routing from `model-routing.yaml`:
  - `main-runtime-only`: run on the detected outer runtime.
  - `dynamic-cross-runtime` with Codex outer runtime: invoke via `claude-code` MCP using the Claude MCP Contract.
  - `dynamic-cross-runtime` with Claude outer runtime: invoke via `codex-worker` MCP in the Claude runtime.
- Prompt must start with:
  - `use agent swarm for smoke test planning: <feature objective + constraints>`
- Do not treat `claude-code` as a subagent launcher type.
- During discovery, generate:
  - happy-path smoke tests
  - unhappy-path smoke tests
  - regression smoke tests
  - post-implementation test execution plan (include browser checks when needed)
- For big-feature planning, also generate dual-mode regression coverage:
  - command routing checks (`plan` vs `plan big feature`)
  - `conflict-aware` mode smoke checks
  - `worktree-isolated` mode smoke checks
  - queue gate/retry/reconciliation regression checklist
- Include this smoke-test plan in the Discovery Summary for downstream PRD and QA phases.

## Alternative PM (mandatory every discovery step)
- Load prompt from `references/alternative-pm.md`.
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
- Include alternatives analysis in Discovery Summary for downstream PRD decisions.

## Discovery Objective
Eliminate ambiguity completely before any planning or execution handoff.

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
- Do not mark discovery complete until each PRD has conflict notes sufficient for independent implementation planning.

## Worktree-Isolated Decomposition (mandatory for big-feature route)
When route is `$pm plan big feature:` and mode is `worktree-isolated`:
- Decompose PRDs so each can be executed in isolated git worktree context.
- For every proposed PRD, record:
  - target worktree execution boundary
  - cross-PRD merge/integration order expectations
  - files or modules with expected merge-pressure
  - cleanup and rollback considerations for isolated worktrees
- Prefer Ralph-native worktree execution semantics for planning assumptions.
- Do not mark discovery complete until each PRD has worktree execution notes sufficient for independent planning.

## Questioning Rules
- Group questions by section (for example: Problem, Scope, UX, Data, Security, Integrations, Rollout).
- Use **numbered questions**.
- After each question add: **Why this matters:** one short sentence.
- Stop after questions and wait for user answers.
- If any answer is ambiguous, follow up with more questions only.

## Completion Check (still in discovery mode)
When you believe discovery may be complete, do not create a PRD.
Output exactly this structure:

1. `Discovery Complete: YES` or `Discovery Complete: NO`
2. If `NO`: list missing clarifications as numbered questions (with "Why this matters").
3. If `YES`: provide a structured **Discovery Summary** in bullets, ready to paste into PRD creation.
4. Propose PRD slug format: `YYYY-MM-DD--kebab-slug`.
5. Include `Smoke Test Plan` with happy/unhappy/regression groups and execution notes.
6. Include `Alternatives Matrix` and recommended option from Alternative PM.
7. For big-feature conflict-aware mode, include `PRD Conflict Boundaries` section with per-PRD ownership/file/dependency constraints.
8. For big-feature worktree-isolated mode, include `PRD Worktree Execution Notes` section with per-PRD worktree boundaries and merge-order constraints.
9. For big-feature route, include `Dual-Mode Regression Checklist` with pass/fail criteria for both planning modes.
10. `Automatic handoff: STARTED` or `Automatic handoff: BLOCKED (<reason>)`.

## Automatic Handoff (mandatory when Discovery Complete is YES)
- Immediately invoke: `$pm-create-prd Use the Discovery Summary above`.
- Do not ask the user to manually type the next command.
- Pass the full Discovery Summary (including smoke tests and alternatives matrix) and proposed slug.
- Preferred orchestration path: if delegation is permitted, create a generic `default` sub-agent with role-labeled context (`[Role: PM Create PRD Handoff]`) for the `$pm-create-prd` step and wait for completion; otherwise continue directly into PRD creation flow in the same interaction and report the skipped delegation as a warning with mitigation and status.
- If direct skill invocation is unavailable, continue directly into PRD creation flow in the same interaction and mark handoff as blocked with the concrete reason.

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
- If user asks for ideas/solutions during this mode, redirect to clarifying questions only.
