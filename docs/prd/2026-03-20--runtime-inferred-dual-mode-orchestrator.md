# PRD

## Title
Runtime-Inferred Dual-Mode PM Orchestrator

## Date
2026-03-20

## Owner
PM Orchestrator

## Problem
The PM orchestrator still centers on provider-specific lead-model profiles and partial runtime heuristics. That creates the wrong control plane for the intended usage:

- Codex App should run the main PM flow natively in Codex.
- Claude Code should run the main PM flow natively in Claude.
- Conductor Codex sessions should behave like Codex-native PM sessions.
- Conductor Claude sessions should behave like Claude-native PM sessions.

The current contract does not fully do that. Runtime inference is limited, `claude-main` remains a selectable provider profile, and failure handling is tied to profile selection instead of the detected outer runtime. This makes the orchestrator harder to reason about and less portable across Codex App, Claude Code, and Conductor.

## Context / Current State
- The current PM helper persists provider-specific lead-model state and still exposes `Full Codex Orchestration`, `Codex as Main Agent`, and `Claude as Main Orchestrator`.
- Runtime auto-selection exists only for Conductor workspaces and currently uses positive Codex detection plus an implicit Claude fallback.
- The current helper reads Codex config from `.codex/config.toml` and `~/.codex/config.toml`, but does not yet treat Claude settings as a first-class main-runtime input.
- The current routing matrix already contains the intended cross-runtime inversion pattern:
  - when main runtime is Codex, Claude-routed MCP roles run through `claude-code`
  - when main runtime is Claude, Codex-routed MCP roles run through `codex-worker`
- Existing telemetry persistence is step-oriented (`pm_step_events`), not runtime-detection-run oriented.

### Confirmed Discovery Findings
- This Codex session exposes positive runtime markers: `CODEX_THREAD_ID` and `CODEX_INTERNAL_ORIGINATOR_OVERRIDE`.
- Codex exposes model and reasoning configuration via CLI/config.
- Claude exposes model and effort configuration via CLI/settings.
- I did not find a supported official CLI/help surface that directly answers "what runtime owns this current PM session" for both products. The orchestrator therefore needs a positive-detection contract and must fail closed when detection is not trustworthy.

### Alternatives Considered
1. Keep provider-specific lead-model profiles and only improve Conductor heuristics.
This was rejected because it preserves the wrong top-level abstraction. The operator cares about outer runtime plus execution mode, not provider-profile naming.

2. Remove cross-runtime orchestration entirely and run everything in the outer runtime.
This was rejected because the user explicitly wants both a dynamic cross-runtime mode and a single-runtime mode.

3. Replace provider-specific lead-model profiles with provider-neutral execution modes, and infer provider from the active outer runtime each run.
This is the selected approach because it matches the intended operating model across Codex App, Claude Code, and Conductor.

## User / Persona
- PM workflow operators running `/pm` from Codex App, Claude Code, or Conductor.
- Maintainers of the PM orchestration package who need a deterministic runtime contract that is portable across environments.

## Goals
- Remove `Claude as Main Orchestrator` as a user-selectable lead-model option.
- Replace provider-specific main-mode selection with two provider-neutral execution modes:
  - `Dynamic Cross-Runtime`
  - `Main Runtime Only`
- Infer the outer runtime from the running agent/session on every invocation instead of relying on persisted provider selection.
- Use the current runtime's configured model/effort for main roles when those values are available through supported config/runtime surfaces.
- In `Dynamic Cross-Runtime` mode:
  - keep main roles on the detected outer runtime
  - route MCP-served cross-provider roles to the opposite provider runtime
- In `Main Runtime Only` mode:
  - run all roles on the detected outer runtime
  - do not require opposite-provider MCP availability
- Support the same behavior in:
  - Codex App
  - Claude Code
  - Conductor Codex sessions
  - Conductor Claude sessions
- Fail closed when the orchestrator cannot positively determine the outer runtime.
- On detection failure, print a structured error report and persist the run into a separate telemetry runs table.

## Non-Goals
- Adding more than two top-level execution modes.
- Reworking Beads flow, PRD gates, or PM phase order.
- Replacing Claude MCP or Codex MCP contracts with direct app-specific special cases.
- Introducing runtime guessing as an accepted fallback when positive runtime detection fails.
- Changing install/inject dual-runtime layout unless required to support the new execution contract.

## Scope

