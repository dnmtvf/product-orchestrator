# PRD

## Title
Always Prompt Execution Mode On `/pm plan`

## Date
2026-03-22

## Owner
PM Orchestrator

## Problem
The runtime-routing contract works in the current Codex session, but the repository-level planning contract is split between interactive PM instructions and helper-level persisted-state behavior.

Today, a new `/pm plan: ...` run can proceed by silently reusing the persisted execution mode from `.codex/pm-lead-model-state.json` when the helper is invoked without `--mode`. In practice, that means a user may not be explicitly asked whether they want:
- `Dynamic Cross-Runtime`
- `Main Runtime Only`

For this planning request, the expected behavior is explicit: when PM planning starts in a Codex runtime, Codex should ask whether to use the hybrid model approach (Codex main roles plus Claude MCP for mapped support roles) or keep the run fully on the runtime-inferred main model. Silent reuse of persisted state makes that choice opaque and conflicts with the current PM workflow language that says the execution-mode question must be asked before Discovery.

## Context / Current State
- In the current session, `./skills/pm/scripts/pm-command.sh plan gate --route default --mode dynamic-cross-runtime` returns `PLAN_ROUTE_READY` with:
  - `outer_runtime=codex`
  - `main_runtime=codex-native`
  - Claude-routed support roles mapped to `claude-code-mcp`
- In the current session, `codex mcp list` shows `claude-code` enabled, so the hybrid path is healthy.
- `scripts/inject-workflow.sh` and `scripts/install-workflow.sh` copy the same PM skill set into both `.codex/skills/...` and `.claude/skills/...`, so there is not a separate runtime-specific implementation of `/pm plan`.
- The helper currently loads `persisted_mode` from `.codex/pm-lead-model-state.json` and, when no `--mode` override is passed, reuses that value and returns `selection_source=persisted_state`.
- Current tests explicitly cover persisted-state auto-selection and `PLAN_ROUTE_READY` without a fresh user choice.
- `scripts/test-pm-command.sh` intentionally asserts helper behavior for persisted-state reuse, which means the current helper-level API surface treats silent persisted selection as valid.
- Current PM workflow docs and skills say the execution-mode question must be asked before Discovery, which creates a repo-level contract mismatch:
  - documented behavior: ask the user
  - helper behavior: auto-select persisted state unless an explicit override is passed
- README and workflow docs already describe interactive PM planning as “select execution mode before Discovery starts,” but helper help text and tests describe persisted execution mode as reused by default.
- The repo does not contain a separate interactive selector implementation outside the PM skill/workflow contract. In this source repo, the only executable planning logic is the shared helper plus the runtime-consumed skill instructions.
- The repo already models the two desired execution behaviors:
  - `Dynamic Cross-Runtime`: keep main PM roles on the detected outer runtime and route mapped support roles through the opposite-provider MCP path
  - `Main Runtime Only`: keep all roles on the detected outer runtime

### Confirmed Discovery Findings
- Codex runtime detection is working in this session.
- The Claude MCP path is configured and executable enough for the current dynamic gate to pass.
- The routing matrix already expresses the hybrid behavior the user asked for.
- The user-facing gap is not routing correctness; it is that fresh interactive `/pm plan` runs do not reliably force a visible execution-mode selection before Discovery.
- The installer/runtime layout means the likely implementation surface is the PM contract and interactive orchestration behavior, not a second hidden runtime-specific plan entrypoint.
- The helper’s persisted-state behavior appears intentional and test-backed for direct helper usage, so the clean contract is:
  - interactive `/pm` flow must ask every new plan run
  - direct helper flow may still support persisted defaults when explicitly used as a lower-level interface

### Research / Verification Notes
**Confirmed**
- The helper emits `EXECUTION_MODE_GATE|question=Select execution mode before Discovery|options=Dynamic Cross-Runtime;Main Runtime Only`.
- The helper still proceeds with `PLAN_ROUTE_READY` when selection comes from `persisted_state`.
- The current dynamic gate works correctly in the active Codex runtime and uses Claude MCP for mapped support roles.
- The shared installer copies the same PM implementation into both Codex and Claude runtime skill roots.
- The current automated tests enforce persisted-state helper behavior but do not enforce an interactive `/pm` selection prompt contract.

**Unknown / Needs verification**
- Whether Codex/Claude runtime harnesses outside this source repo expose any additional top-level `/pm` interaction layer that is not represented in the installed skill contract.

## User / Persona
- PM maintainers who need a deterministic, understandable planning workflow.
- Engineers starting a fresh `/pm plan` run and expecting to choose execution behavior explicitly.
- Operators switching between Codex-only and hybrid Codex/Claude planning sessions.

## Goals
- Make every new `/pm plan: ...` and `/pm plan big feature: ...` run present the two execution-mode options before Discovery starts.
- Treat the persisted execution mode as the default selection, not as permission to skip the question.
- Preserve fresh outer-runtime inference on every invocation.
- Preserve direct helper usability for lower-level workflows that intentionally rely on persisted state, while distinguishing that from interactive PM orchestration.
- Preserve the existing routing matrix semantics:
  - `Dynamic Cross-Runtime` stays hybrid
  - `Main Runtime Only` stays single-runtime
