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

write_claude_settings() {
  local settings_path="$1"
  local model="$2"
  local effort_level="$3"

  mkdir -p "$(dirname "$settings_path")"
  cat >"$settings_path" <<EOF
{
  "model": "$model",
  "effortLevel": "$effort_level"
}
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
assert_contains "$routing_contract" 'default_mode: dynamic-cross-runtime'
assert_contains "$routing_contract" 'dynamic-cross-runtime: Dynamic Cross-Runtime'
assert_contains "$routing_contract" 'main-runtime-only: Main Runtime Only'
assert_contains "$routing_contract" 'fail_closed: true'
assert_contains "$routing_contract" 'dynamic-cross-runtime under codex blocks until claude-code is healthy and executable'
assert_contains "$routing_contract" 'dynamic-cross-runtime under claude blocks until codex-worker is healthy and codex is executable'
assert_contains "$routing_contract" 'phase_entry_requirements:'
assert_contains "$routing_contract" 'runtime_failure_policy:'
assert_contains "$routing_contract" 'do not auto-fallback blocked routed-runtime phases to the main runtime'
assert_not_contains "$routing_contract" 'default_profile:'
assert_not_contains "$routing_contract" 'lead_model_options:'

echo "[test-pm-command] case: workflow docs use the single live workflow file contract"
single_workflow_contracts="$(
  cat \
    "$ROOT_DIR/AGENTS.md" \
    "$ROOT_DIR/README.md" \
    "$ROOT_DIR/docs/INSTALL_INJECT_WORKFLOW.md" \
    "$ROOT_DIR/docs/INSTALL_SUBMODULE_WORKFLOW.md" \
    "$ROOT_DIR/instructions/pm_workflow.md"
)"
assert_not_contains "$single_workflow_contracts" '.config/opencode/instructions/pm_workflow.md'

echo "[test-pm-command] case: active docs distinguish source and installed helper paths"
helper_path_contracts="$(
  cat \
    "$ROOT_DIR/README.md" \
    "$ROOT_DIR/SETUP.md" \
    "$ROOT_DIR/docs/INSTALL_INJECT_WORKFLOW.md" \
    "$ROOT_DIR/docs/INSTALL_SUBMODULE_WORKFLOW.md" \
    "$ROOT_DIR/docs/MCP_PREREQUISITES.md" \
    "$ROOT_DIR/instructions/pm_workflow.md" \
    "$ROOT_DIR/skills/pm/SKILL.md" \
    "$ROOT_DIR/skills/pm-implement/SKILL.md"
)"
assert_contains "$helper_path_contracts" './skills/pm/scripts/pm-command.sh'
assert_contains "$helper_path_contracts" './.codex/skills/pm/scripts/pm-command.sh'
assert_contains "$helper_path_contracts" './.claude/skills/pm/scripts/pm-command.sh'
assert_not_contains "$helper_path_contracts" '.config/opencode/instructions/pm_workflow.md'

echo "[test-pm-command] case: standalone Codex custom agents are documented at the verified agents path"
user_agent_contracts="$(
  cat \
    "$ROOT_DIR/README.md" \
    "$ROOT_DIR/SETUP.md"
)"
assert_contains "$user_agent_contracts" '~/.codex/agents'
assert_contains "$user_agent_contracts" 'install-user-codex-agents.sh'

echo "[test-pm-command] case: live PM contracts forbid degraded fallback after a blocked gate"
live_contracts="$(
  cat \
    "$ROOT_DIR/README.md" \
    "$ROOT_DIR/docs/MCP_PREREQUISITES.md" \
    "$ROOT_DIR/instructions/pm_workflow.md" \
    "$ROOT_DIR/skills/pm/SKILL.md" \
    "$ROOT_DIR/skills/pm-create-prd/SKILL.md" \
    "$ROOT_DIR/skills/pm-beads-plan/SKILL.md" \
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
assert_contains "$live_contracts" 'Interactive `/pm plan` and `/pm plan big feature` runs must ask this question on every new planning invocation before Discovery starts.'
assert_contains "$live_contracts" 'Interactive PM orchestration must use persisted execution-mode state only as the default suggested choice, then pass the user’s explicit selection to the helper gate.'
assert_contains "$live_contracts" 'Do not auto-fallback to `codex-native` inside Discovery. Treat this as a critical phase block and return control to PM.'
assert_contains "$live_contracts" 'Do not auto-fallback to the main runtime inside `dynamic-cross-runtime`. Surface a critical phase block and return control to PM.'
assert_contains "$live_contracts" 'Do not auto-fallback to `codex-native` inside implementation or review phases when a required Claude-routed role is unavailable.'
assert_contains "$live_contracts" 'must launch the required orchestrator subagents by default whenever the current runtime/tool policy permits delegation'
assert_contains "$live_contracts" 'Launch discovery subagents by default whenever the current runtime/tool policy permits delegation.'
assert_contains "$live_contracts" 'Required implementation, verification, review, and QA subagents are default behavior whenever the current runtime/tool policy permits delegation.'
assert_contains "$live_contracts" '/pm self-check'
assert_contains "$live_contracts" 'fail the whole self-check run when Claude registration, executability, or session health is unhealthy'
assert_contains "$live_contracts" 'if helper emits `SELF_CHECK_HEALER_READY`, spawn a generic `default` outer healer'
assert_contains "$live_contracts" 'healer may only package repair work through the normal PM flow and must not bypass approvals'
assert_not_contains "$live_contracts" 'user explicitly requested delegation'
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
write_claude_settings "$HOME/.claude/settings.json" "opus" "high"