### In-Scope
- Replace provider-specific lead-model state with provider-neutral execution-mode state.
- Runtime-detection contract for Codex App, Claude Code, and Conductor.
- Main-role model/effort inference from the active runtime's supported settings/config surface.
- Routing-matrix rewrite for:
  - detected outer runtime = Codex + `Dynamic Cross-Runtime`
  - detected outer runtime = Claude + `Dynamic Cross-Runtime`
  - detected outer runtime = Codex + `Main Runtime Only`
  - detected outer runtime = Claude + `Main Runtime Only`
- Fail-closed preflight behavior when runtime detection is ambiguous or unsupported.
- Structured console error reporting for runtime-detection failures.
- New runtime-detection-runs telemetry table.
- Documentation and regression coverage updates.

### Out-of-Scope
- Replacing step telemetry already handled by `pm_step_events`.
- New provider integrations beyond Codex and Claude.
- Replacing the dual skill installation layout with a new package layout unless required by implementation constraints.
- Changing non-runtime-related PM workflow behavior.

## User Flow

### Happy Path
1. User starts `/pm plan: ...` in Codex App, Claude Code, or Conductor.
2. PM detects the outer runtime using supported runtime markers and config surfaces.
3. PM presents two execution-mode options:
   - `Dynamic Cross-Runtime`
   - `Main Runtime Only`
4. User selects one mode, or the persisted provider-neutral execution mode is reused if already set.
5. PM resolves main-role runtime/model from the detected outer runtime.
6. PM resolves subrole routing from the combination of:
   - detected outer runtime
   - selected execution mode
7. Workflow continues in strict PM phase order.

### Failure Paths
1. PM cannot positively determine whether the current outer runtime is Codex or Claude.
2. PM prints a structured runtime-detection error report.
3. PM writes a runtime-detection run record to the dedicated telemetry runs table.
4. PM does not continue into Discovery or any downstream phase.

5. User selects `Dynamic Cross-Runtime`, but the opposite-provider MCP runtime is unavailable or unusable for a required role.
6. PM prints a structured blocked error with reason, impact, and remediation.
7. PM records the run outcome in the telemetry runs table and blocks before Discovery.

8. User selects `Main Runtime Only`.
9. PM routes all roles to the detected outer runtime and proceeds without requiring opposite-provider MCP availability.

## Acceptance Criteria
1. `/pm plan:` and `/pm plan big feature:` no longer present provider-specific options such as `Claude as Main Orchestrator`.
2. PM presents exactly two execution modes:
   - `Dynamic Cross-Runtime`
   - `Main Runtime Only`
3. Persisted PM state stores only the execution mode, not the provider/runtime identity.
4. On every invocation, provider/runtime identity is inferred fresh from the running session.
5. If the detected outer runtime is Codex and execution mode is `Dynamic Cross-Runtime`:
   - main roles remain Codex-native
   - MCP-served Claude-routed roles use `claude-code`
6. If the detected outer runtime is Claude and execution mode is `Dynamic Cross-Runtime`:
   - main roles remain Claude-native
   - MCP-served Codex-routed roles use `codex-worker`
7. If execution mode is `Main Runtime Only`, all roles use the detected outer runtime regardless of provider-specific historical routing.
8. PM resolves the main-role model/effort from the active runtime's supported configuration surface when available:
   - Codex: `model` and `model_reasoning_effort`
   - Claude: `model` and effort equivalent from Claude settings/runtime surface
9. PM no longer relies on persisted provider selection or helper-path choice to decide whether the main runtime is Codex or Claude.
10. If runtime detection cannot positively determine the outer runtime, PM fails closed before Discovery.
11. On runtime-detection failure, PM prints a structured error report that includes at minimum:
   - run id
   - route
   - workspace path
   - detection status
   - failure reason
   - detail
   - remediation
12. PM creates and writes to a dedicated telemetry runs table for runtime-detection/execution-mode preflight runs.
13. The telemetry runs table captures both successful and failed preflight runs, including detection outcome and selected execution mode.
14. Conductor Codex sessions route identically to Codex App sessions for the same execution mode.
15. Conductor Claude sessions route identically to Claude Code sessions for the same execution mode.
16. `Main Runtime Only` mode remains usable even when opposite-provider MCP is unavailable.
17. `Dynamic Cross-Runtime` mode blocks with explicit remediation when a required opposite-provider MCP runtime is unavailable or not executable.

