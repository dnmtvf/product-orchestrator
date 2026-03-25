# PRD

## 1. Title, Date, Owner
- Title: Claude MCP Launcher Health And Contract Repair
- Date: 2026-03-25
- Owner: PM Orchestrator

## 2. Problem
The PM orchestrator currently treats `claude-code` as usable in `dynamic-cross-runtime` when three checks pass:
- `claude-code` is registered in `codex mcp list`
- the configured `claude` command is executable in the Codex runtime
- the helper's synthetic Claude wrapper/session probe returns a valid status

Live runtime evidence shows that those checks are insufficient. In this workspace:
- `claude mcp serve` initializes successfully
- `tools/list` succeeds and returns `Agent` and non-agent tools such as `Bash`
- non-agent `tools/call` succeeds
- every tested `Agent` launcher path fails with `Agent type '<name>' not found`

This creates a false-green state where:
- `plan gate --mode dynamic-cross-runtime` reports `PLAN_ROUTE_READY`
- `self-check run --mode dynamic-cross-runtime` reports `SELF_CHECK_RESULT|status=clean`
- the first real Claude-routed delegated task still fails at runtime

That breaks the PM contract. Dynamic mode must not advertise Claude as healthy unless the real delegated launcher path is usable.

## 3. Context / Current State
- The current PM contract already says that launcher failures such as `Agent type 'general-purpose' not found` or `no supported agent type` must block the Claude path and return control to PM.
- The routing matrix already says Codex-outer `dynamic-cross-runtime` depends on `claude-code-mcp` for support roles such as `senior_engineer`, `librarian`, `smoke_test_planner`, `alternative_pm`, `researcher`, and `jazz_reviewer`.
- The helper currently validates Claude health via:
  - `claude_mcp_server_healthy()`
  - `claude_mcp_available()`
  - a synthetic wrapper/session response file passed into `run_claude_wrapper_evaluate()`
- The helper does not perform a live `tools/call` to the Claude `Agent` tool during `plan gate` or `self-check`.
- Live discovery evidence from this run:
  - `codex mcp get claude-code` shows `command: claude`, `args: mcp serve`
  - `claude --version` succeeds with `2.1.81 (Claude Code)`
  - direct stdio MCP probe to `claude mcp serve` succeeds on `initialize`
  - direct `tools/call` to `Bash` succeeds and returns the exact expected token
  - direct `tools/call` to `Agent` fails for:
    - implicit default
    - `general-purpose`
    - `Explore` / `explore`
    - `Plan` / `plan`
    - `default`
    - `inherit`
    - `Other` / `other`
  - the same repo/user environment exposes a user Claude agent at `~/.claude/agents/default.md`, but `claude mcp serve` still does not accept `default`
- `self-check run --mode dynamic-cross-runtime` currently reports `clean` in the same environment, proving the current self-check is a false positive for launcher usability.
- There is no project-local `.claude/agents/` directory in this repo today.

Selected framing from discovery:
1. The MCP transport is healthy.
2. The non-agent tool path is healthy.
3. The delegated Claude launcher path is unhealthy.
4. The orchestrator's current health contract is too weak because it does not verify the real launcher path.
5. The fix must harden health detection and make the expected Claude launcher contract explicit rather than relying on implicit built-ins.

## 4. User / Persona
- PM workflow maintainers.
- Engineers running `/pm plan` from Codex who expect dynamic routing to be trustworthy.
- Operators debugging Claude-routed orchestration failures.

## 5. Goals
- Make `dynamic-cross-runtime` pass only when the live Claude delegated launcher path is actually usable.
- Add a real launcher preflight to the PM helper and self-check, using the actual `claude-code` MCP `Agent` tool rather than a synthetic response-only probe.
- Make the expected Claude launcher contract explicit and configurable, instead of assuming implicit `general-purpose` support.
- Preserve `main-runtime-only` as a fully usable fallback while Claude is unhealthy.
- Produce deterministic artifacts and remediation when Claude launcher health fails.
- Add smoke coverage that proves the end-to-end delegated dummy-task path works before the repo reports Claude healthy.

