# PRD

## Title
PM Self-Check Artifact Collection Root-Cause Hardening

## Date
2026-03-20

## Owner
PM Orchestrator

## Problem
The PM self-check artifact collection layer is not trustworthy enough for root-cause debugging. In a live happy-path self-check run, Claude registration, executability, session usability, and the child plan gate all passed, but the artifact snapshot for Claude MCP stalled after partial output and was only recorded as a generic `snapshot_capture_failed` warning.

That leaves the orchestrator in a bad state:
- artifact collection is broken, but the run can still look `clean`
- failure classification is too coarse for root-cause investigation
- the snapshot path is not clearly aligned with the same validated runtime path used by Claude health checks
- telemetry does not yet capture enough evidence to explain why the snapshot stalled

This makes healer-mode diagnosis weaker than intended and hides observability defects that should trigger repair planning.

## Context / Current State
- Self-check currently captures artifact snapshots with direct timeout-wrapped commands:
  - `codex mcp list`
  - `claude mcp list`
- Claude health checks already use a more structured contract:
  - registration check
  - executable-command resolution
  - session usability probe
- The current live self-check run `self-check-20260320T075955Z-9ab16cfec9` produced:
  - `status=clean`
  - `SELF_CHECK_HEALER_READY`
  - one finding: `snapshot_capture_failed`
  - partial artifact output in `claude-mcp-list.txt`: `Checking MCP server health...`
- Current artifact failure classification is too broad. It does not distinguish:
  - hung command
  - partial output
  - nonzero exit
  - runtime unavailable
  - skipped capture
  - incomplete telemetry
- Current self-check summary can stay `clean` even when artifact collection is visibly broken.

### Confirmed Discovery Findings
- The whole self-check artifact collection layer should be fixed, not just the single timeout symptom.
- Artifact capture should use the same validated Claude runtime path/contract that health checks use.
- Failure taxonomy should be split into multiple issue codes for better debugging checkpoints.
- When runtime health fails, self-check should be `failed`.
- When artifact collection fails but runtime health is still usable, self-check should be `issues_detected`, not `clean`.
- Artifact-layer failures should still emit healer-ready outputs and automatic repair packaging guidance.
- Coverage is required across all four runtimes:
  - Codex native
  - Claude native
  - Codex inside Conductor
  - Claude inside Conductor
- Telemetry/debug evidence should capture all useful debugging context, including command path, source, PATH override source, elapsed time, exit/signal, partial stdout/stderr, timeout state, pid/process state, runtime kind, execution mode, and run id.

### Alternatives Considered
1. Increase timeout and/or add retry only.
Rejected because it treats the symptom instead of exposing the root cause.

2. Keep artifact collection best-effort and leave self-check `clean` if health checks pass.
Rejected because broken observability is still a pipeline defect and should not be reported as clean.

3. Use the validated runtime path for artifact collection, split artifact failure codes, capture richer telemetry, and downgrade affected runs to `issues_detected`.
Selected because it best supports root-cause debugging without conflating observability defects with full runtime failure.

## User / Persona
- PM workflow maintainers diagnosing self-check and healer-mode reliability.
- Operators running PM self-check before trusting a larger `/pm` workflow.
- Engineers debugging Codex/Claude runtime behavior in native environments and Conductor.

## Goals
- Harden the entire self-check artifact collection layer.
- Use the same validated runtime path/contract for artifact capture that health checks use.
- Split artifact collection failures into a concrete failure taxonomy.
- Capture enough evidence for root-cause debugging instead of only generic timeout warnings.
- Ensure artifact-layer failures change run outcome from `clean` to `issues_detected`.
- Keep runtime health failures as `failed`.
- Preserve healer-mode continuation for artifact-layer defects so repair packaging is automatic.
- Make the behavior consistent across:
  - Codex native
  - Claude native
  - Codex inside Conductor
  - Claude inside Conductor

## Non-Goals
- Papering over the problem with timeout/retry tuning only.
- Replacing the current health-check contract with a new runtime model.
- Removing healer-mode continuation for non-fatal artifact defects.
- Adding new providers beyond Codex and Claude.
- Ungated direct repair implementation inside self-check.

## Scope

### In-Scope
- Refactor self-check artifact capture to use the validated runtime path/contract for Claude and Codex snapshot collection.
- Split artifact failure reporting into specific issue codes, including at minimum:
  - `snapshot_command_hung`
  - `snapshot_partial_output`
  - `snapshot_nonzero_exit`
  - `snapshot_runtime_unavailable`
  - `snapshot_capture_skipped`
  - `snapshot_telemetry_incomplete`
- Capture richer structured telemetry/debug evidence for artifact collection attempts.
- Update self-check result classification:
  - runtime health failure -> `failed`
  - artifact collection failure with otherwise usable runtime -> `issues_detected`
- Ensure artifact-layer failures emit healer-ready artifacts and automatic repair packaging guidance.
- Update regression tests and smoke coverage for all four runtimes.
- Update docs to describe artifact-layer failure severity and evidence expectations.

### Out-of-Scope
- New autonomous repair behavior beyond the existing approval-gated PM flow.
- UI/dashboard work for self-check visualization.
- New MCP provider integrations.
- General runtime-selection changes unrelated to self-check artifact collection.

## User Flow

### Happy Path
1. Operator runs PM self-check.
2. Self-check captures artifact snapshots through the same validated runtime path used by the runtime health checks.
3. Snapshot capture succeeds and records structured telemetry/debug evidence.
4. Runtime health passes.
5. Child plan gate passes.
6. Self-check exits `clean` and emits healer-ready artifacts with no repair action required.

### Failure Paths
1. Runtime health fails.
2. Self-check exits `failed`, records structured reason/remediation/evidence, and does not continue into repair packaging.

