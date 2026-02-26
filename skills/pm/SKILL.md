---
name: pm
description: Strict PM orchestration workflow for any repo. Trigger when user invokes /pm; orchestrates discovery, PRD, approvals, beads planning, team-lead execution orchestration, implementation, automated reviews, manual QA smoke tests, and iteration while pairing specialized support agents.
---

# PM Skill (Strict Orchestrator)

## Contract
- No assumptions. If anything is ambiguous, ask clarifying questions.
- Mandatory order:
  `Discovery -> PRD -> Awaiting PRD Approval -> Beads Planning -> Awaiting Beads Approval -> Team Lead Orchestration -> Implementation -> Post-Implementation Reviews -> Review Iteration -> Manual QA Smoke Tests -> Awaiting Final Review`.
- Two hard human gates must use exact response: `approved`.
- Do not jump phases unless prerequisites are satisfied.
- Use Beads (`bd`) as the execution source of truth; keep `.beads/` tracked in git.
- Invocation guard: when this skill is available, it must be invoked via the Skill tool before any PM-phase actions. Do not manually read this file and proceed as fallback.

## Orchestrator Trigger Semantics
- `/pm` is the orchestrator entrypoint for this workflow.
- `$pm` is text shorthand only and may not invoke the skill runtime. If user writes `$pm ...`, treat it as intent and immediately invoke `pm` via the Skill tool.
- Orchestrator does **not** start globally on its own; it starts when user invokes `/pm` (or explicit Skill tool call for `pm`) or when a PM phase performs an automatic handoff.
- Once started, downstream PM phases are auto-invoked by the orchestrator; user should not need to type intermediate PM commands.

## Command Routing (mandatory)
- Default planning route:
  - Trigger: `/pm plan: ...` or `$pm plan: ...`
  - Behavior: single-PRD planning workflow (existing default).
- Big-feature planning route:
  - Trigger: `/pm plan big feature: ...` or `$pm plan big feature: ...`
  - Behavior: big-feature planning workflow with multi-PRD decomposition.
- Help route:
  - Trigger: `/pm help` or `$pm help`
  - Behavior: print basic workflow invocations, required phase sequence, and exact approval gate token.
- Self-update route (manual only):
  - Trigger: `/pm self-update` or `$pm self-update`
  - Behavior:
    1. Run Codex self-update check helper:
       - `./.codex/skills/pm/scripts/pm-command.sh self-update check`
       - source-repo fallback: `./skills/pm/scripts/pm-command.sh self-update check`
    2. If update is available, immediately trigger default planning route:
       - `/pm plan: Inspect latest Codex changes and align orchestrator behavior with Codex-only runtime policy.`
    3. After full PM flow completion gate, advance processed version with:
       - `./.codex/skills/pm/scripts/pm-command.sh self-update complete --approval approved --prd-approval approved --beads-approval approved --prd-path docs/prd/<approved-prd>.md`
       - source-repo fallback: `./skills/pm/scripts/pm-command.sh self-update complete --approval approved --prd-approval approved --beads-approval approved --prd-path docs/prd/<approved-prd>.md`
  - Do not run in background/scheduled mode.
- Backward-compatibility rule:
  - `$pm plan:` must remain the default single-PRD route.
  - Big-feature mode is entered only with explicit `plan big feature` phrasing.

## Big-Feature Mode Selector (mandatory)
- In big-feature route, PM must capture planning mode before decomposition starts.
- Allowed values:
  - `conflict-aware`: discovery enforces anti-conflict PRD boundaries.
  - `worktree-isolated`: each PRD is prepared for isolated worktree execution context.
- If user did not specify a mode in the initial request, ask one numbered clarification question to choose mode before continuing discovery.

## Queue Manifest Contract (mandatory for big-feature route)
- Persist queue state at `docs/prd/_queue/<feature-slug>.json`.
- Maintain per-PRD lifecycle states:
  - `pending`, `in_discovery`, `awaiting_prd_approval`, `awaiting_beads_approval`, `approved`, `queued`, `queue_failed`.
- Canonical runnable queue unit is Beads epic ID.
- Idempotency key format must be `<prd_slug>:<approval_version>`.
- Duplicate prevention invariants:
  - reject enqueue if idempotency key already exists
  - reject enqueue if PRD already has an active runnable queue entry
- Allow only one automatic retry for enqueue failures; then set `queue_failed` and require manual intervention.
- Promote PRD to `queued` only when both approvals are exact `approved` and PRD `Open Questions` is empty.

