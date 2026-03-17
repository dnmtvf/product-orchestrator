#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT_DIR/skills/pm/scripts/pm-command.sh"

fail() {
  echo "[test-pm-command] FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if ! grep -Fq "$needle" <<<"$haystack"; then
    fail "expected output to contain: $needle"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if grep -Fq "$needle" <<<"$haystack"; then
    fail "expected output to not contain: $needle"
  fi
}

extract_prefixed_value() {
  local haystack="$1"
  local prefix="$2"
  local line

  while IFS= read -r line; do
    case "$line" in
      "$prefix"*)
        printf '%s' "${line#"$prefix"}"
        return 0
        ;;
    esac
  done <<<"$haystack"

  return 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool missing: $1"
}

write_codex_config() {
  local config_path="$1"
  local model="$2"
  local reasoning_effort="$3"
  local extra_config="${4:-}"

  mkdir -p "$(dirname "$config_path")"
  cat >"$config_path" <<EOF
model = "$model"
model_reasoning_effort = "$reasoning_effort"

[mcp_servers.claude-code]
command = "claude"
args = ["mcp", "serve"]
$extra_config
EOF
}

write_prd() {
  local prd_path="$1"
  shift

  mkdir -p "$(dirname "$prd_path")"

  {
    cat <<'EOF'
# PRD

## 1. Title, Date, Owner
- Title: Self-update test

## 9. Coverage Evidence
EOF

    for version in "$@"; do
      printf -- '- Reviewed Codex %s\n' "$version"
    done

    cat <<'EOF'

## 14. Open Questions
EOF
  } >"$prd_path"
}

require_tool git
require_tool jq
require_tool bash
require_tool diff

echo "[test-pm-command] case: routing policy blocks Claude-dependent phases instead of degrading them"
routing_contract="$(cat "$ROOT_DIR/skills/pm/agents/model-routing.yaml")"
assert_contains "$routing_contract" 'default_profile: codex-main'
assert_contains "$routing_contract" 'full-codex: Full Codex Orchestration'
assert_contains "$routing_contract" 'codex-main: Codex as Main Agent'
assert_contains "$routing_contract" 'claude-main: Claude as Main Orchestrator'
assert_contains "$routing_contract" 'model: gpt-5.4'
assert_contains "$routing_contract" 'reasoning_effort: xhigh'
assert_contains "$routing_contract" 'phase_entry_requirements:'
assert_contains "$routing_contract" 'runtime_failure_policy:'
assert_contains "$routing_contract" 'do not auto-fallback blocked Claude-dependent phases to codex-native'
assert_not_contains "$routing_contract" 'fallback_when:'
assert_not_contains "$routing_contract" 'fallback_runtime: codex-native'

echo "[test-pm-command] case: workflow instruction copies stay synchronized"
if ! diff -u "$ROOT_DIR/instructions/pm_workflow.md" "$ROOT_DIR/.config/opencode/instructions/pm_workflow.md" >/dev/null; then
  fail "workflow instruction files drifted; sync instructions/pm_workflow.md and .config/opencode/instructions/pm_workflow.md"
fi

echo "[test-pm-command] case: active docs distinguish source and installed helper paths"
helper_path_contracts="$(
  cat \
    "$ROOT_DIR/README.md" \
    "$ROOT_DIR/SETUP.md" \
    "$ROOT_DIR/docs/INSTALL_INJECT_WORKFLOW.md" \
    "$ROOT_DIR/docs/INSTALL_SUBMODULE_WORKFLOW.md" \
    "$ROOT_DIR/docs/MCP_PREREQUISITES.md" \
    "$ROOT_DIR/instructions/pm_workflow.md" \
    "$ROOT_DIR/.config/opencode/instructions/pm_workflow.md" \
    "$ROOT_DIR/skills/pm/SKILL.md" \
    "$ROOT_DIR/skills/pm-implement/SKILL.md"
)"
assert_contains "$helper_path_contracts" './skills/pm/scripts/pm-command.sh'
assert_contains "$helper_path_contracts" './.codex/skills/pm/scripts/pm-command.sh'
assert_contains "$helper_path_contracts" './.claude/skills/pm/scripts/pm-command.sh'

echo "[test-pm-command] case: live PM contracts forbid degraded fallback after a blocked gate"
live_contracts="$(
  cat \
    "$ROOT_DIR/README.md" \
    "$ROOT_DIR/docs/MCP_PREREQUISITES.md" \
    "$ROOT_DIR/instructions/pm_workflow.md" \
    "$ROOT_DIR/skills/pm/SKILL.md" \
    "$ROOT_DIR/skills/pm-discovery/SKILL.md" \
    "$ROOT_DIR/skills/pm-implement/SKILL.md" \
    "$ROOT_DIR/skills/pm/references/smoke-test-planner.md" \
    "$ROOT_DIR/skills/pm/references/alternative-pm.md" \
    "$ROOT_DIR/skills/pm/references/researcher.md" \
    "$ROOT_DIR/skills/pm-discovery/references/smoke-test-planner.md" \
    "$ROOT_DIR/skills/pm-discovery/references/alternative-pm.md" \
    "$ROOT_DIR/skills/pm-implement/references/jazz.md" \
    "$ROOT_DIR/skills/pm-implement/references/team-lead.md"
)"
assert_contains "$live_contracts" 'The helper gate output is authoritative. If it returns `PLAN_ROUTE_BLOCKED` or `discovery_can_start=0`, do not invoke Discovery or any downstream phase.'
assert_contains "$live_contracts" 'Discovery may start only if the preceding `plan gate` returned `PLAN_ROUTE_READY` and `discovery_can_start=1`.'
assert_contains "$live_contracts" 'Do not auto-fallback to `codex-native` inside Discovery. Treat this as a critical phase block and return control to PM.'
assert_contains "$live_contracts" 'Do not auto-fallback to `codex-native` inside `codex-main` or `claude-main`. Surface a critical phase block and return control to PM.'
assert_contains "$live_contracts" 'Do not auto-fallback to `codex-native` inside implementation or review phases when a required Claude-routed role is unavailable.'
assert_not_contains "$live_contracts" 'fall back to codex-native instead of repeating install instructions'
assert_not_contains "$live_contracts" 'workflow continues with explicit remediation warnings'

TMPDIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT
export HOME="$TMPDIR/home"
mkdir -p "$HOME"
write_codex_config "$HOME/.codex/config.toml" "gpt-global" "medium"

FAKE_CLAUDE_BIN="$TMPDIR/fake-claude-bin"
mkdir -p "$FAKE_CLAUDE_BIN"
cat >"$FAKE_CLAUDE_BIN/claude" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$FAKE_CLAUDE_BIN/claude"

cd "$TMPDIR"
git init -q
git config user.name "pm-test"
git config user.email "pm-test@example.com"
printf 'seed\n' > README.md
git add README.md
git commit -q -m "init"

