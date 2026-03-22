# PM Workflow (Strict)

This workflow is the source of truth for PM orchestration in this repo. Installed target repos receive the same file at both `instructions/pm_workflow.md` and `.config/opencode/instructions/pm_workflow.md`.

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
- No silent failures: when any issue/error appears at a step, report it explicitly to the user immediately.
- Non-critical issues must not stop the workflow; continue execution while tracking impact and mitigation.
- Critical errors may block the workflow; when blocked, include exact reason, impact, and required remediation.

## Phase Error Reporting Policy
- During any phase step, emit explicit issue reporting with:
  - severity (`warning` or `critical`)
  - phase and step
  - impact
  - next action / mitigation
- At the end of every phase, include a `Phase Error Summary` section:
  - `none` when no issues occurred
  - otherwise list all phase issues (resolved and unresolved) with status.
- End-of-phase summary is mandatory even when the workflow continues.

## Command Routing
- `/pm plan: ...` and `$pm plan: ...` map to default single-PRD planning flow.
- `/pm plan big feature: ...` and `$pm plan big feature: ...` map to big-feature planning flow.
- PM helper path resolution:
  - source repo or submodule checkout: `./skills/pm/scripts/pm-command.sh`
  - installed target repo from Codex: `./.codex/skills/pm/scripts/pm-command.sh`
  - installed target repo from Claude: `./.claude/skills/pm/scripts/pm-command.sh`
- Both plan routes must execute the helper gate before Discovery:
  - `<pm-helper> plan gate --route default|big-feature [--mode dynamic-cross-runtime|main-runtime-only]`
- Before Discovery for both plan routes, run a mandatory execution-mode selection gate with exactly two options:
  - `Dynamic Cross-Runtime`
  - `Main Runtime Only`
- Persist selected execution mode across sessions and reuse by default until changed.
- Selection precedence is explicit `--mode` override, then persisted state.
- Outer runtime must be inferred fresh on every plan gate run from the active Codex or Claude session.
- Selected execution mode plus the inferred outer runtime must drive runtime/model for:
  - `project_manager`
  - `team_lead`
  - `pm_beads_plan_handoff`
  - `pm_implement_handoff`
- `Main Runtime Only` must remain usable without opposite-provider MCP.
- `Dynamic Cross-Runtime` with Codex outer runtime must check Claude MCP availability immediately after selection and, if unavailable, block with remediation to fix `claude-code` or switch to `Main Runtime Only`.
- `Dynamic Cross-Runtime` with Claude outer runtime must keep Claude-native main roles as the outer runtime and check `codex-worker` availability immediately after selection for Codex-routed roles.
- The plan gate result is authoritative. If it emits `PLAN_ROUTE_BLOCKED` or `discovery_can_start=0`, do not start Discovery or any downstream phase.
- If outer runtime detection fails or becomes ambiguous, block before Discovery, print a structured error report, and persist the run outcome in telemetry.
- Do not describe a blocked route as degraded mode.
- Claude availability requires both:
  - healthy `claude-code` registration in `codex mcp list`
  - an executable configured command in the actual PM runtime
- `codex-worker` availability for `dynamic-cross-runtime` in Claude requires both:
  - healthy `codex-worker` registration in `claude mcp list`
  - an executable `codex` command in the actual Claude runtime
- PM must treat `[shell_environment_policy.set].PATH`, `[mcp_servers.claude-code.env].PATH`, or an absolute command path as valid ways to satisfy the executable-command requirement.
- PM must treat the Claude runtime `PATH` (including wrapper scripts or absolute command paths) as valid ways to satisfy the `codex-worker` `codex` executability requirement.
- `mcp__claude-code__Agent` / implicit `general-purpose` agent launching is not a valid PM orchestration path.
- Use `codex mcp add claude-code -- claude mcp serve` only when the server is actually missing; if the launcher reports `no supported agent type` or the command is not executable in the PM runtime, treat Claude runtime as unavailable for that session.
- Use `claude mcp add codex-worker -- codex mcp-server` only when `codex-worker` is actually missing; if `codex-worker` is enabled but `codex` is not executable in the Claude runtime, treat `dynamic-cross-runtime` in Claude as unavailable for that session.
- `/pm help` and `$pm help` print command invocations, required phase order, and approval-gate reminders.
- `/pm execution-mode show|set|reset` and `$pm execution-mode show|set|reset` must route to:
  - `<pm-helper> execution-mode show`
  - `<pm-helper> execution-mode set --mode dynamic-cross-runtime|main-runtime-only`
  - `<pm-helper> execution-mode reset`
- `/pm self-check` and `$pm self-check` must run the PM self-diagnostic route:
  - `<pm-helper> self-check run [--mode dynamic-cross-runtime|main-runtime-only]`
  - self-check uses deterministic built-in fixtures plus a synthetic PM task
  - self-check must print verbose warnings/errors to console and persist an artifact bundle under `.codex/self-check-runs/<run-id>/`
  - fail the whole self-check run when Claude registration, executability, or session health is unhealthy
  - do not report self-check as `clean` when artifact capture is broken; artifact-layer defects must end `issues_detected`
  - artifact capture must persist structured per-snapshot evidence including command source, PATH override source, elapsed time, exit status/signal, timeout state, pid/process state, and partial stdout/stderr
  - if helper exits nonzero or does not emit `SELF_CHECK_HEALER_READY`, stop and report the blocked reason
  - if helper emits `SELF_CHECK_HEALER_READY`, spawn a generic `default` outer healer using the generated prompt/context artifacts
  - `SELF_CHECK_REPAIR_BUNDLE` on `issues_detected` is approval-gated repair packaging guidance, not permission to bypass PM gates
  - healer may only package repair work through the normal PM flow and must not bypass approvals
