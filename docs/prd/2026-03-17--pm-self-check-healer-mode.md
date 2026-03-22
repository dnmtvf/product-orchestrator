# PRD

## 1. Title, Date, Owner
- Title: PM Self-Check Healer Mode
- Date: 2026-03-17
- Owner: PM Orchestrator

## 2. Problem
The orchestrator has partial health primitives, but no end-to-end self-diagnostic mode. Today, failures around subagent spawning, controller handoff, response collection, Claude runtime usability, and cross-agent workflow handling surface as a mix of helper output, wrapper status lines, stderr, and telemetry, without one deterministic harness that can run the orchestrator against itself and turn failures into actionable repair work.

This leaves maintainers without a standard answer to questions such as:
- can the orchestrator still complete a controlled synthetic run
- where exactly did subagent lifecycle handling fail
- is Claude merely registered, or actually usable in the real runtime
- how should discovered orchestrator defects be routed back into the existing PM workflow without bypassing repo gates

## 3. Context / Current State
- The live control-plane helper currently exposes `help`, `lead-model`, `plan`, `claude-contract`, `claude-wrapper`, `telemetry`, and `self-update` only in [pm-command.sh](/Users/d/product-orchestrator/skills/pm/scripts/pm-command.sh).
- There is no existing `self-check` route or fixture catalog in the repository.
- The current PM contract is workflow-heavy and helper-light: execution policy is primarily defined in [SKILL.md](/Users/d/product-orchestrator/skills/pm/SKILL.md), [pm_workflow.md](/Users/d/product-orchestrator/instructions/pm_workflow.md), and [model-routing.yaml](/Users/d/product-orchestrator/skills/pm/agents/model-routing.yaml), while the helper enforces routing gates, Claude wrapper normalization, and telemetry.
- Claude health semantics already distinguish registration from usability:
  - `codex mcp list` / `claude mcp list` health
  - executable command resolution in the actual runtime
  - invocation-time wrapper/runtime failures such as unsupported launcher
- Existing structured failure/output primitives already include:
  - `PLAN_ROUTE_BLOCKED`
  - `PLAN_ROUTE_READY`
  - `CLAUDE_HANDSHAKE|status=context_needed`
  - `CLAUDE_WRAPPER_RESULT|status=runtime_error|error=unsupported_launcher`
- Existing telemetry can record command and step events in `pm_step_events`, but there is no current structured event model for subagent lifecycle transitions such as spawn requested, response timeout, controller failure, or healer remediation decisions.
- Repo policy must remain intact:
  - Discovery before PRD
  - PRD approval before implementation
  - Beads before execution
  - empty `Open Questions` before execution
  - generic launcher contract only (`default`, `explorer`, `worker`)
  - no silent fallback for blocked Claude-dependent phases

## 4. User / Persona
- PM workflow maintainers debugging orchestrator behavior.
- Operators running `/pm` flows who need a fast, repeatable health signal before trusting a larger plan run.
- Engineers investigating failures in subagent orchestration, Claude routing, or parent/child workflow control.

## 5. Goals
- Add a first-class `PM self-check` / helper-managed self-check mode for the orchestrator.
- Spawn an outer healer agent that runs the orchestrator’s normal planning flow against a built-in deterministic fixture suite.
- Print verbose console diagnostics for orchestration failures and warnings, especially around:
  - subagent spawn/control/response handling
  - wrapper/runtime failures
  - blocked routing or phase transitions
  - Claude MCP health
- Normalize those diagnostics into machine-readable structured findings that the healer can aggregate.
- Fail the whole self-check run when Claude health is bad.
- Route discovered repair work back through the normal PM flow, but keep implementation behind the usual approval gates.
- Reuse existing control-plane primitives instead of inventing a second orchestration contract:
  - plan gate
  - Claude health checks
  - Claude wrapper normalization
  - telemetry

## 6. Non-Goals
- Autonomous code modification or ungated self-repair in the same run.
- Replacing the public PM launcher contract with named public healer launchers.
- Treating freeform arbitrary prompts as the v1 self-check signal.
- Adding a browser UI or dashboard for self-check in v1.
- Silently degrading around Claude health failures.

