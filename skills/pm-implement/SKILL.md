---
name: pm-implement
description: Execute approved Beads tasks through a Team Lead orchestration model, run automated post-implementation reviews, complete review iteration, then run Manual QA smoke tests and return for final user review.
---

# PM Implement (Strict)

## Current Phase
- **TEAM LEAD ORCHESTRATION** (then **IMPLEMENTATION**, **POST-IMPLEMENTATION REVIEWS**, **REVIEW ITERATION**, **MANUAL QA SMOKE TESTS**, and **AWAITING FINAL REVIEW**)

## Preconditions (hard gate)
Before implementation starts, verify:
1. PRD is approved.
2. Beads task graph is generated and ready to execute.
3. Epic ID is known and exists.
4. Team Lead orchestration is initialized.

If any precondition fails:
- Stop and ask only for missing prerequisite(s).

## Big-Feature Queue Preconditions (mandatory for `plan big feature`)
- Before starting a PRD work stream, verify manifest item is queue-ready:
  - `state=queued`
  - `epic_id` present
  - `readiness.selectable=true`
  - `readiness.doctor_pass=true`
- If not queue-ready, do not start implementation for that PRD and report blocked reason.

## Claude-Dependent Phase Blocking (mandatory)
- Implementation and review phases must not reinterpret an earlier blocked orchestration gate as degraded mode.
- If a required Claude-routed role under `dynamic-cross-runtime` with Codex outer runtime, or a required `codex-worker` role under `dynamic-cross-runtime` with Claude outer runtime, becomes unavailable during implementation, verification, review, or manual QA, stop the affected phase and return control to PM/Team Lead.
- Do not auto-fallback to `codex-native` inside implementation or review phases when a required Claude-routed role is unavailable.

## PM Helper Path Resolution
- preferred machine-level Codex runtime: `~/.codex/skills/pm/scripts/pm-command.sh`
- preferred machine-level Claude runtime: `~/.claude/skills/pm/scripts/pm-command.sh`
- source repo or submodule checkout: `./skills/pm/scripts/pm-command.sh`
- installed target repo from Codex (compatibility path): `./.codex/skills/pm/scripts/pm-command.sh`
- installed target repo from Claude (compatibility path): `./.claude/skills/pm/scripts/pm-command.sh`

## Claude MCP Contract (mandatory for external Claude agents)
- Use Claude through MCP server `claude-code` (not direct CLI/app invocation).
- Required environment setup (once):
  - run `~/.codex/skills/pm/scripts/setup-global-orchestrator.sh` (or `./scripts/setup-global-orchestrator.sh` from a checkout before bootstrap) so `claude-code` points at the stable user-level dispatcher
- `codex mcp list` only verifies that `claude-code` is configured/enabled; it does not prove the current environment exposes a usable Claude launcher.
- Only use a `claude-code` MCP tool that explicitly provides prompt/session semantics in the current environment. `mcp__claude-code__Agent` with implicit `general-purpose` is not the implementation contract.
- If the launcher reports `Agent type 'general-purpose' not found`, `no supported agent type`, or equivalent, treat `claude-code` runtime as unavailable for that step.
- In that case, block the current phase and return control to PM/Team Lead.
- Remediation split:
  - server missing/not configured -> run the machine-level bootstrap helper so `claude-code` is re-registered to the stable user-level dispatcher
  - server enabled but launcher unusable -> report the launcher limitation, block the current phase, and do not loop on reinstall instructions

## Codex Reviewer Contract (native-first)
- Codex reviewer runs with the Codex-native `model` and `model_reasoning_effort` resolved from repo `.codex/config.toml`, then `~/.codex/config.toml`.
- **Primary invocation:** spawn as generic `default` with role-labeled context (`[Role: Codex Reviewer]`) and load `references/codex-reviewer.md`.
- **Session model:** keep one review session and run 4 sequential layer passes (architecture -> syntax -> composition -> logic).
- **Availability policy:** if native reviewer execution is unavailable, block the review phase and report the exact reason to PM.
- **Failure policy:** if any required reviewer fails (Jazz, AGENTS Compliance, or Codex), block the review phase and report the failure to PM.