FAKE_CLAUDE_BIN="$TMPDIR/fake-claude-bin"
mkdir -p "$FAKE_CLAUDE_BIN"
cat >"$FAKE_CLAUDE_BIN/claude" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "mcp" ] && [ "${2:-}" = "list" ]; then
  case "${FAKE_CLAUDE_MCP_MODE:-ok}" in
    ok)
      if [ "${FAKE_CLAUDE_MCP_ECHO_TIMEOUT:-0}" = "1" ]; then
        printf 'claude-code enabled timeout=%s\n' "${MCP_TIMEOUT:-<unset>}"
      else
        printf 'claude-code enabled\n'
      fi
      exit 0
      ;;
    partial-hang)
      printf 'Checking MCP server health...\n'
      sleep "${FAKE_CLAUDE_MCP_SLEEP_SECONDS:-20}"
      if [ "${FAKE_CLAUDE_MCP_ECHO_TIMEOUT:-0}" = "1" ]; then
        printf 'timeout=%s\n' "${MCP_TIMEOUT:-<unset>}"
      fi
      exit 0
      ;;
    nonzero)
      printf 'claude snapshot failed\n' >&2
      exit "${FAKE_CLAUDE_MCP_EXIT_CODE:-42}"
      ;;
  esac
fi
exit 0
EOF
chmod +x "$FAKE_CLAUDE_BIN/claude"

FAKE_CODEX_BIN="$TMPDIR/fake-codex-bin"
mkdir -p "$FAKE_CODEX_BIN"
cat >"$FAKE_CODEX_BIN/codex" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "mcp" ] && [ "${2:-}" = "list" ]; then
  case "${FAKE_CODEX_MCP_MODE:-ok}" in
    ok)
      printf 'codex-worker enabled\n'
      exit 0
      ;;
    partial-hang)
      printf 'Checking Codex MCP server health...\n'
      sleep "${FAKE_CODEX_MCP_SLEEP_SECONDS:-7}"
      exit 0
      ;;
    nonzero)
      printf 'codex snapshot failed\n' >&2
      exit "${FAKE_CODEX_MCP_EXIT_CODE:-17}"
      ;;
  esac
fi
exit 0
EOF
chmod +x "$FAKE_CODEX_BIN/codex"

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
assert_contains "$help_out" '$pm execution-mode show|set|reset'
assert_contains "$help_out" '$pm self-check'
assert_contains "$help_out" '$pm telemetry init-db|log-step|query-task|query-run'
assert_contains "$help_out" '$pm self-update'
assert_contains "$help_out" 'Self-update policy:'
assert_contains "$help_out" 'Self-check policy:'
assert_contains "$help_out" 'Deterministic fixture suite with verbose artifact capture under `.codex/self-check-runs`'
assert_contains "$help_out" 'Fail whole run when Claude registration, command executability, or session usability is unhealthy'
assert_contains "$help_out" 'Outer healer may package repairs through normal PM flow only after self-check emits healer-ready artifacts'
assert_contains "$help_out" 'Filter non-pipeline changes and emit integration-plan suggestions'
assert_contains "$help_out" 'Execution-mode options are:'
assert_contains "$help_out" 'Dynamic Cross-Runtime'
assert_contains "$help_out" 'Main Runtime Only'
assert_contains "$help_out" 'Interactive `/pm` plan runs should ask for execution mode on every new planning invocation and pass an explicit `--mode` to the helper gate'
assert_contains "$help_out" 'Selected execution mode persists in .codex; direct helper usage may reuse it by default when no `--mode` is supplied'
assert_contains "$help_out" 'Outer runtime is inferred fresh from the running Codex or Claude session on every plan gate'
assert_contains "$help_out" 'If the plan gate reports `PLAN_ROUTE_BLOCKED` or `discovery_can_start=0`, do not enter Discovery or any downstream phase'
assert_contains "$help_out" 'If the outer runtime cannot be positively identified, fail closed, emit `RUNTIME_DETECTION_ERROR`, and persist the run outcome in telemetry'
assert_contains "$help_out" 'If a required routed MCP path later fails at runtime (for example `no supported agent type`), block the current phase and return control to PM with reason-specific remediation'
assert_contains "$help_out" 'Issue reporting policy:'
assert_contains "$help_out" 'End each phase with a Phase Error Summary'
assert_contains "$help_out" '$pm claude-contract validate-context|evaluate-response'
assert_contains "$help_out" 'Claude delegation contract:'
assert_contains "$help_out" 'claude-contract run-loop'
assert_contains "$help_out" 'Codex secondary-runtime usage inside Claude is permitted only through codex-worker MCP'
assert_not_contains "$help_out" 'workflow falls back to codex-native'
assert_not_contains "$help_out" 'Claude-mapped roles fallback to codex-native'

echo "[test-pm-command] case: self-check fixtures catalog"
self_check_fixtures_out="$("$HELPER" self-check fixtures)"
assert_contains "$self_check_fixtures_out" 'SELF_CHECK_FIXTURES|suite_version=pm-self-check-v1|count=5'
assert_contains "$self_check_fixtures_out" 'SELF_CHECK_FIXTURE|id=happy-path|description=Healthy deterministic orchestration harness run.'
assert_contains "$self_check_fixtures_out" 'SELF_CHECK_FIXTURE|id=spawn-failure|description=Injected subagent spawn failure for healer aggregation.'
assert_contains "$self_check_fixtures_out" 'SELF_CHECK_FIXTURE|id=response-timeout|description=Injected child response timeout/no-response path.'
assert_contains "$self_check_fixtures_out" 'SELF_CHECK_FIXTURE|id=context-needed|description=Injected missing-context response-contract path.'
assert_contains "$self_check_fixtures_out" 'SELF_CHECK_FIXTURE|id=unsupported-launcher|description=Injected unsupported-launcher Claude wrapper failure.'

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