## 7. Scope (In/Out)
### In Scope
- Add a new `self-check` command family to [pm-command.sh](/Users/d/product-orchestrator/skills/pm/scripts/pm-command.sh).
- Define a healer-oriented self-check harness that:
  - creates a run/session id
  - selects a built-in fixture suite and fixture version
  - performs Claude health checks
  - runs the child orchestrator flow
  - captures structured outputs plus verbose console evidence
  - summarizes findings
  - prepares repair work through the normal PM process
- Add structured lifecycle/status events for:
  - fixture selected
  - spawn requested / acknowledged / failed
  - response awaited / completed / timed out / malformed
  - wrapper runtime error
  - phase blocked
  - healer remediation decision
- Add a deterministic fixture suite for v1:
  - happy-path orchestration
  - Claude health probe
  - injected subagent/control-path failure cases
  - injected response-contract failure cases
- Define a disk artifact bundle and summary format for self-check runs.
- Update docs/tests/contracts for `PM self-check`.

### Out of Scope
- Direct autonomous implementation after healer diagnosis.
- User-specified freeform fixtures as the primary v1 workflow.
- New public launcher types or direct `mcp__claude-code__Agent` paths.
- A separate observability backend beyond the existing telemetry/event model.

## 8. User Flow
### Happy Path
1. Operator runs `PM self-check`.
2. Helper emits a self-check run id, fixture-suite version, and active runtime/profile context.
3. Self-check performs Claude health validation across:
   - registration health
   - executable/runtime health
   - session usability health
4. If Claude health passes, the helper spawns the outer healer agent using the existing generic launcher contract.
5. The healer runs the orchestrator’s normal planning flow against the built-in fixture suite.
6. The helper and healer capture:
   - plan-gate status
   - wrapper results
   - telemetry events
   - verbose console warnings/errors
7. If no issues are found, self-check exits cleanly with a structured summary and explicit “no repair actions needed”.
8. If issues are found, the healer aggregates them into a repair bundle and starts the normal PM planning flow for orchestrator fixes, stopping before implementation unless the standard approvals are granted.

### Failure Paths
1. Claude health fails at any required layer.
2. Self-check fails the whole run with explicit reason, remediation, and evidence; no silent continuation occurs.

3. Child orchestrator run hits subagent spawn/control/response failures.
4. Self-check logs verbose structured diagnostics and aggregates those findings into the healer summary.

5. Wrapper-level failures occur (`CONTEXT_REQUEST`, unsupported launcher, malformed response, timeout).
6. Self-check preserves the existing wrapper semantics and records them as explicit self-check findings instead of inventing new error classes.

7. Artifact or telemetry persistence partially fails.
8. Self-check continues only if core diagnosis can still complete, while surfacing a warning about degraded observability.

## 9. Acceptance Criteria
1. `PM self-check` is a supported first-class entrypoint in the orchestrator helper/command docs.
2. The helper exposes a `self-check` command family in [pm-command.sh](/Users/d/product-orchestrator/skills/pm/scripts/pm-command.sh).
3. Each self-check run emits a stable run/session id and fixture-suite identifier.
4. Self-check uses a built-in deterministic fixture suite rather than only a freeform prompt.
5. Self-check spawns an outer healer agent using the existing generic launcher contract only.
6. Self-check reuses existing PM routing/gate behavior and does not bypass `PLAN_ROUTE_BLOCKED` / `PLAN_ROUTE_READY`.
7. Claude health is evaluated as three layers:
   - registration present
   - configured command executable in the real runtime
   - session/invocation path usable
8. If Claude health fails, the entire self-check run fails with explicit reason/remediation.
9. Self-check captures and prints verbose diagnostics for:
   - subagent spawn failures
   - subagent control/response failures
   - wrapper runtime errors
   - blocked routing/phase transitions
10. Self-check also emits structured machine-readable summaries for those same failures.
11. Existing wrapper outputs and meanings remain intact, including:
   - `runtime_error`
   - `context_needed`
   - `complete`
12. Existing telemetry/event infrastructure is extended rather than replaced.
13. The healer can automatically package repair work and route it into the normal PM flow.
14. Repair work stops at the existing approval gates; no ungated implementation path is introduced.
15. Existing non-self-check `/pm plan:` behavior remains unchanged.
16. Existing public launcher contract remains unchanged.

### Smoke Test Plan
#### Happy Path
- Start `PM self-check`, confirm run/session id, fixture-suite selection, and child run metadata are printed.
- Complete a clean healthy self-check run with no unexpected warnings.
- Verify Claude health passes only when registration, executable path, and live invocation checks all pass.
- Verify no-repair outcome is explicit when the run is clean.

