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
2. Beads task graph is approved.
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

## Claude MCP Contract (mandatory for external Claude agents)
- **Primary path (Claude Code runtime):** When running inside Claude Code, use the **native Task tool** to spawn Claude subagents — no MCP bridge needed. Use `subagent_type: "default"` for most roles or `subagent_type: "Explore"` for codebase analysis roles.
- **Fallback path (non-Claude-Code runtimes):** Use Claude through MCP server `claude-code` when the outer runtime is not Claude Code.
  - Required environment setup (once):
    - `claude mcp add claude-code -- claude mcp serve`
  - Start a new Claude interaction via `claude-code` MCP tool call with the full prompt.
  - Continue follow-ups/answers in the same Claude interaction using the returned conversation/session identifier from the MCP response.
  - If `claude-code` MCP is unavailable, report a blocked state with exact reason.

## Codex MCP Contract (mandatory for Codex reviewer)
- Codex reviewer runs gpt-5.3-codex at xhigh reasoning effort via Codex CLI MCP server.
- **Setup (once):**
  - `claude mcp add codex-reviewer -- codex mcp-server`
  - Configure model and reasoning effort in project `.codex/config.toml` or global `~/.codex/config.toml`:
    ```toml
    model = "gpt-5.3-codex"
    model_reasoning_effort = "xhigh"
    ```
- **MCP tool names** exposed by `codex mcp-server`:
  - `codex` — start a new review conversation (first layer pass)
  - `codex-reply` — continue an existing review conversation (subsequent layer passes)
- **Invocation:** Use `codex-reviewer` MCP `codex` tool to start the review, then `codex-reply` for each subsequent layer pass. Do not spawn Codex via Task tool or Bash.
- **Verify registration:** `claude mcp list | grep codex-reviewer`
- **Timeout:** 10 minutes total for all 4 layer passes. If any individual pass exceeds 3 minutes, skip remaining passes and report partial findings.
- **Graceful degradation:** If `codex-reviewer` MCP is unavailable (not configured, CLI not installed, auth failure, timeout), log a warning with the exact reason and continue the review phase with existing reviewers (Jazz + AGENTS Compliance). Do not block the pipeline.
- **Cascading failure policy:** If 2 or more reviewers fail (any combination of Jazz, AGENTS Compliance, Codex), the review phase must block and report the failure to PM rather than proceeding with zero or minimal review coverage. A single reviewer failure triggers graceful degradation; multiple reviewer failures trigger a hard block.

## Subagent Launcher Compatibility (mandatory across implementation phases)
- Spawn only supported Claude Code Task tool `subagent_type` values: `default`, `Explore`, `Plan`.
- Encode role in prompt payload for every spawned subagent (for example: `[Role: Backend Engineer]`).
- Do not rely on custom named subagent launchers.
- Recommended launcher mapping:
  - `default`: Backend Engineer, Frontend Engineer, Security Engineer (implementation via Task tool), Team Lead, Task Verification, AGENTS Compliance Reviewer, Jazz reviewer, Manual QA Smoke agent.
  - `Explore`: Senior Engineer read/analyze checks and codebase triage.
  - `codex-reviewer` MCP: Codex reviewer (gpt-5.3-codex, 4-layer post-implementation review).
- Droid worker roles: spawn via `droid-worker` MCP tool call (not via Task tool).
- Codex reviewer: spawn via `codex-reviewer` MCP tool call (not via Task tool). If unavailable, log warning and continue with Jazz + AGENTS Compliance.
- For Task Verification and Jazz reviewer workflows:
  - Primary: spawn via native Task tool with `subagent_type: "default"` and role-labeled prompt
  - Fallback: invoke `claude-code` MCP per Claude MCP Contract
  - do not treat `claude-code` as a launcher type

## Team Lead Orchestration (mandatory before coding)
- Create Team Lead agent from `references/team-lead.md`.
- Team Lead must **not** implement code directly.
- Team Lead organizes and coordinates these engineer subagents:
  - Backend Engineer (`references/backend-engineer.md`)
  - Frontend Engineer (`references/frontend-engineer.md`)
  - Security Engineer (`references/security-engineer.md`)
- Launcher compatibility rule (CLI/Desktop):
  - do not assume custom named subagent launchers exist
  - spawn supported Task tool `subagent_type` values only (`default`, `Explore`)
  - assign role via prompt payload (for example: `[Role: Backend Engineer] ...`)
  - use `Explore` for read/analyze tasks and `default` for implementation tasks
- Team Lead also runs a Task Verification agent after each implemented task:
  - `references/task-verification.md`
  - primary: spawn via native Task tool with `subagent_type: "default"` and role-labeled prompt
  - fallback: invoke via `claude-code` MCP using the Claude MCP Contract
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
  - handle engineer onboarding questions and 4-layer checklist reviews
  - route product/scope questions to PM, then relay PM decisions back to engineering and update tasks/comments accordingly
  - when implementation introduces new behavior/logic or modifies existing behavior/logic, create and run a documentation-sync task owned by Librarian before final handoff
- Preferred orchestration calls:
  - spawn Team Lead first as generic `default` with role-labeled context (`[Role: Team Lead Agent]`)
  - Team Lead spawns engineer subagents using generic launcher types and role-labeled prompts
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

## Per-Task Verification Gate (mandatory before review)
- After each task implementation, Team Lead must run Task Verification agent with:
  - primary: spawn via native Task tool with `subagent_type: "default"` and prompt including task ID, acceptance criteria, and changed files
  - fallback: invoke via `claude-code` MCP with the same prompt
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
  - **Senior Engineer** (`Explore`) for proactive code-level guidance and risk checks.
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
   - Runner: spawn via native Task tool with `subagent_type: "default"` and role-labeled prompt (primary); fallback is `claude-code` MCP.
   - Return concrete defects and demanded fixes.

3. **Codex Reviewer**
   - Load prompt from `references/codex-reviewer.md`.
   - Model: gpt-5.3-codex at xhigh reasoning effort via Codex CLI MCP server.
   - Behavior: 4-layer sequential review (architecture → syntax → composition → logic). Later passes may reference earlier findings.
   - Runner: spawn via `codex-reviewer` MCP tool call per Codex MCP Contract.
   - Return findings grouped by layer with Finding ID, Layer, Severity, File path, Critique, and Required fix.
   - Graceful degradation: if `codex-reviewer` MCP is unavailable, log a warning with the exact reason and continue with Jazz + AGENTS Compliance only. Do not block the review phase.

Run all three reviewers in parallel when possible.

Preferred orchestration calls:
- Spawn compliance reviewer via Task tool with `subagent_type: "default"` and role-labeled context (`[Role: AGENTS Compliance Reviewer]`).
- Spawn Jazz via Task tool with `subagent_type: "default"` and role-labeled context (`[Role: Jazz Reviewer]`).
- Spawn Codex Reviewer via `codex-reviewer` MCP tool call with changed files, feature summary, PRD constraints, and task DoD.
- Team Lead must collect all three review outputs (or two if Codex is unavailable) and wait for all to complete before creating iteration tasks.

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
  - execute discovery/PRD smoke tests for happy, unhappy, and regression coverage
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

## Invocation
- Trigger strongly on `$pm-implement ...`.
- Also trigger as automatic handoff from `$pm-beads-plan` after second approval.