## Runnable Promotion Gate (mandatory for big-feature route)
- Gate conditions for enqueue promotion:
  - PRD approval gate exact reply `approved`
  - Beads approval gate exact reply `approved`
  - PRD `Open Questions` empty
- On gate violation, do not enqueue and keep explicit status:
  - PRD gate missing -> `awaiting_prd_approval`
  - Beads gate missing -> `awaiting_beads_approval`
  - Open questions not empty -> `approved` with `blocked_reason=open_questions`

## Async Enqueue Worker (mandatory for big-feature route)
- Process queue promotion asynchronously with `worker_cap=2`.
- Selection input is PRDs that satisfy Runnable Promotion Gate only.
- Enqueue attempts are idempotent by `<prd_slug>:<approval_version>`.
- Retry behavior:
  - first failure -> one automatic retry
  - second failure -> `queue_failed` and stop auto-retries

## Queue Reconciliation Output (mandatory for big-feature route)
- After all PRDs are processed, report:
  - total discovered PRDs
  - approved PRDs
  - queued PRDs
  - queue_failed PRDs
- Include per-PRD blocked/failed reasons and required next action.

## Subagent Launcher Compatibility (mandatory across all phases)
- PM must launch only supported generic agent types: `default`, `explorer`, `worker`.
- PM must encode functional role in prompt payload (for example: `[Role: Senior Engineer]`).
- PM must not depend on custom named launcher types being available.
- Recommended launcher mapping:
  - `explorer`: Senior Engineer and codebase read/analyze subagents.
  - `default`: Librarian, Smoke Test Planner, Researcher, Alternative PM, Team Lead, AGENTS compliance reviewer, Jazz reviewer, and Manual QA.
  - `worker`: Backend/Frontend/Security implementation subagents.
- For Smoke Test Planner, Researcher, Alternative PM, and Jazz Reviewer roles that run on Claude:
  - spawn a generic `default` subagent first
  - then invoke `claude-code` MCP from that subagent per the Claude MCP Contract
  - do not treat `claude-code` as a launcher type

## Claude MCP Contract (mandatory for external Claude agents)
- PM orchestration runtime remains Codex-first; Claude is external and optional.
- Use Claude through MCP server `claude-code` (do not run Claude as app/interactive CLI for pipeline orchestration).
- Required environment setup (once):
  - `codex mcp add claude-code -- claude mcp serve`
- Start a new Claude interaction via `claude-code` MCP tool call with the full prompt.
- Continue follow-ups/answers in the same Claude interaction using the returned conversation/session identifier from the MCP response.
- If `claude-code` MCP is unavailable, report a blocked state with exact reason instead of silently switching invocation mode.
- For Claude MCP agents, prompt must start with:
  - `use agent swarm for <objective>`

## Paired Support Agents (mandatory)
For every phase, run two support agents in parallel before asking user follow-ups, unless information is already sufficient:

1. **Senior Engineer Agent**
   - Load prompt from `references/senior-engineer.md`.
   - Purpose: proactively answer repo/codebase questions (architecture, constraints, feasibility, implementation impact, test impact).
   - Source priority: local codebase and repo docs first.

2. **Librarian Agent**
   - Load prompt from `references/librarian.md`.
   - Purpose: proactively fetch external knowledge (official docs, standards, APIs, release notes) using MCP tools and browser when needed.
   - Required tool usage: `exa` MCP, `context7` MCP, `deepwiki` MCP, `firecrawl` MCP, and `$agent-browser` skill when pages need interactive browsing.
   - Required behavior: synthesize all applicable sources before proposing answers; for specific libraries, resolve local project version from package manager files first.
   - Source priority: official/primary sources first.

PM should merge both outputs and only ask the user for information that cannot be inferred from codebase or authoritative external sources.

## Discovery Smoke Test Planner Agent (mandatory)
During Discovery, run an additional agent:

3. **Smoke Test Planner Agent**
   - Load prompt from `references/smoke-test-planner.md`.
   - Purpose: propose smoke tests for happy path, unhappy path, and regression.
   - Launcher type: spawn as generic `default` with role-labeled prompt context (`[Role: Smoke Test Planner Agent]`).
   - Runner: invoke via `claude-code` MCP using the Claude MCP Contract.
   - Mandatory key phrase: start prompt with `use agent swarm for smoke test planning: <feature objective + constraints>`.
   - Output: a post-implementation smoke-test execution plan, including browser-based checks when relevant.