## Subagent Launcher Compatibility (mandatory across implementation phases)
- Spawn only supported generic agent types: `default`, `explorer`, `worker`.
- Required implementation, verification, review, and QA subagents are default behavior whenever the current runtime/tool policy permits delegation.
- Encode role in prompt payload for every spawned subagent (for example: `[Role: Backend Engineer]`).
- Do not rely on custom named subagent launchers.
- Recommended launcher mapping:
  - `worker`: Backend Engineer, Frontend Engineer, Security Engineer implementation work.
  - `explorer`: Senior Engineer read/analyze checks and codebase triage.
  - `default`: Team Lead, Task Verification, AGENTS Compliance Reviewer, Jazz reviewer, Manual QA Smoke agent.
  - `default`: Codex reviewer (config-resolved Codex-native model, 4-layer post-implementation review).
- For Task Verification workflows:
  - spawn as generic `default` with role-labeled prompt
- For Jazz reviewer workflows:
  - spawn as generic `default` with role-labeled prompt, then run via `claude-code` MCP per Claude MCP Contract
  - do not treat `claude-code` as a launcher type
- For Codex reviewer:
  - spawn as generic `default` with role-labeled prompt
  - if unavailable, block review and report exact reason

## Team Lead Orchestration (mandatory before coding)
- Create Team Lead agent from `references/team-lead.md`.
- Team Lead must **not** implement code directly.
- Team Lead organizes and coordinates these engineer subagents:
  - Backend Engineer (`references/backend-engineer.md`)
  - Frontend Engineer (`references/frontend-engineer.md`)
  - Security Engineer (`references/security-engineer.md`)
- Launcher compatibility rule (CLI/Desktop):
  - do not assume custom named subagent launchers exist
  - spawn supported generic agent types only (`default`, `explorer`, `worker`)
  - assign role via prompt payload (for example: `[Role: Backend Engineer] ...`)
  - use `explorer` for read/analyze tasks and `worker` for implementation tasks
- Team Lead also runs a Task Verification agent after each implemented task:
  - `references/task-verification.md`
  - run as generic `default` with role-labeled prompt
- Engineer onboarding protocol (mandatory for every task):
  - Engineers are instructed to run a mandatory onboarding sequence before implementation:
    1. **Read project rules**: CLAUDE.md and AGENTS.md from project root
    2. **Scan code patterns**: in-scope files + 2-3 neighboring files for conventions and style
    3. **4-layer checklist**: produce explicit architecture/syntax/composition/logic assessment before writing code
    4. **Ask Team Lead**: on both hard blockers and soft ambiguity — engineers will never guess
  - Team Lead must expect and handle engineer questions promptly (technical answers directly, product/scope via PM)
  - Team Lead must resolve conflicting code patterns when engineers flag them during scanning
  - Team Lead must review the 4-layer checklist output and resolve any gaps before authorizing implementation
- Team Lead responsibilities:
  - split implementation into parallelizable streams
  - assign and sequence work across subagents
  - track integration dependencies and merge order
  - maximize throughput while preserving quality and security gates
  - keep all subagents focused on the current feature goal, PRD scope, and DoD
  - answer technical implementation questions directly for the engineering subagents
  - route product/scope questions to PM, then relay PM decisions back to engineering and update tasks/comments accordingly
  - when implementation introduces new behavior/logic or modifies existing behavior/logic, create and run a documentation-sync task owned by Librarian before final handoff
- Preferred orchestration calls:
  - spawn Team Lead first as generic `default` with role-labeled context (`[Role: Team Lead Agent]`)
  - Team Lead spawns engineer subagents using role-labeled prompts (`worker` for implementation, `explorer` for read/analyze)
  - Team Lead runs task verification after each completed task
  - Team Lead reports status and blockers back to PM

## Claude Invocation Context Pack (mandatory)
Whenever Team Lead invokes any external Claude agent, the prompt must include sufficient context:
1. Feature summary and business objective
2. PRD path/section or extracted requirements
3. Task ID and exact acceptance criteria/DoD
4. Current implementation status and changed files/modules
5. Constraints (performance, security, compatibility, rollout)
6. Relevant logs/test evidence (if available)
7. Explicit instruction:
   - `If you have missing or ambiguous context, ask specific clarifying questions before final recommendations.`
- Before each external-Claude call, Team Lead must validate the context-pack JSON:
  - `<pm-helper> claude-contract validate-context --context-file <json> --role <role>`
- Context-pack JSON must include keys:
  - `feature_objective, prd_context, task_id, acceptance_criteria, implementation_status, changed_files, constraints, evidence, clarifying_instruction`
- Claude missing-context handshake marker must be:
  - `CONTEXT_REQUEST|needed_fields=<csv>|questions=<numbered items>`