echo "[test-pm-command] case: help output"
help_out="$("$HELPER" help)"
assert_contains "$help_out" '$pm help'
assert_contains "$help_out" '$pm plan: <feature request>'
assert_contains "$help_out" '$pm lead-model show|set|reset'
assert_contains "$help_out" '$pm telemetry init-db|log-step|query-task|query-run'
assert_contains "$help_out" '$pm self-update'
assert_contains "$help_out" 'Self-update policy:'
assert_contains "$help_out" 'Filter non-pipeline changes and emit integration-plan suggestions'
assert_contains "$help_out" 'Lead-model options are:'
assert_contains "$help_out" 'Full Codex Orchestration'
assert_contains "$help_out" 'Codex as Main Agent'
assert_contains "$help_out" 'Claude as Main Orchestrator'
assert_contains "$help_out" 'Codex-native orchestrator roles are pinned to `gpt-5.4` with `xhigh` reasoning effort'
assert_contains "$help_out" 'If the plan gate reports `PLAN_ROUTE_BLOCKED` or `discovery_can_start=0`, do not enter Discovery or any downstream phase'
assert_contains "$help_out" 'If a required Claude-routed role later fails at runtime (for example `no supported agent type`), block the current phase and return control to PM with reason-specific remediation'
assert_contains "$help_out" 'Issue reporting policy:'
assert_contains "$help_out" 'End each phase with a Phase Error Summary'
assert_contains "$help_out" '$pm claude-contract validate-context|evaluate-response'
assert_contains "$help_out" 'Claude delegation contract:'
assert_contains "$help_out" 'claude-contract run-loop'
assert_contains "$help_out" 'Claude availability requires both a healthy `codex mcp list` entry and an executable configured command in the actual PM runtime'
assert_not_contains "$help_out" 'workflow falls back to codex-native'
assert_not_contains "$help_out" 'Claude-mapped roles fallback to codex-native'

CLAUDE_CONTEXT_FILE="$TMPDIR/claude-context-valid.json"
cat >"$CLAUDE_CONTEXT_FILE" <<'EOF'
{
  "feature_objective": "Validate notification delivery latency requirements for sprint release",
  "prd_context": "docs/prd/2026-03-04--notifications.md#acceptance",
  "task_id": "BEAD-42",
  "acceptance_criteria": [
    "p95 under 200ms",
    "Retry policy documented"
  ],
  "implementation_status": "Task in progress with API handler completed",
  "changed_files": [
    "src/notifications/service.ts",
    "src/notifications/service.test.ts"
  ],
  "constraints": [
    "No schema changes",
    "Backward-compatible API"
  ],
  "evidence": {
    "tests": [
      "npm test -- notifications"
    ]
  },
  "clarifying_instruction": "If you have missing or ambiguous context, ask specific clarifying questions before final recommendations."
}
EOF

echo "[test-pm-command] case: claude-contract validate-context accepts complete context pack"
contract_valid_out="$("$HELPER" claude-contract validate-context --context-file "$CLAUDE_CONTEXT_FILE" --role task_verification)"
assert_contains "$contract_valid_out" 'CLAUDE_CONTEXT_VALID|role=task_verification'
assert_contains "$contract_valid_out" 'required_fields=feature_objective,prd_context,task_id,acceptance_criteria,implementation_status,changed_files,constraints,evidence,clarifying_instruction'

CLAUDE_CONTEXT_INVALID_FILE="$TMPDIR/claude-context-invalid.json"
cat >"$CLAUDE_CONTEXT_INVALID_FILE" <<'EOF'
{
  "feature_objective": "Assess deployment rollback safety",
  "prd_context": "docs/prd/2026-03-04--rollback.md",
  "task_id": "BEAD-77",
  "acceptance_criteria": "Rollback completes in under 2 minutes",
  "implementation_status": "Pending code review",
  "changed_files": ["src/deploy/rollback.ts"],
  "evidence": "No logs yet",
  "clarifying_instruction": "If you have missing or ambiguous context, ask specific clarifying questions before final recommendations."
}
EOF

echo "[test-pm-command] case: claude-contract validate-context rejects incomplete context pack"
if contract_invalid_out="$("$HELPER" claude-contract validate-context --context-file "$CLAUDE_CONTEXT_INVALID_FILE" --role task_verification 2>&1)"; then
  fail "claude-contract validate-context unexpectedly succeeded with missing required fields"
fi
assert_contains "$contract_invalid_out" 'CLAUDE_CONTEXT_INVALID|role=task_verification'
assert_contains "$contract_invalid_out" 'missing_fields=constraints'

CLAUDE_RESPONSE_NEEDS_CONTEXT="$TMPDIR/claude-response-needs-context.txt"
cat >"$CLAUDE_RESPONSE_NEEDS_CONTEXT" <<'EOF'
CONTEXT_REQUEST|needed_fields=constraints,evidence|questions=1) Provide p95 latency budget;2) Provide failing test logs for retry path
EOF

echo "[test-pm-command] case: claude-contract evaluate-response detects missing-context handshake"
if handshake_needed_out="$("$HELPER" claude-contract evaluate-response --response-file "$CLAUDE_RESPONSE_NEEDS_CONTEXT" --session-id sess-123 --role task_verification 2>&1)"; then
  fail "claude-contract evaluate-response unexpectedly treated context request as complete"
fi
assert_contains "$handshake_needed_out" 'CLAUDE_HANDSHAKE|status=context_needed|role=task_verification|session_id=sess-123'
assert_contains "$handshake_needed_out" 'needed_fields=constraints,evidence'

CLAUDE_RESPONSE_COMPLETE="$TMPDIR/claude-response-complete.txt"
cat >"$CLAUDE_RESPONSE_COMPLETE" <<'EOF'
Review complete. No additional context required.
EOF

echo "[test-pm-command] case: claude-contract evaluate-response accepts completion response"
handshake_complete_out="$("$HELPER" claude-contract evaluate-response --response-file "$CLAUDE_RESPONSE_COMPLETE" --session-id sess-123 --role task_verification)"
assert_contains "$handshake_complete_out" 'CLAUDE_HANDSHAKE|status=complete|role=task_verification|session_id=sess-123'

echo "[test-pm-command] case: claude-contract run-loop reports ready when no response is supplied"
loop_ready_out="$("$HELPER" claude-contract run-loop --context-file "$CLAUDE_CONTEXT_FILE" --session-id sess-123 --role task_verification)"
assert_contains "$loop_ready_out" 'CLAUDE_CONTEXT_VALID|role=task_verification'
assert_contains "$loop_ready_out" 'CLAUDE_LOOP|status=ready|role=task_verification|session_id=sess-123|next_action=invoke_claude_mcp'

echo "[test-pm-command] case: claude-contract run-loop reports awaiting_context on unresolved handshake"
if loop_waiting_out="$("$HELPER" claude-contract run-loop --context-file "$CLAUDE_CONTEXT_FILE" --response-file "$CLAUDE_RESPONSE_NEEDS_CONTEXT" --session-id sess-123 --role task_verification 2>&1)"; then
  fail "claude-contract run-loop unexpectedly completed when context was still needed"
fi
assert_contains "$loop_waiting_out" 'CLAUDE_HANDSHAKE|status=context_needed|role=task_verification|session_id=sess-123'
assert_contains "$loop_waiting_out" 'CLAUDE_LOOP|status=awaiting_context|role=task_verification|session_id=sess-123|round=1|next_action=collect_and_continue'

