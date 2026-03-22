# Deterministic Claude MCP Snapshot Smoke

Date: 2026-03-22
Scope: current Codex-runtime PM self-check after bounded Claude snapshot policy, legacy `droid-worker` cleanup, and detector false-positive hardening

## Execution

Commands executed:

```bash
./scripts/test-pm-command.sh

./skills/pm/scripts/pm-command.sh self-check run \
  --fixture-case happy-path \
  --mode main-runtime-only

git diff --check
```

## Results

- PASS | `./scripts/test-pm-command.sh`
- PASS | `git diff --check`
- PASS | live self-check run `self-check-20260322T180750Z-dc931ec886` ended `clean`

Observed live self-check evidence:

- `SELF_CHECK_ARTIFACT_STATUS|...|step=claude_mcp_snapshot|status=passed|primary_code=none`
- `SELF_CHECK_EVENT|...|phase=artifacts|step=claude_mcp_snapshot|status=passed|code=snapshot_capture_passed`
- `SELF_CHECK_EVENT|...|phase=health|step=claude_registration|status=passed|code=claude_code_mcp_registered`
- `SELF_CHECK_EVENT|...|phase=health|step=claude_executability|status=passed|code=claude_code_mcp_executable`
- `SELF_CHECK_EVENT|...|phase=health|step=claude_session|status=passed|code=claude_session_usable`
- `PLAN_ROUTE_READY|route=default|selected_mode=main-runtime-only|...|discovery_can_start=1`
- `SELF_CHECK_RESULT|status=clean|...`
- `SELF_CHECK_HEALER_READY|status=ready|...`

Summary highlights from `.codex/self-check-runs/self-check-20260322T180750Z-dc931ec886/summary.json`:

- `status=clean`
- `claude_health.registration=passed`
- `claude_health.executability=passed`
- `claude_health.session_usability=passed`
- `artifact_checks.claude_mcp_snapshot.status=passed`
- `artifact_checks.claude_mcp_snapshot.timeout_seconds=12`
- `artifact_checks.claude_mcp_snapshot.command_env_overrides=MCP_TIMEOUT=3000`
- `artifact_checks.claude_mcp_snapshot.timed_out=false`
- `events[]` does not include `legacy_droid_worker_detected`

## Outcome

The previously failing live Codex-runtime path is now clean:

- Claude snapshot capture no longer ends `snapshot_command_hung`
- the attempt artifact records the applied bounded timeout policy
- stale `droid-worker` entries were removed from `/Users/d/.claude.json`
- the legacy detector no longer emits a false-positive cleanup warning on a clean runtime