SELF_CHECK_HAPPY_DIR="$TMPDIR/self-check-happy"
echo "[test-pm-command] case: self-check happy path produces clean summary and healer-ready bundle"
self_check_happy_out="$(
  PM_PLAN_GATE_RUNTIME_OVERRIDE=codex \
  PM_LEAD_MODEL_CLAUDE_MCP_LIST_OVERRIDE='claude-code enabled' \
  PM_LEAD_MODEL_CODEX_COMMAND_OVERRIDE="$FAKE_CODEX_BIN/codex" \
  PM_LEAD_MODEL_CLAUDE_COMMAND_OVERRIDE="$FAKE_CLAUDE_BIN/claude" \
  "$HELPER" self-check run --fixture-case happy-path --artifacts-dir "$SELF_CHECK_HAPPY_DIR" --mode main-runtime-only
)"
assert_contains "$self_check_happy_out" 'SELF_CHECK_RUN|'
assert_contains "$self_check_happy_out" 'execution_mode=main-runtime-only'
assert_contains "$self_check_happy_out" 'PLAN_ROUTE_READY|route=default|selected_mode=main-runtime-only'
assert_contains "$self_check_happy_out" 'SELF_CHECK_ARTIFACT_STATUS|'
assert_contains "$self_check_happy_out" 'SELF_CHECK_RESULT|status=clean|'
assert_contains "$self_check_happy_out" 'SELF_CHECK_HEALER_READY|status=ready|'
assert_not_contains "$self_check_happy_out" 'code=legacy_droid_worker_detected'
[ -f "$SELF_CHECK_HAPPY_DIR/summary.json" ] || fail "self-check happy path did not write summary.json"
[ -f "$SELF_CHECK_HAPPY_DIR/healer-context.json" ] || fail "self-check happy path did not write healer-context.json"
[ -f "$SELF_CHECK_HAPPY_DIR/healer-prompt.md" ] || fail "self-check happy path did not write healer-prompt.md"
jq -e '.status == "clean" and .fixture_case == "happy-path" and .execution_mode == "main-runtime-only" and .claude_health.registration == "passed" and .claude_health.executability == "passed" and .claude_health.session_usability == "passed" and .child_plan_gate.status == "ready" and .artifact_checks.codex_mcp_snapshot.status == "passed" and .artifact_checks.claude_mcp_snapshot.status == "passed" and (.artifact_checks.codex_mcp_snapshot.command_path | test("fake-codex-bin/codex$")) and .artifact_checks.codex_mcp_snapshot.timeout_seconds == 5 and .artifact_checks.claude_mcp_snapshot.command_source == "env:PM_LEAD_MODEL_CLAUDE_COMMAND_OVERRIDE" and .artifact_checks.claude_mcp_snapshot.timeout_seconds == 12 and .artifact_checks.claude_mcp_snapshot.command_env_overrides == "MCP_TIMEOUT=3000" and ([.events[] | select(.code == "legacy_droid_worker_detected")] | length) == 0' "$SELF_CHECK_HAPPY_DIR/summary.json" >/dev/null || fail "self-check happy path summary missing expected clean health or artifact fields"

SELF_CHECK_CLAUDE_BOUNDED_DIR="$TMPDIR/self-check-claude-bounded"
echo "[test-pm-command] case: self-check keeps clean status when Claude snapshot is slow but completes within bounded timeout"
self_check_claude_bounded_out="$(
  PM_PLAN_GATE_RUNTIME_OVERRIDE=codex \
  PM_LEAD_MODEL_CLAUDE_MCP_LIST_OVERRIDE='claude-code enabled' \
  PM_LEAD_MODEL_CODEX_COMMAND_OVERRIDE="$FAKE_CODEX_BIN/codex" \
  PM_LEAD_MODEL_CLAUDE_COMMAND_OVERRIDE="$FAKE_CLAUDE_BIN/claude" \
  FAKE_CLAUDE_MCP_MODE=partial-hang \
  FAKE_CLAUDE_MCP_SLEEP_SECONDS=7 \
  FAKE_CLAUDE_MCP_ECHO_TIMEOUT=1 \
  "$HELPER" self-check run --fixture-case happy-path --artifacts-dir "$SELF_CHECK_CLAUDE_BOUNDED_DIR" --mode main-runtime-only
)"
assert_contains "$self_check_claude_bounded_out" 'SELF_CHECK_RESULT|status=clean|'
jq -e '.status == "clean" and .artifact_checks.claude_mcp_snapshot.status == "passed" and .artifact_checks.claude_mcp_snapshot.timeout_seconds == 12 and .artifact_checks.claude_mcp_snapshot.command_env_overrides == "MCP_TIMEOUT=3000" and (.artifact_checks.claude_mcp_snapshot.partial_combined_output | test("timeout=3000"))' "$SELF_CHECK_CLAUDE_BOUNDED_DIR/summary.json" >/dev/null || fail "self-check bounded Claude snapshot summary missing expected timeout policy evidence"

LEGACY_DROID_CONFIG="$HOME/.claude.json"
cat >"$LEGACY_DROID_CONFIG" <<'EOF'
{
  "mcpServers": {
    "droid-worker": {
      "type": "stdio",
      "command": "/tmp/legacy-droid",
      "args": ["--mcp"],
      "env": {}
    }
  }
}
EOF
SELF_CHECK_LEGACY_DROID_DIR="$TMPDIR/self-check-legacy-droid"
echo "[test-pm-command] case: self-check surfaces legacy droid-worker as cleanup guidance without downgrading clean status"
self_check_legacy_droid_out="$(
  PM_PLAN_GATE_RUNTIME_OVERRIDE=codex \
  PM_LEAD_MODEL_CLAUDE_MCP_LIST_OVERRIDE='claude-code enabled' \
  PM_LEAD_MODEL_CODEX_COMMAND_OVERRIDE="$FAKE_CODEX_BIN/codex" \
  PM_LEAD_MODEL_CLAUDE_COMMAND_OVERRIDE="$FAKE_CLAUDE_BIN/claude" \
  "$HELPER" self-check run --fixture-case happy-path --artifacts-dir "$SELF_CHECK_LEGACY_DROID_DIR" --mode main-runtime-only
)"
assert_contains "$self_check_legacy_droid_out" 'code=legacy_droid_worker_detected'
jq -e '.status == "clean" and ([.events[] | select(.code == "legacy_droid_worker_detected")] | length) == 1' "$SELF_CHECK_LEGACY_DROID_DIR/summary.json" >/dev/null || fail "self-check legacy droid-worker summary missing expected cleanup event"
rm -f "$LEGACY_DROID_CONFIG"