- Preserve existing block behavior when a required opposite-provider MCP path is unavailable.
- Make the Codex-runtime UX clearly describe the hybrid choice in terms the user requested:
  - Codex main model/runtime for main roles
  - Claude MCP for mapped support roles

## Non-Goals
- Changing the meaning of `Dynamic Cross-Runtime` or `Main Runtime Only`.
- Adding a third orchestration mode.
- Removing persisted execution-mode state or the `/pm execution-mode show|set|reset` commands.
- Weakening fail-closed runtime detection or MCP availability gates.
- Requiring direct Claude CLI/app orchestration outside the existing MCP contract.

## Scope

### In-Scope
- Update the user-facing PM planning flow so interactive `/pm plan` runs always surface the two-option execution-mode gate before Discovery.
- Use persisted execution-mode state only to preselect the default option.
- Persist the newly selected mode after the user confirms the choice.
- Ensure normal interactive PM plan runs reach `plan gate` with an explicit user-selected mode.
- Clarify the contract boundary between:
  - interactive `/pm` orchestration behavior
  - direct helper `plan gate` behavior
- Update PM docs and tests so the contract is consistent:
  - interactive `/pm plan` asks every time
  - persisted state remains the default suggestion for interactive runs
  - direct helper persisted-state behavior is documented as lower-level behavior where relevant
- Add smoke coverage for Codex-runtime hybrid selection wording and resulting routing behavior.

### Out-of-Scope
- Reworking `plan gate` runtime-detection internals.
- Replacing the helper CLI with a new orchestration layer.
- Changing role mappings in `skills/pm/agents/model-routing.yaml`.
- Removing persisted-state support from the helper entirely unless that is required by implementation discovery later.
- Implementation or review-phase runtime routing changes unrelated to the plan-start selection UX.

## User Flow

### Happy Path
1. User starts `/pm plan: ...` in a Codex runtime.
2. PM detects the outer runtime as Codex.
3. PM presents exactly two execution-mode choices:
   - `Dynamic Cross-Runtime`
   - `Main Runtime Only`
4. PM uses the persisted mode only as the default highlighted choice.
5. User explicitly selects one option.
6. PM persists that selection and invokes `plan gate` with an explicit mode override.
7. If the user selected `Dynamic Cross-Runtime`, PM keeps main roles on Codex and routes mapped support roles through `claude-code-mcp`.
8. If the user selected `Main Runtime Only`, PM keeps all roles on Codex-native runtime/model.
9. Discovery starts only after `PLAN_ROUTE_READY` and `discovery_can_start=1`.

### Failure Paths
1. User selects `Dynamic Cross-Runtime` in a Codex runtime, but `claude-code` MCP is unavailable or not executable.
2. `plan gate` blocks before Discovery with explicit remediation and does not silently switch to `Main Runtime Only`.

3. Outer runtime detection fails or is ambiguous.
4. PM blocks before Discovery and reports the structured runtime-detection error.

5. Persisted state exists, but the interactive plan flow fails to show the selection prompt.
6. That is treated as a contract regression because the run skipped the required explicit user choice.

7. A developer invokes `./skills/pm/scripts/pm-command.sh plan gate ...` directly without `--mode`.
8. Helper-level persisted-state selection may still occur if that lower-level contract is intentionally preserved.
9. Docs must distinguish this from the interactive `/pm` requirement so the two behaviors are not conflated.

## Acceptance Criteria
1. Every new interactive `/pm plan: ...` run asks the user to choose between `Dynamic Cross-Runtime` and `Main Runtime Only` before Discovery.
2. Every new interactive `/pm plan big feature: ...` run asks the same two-option question before Discovery.
3. Persisted execution-mode state is used only to preselect the default option; it does not auto-advance an interactive plan run.
4. Normal interactive PM plan runs invoke `plan gate` with an explicit user-selected mode, so the resulting gate output uses `selection_source=explicit_override`.
5. In Codex outer runtime, the `Dynamic Cross-Runtime` option is described to the user as:
   - main PM roles on Codex
   - mapped support roles through Claude MCP
6. In Codex outer runtime, selecting `Dynamic Cross-Runtime` still produces Codex-native main roles and Claude-MCP-routed support roles.
7. In Codex outer runtime, selecting `Main Runtime Only` still produces Codex-native routing for all roles.
8. If the user selects `Dynamic Cross-Runtime` and Claude MCP is unavailable or not executable, PM blocks before Discovery with explicit remediation and no silent fallback.
9. `/pm execution-mode show|set|reset` continues to work and continues to persist cross-session state.
10. PM docs and tests no longer imply that persisted mode may silently satisfy the interactive selection requirement for interactive `/pm` runs.
11. The repo explicitly distinguishes interactive `/pm` contract requirements from direct helper `plan gate` defaults.