- After each Claude response, Team Lead must parse handshake status:
  - `<pm-helper> claude-contract evaluate-response --response-file <txt> --session-id <id> --role <role>`
- Optional wrapper for multi-step sessions:
  - `<pm-helper> claude-contract run-loop --context-file <json> --response-file <txt> [--response-file <txt> ...] --session-id <id> --role <role>`
- If parser/wrapper returns `status=context_needed` or `status=awaiting_context`, Team Lead must gather requested details and continue in the same Claude session before accepting recommendations.

## Per-Task Verification Gate (mandatory before review)
- After each task implementation, Team Lead must run Task Verification agent with:
  - spawn as generic `default` with prompt including task ID, acceptance criteria, and changed files
- Include the full Claude Invocation Context Pack in that prompt.
- If verification passes:
  - mark task as verified and continue.
- If verification fails:
  - create a new Beads ticket for fix/reimplementation with explicit DoD:
    - `bd create --type task --parent <epic-id> --title "Task verification fix: <task-id>" --description "<verification findings + required reimplementation + DoD>" --labels verification,reimplementation`
  - implement the fix ticket before any review phase begins.
  - rerun Task Verification on the original task and fix ticket.
- Do not proceed to automated review until all implemented tasks are verification-passed.

## Implementation Rules
- Keep paired support agents available:
  - **Senior Engineer** (`explorer`) for proactive code-level guidance and risk checks.
  - **Librarian** (`default`) for external docs/compatibility checks when implementation touches APIs/platform specifics.
- Execute coding work through Team Lead-managed subagents:
  - Backend Engineer owns backend tasks
  - Frontend Engineer owns frontend tasks
  - Security Engineer performs security-focused implementation/review tasks
- For big-feature worktree-isolated mode:
  - keep PRD work streams isolated by worktree execution boundaries
  - follow Ralph-native worktree lifecycle assumptions for parallel execution and merge sequencing
  - treat external worktree managers as optional helpers, not execution source of truth
- For big-feature queue execution:
  - respect async enqueue worker cap (`worker_cap=2`) when dispatching parallel PRD streams
  - do not bypass queue states manually to start blocked PRDs
- Before task selection or any other `bd` command in this phase, run:
  - `<pm-helper> beads preflight --phase implementation`
- Execute tasks from ready queue first:
  - `bd ready --parent <epic-id> --pretty`
- Claim/start work:
  - `bd update <task-id> --claim`
- Keep changes scoped to active tasks.
- Log meaningful status notes:
  - `bd comments add <task-id> "<progress/update>"`
- Close completed tasks:
  - `bd close <task-id>`

## Automatic Triple-Agent Post-Implementation Review
After implementation tasks are complete, automatically run all three reviewers in parallel:

1. **AGENTS Compliance Reviewer**
   - Load prompt from `references/agents-compliance.md`.
   - Check implementation against repo `AGENTS.md` rules and workflow constraints.
   - Return violations, file references, severity, and required fix.

2. **Jazz**
   - Load prompt from `references/jazz.md`.
   - Persona: grumpy, nitpicky old fart.
   - Behavior: doubt assumptions, challenge weak logic, call out edge cases and missing rigor.
   - Runner: use active execution-mode routing from `model-routing.yaml`:
     - `main-runtime-only`: run on the detected outer runtime.
     - `dynamic-cross-runtime` with Codex outer runtime: spawn as generic `default` with role-labeled prompt, then invoke via `claude-code` MCP.
     - `dynamic-cross-runtime` with Claude outer runtime: invoke via `codex-worker` MCP in the Claude runtime.
   - Return concrete defects and demanded fixes.

3. **Codex Reviewer**
   - Load prompt from `references/codex-reviewer.md`.
   - Model: Codex-native config-selected `model` and `model_reasoning_effort`.
   - Behavior: 4-layer sequential review (architecture -> syntax -> composition -> logic).
   - Runner: spawn as generic `default` with role-labeled prompt (`[Role: Codex Reviewer]`) per Codex Reviewer Contract.
   - Return findings grouped by layer with Finding ID, Layer, Severity, File path, Critique, and Required fix.
   - Availability rule: if native spawn fails, block review phase and report exact reason.

Preferred orchestration calls:
- Spawn compliance reviewer as generic `default` with role-labeled context (`[Role: AGENTS Compliance Reviewer]`).
- Spawn Jazz as generic `default` with role-labeled context (`[Role: Jazz Reviewer]`), then invoke via `claude-code` MCP.
- Spawn Codex Reviewer as generic `default` with role-labeled context (`[Role: Codex Reviewer]`) and include changed files, feature summary, PRD constraints, and task DoD.
- Team Lead must collect all three review outputs before creating iteration tasks.

