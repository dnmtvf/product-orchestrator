# Self-Check Artifact Collection Hardening Smoke

Date: 2026-03-22

## Scope

Manual smoke evidence for the approved self-check artifact hardening contract:

- artifact capture uses structured per-snapshot attempt evidence instead of a generic timeout warning
- artifact-layer defects downgrade runs to `issues_detected` instead of leaving them `clean`
- unhealthy Claude registration, executability, or session usability still fails the whole run
- `SELF_CHECK_REPAIR_BUNDLE` and `SELF_CHECK_HEALER_READY` remain available for non-fatal artifact defects
- docs and automated regression coverage stay aligned with the new issue taxonomy and severity split

## Commands Executed

```bash
./scripts/test-pm-command.sh

./skills/pm/scripts/pm-command.sh self-check run \
  --fixture-case happy-path \
  --mode main-runtime-only

perl -e 'alarm shift; exec @ARGV' 30 claude -p 'Respond with OK only.'

command -v conductor
```

## Results

### Automated Regression Coverage

- PASS | `./scripts/test-pm-command.sh`
- Observed:
  - clean happy-path self-check stayed `clean`
  - unhealthy Claude runtime still ended `failed`
  - artifact hang with partial output ended `issues_detected`
  - artifact nonzero exit ended `issues_detected`
  - runtime-unavailable artifact path was recorded on failed health runs
  - skipped-capture and telemetry-incomplete classifications were exercised explicitly

### Live Codex-Native Self-Check

- PASS | live Codex-native self-check now surfaces the original Claude snapshot defect as `issues_detected`
- Command:

```bash
./skills/pm/scripts/pm-command.sh self-check run \
  --fixture-case happy-path \
  --mode main-runtime-only
```

- Observed run id: `self-check-20260322T165855Z-d26a57f1ea`
- Observed console evidence:
  - `SELF_CHECK_ARTIFACT_STATUS|...|step=claude_mcp_snapshot|status=failed|primary_code=snapshot_command_hung|issue_codes=snapshot_command_hung,snapshot_partial_output`
  - `SELF_CHECK_EVENT|...|phase=artifacts|step=claude_mcp_snapshot|status=failed|code=snapshot_command_hung`
  - `SELF_CHECK_EVENT|...|phase=health|step=claude_registration|status=passed|code=claude_code_mcp_registered`
  - `SELF_CHECK_EVENT|...|phase=health|step=claude_executability|status=passed|code=claude_code_mcp_executable`
  - `SELF_CHECK_EVENT|...|phase=health|step=claude_session|status=passed|code=claude_session_usable`
  - `PLAN_ROUTE_READY|route=default|selected_mode=main-runtime-only|...|discovery_can_start=1`
  - `SELF_CHECK_REPAIR_BUNDLE|path=.codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/healer-context.json|next_action=spawn_outer_healer`
  - `SELF_CHECK_RESULT|status=issues_detected|...`
  - `SELF_CHECK_HEALER_READY|status=ready|...`
- Summary highlights from `.codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/summary.json`:
  - `status=issues_detected`
  - `claude_health.registration=passed`
  - `claude_health.executability=passed`
  - `claude_health.session_usability=passed`
  - `child_plan_gate.status=ready`
  - `artifact_checks.claude_mcp_snapshot.primary_code=snapshot_command_hung`
  - `artifact_checks.claude_mcp_snapshot.issue_codes=[snapshot_command_hung, snapshot_partial_output]`
  - `artifact_checks.claude_mcp_snapshot.partial_combined_output="Checking MCP server health..."`

### Claude-Native Manual Smoke

- BLOCKED | true Claude-native helper execution was not available from this Codex session
- Command:

```bash
perl -e 'alarm shift; exec @ARGV' 30 claude -p 'Respond with OK only.'
```

- Observed:
  - the bounded Claude CLI probe produced no output before the 30-second timeout
  - no usable Claude-native helper run could be captured from this session

### Conductor Manual Smoke

- BLOCKED | no Conductor runtime entrypoint was available from this session
- Command:

```bash
command -v conductor
```

- Observed:
  - no `conductor` executable was present in the current environment

## Outcome

The core artifact-hardening behavior is verified locally:

- the helper no longer hides broken artifact capture under `clean`
- live Codex-native self-check now records the original Claude MCP stall as a diagnosable artifact defect with structured evidence
- automated regression coverage exercises the full approved issue taxonomy and severity split

Remaining manual QA is external to this session:

- actual Claude-native smoke
- actual Codex-in-Conductor smoke
- actual Claude-in-Conductor smoke