### Smoke Test Plan
- Happy path:
  - Start a new interactive `/pm plan: ...` in Codex with persisted mode `dynamic-cross-runtime`; verify the selector still appears and defaults to `Dynamic Cross-Runtime`.
  - Confirm that choosing `Dynamic Cross-Runtime` yields `selection_source=explicit_override`, `outer_runtime=codex`, Codex-native main roles, and Claude-MCP-routed support roles.
  - Start a new interactive `/pm plan: ...` in Codex with persisted mode `main-runtime-only`; verify the selector still appears and defaults to `Main Runtime Only`.
  - Confirm that choosing `Main Runtime Only` yields `selection_source=explicit_override` and all roles stay Codex-native.
- Unhappy path:
  - Start a new interactive `/pm plan: ...` in Codex, choose `Dynamic Cross-Runtime`, and simulate unavailable Claude MCP.
  - Verify the run stops before Discovery with `PLAN_ROUTE_BLOCKED` and explicit remediation.
  - Simulate runtime-detection failure and verify PM blocks before Discovery with structured runtime error output.
- Regression:
  - Verify `/pm execution-mode show|set|reset` still reads and writes the persisted state correctly.
  - Verify non-interactive helper invocations that intentionally rely on persisted state remain documented as helper behavior, not interactive PM UX behavior.
  - Verify the routing matrix and gate semantics remain unchanged aside from the interactive selection requirement.

## Success Metrics
- 100% of interactive `/pm plan` runs display the two-option execution-mode selector before Discovery.
- 100% of interactive `/pm plan big feature` runs display the same selector before Discovery.
- 0 interactive plan runs proceed from persisted state without a visible user choice.
- 100% of hybrid selections in Codex runtime keep main roles Codex-native and mapped support roles Claude-routed when Claude MCP is healthy.
- 100% of interactive plan runs preserve explicit pre-Discovery failure when the selected routed runtime is unavailable.

## BEADS

### Business
- Reduces operator confusion about which runtime/model mix a planning run will use.
- Prevents accidental planning runs under the wrong execution mode.

### Experience
- Makes the start of a PM planning run explicit and understandable.
- Preserves user control without removing the convenience of a remembered default.

### Architecture
- Keep runtime inference and routing logic in the existing helper.
- Shift interactive plan-start semantics to explicit user confirmation on every new plan run.
- Preserve persisted execution-mode state as a default-selection source for the interactive layer instead of an auto-continue trigger.
- Keep any helper-level persisted-state fallback explicit and documented if retained as a lower-level interface.

### Data
- Continue storing the last selected execution mode in `.codex/pm-lead-model-state.json`.
- Ensure telemetry and gate outputs still capture selected mode, selection source, and detected outer runtime.

### Security
- Preserve fail-closed behavior when routed MCP dependencies are unavailable.
- Avoid hidden runtime selection, which can conceal whether an external MCP path will be used.

## Rollout / Migration / Rollback
- Rollout:
  - update the interactive PM planning entrypoint to always ask for execution mode
  - keep persisted state as the default selection
  - update tests and workflow docs to match the interactive contract
- Migration:
  - preserve existing state files
  - reinterpret persisted mode as default choice for the selector
  - keep `plan gate` and runtime-routing semantics unchanged
- Rollback:
  - restore the current behavior where interactive runs may auto-use persisted state
  - retain the current helper/state format

## Risks & Edge Cases
- Risk: prompting on every interactive plan run may feel repetitive if not presented with a clear default selection.
- Risk: docs may stay inconsistent if helper-level persisted-state behavior and interactive PM UX behavior are not explicitly distinguished.
- Risk: downstream installed repos may surface the selector differently unless the contract is centralized in shared PM workflow instructions.
- Edge case: a user launches helper commands directly instead of using interactive `/pm` entrypoints; helper-level persisted-state behavior may still be valid there and should not be confused with the interactive PM contract.
- Edge case: Codex runtime is healthy, but Claude MCP becomes unavailable between selection and routed-role execution; the existing phase-level block behavior must remain intact.

## Open Questions
None.

## Alternatives Considered
### Option A: Keep the current persisted-state auto-selection behavior
- Pros:
  - least change to the helper path
  - fastest repeated planning runs
- Cons:
  - conflicts with the current PM workflow language for interactive `/pm`
  - hides the runtime/mode choice from the user
  - does not satisfy the user expectation for fresh `/pm plan` runs
- Status: Rejected.

### Option B: Always ask on interactive `/pm plan`, but preselect the persisted default
- Pros:
  - satisfies the user expectation
  - keeps the remembered preference useful
  - preserves current routing and gate behavior
  - fits the actual repo structure, where the shared helper remains the lower-level engine and the PM contract defines the interactive behavior
- Cons:
  - adds one confirmation step per interactive planning run
- Status: Selected.

### Option C: Remove helper persisted-state behavior entirely
- Pros:
  - simplest mental model for interactive runs
- Cons:
  - throws away a useful cross-session preference
  - may break existing helper-level expectations already encoded in tests
  - broader than necessary if the real fix is contract separation between interactive PM and direct helper usage
- Status: Rejected.