SELF_CHECK_UNHEALTHY_DIR="$TMPDIR/self-check-unhealthy"
echo "[test-pm-command] case: self-check fails whole run when Claude health checks fail"
if self_check_unhealthy_out="$(
  PM_PLAN_GATE_RUNTIME_OVERRIDE=codex \
  PM_LEAD_MODEL_CODEX_COMMAND_OVERRIDE="$FAKE_CODEX_BIN/codex" \
  PM_LEAD_MODEL_FORCE_CLAUDE_MCP_UNAVAILABLE=1 \
  "$HELPER" self-check run --fixture-case happy-path --artifacts-dir "$SELF_CHECK_UNHEALTHY_DIR" --mode main-runtime-only 2>&1
)"; then
  fail "self-check unexpectedly succeeded when Claude health was unavailable"
fi
assert_contains "$self_check_unhealthy_out" 'SELF_CHECK_EVENT|'
assert_contains "$self_check_unhealthy_out" 'code=claude_code_mcp_unavailable'
assert_contains "$self_check_unhealthy_out" 'SELF_CHECK_RESULT|status=failed|'
assert_not_contains "$self_check_unhealthy_out" 'SELF_CHECK_HEALER_READY|'
[ -f "$SELF_CHECK_UNHEALTHY_DIR/summary.json" ] || fail "self-check unhealthy path did not write summary.json"
jq -e '.status == "failed" and .claude_health.executability == "failed" and .claude_health.session_usability == "failed" and .child_plan_gate.status == "not_started" and .artifact_checks.claude_mcp_snapshot.primary_code == "snapshot_runtime_unavailable"' "$SELF_CHECK_UNHEALTHY_DIR/summary.json" >/dev/null || fail "self-check unhealthy summary missing expected failed health or artifact runtime-unavailable fields"

SELF_CHECK_ARTIFACT_HANG_DIR="$TMPDIR/self-check-artifact-hang"
echo "[test-pm-command] case: self-check downgrades to issues_detected when Claude snapshot hangs after partial output"
self_check_artifact_hang_out="$(
  PM_PLAN_GATE_RUNTIME_OVERRIDE=codex \
  PM_LEAD_MODEL_CLAUDE_MCP_LIST_OVERRIDE='claude-code enabled' \
  PM_LEAD_MODEL_CODEX_COMMAND_OVERRIDE="$FAKE_CODEX_BIN/codex" \
  PM_LEAD_MODEL_CLAUDE_COMMAND_OVERRIDE="$FAKE_CLAUDE_BIN/claude" \
  FAKE_CLAUDE_MCP_MODE=partial-hang \
  "$HELPER" self-check run --fixture-case happy-path --artifacts-dir "$SELF_CHECK_ARTIFACT_HANG_DIR" --mode main-runtime-only
)"
assert_contains "$self_check_artifact_hang_out" 'SELF_CHECK_ARTIFACT_STATUS|'
assert_contains "$self_check_artifact_hang_out" 'primary_code=snapshot_command_hung'
assert_contains "$self_check_artifact_hang_out" 'issue_codes=snapshot_command_hung,snapshot_partial_output'
assert_contains "$self_check_artifact_hang_out" 'SELF_CHECK_RESULT|status=issues_detected|'
assert_contains "$self_check_artifact_hang_out" 'SELF_CHECK_REPAIR_BUNDLE|path='
assert_contains "$self_check_artifact_hang_out" 'SELF_CHECK_HEALER_READY|status=ready|'
jq -e '.status == "issues_detected" and .claude_health.session_usability == "passed" and .artifact_checks.claude_mcp_snapshot.primary_code == "snapshot_command_hung" and .artifact_checks.claude_mcp_snapshot.timeout_seconds == 12 and .artifact_checks.claude_mcp_snapshot.command_env_overrides == "MCP_TIMEOUT=3000" and (.artifact_checks.claude_mcp_snapshot.issue_codes | index("snapshot_partial_output")) != null and .artifact_checks.claude_mcp_snapshot.partial_combined_output == "Checking MCP server health..."' "$SELF_CHECK_ARTIFACT_HANG_DIR/summary.json" >/dev/null || fail "self-check artifact hang summary missing expected hang classification"

SELF_CHECK_ARTIFACT_NONZERO_DIR="$TMPDIR/self-check-artifact-nonzero"
echo "[test-pm-command] case: self-check downgrades to issues_detected when Claude snapshot exits nonzero"
self_check_artifact_nonzero_out="$(
  PM_PLAN_GATE_RUNTIME_OVERRIDE=codex \
  PM_LEAD_MODEL_CLAUDE_MCP_LIST_OVERRIDE='claude-code enabled' \
  PM_LEAD_MODEL_CODEX_COMMAND_OVERRIDE="$FAKE_CODEX_BIN/codex" \
  PM_LEAD_MODEL_CLAUDE_COMMAND_OVERRIDE="$FAKE_CLAUDE_BIN/claude" \
  FAKE_CLAUDE_MCP_MODE=nonzero \
  "$HELPER" self-check run --fixture-case happy-path --artifacts-dir "$SELF_CHECK_ARTIFACT_NONZERO_DIR" --mode main-runtime-only
)"
assert_contains "$self_check_artifact_nonzero_out" 'primary_code=snapshot_nonzero_exit'
assert_contains "$self_check_artifact_nonzero_out" 'SELF_CHECK_RESULT|status=issues_detected|'
jq -e '.status == "issues_detected" and .artifact_checks.claude_mcp_snapshot.primary_code == "snapshot_nonzero_exit" and .artifact_checks.claude_mcp_snapshot.exit_code == 42 and .artifact_checks.claude_mcp_snapshot.partial_stderr == "claude snapshot failed"' "$SELF_CHECK_ARTIFACT_NONZERO_DIR/summary.json" >/dev/null || fail "self-check artifact nonzero summary missing expected nonzero-exit classification"