echo "[test-pm-command] case: claude-contract run-loop completes multi-step response chain"
loop_complete_out="$("$HELPER" claude-contract run-loop --context-file "$CLAUDE_CONTEXT_FILE" --response-file "$CLAUDE_RESPONSE_NEEDS_CONTEXT" --response-file "$CLAUDE_RESPONSE_COMPLETE" --session-id sess-123 --role task_verification)"
assert_contains "$loop_complete_out" 'CLAUDE_LOOP|status=context_requested|role=task_verification|session_id=sess-123|round=1|next_action=continue_session'
assert_contains "$loop_complete_out" 'CLAUDE_HANDSHAKE|status=complete|role=task_verification|session_id=sess-123'
assert_contains "$loop_complete_out" 'CLAUDE_LOOP|status=complete|role=task_verification|session_id=sess-123|round=2|responses_seen=2'

CLAUDE_WRAPPER_PROMPT_FILE="$TMPDIR/claude-wrapper-prompt.md"
CLAUDE_WRAPPER_RESPONSE_UNSUPPORTED="$TMPDIR/claude-wrapper-response-unsupported.txt"
cat >"$CLAUDE_WRAPPER_RESPONSE_UNSUPPORTED" <<'EOF'
Agent type 'general-purpose' not found
EOF

echo "[test-pm-command] case: claude-wrapper prepare validates context and renders internal prompt"
wrapper_prepare_out="$("$HELPER" claude-wrapper prepare --context-file "$CLAUDE_CONTEXT_FILE" --prompt-file "$CLAUDE_WRAPPER_PROMPT_FILE" --objective "review retry policy and latency evidence" --role jazz_reviewer)"
assert_contains "$wrapper_prepare_out" 'CLAUDE_CONTEXT_VALID|role=jazz_reviewer'
assert_contains "$wrapper_prepare_out" 'CLAUDE_WRAPPER_READY|status=ready|role=jazz_reviewer|session_id=claude-wrapper-'
[ -f "$CLAUDE_WRAPPER_PROMPT_FILE" ] || fail "claude-wrapper prepare did not create prompt file"
wrapper_prompt_contents="$(cat "$CLAUDE_WRAPPER_PROMPT_FILE")"
assert_contains "$wrapper_prompt_contents" 'use agent swarm for review retry policy and latency evidence'
assert_contains "$wrapper_prompt_contents" 'You are an internal Claude MCP adapter for the PM orchestrator.'
assert_contains "$wrapper_prompt_contents" '[Role: jazz_reviewer]'
assert_contains "$wrapper_prompt_contents" 'Wrapper runtime: claude-code-mcp'

echo "[test-pm-command] case: claude-wrapper evaluate normalizes completion"
wrapper_complete_out="$("$HELPER" claude-wrapper evaluate --context-file "$CLAUDE_CONTEXT_FILE" --response-file "$CLAUDE_RESPONSE_COMPLETE" --session-id wrap-123 --role jazz_reviewer)"
assert_contains "$wrapper_complete_out" 'CLAUDE_HANDSHAKE|status=complete|role=jazz_reviewer|session_id=wrap-123'
assert_contains "$wrapper_complete_out" 'CLAUDE_WRAPPER_RESULT|status=complete|role=jazz_reviewer|session_id=wrap-123|runtime=claude-code-mcp'
assert_contains "$wrapper_complete_out" 'next_action=return_to_parent'

echo "[test-pm-command] case: claude-wrapper evaluate normalizes missing-context handshakes"
if wrapper_context_needed_out="$("$HELPER" claude-wrapper evaluate --context-file "$CLAUDE_CONTEXT_FILE" --response-file "$CLAUDE_RESPONSE_NEEDS_CONTEXT" --session-id wrap-123 --role jazz_reviewer 2>&1)"; then
  fail "claude-wrapper evaluate unexpectedly completed when context was still needed"
fi
assert_contains "$wrapper_context_needed_out" 'CLAUDE_HANDSHAKE|status=context_needed|role=jazz_reviewer|session_id=wrap-123'
assert_contains "$wrapper_context_needed_out" 'CLAUDE_WRAPPER_RESULT|status=context_needed|role=jazz_reviewer|session_id=wrap-123|runtime=claude-code-mcp'
assert_contains "$wrapper_context_needed_out" 'needed_fields=constraints,evidence'
assert_contains "$wrapper_context_needed_out" 'next_action=continue_session'

echo "[test-pm-command] case: claude-wrapper evaluate reports unsupported launcher failures"
if wrapper_runtime_error_out="$("$HELPER" claude-wrapper evaluate --context-file "$CLAUDE_CONTEXT_FILE" --response-file "$CLAUDE_WRAPPER_RESPONSE_UNSUPPORTED" --session-id wrap-123 --role jazz_reviewer 2>&1)"; then
  fail "claude-wrapper evaluate unexpectedly completed on unsupported launcher output"
fi
assert_contains "$wrapper_runtime_error_out" 'CLAUDE_WRAPPER_RESULT|status=runtime_error|error=unsupported_launcher|role=jazz_reviewer|session_id=wrap-123|runtime=claude-code-mcp'
assert_contains "$wrapper_runtime_error_out" "detail=Agent type 'general-purpose' not found"
assert_contains "$wrapper_runtime_error_out" 'next_action=return_to_parent'

echo "[test-pm-command] case: claude-wrapper run reports ready before Claude invocation"
wrapper_run_ready_out="$("$HELPER" claude-wrapper run --context-file "$CLAUDE_CONTEXT_FILE" --prompt-file "$CLAUDE_WRAPPER_PROMPT_FILE" --objective "review retry policy and latency evidence" --session-id wrap-run-1 --role jazz_reviewer)"
assert_contains "$wrapper_run_ready_out" 'CLAUDE_WRAPPER_READY|status=ready|role=jazz_reviewer|session_id=wrap-run-1|runtime=claude-code-mcp'

echo "[test-pm-command] case: claude-wrapper run completes after a direct Claude response"
wrapper_run_complete_out="$("$HELPER" claude-wrapper run --context-file "$CLAUDE_CONTEXT_FILE" --prompt-file "$CLAUDE_WRAPPER_PROMPT_FILE" --objective "review retry policy and latency evidence" --response-file "$CLAUDE_RESPONSE_COMPLETE" --session-id wrap-run-2 --role jazz_reviewer)"
assert_contains "$wrapper_run_complete_out" 'CLAUDE_WRAPPER_READY|status=ready|role=jazz_reviewer|session_id=wrap-run-2|runtime=claude-code-mcp'
assert_contains "$wrapper_run_complete_out" 'CLAUDE_WRAPPER_RESULT|status=complete|role=jazz_reviewer|session_id=wrap-run-2|runtime=claude-code-mcp'

