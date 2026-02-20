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

## Subagent Launcher Compatibility (mandatory)
- Spawn only supported generic agent types: `default`, `explorer`, `worker`.
- Encode role in prompt payload for every spawned subagent (for example: `[Role: Senior Engineer]`).
- Do not rely on custom named subagent launchers.
- Recommended launcher mapping for discovery:
  - `explorer`: Senior Engineer codebase analysis.
  - `default`: Librarian, Smoke Test Planner, Alternative PM, and handoff helper agents.
- For Smoke Test Planner and Alternative PM Claude runs:
  - spawn generic `default` first
  - then invoke `claude-code` MCP
  - do not treat `claude-code` as a launcher type

## Claude MCP Contract (mandatory for external Claude agents)
- Use Claude through MCP server `claude-code` (not direct CLI/app invocation).
- Required environment setup (once):
  - `codex mcp add claude-code -- claude mcp serve`
- Start a new Claude interaction via `claude-code` MCP tool call with the full prompt.
- Continue follow-ups/answers in the same Claude interaction using the returned conversation/session identifier from the MCP response.
- If `claude-code` MCP is unavailable, report a blocked state with exact reason.
- For Claude MCP agents, prompt must start with:
  - `use agent swarm for <objective>`

## Paired Support Agents (recommended)
Before asking user follow-ups, proactively consult:
1. **Senior Engineer** (`explorer`) for codebase-derived clarifications.
2. **Librarian** (`default`) for external doc/API clarifications via MCP/browser (`exa`, `context7`, `deepwiki`, `firecrawl`, and `$agent-browser` when needed).
3. **Smoke Test Planner** (`default`) for discovery-phase smoke-test planning (happy/unhappy/regression) and post-implementation QA plan.
4. **Alternative PM** (`default`) for critical alternative-solution analysis on every discovery step.

Only ask the user questions that remain unresolved after those checks.

## Smoke Test Planner (mandatory)
- Load prompt from `references/smoke-test-planner.md`.
- Launcher type: spawn as generic `default` with role-labeled prompt context (`[Role: Smoke Test Planner Agent]`).
- Invoke via `claude-code` MCP using the Claude MCP Contract.
- Prompt must start with:
  - `use agent swarm for smoke test planning: <feature objective + constraints>`
- Do not treat `claude-code` as a subagent launcher type.
- During discovery, generate:
  - happy-path smoke tests
  - unhappy-path smoke tests
  - regression smoke tests
  - post-implementation test execution plan (include browser checks when needed)
- Include this smoke-test plan in the Discovery Summary for downstream PRD and QA phases.

## Alternative PM (mandatory every discovery step)
- Load prompt from `references/alternative-pm.md`.
- Launcher type: spawn as generic `default` with role-labeled prompt context (`[Role: Alternative PM Agent]`).
- Invoke via `claude-code` MCP using the Claude MCP Contract.
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
7. `Automatic handoff: STARTED` or `Automatic handoff: BLOCKED (<reason>)`.

## Automatic Handoff (mandatory when Discovery Complete is YES)
- Immediately invoke: `$pm-create-prd Use the Discovery Summary above`.
- Do not ask the user to manually type the next command.
- Pass the full Discovery Summary (including smoke tests and alternatives matrix) and proposed slug.
- Preferred orchestration path: create a generic `default` sub-agent with role-labeled context (`[Role: PM Create PRD Handoff]`) for the `$pm-create-prd` step and wait for completion.
- If direct skill invocation is unavailable, continue directly into PRD creation flow in the same interaction and mark handoff as blocked with the concrete reason.

## Response Contract (every run)
Always include:
- `Current phase: DISCOVERY`
- Discovery questions or completion check output per rules above
- `What I need from you next`

## Invocation
- Trigger strongly on explicit `$pm-discovery ...`.
- If user asks for ideas/solutions during this mode, redirect to clarifying questions only.
