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

## Command Routing
- `/pm plan: ...` and `$pm plan: ...` map to default single-PRD planning flow.
- `/pm plan big feature: ...` and `$pm plan big feature: ...` map to big-feature planning flow.
- Big-feature planning must require explicit mode selection:
  - `conflict-aware`
  - `worktree-isolated`
- If mode is missing in the initial request, discovery must ask for it before decomposition.

## Queue Manifest And Idempotency
- Persist big-feature queue state at `docs/prd/_queue/<feature-slug>.json`.
- Per-PRD states must include at least:
  - `pending`, `in_discovery`, `awaiting_prd_approval`, `awaiting_beads_approval`, `approved`, `queued`, `queue_failed`.
- Canonical runnable queue handle is Beads epic ID.
- Idempotency key format: `<prd_slug>:<approval_version>`.
- Duplicate prevention invariants:
  - never enqueue the same idempotency key twice
  - never allow more than one active queue entry for the same PRD slug
- Enqueue retry policy: one automatic retry, then manual intervention (`queue_failed`).
- Queue-ready means `queued` + selectable work + passing preflight.

## Runnable Promotion Gate
- Promotion to `queued` is allowed only when all are true:
  - PRD approval gate exact reply is `approved`
  - Beads approval gate exact reply is `approved`
  - PRD `Open Questions` is empty
- If any condition fails, block promotion and keep explicit non-runnable state:
  - missing PRD approval -> `awaiting_prd_approval`
  - missing Beads approval -> `awaiting_beads_approval`
  - open questions remaining -> `approved` with `blocked_reason=open_questions`

## Async Enqueue Worker
- Big-feature route must enqueue approved PRDs asynchronously with bounded concurrency: `worker_cap=2`.
- Worker selection should operate on ready-approved PRDs only and must be deterministic.
- Each enqueue attempt must be idempotent by `<prd_slug>:<approval_version>`.
- Retry policy: one automatic retry per PRD; second failure transitions PRD to `queue_failed`.
- `queue_failed` requires manual intervention before any additional enqueue attempts.

## Queue Reconciliation Output
- At end of big-feature planning, publish reconciliation summary with per-PRD status and counts:
  - `discovered`
  - `approved`
  - `queued`
  - `queue_failed`
- Report blocked items with explicit reason and next action.

## Model Routing Policy
- Planning/discovery/docs/research/QA/review orchestration: `openai/gpt-5.3-codex` (variant: `high`)
- Implementation coding tasks: `openai/gpt-5.3-codex` (variant: `xhigh`)
- Workflow runtime is Codex-first.
- External Claude agents are allowed only through `claude-code` MCP contract.
- Direct Claude CLI/app orchestration is not allowed.

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

## Dual-Mode Smoke Coverage
- For big-feature workflows, smoke planning and QA must cover both planning modes:
  - `conflict-aware`
  - `worktree-isolated`
- Required categories:
  - happy path
  - unhappy path
  - regression
- Smoke output must include pass/fail evidence and a regression checklist.

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