### Smoke Test Plan
- Happy path:
  - Verify Codex App + `Dynamic Cross-Runtime` keeps main roles on Codex and routes MCP-served opposite-provider roles to Claude.
  - Verify Claude Code + `Dynamic Cross-Runtime` keeps main roles on Claude and routes MCP-served opposite-provider roles to Codex.
  - Verify Codex App + `Main Runtime Only` runs all roles on Codex.
  - Verify Claude Code + `Main Runtime Only` runs all roles on Claude.
  - Verify Conductor Codex matches Codex App behavior for both modes.
  - Verify Conductor Claude matches Claude Code behavior for both modes.
- Unhappy path:
  - Verify ambiguous runtime detection blocks before Discovery.
  - Verify `Dynamic Cross-Runtime` blocks when opposite-provider MCP is missing or not executable.
  - Verify runtime-detection failure prints a structured error report.
  - Verify runtime-detection failure inserts a row into the telemetry runs table.
- Regression:
  - Verify provider-specific persisted state no longer influences runtime selection.
  - Verify helper-path layout remains valid if retained.
  - Verify `pm_step_events` behavior is unchanged for existing step telemetry.

## Success Metrics
- 100% of planning invocations use provider-neutral execution-mode selection.
- 0 cases where runtime provider is inferred from persisted provider state.
- 0 cases where runtime detection falls back to silent guessing after positive detection fails.
- 100% of runtime-detection failures produce both console error output and telemetry run records.
- 100% routing conformance in smoke coverage across Codex App, Claude Code, Conductor Codex, and Conductor Claude.

## BEADS

### Business
- Reduces operator confusion by aligning the top-level PM control plane with the actual runtime they launched.
- Makes the orchestrator portable across Codex App, Claude Code, and Conductor without provider-specific session setup rituals.

### Experience
- Operators choose execution mode, not provider profile.
- The orchestrator behaves consistently with the runtime already in use.
- Failure behavior is explicit, structured, and diagnosable.

### Architecture
- Replace provider-profile routing with a two-axis contract:
  - detected outer runtime
  - selected execution mode
- Use positive runtime detection only.
- Fail closed when runtime identity is ambiguous.
- Keep opposite-provider MCP routing only in `Dynamic Cross-Runtime`.
- Make `Main Runtime Only` a true runtime-relative mode, not a Codex-only escape hatch.

### Data
- Replace provider-specific lead-model state with provider-neutral execution-mode state.
- Add a dedicated telemetry runs table for runtime-detection and preflight outcomes.
- Recommended table contract:
  - table name: `pm_runtime_detection_runs`
  - fields: `run_id`, `route`, `workspace_path`, `outer_runtime`, `execution_mode`, `status`, `reason`, `detail`, `remediation`, `started_at`, `completed_at`

### Security
- No new secret classes are introduced.
- Fail-closed runtime detection avoids accidental provider switching.
- Structured telemetry must not store secrets, tokens, or raw credential-bearing config payloads.

## Rollout / Migration / Rollback
- Rollout:
  - introduce the new execution-mode gate and runtime-detection preflight
  - migrate docs/tests/routing matrix together
  - keep legacy state migration logic only long enough to translate old provider profiles into the new execution-mode state
- Migration:
  - old provider-specific state is converted to provider-neutral execution mode on first read
  - runtime provider is always recalculated per invocation
- Rollback:
  - restore provider-specific lead-model state and routing only if the new runtime-detection contract proves unworkable

## Risks & Edge Cases
- Risk: no stable official session-runtime API exists for both products.
  - Mitigation: use positive supported markers/config surfaces only and fail closed when unresolved.
- Risk: `Main Runtime Only` in Claude may expose assumptions currently baked into Codex-only helper behavior.
  - Mitigation: add explicit Claude-only smoke coverage before approval to implement.
- Risk: dual-runtime install layout may still be mistaken for runtime selection.
  - Mitigation: update docs/tests so layout is packaging-only and runtime selection is session-driven.
- Edge case: opposite-provider MCP is configured but not executable in the current runtime.
  - Mitigation: keep existing executability checks and treat them as hard preflight failures in `Dynamic Cross-Runtime`.
- Edge case: legacy persisted state exists from the old three-profile contract.
  - Mitigation: one-time migration to the new mode state with explicit telemetry/logging.

## Open Questions
None.
