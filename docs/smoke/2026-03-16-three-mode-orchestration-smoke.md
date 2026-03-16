# Three-Mode Orchestration Smoke

Date: 2026-03-16

## Scope

Manual smoke evidence for the approved three-mode orchestration contract:

- `Full Codex Orchestration`
- `Codex as Main Agent`
- `Claude as Main Orchestrator`

This smoke also verifies:

- codex-main fallback offer behavior when Claude is unavailable
- claude-main fail-fast behavior when Claude is unavailable
- non-interactive runtime `PATH` regression handling via Codex config
- Claude context-pack validation and handshake parsing

## Environment Notes

- Current Codex exec runtime `PATH` did not include `/Users/d/.local/bin`.
- `command -v claude` returned no result in that stripped runtime.
- Global Codex config supplied the launch path via `[shell_environment_policy.set].PATH` in `/Users/d/.codex/config.toml`.

## Happy Path Results

### Full Codex Orchestration

Command:

```bash
skills/pm/scripts/pm-command.sh plan gate --route default --lead-model full-codex --state-file <temp>
```

Observed:

- `ROUTING_PROFILE|route=default|profile=full-codex|main_runtime=codex-native|main_model=gpt-5.4|main_reasoning_effort=xhigh|fallback_active=0`
- `PLAN_ROUTE_READY|route=default|selected_profile=full-codex|selected_label=Full Codex Orchestration|discovery_can_start=1`

Result: pass

### Codex as Main Agent

Command:

```bash
skills/pm/scripts/pm-command.sh plan gate --route default --lead-model codex-main --state-file <temp>
```

Observed:

- `ROUTING_PROFILE|route=default|profile=codex-main|main_runtime=codex-native|main_model=gpt-5.4|main_reasoning_effort=xhigh|fallback_active=0`
- Claude-mapped support roles remained on `claude-code-mcp`
- `PLAN_ROUTE_READY|route=default|selected_profile=codex-main|selected_label=Codex as Main Agent|discovery_can_start=1`

Result: pass

### Claude as Main Orchestrator

Command:

```bash
skills/pm/scripts/pm-command.sh plan gate --route default --lead-model claude-main --state-file <temp>
```

Observed:

- `ROUTING_PROFILE|route=default|profile=claude-main|main_runtime=claude-code-mcp|main_model=<unpinned>|main_reasoning_effort=<unpinned>|fallback_active=0`
- codex-native support roles stayed pinned to `gpt-5.4` / `xhigh`
- `PLAN_ROUTE_READY|route=default|selected_profile=claude-main|selected_label=Claude as Main Orchestrator|discovery_can_start=1`

Result: pass

## Unhappy Path Results

### Codex as Main Agent With Unresolvable Claude Command

Command:

```bash
PM_LEAD_MODEL_CLAUDE_MCP_LIST_OVERRIDE='claude-code enabled' \
PM_LEAD_MODEL_CLAUDE_COMMAND_OVERRIDE='definitely-missing-claude-command' \
skills/pm/scripts/pm-command.sh plan gate --route default --lead-model codex-main --state-file <temp>
```

Observed:

- `PLAN_ROUTE_BLOCKED|route=default|selected_profile=codex-main`
- `reason=claude_code_mcp_command_not_executable`
- `fallback_offer=1|fallback_profile=full-codex|fallback_label=Full Codex Orchestration`
- `next_action=ask_user_for_full_codex_fallback|discovery_can_start=0`

Result: pass

### Codex as Main Agent Fallback Accepted

Command:

```bash
PM_LEAD_MODEL_FORCE_CLAUDE_MCP_UNAVAILABLE=1 \
skills/pm/scripts/pm-command.sh plan gate --route default --lead-model full-codex --state-file <temp>
```

Observed:

- `PLAN_ROUTE_READY|route=default|selected_profile=full-codex|selected_label=Full Codex Orchestration|discovery_can_start=1`

Result: pass

### Codex as Main Agent Fallback Declined

Observed:

- repeating the blocked `codex-main` case leaves the workflow at `discovery_can_start=0`
- no automatic continuation occurs without explicit fallback acceptance

Result: pass

### Claude as Main Orchestrator With Claude Unavailable

Command:

```bash
PM_LEAD_MODEL_FORCE_CLAUDE_MCP_UNAVAILABLE=1 \
skills/pm/scripts/pm-command.sh plan gate --route default --lead-model claude-main --state-file <temp>
```

Observed:

- `PLAN_ROUTE_BLOCKED|route=default|selected_profile=claude-main`
- `reason=claude_code_mcp_unavailable`
- `fallback_offer=0`
- `next_action=fix_claude_mcp_or_choose_supported_mode|discovery_can_start=0`

Result: pass

## Regression Checks

### Non-Interactive PATH Executability

Command:

```bash
command -v claude || true
printf 'PATH=%s\n' "$PATH"
```

Observed:

- `command -v claude` returned no result
- runtime `PATH` was `/Users/d/.volta/bin:/Users/d/.volta/bin:/Users/d/.codex/tmp/arg0/codex-arg0PjbcG7:/usr/bin:/bin:/usr/sbin:/sbin:/Applications/Codex.app/Contents/Resources`
- despite that stripped runtime PATH, both `codex-main` and `claude-main` happy-path gate checks returned `PLAN_ROUTE_READY`

Result: pass

### Claude Context-Pack Contract

Commands:

```bash
skills/pm/scripts/pm-command.sh claude-contract validate-context --context-file <valid> --role researcher
skills/pm/scripts/pm-command.sh claude-contract validate-context --context-file <invalid> --role researcher
skills/pm/scripts/pm-command.sh claude-contract evaluate-response --response-file <context_request> --session-id smoke-session --role researcher
skills/pm/scripts/pm-command.sh claude-contract evaluate-response --response-file <complete> --session-id smoke-session --role researcher
```

Observed:

- valid pack emitted `CLAUDE_CONTEXT_VALID`
- invalid pack emitted `CLAUDE_CONTEXT_INVALID` with missing required fields
- handshake request emitted `CLAUDE_HANDSHAKE|status=context_needed`
- completed response emitted `CLAUDE_HANDSHAKE|status=complete`

Result: pass

## Outcome

The three orchestration modes, the codex-main fallback path, the claude-main fail-fast path, the config-backed Claude executability check, and the Claude context-pack helpers all behaved as designed.
