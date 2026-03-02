# Claude Code PM Workflow (Strict)

This workflow is the source of truth for PM orchestration in Claude Code.

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
- `/pm help` and `$pm help` print command invocations, required phase order, and approval-gate reminders.
- `/pm self-update` and `$pm self-update` are manual-only and must run the Claude Code self-update check flow, then trigger:
  - `/pm plan: Inspect latest Claude Code changes and align orchestrator behavior with Claude Code runtime policy.`
- Helper script path resolution:
  - preferred in installed target repos: `./.claude/skills/pm/scripts/pm-command.sh`
  - source-repo fallback: `./skills/pm/scripts/pm-command.sh`
- Self-update completion gate is explicit and manual:
  - `./.claude/skills/pm/scripts/pm-command.sh self-update complete --approval approved --prd-approval approved --beads-approval approved --prd-path docs/prd/<approved-prd>.md`
  - or `./skills/pm/scripts/pm-command.sh self-update complete --approval approved --prd-approval approved --beads-approval approved --prd-path docs/prd/<approved-prd>.md`
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
- Lead roles (PM, Team Lead, Senior Engineer, Researcher, Jazz Reviewer): `claude-opus-4-6` via Claude Code native Task tool.
- Worker roles (Backend/Frontend/Security Engineers, Librarian, Smoke Test Planner, Alternative PM, Manual QA): `MiniMax-M2.5` via Droid MCP worker.
- Workflow runtime is Claude Code-native with Droid hybrid workers for cost-effective tasks.
- Direct Claude CLI/app orchestration is not allowed; use the native Task tool for Claude subagents.

## Git / Shipping Policy
- No `git commit` or `git push` during PM execution phases (Discovery through Awaiting Final Review).
- Shipping is a separate, user-triggered step after verification/final review.
- Use `/ship <optional notes>` to run tests, then (only with user confirmation) commit and push.
- AGENTS landing-plane rules apply at session completion after PM execution phases are finished.
- Self-update checkpoint commits from `pm-command.sh self-update complete ...` are explicitly outside active PM execution phases.

## Subagent Orchestration Policy
- PM must use the Claude Code Task tool for parallel support work.
- In Claude Code, parallel subagent work means multiple Task tool calls in a single response.
- Supported Task tool `subagent_type` values: `default`, `Explore`, `Plan`.
- Encode functional role in prompt payload (e.g., `[Role: Senior Engineer]`).
- Required support agents in discovery:
  - Senior Engineer (`Explore` subagent) — codebase analysis
  - Librarian (`default` subagent) — external docs via MCP tools
  - Smoke Test Planner (`default` subagent) — test planning
  - Researcher (`default` subagent) — complex research questions
  - Alternative PM (`default` subagent) — alternative solution analysis
- Implementation must run through Team Lead (`default` subagent), which delegates coding to:
  - Backend Engineer (`default` subagent with `[Role: Backend Engineer]`)
  - Frontend Engineer (`default` subagent with `[Role: Frontend Engineer]`)
  - Security Engineer (`default` subagent with `[Role: Security Engineer]`)
- Verification/review agents:
  - Task Verification (`default` subagent)
  - Jazz Reviewer (`default` subagent)
  - AGENTS Compliance Reviewer (`default` subagent)
- Droid worker roles (Librarian, Smoke Test Planner, Alternative PM, implementation engineers) are spawned via `droid-worker` MCP tool call with structured context block, not via the Task tool.

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