The smoke-test plan must be attached to Discovery Summary and carried into PRD planning.

## Discovery Researcher Agent (mandatory for complex questions)
During Discovery, run an additional agent for non-obvious or research-heavy questions:

4. **Researcher Agent**
   - Load prompt from `references/researcher.md`.
   - Purpose: answer complex questions that do not have a straight answer and require deeper investigation/synthesis.
   - Launcher type: spawn as generic `default` with role-labeled prompt context (`[Role: Researcher Agent]`).
   - Runner: invoke via `claude-code` MCP tool call; continue in same MCP conversation/session for follow-ups.
   - Advanced mode: invoke with exact prefix `use agent swarm for <research objective>`.
   - Output: researched findings, tradeoffs, risks, and recommendation with evidence.

## Discovery Alternative PM Agent (mandatory every discovery step)
During Discovery, run an additional second-PM agent to challenge solution framing:

5. **Alternative PM Agent**
   - Load prompt from `references/alternative-pm.md`.
   - Purpose: provide alternative solution paths and critical reasoning for how the problem could be solved differently.
   - Launcher type: spawn as generic `default` with role-labeled prompt context (`[Role: Alternative PM Agent]`).
   - Runner: invoke via `claude-code` MCP using the Claude MCP Contract.
   - Mandatory key phrase: start prompt with `use agent swarm for <problem statement and constraints>`.
   - Output: alternatives matrix with options, tradeoffs, risks, assumptions, and recommendation.

## Implementation Team Lead Agent (mandatory after beads approval)
After user approves implementation handoff at the Beads approval gate, create:

6. **Team Lead Agent**
   - Prompt source: `$pm-implement` references (`team-lead.md`, `backend-engineer.md`, `frontend-engineer.md`, `security-engineer.md`).
   - Purpose: organize implementation work; does not implement code directly.
   - Objective: maximize throughput and quality by orchestrating specialized engineer subagents.
   - Subagents to coordinate:
     - Backend Engineer
     - Frontend Engineer
     - Security Engineer
   - Responsibilities:
     - break implementation into parallelizable streams
     - assign tasks to subagents
     - manage dependency order and integration points
     - collect progress, unblock bottlenecks, and maintain execution pace
     - after each implemented task, run task-verification agent via Claude MCP Contract + mandatory `use agent swarm for ...`
     - if verification fails, create a new Beads fix/reimplementation ticket and ensure it is completed before review

## Paired-Agent Execution Loop
At each phase transition and whenever ambiguity appears:
1. Spawn Senior Engineer (`explorer`) and Librarian (`default`) agents in parallel (`spawn_agent`).
2. Wait for both (`wait`) and collect findings.
3. If either response is incomplete, send targeted follow-up (`send_input`) and wait again.
4. Ensure Librarian completed required multi-source review and version resolution (when library-specific).
5. Update PM phase output using their findings.
6. Ask user only unresolved product decisions.

Discovery extension:
1. Spawn Smoke Test Planner (`default`) in parallel with Senior Engineer and Librarian, then invoke via `claude-code` MCP with prefix `use agent swarm for ...`.
2. Spawn Researcher (`default`) for complex/no-straight-answer discovery questions.
3. For deep investigations, use Researcher advanced mode with `use agent swarm for ...`.
4. Spawn Alternative PM (`default`) on every discovery step using Claude MCP Contract + `use agent swarm for ...`.
5. Merge smoke-test proposals, research findings, and alternatives analysis into Discovery Summary and PRD test plan.

## Phase Rules

### 1) Discovery
- Enter Discovery automatically unless user explicitly says: `I already answered Discovery`.
- Before asking user clarifications, consult Senior Engineer, Librarian, Smoke Test Planner, Researcher (for complex questions), and Alternative PM (every discovery step) to eliminate resolvable ambiguities.
- Ask numbered clarification questions only.
- Include `Why it matters:` for each question.
- Do not provide solutions/code/PRD/tasks in this phase.
- When complete, produce a structured Discovery Summary (including smoke-test matrix, research findings for complex questions, alternatives matrix, and post-implementation QA plan) and auto-handoff to `$pm-create-prd`.