echo "[test-pm-command] case: claude-wrapper run preserves same-session continuation state"
wrapper_run_context_out="$("$HELPER" claude-wrapper run --context-file "$CLAUDE_CONTEXT_FILE" --prompt-file "$CLAUDE_WRAPPER_PROMPT_FILE" --objective "review retry policy and latency evidence" --response-file "$CLAUDE_RESPONSE_NEEDS_CONTEXT" --response-file "$CLAUDE_RESPONSE_COMPLETE" --session-id wrap-run-3 --role jazz_reviewer)"
assert_contains "$wrapper_run_context_out" 'CLAUDE_WRAPPER_RESULT|status=context_needed|role=jazz_reviewer|session_id=wrap-run-3|runtime=claude-code-mcp'
assert_contains "$wrapper_run_context_out" 'CLAUDE_WRAPPER_RESULT|status=context_requested|role=jazz_reviewer|session_id=wrap-run-3|runtime=claude-code-mcp|round=1|next_action=continue_session'
assert_contains "$wrapper_run_context_out" 'CLAUDE_WRAPPER_RESULT|status=complete|role=jazz_reviewer|session_id=wrap-run-3|runtime=claude-code-mcp'

echo "[test-pm-command] case: claude-wrapper run exits on unsupported launcher output"
if wrapper_run_unsupported_out="$("$HELPER" claude-wrapper run --context-file "$CLAUDE_CONTEXT_FILE" --prompt-file "$CLAUDE_WRAPPER_PROMPT_FILE" --objective "review retry policy and latency evidence" --response-file "$CLAUDE_WRAPPER_RESPONSE_UNSUPPORTED" --session-id wrap-run-4 --role jazz_reviewer 2>&1)"; then
  fail "claude-wrapper run unexpectedly completed on unsupported launcher output"
fi
assert_contains "$wrapper_run_unsupported_out" 'CLAUDE_WRAPPER_READY|status=ready|role=jazz_reviewer|session_id=wrap-run-4|runtime=claude-code-mcp'
assert_contains "$wrapper_run_unsupported_out" 'CLAUDE_WRAPPER_RESULT|status=runtime_error|error=unsupported_launcher|role=jazz_reviewer|session_id=wrap-run-4|runtime=claude-code-mcp'

LEAD_MODEL_STATE_FILE="$TMPDIR/.codex/pm-lead-model-state.json"

echo "[test-pm-command] case: lead-model state bootstraps to codex-main"
lead_show="$("$HELPER" lead-model show --state-file "$LEAD_MODEL_STATE_FILE")"
assert_contains "$lead_show" 'LEAD_MODEL_STATE|action=show|profile=codex-main|label=Codex as Main Agent|codex_model=gpt-5.4|codex_reasoning_effort=xhigh'
jq -e '.selected_profile == "codex-main"' "$LEAD_MODEL_STATE_FILE" >/dev/null || fail "lead-model default profile should be codex-main"

echo "[test-pm-command] case: legacy lead-model state migrates to canonical claude-main profile"
cat >"$LEAD_MODEL_STATE_FILE" <<'EOF'
{
  "schema_version": 1,
  "selected_profile": "claude-first",
  "selected_label": "Claude Opus 4.6 Thinking",
  "updated_at": "2026-03-16T00:00:00Z",
  "last_selected_by": "legacy_test"
}
EOF
lead_show_legacy="$("$HELPER" lead-model show --state-file "$LEAD_MODEL_STATE_FILE")"
assert_contains "$lead_show_legacy" 'LEAD_MODEL_STATE|action=show|profile=claude-main|label=Claude as Main Orchestrator|codex_model=gpt-5.4|codex_reasoning_effort=xhigh'
jq -e '.selected_profile == "claude-main"' "$LEAD_MODEL_STATE_FILE" >/dev/null || fail "legacy lead-model state did not migrate to claude-main"

echo "[test-pm-command] case: plan gate on default route emits persisted claude-main routing"
plan_gate_default="$(
  PM_LEAD_MODEL_FORCE_CODEX_MCP_AVAILABLE=1 \
  "$HELPER" plan gate --route default --state-file "$LEAD_MODEL_STATE_FILE"
)"
assert_contains "$plan_gate_default" 'LEAD_MODEL_GATE|route=default'
assert_contains "$plan_gate_default" 'options=Full Codex Orchestration;Codex as Main Agent;Claude as Main Orchestrator'
assert_contains "$plan_gate_default" 'selected_profile=claude-main'
assert_contains "$plan_gate_default" 'codex_model=gpt-5.4|codex_reasoning_effort=xhigh'
assert_contains "$plan_gate_default" 'ROUTING_PROFILE|route=default|profile=claude-main|selection_source=persisted_state|main_runtime=claude-native|main_model=<unpinned>|main_reasoning_effort=<unpinned>|fallback_active=0'
assert_contains "$plan_gate_default" 'ROUTING_ROLE|role=pm_beads_plan_handoff|class=main|runtime=claude-native|model=<unpinned>|reasoning_effort=<unpinned>|agent_type=default'
assert_contains "$plan_gate_default" 'ROUTING_ROLE|role=senior_engineer|class=sub|runtime=codex-worker-mcp|model=<unpinned>|reasoning_effort=<unpinned>|agent_type=explorer'
assert_contains "$plan_gate_default" 'ROUTING_ROLE|role=task_verification|class=sub|runtime=claude-native|model=<unpinned>|reasoning_effort=<unpinned>|agent_type=default'
assert_contains "$plan_gate_default" 'PLAN_ROUTE_READY|route=default|selected_profile=claude-main|selected_label=Claude as Main Orchestrator|selection_source=persisted_state|discovery_can_start=1'

echo "[test-pm-command] case: full-codex route is ready without Claude availability"
plan_gate_full_codex="$(
  PM_LEAD_MODEL_FORCE_CLAUDE_MCP_UNAVAILABLE=1 \
  "$HELPER" plan gate --route big-feature --lead-model full-codex --state-file "$LEAD_MODEL_STATE_FILE"
)"
assert_contains "$plan_gate_full_codex" 'LEAD_MODEL_GATE|route=big-feature'
assert_contains "$plan_gate_full_codex" 'selected_profile=full-codex'
assert_contains "$plan_gate_full_codex" 'ROUTING_PROFILE|route=big-feature|profile=full-codex|selection_source=explicit_override|main_runtime=codex-native|main_model=gpt-5.4|main_reasoning_effort=xhigh|fallback_active=0'
assert_contains "$plan_gate_full_codex" 'ROUTING_ROLE|role=librarian|class=sub|runtime=codex-native|model=gpt-5.4|reasoning_effort=xhigh|agent_type=default'
assert_contains "$plan_gate_full_codex" 'ROUTING_ROLE|role=task_verification|class=sub|runtime=codex-native|model=gpt-5.4|reasoning_effort=xhigh|agent_type=default'
assert_contains "$plan_gate_full_codex" 'PLAN_ROUTE_READY|route=big-feature|selected_profile=full-codex|selected_label=Full Codex Orchestration|selection_source=explicit_override|discovery_can_start=1'
jq -e '.selected_profile == "full-codex"' "$LEAD_MODEL_STATE_FILE" >/dev/null || fail "plan gate override did not persist full-codex profile"