SELF_CHECK_ARTIFACT_SKIP_DIR="$TMPDIR/self-check-artifact-skip"
echo "[test-pm-command] case: self-check surfaces skipped artifact capture as issues_detected"
self_check_artifact_skip_out="$(
  PM_PLAN_GATE_RUNTIME_OVERRIDE=codex \
  PM_LEAD_MODEL_CLAUDE_MCP_LIST_OVERRIDE='claude-code enabled' \
  PM_LEAD_MODEL_CODEX_COMMAND_OVERRIDE="$FAKE_CODEX_BIN/codex" \
  PM_LEAD_MODEL_CLAUDE_COMMAND_OVERRIDE="$FAKE_CLAUDE_BIN/claude" \
  PM_SELF_CHECK_SKIP_ARTIFACT_STEPS='claude_mcp_snapshot' \
  "$HELPER" self-check run --fixture-case happy-path --artifacts-dir "$SELF_CHECK_ARTIFACT_SKIP_DIR" --mode main-runtime-only
)"
assert_contains "$self_check_artifact_skip_out" 'primary_code=snapshot_capture_skipped'
assert_contains "$self_check_artifact_skip_out" 'SELF_CHECK_RESULT|status=issues_detected|'
jq -e '.status == "issues_detected" and .artifact_checks.claude_mcp_snapshot.primary_code == "snapshot_capture_skipped" and .artifact_checks.claude_mcp_snapshot.status == "skipped"' "$SELF_CHECK_ARTIFACT_SKIP_DIR/summary.json" >/dev/null || fail "self-check artifact skip summary missing expected skipped classification"

SELF_CHECK_ARTIFACT_TELEMETRY_DIR="$TMPDIR/self-check-artifact-telemetry"
echo "[test-pm-command] case: self-check surfaces incomplete artifact telemetry as issues_detected"
self_check_artifact_telemetry_out="$(
  PM_PLAN_GATE_RUNTIME_OVERRIDE=codex \
  PM_LEAD_MODEL_CLAUDE_MCP_LIST_OVERRIDE='claude-code enabled' \
  PM_LEAD_MODEL_CODEX_COMMAND_OVERRIDE="$FAKE_CODEX_BIN/codex" \
  PM_LEAD_MODEL_CLAUDE_COMMAND_OVERRIDE="$FAKE_CLAUDE_BIN/claude" \
  PM_SELF_CHECK_FORCE_TELEMETRY_INCOMPLETE_STEPS='claude_mcp_snapshot' \
  "$HELPER" self-check run --fixture-case happy-path --artifacts-dir "$SELF_CHECK_ARTIFACT_TELEMETRY_DIR" --mode main-runtime-only
)"
assert_contains "$self_check_artifact_telemetry_out" 'primary_code=snapshot_telemetry_incomplete'
assert_contains "$self_check_artifact_telemetry_out" 'SELF_CHECK_RESULT|status=issues_detected|'
jq -e '.status == "issues_detected" and .artifact_checks.claude_mcp_snapshot.primary_code == "snapshot_telemetry_incomplete" and .artifact_checks.claude_mcp_snapshot.telemetry_complete == false and .artifact_checks.claude_mcp_snapshot.path_override_source == "<none>"' "$SELF_CHECK_ARTIFACT_TELEMETRY_DIR/summary.json" >/dev/null || fail "self-check artifact telemetry summary missing expected telemetry-incomplete classification"

SELF_CHECK_UNSUPPORTED_DIR="$TMPDIR/self-check-unsupported"
echo "[test-pm-command] case: self-check unsupported-launcher fixture produces repair bundle"
self_check_unsupported_out="$(
  PM_PLAN_GATE_RUNTIME_OVERRIDE=codex \
  PM_LEAD_MODEL_CLAUDE_MCP_LIST_OVERRIDE='claude-code enabled' \
  PM_LEAD_MODEL_CODEX_COMMAND_OVERRIDE="$FAKE_CODEX_BIN/codex" \
  PM_LEAD_MODEL_CLAUDE_COMMAND_OVERRIDE="$FAKE_CLAUDE_BIN/claude" \
  "$HELPER" self-check run --fixture-case unsupported-launcher --artifacts-dir "$SELF_CHECK_UNSUPPORTED_DIR" --mode main-runtime-only
)"
assert_contains "$self_check_unsupported_out" 'SELF_CHECK_EVENT|'
assert_contains "$self_check_unsupported_out" 'code=unsupported_launcher'
assert_contains "$self_check_unsupported_out" 'SELF_CHECK_RESULT|status=issues_detected|'
assert_contains "$self_check_unsupported_out" 'SELF_CHECK_REPAIR_BUNDLE|path='
assert_contains "$self_check_unsupported_out" 'SELF_CHECK_HEALER_READY|status=ready|'
[ -f "$SELF_CHECK_UNSUPPORTED_DIR/summary.json" ] || fail "self-check unsupported fixture did not write summary.json"
jq -e '.status == "issues_detected" and .execution_mode == "main-runtime-only" and ([.findings[] | select(.code == "unsupported_launcher")] | length) == 1' "$SELF_CHECK_UNSUPPORTED_DIR/summary.json" >/dev/null || fail "self-check unsupported summary missing unsupported_launcher finding"

rm -f "$TMPDIR/.codex/pm-lead-model-state.json"
EXECUTION_MODE_STATE_FILE="$TMPDIR/.codex/pm-lead-model-state.json"

echo "[test-pm-command] case: execution-mode state bootstraps to dynamic-cross-runtime"
mode_show="$("$HELPER" execution-mode show --state-file "$EXECUTION_MODE_STATE_FILE")"
assert_contains "$mode_show" 'EXECUTION_MODE_STATE|action=show|mode=dynamic-cross-runtime|label=Dynamic Cross-Runtime'
jq -e '.selected_mode == "dynamic-cross-runtime"' "$EXECUTION_MODE_STATE_FILE" >/dev/null || fail "execution-mode default should be dynamic-cross-runtime"