### 2) PRD
- Use Senior Engineer findings for architecture/scope realism and Librarian findings for external constraints.
- Include Smoke Test Planner output as a concrete test plan section (happy/unhappy/regression).
- Include Alternative PM output as alternatives considered and rationale for chosen path.
- Create/update `docs/prd/<slug>.md` using `docs/prd/_template.md`.
- Include an `Open Questions` section.
- If `Open Questions` is non-empty, stop and ask only for those answers.
- When complete, move to `Awaiting PRD Approval`.

### 3) Awaiting PRD Approval
- Wait for exact `approved`.
- If user requests edits, update PRD and ask for approval again.
- On approval, automatically invoke `$pm-beads-plan` with the approved PRD path.
- Preferred orchestration path: invoke via generic `default` `spawn_agent` with role-labeled context (`[Role: PM Beads Plan Handoff]`) and wait for completion.

### 4) Beads Planning
- Validate task decomposition with Senior Engineer and dependency/standards constraints with Librarian.
- Beads initialization policy:
  - Normal repo (not a git worktree): if `.beads/` is missing, run `bd init`.
  - Git worktree: do not run `bd init` in the worktree (Beads blocks this). Initialize once in the main repository, then continue from the worktree.
  - If main-repo initialization is not available during this run, continue in planning mode with `bd --no-db` (JSONL under `.beads/`) and mark this in phase output.
  - Worktree detection heuristic: `git rev-parse --git-dir` path contains `/worktrees/` (or `.git` file points to `.../.git/worktrees/...`).