echo "[test-pm-command] case: codex-main route stays pinned and Claude-routed when Claude is available"
plan_gate_codex_main="$(
  PM_LEAD_MODEL_FORCE_CLAUDE_MCP_AVAILABLE=1 \
  "$HELPER" plan gate --route default --lead-model codex-main --state-file "$LEAD_MODEL_STATE_FILE"
)"
assert_contains "$plan_gate_codex_main" 'selected_profile=codex-main'
assert_contains "$plan_gate_codex_main" 'ROUTING_PROFILE|route=default|profile=codex-main|selection_source=explicit_override|main_runtime=codex-native|main_model=gpt-5.4|main_reasoning_effort=xhigh|fallback_active=0'
assert_contains "$plan_gate_codex_main" 'ROUTING_ROLE|role=project_manager|class=main|runtime=codex-native|model=gpt-5.4|reasoning_effort=xhigh|agent_type=default'
assert_contains "$plan_gate_codex_main" 'ROUTING_ROLE|role=librarian|class=sub|runtime=claude-code-mcp|model=<unpinned>|reasoning_effort=<unpinned>|agent_type=default'
assert_contains "$plan_gate_codex_main" 'ROUTING_ROLE|role=task_verification|class=sub|runtime=codex-native|model=gpt-5.4|reasoning_effort=xhigh|agent_type=default'
assert_contains "$plan_gate_codex_main" 'PLAN_ROUTE_READY|route=default|selected_profile=codex-main|selected_label=Codex as Main Agent|selection_source=explicit_override|discovery_can_start=1'

echo "[test-pm-command] case: Conductor Codex session auto-selects codex-main"
conductor_codex_out="$(
  CODEX_THREAD_ID='codex-session' \
  CODEX_INTERNAL_ORIGINATOR_OVERRIDE='Codex Desktop' \
  PM_LEAD_MODEL_FORCE_CLAUDE_MCP_AVAILABLE=1 \
  PM_PLAN_GATE_WORKSPACE_PATH_OVERRIDE='/tmp/conductor/workspaces/product-orchestrator/main' \
  "$HELPER" plan gate --route default --state-file "$LEAD_MODEL_STATE_FILE"
)"
assert_contains "$conductor_codex_out" 'LEAD_MODEL_GATE|route=default'
assert_contains "$conductor_codex_out" 'selected_profile=codex-main'
assert_contains "$conductor_codex_out" 'selection_source=conductor_auto'
assert_contains "$conductor_codex_out" 'PLAN_ROUTE_READY|route=default|selected_profile=codex-main|selected_label=Codex as Main Agent|selection_source=conductor_auto|discovery_can_start=1'

echo "[test-pm-command] case: Conductor Claude session auto-selects claude-main"
conductor_claude_out="$(
  env -u CODEX_THREAD_ID -u CODEX_INTERNAL_ORIGINATOR_OVERRIDE \
    PM_LEAD_MODEL_FORCE_CODEX_MCP_AVAILABLE=1 \
    PM_PLAN_GATE_WORKSPACE_PATH_OVERRIDE='/tmp/conductor/workspaces/product-orchestrator/main' \
    "$HELPER" plan gate --route default --state-file "$LEAD_MODEL_STATE_FILE"
)"
assert_contains "$conductor_claude_out" 'LEAD_MODEL_GATE|route=default'
assert_contains "$conductor_claude_out" 'selected_profile=claude-main'
assert_contains "$conductor_claude_out" 'selection_source=conductor_auto'
assert_contains "$conductor_claude_out" 'PLAN_ROUTE_READY|route=default|selected_profile=claude-main|selected_label=Claude as Main Orchestrator|selection_source=conductor_auto|discovery_can_start=1'

echo "[test-pm-command] case: explicit override beats Conductor auto-selection"
conductor_override_out="$(
  CODEX_THREAD_ID='codex-session' \
  CODEX_INTERNAL_ORIGINATOR_OVERRIDE='Codex Desktop' \
  PM_PLAN_GATE_WORKSPACE_PATH_OVERRIDE='/tmp/conductor/workspaces/product-orchestrator/main' \
  PM_LEAD_MODEL_FORCE_CLAUDE_MCP_UNAVAILABLE=1 \
  "$HELPER" plan gate --route default --lead-model full-codex --state-file "$LEAD_MODEL_STATE_FILE"
)"
assert_contains "$conductor_override_out" 'selected_profile=full-codex'
assert_contains "$conductor_override_out" 'selection_source=explicit_override'
assert_contains "$conductor_override_out" 'PLAN_ROUTE_READY|route=default|selected_profile=full-codex|selected_label=Full Codex Orchestration|selection_source=explicit_override|discovery_can_start=1'

echo "[test-pm-command] case: lead-model reset is idempotent"
lead_reset_one="$("$HELPER" lead-model reset --state-file "$LEAD_MODEL_STATE_FILE")"
lead_reset_two="$("$HELPER" lead-model reset --state-file "$LEAD_MODEL_STATE_FILE")"
assert_contains "$lead_reset_one" 'LEAD_MODEL_STATE|action=reset|profile=codex-main|label=Codex as Main Agent|codex_model=gpt-5.4|codex_reasoning_effort=xhigh'
assert_contains "$lead_reset_two" 'LEAD_MODEL_STATE|action=reset|profile=codex-main|label=Codex as Main Agent|codex_model=gpt-5.4|codex_reasoning_effort=xhigh'

echo "[test-pm-command] case: invalid lead-model and route inputs fail"
if "$HELPER" lead-model set --state-file "$LEAD_MODEL_STATE_FILE" --profile invalid >/dev/null 2>&1; then
  fail "lead-model set unexpectedly accepted invalid profile"
fi
if "$HELPER" plan gate --route default --lead-model invalid --state-file "$LEAD_MODEL_STATE_FILE" >/dev/null 2>&1; then
  fail "plan gate unexpectedly accepted invalid lead-model override"
fi
if "$HELPER" plan gate --route invalid --state-file "$LEAD_MODEL_STATE_FILE" >/dev/null 2>&1; then
  fail "plan gate unexpectedly accepted invalid route"
fi

echo "[test-pm-command] case: codex-main blocks and offers full-codex fallback when Claude command is not executable"
blocked_codex_main_file="$TMPDIR/plan-gate-blocked-codex-main.out"
if PM_LEAD_MODEL_CLAUDE_MCP_LIST_OVERRIDE='claude-code enabled' \
  PM_LEAD_MODEL_CLAUDE_COMMAND_OVERRIDE='definitely-missing-claude-command' \
  "$HELPER" plan gate --route default --lead-model codex-main --state-file "$LEAD_MODEL_STATE_FILE" >"$blocked_codex_main_file" 2>&1; then
  fail "codex-main unexpectedly proceeded when Claude command was not executable"
fi
blocked_codex_main_out="$(cat "$blocked_codex_main_file")"
assert_contains "$blocked_codex_main_out" 'LEAD_MODEL_GATE|route=default'
assert_contains "$blocked_codex_main_out" 'PLAN_ROUTE_BLOCKED|route=default|selected_profile=codex-main|selected_label=Codex as Main Agent|selection_source=explicit_override|reason=claude_code_mcp_command_not_executable'
assert_contains "$blocked_codex_main_out" 'fallback_offer=1|fallback_profile=full-codex|fallback_label=Full Codex Orchestration|next_action=ask_user_for_full_codex_fallback|discovery_can_start=0'
assert_not_contains "$blocked_codex_main_out" 'PLAN_ROUTE_READY|'