echo "[test-pm-command] case: legacy lead-model state migrates to dynamic-cross-runtime execution mode"
cat >"$EXECUTION_MODE_STATE_FILE" <<'EOF'
{
  "schema_version": 1,
  "selected_profile": "claude-first",
  "selected_label": "Claude Opus 4.6 Thinking",
  "updated_at": "2026-03-16T00:00:00Z",
  "last_selected_by": "legacy_test"
}
EOF
mode_show_legacy="$("$HELPER" execution-mode show --state-file "$EXECUTION_MODE_STATE_FILE")"
assert_contains "$mode_show_legacy" 'EXECUTION_MODE_STATE|action=show|mode=dynamic-cross-runtime|label=Dynamic Cross-Runtime'
jq -e '.selected_mode == "dynamic-cross-runtime"' "$EXECUTION_MODE_STATE_FILE" >/dev/null || fail "legacy lead-model state did not migrate to dynamic-cross-runtime"

echo "[test-pm-command] case: plan gate on default route emits persisted dynamic cross-runtime routing for Claude outer runtime"
plan_gate_default="$(
  PM_PLAN_GATE_RUNTIME_OVERRIDE=claude \
  PM_LEAD_MODEL_FORCE_CODEX_MCP_AVAILABLE=1 \
  "$HELPER" plan gate --route default --state-file "$EXECUTION_MODE_STATE_FILE"
)"
assert_contains "$plan_gate_default" 'RUNTIME_DETECTION|'
assert_contains "$plan_gate_default" 'outer_runtime=claude|source=explicit_override'
assert_contains "$plan_gate_default" 'EXECUTION_MODE_GATE|route=default'
assert_contains "$plan_gate_default" 'options=Dynamic Cross-Runtime;Main Runtime Only'
assert_contains "$plan_gate_default" 'persisted_mode=dynamic-cross-runtime|selected_mode=dynamic-cross-runtime|selected_label=Dynamic Cross-Runtime|selection_source=persisted_state|outer_runtime=claude|outer_runtime_source=explicit_override'
assert_contains "$plan_gate_default" 'codex_model=gpt-global|codex_reasoning_effort=medium|claude_model=opus|claude_reasoning_effort=high'
assert_contains "$plan_gate_default" 'ROUTING_PROFILE|route=default|mode=dynamic-cross-runtime|selection_source=persisted_state|outer_runtime=claude|outer_runtime_source=explicit_override|main_runtime=claude-native|main_model=opus|main_reasoning_effort=high|fallback_active=0'
assert_contains "$plan_gate_default" 'ROUTING_ROLE|role=pm_beads_plan_handoff|class=main|runtime=claude-native|model=opus|reasoning_effort=high|agent_type=default'
assert_contains "$plan_gate_default" 'ROUTING_ROLE|role=senior_engineer|class=sub|runtime=codex-worker-mcp|model=gpt-global|reasoning_effort=medium|agent_type=explorer'
assert_contains "$plan_gate_default" 'ROUTING_ROLE|role=task_verification|class=sub|runtime=claude-native|model=opus|reasoning_effort=high|agent_type=default'
assert_contains "$plan_gate_default" 'PLAN_ROUTE_READY|route=default|selected_mode=dynamic-cross-runtime|selected_label=Dynamic Cross-Runtime|selection_source=persisted_state|outer_runtime=claude|outer_runtime_source=explicit_override|discovery_can_start=1'

echo "[test-pm-command] case: main-runtime-only route is ready without opposite-provider MCP"
plan_gate_main_only="$(
  PM_PLAN_GATE_RUNTIME_OVERRIDE=codex \
  PM_LEAD_MODEL_FORCE_CLAUDE_MCP_UNAVAILABLE=1 \
  "$HELPER" plan gate --route big-feature --mode main-runtime-only --state-file "$EXECUTION_MODE_STATE_FILE"
)"
assert_contains "$plan_gate_main_only" 'selected_mode=main-runtime-only'
assert_contains "$plan_gate_main_only" 'ROUTING_PROFILE|route=big-feature|mode=main-runtime-only|selection_source=explicit_override|outer_runtime=codex|outer_runtime_source=explicit_override|main_runtime=codex-native|main_model=gpt-global|main_reasoning_effort=medium|fallback_active=0'
assert_contains "$plan_gate_main_only" 'ROUTING_ROLE|role=librarian|class=sub|runtime=codex-native|model=gpt-global|reasoning_effort=medium|agent_type=default'
assert_contains "$plan_gate_main_only" 'ROUTING_ROLE|role=task_verification|class=sub|runtime=codex-native|model=gpt-global|reasoning_effort=medium|agent_type=default'
assert_contains "$plan_gate_main_only" 'PLAN_ROUTE_READY|route=big-feature|selected_mode=main-runtime-only|selected_label=Main Runtime Only|selection_source=explicit_override|outer_runtime=codex|outer_runtime_source=explicit_override|discovery_can_start=1'
jq -e '.selected_mode == "main-runtime-only"' "$EXECUTION_MODE_STATE_FILE" >/dev/null || fail "plan gate override did not persist main-runtime-only mode"

echo "[test-pm-command] case: dynamic cross-runtime on Codex stays Codex-main for core roles and Claude-routed for support roles"
plan_gate_dynamic_codex="$(
  PM_PLAN_GATE_RUNTIME_OVERRIDE=codex \
  PM_LEAD_MODEL_FORCE_CLAUDE_MCP_AVAILABLE=1 \
  "$HELPER" plan gate --route default --mode dynamic-cross-runtime --state-file "$EXECUTION_MODE_STATE_FILE"
)"
assert_contains "$plan_gate_dynamic_codex" 'selected_mode=dynamic-cross-runtime'
assert_contains "$plan_gate_dynamic_codex" 'ROUTING_PROFILE|route=default|mode=dynamic-cross-runtime|selection_source=explicit_override|outer_runtime=codex|outer_runtime_source=explicit_override|main_runtime=codex-native|main_model=gpt-global|main_reasoning_effort=medium|fallback_active=0'
assert_contains "$plan_gate_dynamic_codex" 'ROUTING_ROLE|role=project_manager|class=main|runtime=codex-native|model=gpt-global|reasoning_effort=medium|agent_type=default'
assert_contains "$plan_gate_dynamic_codex" 'ROUTING_ROLE|role=librarian|class=sub|runtime=claude-code-mcp|model=opus|reasoning_effort=high|agent_type=default'
assert_contains "$plan_gate_dynamic_codex" 'ROUTING_ROLE|role=task_verification|class=sub|runtime=codex-native|model=gpt-global|reasoning_effort=medium|agent_type=default'
assert_contains "$plan_gate_dynamic_codex" 'PLAN_ROUTE_READY|route=default|selected_mode=dynamic-cross-runtime|selected_label=Dynamic Cross-Runtime|selection_source=explicit_override|outer_runtime=codex|outer_runtime_source=explicit_override|discovery_can_start=1'

