# Runtime-Inferred Dual-Mode Orchestrator Smoke Evidence

Date: 2026-03-20
Scope: provider-neutral execution modes, positive outer-runtime detection, fail-closed preflight, routing matrix parity, telemetry-run contract, and updated PM workflow docs.

## Execution
Commands executed:

```bash
./scripts/test-pm-command.sh

PM_PLAN_GATE_RUNTIME_OVERRIDE=codex \
PM_LEAD_MODEL_FORCE_CLAUDE_MCP_AVAILABLE=1 \
./skills/pm/scripts/pm-command.sh plan gate --route default

PM_PLAN_GATE_RUNTIME_OVERRIDE=claude \
PM_LEAD_MODEL_FORCE_CODEX_MCP_AVAILABLE=1 \
./skills/pm/scripts/pm-command.sh plan gate --route default --mode main-runtime-only

PM_PLAN_GATE_RUNTIME_OVERRIDE=none \
./skills/pm/scripts/pm-command.sh plan gate --route default

diff -u instructions/pm_workflow.md .config/opencode/instructions/pm_workflow.md
```

## Results
- PASS | `./scripts/test-pm-command.sh` completed successfully with updated execution-mode, runtime-detection, self-check, and self-update coverage.
- PASS | Codex outer runtime emits `RUNTIME_DETECTION`, `EXECUTION_MODE_GATE`, Codex-native main roles, and Claude MCP-routed support roles under `dynamic-cross-runtime`.
- PASS | Claude outer runtime emits `RUNTIME_DETECTION`, `EXECUTION_MODE_GATE`, and keeps all roles Claude-native under `main-runtime-only`.
- PASS | Explicit detection disable (`PM_PLAN_GATE_RUNTIME_OVERRIDE=none`) fails closed with `RUNTIME_DETECTION_ERROR` and `PLAN_ROUTE_BLOCKED`.
- PASS | Workflow instruction copies remain synchronized after the contract update.

## Regression Checklist
- [x] Top-level user selection is reduced to `Dynamic Cross-Runtime` and `Main Runtime Only`.
- [x] Outer runtime is inferred fresh per plan-gate run instead of selected as a provider profile.
- [x] Legacy provider-profile state migrates to execution-mode state without breaking the existing state-file path.
- [x] `dynamic-cross-runtime` blocks with explicit remediation when `claude-code` or `codex-worker` is unavailable.
- [x] `main-runtime-only` remains usable without opposite-provider MCP.
- [x] Runtime-detection failures emit structured console output and target the dedicated telemetry runs table contract.
- [x] README, workflow copies, PM skills, MCP prerequisites, and routing YAML all describe the same provider-neutral contract.
