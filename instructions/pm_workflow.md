# OpenCode PM Workflow (Strict)

This workflow is the source of truth for PM orchestration in OpenCode.

## Required Phase Order
`Discovery -> PRD -> Awaiting PRD Approval -> Beads Planning -> Awaiting Beads Approval -> Team Lead Orchestration -> Implementation -> Post-Implementation Reviews -> Review Iteration -> Manual QA Smoke Tests -> Awaiting Final Review`

## Hard Rules
- No assumptions.
- Discovery must ask numbered clarification questions with `Why it matters:` until ambiguity is removed.
- Two human gates require the exact reply `approved`:
  - PRD approval gate
  - Beads approval gate
- Do not start implementation without approved PRD + approved Beads plan.
- PRD must exist at `docs/prd/<slug>.md`.
- PRD `Open Questions` must be empty before execution.
- Beads (`bd`) is the execution source of truth and `.beads/` must stay in git.

## Model Routing Policy
- Planning/discovery/docs/research/QA/review orchestration: `kimi-for-coding/k2p5`
- Implementation coding tasks: `openai/gpt-5.3-codex` (variant: `xhigh`)
- Do not use Claude MCP in this flow.

## Git / Shipping Policy
- No `git commit` or `git push` during PM execution phases (including Implementation).
- Shipping is a separate, user-triggered step after verification.
- Use `/ship <optional notes>` to run tests, then (only with user confirmation) commit and push.

## Subagent Orchestration Policy
- PM must use `Task(...)` subagent calls for parallel support work.
- Mandatory prompt prefix for delegation objectives: `use agent swarm for <objective>`.
- In OpenCode, "agent swarm" means parallel `Task(...)` fan-out to specialized subagents.
- Required support subagents in discovery:
  - `pm-research`
  - `pm-docs`
  - `pm-qa` (for smoke-test planning)
- Implementation must run through `pm-team-lead`, which delegates coding to:
  - `pm-backend`
  - `pm-frontend`
  - `pm-security`
- Verification/review subagents:
  - `pm-verify`
  - `pm-jazz-review`

## Bootstrap Requirements
Ensure the repo has:
- `AGENTS.md`
- `docs/prd/_template.md`
- `docs/beads.md`

## Output Contract
Each PM response must include:
1. `Current phase: <...>`
2. Phase-appropriate output
3. `What I need from you next`