echo "[test-pm-command] case: runtime detection resolves Codex session from positive environment markers"
detected_codex_out="$(
  CODEX_THREAD_ID='codex-session' \
  CODEX_INTERNAL_ORIGINATOR_OVERRIDE='Codex Desktop' \
  PM_LEAD_MODEL_FORCE_CLAUDE_MCP_AVAILABLE=1 \
  "$HELPER" plan gate --route default --state-file "$EXECUTION_MODE_STATE_FILE"
)"
assert_contains "$detected_codex_out" 'RUNTIME_DETECTION|'
assert_contains "$detected_codex_out" 'outer_runtime=codex|source=codex_env'
assert_contains "$detected_codex_out" 'PLAN_ROUTE_READY|route=default|selected_mode=dynamic-cross-runtime|selected_label=Dynamic Cross-Runtime|selection_source=persisted_state|outer_runtime=codex|outer_runtime_source=codex_env|discovery_can_start=1'

echo "[test-pm-command] case: explicit mode override beats persisted state"
explicit_override_out="$(
  PM_PLAN_GATE_RUNTIME_OVERRIDE=claude \
  PM_LEAD_MODEL_FORCE_CODEX_MCP_AVAILABLE=1 \
  "$HELPER" plan gate --route default --mode dynamic-cross-runtime --state-file "$EXECUTION_MODE_STATE_FILE"
)"
assert_contains "$explicit_override_out" 'selected_mode=dynamic-cross-runtime'
assert_contains "$explicit_override_out" 'selection_source=explicit_override'
assert_contains "$explicit_override_out" 'PLAN_ROUTE_READY|route=default|selected_mode=dynamic-cross-runtime|selected_label=Dynamic Cross-Runtime|selection_source=explicit_override|outer_runtime=claude|outer_runtime_source=explicit_override|discovery_can_start=1'

echo "[test-pm-command] case: execution-mode reset is idempotent"
mode_reset_one="$("$HELPER" execution-mode reset --state-file "$EXECUTION_MODE_STATE_FILE")"
mode_reset_two="$("$HELPER" execution-mode reset --state-file "$EXECUTION_MODE_STATE_FILE")"
assert_contains "$mode_reset_one" 'EXECUTION_MODE_STATE|action=reset|mode=dynamic-cross-runtime|label=Dynamic Cross-Runtime'
assert_contains "$mode_reset_two" 'EXECUTION_MODE_STATE|action=reset|mode=dynamic-cross-runtime|label=Dynamic Cross-Runtime'

echo "[test-pm-command] case: invalid execution mode and route inputs fail"
if "$HELPER" execution-mode set --state-file "$EXECUTION_MODE_STATE_FILE" --mode invalid >/dev/null 2>&1; then
  fail "execution-mode set unexpectedly accepted invalid mode"
fi
if "$HELPER" plan gate --route default --mode invalid --state-file "$EXECUTION_MODE_STATE_FILE" >/dev/null 2>&1; then
  fail "plan gate unexpectedly accepted invalid mode override"
fi
if "$HELPER" plan gate --route invalid --state-file "$EXECUTION_MODE_STATE_FILE" >/dev/null 2>&1; then
  fail "plan gate unexpectedly accepted invalid route"
fi

echo "[test-pm-command] case: runtime detection fail-closes with structured error report"
blocked_detection_file="$TMPDIR/plan-gate-blocked-runtime-detection.out"
if PM_PLAN_GATE_RUNTIME_OVERRIDE=none \
  "$HELPER" plan gate --route default --state-file "$EXECUTION_MODE_STATE_FILE" >"$blocked_detection_file" 2>&1; then
  fail "plan gate unexpectedly proceeded when runtime detection was explicitly disabled"
fi
blocked_detection_out="$(cat "$blocked_detection_file")"
assert_contains "$blocked_detection_out" 'RUNTIME_DETECTION_ERROR|'
assert_contains "$blocked_detection_out" 'reason=runtime_detection_failed'
assert_contains "$blocked_detection_out" 'source=explicit_disable'
assert_contains "$blocked_detection_out" 'PLAN_ROUTE_BLOCKED|route=default|selected_mode=dynamic-cross-runtime|selected_label=Dynamic Cross-Runtime|selection_source=persisted_state|outer_runtime=|reason=runtime_detection_failed'

echo "[test-pm-command] case: dynamic cross-runtime blocks when Claude command is not executable"
blocked_codex_dynamic_file="$TMPDIR/plan-gate-blocked-codex-dynamic.out"
if PM_PLAN_GATE_RUNTIME_OVERRIDE=codex \
  PM_LEAD_MODEL_CLAUDE_MCP_LIST_OVERRIDE='claude-code enabled' \
  PM_LEAD_MODEL_CLAUDE_COMMAND_OVERRIDE='definitely-missing-claude-command' \
  "$HELPER" plan gate --route default --mode dynamic-cross-runtime --state-file "$EXECUTION_MODE_STATE_FILE" >"$blocked_codex_dynamic_file" 2>&1; then
  fail "dynamic-cross-runtime unexpectedly proceeded when Claude command was not executable"