echo "[test-pm-command] case: mcp_servers.claude-code.env PATH makes codex-main gate pass"
write_codex_config "$HOME/.codex/config.toml" "gpt-global" "medium" "

[mcp_servers.claude-code.env]
PATH = \"$FAKE_CLAUDE_BIN\"
"
config_path_pass_out="$(
  PM_LEAD_MODEL_CLAUDE_MCP_LIST_OVERRIDE='claude-code enabled' \
  "$HELPER" plan gate --route default --lead-model codex-main --state-file "$LEAD_MODEL_STATE_FILE"
)"
assert_contains "$config_path_pass_out" 'PLAN_ROUTE_READY|route=default|selected_profile=codex-main|selected_label=Codex as Main Agent|selection_source=explicit_override'
assert_not_contains "$config_path_pass_out" 'PLAN_ROUTE_BLOCKED|'

echo "[test-pm-command] case: shell_environment_policy.set PATH also makes codex-main gate pass"
write_codex_config "$HOME/.codex/config.toml" "gpt-global" "medium" "

[shell_environment_policy.set]
PATH = \"$FAKE_CLAUDE_BIN\"
"
shell_env_path_pass_out="$(
  PM_LEAD_MODEL_CLAUDE_MCP_LIST_OVERRIDE='claude-code enabled' \
  "$HELPER" plan gate --route default --lead-model codex-main --state-file "$LEAD_MODEL_STATE_FILE"
)"
assert_contains "$shell_env_path_pass_out" 'PLAN_ROUTE_READY|route=default|selected_profile=codex-main|selected_label=Codex as Main Agent|selection_source=explicit_override'
assert_not_contains "$shell_env_path_pass_out" 'PLAN_ROUTE_BLOCKED|'

echo "[test-pm-command] case: claude-main blocks without fallback when codex-worker MCP is unavailable"
blocked_claude_main_file="$TMPDIR/plan-gate-blocked-claude-main.out"
if PM_LEAD_MODEL_FORCE_CODEX_MCP_UNAVAILABLE=1 \
  "$HELPER" plan gate --route default --lead-model claude-main --state-file "$LEAD_MODEL_STATE_FILE" >"$blocked_claude_main_file" 2>&1; then
  fail "claude-main unexpectedly proceeded when codex-worker MCP was unavailable"
fi
blocked_claude_main_out="$(cat "$blocked_claude_main_file")"
assert_contains "$blocked_claude_main_out" 'PLAN_ROUTE_BLOCKED|route=default|selected_profile=claude-main|selected_label=Claude as Main Orchestrator|selection_source=explicit_override|reason=codex_worker_mcp_unavailable'
assert_contains "$blocked_claude_main_out" 'fallback_offer=0|fallback_profile=|fallback_label=|next_action=fix_codex_worker_mcp_or_choose_supported_mode|discovery_can_start=0'
assert_not_contains "$blocked_claude_main_out" 'PLAN_ROUTE_READY|'

echo "[test-pm-command] case: claude-main blocks when codex command is not executable"
blocked_claude_command_file="$TMPDIR/plan-gate-blocked-claude-command.out"
if PM_LEAD_MODEL_CODEX_MCP_LIST_OVERRIDE='codex-worker enabled' \
  PM_LEAD_MODEL_CODEX_COMMAND_OVERRIDE='definitely-missing-codex-command' \
  "$HELPER" plan gate --route default --lead-model claude-main --state-file "$LEAD_MODEL_STATE_FILE" >"$blocked_claude_command_file" 2>&1; then
  fail "claude-main unexpectedly proceeded when codex command was not executable"
fi
blocked_claude_command_out="$(cat "$blocked_claude_command_file")"
assert_contains "$blocked_claude_command_out" 'PLAN_ROUTE_BLOCKED|route=default|selected_profile=claude-main|selected_label=Claude as Main Orchestrator|selection_source=explicit_override|reason=codex_worker_command_not_executable'
assert_contains "$blocked_claude_command_out" 'next_action=fix_codex_worker_mcp_or_choose_supported_mode|discovery_can_start=0'

echo "[test-pm-command] case: lead-model reset repairs corrupt state file"
printf 'not-json\n' >"$LEAD_MODEL_STATE_FILE"
repair_out="$("$HELPER" lead-model reset --state-file "$LEAD_MODEL_STATE_FILE")"
assert_contains "$repair_out" 'LEAD_MODEL_STATE|action=reset|profile=codex-main|label=Codex as Main Agent|codex_model=gpt-5.4|codex_reasoning_effort=xhigh'
jq -e '.selected_profile == "codex-main"' "$LEAD_MODEL_STATE_FILE" >/dev/null || fail "lead-model reset did not repair corrupt state"

STATE_FILE="$TMPDIR/.codex/pm-self-update-state.json"
PRD_PATH="$TMPDIR/docs/prd/self-update.md"

BOOTSTRAP_CHANGELOG=$'Codex CLI 0.104.0'
BOOTSTRAP_RELEASE_URL='https://github.com/openai/codex/releases/tag/rust-v0.104.0'
BOOTSTRAP_NPM='{"latest":"0.104.0","alpha":"0.104.0-alpha.1"}'

echo "[test-pm-command] case: bootstrap processed baseline"
bootstrap_check="$(
  PM_SELF_UPDATE_CHANGELOG_PAYLOAD="$BOOTSTRAP_CHANGELOG" \
  PM_SELF_UPDATE_RELEASE_REDIRECT_URL="$BOOTSTRAP_RELEASE_URL" \
  PM_SELF_UPDATE_NPM_TAGS_PAYLOAD="$BOOTSTRAP_NPM" \
  "$HELPER" self-update check
)"
assert_contains "$bootstrap_check" 'UPDATE_AVAILABLE|'
assert_contains "$bootstrap_check" 'latest_version=0.104.0'

write_prd "$PRD_PATH" '0.104.0'
"$HELPER" self-update complete --approval approved --prd-approval approved --beads-approval approved --prd-path "$PRD_PATH" >/dev/null
jq -e '.latest_processed_codex_version == "0.104.0"' "$STATE_FILE" >/dev/null || fail "bootstrap processed version not written"

DUAL_CHANGELOG=$'Codex CLI 0.105.0
Codex CLI 0.106.0-alpha.1
Codex CLI 0.106.0-alpha.2'
DUAL_RELEASE_URL='https://github.com/openai/codex/releases/tag/rust-v0.105.0'
DUAL_NPM='{"latest":"0.105.0","alpha":"0.106.0-alpha.2"}'

echo "[test-pm-command] case: prerelease toggle can disable prerelease-sensitive path"
stable_only_out="$(
  PM_SELF_UPDATE_INCLUDE_PRERELEASE=0 \
  PM_SELF_UPDATE_CHANGELOG_PAYLOAD="$DUAL_CHANGELOG" \
  PM_SELF_UPDATE_RELEASE_REDIRECT_URL="$DUAL_RELEASE_URL" \
  PM_SELF_UPDATE_NPM_TAGS_PAYLOAD="$DUAL_NPM" \
  "$HELPER" self-update check
)"
assert_contains "$stable_only_out" 'UPDATE_AVAILABLE|'
assert_contains "$stable_only_out" 'latest_version=0.105.0'
assert_contains "$stable_only_out" 'pending_count=1'
assert_contains "$stable_only_out" 'PENDING_BATCH|versions=0.105.0'
jq -e '.pending_codex_versions == ["0.105.0"]' "$STATE_FILE" >/dev/null || fail "stable-only pending batch incorrect"