## Review Output Handling (mandatory)
Team Lead is the explicit owner of review-fix orchestration.
For every actionable review finding, Team Lead must:
- Add comment on mapped task:
  - `bd comments add <task-id> "<reviewer>: <finding>"`
- Create iteration task when code changes are required:
  - `bd create --type task --parent <epic-id> --title "Review iteration: <short title>" --description "<fix + DoD>" --labels review,iteration`
- Set dependencies so unresolved findings block completion:
  - `bd dep <blocking-task-id> --blocks <blocked-task-id>`

## Review Iteration Loop
- Team Lead must orchestrate execution of all review iteration tasks through backend/frontend/security subagents.
- Team Lead must track these tasks as a dedicated review-fix workstream on Beads until all are done.
- Re-run targeted validation for changed areas.
- Team Lead closes iteration tasks only when their DoD is met.

## Documentation Sync Gate (mandatory when behavior/logic changes)
- Trigger this gate whenever implementation adds new logic or changes existing logic/behavior, including API contracts, UX flows, feature flags/configs, or operational behavior.
- Team Lead must create a dedicated Beads task for documentation sync:
  - `bd create --type task --parent <epic-id> --title "Documentation sync: <scope>" --description "<affected behavior + docs to update + DoD>" --labels docs,documentation`
- Team Lead must spawn Librarian as generic `default` with role-labeled context (`[Role: Librarian Documentation Sync]`) to:
  - audit impacted project documentation against the implemented behavior
  - update outdated docs and add missing docs where needed
  - report changed files and any remaining documentation gaps
- Documentation sync task DoD:
  - impacted docs are updated and consistent with shipped behavior
  - or a justified `no doc changes required` decision is recorded in task comments with evidence
- Do not proceed to Manual QA or final handoff while required documentation-sync tasks are open.

## Manual QA Smoke Tests (mandatory after automated reviews)
- After automated reviews and review-iteration fixes, run Manual QA smoke execution:
  - load prompt from `references/manual-qa-smoke.md`
  - execute the approved PRD smoke-test plan for happy, unhappy, and regression coverage
  - run browser-based smoke checks when required by the test plan
- Preferred orchestration call:
  - spawn Manual QA agent as generic `default` with role-labeled context (`[Role: Manual QA Smoke Agent]`) and wait for completion before final handoff
- If smoke tests fail:
  - create/fill beads follow-up tasks with explicit DoD
  - implement fixes
  - rerun Manual QA smoke tests
- Continue until smoke tests pass or only user-accepted risks remain.

## Final Gate
- Move to `Current phase: AWAITING FINAL REVIEW`.
- Present:
  - implementation summary
  - queue reconciliation summary (`discovered`, `approved`, `queued`, `queue_failed`) when big-feature route is used
  - reviewer findings summary
  - review-iteration changes completed
  - Manual QA smoke-test results
- Ask user to review results and provide requested fixes directly in the conversation.
- If user requests fixes:
  - pass user feedback to Team Lead
  - Team Lead creates Beads review-fix tickets and orchestrates implementation using the same regular flow (subagents + verification + close on DoD)
  - return to `AWAITING FINAL REVIEW` after fixes are completed
- If user approves without additional fixes, finish.

## Output Requirements (every run)
Always include:
1. `Current phase: <...>`
2. `Epic ID`
3. `Team Lead status` (not started/running/blocked/completed)
4. `Subagent status` (backend/frontend/security)
5. `Active/ready tasks`
6. `Reviewer status` (not started/running/completed)
7. `Iteration task status`
8. `Manual QA smoke status` (not started/running/passed/failed)
9. `Human review fix status` (none/pending/in-progress/completed)
10. `What I need from you next`
11. `Queue reconciliation` (required for big-feature route; include per-PRD state and blocked/failed reasons)
12. `Phase Error Summary` (`none` or issue list with status)

Issue reporting rules:
- Report step issues explicitly when they occur (severity, impact, next action).
- Non-critical issues do not stop implementation/review/QA flow.
- Critical blockers must include exact reason and remediation.

## Invocation
- Trigger strongly on `$pm-implement ...`.
- Also trigger as automatic handoff from `$pm-beads-plan` after second approval.
