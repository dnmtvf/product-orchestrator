# Smoke Evidence: Lead-Model Gate And Routing

Date: 2026-03-04
Epic: `product-orchestrator-9i6`
PRD: `/Users/d/product-orchestrator/docs/prd/2026-03-04--pm-lead-model-selection-routing.md`
Helper: `/Users/d/product-orchestrator/skills/pm/scripts/pm-command.sh`

## Scope
Manual smoke execution for:
- lead-model gate on both plan routes (`default`, `big-feature`)
- persisted lead-model profile reuse across invocations
- propagation of selected main model/runtime to handoff roles
- fail-fast behavior when `claude-first` is selected and `claude-code` MCP is unavailable

## Environment
- Temporary state file used for smoke isolation:
  - `/var/folders/x9/7khmhvfd7874d4cycdcyspkr0000gn/T/tmp.E3WrZAUUW3/pm-lead-model-state.json`
- MCP availability was controlled with test env toggles:
  - `PM_LEAD_MODEL_FORCE_CLAUDE_MCP_AVAILABLE=1`
  - `PM_LEAD_MODEL_FORCE_CLAUDE_MCP_UNAVAILABLE=1`

## Results
1. `codex-first` on `default` route: PASS
- `LEAD_MODEL_GATE|route=default` emitted before readiness.
- `ROUTING_PROFILE|...|profile=codex-first|main_runtime=codex-native|main_model=gpt-5.3-codex`.
- `project_manager`, `pm_beads_plan_handoff`, `pm_implement_handoff` mapped to `codex-native` + `gpt-5.3-codex`.
- `task_verification` mapped to `codex-native` (unpinned model).
- `PLAN_ROUTE_READY|route=default|selected_profile=codex-first` emitted.

2. `codex-first` on `big-feature` route: PASS
- `LEAD_MODEL_GATE|route=big-feature` emitted before readiness.
- Main roles and both handoff roles remained on `codex-native` + `gpt-5.3-codex`.
- `PLAN_ROUTE_READY|route=big-feature|selected_profile=codex-first` emitted.

3. Persisted `claude-first` profile reuse: PASS
- After `lead-model set --profile claude-first`, next `plan gate --route default` without override emitted:
  - `persisted_profile=claude-first|selected_profile=claude-first`.
- `ROUTING_PROFILE|...|main_runtime=claude-code-mcp|main_model=<unpinned>`.
- `project_manager`, `pm_beads_plan_handoff`, `pm_implement_handoff`, and `task_verification` mapped to `claude-code-mcp`.

4. Claude MCP unavailable fail-fast: PASS
- Command exit code: `2`.
- Gate line emitted first (`LEAD_MODEL_GATE|route=default|...`).
- Block line emitted:
  - `BLOCKED|reason=claude_code_mcp_unavailable|...|remediation=codex mcp add claude-code -- claude mcp serve`
- No `PLAN_ROUTE_READY` emitted in blocked case.

5. Review-iteration recheck (disabled MCP status + reset repair): PASS
- When MCP list reported `claude-code disabled`, gate blocked with:
  - `BLOCKED|reason=claude_code_mcp_unavailable|...`
- When lead-model state file contained invalid JSON, `lead-model reset` repaired state and emitted:
  - `LEAD_MODEL_STATE|action=reset|profile=codex-first`

## Conclusion
Smoke coverage for happy/unhappy/regression scenarios passed for lead-model selection routing:
- happy path: codex-first on both plan routes
- unhappy path: claude-first with missing MCP blocks immediately
- regression: persisted profile reuse, disabled-MCP handling, reset repair, and handoff-role propagation remain consistent