echo "[test-pm-command] case: ignore non-CLI semver noise in changelog payload"
NOISY_CHANGELOG=$'Codex docs shell 4.5.58
Codex CLI 0.105.0
Codex CLI 0.106.0-alpha.2'
noisy_out="$(
  PM_SELF_UPDATE_INCLUDE_PRERELEASE=1 \
  PM_SELF_UPDATE_CHANGELOG_PAYLOAD="$NOISY_CHANGELOG" \
  PM_SELF_UPDATE_RELEASE_REDIRECT_URL="$DUAL_RELEASE_URL" \
  PM_SELF_UPDATE_NPM_TAGS_PAYLOAD="$DUAL_NPM" \
  "$HELPER" self-update check
)"
assert_contains "$noisy_out" 'latest_version=0.106.0-alpha.2'
if grep -Fq 'latest_version=4.5.58' <<<"$noisy_out"; then
  fail "non-CLI semver noise incorrectly selected as Codex version"
fi
jq -e '(.pending_codex_versions | index("4.5.58")) == null' "$STATE_FILE" >/dev/null || fail "noisy semver leaked into pending batch"

echo "[test-pm-command] case: dual-track batch detection and plan trigger"
dual_out="$(
  PM_SELF_UPDATE_INCLUDE_PRERELEASE=1 \
  PM_SELF_UPDATE_CHANGELOG_PAYLOAD="$DUAL_CHANGELOG" \
  PM_SELF_UPDATE_RELEASE_REDIRECT_URL="$DUAL_RELEASE_URL" \
  PM_SELF_UPDATE_NPM_TAGS_PAYLOAD="$DUAL_NPM" \
  "$HELPER" self-update check
)"
assert_contains "$dual_out" 'UPDATE_AVAILABLE|'
assert_contains "$dual_out" 'latest_version=0.106.0-alpha.2'
assert_contains "$dual_out" 'pending_count=3'
assert_contains "$dual_out" 'PENDING_BATCH|versions=0.105.0,0.106.0-alpha.1,0.106.0-alpha.2'
assert_contains "$dual_out" 'RELEVANCE_SUMMARY|total_entries=3|relevant_entries=3|ignored_entries=0'
assert_contains "$dual_out" 'PLAN_TRIGGER|/pm plan:'
assert_contains "$dual_out" 'PLAN_CONTEXT|detected_version=0.106.0-alpha.2|pending_count=3|relevant_count=3|ignored_count=0|'

relevant_json="$(extract_prefixed_value "$dual_out" 'RELEVANT_CHANGES_JSON|')" || fail "missing RELEVANT_CHANGES_JSON output"
ignored_json="$(extract_prefixed_value "$dual_out" 'IGNORED_CHANGES_JSON|')" || fail "missing IGNORED_CHANGES_JSON output"
plan_json="$(extract_prefixed_value "$dual_out" 'INTEGRATION_PLAN_JSON|')" || fail "missing INTEGRATION_PLAN_JSON output"
printf '%s' "$relevant_json" | jq -e 'length == 3 and .[0].version != null and .[0].change != null' >/dev/null || fail "unexpected relevant changes JSON payload"
printf '%s' "$ignored_json" | jq -e 'length == 0' >/dev/null || fail "unexpected ignored changes JSON payload"
printf '%s' "$plan_json" | jq -e 'length == 3 and .[0].integration != null and .[0].expected_improvement != null' >/dev/null || fail "unexpected integration plan JSON payload"

jq -e '.pending_codex_versions == ["0.105.0","0.106.0-alpha.1","0.106.0-alpha.2"]' "$STATE_FILE" >/dev/null || fail "dual-track pending batch incorrect"
jq -e '.pending_batch.to_version == "0.106.0-alpha.2"' "$STATE_FILE" >/dev/null || fail "pending batch boundary incorrect"
jq -e '.pending_batch.entry_analysis.total_entries == 3 and .pending_batch.entry_analysis.relevant_entries == 3 and .pending_batch.entry_analysis.ignored_entries == 0' "$STATE_FILE" >/dev/null || fail "pending batch entry analysis missing"

echo "[test-pm-command] case: filter non-pipeline changelog entries"
FILTER_CHANGELOG=$'Codex CLI 0.107.0-alpha.1 approval-gate workflow update\nCodex CLI 0.107.0-alpha.1 marketing website color refresh'
filter_out="$(\
  PM_SELF_UPDATE_INCLUDE_PRERELEASE=1 \
  PM_SELF_UPDATE_CHANGELOG_PAYLOAD="$FILTER_CHANGELOG" \
  PM_SELF_UPDATE_RELEASE_REDIRECT_URL='https://github.com/openai/codex/releases/tag/rust-v0.107.0-alpha.1' \
  PM_SELF_UPDATE_NPM_TAGS_PAYLOAD='{"latest":"0.107.0-alpha.1","alpha":"0.107.0-alpha.1"}' \
  "$HELPER" self-update check\
)"
assert_contains "$filter_out" 'UPDATE_AVAILABLE|'
assert_contains "$filter_out" 'latest_version=0.107.0-alpha.1'
assert_contains "$filter_out" 'RELEVANCE_SUMMARY|total_entries=2|relevant_entries=1|ignored_entries=1'

filter_relevant_json="$(extract_prefixed_value "$filter_out" 'RELEVANT_CHANGES_JSON|')" || fail "missing filtered RELEVANT_CHANGES_JSON output"
filter_ignored_json="$(extract_prefixed_value "$filter_out" 'IGNORED_CHANGES_JSON|')" || fail "missing filtered IGNORED_CHANGES_JSON output"
filter_plan_json="$(extract_prefixed_value "$filter_out" 'INTEGRATION_PLAN_JSON|')" || fail "missing filtered INTEGRATION_PLAN_JSON output"
printf '%s' "$filter_relevant_json" | jq -e 'length == 1 and .[0].reason == "matches_pipeline_relevance_policy"' >/dev/null || fail "filtered relevant JSON incorrect"
printf '%s' "$filter_ignored_json" | jq -e 'length == 1 and .[0].reason == "filtered_non_pipeline_change"' >/dev/null || fail "filtered ignored JSON incorrect"
printf '%s' "$filter_plan_json" | jq -e 'length == 1 and .[0].integration != null and .[0].expected_improvement != null' >/dev/null || fail "filtered integration plan JSON incorrect"
jq -e '.pending_batch.entry_analysis.total_entries == 2 and .pending_batch.entry_analysis.relevant_entries == 1 and .pending_batch.entry_analysis.ignored_entries == 1' "$STATE_FILE" >/dev/null || fail "filtered entry analysis not persisted"