## 6. Non-Goals
- Fixing upstream Claude Code behavior outside this repository if the root cause is entirely external.
- Replacing the PM public launcher contract with runtime-specific hidden behavior.
- Requiring browser/UI checks for this runtime-only workflow.
- Changing `main-runtime-only` semantics.
- Adding a direct non-MCP Claude CLI orchestration path for PM.

## 7. Scope (In/Out)
### In Scope
- Add a live Claude launcher health probe to the PM helper, reusable by:
  - `plan gate`
  - `self-check`
  - any future Claude-routed runtime preflight
- The live probe must:
  - initialize `claude mcp serve`
  - complete MCP lifecycle correctly
  - discover tools
  - call the `Agent` tool using the configured/expected launcher path
  - verify a deterministic dummy-task response
- Add repo-owned configuration for Claude launcher expectations, for example:
  - explicit preferred Claude subagent names or candidates
  - explicit failure messaging when no candidate works
- Update `self-check` so a false-green dynamic result is no longer possible when live launcher invocation fails.
- Update docs/contracts to reflect:
  - registration/executability is not enough
  - delegated launcher usability is a separate required health layer
  - dynamic routing must fail closed when launcher health is bad
- Add smoke tests and deterministic fixtures for:
  - healthy launcher path
  - unsupported launcher path
  - regression on non-agent tools

### Out of Scope
- Rewriting the entire PM orchestrator.
- Designing a new public PM role taxonomy.
- Adding project-specific UI around Claude health.
- Automatically creating or mutating user-global Claude agent files without explicit repo-owned contract and user approval.

## 8. User Flow
### Happy Path
1. User runs `/pm plan: ...`.
2. PM runs the execution-mode gate and selects `dynamic-cross-runtime`.
3. Before Discovery starts, the helper verifies:
   - `claude-code` registration
   - command executability
   - live delegated launcher usability through an actual `Agent` tool probe
4. The probe uses a deterministic dummy task and validates the exact expected response.
5. If the probe succeeds, the helper emits `PLAN_ROUTE_READY`.
6. Claude-routed support roles execute normally.
7. `self-check run --mode dynamic-cross-runtime` also passes only when that same launcher path is healthy.

### Failure Paths
1. `claude-code` is registered and executable, but the live `Agent` call returns `Agent type '<name>' not found` or equivalent.
2. PM blocks dynamic mode before Discovery, reports the launcher-specific failure, and keeps `main-runtime-only` available.
3. `self-check` records the same failure and does not report a clean result.

4. No configured Claude launcher candidate succeeds.
5. PM reports explicit remediation:
   - install/configure a valid Claude launcher contract for this environment, or
   - continue with `Main Runtime Only`

6. Non-agent tools still work while `Agent` remains broken.
7. PM does not misclassify that state as fully healthy Claude support.

## 9. Acceptance Criteria
1. `plan gate --mode dynamic-cross-runtime` fails closed when the live Claude `Agent` launcher path is unusable, even if registration and executability succeed.
2. `self-check run --mode dynamic-cross-runtime` fails or reports `issues_detected` when the live Claude `Agent` launcher path is unusable.
3. The helper no longer reports Claude session usability based only on a synthetic response file.
4. A reusable helper function exists for a live Claude launcher probe.
5. The live probe uses actual MCP stdio lifecycle and a real `tools/call` to `Agent`.
6. The live probe validates an exact deterministic dummy-task result, not a vague success string.
7. The repo exposes a documented configuration surface for the expected Claude launcher path or candidate launcher names.
8. If none of the configured launcher candidates work, the helper emits explicit reason/remediation and blocks dynamic mode.
9. `main-runtime-only` remains unaffected and continues to pass the gate without Claude.
10. Non-agent Claude MCP tools may continue to work, but they must not be treated as proof that dynamic Claude delegation is healthy.
11. Repo docs explicitly distinguish:
   - MCP transport health
   - command executability
   - delegated launcher health
12. Smoke-test guidance exists for happy path, unhappy path, and regression.
13. `Open Questions` remains empty before implementation handoff.

### Smoke Test Plan
#### Happy Path
- Run direct MCP probe:
  - `initialize`
  - `notifications/initialized`
  - `tools/list`
  - `tools/call` to `Agent` using the configured launcher path
