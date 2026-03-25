# Historical Conductor Runtime Selection Smoke

Date: 2026-03-17

## Scope

Historical smoke evidence for an older Conductor-aware dual-runtime contract:

- Conductor Codex sessions auto-select `codex-main`
- Conductor Claude sessions auto-select `claude-main`
- `codex-main` blocks with an explicit fallback offer when Claude is configured but not executable
- `claude-main` blocks when `codex-worker` is configured but `codex` is not executable in the Claude runtime
- install and inject flows created the dual-runtime helper layout used by both runtimes

This document is retained for historical reference only and does not define the current PM contract.

Helper path used for source-repo checks:

```bash
./skills/pm/scripts/pm-command.sh
```

## Happy Path Results

### Conductor Codex Session Auto-Selects `codex-main`

Command:

```bash
CODEX_THREAD_ID='codex-session' \
CODEX_INTERNAL_ORIGINATOR_OVERRIDE='Codex Desktop' \
PM_LEAD_MODEL_FORCE_CLAUDE_MCP_AVAILABLE=1 \
PM_PLAN_GATE_WORKSPACE_PATH_OVERRIDE='/tmp/conductor/workspaces/product-orchestrator/main' \
./skills/pm/scripts/pm-command.sh plan gate --route default --state-file <temp>
```

Observed:

- `LEAD_MODEL_GATE|...|selected_profile=codex-main|selection_source=conductor_auto`
- `ROUTING_PROFILE|...|profile=codex-main|selection_source=conductor_auto|main_runtime=codex-native`
- `PLAN_ROUTE_READY|...|selected_profile=codex-main|selection_source=conductor_auto|discovery_can_start=1`

Result: pass

### Conductor Claude Session Auto-Selects `claude-main`

Command:

```bash
env -u CODEX_THREAD_ID -u CODEX_INTERNAL_ORIGINATOR_OVERRIDE \
  PM_LEAD_MODEL_FORCE_CODEX_MCP_AVAILABLE=1 \
  PM_PLAN_GATE_WORKSPACE_PATH_OVERRIDE='/tmp/conductor/workspaces/product-orchestrator/main' \
  ./skills/pm/scripts/pm-command.sh plan gate --route default --state-file <temp>
```

Observed:

- `LEAD_MODEL_GATE|...|selected_profile=claude-main|selection_source=conductor_auto`
- `ROUTING_PROFILE|...|profile=claude-main|selection_source=conductor_auto|main_runtime=claude-native`
- `ROUTING_ROLE|role=senior_engineer|...|runtime=codex-worker-mcp`
- `PLAN_ROUTE_READY|...|selected_profile=claude-main|selection_source=conductor_auto|discovery_can_start=1`

Result: pass

## Unhappy Path Results

### `codex-main` Blocks When Claude Command Is Not Executable

Command:

```bash
PM_LEAD_MODEL_CLAUDE_MCP_LIST_OVERRIDE='claude-code enabled' \
PM_LEAD_MODEL_CLAUDE_COMMAND_OVERRIDE='definitely-missing-claude-command' \
./skills/pm/scripts/pm-command.sh plan gate --route default --lead-model codex-main --state-file <temp>
```

Observed:

- exit code `1`
- `PLAN_ROUTE_BLOCKED|...|selected_profile=codex-main|selection_source=explicit_override`
- `reason=claude_code_mcp_command_not_executable`
- `fallback_offer=1|fallback_profile=full-codex|fallback_label=Full Codex Orchestration`
- `next_action=ask_user_for_full_codex_fallback|discovery_can_start=0`

Result: pass

### `claude-main` Blocks When `codex` Is Not Executable In The Claude Runtime

Command:

```bash
PM_LEAD_MODEL_CODEX_MCP_LIST_OVERRIDE='codex-worker enabled' \
PM_LEAD_MODEL_CODEX_COMMAND_OVERRIDE='definitely-missing-codex-command' \
./skills/pm/scripts/pm-command.sh plan gate --route default --lead-model claude-main --state-file <temp>
```

Observed:

- exit code `1`
- `PLAN_ROUTE_BLOCKED|...|selected_profile=claude-main|selection_source=explicit_override`
- `reason=codex_worker_command_not_executable`
- `fallback_offer=0`
- `next_action=fix_codex_worker_mcp_or_choose_supported_mode|discovery_can_start=0`

Result: pass

## Regression Checks

### Dual-Runtime Install Layout

Command:

```bash
./scripts/test-runtime-layout.sh
```

Observed:

- injector test created `.codex/skills/...`, `.claude/skills/...`, `instructions/pm_workflow.md`, and `.config/opencode/instructions/pm_workflow.md`
- installer `--sync-only` test created the same dual-runtime layout
- script ended with `[test-runtime-layout] PASS`

Result: pass

### Helper Regression Suite

Command:

```bash
./scripts/test-pm-command.sh
```

Observed:

- Conductor Codex auto-selection case passed
- Conductor Claude auto-selection case passed
- blocked `codex-main` case passed
- blocked `claude-main` case passed
- script ended with `[test-pm-command] PASS`

Result: pass

## Outcome

The Conductor-aware selection precedence, the inverted `claude-main` runtime contract, the blocked secondary-runtime cases, and the dual-runtime install layout all behaved as designed.
