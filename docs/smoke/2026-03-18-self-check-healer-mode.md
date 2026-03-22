# PM Self-Check Healer Smoke

Date: 2026-03-18

## Scope

Manual smoke evidence for the approved PM self-check/healer mode:

- `/pm self-check` helper route is wired through `pm-command.sh self-check`
- clean runs emit a healer-ready artifact bundle with no findings
- Claude health failures stop the whole run before child flow planning
- injected runtime failures emit verbose diagnostics plus an approval-gated repair bundle
- docs, helper help output, and install/inject layout stay aligned with the new route

## Environment Notes

- Smoke commands were run in isolated temporary Git repos to avoid mutating repo-local PM state.
- Happy-path and injected-runtime checks used `PM_LEAD_MODEL_CLAUDE_MCP_LIST_OVERRIDE='claude-code enabled'` plus `PM_LEAD_MODEL_CLAUDE_COMMAND_OVERRIDE=<temp fake claude>` so the helper used a deterministic Claude command path.
- The fail-whole-run check used `PM_LEAD_MODEL_FORCE_CLAUDE_MCP_UNAVAILABLE=1` to force Claude-health failure after registration.

## Happy Path Results

### Clean Self-Check Produces Healer-Ready Artifacts

Command:

```bash
PM_LEAD_MODEL_CLAUDE_MCP_LIST_OVERRIDE='claude-code enabled' \
PM_LEAD_MODEL_CLAUDE_COMMAND_OVERRIDE=<temp fake claude> \
./skills/pm/scripts/pm-command.sh self-check run \
  --fixture-case happy-path \
  --artifacts-dir <temp>/self-check-happy \
  --lead-model full-codex
```

Observed:

- `SELF_CHECK_ARTIFACT|kind=claude_mcp_snapshot|.../claude-mcp-list.txt`
- `SELF_CHECK_EVENT|...|step=claude_registration|status=passed|code=claude_code_mcp_registered`
- `SELF_CHECK_EVENT|...|step=claude_executability|status=passed|code=claude_code_mcp_executable`
- `SELF_CHECK_EVENT|...|step=claude_session|status=passed|code=claude_session_usable`
- `PLAN_ROUTE_READY|route=default|selected_profile=full-codex|...|discovery_can_start=1`
- `SELF_CHECK_RESULT|status=clean|...|finding_count=0|critical_count=0`
- `SELF_CHECK_HEALER_READY|status=ready|...|next_action=spawn_outer_healer`
- summary JSON recorded:
  - `status=clean`
  - `claude_health.registration=passed`
  - `claude_health.executability=passed`
  - `claude_health.session_usability=passed`
  - `child_plan_gate.status=ready`

Result: pass

## Unhappy Path Results

### Claude Health Failure Stops The Run Before Child Flow

Command:

```bash
PM_LEAD_MODEL_FORCE_CLAUDE_MCP_UNAVAILABLE=1 \
./skills/pm/scripts/pm-command.sh self-check run \
  --fixture-case happy-path \
  --artifacts-dir <temp>/self-check-unhealthy \
  --lead-model full-codex
```

Observed:

- `SELF_CHECK_EVENT|...|step=claude_registration|status=passed|code=claude_code_mcp_registered`
- `SELF_CHECK_EVENT|...|step=claude_executability|status=failed|code=claude_code_mcp_unavailable`
- `SELF_CHECK_RESULT|status=failed|...|reason=claude_code_mcp_unavailable`
- no `SELF_CHECK_HEALER_READY` line was emitted
- summary JSON recorded:
  - `status=failed`
  - `claude_health.executability=failed`
  - `claude_health.session_usability=failed`
  - `child_plan_gate.status=not_started`

Result: pass

### Unsupported Launcher Fixture Produces Repair Bundle

Command:

```bash
PM_LEAD_MODEL_CLAUDE_MCP_LIST_OVERRIDE='claude-code enabled' \
PM_LEAD_MODEL_CLAUDE_COMMAND_OVERRIDE=<temp fake claude> \
./skills/pm/scripts/pm-command.sh self-check run \
  --fixture-case unsupported-launcher \
  --artifacts-dir <temp>/self-check-unsupported \
  --lead-model full-codex
```

Observed:

- `CLAUDE_WRAPPER_RESULT|status=runtime_error|error=unsupported_launcher|...`
- `SELF_CHECK_EVENT|...|phase=fixture|step=runtime|status=failed|code=unsupported_launcher`
- `SELF_CHECK_REPAIR_BUNDLE|path=<temp>/self-check-unsupported/healer-context.json|next_action=spawn_outer_healer`
- `SELF_CHECK_RESULT|status=issues_detected|...|critical_count=1`
- `SELF_CHECK_HEALER_READY|status=ready|...|next_action=spawn_outer_healer`
- summary JSON recorded one `unsupported_launcher` finding with remediation:
  - `Do not silently reroute blocked Claude-dependent paths.`

Result: pass

## Regression Checks

### Helper Regression Suite

Command:

```bash
./scripts/test-pm-command.sh
```

Observed:

- new self-check fixture/help/docs tests passed
- legacy lead-model, plan-gate, Claude wrapper, and self-update cases still passed
- script ended with `[test-pm-command] PASS`

Result: pass

### Install And Inject Layout

Command:

```bash
./scripts/test-runtime-layout.sh
```

Observed:

- injector and installer sync-only flows still produced dual-runtime skill trees
- script ended with `[test-runtime-layout] PASS`

Result: pass

## Outcome

PM self-check now has a deterministic helper route, emits explicit machine-readable diagnostics, fails closed on unhealthy Claude runtime conditions, and produces healer-ready repair artifacts when non-fatal orchestration issues are detected. The live docs, helper help surface, regression tests, and runtime layout checks all match the new contract.