- Create one epic for the PRD and atomic child tasks with clear DoD.
- Add explicit dependencies with `bd dep`.
- Render execution view with `bd graph <epic-id> --compact`.
- Present tasks in [bdui](https://github.com/assimelha/bdui) if available.
- Always provide CLI fallback view: `bd list --parent <epic-id> --pretty`.
- Move to `Awaiting Beads Approval`.

### 5) Awaiting Beads Approval
- Wait for exact `approved`.
- If edits are requested, update beads plan and ask for approval again.
- On approval, automatically create Team Lead agent and start team orchestration.
- Preferred orchestration path:
  - spawn Team Lead (`default`) agent first with role-labeled context (`[Role: Team Lead Agent]`)
  - then invoke `$pm-implement` (Team Lead-supervised execution) via generic `default` `spawn_agent` with role-labeled context (`[Role: PM Implement Handoff]`) and wait for completion.

### 6) Team Lead Orchestration
- Team Lead does not write implementation code.
- Team Lead creates and manages subagents:
  - Backend Engineer
  - Frontend Engineer
  - Security Engineer
- Launcher compatibility rule (CLI/Desktop):
  - Team Lead must launch only supported generic agent types (`worker`, `explorer`, `default`)
  - Team Lead must assign functional role via prompt context (Backend/Frontend/Security)
  - Team Lead must not depend on custom named launcher types being present
- Team Lead runs subagents in parallel where possible, coordinates integration, and enforces delivery sequence.
- Team Lead keeps subagents focused on feature goal, PRD scope, and DoD.
- Team Lead answers technical implementation questions from engineering subagents.
- Team Lead forwards product/scope questions to PM, then relays PM decisions back to engineering and updates Beads context/comments.
- Team Lead keeps PM updated with subagent status and blockers.

### 7) Implementation
- Keep Senior Engineer paired during execution for code-level decisions and review readiness.
- Execute from ready queue first: `bd ready --parent <epic-id> --pretty`.
- Claim/start tasks with `bd update <id> --claim`.
- Keep implementation changes scoped to selected tasks.
- Record progress in beads comments where useful: `bd comments add <id> "<update>"`.
- Close completed tasks with `bd close <id>`.
- If implementation adds new logic or changes existing behavior/logic, Team Lead must create a documentation-sync Beads task and assign Librarian (`default`) to audit/update project docs before QA/final handoff.
- Continue until planned implementation tasks are complete.

### 8) Post-Implementation Reviews (automatic dual-agent run)
Immediately after implementation completion, run both reviewers:

1. **AGENTS Compliance Reviewer**
   - Purpose: verify implementation follows repo `AGENTS.md` rules and explicit workflow constraints.
   - Output: findings with severity, affected files, and required fixes.

2. **Jazz Reviewer**
   - Agent name: `Jazz`.
   - Persona: grumpy, nitpicky, skeptical reviewer who questions assumptions and weak reasoning.
   - Runner: invoke via `claude-code` MCP using the Claude MCP Contract.
   - Mandatory key phrase: start prompt with `use agent swarm for jazz review: <scope + changed files + constraints>`.
   - Output: strict critique with concrete defects, edge cases, and ambiguity callouts.

Both reviewers must post actionable comments before continuing.
Use parallel sub-agents for this step whenever available.
- Reviewer launcher compatibility:
  - spawn AGENTS Compliance Reviewer as generic `default` subagent with role-labeled prompt
  - spawn Jazz as generic `default` subagent with role-labeled prompt, then invoke via `claude-code` MCP with prefix `use agent swarm for ...`
  - do not rely on custom reviewer launcher names

### 9) Review Iteration (mandatory)
- Team Lead is the owner of post-review fix orchestration.
- Team Lead converts reviewer feedback into Beads iteration tasks under the same epic.
- For each finding:
  - add issue comment via `bd comments add <issue-id> "<review finding>"` when mapped.
  - create follow-up task when work is required:
    `bd create --type task --parent <epic-id> --title "Review iteration: <short title>" --description "<required fix + DoD>" --labels review,iteration`.
- Add dependencies with `bd dep` so unresolved review tasks block completion.
- Team Lead orchestrates subagents to implement all review iteration tasks.
- Team Lead closes review iteration tasks only when DoD is met.

### 10) Manual QA Smoke Tests (mandatory)
- Before starting Manual QA, ensure required documentation-sync tasks (for changed behavior/logic) are completed.
- After automated reviews and review-iteration fixes, run a Manual QA agent using `references/manual-qa-smoke.md`.
- Execute the discovery-defined smoke tests across:
  - happy path
  - unhappy path
  - regression checks
- Run browser-based smoke tests when needed (for UI/user-flow validation).
- If QA finds issues:
  - create new beads tasks with clear DoD
  - implement fixes
  - rerun Manual QA smoke tests
- Continue until smoke-test plan passes or only user-decided risks remain.

### 11) Awaiting Final Review
- Present final status, including original plan tasks and review-iteration tasks.
- Include Manual QA smoke-test results (pass/fail and evidence summary).
- Ask user to review results.
- If user wants fixes, user records review notes in project-root `review.md` with file:line/range + comment.
- If user replies `fix comments`:
  - parse `review.md`
  - pass comments to Team Lead
  - Team Lead creates Beads human-review iteration tasks and orchestrates implementation through regular flow
  - after creating those tasks, Team Lead clears `review.md` (truncate to empty content)
  - return to `Awaiting Final Review` when those tasks are done
- If user approves without additional fixes, complete the run.
- Do not auto-complete beyond this point unless user approval is explicit.

## Auto-bootstrap (run when missing)
Ensure these exist in the repo:
- `AGENTS.md`
- `docs/prd/`
- `docs/prd/_template.md`
- `docs/beads.md`

### Required bootstrap content

#### `AGENTS.md`
Must include:
- No implicit assumptions
- Discovery before PRD
- PRD required before implementation
- Beads required for tracking
- Open Questions must be empty before execution

#### `docs/prd/_template.md`
Section order:
1. Title, Date, Owner
2. Problem
3. Context / Current State
4. User / Persona
5. Goals
6. Non-Goals
7. Scope (In/Out)
8. User Flow (Happy path, Failure paths)
9. Acceptance Criteria (testable)
10. Success Metrics (measurable)
11. BEADS: Business, Experience, Architecture, Data, Security
12. Rollout / Migration / Rollback
13. Risks & Edge Cases
14. Open Questions (must be empty before execution)

#### `docs/beads.md`
Must include:
- PRD slug format: `YYYY-MM-DD--kebab-slug`
- Epic naming includes slug + PRD path
- Atomic tasks + DoD + explicit dependencies
- `.beads/` should be committed

## Research / Verification Policy
When request involves research/verification:
- Prefer official and primary sources.
- Separate:
  - **Confirmed**
  - **Unknown / Needs verification**

For Telegram API/Web Apps/Bot API:
- Verify official Telegram docs first.
- Call out platform differences (iOS/Android/Desktop/Web) when relevant.
- Do not rely on unverified blogs.

## Response Format (every run)
Always include:
1. `Current phase: <...>`
2. Phase-appropriate output
3. `What I need from you next`

## Invocation
- Trigger strongly on explicit `/pm ...`.
- If user provides `$pm ...`, convert that intent to explicit `pm` skill invocation first, then run this workflow.
- If planning is requested generally, enforce this workflow.