- `/pm self-update` and `$pm self-update` are manual-only and must run the Codex self-update check flow, then trigger:
  - `/pm plan: Inspect latest Codex changes and align orchestrator behavior with runtime-inferred execution-mode policy.`
- Self-update check policy:
  - changelog website is source of truth
  - release/npm signals are corroborative only
  - pending updates are evaluated as one deterministic batch (stable + prerelease by default)
  - changelog items must be split into pipeline-relevant vs non-relevant before planning approval
  - for relevant items, output an integration plan item (`change -> orchestrator integration -> expected improvement`)
  - configurable gates:
    - `PM_SELF_UPDATE_INCLUDE_PRERELEASE=0|1`
    - `PM_SELF_UPDATE_STRICT_MISMATCH=0|1`
- Helper script path resolution:
  - source repo and submodule checkouts: `./skills/pm/scripts/pm-command.sh`
  - installed target repo from Codex: `./.codex/skills/pm/scripts/pm-command.sh`
  - installed target repo from Claude: `./.claude/skills/pm/scripts/pm-command.sh`
- Self-update completion gate is explicit and manual:
  - `<pm-helper> self-update complete --approval approved --prd-approval approved --beads-approval approved --prd-path docs/prd/<approved-prd>.md`
  - completion requires PRD coverage evidence for all pending batch versions and empty `Open Questions`
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
- Execution modes:
  - `dynamic-cross-runtime` (default): main roles stay on the detected outer runtime and routed support roles cross into the opposite provider through MCP.
  - `main-runtime-only`: all roles stay on the detected outer runtime.
- Planning/discovery/docs/research/QA/review orchestration model selection follows the active execution-mode routing matrix.
- Implementation coding tasks follow the active execution-mode routing matrix.
- External Claude agents are allowed only through `claude-code` MCP contract.
- Direct Claude CLI/app orchestration is not allowed.
- If a required Claude-routed role is unavailable under `dynamic-cross-runtime` with Codex outer runtime, or a required `codex-worker` role is unavailable under `dynamic-cross-runtime` with Claude outer runtime, block the current phase and return control to PM. Do not auto-fallback to the main runtime.

## Git / Shipping Policy
- No `git commit` or `git push` during PM execution phases (Discovery through Awaiting Final Review).
- Shipping is a separate, user-triggered step after verification/final review.
- Use `/ship <optional notes>` to run tests, then (only with user confirmation) commit and push.
- AGENTS landing-plane rules apply at session completion after PM execution phases are finished.
- Self-update checkpoint commits from `pm-command.sh self-update complete ...` are explicitly outside active PM execution phases.

## Subagent Orchestration Policy
- PM must launch only supported generic subagent types: `default`, `explorer`, and `worker`.
- PM/Team Lead must launch the required orchestrator subagents by default whenever the current runtime/tool policy permits delegation.
- If current policy blocks delegation for the active session, PM/Team Lead must perform the equivalent repo analysis, external research, or QA work locally and report the skipped delegation as a warning with mitigation and status.
- PM must encode functional role in prompt payloads (for example: `[Role: Senior Engineer]`).
- PM must not depend on named workflow agents or custom launcher types.
- Claude remains an external MCP runtime, not a public launcher type.
- If a Codex-side Claude wrapper exists, it is an internal implementation detail behind the same generic outer contract.
- Mandatory prompt prefix for delegation objectives: `use agent swarm for <objective>`.
- In this workflow, "agent swarm" means parallel fan-out to generic subagents with role-labeled prompts.
- For every external-Claude delegation, PM/Team Lead must validate a context-pack JSON before invocation:
  - `<pm-helper> claude-contract validate-context --context-file <json> --role <role>`
- Required context-pack keys:
  - `feature_objective, prd_context, task_id, acceptance_criteria, implementation_status, changed_files, constraints, evidence, clarifying_instruction`
- External-Claude responses must use missing-context handshake marker when blocked:
  - `CONTEXT_REQUEST|needed_fields=<csv>|questions=<numbered items>`
- PM/Team Lead must parse response handshake before accepting completion:
  - `<pm-helper> claude-contract evaluate-response --response-file <txt> --session-id <id> --role <role>`
- Optional wrapper for multi-step sessions:
  - `<pm-helper> claude-contract run-loop --context-file <json> --response-file <txt> [--response-file <txt> ...] --session-id <id> --role <role>`
- If handshake parser/wrapper returns `status=context_needed` or `status=awaiting_context`, orchestrator must gather requested context and continue in the same Claude session.
- Required discovery support coverage:
  - Senior Engineer (`explorer` by default when delegation is permitted; otherwise local codebase analysis)
  - Librarian (`default` by default when delegation is permitted; otherwise local official-doc research)
  - Smoke Test Planner (`default` by default when delegation is permitted; otherwise local smoke planning)
  - Alternative PM (`default` by default when delegation is permitted; otherwise local alternatives analysis)
- Implementation must run through Team Lead (`default`), which delegates coding to:
  - Backend Engineer (`worker`)
  - Frontend Engineer (`worker`)
  - Security Engineer (`worker`)
- Verification/review subagents:
  - Task Verification (`default`)
  - Jazz Reviewer (`default`, then runtime-routed per profile)

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
4. `Phase Error Summary` (must be `none` or a list of issues with status)