#### Unhappy Path
- Inject subagent spawn failure and verify structured warning/error plus healer aggregation.
- Inject child response timeout/no-response and verify self-check does not hang and reports the timeout explicitly.
- Inject `CONTEXT_REQUEST|...` and verify self-check classifies it as a structured context deficiency.
- Inject unsupported launcher output and verify explicit runtime-error reporting with no silent reroute.
- Simulate `claude-code` registered but command not executable and verify full-run failure.
- Simulate telemetry degradation and verify self-check finishes with degraded-observability warning.

#### Regression
- Existing `/pm plan:` flow remains unchanged when `self-check` is not used.
- Existing plan-gate blocking behavior remains authoritative.
- Existing Claude wrapper status outputs remain unchanged.
- `full-codex` remains usable for normal PM flow.
- No test requires named public launcher types.

#### Execution Notes
- Browser checks are not required for v1; this is a CLI/control-plane workflow.
- Store verbose logs on disk and summarize them in agent-facing output to avoid oversized response payloads.

## 10. Success Metrics
- 100% of self-check runs produce a run id plus structured summary artifact.
- 100% of Claude-unhealthy self-check runs fail with explicit reason/remediation.
- 100% of injected lifecycle failure classes surface both:
  - verbose console evidence
  - structured machine-readable summary entries
- 0 regressions in standard `/pm plan:` command routing after self-check is added.
- 0 public PM interfaces depend on named launcher types or hidden runtime-specific healer contracts.

## 11. BEADS
### Business
- Reduces time-to-diagnosis for orchestrator regressions and runtime drift.

### Experience
- Maintainers can run one explicit health command and get both verbose evidence and normalized findings.

### Architecture
- Keep the public PM contract generic and orchestrator-owned.
- Add self-check as a helper-managed harness that reuses existing routing, wrapper, and telemetry primitives.
- Model healer as an internal orchestrator-owned role, not a new public runtime contract.

### Data
- Persist or emit structured run metadata, fixture ids, response/session ids, hashes, runtime command/path evidence, and summary findings.

### Security
- Preserve explicit approval gates for any repair implementation work.
- Avoid silent fallback or hidden autonomous mutation paths.

## 12. Rollout / Migration / Rollback
- Rollout:
  - add `self-check` helper surface
  - add deterministic fixture suite and lifecycle event schema
  - add healer prompt/reference and docs
  - extend tests and smoke evidence
- Migration:
  - no user-facing behavior changes for existing `/pm plan:` runs
  - self-check becomes an opt-in maintenance mode
- Rollback:
  - remove `self-check` route, fixtures, and healer-specific docs/tests
  - preserve existing plan-gate, wrapper, and telemetry behavior

## 13. Risks & Edge Cases
- Risk: a large synthetic fixture can produce false positives unrelated to orchestrator health.
- Risk: failing the whole run on Claude health reduces total diagnostic coverage when Claude is down, but that is the selected policy for v1.
- Risk: free-form verbose logging without structured event emission will be too noisy for reliable healer aggregation.
- Risk: healer-created repair work can become noisy or duplicative without dedupe/idempotency rules.
- Risk: older docs/PRDs in the repo still describe fallback semantics that conflict with the current block-on-Claude-failure contract.
- Edge case: Claude is registered and executable but still unusable at session time; self-check must treat that as unhealthy, not partially healthy.

## 14. Open Questions
None.

## 15. Alternatives Considered
### Option A: Diagnostic-only self-check harness
- Pros:
  - lowest implementation risk
  - simple reuse of existing status lines and telemetry
- Cons:
  - does not satisfy the requested healer/fix workflow
- Status: Rejected for final direction.

### Option B: Two-stage healer with approval-gated repair flow
- Pros:
  - fits the existing PM contract
  - allows automatic diagnosis and repair packaging
  - preserves approvals before implementation
- Cons:
  - slower than direct autonomous repair
  - requires deterministic fixtures and structured failure taxonomy
- Status: Selected.

### Option C: Fully autonomous self-healing loop
- Pros:
  - fastest feedback loop when it works
- Cons:
  - conflicts with current mandatory PM approval gates
  - higher recursion and control-plane risk
- Status: Rejected.