3. Artifact capture fails but runtime health is still usable.
4. Self-check classifies the defect under a specific artifact issue code.
5. Self-check exits `issues_detected`, emits healer-ready artifacts, and includes automatic repair packaging guidance.

6. Artifact capture produces partial output or stalls.
7. Self-check stores partial stdout/stderr plus structured process/timeout evidence instead of only a generic timeout line.

8. The same artifact defect reproduces across native and Conductor runtimes.
9. Smoke evidence and telemetry make the runtime-specific failure surface explicit rather than collapsing it into one undebuggable warning.

## Acceptance Criteria
1. Self-check artifact capture uses the same validated runtime path/contract used by runtime health checks.
2. Artifact capture no longer relies on a looser snapshot path that can disagree with the health-check runtime path.
3. Artifact-layer failures are split into specific issue codes, including:
   - `snapshot_command_hung`
   - `snapshot_partial_output`
   - `snapshot_nonzero_exit`
   - `snapshot_runtime_unavailable`
   - `snapshot_capture_skipped`
   - `snapshot_telemetry_incomplete`
4. Self-check captures structured evidence for artifact collection attempts including:
   - command path
   - command source
   - PATH override source
   - elapsed time
   - exit status or signal
   - partial stdout
   - partial stderr
   - timeout flag
   - pid/process state
   - runtime kind
   - execution mode
   - run id
5. A runtime health failure causes self-check to end with `status=failed`.
6. An artifact collection failure with otherwise usable runtime causes self-check to end with `status=issues_detected`.
7. Self-check no longer reports `status=clean` when artifact collection is broken.
8. Artifact-layer `issues_detected` runs still emit `SELF_CHECK_HEALER_READY`.
9. Artifact-layer `issues_detected` runs include automatic repair packaging guidance grounded in the artifact bundle.
10. The current live defect class represented by partial Claude MCP snapshot output is reproducibly diagnosable through the new evidence contract.
11. Behavior is covered and verified for:
   - Codex native
   - Claude native
   - Codex inside Conductor
   - Claude inside Conductor
12. Regression coverage verifies that healthy self-check runs remain `clean` when artifact collection and runtime health both pass.

### Smoke Test Plan
- Happy path:
  - Verify `clean` self-check runs in all four runtimes when artifact capture, runtime health, and child plan gate all pass.
  - Verify healer-ready artifacts are still emitted on clean runs.
- Unhappy path:
  - Reproduce artifact capture failure with partial output and verify `issues_detected`.
  - Reproduce artifact command hang and verify `snapshot_command_hung`.
  - Reproduce nonzero exit and verify `snapshot_nonzero_exit`.
  - Reproduce runtime-unavailable path and verify `snapshot_runtime_unavailable`.
  - Reproduce telemetry degradation and verify `snapshot_telemetry_incomplete`.
  - Verify runtime health failure still ends with `failed` and no repair continuation.
- Regression:
  - Verify validated runtime path is shared between health checks and artifact capture.
  - Verify no artifact-layer defect can still produce `status=clean`.
  - Verify healer-ready behavior remains available for `issues_detected`.
  - Verify Codex native and Codex inside Conductor behave consistently.
  - Verify Claude native and Claude inside Conductor behave consistently.

## Success Metrics
- 100% of artifact capture attempts emit the required debugging evidence fields.
- 0 self-check runs with artifact-layer defects end with `status=clean`.
- 100% of runtime health failures still end with `status=failed`.
- 100% of artifact-layer failures end with a specific issue code rather than a generic undifferentiated snapshot warning.
- 100% smoke coverage across the four required runtimes for the approved contract.

## BEADS

### Business
- Makes self-check/healer mode useful for real maintenance work instead of producing ambiguous “mostly healthy” runs.

### Experience
- Operators get actionable, root-cause-oriented evidence instead of a generic timeout symptom.
- Broken observability is treated as a visible defect, not hidden under `clean`.

### Architecture
- Reuse the validated runtime path/contract already established by health checks.
- Keep severity split:
  - runtime broken -> `failed`
  - observability broken -> `issues_detected`
- Preserve healer-mode continuation for non-fatal artifact defects.

### Data
- Extend self-check artifact events and/or telemetry payloads with richer debugging fields.
- Add explicit artifact-failure issue codes and evidence payload structure.

### Security
- Telemetry and artifacts must not capture secrets or raw credential-bearing config values.
- Command/path evidence should be sanitized to avoid leaking sensitive environment details.

## Rollout / Migration / Rollback
- Rollout:
  - update helper artifact capture
  - extend issue taxonomy and evidence payloads
  - update tests and smoke docs for all four runtimes
- Migration:
  - no user-facing migration needed beyond new result classification and richer artifacts
- Rollback:
  - revert to current artifact capture behavior if the validated-path approach proves incompatible, while preserving the existing runtime health contract

## Risks & Edge Cases
- Risk: native and Conductor runtimes may hang for different reasons.
  - Mitigation: require runtime-specific evidence collection and smoke coverage for all four runtimes.
- Risk: richer telemetry fields could still miss the root cause if partial output is not preserved.
  - Mitigation: require partial stdout/stderr capture in the acceptance contract.
- Risk: reclassifying runs from `clean` to `issues_detected` may increase repair-plan noise.
  - Mitigation: restrict the change to objectively broken artifact collection rather than minor cosmetic warnings.
- Edge case: artifact capture is skipped because the runtime path cannot be resolved even though the configured server is present.
  - Mitigation: classify as `snapshot_runtime_unavailable` or `snapshot_capture_skipped` with explicit remediation.
- Edge case: telemetry write partially fails while artifact files are still written.
  - Mitigation: classify as `snapshot_telemetry_incomplete` and keep artifact evidence on disk.

## Open Questions
None.