- Verify the delegated dummy task returns the exact expected token from a probe file.
- Run `./skills/pm/scripts/pm-command.sh plan gate --route default --mode dynamic-cross-runtime` and verify `PLAN_ROUTE_READY`.
- Run `./skills/pm/scripts/pm-command.sh self-check run --mode dynamic-cross-runtime` and verify it reports healthy Claude only when the live launcher probe passes.

#### Unhappy Path
- Force an invalid launcher candidate and verify the helper blocks dynamic mode with a launcher-specific reason.
- Verify `self-check` does not report `clean` when the live launcher path fails.
- Verify unsupported-launcher responses such as `Agent type 'general-purpose' not found` are surfaced explicitly and never silently downgraded.

#### Regression
- Verify non-agent Claude MCP tools such as `Bash` still work.
- Verify `main-runtime-only` still reports `PLAN_ROUTE_READY` without Claude.
- Verify dynamic mode only becomes ready when live launcher health is confirmed.
- Verify helper output and artifact capture remain deterministic.

## 10. Success Metrics
- 0 false-green dynamic-mode passes when the live Claude launcher path is unusable.
- 100% of dynamic-mode readiness decisions include live launcher evidence.
- 100% of self-check runs classify launcher failure as unhealthy, not clean.
- 100% of happy-path delegated dummy-task probes return exact expected payloads before dynamic mode is considered healthy.
- 0 regressions in `main-runtime-only`.

## 11. BEADS
### Business
- Prevents wasted engineering time on PM plans that appear routable but fail on the first actual Claude delegation.

### Experience
- Operators get one clear answer about Claude readiness, with evidence tied to the real delegated path.

### Architecture
- Preserve the current PM contract:
  - generic PM launcher types on the outer runtime
  - Claude as an external MCP runtime
  - fail-closed dynamic routing
- Strengthen the Claude-health contract by requiring a live delegated launcher probe.
- Make the Claude launcher expectation explicit/configurable rather than implicit.

### Data
- Persist launcher probe artifacts, selected launcher candidate, exact expected token, exact returned token, and failure reason in self-check/diagnostic bundles.

### Security
- Keep human approval and PM gating intact.
- Avoid silent fallback from blocked Claude-dependent flows.
- Avoid treating partial transport success as full runtime trust.

## 12. Rollout / Migration / Rollback
- Rollout:
  - implement live launcher probe helper
  - wire it into dynamic-mode gate and self-check
  - add documented Claude launcher configuration
  - add smoke coverage and docs
- Migration:
  - preserve `main-runtime-only`
  - stop relying on synthetic-only Claude session health
  - stop assuming implicit `general-purpose` support
- Rollback:
  - revert the new live-probe path and configuration
  - keep `main-runtime-only` as the stable operating mode

## 13. Risks & Edge Cases
- Risk: the underlying Claude MCP runtime has an upstream defect that repo changes can only detect, not fully fix.
- Risk: explicit launcher configuration may vary by environment and require careful diagnostics.
- Risk: if the probe is too permissive, false greens remain; if too strict, dynamic mode may block unnecessarily.
- Risk: user-global Claude agent state and MCP-served agent state may diverge, as seen in this run.
- Edge case: non-agent tools succeed while `Agent` is broken; the helper must classify that as partially healthy transport but unhealthy delegated launcher.
- Edge case: multiple launcher candidates may exist; the helper must use a deterministic selection order and artifact output.

## 14. Open Questions
None.

## 15. Alternatives Considered
### Option A: Only harden diagnostics, keep current dynamic gate
- Pros:
  - smallest code change
  - easier rollout
- Cons:
  - dynamic mode can still advertise false readiness
  - does not solve the core contract violation
- Status: Rejected.

### Option B: Add live launcher probe and explicit launcher configuration
- Pros:
  - aligns health classification with the real delegated path
  - preserves dynamic mode when Claude is truly usable
  - fail-closed behavior remains deterministic
- Cons:
  - more helper complexity
  - may expose upstream Claude defects more often
- Status: Selected.

### Option C: Remove dynamic Claude routing entirely and rely on Main Runtime Only
- Pros:
  - simplest operational model
  - no Claude launcher ambiguity
- Cons:
  - abandons the intended dual-runtime architecture
  - loses Claude-routed support-role capacity
- Status: Rejected as default direction, acceptable fallback if no usable Claude launcher exists.