fi
blocked_codex_dynamic_out="$(cat "$blocked_codex_dynamic_file")"
assert_contains "$blocked_codex_dynamic_out" 'PLAN_ROUTE_BLOCKED|route=default|selected_mode=dynamic-cross-runtime|selected_label=Dynamic Cross-Runtime|selection_source=explicit_override|outer_runtime=codex|reason=claude_code_mcp_command_not_executable'
assert_contains "$blocked_codex_dynamic_out" 'next_action=fix_claude_mcp_or_switch_to_main_runtime_only|discovery_can_start=0'
assert_not_contains "$blocked_codex_dynamic_out" 'PLAN_ROUTE_READY|'

echo "[test-pm-command] case: mcp_servers.claude-code.env PATH makes dynamic cross-runtime pass on Codex"
write_codex_config "$HOME/.codex/config.toml" "gpt-global" "medium" "

[mcp_servers.claude-code.env]
PATH = \"$FAKE_CLAUDE_BIN\"
"
config_path_pass_out="$(
  PM_PLAN_GATE_RUNTIME_OVERRIDE=codex \
  PM_LEAD_MODEL_CLAUDE_MCP_LIST_OVERRIDE='claude-code enabled' \
  "$HELPER" plan gate --route default --mode dynamic-cross-runtime --state-file "$EXECUTION_MODE_STATE_FILE"
)"
assert_contains "$config_path_pass_out" 'PLAN_ROUTE_READY|route=default|selected_mode=dynamic-cross-runtime|selected_label=Dynamic Cross-Runtime|selection_source=explicit_override'
assert_not_contains "$config_path_pass_out" 'PLAN_ROUTE_BLOCKED|'

echo "[test-pm-command] case: shell_environment_policy.set PATH also makes dynamic cross-runtime pass on Codex"
write_codex_config "$HOME/.codex/config.toml" "gpt-global" "medium" "

[shell_environment_policy.set]
PATH = \"$FAKE_CLAUDE_BIN\"
"
shell_env_path_pass_out="$(
  PM_PLAN_GATE_RUNTIME_OVERRIDE=codex \
  PM_LEAD_MODEL_CLAUDE_MCP_LIST_OVERRIDE='claude-code enabled' \
  "$HELPER" plan gate --route default --mode dynamic-cross-runtime --state-file "$EXECUTION_MODE_STATE_FILE"
)"
assert_contains "$shell_env_path_pass_out" 'PLAN_ROUTE_READY|route=default|selected_mode=dynamic-cross-runtime|selected_label=Dynamic Cross-Runtime|selection_source=explicit_override'
assert_not_contains "$shell_env_path_pass_out" 'PLAN_ROUTE_BLOCKED|'

echo "[test-pm-command] case: dynamic cross-runtime in Claude blocks when codex-worker MCP is unavailable"
blocked_claude_dynamic_file="$TMPDIR/plan-gate-blocked-claude-dynamic.out"
if PM_PLAN_GATE_RUNTIME_OVERRIDE=claude \
  PM_LEAD_MODEL_FORCE_CODEX_MCP_UNAVAILABLE=1 \
  "$HELPER" plan gate --route default --mode dynamic-cross-runtime --state-file "$EXECUTION_MODE_STATE_FILE" >"$blocked_claude_dynamic_file" 2>&1; then
  fail "dynamic-cross-runtime in Claude unexpectedly proceeded when codex-worker MCP was unavailable"
fi
blocked_claude_dynamic_out="$(cat "$blocked_claude_dynamic_file")"
assert_contains "$blocked_claude_dynamic_out" 'PLAN_ROUTE_BLOCKED|route=default|selected_mode=dynamic-cross-runtime|selected_label=Dynamic Cross-Runtime|selection_source=explicit_override|outer_runtime=claude|reason=codex_worker_mcp_unavailable'
assert_contains "$blocked_claude_dynamic_out" 'next_action=fix_codex_worker_mcp_or_switch_to_main_runtime_only|discovery_can_start=0'
assert_not_contains "$blocked_claude_dynamic_out" 'PLAN_ROUTE_READY|'

echo "[test-pm-command] case: dynamic cross-runtime in Claude blocks when codex command is not executable"
blocked_claude_command_file="$TMPDIR/plan-gate-blocked-claude-command.out"
if PM_PLAN_GATE_RUNTIME_OVERRIDE=claude \
  PM_LEAD_MODEL_CODEX_MCP_LIST_OVERRIDE='codex-worker enabled' \
  PM_LEAD_MODEL_CODEX_COMMAND_OVERRIDE='definitely-missing-codex-command' \
  "$HELPER" plan gate --route default --mode dynamic-cross-runtime --state-file "$EXECUTION_MODE_STATE_FILE" >"$blocked_claude_command_file" 2>&1; then
  fail "dynamic-cross-runtime in Claude unexpectedly proceeded when codex command was not executable"
fi
blocked_claude_command_out="$(cat "$blocked_claude_command_file")"
assert_contains "$blocked_claude_command_out" 'PLAN_ROUTE_BLOCKED|route=default|selected_mode=dynamic-cross-runtime|selected_label=Dynamic Cross-Runtime|selection_source=explicit_override|outer_runtime=claude|reason=codex_worker_command_not_executable'
assert_contains "$blocked_claude_command_out" 'next_action=fix_codex_worker_mcp_or_switch_to_main_runtime_only|discovery_can_start=0'

echo "[test-pm-command] case: execution-mode reset repairs corrupt state file"
printf 'not-json\n' >"$EXECUTION_MODE_STATE_FILE"
repair_out="$("$HELPER" execution-mode reset --state-file "$EXECUTION_MODE_STATE_FILE")"
assert_contains "$repair_out" 'EXECUTION_MODE_STATE|action=reset|mode=dynamic-cross-runtime|label=Dynamic Cross-Runtime'
jq -e '.selected_mode == "dynamic-cross-runtime"' "$EXECUTION_MODE_STATE_FILE" >/dev/null || fail "execution-mode reset did not repair corrupt state"

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