echo "[test-pm-command] case: restore dual-track pending batch for completion tests"
dual_restore_out="$(\
  PM_SELF_UPDATE_INCLUDE_PRERELEASE=1 \
  PM_SELF_UPDATE_CHANGELOG_PAYLOAD="$DUAL_CHANGELOG" \
  PM_SELF_UPDATE_RELEASE_REDIRECT_URL="$DUAL_RELEASE_URL" \
  PM_SELF_UPDATE_NPM_TAGS_PAYLOAD="$DUAL_NPM" \
  "$HELPER" self-update check\
)"
assert_contains "$dual_restore_out" 'UPDATE_AVAILABLE|'
jq -e '.pending_codex_versions == ["0.105.0","0.106.0-alpha.1","0.106.0-alpha.2"]' "$STATE_FILE" >/dev/null || fail "failed to restore dual-track pending batch"

echo "[test-pm-command] case: complete rejects incomplete PRD evidence"
write_prd "$PRD_PATH" '0.105.0' '0.106.0-alpha.2'
if "$HELPER" self-update complete --approval approved --prd-approval approved --beads-approval approved --prd-path "$PRD_PATH" >/dev/null 2>&1; then
  fail "complete unexpectedly succeeded with incomplete PRD coverage"
fi

echo "[test-pm-command] case: complete rejects invalid approval token"
if "$HELPER" self-update complete --approval nope --prd-approval approved --beads-approval approved --prd-path "$PRD_PATH" >/dev/null 2>&1; then
  fail "complete unexpectedly succeeded with invalid approval token"
fi

write_prd "$PRD_PATH" '0.105.0' '0.106.0-alpha.1' '0.106.0-alpha.2'

echo "[test-pm-command] case: dry-run does not mutate state"
dry_run_out="$("$HELPER" self-update complete --approval approved --prd-approval approved --beads-approval approved --prd-path "$PRD_PATH" --dry-run)"
assert_contains "$dry_run_out" 'CHECKPOINT_DRY_RUN|'
jq -e '.latest_processed_codex_version == "0.104.0"' "$STATE_FILE" >/dev/null || fail "dry-run mutated processed version"
jq -e '.pending_codex_versions == ["0.105.0","0.106.0-alpha.1","0.106.0-alpha.2"]' "$STATE_FILE" >/dev/null || fail "dry-run mutated pending batch"

echo "[test-pm-command] case: complete updates state and creates checkpoint commit"
printf 'keep-staged\n' > "$TMPDIR/unrelated.txt"
git add "$TMPDIR/unrelated.txt"

complete_out="$("$HELPER" self-update complete --approval approved --prd-approval approved --beads-approval approved --prd-path "$PRD_PATH")"
assert_contains "$complete_out" 'CHECKPOINT_CREATED|'
assert_contains "$complete_out" 'COMPLETE|latest_processed_codex_version=0.106.0-alpha.2|pending_count=3'

jq -e '.latest_processed_codex_version == "0.106.0-alpha.2"' "$STATE_FILE" >/dev/null || fail "processed version not updated"
jq -e '.pending_codex_versions == []' "$STATE_FILE" >/dev/null || fail "pending batch not cleared"

latest_commit_msg="$(git log -1 --pretty=%s)"
assert_contains "$latest_commit_msg" 'chore(pm-self-update): checkpoint codex version 0.106.0-alpha.2'

commit_files="$(git show --name-only --pretty=format: HEAD)"
assert_contains "$commit_files" '.codex/pm-self-update-state.json'
if grep -Fq 'unrelated.txt' <<<"$commit_files"; then
  fail "checkpoint commit included unrelated staged file"
fi

cached_after_commit="$(git diff --cached --name-only)"
assert_contains "$cached_after_commit" 'unrelated.txt'

echo "[test-pm-command] case: source mismatch reports in non-strict mode"
MISMATCH_CHANGELOG=$'Codex CLI 0.107.0-alpha.1'
MISMATCH_RELEASE='https://github.com/openai/codex/releases/tag/rust-v9.9.9'
MISMATCH_NPM='{"latest":"0.107.0-alpha.1","alpha":"0.107.0-alpha.1"}'

mismatch_out="$(
  PM_SELF_UPDATE_CHANGELOG_PAYLOAD="$MISMATCH_CHANGELOG" \
  PM_SELF_UPDATE_RELEASE_REDIRECT_URL="$MISMATCH_RELEASE" \
  PM_SELF_UPDATE_NPM_TAGS_PAYLOAD="$MISMATCH_NPM" \
  "$HELPER" self-update check
)"
assert_contains "$mismatch_out" 'UPDATE_AVAILABLE|'
assert_contains "$mismatch_out" 'SOURCE_MISMATCH|flags=release_not_in_changelog:9.9.9'

state_before_strict="$(cat "$STATE_FILE")"
echo "[test-pm-command] case: strict mismatch mode fails closed"
if PM_SELF_UPDATE_STRICT_MISMATCH=1 \
   PM_SELF_UPDATE_CHANGELOG_PAYLOAD="$MISMATCH_CHANGELOG" \
   PM_SELF_UPDATE_RELEASE_REDIRECT_URL="$MISMATCH_RELEASE" \
   PM_SELF_UPDATE_NPM_TAGS_PAYLOAD="$MISMATCH_NPM" \
   "$HELPER" self-update check >/dev/null 2>&1; then
  fail "strict mismatch unexpectedly succeeded"
fi
state_after_strict="$(cat "$STATE_FILE")"
if [ "$state_before_strict" != "$state_after_strict" ]; then
  fail "strict mismatch mutated state"
fi

echo "[test-pm-command] case: malformed changelog payload fails closed"
state_before_malformed="$(cat "$STATE_FILE")"
if PM_SELF_UPDATE_CHANGELOG_PAYLOAD='not-a-codex-version' "$HELPER" self-update check >/dev/null 2>&1; then
  fail "malformed changelog unexpectedly succeeded"
fi
state_after_malformed="$(cat "$STATE_FILE")"
if [ "$state_before_malformed" != "$state_after_malformed" ]; then
  fail "malformed changelog mutated state"
fi

echo "[test-pm-command] case: re-check is explicit no-op when up-to-date"
noop_out="$(
  PM_SELF_UPDATE_CHANGELOG_PAYLOAD='Codex CLI 0.106.0-alpha.2' \
  PM_SELF_UPDATE_RELEASE_REDIRECT_URL='https://github.com/openai/codex/releases/tag/rust-v0.106.0-alpha.2' \
  PM_SELF_UPDATE_NPM_TAGS_PAYLOAD='{"latest":"0.106.0-alpha.2","alpha":"0.106.0-alpha.2"}' \
  "$HELPER" self-update check
)"
assert_contains "$noop_out" 'NO_OP|'
assert_contains "$noop_out" 'latest_version=0.106.0-alpha.2'
assert_contains "$noop_out" 'RELEVANCE_SUMMARY|total_entries=0|relevant_entries=0|ignored_entries=0'
noop_plan_json="$(extract_prefixed_value "$noop_out" 'INTEGRATION_PLAN_JSON|')" || fail "missing no-op integration plan output"
printf '%s' "$noop_plan_json" | jq -e 'length == 0' >/dev/null || fail "no-op integration plan should be empty"

echo "[test-pm-command] PASS"
