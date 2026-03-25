# Claude Launcher Health Smoke

Date: 2026-03-25

## Scope

Manual smoke evidence for the approved Claude launcher health repair:

- dynamic Claude readiness is determined by a live launcher probe, not by MCP registration alone
- `dynamic-cross-runtime` under Codex fails closed when the Claude `Agent` launcher cannot run any configured candidate
- `self-check run --mode dynamic-cross-runtime` now uses the same live launcher probe and fails instead of returning a false-green summary
- `main-runtime-only` remains ready and unaffected by Claude launcher failure
- automated regression coverage exercises the launcher contract, unsupported-launcher path, config-backed PATH handling, and self-check regression cases

## Commands Executed

```bash
./scripts/test-pm-command.sh

./skills/pm/scripts/pm-command.sh plan gate \
  --route default \
  --mode dynamic-cross-runtime \
  --state-file <temp>

./skills/pm/scripts/pm-command.sh plan gate \
  --route default \
  --mode main-runtime-only \
  --state-file <temp>

./skills/pm/scripts/pm-command.sh self-check run \
  --mode dynamic-cross-runtime \
  --artifacts-dir .codex/self-check-runs/manual-claude-launcher-smoke-20260325T091939Z
```

## Results

### Automated Regression Coverage

- PASS | `./scripts/test-pm-command.sh`
- Observed:
  - launcher contract file is required and validated
  - self-check happy path now reports the normalized launcher contract path
  - dynamic plan gate blocks on unsupported launcher candidates
  - `self-check run --mode dynamic-cross-runtime` fails when the launcher probe fails
  - config-backed `PATH` handling still allows live launcher probes to run without clobbering the ambient runtime `PATH`

### Live Dynamic Plan Gate

- PASS | dynamic mode blocked exactly as designed
- Command:

```bash
./skills/pm/scripts/pm-command.sh plan gate \
  --route default \
  --mode dynamic-cross-runtime \
  --state-file <temp>
```

- Observed:
  - `PLAN_ROUTE_BLOCKED|route=default|selected_mode=dynamic-cross-runtime|...|reason=claude_code_mcp_launcher_unusable|...|discovery_can_start=0`
  - `detail=default: Agent type 'default' not found. Available agents:; Plan: Agent type 'Plan' not found. Available agents:; Explore: Agent type 'Explore' not found. Available agents:`

### Live Dynamic Self-Check

- PASS | dynamic self-check now fails closed on the live launcher defect
- Command:

```bash
./skills/pm/scripts/pm-command.sh self-check run \
  --mode dynamic-cross-runtime \
  --artifacts-dir .codex/self-check-runs/manual-claude-launcher-smoke-20260325T091939Z
```

- Observed run id: `self-check-20260325T091951Z-c38c65622c`
- Console evidence:
  - `SELF_CHECK_EVENT|...|phase=health|step=claude_registration|status=passed|code=claude_code_mcp_registered`
  - `SELF_CHECK_EVENT|...|phase=health|step=claude_executability|status=passed|code=claude_code_mcp_executable`
  - `SELF_CHECK_EVENT|...|phase=health|step=claude_session|status=failed|code=claude_code_mcp_launcher_unusable`
  - `SELF_CHECK_RESULT|status=failed|...|reason=claude_code_mcp_launcher_unusable|summary_file=.codex/self-check-runs/manual-claude-launcher-smoke-20260325T091939Z/summary.json`
- Summary highlights from `.codex/self-check-runs/manual-claude-launcher-smoke-20260325T091939Z/summary.json`:
  - `status=failed`
  - `claude_health.registration=passed`
  - `claude_health.executability=passed`
  - `claude_health.session_usability=failed`
  - `claude_health.launcher_contract_file=skills/pm/agents/claude-launcher-contract.json`
  - `child_plan_gate.status=not_started`
  - `artifact_checks.claude_launcher_probe.reason=claude_code_mcp_launcher_unusable`
- Probe highlights from `.codex/self-check-runs/manual-claude-launcher-smoke-20260325T091939Z/claude-session-probe-result.json`:
  - `server_info.name=claude/tengu`
  - `server_info.version=2.1.81`
  - `tool_name=Agent`
  - `candidate_field=subagent_type`
  - `candidate_results[default].error_kind=unsupported_launcher`
  - `candidate_results[Plan].error_kind=unsupported_launcher`
  - `candidate_results[Explore].error_kind=unsupported_launcher`

### Main Runtime Only Fallback

- PASS | `main-runtime-only` remains ready
- Command:

```bash
./skills/pm/scripts/pm-command.sh plan gate \
  --route default \
  --mode main-runtime-only \
  --state-file <temp>
```

- Observed:
  - `PLAN_ROUTE_READY|route=default|selected_mode=main-runtime-only|selected_label=Main Runtime Only|selection_source=explicit_override|outer_runtime=codex|outer_runtime_source=codex_env|discovery_can_start=1`

## Outcome

The approved repair is verified locally:

- dynamic Claude readiness now depends on a real delegated launcher probe
- broken Claude launchers block dynamic mode and fail self-check with explicit evidence instead of returning `clean`
- `main-runtime-only` remains available as the unaffected fallback mode
