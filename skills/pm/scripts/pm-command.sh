#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
APPROVAL_TOKEN="approved"
DEFAULT_CHANGELOG_URL="https://developers.openai.com/codex/changelog/"
DEFAULT_RELEASE_URL="https://github.com/openai/codex/releases/latest"
DEFAULT_NPM_TAGS_URL="https://registry.npmjs.org/-/package/@openai/codex/dist-tags"
DEFAULT_PLAN_TRIGGER="/pm plan: Inspect latest Codex changes and align orchestrator behavior with orchestration-mode runtime policy."
STATE_RELATIVE_PATH=".codex/pm-self-update-state.json"
SELF_CHECK_ARTIFACTS_RELATIVE_PATH=".codex/self-check-runs"
LEAD_MODEL_STATE_RELATIVE_PATH=".codex/pm-lead-model-state.json"
EXECUTION_MODE_SCHEMA_VERSION=2
EXECUTION_MODE_DYNAMIC="dynamic-cross-runtime"
EXECUTION_MODE_MAIN_ONLY="main-runtime-only"
EXECUTION_MODE_DEFAULT="$EXECUTION_MODE_DYNAMIC"
EXECUTION_MODE_OPTION_DYNAMIC="Dynamic Cross-Runtime"
EXECUTION_MODE_OPTION_MAIN_ONLY="Main Runtime Only"
RUNTIME_PROVIDER_CODEX="codex"
RUNTIME_PROVIDER_CLAUDE="claude"
LEAD_MODEL_PROFILE_FULL_CODEX="full-codex"
LEAD_MODEL_PROFILE_CODEX_MAIN="codex-main"
LEAD_MODEL_PROFILE_CLAUDE_MAIN="claude-main"
LEAD_MODEL_PROFILE_CODEX_LEGACY="codex-first"
LEAD_MODEL_PROFILE_CLAUDE_LEGACY="claude-first"
CODEX_PINNED_MODEL="gpt-5.4"
CODEX_PINNED_REASONING_EFFORT="xhigh"
UNPINNED_MODEL_VALUE="<unpinned>"
UNPINNED_REASONING_VALUE="<unpinned>"
CLAUDE_MCP_INSTALL_COMMAND="codex mcp add claude-code -- claude mcp serve"
CLAUDE_MCP_REMEDIATION_MISSING="$CLAUDE_MCP_INSTALL_COMMAND"
CLAUDE_MCP_LAST_REASON=""
CLAUDE_MCP_LAST_REMEDIATION=""
CLAUDE_MCP_LAST_DETAIL=""
CLAUDE_MCP_LAST_COMMAND=""
CLAUDE_MCP_LAST_COMMAND_SOURCE=""
CLAUDE_MCP_LAST_PATH_OVERRIDE=""
CLAUDE_MCP_LAST_PATH_OVERRIDE_SOURCE=""
CODEX_WORKER_MCP_INSTALL_COMMAND="claude mcp add codex-worker -- codex mcp-server"
CODEX_WORKER_MCP_REMEDIATION_MISSING="$CODEX_WORKER_MCP_INSTALL_COMMAND"
CODEX_WORKER_MCP_LAST_REASON=""
CODEX_WORKER_MCP_LAST_REMEDIATION=""
CODEX_WORKER_MCP_LAST_DETAIL=""
CODEX_WORKER_MCP_LAST_COMMAND=""
CODEX_WORKER_MCP_LAST_COMMAND_SOURCE=""
CODEX_WORKER_MCP_LAST_PATH_OVERRIDE=""
CODEX_WORKER_MCP_LAST_PATH_OVERRIDE_SOURCE=""
CODEX_RUNTIME_LAST_COMMAND=""
CODEX_RUNTIME_LAST_COMMAND_SOURCE=""
CODEX_RUNTIME_LAST_PATH_OVERRIDE=""
CODEX_RUNTIME_LAST_PATH_OVERRIDE_SOURCE=""
CLAUDE_WRAPPER_RUNTIME="claude-code-mcp"
CLAUDE_WRAPPER_TEMPLATE_RELATIVE_PATH="../references/internal-claude-wrapper.md"
SELF_CHECK_HEALER_TEMPLATE_RELATIVE_PATH="../references/self-check-healer.md"
CLAUDE_WRAPPER_UNSUPPORTED_LAUNCHER_PATTERN="Agent type 'general-purpose' not found|no supported agent type|unsupported launcher"
CLAUDE_CONTEXT_REQUEST_PREFIX="CONTEXT_REQUEST|"
CLAUDE_CONTEXT_REQUIRED_FIELDS_CSV="feature_objective,prd_context,task_id,acceptance_criteria,implementation_status,changed_files,constraints,evidence,clarifying_instruction"
CLAUDE_CLARIFYING_INSTRUCTION="If you have missing or ambiguous context, ask specific clarifying questions before final recommendations."
SELF_CHECK_FIXTURE_SUITE_VERSION="pm-self-check-v1"
SELF_CHECK_DEFAULT_FIXTURE_CASE="happy-path"
SELF_CHECK_DEFAULT_EXECUTION_MODE="$EXECUTION_MODE_MAIN_ONLY"
SELF_CHECK_PROBE_SUCCESS_RESPONSE="Synthetic self-check Claude probe complete."
SELF_CHECK_CODEX_SNAPSHOT_TIMEOUT_SECONDS_DEFAULT=5
SELF_CHECK_CLAUDE_SNAPSHOT_TIMEOUT_SECONDS_DEFAULT=12
SELF_CHECK_CLAUDE_MCP_TIMEOUT_MS_DEFAULT=3000
LEGACY_CLAUDE_MCP_SERVER_DROID="droid-worker"
TELEMETRY_TABLE_NAME="pm_step_events"
TELEMETRY_RUNS_TABLE_NAME="pm_runtime_detection_runs"
TELEMETRY_DEFAULT_USAGE_SOURCE="provider_response"
TELEMETRY_DEFAULT_USAGE_STATUS="complete"
SEMVER_PATTERN='v?[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?'
DEFAULT_RELEVANCE_INCLUDE_PATTERN='orchestrator|pipeline|workflow|pm|beads|approval|gate|state|checkpoint|self-update|agent|mcp|cli|command|test|qa|smoke|automation'
DEFAULT_RELEVANCE_EXCLUDE_PATTERN='marketing|landing[[:space:]-]*page|pricing[[:space:]-]*page|branding|color[[:space:]-]*refresh|theme[[:space:]-]*refresh'

usage() {
  cat <<'EOF'
Codex PM command helper.

Usage:
  pm-command.sh help
  pm-command.sh execution-mode show [--state-file PATH]
  pm-command.sh execution-mode set --mode dynamic-cross-runtime|main-runtime-only [--state-file PATH]
  pm-command.sh execution-mode reset [--state-file PATH]
  pm-command.sh lead-model show|set|reset ...   # legacy alias for execution-mode
  pm-command.sh plan gate --route default|big-feature [--mode dynamic-cross-runtime|main-runtime-only] [--state-file PATH]
  pm-command.sh claude-contract validate-context --context-file PATH [--role ROLE]
  pm-command.sh claude-contract evaluate-response --response-file PATH [--session-id ID] [--role ROLE]
  pm-command.sh claude-contract run-loop --context-file PATH [--response-file PATH ...] [--session-id ID] [--role ROLE] [--max-rounds N]
  pm-command.sh claude-wrapper prepare --context-file PATH --prompt-file PATH --objective TEXT [--session-id ID] [--role ROLE]
  pm-command.sh claude-wrapper evaluate --context-file PATH --response-file PATH [--session-id ID] [--role ROLE]
  pm-command.sh claude-wrapper run --context-file PATH --prompt-file PATH --objective TEXT [--response-file PATH ...] [--session-id ID] [--role ROLE] [--max-rounds N]
  pm-command.sh telemetry init-db [--dsn POSTGRES_DSN]
  pm-command.sh telemetry log-step --workflow-run-id ID --step-id ID [--event-id ID] [fields...]
  pm-command.sh telemetry query-task --task-id ID [--workflow-run-id ID] [--limit N]
  pm-command.sh telemetry query-run --workflow-run-id ID [--dsn POSTGRES_DSN] [--limit N]
  pm-command.sh self-check fixtures
  pm-command.sh self-check run [--fixture-case CASE] [--artifacts-dir PATH] [--mode dynamic-cross-runtime|main-runtime-only] [--prompt-file PATH] [--context-file PATH]
  pm-command.sh self-update [check] [--state-file PATH] [--changelog-url URL] [--release-url URL] [--npm-tags-url URL]
  pm-command.sh self-update complete --approval approved --prd-approval approved --beads-approval approved --prd-path PATH [--state-file PATH] [--dry-run]

Commands:
  help          Print deterministic $pm help output.
  execution-mode Read/update persistent provider-neutral orchestration mode state.
  lead-model    Legacy alias for execution-mode.
  plan          Run plan-route runtime detection, orchestration mode gate, and routing preflight.
  claude-contract Enforce Claude context-pack and missing-context handshake.
  claude-wrapper Internal-only adapter for Claude-routed prompt generation and result normalization.
  telemetry     Persist/query PM step telemetry in PostgreSQL.
  self-check    Deterministic self-diagnostic harness for the PM orchestrator.
  self-update   Manual self-update orchestration. Defaults to check mode.

Self-update modes:
  check         Build changelog-source-of-truth pending batch (stable + prerelease by default).
  complete      Advance processed version only after explicit approval gate and PRD evidence coverage.

Self-check modes:
  fixtures      Print the built-in deterministic fixture suite catalog.
  run           Execute self-check preparation/diagnostics and emit healer-ready artifacts.

Environment toggles:
  PM_SELF_UPDATE_INCLUDE_PRERELEASE=1|0   Include prerelease entries from changelog (default: 1)
  PM_SELF_UPDATE_STRICT_MISMATCH=1|0      Fail check when corroborative sources disagree with changelog (default: 0)
  PM_SELF_UPDATE_RELEVANCE_INCLUDE_REGEX   Override include regex for pipeline-relevant change filtering
  PM_SELF_UPDATE_RELEVANCE_EXCLUDE_REGEX   Override exclude regex for non-pipeline change filtering
  PM_SELF_CHECK_CODEX_SNAPSHOT_TIMEOUT_SECONDS   Override codex snapshot timeout window (default: 5)
  PM_SELF_CHECK_CLAUDE_SNAPSHOT_TIMEOUT_SECONDS  Override Claude snapshot timeout window (default: 12)
  PM_SELF_CHECK_CLAUDE_MCP_TIMEOUT_MS            Override Claude MCP startup timeout used during self-check snapshots (default: 3000)
  PM_TELEMETRY_DSN                         PostgreSQL DSN used for telemetry persistence/query
  PM_TELEMETRY_PSQL_BIN                    Optional absolute path to psql binary

Notes:
  - This workflow is manual-only. No scheduled/background triggers are provided.
  - Completion requires exact approval token: approved
  - Changelog website is the source of truth; release/npm are corroborative.
EOF
}

die() {
  echo "[$SCRIPT_NAME] ERROR: $*" >&2
  exit 1
}

warn() {
  echo "[$SCRIPT_NAME] WARN: $*" >&2
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || die "Required tool not found: $1"
}

repo_root() {
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
  else
    pwd
  fi
}

default_state_file() {
  local root
  root="$(repo_root)"
  printf '%s/%s' "$root" "$STATE_RELATIVE_PATH"
}

default_lead_model_state_file() {
  local root
  root="$(repo_root)"
  printf '%s/%s' "$root" "$LEAD_MODEL_STATE_RELATIVE_PATH"
}

project_codex_config_file() {
  local root
  root="$(repo_root)"
  printf '%s/.codex/config.toml' "$root"
}

global_codex_config_file() {
  printf '%s/.codex/config.toml' "$HOME"
}

project_claude_settings_file() {
  local root
  root="$(repo_root)"
  printf '%s/.claude/settings.json' "$root"
}

project_claude_settings_local_file() {
  local root
  root="$(repo_root)"
  printf '%s/.claude/settings.local.json' "$root"
}

global_claude_settings_file() {
  printf '%s/.claude/settings.json' "$HOME"
}

script_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

internal_claude_wrapper_template_path() {
  local base
  base="$(script_dir)"
  printf '%s/%s' "$base" "$CLAUDE_WRAPPER_TEMPLATE_RELATIVE_PATH"
}

internal_self_check_healer_template_path() {
  local base
  base="$(script_dir)"
  printf '%s/%s' "$base" "$SELF_CHECK_HEALER_TEMPLATE_RELATIVE_PATH"
}

display_path() {
  local path="$1"
  local root

  root="$(repo_root)"
  case "$path" in
    "$root"/*)
      printf '%s' "${path#"$root"/}"
      ;;
    *)
      printf '%s' "$path"
      ;;
  esac
}

now_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

sanitize_single_line() {
  local value="${1:-}"
  printf '%s' "$value" | tr '\r\n\t' ' ' | sed -E 's/[[:space:]]+/ /g; s/^[[:space:]]+//; s/[[:space:]]+$//'
}

epoch_ms() {
  printf '%s' "$(( $(date +%s) * 1000 ))"
}

toml_top_level_string_value() {
  local file="$1"
  local key="$2"
  local line

  [ -f "$file" ] || return 1

  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    if [[ "$line" =~ ^[[:space:]]*$ ]]; then
      continue
    fi
    if [[ "$line" =~ ^[[:space:]]*\[ ]]; then
      break
    fi
    if [[ "$line" =~ ^[[:space:]]*$key[[:space:]]*=[[:space:]]*\"([^\"]*)\" ]]; then
      printf '%s' "${BASH_REMATCH[1]}"
      return 0
    fi
    if [[ "$line" =~ ^[[:space:]]*$key[[:space:]]*=[[:space:]]*\'([^\']*)\' ]]; then
      printf '%s' "${BASH_REMATCH[1]}"
      return 0
    fi
  done < "$file"

  return 1
}

toml_section_string_value() {
  local file="$1"
  local section="$2"
  local key="$3"
  local line current_section=""

  [ -f "$file" ] || return 1

  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    if [[ "$line" =~ ^[[:space:]]*$ ]]; then
      continue
    fi
    if [[ "$line" =~ ^[[:space:]]*\[([^]]+)\][[:space:]]*$ ]]; then
      current_section="${BASH_REMATCH[1]}"
      continue
    fi
    [ "$current_section" = "$section" ] || continue
    if [[ "$line" =~ ^[[:space:]]*$key[[:space:]]*=[[:space:]]*\"([^\"]*)\" ]]; then
      printf '%s' "${BASH_REMATCH[1]}"
      return 0
    fi
    if [[ "$line" =~ ^[[:space:]]*$key[[:space:]]*=[[:space:]]*\'([^\']*)\' ]]; then
      printf '%s' "${BASH_REMATCH[1]}"
      return 0
    fi
  done < "$file"

  return 1
}

codex_config_section_string_value() {
  local section="$1"
  local key="$2"
  local project_file global_file value

  project_file="$(project_codex_config_file)"
  global_file="$(global_codex_config_file)"

  value="$(toml_section_string_value "$project_file" "$section" "$key" || true)"
  if [ -n "$value" ]; then
    printf '%s|%s' "$value" "$(display_path "$project_file")"
    return 0
  fi

  value="$(toml_section_string_value "$global_file" "$section" "$key" || true)"
  if [ -n "$value" ]; then
    printf '%s|%s' "$value" "$(display_path "$global_file")"
    return 0
  fi

  return 1
}

codex_config_value() {
  local key="$1"
  local project_file global_file value

  project_file="$(project_codex_config_file)"
  global_file="$(global_codex_config_file)"

  value="$(toml_top_level_string_value "$project_file" "$key" || true)"
  if [ -n "$value" ]; then
    printf '%s' "$value"
    return 0
  fi

  value="$(toml_top_level_string_value "$global_file" "$key" || true)"
  if [ -n "$value" ]; then
    printf '%s' "$value"
    return 0
  fi

  return 1
}

resolved_codex_model() {
  local configured
  configured="$(codex_config_value "model" || true)"
  if [ -n "$configured" ]; then
    printf '%s' "$configured"
    return 0
  fi
  printf '%s' "$CODEX_PINNED_MODEL"
}

resolved_codex_reasoning_effort() {
  local configured
  configured="$(codex_config_value "model_reasoning_effort" || true)"
  if [ -n "$configured" ]; then
    printf '%s' "$configured"
    return 0
  fi
  printf '%s' "$CODEX_PINNED_REASONING_EFFORT"
}

json_top_level_string_value() {
  local file="$1"
  local key="$2"

  [ -f "$file" ] || return 1
  jq -r --arg key "$key" '.[$key] // empty' "$file" 2>/dev/null
}

claude_settings_value() {
  local key="$1"
  local local_file project_file global_file value

  local_file="$(project_claude_settings_local_file)"
  project_file="$(project_claude_settings_file)"
  global_file="$(global_claude_settings_file)"

  value="$(json_top_level_string_value "$local_file" "$key" || true)"
  if [ -n "$value" ] && [ "$value" != "null" ]; then
    printf '%s' "$value"
    return 0
  fi

  value="$(json_top_level_string_value "$project_file" "$key" || true)"
  if [ -n "$value" ] && [ "$value" != "null" ]; then
    printf '%s' "$value"
    return 0
  fi

  value="$(json_top_level_string_value "$global_file" "$key" || true)"
  if [ -n "$value" ] && [ "$value" != "null" ]; then
    printf '%s' "$value"
    return 0
  fi

  return 1
}

resolved_claude_model() {
  local configured

  configured="${PM_PLAN_GATE_CLAUDE_MODEL_OVERRIDE:-}"
  if [ -n "$configured" ]; then
    printf '%s' "$configured"
    return 0
  fi

  configured="${ANTHROPIC_MODEL:-}"
  if [ -n "$configured" ]; then
    printf '%s' "$configured"
    return 0
  fi

  configured="$(claude_settings_value "model" || true)"
  if [ -n "$configured" ]; then
    printf '%s' "$configured"
    return 0
  fi

  printf '%s' "$UNPINNED_MODEL_VALUE"
}

resolved_claude_reasoning_effort() {
  local configured

  configured="${PM_PLAN_GATE_CLAUDE_EFFORT_OVERRIDE:-}"
  if [ -n "$configured" ]; then
    printf '%s' "$configured"
    return 0
  fi

  configured="$(claude_settings_value "effortLevel" || true)"
  if [ -n "$configured" ]; then
    printf '%s' "$configured"
    return 0
  fi

  printf '%s' "$UNPINNED_REASONING_VALUE"
}

conductor_workspace_path() {
  if [ -n "${PM_PLAN_GATE_WORKSPACE_PATH_OVERRIDE:-}" ]; then
    printf '%s' "$PM_PLAN_GATE_WORKSPACE_PATH_OVERRIDE"
    return 0
  fi

  repo_root
}

in_conductor_workspace() {
  local workspace_path

  workspace_path="$(conductor_workspace_path)"
  case "$workspace_path" in
    */conductor/workspaces/*)
      return 0
      ;;
  esac

  return 1
}

codex_runtime_detected() {
  [ -n "${CODEX_THREAD_ID:-}" ] || [ -n "${CODEX_INTERNAL_ORIGINATOR_OVERRIDE:-}" ]
}

process_command_for_pid() {
  local pid="$1"
  [ -n "$pid" ] || return 1
  ps -o command= -p "$pid" 2>/dev/null | head -n 1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

process_tree_contains_pattern() {
  local pid="${1:-$$}"
  local pattern="$2"
  local depth=0
  local cmd=""
  local parent=""

  while [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null && [ "$depth" -lt 6 ]; do
    cmd="$(process_command_for_pid "$pid" || true)"
    if printf '%s\n' "$cmd" | grep -Eiq "$pattern"; then
      return 0
    fi
    parent="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d '[:space:]')"
    [ -n "$parent" ] || break
    pid="$parent"
    depth=$((depth + 1))
  done

  return 1
}

claude_runtime_detected() {
  if [ -n "${CLAUDECODE:-}" ] || [ -n "${CLAUDE_CODE:-}" ] || [ -n "${CLAUDE_SESSION_ID:-}" ]; then
    return 0
  fi

  process_tree_contains_pattern "$PPID" '(^|[ /])claude([[:space:]]|$)|Claude\.app'
}

detect_outer_runtime() {
  local runtime_override="${PM_PLAN_GATE_RUNTIME_OVERRIDE:-${PM_PLAN_GATE_CONDUCTOR_RUNTIME_OVERRIDE:-}}"
  local codex_detected=1
  local claude_detected=1

  OUTER_RUNTIME_LAST_VALUE=""

  case "$runtime_override" in
    codex)
      OUTER_RUNTIME_LAST_VALUE="$RUNTIME_PROVIDER_CODEX"
      OUTER_RUNTIME_LAST_SOURCE="explicit_override"
      OUTER_RUNTIME_LAST_DETAIL="Runtime forced via PM_PLAN_GATE_RUNTIME_OVERRIDE."
      return 0
      ;;
    claude)
      OUTER_RUNTIME_LAST_VALUE="$RUNTIME_PROVIDER_CLAUDE"
      OUTER_RUNTIME_LAST_SOURCE="explicit_override"
      OUTER_RUNTIME_LAST_DETAIL="Runtime forced via PM_PLAN_GATE_RUNTIME_OVERRIDE."
      return 0
      ;;
    off|none)
      OUTER_RUNTIME_LAST_SOURCE="explicit_disable"
      OUTER_RUNTIME_LAST_DETAIL="Runtime auto-detection was explicitly disabled via PM_PLAN_GATE_RUNTIME_OVERRIDE."
      return 1
      ;;
    "")
      ;;
    *)
      die "Invalid PM_PLAN_GATE_CONDUCTOR_RUNTIME_OVERRIDE: $runtime_override"
      ;;
  esac

  if codex_runtime_detected; then
    codex_detected=0
  fi

  if claude_runtime_detected; then
    claude_detected=0
  fi

  if [ "$codex_detected" -eq 0 ] && [ "$claude_detected" -eq 0 ]; then
    OUTER_RUNTIME_LAST_SOURCE="ambiguous_positive_markers"
    OUTER_RUNTIME_LAST_DETAIL="Both Codex and Claude runtime markers were detected in the current session."
    return 1
  fi

  if [ "$codex_detected" -eq 0 ]; then
    OUTER_RUNTIME_LAST_VALUE="$RUNTIME_PROVIDER_CODEX"
    if [ -n "${CODEX_THREAD_ID:-}" ] || [ -n "${CODEX_INTERNAL_ORIGINATOR_OVERRIDE:-}" ]; then
      OUTER_RUNTIME_LAST_SOURCE="codex_env"
      OUTER_RUNTIME_LAST_DETAIL="Detected Codex runtime from Codex session environment markers."
    else
      OUTER_RUNTIME_LAST_SOURCE="process_tree"
      OUTER_RUNTIME_LAST_DETAIL="Detected Codex runtime from the process tree."
    fi
    return 0
  fi

  if [ "$claude_detected" -eq 0 ]; then
    OUTER_RUNTIME_LAST_VALUE="$RUNTIME_PROVIDER_CLAUDE"
    if [ -n "${CLAUDECODE:-}" ] || [ -n "${CLAUDE_CODE:-}" ] || [ -n "${CLAUDE_SESSION_ID:-}" ]; then
      OUTER_RUNTIME_LAST_SOURCE="claude_env"
      OUTER_RUNTIME_LAST_DETAIL="Detected Claude runtime from Claude session environment markers."
    else
      OUTER_RUNTIME_LAST_SOURCE="process_tree"
      OUTER_RUNTIME_LAST_DETAIL="Detected Claude runtime from the process tree."
    fi
    return 0
  fi

  OUTER_RUNTIME_LAST_SOURCE="unresolved"
  OUTER_RUNTIME_LAST_DETAIL="No supported positive runtime markers were found for Codex or Claude in this session."
  return 1
}

execution_mode_selection_source() {
  local selection_source="persisted_state"

  if [ -n "${1:-}" ]; then
    selection_source="explicit_override"
  fi

  printf '%s' "$selection_source"
}

telemetry_new_event_id() {
  local step="${1:-unknown}"
  local event_type="${2:-event}"
  printf 'pmcmd-%s-%s-%s-%s' "$(date +%s)" "$$" "$step" "$event_type"
}

telemetry_dsn() {
  printf '%s' "${PM_TELEMETRY_DSN:-}"
}

telemetry_psql_bin() {
  if [ -n "${PM_TELEMETRY_PSQL_BIN:-}" ] && [ -x "${PM_TELEMETRY_PSQL_BIN:-}" ]; then
    printf '%s' "$PM_TELEMETRY_PSQL_BIN"
    return 0
  fi

  if command -v psql >/dev/null 2>&1; then
    command -v psql
    return 0
  fi

  if [ -x "/opt/homebrew/opt/libpq/bin/psql" ]; then
    printf '%s' "/opt/homebrew/opt/libpq/bin/psql"
    return 0
  fi

  return 1
}

telemetry_enabled() {
  [ -n "$(telemetry_dsn)" ]
}

telemetry_exec_sql() {
  local sql="$1"
  local dsn psql_bin
  shift || true

  dsn="$(telemetry_dsn)"
  [ -n "$dsn" ] || return 10

  psql_bin="$(telemetry_psql_bin)" || return 11
  printf '%s\n' "$sql" | "$psql_bin" "$dsn" -v ON_ERROR_STOP=1 "$@"
}

telemetry_init_db() {
  telemetry_exec_sql "
CREATE TABLE IF NOT EXISTS ${TELEMETRY_TABLE_NAME} (
  id BIGSERIAL PRIMARY KEY,
  event_id TEXT NOT NULL UNIQUE,
  workflow_run_id TEXT NOT NULL,
  task_id TEXT,
  step_id TEXT NOT NULL,
  parent_step_id TEXT,
  phase TEXT,
  step_name TEXT,
  event_type TEXT NOT NULL,
  agent_role TEXT,
  invoked_by_role TEXT,
  runtime TEXT,
  provider TEXT,
  model TEXT,
  started_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  duration_ms BIGINT,
  prompt_tokens INTEGER,
  completion_tokens INTEGER,
  total_tokens INTEGER,
  usage_source TEXT NOT NULL DEFAULT '${TELEMETRY_DEFAULT_USAGE_SOURCE}',
  usage_status TEXT NOT NULL DEFAULT '${TELEMETRY_DEFAULT_USAGE_STATUS}',
  status TEXT,
  error_or_warning_code TEXT,
  warning_message TEXT,
  remediation TEXT,
  request_id TEXT,
  trace_id TEXT,
  span_id TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (duration_ms IS NULL OR duration_ms >= 0),
  CHECK (prompt_tokens IS NULL OR prompt_tokens >= 0),
  CHECK (completion_tokens IS NULL OR completion_tokens >= 0),
  CHECK (total_tokens IS NULL OR total_tokens >= 0)
);

CREATE INDEX IF NOT EXISTS idx_${TELEMETRY_TABLE_NAME}_task_created
  ON ${TELEMETRY_TABLE_NAME} (task_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_${TELEMETRY_TABLE_NAME}_run_created
  ON ${TELEMETRY_TABLE_NAME} (workflow_run_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_${TELEMETRY_TABLE_NAME}_phase_step
  ON ${TELEMETRY_TABLE_NAME} (phase, step_name, created_at DESC);

CREATE TABLE IF NOT EXISTS ${TELEMETRY_RUNS_TABLE_NAME} (
  id BIGSERIAL PRIMARY KEY,
  run_id TEXT NOT NULL UNIQUE,
  route TEXT NOT NULL,
  workspace_path TEXT,
  outer_runtime TEXT,
  execution_mode TEXT,
  status TEXT NOT NULL,
  reason TEXT,
  detail TEXT,
  remediation TEXT,
  detection_source TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_${TELEMETRY_RUNS_TABLE_NAME}_route_created
  ON ${TELEMETRY_RUNS_TABLE_NAME} (route, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_${TELEMETRY_RUNS_TABLE_NAME}_status_created
  ON ${TELEMETRY_RUNS_TABLE_NAME} (status, created_at DESC);
"
}

telemetry_require_table() {
  local exists

  if ! exists="$(telemetry_exec_sql "
SELECT to_regclass(current_schema() || '.${TELEMETRY_TABLE_NAME}') IS NOT NULL;
" -tA 2>/dev/null)"; then
    die "Unable to validate telemetry table presence. Ensure DB access is valid and run pm-command.sh telemetry init-db --dsn <postgres-dsn>"
  fi

  exists="$(printf '%s' "$exists" | tr -d '[:space:]')"
  if [ "$exists" != "t" ]; then
    die "Telemetry table ${TELEMETRY_TABLE_NAME} is missing. Run pm-command.sh telemetry init-db --dsn <postgres-dsn>"
  fi
}

telemetry_record_event() {
  local event_id="$1"
  local workflow_run_id="$2"
  local task_id="${3:-}"
  local step_id="$4"
  local parent_step_id="${5:-}"
  local phase="${6:-}"
  local step_name="${7:-}"
  local event_type="${8:-}"
  local agent_role="${9:-}"
  local invoked_by_role="${10:-}"
  local runtime="${11:-}"
  local provider="${12:-}"
  local model="${13:-}"
  local started_at="${14:-}"
  local ended_at="${15:-}"
  local duration_ms="${16:-}"
  local prompt_tokens="${17:-}"
  local completion_tokens="${18:-}"
  local total_tokens="${19:-}"
  local usage_source="${20:-$TELEMETRY_DEFAULT_USAGE_SOURCE}"
  local usage_status="${21:-$TELEMETRY_DEFAULT_USAGE_STATUS}"
  local status="${22:-}"
  local error_or_warning_code="${23:-}"
  local warning_message="${24:-}"
  local remediation="${25:-}"
  local request_id="${26:-}"
  local trace_id="${27:-}"
  local span_id="${28:-}"
  local metadata_json="${29:-{}}"

  [ -n "$event_id" ] || die "telemetry event_id is required"
  [ -n "$workflow_run_id" ] || die "telemetry workflow_run_id is required"
  [ -n "$step_id" ] || die "telemetry step_id is required"
  [ -n "$event_type" ] || die "telemetry event_type is required"
  if ! printf '%s' "$metadata_json" | jq -e . >/dev/null 2>&1; then
    local normalized_metadata_json
    normalized_metadata_json="$(printf '%s' "$metadata_json" | sed 's/\\"/"/g')"
    if printf '%s' "$normalized_metadata_json" | jq -e . >/dev/null 2>&1; then
      metadata_json="$normalized_metadata_json"
    else
      warn "telemetry metadata_json was invalid; defaulting to {}"
      metadata_json="{}"
    fi
  fi

  telemetry_init_db >/dev/null
  telemetry_exec_sql "
INSERT INTO ${TELEMETRY_TABLE_NAME} (
  event_id, workflow_run_id, task_id, step_id, parent_step_id, phase, step_name, event_type,
  agent_role, invoked_by_role, runtime, provider, model, started_at, ended_at, duration_ms,
  prompt_tokens, completion_tokens, total_tokens, usage_source, usage_status, status,
  error_or_warning_code, warning_message, remediation, request_id, trace_id, span_id, metadata
)
VALUES (
  NULLIF(:'event_id',''),
  NULLIF(:'workflow_run_id',''),
  NULLIF(:'task_id',''),
  NULLIF(:'step_id',''),
  NULLIF(:'parent_step_id',''),
  NULLIF(:'phase',''),
  NULLIF(:'step_name',''),
  NULLIF(:'event_type',''),
  NULLIF(:'agent_role',''),
  NULLIF(:'invoked_by_role',''),
  NULLIF(:'runtime',''),
  NULLIF(:'provider',''),
  NULLIF(:'model',''),
  NULLIF(:'started_at','')::timestamptz,
  NULLIF(:'ended_at','')::timestamptz,
  NULLIF(:'duration_ms','')::bigint,
  NULLIF(:'prompt_tokens','')::integer,
  NULLIF(:'completion_tokens','')::integer,
  NULLIF(:'total_tokens','')::integer,
  COALESCE(NULLIF(:'usage_source',''), '${TELEMETRY_DEFAULT_USAGE_SOURCE}'),
  COALESCE(NULLIF(:'usage_status',''), '${TELEMETRY_DEFAULT_USAGE_STATUS}'),
  NULLIF(:'status',''),
  NULLIF(:'error_or_warning_code',''),
  NULLIF(:'warning_message',''),
  NULLIF(:'remediation',''),
  NULLIF(:'request_id',''),
  NULLIF(:'trace_id',''),
  NULLIF(:'span_id',''),
  COALESCE(NULLIF(:'metadata_json','')::jsonb, '{}'::jsonb)
)
ON CONFLICT (event_id) DO UPDATE
SET
  ended_at = COALESCE(EXCLUDED.ended_at, ${TELEMETRY_TABLE_NAME}.ended_at),
  duration_ms = COALESCE(EXCLUDED.duration_ms, ${TELEMETRY_TABLE_NAME}.duration_ms),
  prompt_tokens = COALESCE(EXCLUDED.prompt_tokens, ${TELEMETRY_TABLE_NAME}.prompt_tokens),
  completion_tokens = COALESCE(EXCLUDED.completion_tokens, ${TELEMETRY_TABLE_NAME}.completion_tokens),
  total_tokens = COALESCE(EXCLUDED.total_tokens, ${TELEMETRY_TABLE_NAME}.total_tokens),
  status = COALESCE(EXCLUDED.status, ${TELEMETRY_TABLE_NAME}.status),
  error_or_warning_code = COALESCE(EXCLUDED.error_or_warning_code, ${TELEMETRY_TABLE_NAME}.error_or_warning_code),
  warning_message = COALESCE(EXCLUDED.warning_message, ${TELEMETRY_TABLE_NAME}.warning_message),
  remediation = COALESCE(EXCLUDED.remediation, ${TELEMETRY_TABLE_NAME}.remediation),
  metadata = CASE
    WHEN EXCLUDED.metadata = '{}'::jsonb THEN ${TELEMETRY_TABLE_NAME}.metadata
    ELSE EXCLUDED.metadata
  END;
" \
    -v event_id="$event_id" \
    -v workflow_run_id="$workflow_run_id" \
    -v task_id="$task_id" \
    -v step_id="$step_id" \
    -v parent_step_id="$parent_step_id" \
    -v phase="$phase" \
    -v step_name="$step_name" \
    -v event_type="$event_type" \
    -v agent_role="$agent_role" \
    -v invoked_by_role="$invoked_by_role" \
    -v runtime="$runtime" \
    -v provider="$provider" \
    -v model="$model" \
    -v started_at="$started_at" \
    -v ended_at="$ended_at" \
    -v duration_ms="$duration_ms" \
    -v prompt_tokens="$prompt_tokens" \
    -v completion_tokens="$completion_tokens" \
    -v total_tokens="$total_tokens" \
    -v usage_source="$usage_source" \
    -v usage_status="$usage_status" \
    -v status="$status" \
    -v error_or_warning_code="$error_or_warning_code" \
    -v warning_message="$warning_message" \
    -v remediation="$remediation" \
    -v request_id="$request_id" \
    -v trace_id="$trace_id" \
    -v span_id="$span_id" \
    -v metadata_json="$metadata_json" >/dev/null
}

telemetry_record_event_nonblocking() {
  local err_file
  if ! telemetry_enabled; then
    return 0
  fi
  err_file="$(mktemp)"
  if ! telemetry_record_event "$@" 2>"$err_file"; then
    warn "Telemetry write skipped: $(sanitize_single_line "$(cat "$err_file")")"
    rm -f "$err_file"
    return 0
  fi
  rm -f "$err_file"
}

telemetry_record_runtime_detection_run() {
  local run_id="$1"
  local route="$2"
  local workspace_path="${3:-}"
  local outer_runtime="${4:-}"
  local execution_mode="${5:-}"
  local status="${6:-}"
  local reason="${7:-}"
  local detail="${8:-}"
  local remediation="${9:-}"
  local detection_source="${10:-}"
  local started_at="${11:-}"
  local completed_at="${12:-}"
  local metadata_json="${13:-{}}"

  [ -n "$run_id" ] || die "runtime detection run_id is required"
  [ -n "$route" ] || die "runtime detection route is required"
  [ -n "$status" ] || die "runtime detection status is required"
  if ! printf '%s' "$metadata_json" | jq -e . >/dev/null 2>&1; then
    metadata_json="{}"
  fi

  telemetry_init_db >/dev/null
  telemetry_exec_sql "
INSERT INTO ${TELEMETRY_RUNS_TABLE_NAME} (
  run_id, route, workspace_path, outer_runtime, execution_mode, status, reason, detail,
  remediation, detection_source, metadata, started_at, completed_at
)
VALUES (
  NULLIF(:'run_id',''),
  NULLIF(:'route',''),
  NULLIF(:'workspace_path',''),
  NULLIF(:'outer_runtime',''),
  NULLIF(:'execution_mode',''),
  NULLIF(:'status',''),
  NULLIF(:'reason',''),
  NULLIF(:'detail',''),
  NULLIF(:'remediation',''),
  NULLIF(:'detection_source',''),
  COALESCE(NULLIF(:'metadata_json','')::jsonb, '{}'::jsonb),
  NULLIF(:'started_at','')::timestamptz,
  NULLIF(:'completed_at','')::timestamptz
)
ON CONFLICT (run_id) DO UPDATE
SET
  workspace_path = COALESCE(EXCLUDED.workspace_path, ${TELEMETRY_RUNS_TABLE_NAME}.workspace_path),
  outer_runtime = COALESCE(EXCLUDED.outer_runtime, ${TELEMETRY_RUNS_TABLE_NAME}.outer_runtime),
  execution_mode = COALESCE(EXCLUDED.execution_mode, ${TELEMETRY_RUNS_TABLE_NAME}.execution_mode),
  status = COALESCE(EXCLUDED.status, ${TELEMETRY_RUNS_TABLE_NAME}.status),
  reason = COALESCE(EXCLUDED.reason, ${TELEMETRY_RUNS_TABLE_NAME}.reason),
  detail = COALESCE(EXCLUDED.detail, ${TELEMETRY_RUNS_TABLE_NAME}.detail),
  remediation = COALESCE(EXCLUDED.remediation, ${TELEMETRY_RUNS_TABLE_NAME}.remediation),
  detection_source = COALESCE(EXCLUDED.detection_source, ${TELEMETRY_RUNS_TABLE_NAME}.detection_source),
  metadata = CASE
    WHEN EXCLUDED.metadata = '{}'::jsonb THEN ${TELEMETRY_RUNS_TABLE_NAME}.metadata
    ELSE EXCLUDED.metadata
  END,
  started_at = COALESCE(EXCLUDED.started_at, ${TELEMETRY_RUNS_TABLE_NAME}.started_at),
  completed_at = COALESCE(EXCLUDED.completed_at, ${TELEMETRY_RUNS_TABLE_NAME}.completed_at);
" \
    -v run_id="$run_id" \
    -v route="$route" \
    -v workspace_path="$workspace_path" \
    -v outer_runtime="$outer_runtime" \
    -v execution_mode="$execution_mode" \
    -v status="$status" \
    -v reason="$reason" \
    -v detail="$detail" \
    -v remediation="$remediation" \
    -v detection_source="$detection_source" \
    -v metadata_json="$metadata_json" \
    -v started_at="$started_at" \
    -v completed_at="$completed_at" >/dev/null
}

telemetry_record_runtime_detection_run_nonblocking() {
  local err_file
  if ! telemetry_enabled; then
    return 0
  fi
  err_file="$(mktemp)"
  if ! telemetry_record_runtime_detection_run "$@" 2>"$err_file"; then
    warn "Telemetry run write skipped: $(sanitize_single_line "$(cat "$err_file")")"
    rm -f "$err_file"
    return 0
  fi
  rm -f "$err_file"
}

default_self_check_artifacts_root() {
  local root
  root="$(repo_root)"
  printf '%s/%s' "$root" "$SELF_CHECK_ARTIFACTS_RELATIVE_PATH"
}

self_check_fixture_catalog_json() {
  cat <<'EOF'
[
  {
    "id": "happy-path",
    "description": "Healthy deterministic orchestration harness run.",
    "synthetic_task": "Create a snake game",
    "failure_mode": "",
    "expected_status": "clean"
  },
  {
    "id": "spawn-failure",
    "description": "Injected subagent spawn failure for healer aggregation.",
    "synthetic_task": "Create a snake game",
    "failure_mode": "subagent_spawn_failed",
    "expected_status": "issues_detected"
  },
  {
    "id": "response-timeout",
    "description": "Injected child response timeout/no-response path.",
    "synthetic_task": "Create a snake game",
    "failure_mode": "subagent_response_timeout",
    "expected_status": "issues_detected"
  },
  {
    "id": "context-needed",
    "description": "Injected missing-context response-contract path.",
    "synthetic_task": "Create a snake game",
    "failure_mode": "context_needed",
    "expected_status": "issues_detected"
  },
  {
    "id": "unsupported-launcher",
    "description": "Injected unsupported-launcher Claude wrapper failure.",
    "synthetic_task": "Create a snake game",
    "failure_mode": "unsupported_launcher",
    "expected_status": "issues_detected"
  }
]
EOF
}

self_check_fixture_exists() {
  local fixture_case="$1"
  self_check_fixture_catalog_json | jq -e --arg fixture_case "$fixture_case" '.[] | select(.id == $fixture_case)' >/dev/null
}

self_check_fixture_value() {
  local fixture_case="$1"
  local field="$2"
  self_check_fixture_catalog_json | jq -r --arg fixture_case "$fixture_case" ".[] | select(.id == \$fixture_case) | .${field}"
}

self_check_generate_run_id() {
  local fixture_case="$1"
  local stamp seed

  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  seed="$(hash_string "${fixture_case}|${stamp}|$$")"
  printf 'self-check-%s-%s' "$stamp" "${seed:0:10}"
}

run_with_timeout_capture() {
  local timeout_seconds="$1"
  local output_file="$2"
  local elapsed=0
  shift 2

  : >"$output_file"
  ("$@" >"$output_file" 2>&1) &
  local pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    if [ "$elapsed" -ge "$timeout_seconds" ]; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  wait "$pid"
}

self_check_emit_line() {
  local console_log_file="$1"
  local line="$2"

  echo "$line"
  printf '%s\n' "$line" >>"$console_log_file"
}

self_check_append_jsonl() {
  local file="$1"
  local payload="$2"
  printf '%s\n' "$payload" >>"$file"
}

self_check_record_event() {
  local console_log_file="$1"
  local events_file="$2"
  local findings_file="$3"
  local workflow_run_id="$4"
  local phase="$5"
  local step="$6"
  local severity="$7"
  local status="$8"
  local code="$9"
  local detail="${10:-}"
  local remediation="${11:-}"
  local artifact_path="${12:-}"
  local metadata_json_input="${13:-{}}"
  local detail_clean remediation_clean line event_json metadata_json

  if ! printf '%s' "$metadata_json_input" | jq -e . >/dev/null 2>&1; then
    metadata_json_input="{}"
  fi

  detail_clean="$(sanitize_single_line "$detail")"
  remediation_clean="$(sanitize_single_line "$remediation")"
  line="SELF_CHECK_EVENT|run_id=$workflow_run_id|severity=$severity|phase=$phase|step=$step|status=$status|code=$code|detail=$detail_clean|remediation=$remediation_clean"
  self_check_emit_line "$console_log_file" "$line"

  event_json="$(jq -nc \
    --arg run_id "$workflow_run_id" \
    --arg phase "$phase" \
    --arg step "$step" \
    --arg severity "$severity" \
    --arg status "$status" \
    --arg code "$code" \
    --arg detail "$detail_clean" \
    --arg remediation "$remediation_clean" \
    --arg artifact_path "$artifact_path" \
    --arg created_at "$(now_utc)" \
    --argjson metadata "$metadata_json_input" \
    '{
      run_id: $run_id,
      phase: $phase,
      step: $step,
      severity: $severity,
      status: $status,
      code: $code,
      detail: $detail,
      remediation: $remediation,
      artifact_path: $artifact_path,
      metadata: $metadata,
      created_at: $created_at
    }')"
  self_check_append_jsonl "$events_file" "$event_json"

  if [ "$severity" != "info" ]; then
    self_check_append_jsonl "$findings_file" "$event_json"
  fi

  metadata_json="$(jq -nc \
    --arg code "$code" \
    --arg severity "$severity" \
    --arg artifact_path "$artifact_path" \
    --argjson extra "$metadata_json_input" \
    '{code: $code, severity: $severity, artifact_path: $artifact_path} + (if ($extra | type) == "object" then $extra else {} end)')"
  telemetry_record_event_nonblocking \
    "$(telemetry_new_event_id "self-check-${step}" "$status")" \
    "$workflow_run_id" \
    "" \
    "self-check:${step}" \
    "" \
    "Self Check" \
    "$step" \
    "self_check_event" \
    "project_manager" \
    "project_manager" \
    "${PM_RUNTIME:-self-check}" \
    "${PM_TELEMETRY_PROVIDER:-codex}" \
    "${PM_MODEL:-$CODEX_PINNED_MODEL}" \
    "$(now_utc)" \
    "" \
    "" \
    "" \
    "" \
    "" \
    "$TELEMETRY_DEFAULT_USAGE_SOURCE" \
    "$TELEMETRY_DEFAULT_USAGE_STATUS" \
    "$status" \
    "$code" \
    "$detail_clean" \
    "$remediation_clean" \
    "" \
    "" \
    "" \
    "$metadata_json"
}

self_check_text_excerpt() {
  local file="$1"
  local byte_limit="${2:-400}"

  [ -f "$file" ] || return 0
  LC_ALL=C head -c "$byte_limit" "$file" 2>/dev/null | tr '\r\n\t' ' ' | sed -E 's/[[:space:]]+/ /g; s/^[[:space:]]+//; s/[[:space:]]+$//'
}

self_check_process_state() {
  local pid="$1"

  [ -n "$pid" ] || return 1
  ps -o pid=,ppid=,stat=,command= -p "$pid" 2>/dev/null | awk '
    NF {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      print
      found=1
      exit
    }
    END { exit !found }
  '
}

self_check_csv_contains() {
  local csv="${1:-}"
  local token="$2"
  local normalized

  normalized="$(printf '%s' "$csv" | tr -d '[:space:]')"
  case ",$normalized," in
    *,all,*|*,"$token",*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

self_check_should_skip_artifact_step() {
  self_check_csv_contains "${PM_SELF_CHECK_SKIP_ARTIFACT_STEPS:-}" "$1"
}

self_check_force_telemetry_incomplete_step() {
  self_check_csv_contains "${PM_SELF_CHECK_FORCE_TELEMETRY_INCOMPLETE_STEPS:-}" "$1"
}

self_check_write_snapshot_attempt() {
  local attempt_file="$1"
  local step="$2"
  local runtime_kind="$3"
  local execution_mode="$4"
  local run_id="$5"
  local status="$6"
  local primary_code="$7"
  local issue_codes_csv="$8"
  local detail="$9"
  local remediation="${10:-}"
  local command_path="${11:-}"
  local command_source="${12:-}"
  local path_override_source="${13:-}"
  local artifact_path="${14:-}"
  local stdout_path="${15:-}"
  local stderr_path="${16:-}"
  local started_at="${17:-}"
  local completed_at="${18:-}"
  local elapsed_ms="${19:-}"
  local exit_code="${20:-}"
  local exit_signal="${21:-}"
  local timeout_flag="${22:-0}"
  local pid="${23:-}"
  local process_state="${24:-}"
  local telemetry_complete="${25:-1}"
  local timeout_seconds="${26:-}"
  local command_env_overrides="${27:-}"
  local stdout_excerpt stderr_excerpt combined_excerpt issue_codes_json

  stdout_excerpt="$(self_check_text_excerpt "$stdout_path")"
  stderr_excerpt="$(self_check_text_excerpt "$stderr_path")"
  combined_excerpt="$(self_check_text_excerpt "$artifact_path")"
  issue_codes_json="$(printf '%s' "$issue_codes_csv" | tr ',' '\n' | json_array_from_newlines 2>/dev/null || printf '[]')"
  if [ -z "$path_override_source" ]; then
    path_override_source="<none>"
  fi
  if [ -z "$command_env_overrides" ]; then
    command_env_overrides="<none>"
  fi
  if [ -z "$process_state" ] || [ "$process_state" = "not_started" ]; then
    process_state="exited"
  fi

  jq -n \
    --arg step "$step" \
    --arg runtime_kind "$runtime_kind" \
    --arg execution_mode "$execution_mode" \
    --arg run_id "$run_id" \
    --arg status "$status" \
    --arg primary_code "$primary_code" \
    --arg detail "$(sanitize_single_line "$detail")" \
    --arg remediation "$(sanitize_single_line "$remediation")" \
    --arg command_path "$command_path" \
    --arg command_source "$command_source" \
    --arg path_override_source "$path_override_source" \
    --arg artifact_path "$(display_path "$artifact_path")" \
    --arg stdout_path "$(display_path "$stdout_path")" \
    --arg stderr_path "$(display_path "$stderr_path")" \
    --arg attempt_file "$(display_path "$attempt_file")" \
    --arg started_at "$started_at" \
    --arg completed_at "$completed_at" \
    --arg elapsed_ms "$elapsed_ms" \
    --arg exit_code "$exit_code" \
    --arg exit_signal "$exit_signal" \
    --arg pid "$pid" \
    --arg process_state "$process_state" \
    --arg timeout_seconds "$timeout_seconds" \
    --arg command_env_overrides "$command_env_overrides" \
    --arg stdout_excerpt "$stdout_excerpt" \
    --arg stderr_excerpt "$stderr_excerpt" \
    --arg combined_excerpt "$combined_excerpt" \
    --argjson issue_codes "$issue_codes_json" \
    --argjson timed_out "$(if [ "${timeout_flag:-0}" -eq 1 ]; then printf 'true'; else printf 'false'; fi)" \
    --argjson telemetry_complete "$(if [ "${telemetry_complete:-1}" -eq 1 ]; then printf 'true'; else printf 'false'; fi)" \
    '{
      step: $step,
      runtime_kind: $runtime_kind,
      execution_mode: $execution_mode,
      run_id: $run_id,
      status: $status,
      primary_code: $primary_code,
      issue_codes: $issue_codes,
      detail: $detail,
      remediation: $remediation,
      command_path: $command_path,
      command_source: $command_source,
      path_override_source: $path_override_source,
      artifact_path: $artifact_path,
      stdout_path: $stdout_path,
      stderr_path: $stderr_path,
      attempt_file: $attempt_file,
      started_at: $started_at,
      completed_at: $completed_at,
      elapsed_ms: ($elapsed_ms | tonumber? // null),
      exit_code: ($exit_code | tonumber? // null),
      exit_signal: (if $exit_signal == "" then null else $exit_signal end),
      timed_out: $timed_out,
      pid: (if $pid == "" then null else $pid end),
      process_state: $process_state,
      timeout_seconds: ($timeout_seconds | tonumber? // null),
      command_env_overrides: $command_env_overrides,
      partial_stdout: $stdout_excerpt,
      partial_stderr: $stderr_excerpt,
      partial_combined_output: $combined_excerpt,
      telemetry_complete: $telemetry_complete
    }' >"$attempt_file"
}

self_check_capture_snapshot_command() {
  local timeout_seconds="$1"
  local step="$2"
  local runtime_kind="$3"
  local execution_mode="$4"
  local run_id="$5"
  local command_path="$6"
  local command_source="$7"
  local path_override_source="$8"
  local artifact_path="$9"
  local stdout_path="${10}"
  local stderr_path="${11}"
  local attempt_file="${12}"
  local command_env_overrides="${13:-}"
  shift 13
  local started_at completed_at start_ms end_ms elapsed_ms
  local pid="" wait_rc=0 timed_out=0 telemetry_complete=1
  local exit_code="" exit_signal="" process_state="not_started"
  local status="passed" primary_code="" issue_codes_csv=""
  local detail remediation
  local -a command=("$@")

  : >"$artifact_path"
  : >"$stdout_path"
  : >"$stderr_path"
  started_at="$(now_utc)"
  start_ms="$(epoch_ms)"

  (
    "${command[@]}" \
      > >(tee "$stdout_path" >>"$artifact_path") \
      2> >(tee "$stderr_path" >>"$artifact_path" >&2)
  ) &
  pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    process_state="$(self_check_process_state "$pid" || true)"
    if [ $(( ($(epoch_ms) - start_ms) / 1000 )) -ge "$timeout_seconds" ]; then
      timed_out=1
      [ -n "$process_state" ] || process_state="timeout_pending"
      kill "$pid" 2>/dev/null || true
      sleep 1
      if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null || true
        exit_signal="KILL"
      else
        exit_signal="TERM"
      fi
      wait "$pid" 2>/dev/null || true
      break
    fi
    sleep 1
  done

  if [ "$timed_out" -eq 0 ]; then
    if wait "$pid"; then
      wait_rc=0
      exit_code=0
    else
      wait_rc=$?
      if [ "$wait_rc" -gt 128 ]; then
        exit_signal="signal_$((wait_rc - 128))"
      else
        exit_code="$wait_rc"
      fi
    fi
  fi

  completed_at="$(now_utc)"
  end_ms="$(epoch_ms)"
  elapsed_ms="$((end_ms - start_ms))"
  if [ -z "$process_state" ]; then
    process_state="exited"
  fi

  detail="Snapshot captured successfully."
  remediation=""
  if [ "$timed_out" -eq 1 ]; then
    status="failed"
    primary_code="snapshot_command_hung"
    issue_codes_csv="snapshot_command_hung"
    detail="Snapshot command exceeded timeout while collecting MCP state."
    remediation="Inspect the snapshot attempt JSON plus stdout/stderr artifacts and fix the runtime or launcher path before rerunning self-check."
  elif [ -n "$exit_signal" ] || { [ -n "$exit_code" ] && [ "$exit_code" != "0" ]; }; then
    status="failed"
    primary_code="snapshot_nonzero_exit"
    issue_codes_csv="snapshot_nonzero_exit"
    detail="Snapshot command exited unsuccessfully while collecting MCP state."
    remediation="Inspect the snapshot attempt JSON plus stdout/stderr artifacts and fix the runtime or launcher path before rerunning self-check."
  fi

  if [ "$status" != "passed" ] && { [ -s "$artifact_path" ] || [ -s "$stdout_path" ] || [ -s "$stderr_path" ]; }; then
    issue_codes_csv="${issue_codes_csv:+$issue_codes_csv,}snapshot_partial_output"
  fi

  if self_check_force_telemetry_incomplete_step "$step"; then
    status="failed"
    telemetry_complete=0
    path_override_source=""
    issue_codes_csv="${issue_codes_csv:+$issue_codes_csv,}snapshot_telemetry_incomplete"
    if [ -z "$primary_code" ]; then
      primary_code="snapshot_telemetry_incomplete"
      detail="Snapshot evidence is incomplete and cannot support root-cause debugging."
      remediation="Inspect the snapshot attempt JSON and repair evidence capture before trusting this self-check run."
    fi
  fi

  self_check_write_snapshot_attempt \
    "$attempt_file" "$step" "$runtime_kind" "$execution_mode" "$run_id" "$status" "$primary_code" "$issue_codes_csv" \
    "$detail" "$remediation" "$command_path" "$command_source" "$path_override_source" \
    "$artifact_path" "$stdout_path" "$stderr_path" "$started_at" "$completed_at" "$elapsed_ms" \
    "$exit_code" "$exit_signal" "$timed_out" "$pid" "$process_state" "$telemetry_complete" \
    "$timeout_seconds" "$command_env_overrides"
}

self_check_write_snapshot_unavailable() {
  local step="$1"
  local runtime_kind="$2"
  local execution_mode="$3"
  local run_id="$4"
  local command_source="$5"
  local path_override_source="$6"
  local detail="$7"
  local remediation="$8"
  local artifact_path="$9"
  local stdout_path="${10}"
  local stderr_path="${11}"
  local attempt_file="${12}"
  local started_at

  : >"$artifact_path"
  : >"$stdout_path"
  : >"$stderr_path"
  started_at="$(now_utc)"
  self_check_write_snapshot_attempt \
    "$attempt_file" "$step" "$runtime_kind" "$execution_mode" "$run_id" "failed" "snapshot_runtime_unavailable" "snapshot_runtime_unavailable" \
    "$detail" "$remediation" "" "$command_source" "$path_override_source" \
    "$artifact_path" "$stdout_path" "$stderr_path" "$started_at" "$started_at" "0" \
    "" "" "0" "" "unavailable" "1" \
    "" ""
}

self_check_write_snapshot_skipped() {
  local step="$1"
  local runtime_kind="$2"
  local execution_mode="$3"
  local run_id="$4"
  local detail="$5"
  local remediation="$6"
  local artifact_path="$7"
  local stdout_path="$8"
  local stderr_path="$9"
  local attempt_file="${10}"
  local started_at

  : >"$artifact_path"
  : >"$stdout_path"
  : >"$stderr_path"
  started_at="$(now_utc)"
  self_check_write_snapshot_attempt \
    "$attempt_file" "$step" "$runtime_kind" "$execution_mode" "$run_id" "skipped" "snapshot_capture_skipped" "snapshot_capture_skipped" \
    "$detail" "$remediation" "" "policy:PM_SELF_CHECK_SKIP_ARTIFACT_STEPS" "<none>" \
    "$artifact_path" "$stdout_path" "$stderr_path" "$started_at" "$started_at" "0" \
    "" "" "0" "" "skipped" "1" \
    "" ""
}

self_check_record_snapshot_attempt() {
  local console_log_file="$1"
  local events_file="$2"
  local findings_file="$3"
  local run_id="$4"
  local attempt_file="$5"
  local step status primary_code detail remediation artifact_path metadata_json
  local stdout_path stderr_path issue_codes_csv severity

  [ -f "$attempt_file" ] || return 1

  step="$(jq -r '.step' "$attempt_file")"
  status="$(jq -r '.status' "$attempt_file")"
  primary_code="$(jq -r '.primary_code // empty' "$attempt_file")"
  detail="$(jq -r '.detail // empty' "$attempt_file")"
  remediation="$(jq -r '.remediation // empty' "$attempt_file")"
  artifact_path="$(jq -r '.artifact_path // empty' "$attempt_file")"
  stdout_path="$(jq -r '.stdout_path // empty' "$attempt_file")"
  stderr_path="$(jq -r '.stderr_path // empty' "$attempt_file")"
  issue_codes_csv="$(jq -r '.issue_codes | join(",")' "$attempt_file")"

  [ -n "$artifact_path" ] && self_check_emit_line "$console_log_file" "SELF_CHECK_ARTIFACT|kind=$step|path=$artifact_path"
  [ -n "$stdout_path" ] && self_check_emit_line "$console_log_file" "SELF_CHECK_ARTIFACT|kind=${step}_stdout|path=$stdout_path"
  [ -n "$stderr_path" ] && self_check_emit_line "$console_log_file" "SELF_CHECK_ARTIFACT|kind=${step}_stderr|path=$stderr_path"
  self_check_emit_line "$console_log_file" "SELF_CHECK_ARTIFACT|kind=${step}_attempt|path=$(jq -r '.attempt_file' "$attempt_file")"
  self_check_emit_line "$console_log_file" "SELF_CHECK_ARTIFACT_STATUS|run_id=$run_id|step=$step|status=$status|primary_code=${primary_code:-none}|issue_codes=${issue_codes_csv:-none}|attempt_file=$(jq -r '.attempt_file' "$attempt_file")"

  metadata_json="$(jq -c '{
    runtime_kind,
    execution_mode,
    issue_codes,
    command_path,
    command_source,
    path_override_source,
    timeout_seconds,
    command_env_overrides,
    elapsed_ms,
    exit_code,
    exit_signal,
    timed_out,
    pid,
    process_state,
    partial_stdout,
    partial_stderr,
    partial_combined_output,
    telemetry_complete,
    attempt_file,
    stdout_path,
    stderr_path
  }' "$attempt_file")"

  if [ "$status" = "passed" ]; then
    self_check_record_event "$console_log_file" "$events_file" "$findings_file" "$run_id" "artifacts" "$step" "info" "passed" "snapshot_capture_passed" "Snapshot capture completed successfully." "" "$artifact_path" "$metadata_json"
    return 0
  fi

  severity="warning"
  self_check_record_event "$console_log_file" "$events_file" "$findings_file" "$run_id" "artifacts" "$step" "$severity" "$status" "${primary_code:-snapshot_capture_failed}" "$detail" "$remediation" "$artifact_path" "$metadata_json"
  return 1
}

self_check_snapshot_timeout_seconds() {
  local runtime_kind="$1"
  local configured default_value

  case "$runtime_kind" in
    "$RUNTIME_PROVIDER_CODEX")
      default_value="$SELF_CHECK_CODEX_SNAPSHOT_TIMEOUT_SECONDS_DEFAULT"
      configured="${PM_SELF_CHECK_CODEX_SNAPSHOT_TIMEOUT_SECONDS:-$default_value}"
      ;;
    "$RUNTIME_PROVIDER_CLAUDE")
      default_value="$SELF_CHECK_CLAUDE_SNAPSHOT_TIMEOUT_SECONDS_DEFAULT"
      configured="${PM_SELF_CHECK_CLAUDE_SNAPSHOT_TIMEOUT_SECONDS:-$default_value}"
      ;;
    *)
      default_value="$SELF_CHECK_CODEX_SNAPSHOT_TIMEOUT_SECONDS_DEFAULT"
      configured="$default_value"
      ;;
  esac

  if [[ "$configured" =~ ^[0-9]+$ ]] && [ "$configured" -gt 0 ]; then
    printf '%s' "$configured"
    return 0
  fi

  printf '%s' "$default_value"
}

self_check_claude_mcp_timeout_ms() {
  local configured="${PM_SELF_CHECK_CLAUDE_MCP_TIMEOUT_MS:-$SELF_CHECK_CLAUDE_MCP_TIMEOUT_MS_DEFAULT}"
  if [[ "$configured" =~ ^[0-9]+$ ]] && [ "$configured" -ge 1000 ]; then
    printf '%s' "$configured"
    return 0
  fi
  printf '%s' "$SELF_CHECK_CLAUDE_MCP_TIMEOUT_MS_DEFAULT"
}

self_check_legacy_droid_worker_config_path() {
  local config_file="${HOME:-}/.claude.json"
  [ -n "${HOME:-}" ] || return 1
  [ -f "$config_file" ] || return 1
  if jq -e --arg name "$LEGACY_CLAUDE_MCP_SERVER_DROID" '.mcpServers?[$name] != null' "$config_file" >/dev/null 2>&1; then
    printf '%s' "$config_file"
    return 0
  fi
  return 1
}

self_check_write_probe_context() {
  local context_file="$1"
  local run_id="$2"
  local synthetic_task="$3"

  mkdir -p "$(dirname "$context_file")"
  cat >"$context_file" <<EOF
{
  "feature_objective": "Validate Claude session usability for PM self-check run ${run_id}",
  "prd_context": "docs/prd/2026-03-17--pm-self-check-healer-mode.md#self-check",
  "task_id": "${run_id}",
  "acceptance_criteria": [
    "Claude wrapper evaluation returns a usable result for the synthetic probe"
  ],
  "implementation_status": "Self-check preflight",
  "changed_files": [
    "skills/pm/scripts/pm-command.sh"
  ],
  "constraints": [
    "Keep PM public launcher contract generic",
    "Do not bypass approval gates"
  ],
  "evidence": {
    "synthetic_task": "${synthetic_task}"
  },
  "clarifying_instruction": "${CLAUDE_CLARIFYING_INSTRUCTION}"
}
EOF
}

self_check_write_healer_prompt() {
  local template_path="$1"
  local prompt_file="$2"
  local run_id="$3"
  local fixture_case="$4"
  local synthetic_task="$5"
  local summary_file="$6"
  local context_file="$7"

  mkdir -p "$(dirname "$prompt_file")"
  {
    printf 'use agent swarm for PM self-check healer: investigate run %s for fixture %s and use the normal PM flow to package any orchestrator repairs.\n\n' "$run_id" "$fixture_case"
    cat "$template_path"
    printf '\nRun ID: %s\n' "$run_id"
    printf 'Fixture case: %s\n' "$fixture_case"
    printf 'Synthetic task: %s\n' "$synthetic_task"
    printf 'Summary file: %s\n' "$(display_path "$summary_file")"
    printf 'Healer context file: %s\n' "$(display_path "$context_file")"
    printf '\nSummary JSON:\n'
    jq . "$summary_file"
    printf '\n'
  } >"$prompt_file"
}

self_check_write_summary() {
  local summary_file="$1"
  local run_id="$2"
  local fixture_case="$3"
  local execution_mode="$4"
  local artifacts_dir="$5"
  local synthetic_task="$6"
  local status="$7"
  local started_at="$8"
  local completed_at="$9"
  local registration_status="${10}"
  local executability_status="${11}"
  local session_status="${12}"
  local plan_gate_status="${13}"
  local plan_gate_output_file="${14}"
  local summary_prompt_file="${15}"
  local summary_context_file="${16}"
  local events_file="${17}"
  local findings_file="${18}"
  local codex_attempt_file="${19:-}"
  local claude_attempt_file="${20:-}"
  local events_json findings_json codex_attempt_json claude_attempt_json

  events_json="$(jq -s '.' "$events_file" 2>/dev/null || echo '[]')"
  findings_json="$(jq -s '.' "$findings_file" 2>/dev/null || echo '[]')"
  codex_attempt_json="$(jq -c '.' "$codex_attempt_file" 2>/dev/null || echo '{}')"
  claude_attempt_json="$(jq -c '.' "$claude_attempt_file" 2>/dev/null || echo '{}')"

  jq -n \
    --arg run_id "$run_id" \
    --arg fixture_suite_version "$SELF_CHECK_FIXTURE_SUITE_VERSION" \
    --arg fixture_case "$fixture_case" \
    --arg execution_mode "$execution_mode" \
    --arg artifact_dir "$(display_path "$artifacts_dir")" \
    --arg synthetic_task "$synthetic_task" \
    --arg status "$status" \
    --arg started_at "$started_at" \
    --arg completed_at "$completed_at" \
    --arg registration_status "$registration_status" \
    --arg executability_status "$executability_status" \
    --arg session_status "$session_status" \
    --arg plan_gate_status "$plan_gate_status" \
    --arg plan_gate_output_file "$(display_path "$plan_gate_output_file")" \
    --arg prompt_file "$(display_path "$summary_prompt_file")" \
    --arg context_file "$(display_path "$summary_context_file")" \
    --argjson events "$events_json" \
    --argjson findings "$findings_json" \
    --argjson codex_attempt "$codex_attempt_json" \
    --argjson claude_attempt "$claude_attempt_json" \
    '{
      run_id: $run_id,
      fixture_suite_version: $fixture_suite_version,
      fixture_case: $fixture_case,
      execution_mode: $execution_mode,
      artifact_dir: $artifact_dir,
      synthetic_task: $synthetic_task,
      status: $status,
      started_at: $started_at,
      completed_at: $completed_at,
      claude_health: {
        registration: $registration_status,
        executability: $executability_status,
        session_usability: $session_status
      },
      child_plan_gate: {
        status: $plan_gate_status,
        output_file: $plan_gate_output_file
      },
      artifact_checks: {
        codex_mcp_snapshot: $codex_attempt,
        claude_mcp_snapshot: $claude_attempt
      },
      healer_prompt_file: $prompt_file,
      healer_context_file: $context_file,
      events: $events,
      findings: $findings
    }' >"$summary_file"
}

run_self_check_fixtures() {
  local catalog
  catalog="$(self_check_fixture_catalog_json)"
  echo "SELF_CHECK_FIXTURES|suite_version=$SELF_CHECK_FIXTURE_SUITE_VERSION|count=$(printf '%s' "$catalog" | jq 'length')"
  printf '%s' "$catalog" | jq -r '.[] | "SELF_CHECK_FIXTURE|id=\(.id)|description=\(.description)|synthetic_task=\(.synthetic_task)|failure_mode=\(.failure_mode // "")|expected_status=\(.expected_status)"'
}

run_self_check_run() {
  local fixture_case="$SELF_CHECK_DEFAULT_FIXTURE_CASE"
  local artifacts_dir=""
  local prompt_file=""
  local context_file=""
  local execution_mode="$SELF_CHECK_DEFAULT_EXECUTION_MODE"
  local console_log_file events_file findings_file summary_file
  local codex_snapshot_file codex_snapshot_stdout_file codex_snapshot_stderr_file codex_snapshot_attempt_file
  local claude_snapshot_file claude_snapshot_stdout_file claude_snapshot_stderr_file claude_snapshot_attempt_file
  local plan_gate_output_file
  local session_probe_context_file session_probe_response_file session_probe_eval_file
  local run_id synthetic_task failure_mode expected_status started_at completed_at
  local registration_status="failed" executability_status="failed" session_status="failed"
  local plan_gate_status="not_started"
  local final_status="clean"
  local summary_reason="" summary_detail="" summary_remediation=""
  local finding_count=0 critical_count=0
  local plan_gate_out="" plan_gate_rc=0 blocked_line="" blocked_reason="" blocked_detail="" blocked_remediation=""
  local template_path healer_prompt_file healer_context_file
  local probe_output probe_eval_out probe_eval_rc=0
  local codex_snapshot_command="" codex_snapshot_command_source="" codex_snapshot_path_override_source=""
  local claude_snapshot_command="" claude_snapshot_command_source="" claude_snapshot_path_override_source=""
  local codex_snapshot_timeout_seconds="" claude_snapshot_timeout_seconds="" claude_mcp_timeout_ms=""
  local claude_command_env_overrides="" legacy_droid_worker_config=""
  local artifact_status="passed" artifact_metadata_json=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --fixture-case)
        fixture_case="${2:-}"
        shift 2
        ;;
      --artifacts-dir)
        artifacts_dir="${2:-}"
        shift 2
        ;;
      --prompt-file)
        prompt_file="${2:-}"
        shift 2
        ;;
      --context-file)
        context_file="${2:-}"
        shift 2
        ;;
      --mode|--execution-mode)
        execution_mode="${2:-}"
        shift 2
        ;;
      --lead-model)
        execution_mode="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown self-check run argument: $1"
        ;;
    esac
  done

  self_check_fixture_exists "$fixture_case" || die "Unknown self-check fixture case: $fixture_case"
  validate_execution_mode "$execution_mode" || die "Invalid execution mode for self-check: $execution_mode"
  execution_mode="$(canonical_execution_mode "$execution_mode")"

  synthetic_task="$(self_check_fixture_value "$fixture_case" "synthetic_task")"
  failure_mode="$(self_check_fixture_value "$fixture_case" "failure_mode")"
  expected_status="$(self_check_fixture_value "$fixture_case" "expected_status")"
  run_id="$(self_check_generate_run_id "$fixture_case")"
  started_at="$(now_utc)"

  if [ -z "$artifacts_dir" ]; then
    artifacts_dir="$(default_self_check_artifacts_root)/$run_id"
  fi
  mkdir -p "$artifacts_dir"

  console_log_file="$artifacts_dir/console.log"
  events_file="$artifacts_dir/events.jsonl"
  findings_file="$artifacts_dir/findings.jsonl"
  summary_file="$artifacts_dir/summary.json"
  codex_snapshot_file="$artifacts_dir/codex-mcp-list.txt"
  codex_snapshot_stdout_file="$artifacts_dir/codex-mcp-list.stdout.txt"
  codex_snapshot_stderr_file="$artifacts_dir/codex-mcp-list.stderr.txt"
  codex_snapshot_attempt_file="$artifacts_dir/codex-mcp-list.attempt.json"
  claude_snapshot_file="$artifacts_dir/claude-mcp-list.txt"
  claude_snapshot_stdout_file="$artifacts_dir/claude-mcp-list.stdout.txt"
  claude_snapshot_stderr_file="$artifacts_dir/claude-mcp-list.stderr.txt"
  claude_snapshot_attempt_file="$artifacts_dir/claude-mcp-list.attempt.json"
  plan_gate_output_file="$artifacts_dir/child-plan-gate.txt"
  session_probe_context_file="$artifacts_dir/claude-session-probe-context.json"
  session_probe_response_file="$artifacts_dir/claude-session-probe-response.txt"
  session_probe_eval_file="$artifacts_dir/claude-session-probe-eval.txt"
  healer_prompt_file="${prompt_file:-$artifacts_dir/healer-prompt.md}"
  healer_context_file="${context_file:-$artifacts_dir/healer-context.json}"

  : >"$console_log_file"
  : >"$events_file"
  : >"$findings_file"

  self_check_emit_line "$console_log_file" "SELF_CHECK_RUN|run_id=$run_id|fixture_suite=$SELF_CHECK_FIXTURE_SUITE_VERSION|fixture_case=$fixture_case|execution_mode=$execution_mode|expected_status=$expected_status|artifact_dir=$(display_path "$artifacts_dir")"
  self_check_emit_line "$console_log_file" "SELF_CHECK_ARTIFACT|kind=console_log|path=$(display_path "$console_log_file")"

  codex_snapshot_timeout_seconds="$(self_check_snapshot_timeout_seconds "$RUNTIME_PROVIDER_CODEX")"
  claude_snapshot_timeout_seconds="$(self_check_snapshot_timeout_seconds "$RUNTIME_PROVIDER_CLAUDE")"
  claude_mcp_timeout_ms="$(self_check_claude_mcp_timeout_ms)"
  claude_command_env_overrides="MCP_TIMEOUT=$claude_mcp_timeout_ms"

  if self_check_should_skip_artifact_step "codex_mcp_snapshot"; then
    self_check_write_snapshot_skipped \
      "codex_mcp_snapshot" "$RUNTIME_PROVIDER_CODEX" "$execution_mode" "$run_id" \
      "Codex MCP snapshot was skipped by explicit self-check artifact policy." \
      "Remove the step from PM_SELF_CHECK_SKIP_ARTIFACT_STEPS and rerun self-check." \
      "$codex_snapshot_file" "$codex_snapshot_stdout_file" "$codex_snapshot_stderr_file" "$codex_snapshot_attempt_file"
  else
    codex_snapshot_command="$(codex_runtime_resolved_command || true)"
    codex_snapshot_command_source="$CODEX_RUNTIME_LAST_COMMAND_SOURCE"
    codex_snapshot_path_override_source="$CODEX_RUNTIME_LAST_PATH_OVERRIDE_SOURCE"
    if [ -z "$codex_snapshot_command" ]; then
      self_check_write_snapshot_unavailable \
        "codex_mcp_snapshot" "$RUNTIME_PROVIDER_CODEX" "$execution_mode" "$run_id" \
        "${codex_snapshot_command_source:-default(command=codex)}" \
        "${codex_snapshot_path_override_source:-<none>}" \
        "Codex snapshot command could not be resolved in the current runtime." \
        "Provide an executable codex command or fix PM_LEAD_MODEL_CODEX_PATH_OVERRIDE before rerunning self-check." \
        "$codex_snapshot_file" "$codex_snapshot_stdout_file" "$codex_snapshot_stderr_file" "$codex_snapshot_attempt_file"
    else
      self_check_capture_snapshot_command \
        "$codex_snapshot_timeout_seconds" "codex_mcp_snapshot" "$RUNTIME_PROVIDER_CODEX" "$execution_mode" "$run_id" \
        "$codex_snapshot_command" "${codex_snapshot_command_source:-default(command=codex)}" "${codex_snapshot_path_override_source:-<none>}" \
        "$codex_snapshot_file" "$codex_snapshot_stdout_file" "$codex_snapshot_stderr_file" "$codex_snapshot_attempt_file" "" \
        "$codex_snapshot_command" mcp list
    fi
  fi
  if ! self_check_record_snapshot_attempt "$console_log_file" "$events_file" "$findings_file" "$run_id" "$codex_snapshot_attempt_file"; then
    artifact_status="issues_detected"
  fi

  if self_check_should_skip_artifact_step "claude_mcp_snapshot"; then
    self_check_write_snapshot_skipped \
      "claude_mcp_snapshot" "$RUNTIME_PROVIDER_CLAUDE" "$execution_mode" "$run_id" \
      "Claude MCP snapshot was skipped by explicit self-check artifact policy." \
      "Remove the step from PM_SELF_CHECK_SKIP_ARTIFACT_STEPS and rerun self-check." \
      "$claude_snapshot_file" "$claude_snapshot_stdout_file" "$claude_snapshot_stderr_file" "$claude_snapshot_attempt_file"
  else
    if ! claude_mcp_available; then
      self_check_write_snapshot_unavailable \
        "claude_mcp_snapshot" "$RUNTIME_PROVIDER_CLAUDE" "$execution_mode" "$run_id" \
        "${CLAUDE_MCP_LAST_COMMAND_SOURCE:-default(command=claude)}" \
        "${CLAUDE_MCP_LAST_PATH_OVERRIDE_SOURCE:-<none>}" \
        "${CLAUDE_MCP_LAST_DETAIL:-Claude MCP command is not usable in the current runtime.}" \
        "${CLAUDE_MCP_LAST_REMEDIATION:-$CLAUDE_MCP_REMEDIATION_MISSING}" \
        "$claude_snapshot_file" "$claude_snapshot_stdout_file" "$claude_snapshot_stderr_file" "$claude_snapshot_attempt_file"
    else
      claude_snapshot_command="$CLAUDE_MCP_LAST_COMMAND"
      claude_snapshot_command_source="$CLAUDE_MCP_LAST_COMMAND_SOURCE"
      claude_snapshot_path_override_source="$CLAUDE_MCP_LAST_PATH_OVERRIDE_SOURCE"
      self_check_capture_snapshot_command \
        "$claude_snapshot_timeout_seconds" "claude_mcp_snapshot" "$RUNTIME_PROVIDER_CLAUDE" "$execution_mode" "$run_id" \
        "$claude_snapshot_command" "${claude_snapshot_command_source:-default(command=claude)}" "${claude_snapshot_path_override_source:-<none>}" \
        "$claude_snapshot_file" "$claude_snapshot_stdout_file" "$claude_snapshot_stderr_file" "$claude_snapshot_attempt_file" "$claude_command_env_overrides" \
        env "MCP_TIMEOUT=$claude_mcp_timeout_ms" "$claude_snapshot_command" mcp list
    fi
  fi
  if ! self_check_record_snapshot_attempt "$console_log_file" "$events_file" "$findings_file" "$run_id" "$claude_snapshot_attempt_file"; then
    artifact_status="issues_detected"
  fi

  legacy_droid_worker_config="$(self_check_legacy_droid_worker_config_path || true)"
  if [ -n "$legacy_droid_worker_config" ]; then
    self_check_record_event \
      "$console_log_file" "$events_file" "$findings_file" "$run_id" \
      "artifacts" "claude_mcp_snapshot" "info" "detected" "legacy_droid_worker_detected" \
      "Legacy Claude MCP server droid-worker is still configured in user scope. Current PM runtimes do not use it." \
      "Remove it with: claude mcp remove droid-worker -s user" \
      "$(display_path "$claude_snapshot_file")" \
      "$(jq -nc --arg server_name "$LEGACY_CLAUDE_MCP_SERVER_DROID" --arg config_path "$(display_path "$legacy_droid_worker_config")" '{server_name: $server_name, config_path: $config_path}')"
  fi

  if ! claude_mcp_server_healthy; then
    summary_reason="claude_code_mcp_unavailable"
    summary_detail="claude-code MCP server is missing, disabled, or unhealthy in the current runtime."
    summary_remediation="$CLAUDE_MCP_REMEDIATION_MISSING"
    self_check_record_event "$console_log_file" "$events_file" "$findings_file" "$run_id" "health" "claude_registration" "critical" "failed" "$summary_reason" "$summary_detail" "$summary_remediation" "$(display_path "$codex_snapshot_file")"
    final_status="failed"
  else
    registration_status="passed"
    self_check_record_event "$console_log_file" "$events_file" "$findings_file" "$run_id" "health" "claude_registration" "info" "passed" "claude_code_mcp_registered" "claude-code MCP registration is present." "" "$(display_path "$codex_snapshot_file")"
  fi

  if [ "$final_status" != "failed" ]; then
    if ! claude_mcp_available; then
      summary_reason="${CLAUDE_MCP_LAST_REASON:-claude_code_mcp_unavailable}"
      summary_detail="${CLAUDE_MCP_LAST_DETAIL:-Claude MCP command is not usable in the current runtime.}"
      summary_remediation="${CLAUDE_MCP_LAST_REMEDIATION:-$CLAUDE_MCP_REMEDIATION_MISSING}"
      self_check_record_event "$console_log_file" "$events_file" "$findings_file" "$run_id" "health" "claude_executability" "critical" "failed" "$summary_reason" "$summary_detail" "$summary_remediation" "$(display_path "$codex_snapshot_file")"
      final_status="failed"
    else
      executability_status="passed"
      self_check_record_event "$console_log_file" "$events_file" "$findings_file" "$run_id" "health" "claude_executability" "info" "passed" "claude_code_mcp_executable" "claude-code command is executable in the current runtime." "" "$(display_path "$codex_snapshot_file")"
    fi
  fi

  if [ "$final_status" != "failed" ]; then
    self_check_write_probe_context "$session_probe_context_file" "$run_id" "$synthetic_task"
    probe_output="${PM_SELF_CHECK_CLAUDE_SESSION_PROBE_OUTPUT:-$SELF_CHECK_PROBE_SUCCESS_RESPONSE}"
    printf '%s\n' "$probe_output" >"$session_probe_response_file"

    if probe_eval_out="$(run_claude_wrapper_evaluate --context-file "$session_probe_context_file" --response-file "$session_probe_response_file" --session-id "${run_id}-claude-probe" --role self_check_probe 2>&1)"; then
      probe_eval_rc=0
    else
      probe_eval_rc=$?
    fi
    printf '%s\n' "$probe_eval_out" >"$session_probe_eval_file"
    while IFS= read -r line || [ -n "$line" ]; do
      [ -n "$line" ] || continue
      self_check_emit_line "$console_log_file" "$line"
    done <<<"$probe_eval_out"
    self_check_emit_line "$console_log_file" "SELF_CHECK_ARTIFACT|kind=claude_session_probe_eval|path=$(display_path "$session_probe_eval_file")"

    if [ "$probe_eval_rc" -ne 0 ]; then
      summary_reason="claude_session_unusable"
      summary_detail="$(sanitize_single_line "$(grep -Eim1 'CLAUDE_WRAPPER_RESULT\|' "$session_probe_eval_file" || printf 'Claude session probe failed.')")"
      summary_remediation="Fix the Claude invocation/session path and rerun PM self-check."
      self_check_record_event "$console_log_file" "$events_file" "$findings_file" "$run_id" "health" "claude_session" "critical" "failed" "$summary_reason" "$summary_detail" "$summary_remediation" "$(display_path "$session_probe_eval_file")"
      final_status="failed"
    else
      session_status="passed"
      self_check_record_event "$console_log_file" "$events_file" "$findings_file" "$run_id" "health" "claude_session" "info" "passed" "claude_session_usable" "Claude session probe completed successfully." "" "$(display_path "$session_probe_eval_file")"
    fi
  fi

  if [ "$final_status" != "failed" ]; then
    if plan_gate_out="$(run_plan_gate --route default --mode "$execution_mode" 2>&1)"; then
      plan_gate_rc=0
    else
      plan_gate_rc=$?
    fi
    printf '%s\n' "$plan_gate_out" >"$plan_gate_output_file"
    while IFS= read -r line || [ -n "$line" ]; do
      [ -n "$line" ] || continue
      self_check_emit_line "$console_log_file" "$line"
    done <<<"$plan_gate_out"
    self_check_emit_line "$console_log_file" "SELF_CHECK_ARTIFACT|kind=child_plan_gate|path=$(display_path "$plan_gate_output_file")"

    if [ "$plan_gate_rc" -eq 0 ]; then
      plan_gate_status="ready"
      self_check_record_event "$console_log_file" "$events_file" "$findings_file" "$run_id" "child_flow" "plan_gate" "info" "passed" "plan_route_ready" "Child plan gate completed successfully." "" "$(display_path "$plan_gate_output_file")"
    else
      plan_gate_status="blocked"
      blocked_line="$(awk 'index($0, "PLAN_ROUTE_BLOCKED|") == 1 { print; exit }' "$plan_gate_output_file" || true)"
      blocked_reason="$(pipe_kv_get "$blocked_line" "reason" || true)"
      blocked_detail="$(pipe_kv_get "$blocked_line" "detail" || true)"
      blocked_remediation="$(pipe_kv_get "$blocked_line" "remediation" || true)"
      self_check_record_event "$console_log_file" "$events_file" "$findings_file" "$run_id" "child_flow" "plan_gate" "warning" "blocked" "${blocked_reason:-plan_route_blocked}" "${blocked_detail:-Child plan gate blocked.}" "${blocked_remediation:-Use the reported remediation and rerun self-check.}" "$(display_path "$plan_gate_output_file")"
      final_status="issues_detected"
    fi
  fi

  if [ "$final_status" != "failed" ]; then
    case "$failure_mode" in
      "")
        self_check_record_event "$console_log_file" "$events_file" "$findings_file" "$run_id" "fixture" "synthetic_task" "info" "passed" "fixture_ready" "Synthetic task prepared: $synthetic_task" "" ""
        ;;
      subagent_spawn_failed)
        local spawn_output_file="$artifacts_dir/spawn-failure.txt"
        if run_with_timeout_capture 5 "$spawn_output_file" command-does-not-exist-self-check-spawn; then
          :
        fi
        self_check_emit_line "$console_log_file" "SELF_CHECK_ARTIFACT|kind=spawn_failure_output|path=$(display_path "$spawn_output_file")"
        self_check_record_event "$console_log_file" "$events_file" "$findings_file" "$run_id" "fixture" "spawn" "warning" "failed" "subagent_spawn_failed" "Injected subagent spawn failure captured for healer aggregation." "Inspect the spawn failure output and use the normal PM flow to plan a fix." "$(display_path "$spawn_output_file")"
        final_status="issues_detected"
        ;;
      subagent_response_timeout)
        local timeout_output_file="$artifacts_dir/response-timeout.txt"
        if run_with_timeout_capture 1 "$timeout_output_file" bash -lc 'sleep 2; echo completed'; then
          :
        fi
        self_check_emit_line "$console_log_file" "SELF_CHECK_ARTIFACT|kind=response_timeout_output|path=$(display_path "$timeout_output_file")"
        self_check_record_event "$console_log_file" "$events_file" "$findings_file" "$run_id" "fixture" "response" "warning" "failed" "subagent_response_timeout" "Injected response timeout/no-response path captured for healer aggregation." "Inspect the timeout path and keep retries/abort behavior explicit." "$(display_path "$timeout_output_file")"
        final_status="issues_detected"
        ;;
      context_needed)
        local context_response_file="$artifacts_dir/context-needed-response.txt"
        local context_eval_file="$artifacts_dir/context-needed-eval.txt"
        printf '%s\n' 'CONTEXT_REQUEST|needed_fields=constraints,evidence|questions=1) Provide p95 latency budget;2) Provide failing test logs for retry path' >"$context_response_file"
        if probe_eval_out="$(run_claude_wrapper_evaluate --context-file "$session_probe_context_file" --response-file "$context_response_file" --session-id "${run_id}-context-needed" --role self_check_probe 2>&1)"; then
          probe_eval_rc=0
        else
          probe_eval_rc=$?
        fi
        printf '%s\n' "$probe_eval_out" >"$context_eval_file"
        while IFS= read -r line || [ -n "$line" ]; do
          [ -n "$line" ] || continue
          self_check_emit_line "$console_log_file" "$line"
        done <<<"$probe_eval_out"
        self_check_emit_line "$console_log_file" "SELF_CHECK_ARTIFACT|kind=context_needed_eval|path=$(display_path "$context_eval_file")"
        self_check_record_event "$console_log_file" "$events_file" "$findings_file" "$run_id" "fixture" "response_contract" "warning" "failed" "context_needed" "Injected missing-context handshake captured for healer aggregation." "Keep same-session continuation explicit in the repair plan." "$(display_path "$context_eval_file")"
        final_status="issues_detected"
        ;;
      unsupported_launcher)
        local unsupported_response_file="$artifacts_dir/unsupported-launcher-response.txt"
        local unsupported_eval_file="$artifacts_dir/unsupported-launcher-eval.txt"
        printf '%s\n' "Agent type 'general-purpose' not found" >"$unsupported_response_file"
        if probe_eval_out="$(run_claude_wrapper_evaluate --context-file "$session_probe_context_file" --response-file "$unsupported_response_file" --session-id "${run_id}-unsupported-launcher" --role self_check_probe 2>&1)"; then
          probe_eval_rc=0
        else
          probe_eval_rc=$?
        fi
        printf '%s\n' "$probe_eval_out" >"$unsupported_eval_file"
        while IFS= read -r line || [ -n "$line" ]; do
          [ -n "$line" ] || continue
          self_check_emit_line "$console_log_file" "$line"
        done <<<"$probe_eval_out"
        self_check_emit_line "$console_log_file" "SELF_CHECK_ARTIFACT|kind=unsupported_launcher_eval|path=$(display_path "$unsupported_eval_file")"
        self_check_record_event "$console_log_file" "$events_file" "$findings_file" "$run_id" "fixture" "runtime" "critical" "failed" "unsupported_launcher" "Injected unsupported-launcher runtime failure captured for healer aggregation." "Do not silently reroute blocked Claude-dependent paths." "$(display_path "$unsupported_eval_file")"
        final_status="issues_detected"
        ;;
    esac
  fi

  if [ "$final_status" != "failed" ] && [ "$artifact_status" = "issues_detected" ]; then
    final_status="issues_detected"
  fi

  finding_count="$(jq -s 'length' "$findings_file" 2>/dev/null || printf '0')"
  critical_count="$(jq -s '[.[] | select(.severity == "critical")] | length' "$findings_file" 2>/dev/null || printf '0')"
  completed_at="$(now_utc)"

  if [ "$final_status" != "failed" ]; then
    artifact_metadata_json="$(jq -n \
      --slurpfile codex "$codex_snapshot_attempt_file" \
      --slurpfile claude "$claude_snapshot_attempt_file" \
      '{
        codex_mcp_snapshot: ($codex[0] // {}),
        claude_mcp_snapshot: ($claude[0] // {})
      }')"
    mkdir -p "$(dirname "$healer_context_file")"
    jq -n \
      --arg run_id "$run_id" \
      --arg fixture_suite_version "$SELF_CHECK_FIXTURE_SUITE_VERSION" \
      --arg fixture_case "$fixture_case" \
      --arg synthetic_task "$synthetic_task" \
      --arg repair_policy "approval_gated" \
      --arg summary_file "$(display_path "$summary_file")" \
      --arg artifact_dir "$(display_path "$artifacts_dir")" \
      --arg recommended_plan_trigger "/pm plan: Repair PM self-check findings from run ${run_id} using artifact bundle ${run_id}." \
      --argjson findings "$(jq -s '.' "$findings_file" 2>/dev/null || echo '[]')" \
      --argjson artifact_checks "$artifact_metadata_json" \
      '{
        run_id: $run_id,
        fixture_suite_version: $fixture_suite_version,
        fixture_case: $fixture_case,
        synthetic_task: $synthetic_task,
        repair_policy: $repair_policy,
        summary_file: $summary_file,
        artifact_dir: $artifact_dir,
        recommended_plan_trigger: $recommended_plan_trigger,
        findings: $findings,
        artifact_checks: $artifact_checks
      }' >"$healer_context_file"

    template_path="$(internal_self_check_healer_template_path)"
    [ -f "$template_path" ] || die "Self-check healer template not found: $template_path"
    self_check_write_summary "$summary_file" "$run_id" "$fixture_case" "$execution_mode" "$artifacts_dir" "$synthetic_task" "$final_status" "$started_at" "$completed_at" "$registration_status" "$executability_status" "$session_status" "$plan_gate_status" "$plan_gate_output_file" "$healer_prompt_file" "$healer_context_file" "$events_file" "$findings_file" "$codex_snapshot_attempt_file" "$claude_snapshot_attempt_file"
    self_check_write_healer_prompt "$template_path" "$healer_prompt_file" "$run_id" "$fixture_case" "$synthetic_task" "$summary_file" "$healer_context_file"
    self_check_emit_line "$console_log_file" "SELF_CHECK_ARTIFACT|kind=summary|path=$(display_path "$summary_file")"
    self_check_emit_line "$console_log_file" "SELF_CHECK_ARTIFACT|kind=healer_context|path=$(display_path "$healer_context_file")"
    self_check_emit_line "$console_log_file" "SELF_CHECK_ARTIFACT|kind=healer_prompt|path=$(display_path "$healer_prompt_file")"
    if [ "$final_status" = "issues_detected" ]; then
      self_check_emit_line "$console_log_file" "SELF_CHECK_REPAIR_BUNDLE|path=$(display_path "$healer_context_file")|next_action=spawn_outer_healer"
    fi
  else
    self_check_write_summary "$summary_file" "$run_id" "$fixture_case" "$execution_mode" "$artifacts_dir" "$synthetic_task" "$final_status" "$started_at" "$completed_at" "$registration_status" "$executability_status" "$session_status" "$plan_gate_status" "$plan_gate_output_file" "" "" "$events_file" "$findings_file" "$codex_snapshot_attempt_file" "$claude_snapshot_attempt_file"
    self_check_emit_line "$console_log_file" "SELF_CHECK_ARTIFACT|kind=summary|path=$(display_path "$summary_file")"
  fi

  self_check_emit_line "$console_log_file" "SELF_CHECK_RESULT|status=$final_status|run_id=$run_id|fixture_case=$fixture_case|finding_count=$finding_count|critical_count=$critical_count|reason=${summary_reason:-none}|summary_file=$(display_path "$summary_file")"
  if [ "$final_status" = "failed" ]; then
    return 1
  fi

  self_check_emit_line "$console_log_file" "SELF_CHECK_HEALER_READY|status=ready|run_id=$run_id|context_file=$(display_path "$healer_context_file")|prompt_file=$(display_path "$healer_prompt_file")|next_action=spawn_outer_healer"
}

run_self_check() {
  local subcommand="${1:-run}"
  shift || true

  case "$subcommand" in
    fixtures)
      run_self_check_fixtures
      ;;
    run)
      run_self_check_run "$@"
      ;;
    *)
      die "Unknown self-check subcommand: $subcommand"
      ;;
  esac
}

pipe_kv_get() {
  local line="$1"
  local key="$2"
  local part
  local -a parts=()

  IFS='|' read -r -a parts <<<"$line"
  for part in "${parts[@]}"; do
    case "$part" in
      "$key="*)
        printf '%s' "${part#"$key="}"
        return 0
        ;;
    esac
  done

  return 1
}

validate_legacy_lead_model_profile() {
  canonical_legacy_lead_model_profile "$1" >/dev/null 2>&1
}

canonical_legacy_lead_model_profile() {
  local profile="$1"

  case "$profile" in
    "$LEAD_MODEL_PROFILE_FULL_CODEX"|"$LEAD_MODEL_PROFILE_CODEX_MAIN"|"$LEAD_MODEL_PROFILE_CLAUDE_MAIN")
      printf '%s' "$profile"
      ;;
    "$LEAD_MODEL_PROFILE_CODEX_LEGACY")
      printf '%s' "$LEAD_MODEL_PROFILE_CODEX_MAIN"
      ;;
    "$LEAD_MODEL_PROFILE_CLAUDE_LEGACY")
      printf '%s' "$LEAD_MODEL_PROFILE_CLAUDE_MAIN"
      ;;
    *)
      return 1
      ;;
  esac
}

canonical_execution_mode() {
  local mode="$1"

  case "$mode" in
    "$EXECUTION_MODE_DYNAMIC"|dynamic|cross-runtime)
      printf '%s' "$EXECUTION_MODE_DYNAMIC"
      ;;
    "$EXECUTION_MODE_MAIN_ONLY"|main-only|main-runtime)
      printf '%s' "$EXECUTION_MODE_MAIN_ONLY"
      ;;
    "$LEAD_MODEL_PROFILE_FULL_CODEX")
      printf '%s' "$EXECUTION_MODE_MAIN_ONLY"
      ;;
    "$LEAD_MODEL_PROFILE_CODEX_MAIN"|"$LEAD_MODEL_PROFILE_CLAUDE_MAIN"|"$LEAD_MODEL_PROFILE_CODEX_LEGACY"|"$LEAD_MODEL_PROFILE_CLAUDE_LEGACY")
      printf '%s' "$EXECUTION_MODE_DYNAMIC"
      ;;
    *)
      return 1
      ;;
  esac
}

validate_execution_mode() {
  canonical_execution_mode "$1" >/dev/null 2>&1
}

execution_mode_label_for_mode() {
  local mode="$1"
  local canonical_mode

  canonical_mode="$(canonical_execution_mode "$mode")" || return 1

  case "$canonical_mode" in
    "$EXECUTION_MODE_DYNAMIC")
      printf '%s' "$EXECUTION_MODE_OPTION_DYNAMIC"
      ;;
    "$EXECUTION_MODE_MAIN_ONLY")
      printf '%s' "$EXECUTION_MODE_OPTION_MAIN_ONLY"
      ;;
    *)
      return 1
      ;;
  esac
}

execution_mode_state_init_json() {
  local now="$1"
  local default_label

  default_label="$(execution_mode_label_for_mode "$EXECUTION_MODE_DEFAULT")"

  cat <<EOF
{
  "schema_version": $EXECUTION_MODE_SCHEMA_VERSION,
  "selected_mode": "$EXECUTION_MODE_DEFAULT",
  "selected_label": "$default_label",
  "updated_at": "$now",
  "last_selected_by": "default_bootstrap"
}
EOF
}

validate_execution_mode_state_file() {
  local state_file="$1"
  local mode

  jq -e '
    .schema_version == 2 and
    (.selected_mode | type == "string") and
    (.selected_label | type == "string") and
    (.updated_at | type == "string") and
    (.last_selected_by | type == "string")
  ' "$state_file" >/dev/null || return 1

  mode="$(jq -r '.selected_mode' "$state_file")"
  validate_execution_mode "$mode"
}

migrate_execution_mode_state_file() {
  local state_file="$1"
  local now="$2"
  local selected_by="" legacy_profile="" migrated_mode="" migrated_label="" tmp=""

  selected_by="$(jq -r '.last_selected_by // "legacy_profile_migration"' "$state_file" 2>/dev/null || true)"
  if [ -z "$selected_by" ] || [ "$selected_by" = "null" ]; then
    selected_by="legacy_profile_migration"
  fi

  legacy_profile="$(jq -r '.selected_profile // empty' "$state_file" 2>/dev/null || true)"
  if [ -n "$legacy_profile" ]; then
    migrated_mode="$(canonical_execution_mode "$legacy_profile" || true)"
  fi

  if [ -z "$migrated_mode" ]; then
    migrated_mode="$EXECUTION_MODE_DEFAULT"
    selected_by="legacy_state_reset"
  fi

  migrated_label="$(execution_mode_label_for_mode "$migrated_mode")"
  tmp="$(mktemp "${state_file}.tmp.XXXX")"
  jq -n \
    --arg mode "$migrated_mode" \
    --arg label "$migrated_label" \
    --arg selected_by "$selected_by" \
    --arg now "$now" \
    '
      {
        schema_version: 2,
        selected_mode: $mode,
        selected_label: $label,
        updated_at: $now,
        last_selected_by: $selected_by
      }
    ' >"$tmp"
  mv "$tmp" "$state_file"
}

ensure_execution_mode_state_file() {
  local state_file="$1"
  local now schema

  now="$(now_utc)"
  mkdir -p "$(dirname "$state_file")"

  if [ ! -f "$state_file" ]; then
    execution_mode_state_init_json "$now" >"$state_file"
  fi

  schema="$(jq -r '.schema_version // 0' "$state_file" 2>/dev/null || echo 0)"
  if [ "$schema" != "$EXECUTION_MODE_SCHEMA_VERSION" ]; then
    migrate_execution_mode_state_file "$state_file" "$now"
  fi

  if ! validate_execution_mode_state_file "$state_file"; then
    die "Execution-mode state file is invalid/corrupt and will not be mutated: $state_file"
  fi

  normalize_execution_mode_state_file "$state_file"
}

execution_mode_state_get_mode() {
  local state_file="$1"
  jq -r '.selected_mode' "$state_file"
}

execution_mode_state_get_updated_at() {
  local state_file="$1"
  jq -r '.updated_at' "$state_file"
}

execution_mode_state_set_mode() {
  local state_file="$1"
  local mode="$2"
  local selected_by="$3"
  local canonical_mode label now tmp

  validate_execution_mode "$mode" || die "Invalid execution mode: $mode"
  canonical_mode="$(canonical_execution_mode "$mode")"
  label="$(execution_mode_label_for_mode "$canonical_mode")"
  now="$(now_utc)"
  tmp="$(mktemp "${state_file}.tmp.XXXX")"

  jq \
    --arg mode "$canonical_mode" \
    --arg label "$label" \
    --arg selected_by "$selected_by" \
    --arg now "$now" \
    '
      .schema_version = 2 |
      .selected_mode = $mode |
      .selected_label = $label |
      .last_selected_by = $selected_by |
      .updated_at = $now
    ' "$state_file" >"$tmp"
  mv "$tmp" "$state_file"
}

normalize_execution_mode_state_file() {
  local state_file="$1"
  local current_mode canonical_mode current_label canonical_label selected_by now tmp

  current_mode="$(jq -r '.selected_mode' "$state_file")"
  canonical_mode="$(canonical_execution_mode "$current_mode" || true)"
  [ -n "$canonical_mode" ] || die "Execution-mode state file has unsupported mode: $state_file"

  current_label="$(jq -r '.selected_label' "$state_file")"
  canonical_label="$(execution_mode_label_for_mode "$canonical_mode")"
  if [ "$current_mode" = "$canonical_mode" ] && [ "$current_label" = "$canonical_label" ]; then
    return 0
  fi

  selected_by="$(jq -r '.last_selected_by' "$state_file")"
  if [ -z "$selected_by" ] || [ "$selected_by" = "null" ]; then
    selected_by="execution_mode_normalization"
  fi
  now="$(now_utc)"
  tmp="$(mktemp "${state_file}.tmp.XXXX")"

  jq \
    --arg mode "$canonical_mode" \
    --arg label "$canonical_label" \
    --arg selected_by "$selected_by" \
    --arg now "$now" \
    '
      .schema_version = 2 |
      .selected_mode = $mode |
      .selected_label = $label |
      .last_selected_by = $selected_by |
      .updated_at = $now
    ' "$state_file" >"$tmp"
  mv "$tmp" "$state_file"
}

claude_mcp_server_healthy() {
  local mcp_list mcp_list_override

  mcp_list_override="${PM_LEAD_MODEL_CLAUDE_MCP_LIST_OVERRIDE:-}"
  if [ -n "$mcp_list_override" ]; then
    mcp_list="$mcp_list_override"
  else
    if ! command -v codex >/dev/null 2>&1; then
      return 1
    fi
    mcp_list="$(codex mcp list 2>/dev/null || true)"
  fi
  [ -n "$mcp_list" ] || return 1

  # Treat claude-code as configured only when at least one claude-code entry is not disabled/error-like.
  printf '%s\n' "$mcp_list" | awk '
    BEGIN { IGNORECASE=1; found=0; healthy=0 }
    /(^|[[:space:]])claude-code([[:space:]]|$)/ {
      found=1
      if ($0 !~ /(disabled|error|failed|unavailable|inactive|stopped)/) {
        healthy=1
      }
    }
    END { exit !(found && healthy) }
  '
}

claude_mcp_command_from_config_file() {
  local file="$1"
  toml_section_string_value "$file" "mcp_servers.claude-code" "command"
}

claude_mcp_load_configured_command() {
  local command_override project_file global_file value

  CLAUDE_MCP_LAST_COMMAND=""
  CLAUDE_MCP_LAST_COMMAND_SOURCE=""

  command_override="${PM_LEAD_MODEL_CLAUDE_COMMAND_OVERRIDE:-}"
  if [ -n "$command_override" ]; then
    CLAUDE_MCP_LAST_COMMAND_SOURCE="env:PM_LEAD_MODEL_CLAUDE_COMMAND_OVERRIDE"
    CLAUDE_MCP_LAST_COMMAND="$command_override"
    return 0
  fi

  project_file="$(project_codex_config_file)"
  global_file="$(global_codex_config_file)"

  value="$(claude_mcp_command_from_config_file "$project_file" || true)"
  if [ -n "$value" ]; then
    CLAUDE_MCP_LAST_COMMAND_SOURCE="$(display_path "$project_file")"
    CLAUDE_MCP_LAST_COMMAND="$value"
    return 0
  fi

  value="$(claude_mcp_command_from_config_file "$global_file" || true)"
  if [ -n "$value" ]; then
    CLAUDE_MCP_LAST_COMMAND_SOURCE="$(display_path "$global_file")"
    CLAUDE_MCP_LAST_COMMAND="$value"
    return 0
  fi

  CLAUDE_MCP_LAST_COMMAND_SOURCE="default(command=claude)"
  CLAUDE_MCP_LAST_COMMAND="claude"
}

claude_mcp_load_effective_path_override() {
  local entry value source

  CLAUDE_MCP_LAST_PATH_OVERRIDE=""
  CLAUDE_MCP_LAST_PATH_OVERRIDE_SOURCE=""

  entry="$(codex_config_section_string_value "mcp_servers.claude-code.env" "PATH" || true)"
  if [ -n "$entry" ]; then
    value="${entry%%|*}"
    source="${entry#*|}"
    CLAUDE_MCP_LAST_PATH_OVERRIDE="$value"
    CLAUDE_MCP_LAST_PATH_OVERRIDE_SOURCE="[mcp_servers.claude-code.env] in $source"
    return 0
  fi

  entry="$(codex_config_section_string_value "shell_environment_policy.set" "PATH" || true)"
  if [ -n "$entry" ]; then
    value="${entry%%|*}"
    source="${entry#*|}"
    CLAUDE_MCP_LAST_PATH_OVERRIDE="$value"
    CLAUDE_MCP_LAST_PATH_OVERRIDE_SOURCE="[shell_environment_policy.set] in $source"
    return 0
  fi

  return 1
}

resolve_runtime_executable() {
  local command_name="$1"
  local path_override="${2:-}"

  [ -n "$command_name" ] || return 1
  case "$command_name" in
    */*)
	      [ -x "$command_name" ] || return 1
	      printf '%s' "$command_name"
	      ;;
	    *)
	      if [ -n "$path_override" ]; then
	        PATH="$path_override" command -v "$command_name" 2>/dev/null | head -n 1
	      else
	        command -v "$command_name" 2>/dev/null | head -n 1
	      fi
	      ;;
	  esac
}

claude_mcp_available() {
  local force_available force_unavailable configured_command resolved_command command_source path_override path_override_source

  force_available="$(resolve_bool_setting "PM_LEAD_MODEL_FORCE_CLAUDE_MCP_AVAILABLE" "" 0)"
  force_unavailable="$(resolve_bool_setting "PM_LEAD_MODEL_FORCE_CLAUDE_MCP_UNAVAILABLE" "" 0)"

  CLAUDE_MCP_LAST_REASON="claude_code_mcp_unavailable"
  CLAUDE_MCP_LAST_REMEDIATION="$CLAUDE_MCP_REMEDIATION_MISSING"
  CLAUDE_MCP_LAST_DETAIL="Claude MCP server is missing, disabled, or unhealthy. The selected orchestration mode cannot continue."
  CLAUDE_MCP_LAST_COMMAND=""
  CLAUDE_MCP_LAST_COMMAND_SOURCE=""
  CLAUDE_MCP_LAST_PATH_OVERRIDE=""
  CLAUDE_MCP_LAST_PATH_OVERRIDE_SOURCE=""

  if [ "$force_unavailable" -eq 1 ]; then
    return 1
  fi

  if [ "$force_available" -eq 1 ]; then
    claude_mcp_load_configured_command
    claude_mcp_load_effective_path_override || true
    resolved_command="$(resolve_runtime_executable "$CLAUDE_MCP_LAST_COMMAND" "$CLAUDE_MCP_LAST_PATH_OVERRIDE" || true)"
    if [ -n "$resolved_command" ]; then
      CLAUDE_MCP_LAST_COMMAND="$resolved_command"
    fi
    CLAUDE_MCP_LAST_REASON=""
    CLAUDE_MCP_LAST_REMEDIATION=""
    CLAUDE_MCP_LAST_DETAIL=""
    return 0
  fi

  if ! claude_mcp_server_healthy; then
    return 1
  fi

  claude_mcp_load_configured_command
  claude_mcp_load_effective_path_override || true
  configured_command="$CLAUDE_MCP_LAST_COMMAND"
  command_source="$CLAUDE_MCP_LAST_COMMAND_SOURCE"
  path_override="$CLAUDE_MCP_LAST_PATH_OVERRIDE"
  path_override_source="$CLAUDE_MCP_LAST_PATH_OVERRIDE_SOURCE"

  resolved_command="$(resolve_runtime_executable "$configured_command" "$path_override" || true)"
  if [ -z "$resolved_command" ]; then
    CLAUDE_MCP_LAST_REASON="claude_code_mcp_command_not_executable"
    if [ -n "$path_override_source" ]; then
      CLAUDE_MCP_LAST_REMEDIATION="$(sanitize_single_line "Update [mcp_servers.claude-code].command in $command_source to an executable command path, or fix PATH in $path_override_source so $configured_command resolves.")"
      CLAUDE_MCP_LAST_DETAIL="$(sanitize_single_line "claude-code is registered, but configured command $configured_command from $command_source is not executable in this PM runtime when using PATH from $path_override_source.")"
    else
      CLAUDE_MCP_LAST_REMEDIATION="$(sanitize_single_line "Update [mcp_servers.claude-code].command in $command_source to an executable command path, or fix the PM runtime PATH so $configured_command resolves.")"
      CLAUDE_MCP_LAST_DETAIL="$(sanitize_single_line "claude-code is registered, but configured command $configured_command from $command_source is not executable in this PM runtime.")"
    fi
    return 1
  fi

  CLAUDE_MCP_LAST_COMMAND="$resolved_command"
  CLAUDE_MCP_LAST_REASON=""
  CLAUDE_MCP_LAST_REMEDIATION=""
  CLAUDE_MCP_LAST_DETAIL=""
  return 0
}

claude_mcp_resolved_command() {
  local configured_command path_override resolved_command

  claude_mcp_load_configured_command
  claude_mcp_load_effective_path_override || true
  configured_command="$CLAUDE_MCP_LAST_COMMAND"
  path_override="$CLAUDE_MCP_LAST_PATH_OVERRIDE"
  resolved_command="$(resolve_runtime_executable "$configured_command" "$path_override" || true)"
  [ -n "$resolved_command" ] || return 1
  printf '%s' "$resolved_command"
}

codex_runtime_load_configured_command() {
  CODEX_RUNTIME_LAST_COMMAND="${PM_LEAD_MODEL_CODEX_COMMAND_OVERRIDE:-codex}"
  CODEX_RUNTIME_LAST_COMMAND_SOURCE="${PM_LEAD_MODEL_CODEX_COMMAND_OVERRIDE:+env:PM_LEAD_MODEL_CODEX_COMMAND_OVERRIDE}"
  if [ -z "$CODEX_RUNTIME_LAST_COMMAND_SOURCE" ]; then
    CODEX_RUNTIME_LAST_COMMAND_SOURCE="default(command=codex)"
  fi
}

codex_runtime_load_effective_path_override() {
  CODEX_RUNTIME_LAST_PATH_OVERRIDE="${PM_LEAD_MODEL_CODEX_PATH_OVERRIDE:-}"
  CODEX_RUNTIME_LAST_PATH_OVERRIDE_SOURCE=""
  if [ -n "$CODEX_RUNTIME_LAST_PATH_OVERRIDE" ]; then
    CODEX_RUNTIME_LAST_PATH_OVERRIDE_SOURCE="env:PM_LEAD_MODEL_CODEX_PATH_OVERRIDE"
    return 0
  fi
  return 1
}

codex_runtime_resolved_command() {
  local configured_command path_override resolved_command

  codex_runtime_load_configured_command
  codex_runtime_load_effective_path_override || true
  configured_command="$CODEX_RUNTIME_LAST_COMMAND"
  path_override="$CODEX_RUNTIME_LAST_PATH_OVERRIDE"
  resolved_command="$(resolve_runtime_executable "$configured_command" "$path_override" || true)"
  [ -n "$resolved_command" ] || return 1
  printf '%s' "$resolved_command"
}

codex_worker_mcp_server_healthy() {
  local mcp_list mcp_list_override

  mcp_list_override="${PM_LEAD_MODEL_CODEX_MCP_LIST_OVERRIDE:-}"
  if [ -n "$mcp_list_override" ]; then
    mcp_list="$mcp_list_override"
  else
    if ! command -v claude >/dev/null 2>&1; then
      return 1
    fi
    mcp_list="$(claude mcp list 2>/dev/null || true)"
  fi
  [ -n "$mcp_list" ] || return 1

  printf '%s\n' "$mcp_list" | awk '
    BEGIN { IGNORECASE=1; found=0; healthy=0 }
    /(^|[[:space:]])codex-worker([[:space:]]|$)/ {
      found=1
      if ($0 !~ /(disabled|error|failed|unavailable|inactive|stopped)/) {
        healthy=1
      }
    }
    END { exit !(found && healthy) }
  '
}

codex_worker_mcp_available() {
  local force_available force_unavailable configured_command resolved_command

  force_available="$(resolve_bool_setting "PM_LEAD_MODEL_FORCE_CODEX_MCP_AVAILABLE" "" 0)"
  force_unavailable="$(resolve_bool_setting "PM_LEAD_MODEL_FORCE_CODEX_MCP_UNAVAILABLE" "" 0)"

  CODEX_WORKER_MCP_LAST_REASON="codex_worker_mcp_unavailable"
  CODEX_WORKER_MCP_LAST_REMEDIATION="$CODEX_WORKER_MCP_REMEDIATION_MISSING"
  CODEX_WORKER_MCP_LAST_DETAIL="Codex worker MCP server is missing, disabled, or unhealthy. The selected orchestration mode cannot continue."
  CODEX_WORKER_MCP_LAST_COMMAND=""
  CODEX_WORKER_MCP_LAST_COMMAND_SOURCE=""
  CODEX_WORKER_MCP_LAST_PATH_OVERRIDE=""
  CODEX_WORKER_MCP_LAST_PATH_OVERRIDE_SOURCE=""

  if [ "$force_unavailable" -eq 1 ]; then
    return 1
  fi

  if [ "$force_available" -eq 1 ]; then
    codex_runtime_load_configured_command
    codex_runtime_load_effective_path_override || true
    resolved_command="$(resolve_runtime_executable "$CODEX_RUNTIME_LAST_COMMAND" "$CODEX_RUNTIME_LAST_PATH_OVERRIDE" || true)"
    CODEX_WORKER_MCP_LAST_COMMAND="${resolved_command:-$CODEX_RUNTIME_LAST_COMMAND}"
    CODEX_WORKER_MCP_LAST_COMMAND_SOURCE="$CODEX_RUNTIME_LAST_COMMAND_SOURCE"
    CODEX_WORKER_MCP_LAST_PATH_OVERRIDE="$CODEX_RUNTIME_LAST_PATH_OVERRIDE"
    CODEX_WORKER_MCP_LAST_PATH_OVERRIDE_SOURCE="$CODEX_RUNTIME_LAST_PATH_OVERRIDE_SOURCE"
    CODEX_WORKER_MCP_LAST_REASON=""
    CODEX_WORKER_MCP_LAST_REMEDIATION=""
    CODEX_WORKER_MCP_LAST_DETAIL=""
    return 0
  fi

  if ! codex_worker_mcp_server_healthy; then
    return 1
  fi

  codex_runtime_load_configured_command
  codex_runtime_load_effective_path_override || true
  configured_command="$CODEX_RUNTIME_LAST_COMMAND"
  CODEX_WORKER_MCP_LAST_COMMAND_SOURCE="$CODEX_RUNTIME_LAST_COMMAND_SOURCE"
  CODEX_WORKER_MCP_LAST_PATH_OVERRIDE="$CODEX_RUNTIME_LAST_PATH_OVERRIDE"
  CODEX_WORKER_MCP_LAST_PATH_OVERRIDE_SOURCE="$CODEX_RUNTIME_LAST_PATH_OVERRIDE_SOURCE"

  resolved_command="$(resolve_runtime_executable "$configured_command" "$CODEX_WORKER_MCP_LAST_PATH_OVERRIDE" || true)"
  if [ -z "$resolved_command" ]; then
    CODEX_WORKER_MCP_LAST_REASON="codex_worker_command_not_executable"
    if [ -n "$CODEX_WORKER_MCP_LAST_PATH_OVERRIDE_SOURCE" ]; then
      CODEX_WORKER_MCP_LAST_REMEDIATION="$(sanitize_single_line "Register codex-worker with \`$CODEX_WORKER_MCP_INSTALL_COMMAND\`, or fix PATH in $CODEX_WORKER_MCP_LAST_PATH_OVERRIDE_SOURCE so $configured_command resolves.")"
      CODEX_WORKER_MCP_LAST_DETAIL="$(sanitize_single_line "codex-worker is registered, but configured command $configured_command from $CODEX_WORKER_MCP_LAST_COMMAND_SOURCE is not executable in this runtime when using PATH from $CODEX_WORKER_MCP_LAST_PATH_OVERRIDE_SOURCE.")"
    else
      CODEX_WORKER_MCP_LAST_REMEDIATION="$(sanitize_single_line "Register codex-worker with \`$CODEX_WORKER_MCP_INSTALL_COMMAND\`, or fix the runtime PATH so $configured_command resolves.")"
      CODEX_WORKER_MCP_LAST_DETAIL="$(sanitize_single_line "codex-worker is registered, but configured command $configured_command from $CODEX_WORKER_MCP_LAST_COMMAND_SOURCE is not executable in this runtime.")"
    fi
    return 1
  fi

  CODEX_WORKER_MCP_LAST_COMMAND="$resolved_command"
  CODEX_WORKER_MCP_LAST_REASON=""
  CODEX_WORKER_MCP_LAST_REMEDIATION=""
  CODEX_WORKER_MCP_LAST_DETAIL=""
  return 0
}

emit_routing_role() {
  local role="$1"
  local runtime="$2"
  local model="${3:-<unpinned>}"
  local reasoning_effort="${4:-<unpinned>}"
  local agent_type="$5"
  local role_class="$6"

  echo "ROUTING_ROLE|role=$role|class=$role_class|runtime=$runtime|model=$model|reasoning_effort=$reasoning_effort|agent_type=$agent_type"
}

emit_routing_matrix_for_mode() {
  local outer_runtime="$1"
  local execution_mode="$2"
  local codex_model codex_reasoning_effort claude_model claude_reasoning_effort
  local main_runtime main_model main_reasoning opposite_runtime opposite_model opposite_reasoning

  codex_model="$(resolved_codex_model)"
  codex_reasoning_effort="$(resolved_codex_reasoning_effort)"
  claude_model="$(resolved_claude_model)"
  claude_reasoning_effort="$(resolved_claude_reasoning_effort)"
  execution_mode="$(canonical_execution_mode "$execution_mode")" || die "Unknown execution mode: $execution_mode"

  case "$outer_runtime" in
    "$RUNTIME_PROVIDER_CODEX")
      main_runtime="codex-native"
      main_model="$codex_model"
      main_reasoning="$codex_reasoning_effort"
      opposite_runtime="claude-code-mcp"
      opposite_model="$claude_model"
      opposite_reasoning="$claude_reasoning_effort"
      ;;
    "$RUNTIME_PROVIDER_CLAUDE")
      main_runtime="claude-native"
      main_model="$claude_model"
      main_reasoning="$claude_reasoning_effort"
      opposite_runtime="codex-worker-mcp"
      opposite_model="$codex_model"
      opposite_reasoning="$codex_reasoning_effort"
      ;;
    *)
      die "Unknown outer runtime: $outer_runtime"
      ;;
  esac

  emit_routing_role "project_manager" "$main_runtime" "$main_model" "$main_reasoning" "default" "main"
  emit_routing_role "team_lead" "$main_runtime" "$main_model" "$main_reasoning" "default" "main"
  emit_routing_role "pm_beads_plan_handoff" "$main_runtime" "$main_model" "$main_reasoning" "default" "main"
  emit_routing_role "pm_implement_handoff" "$main_runtime" "$main_model" "$main_reasoning" "default" "main"

  if [ "$execution_mode" = "$EXECUTION_MODE_MAIN_ONLY" ]; then
    emit_routing_role "senior_engineer" "$main_runtime" "$main_model" "$main_reasoning" "explorer" "sub"
    emit_routing_role "librarian" "$main_runtime" "$main_model" "$main_reasoning" "default" "sub"
    emit_routing_role "smoke_test_planner" "$main_runtime" "$main_model" "$main_reasoning" "default" "sub"
    emit_routing_role "alternative_pm" "$main_runtime" "$main_model" "$main_reasoning" "default" "sub"
    emit_routing_role "researcher" "$main_runtime" "$main_model" "$main_reasoning" "default" "sub"
    emit_routing_role "backend_engineer" "$main_runtime" "$main_model" "$main_reasoning" "worker" "sub"
    emit_routing_role "frontend_engineer" "$main_runtime" "$main_model" "$main_reasoning" "worker" "sub"
    emit_routing_role "security_engineer" "$main_runtime" "$main_model" "$main_reasoning" "worker" "sub"
    emit_routing_role "agents_compliance_reviewer" "$main_runtime" "$main_model" "$main_reasoning" "default" "sub"
    emit_routing_role "jazz_reviewer" "$main_runtime" "$main_model" "$main_reasoning" "default" "sub"
    emit_routing_role "codex_reviewer" "$main_runtime" "$main_model" "$main_reasoning" "default" "sub"
    emit_routing_role "manual_qa" "$main_runtime" "$main_model" "$main_reasoning" "default" "sub"
    emit_routing_role "task_verification" "$main_runtime" "$main_model" "$main_reasoning" "default" "sub"
    return 0
  fi

  case "$outer_runtime" in
    "$RUNTIME_PROVIDER_CODEX")
      emit_routing_role "senior_engineer" "$opposite_runtime" "$opposite_model" "$opposite_reasoning" "explorer" "sub"
      emit_routing_role "librarian" "$opposite_runtime" "$opposite_model" "$opposite_reasoning" "default" "sub"
      emit_routing_role "smoke_test_planner" "$opposite_runtime" "$opposite_model" "$opposite_reasoning" "default" "sub"
      emit_routing_role "alternative_pm" "$opposite_runtime" "$opposite_model" "$opposite_reasoning" "default" "sub"
      emit_routing_role "researcher" "$opposite_runtime" "$opposite_model" "$opposite_reasoning" "default" "sub"
      emit_routing_role "backend_engineer" "$main_runtime" "$main_model" "$main_reasoning" "worker" "sub"
      emit_routing_role "frontend_engineer" "$main_runtime" "$main_model" "$main_reasoning" "worker" "sub"
      emit_routing_role "security_engineer" "$main_runtime" "$main_model" "$main_reasoning" "worker" "sub"
      emit_routing_role "agents_compliance_reviewer" "$main_runtime" "$main_model" "$main_reasoning" "default" "sub"
      emit_routing_role "jazz_reviewer" "$opposite_runtime" "$opposite_model" "$opposite_reasoning" "default" "sub"
      emit_routing_role "codex_reviewer" "$main_runtime" "$main_model" "$main_reasoning" "default" "sub"
      emit_routing_role "manual_qa" "$main_runtime" "$main_model" "$main_reasoning" "default" "sub"
      emit_routing_role "task_verification" "$main_runtime" "$main_model" "$main_reasoning" "default" "sub"
      ;;
    "$RUNTIME_PROVIDER_CLAUDE")
      emit_routing_role "senior_engineer" "$opposite_runtime" "$opposite_model" "$opposite_reasoning" "explorer" "sub"
      emit_routing_role "librarian" "$main_runtime" "$main_model" "$main_reasoning" "default" "sub"
      emit_routing_role "smoke_test_planner" "$opposite_runtime" "$opposite_model" "$opposite_reasoning" "default" "sub"
      emit_routing_role "alternative_pm" "$opposite_runtime" "$opposite_model" "$opposite_reasoning" "default" "sub"
      emit_routing_role "researcher" "$main_runtime" "$main_model" "$main_reasoning" "default" "sub"
      emit_routing_role "backend_engineer" "$main_runtime" "$main_model" "$main_reasoning" "worker" "sub"
      emit_routing_role "frontend_engineer" "$main_runtime" "$main_model" "$main_reasoning" "worker" "sub"
      emit_routing_role "security_engineer" "$main_runtime" "$main_model" "$main_reasoning" "worker" "sub"
      emit_routing_role "agents_compliance_reviewer" "$main_runtime" "$main_model" "$main_reasoning" "default" "sub"
      emit_routing_role "jazz_reviewer" "$opposite_runtime" "$opposite_model" "$opposite_reasoning" "default" "sub"
      emit_routing_role "codex_reviewer" "$main_runtime" "$main_model" "$main_reasoning" "default" "sub"
      emit_routing_role "manual_qa" "$main_runtime" "$main_model" "$main_reasoning" "default" "sub"
      emit_routing_role "task_verification" "$main_runtime" "$main_model" "$main_reasoning" "default" "sub"
      ;;
  esac
}

normalize_version() {
  local value="$1"
  value="${value#v}"
  printf '%s' "$value"
}

bool_from_string() {
  local raw
  raw="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"

  case "$raw" in
    1|true|yes|on)
      echo 1
      ;;
    0|false|no|off)
      echo 0
      ;;
    *)
      return 1
      ;;
  esac
}

resolve_bool_setting() {
  local env_name="$1"
  local state_val="$2"
  local fallback="$3"
  local env_val="${!env_name:-}"
  local resolved

  if [ -n "$env_val" ]; then
    resolved="$(bool_from_string "$env_val" || true)"
    [ -n "$resolved" ] || die "Invalid boolean for $env_name: $env_val"
    echo "$resolved"
    return 0
  fi

  if [ -n "$state_val" ] && [ "$state_val" != "null" ]; then
    resolved="$(bool_from_string "$state_val" || true)"
    if [ -n "$resolved" ]; then
      echo "$resolved"
      return 0
    fi
  fi

  echo "$fallback"
}

semver_validate() {
  local v="$1"
  [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]
}

semver_main_and_pre() {
  local v="$1"
  local core pre

  core="$v"
  pre=""

  if [[ "$v" == *-* ]]; then
    core="${v%%-*}"
    pre="${v#*-}"
  fi

  printf '%s\n%s\n' "$core" "$pre"
}

semver_compare() {
  local a b a_core b_core a_pre b_pre
  local a_major a_minor a_patch b_major b_minor b_patch
  local i max ai bi
  local -a a_parts b_parts

  a="$(normalize_version "$1")"
  b="$(normalize_version "$2")"

  semver_validate "$a" || die "Invalid semver value: $a"
  semver_validate "$b" || die "Invalid semver value: $b"

  a_core="$(semver_main_and_pre "$a" | sed -n '1p')"
  a_pre="$(semver_main_and_pre "$a" | sed -n '2p')"
  b_core="$(semver_main_and_pre "$b" | sed -n '1p')"
  b_pre="$(semver_main_and_pre "$b" | sed -n '2p')"

  IFS='.' read -r a_major a_minor a_patch <<<"$a_core"
  IFS='.' read -r b_major b_minor b_patch <<<"$b_core"

  if [ "$a_major" -gt "$b_major" ]; then echo 1; return 0; fi
  if [ "$a_major" -lt "$b_major" ]; then echo -1; return 0; fi

  if [ "$a_minor" -gt "$b_minor" ]; then echo 1; return 0; fi
  if [ "$a_minor" -lt "$b_minor" ]; then echo -1; return 0; fi

  if [ "$a_patch" -gt "$b_patch" ]; then echo 1; return 0; fi
  if [ "$a_patch" -lt "$b_patch" ]; then echo -1; return 0; fi

  if [ -z "$a_pre" ] && [ -n "$b_pre" ]; then echo 1; return 0; fi
  if [ -n "$a_pre" ] && [ -z "$b_pre" ]; then echo -1; return 0; fi
  if [ -z "$a_pre" ] && [ -z "$b_pre" ]; then echo 0; return 0; fi

  IFS='.' read -r -a a_parts <<<"$a_pre"
  IFS='.' read -r -a b_parts <<<"$b_pre"

  max="${#a_parts[@]}"
  if [ "${#b_parts[@]}" -gt "$max" ]; then
    max="${#b_parts[@]}"
  fi

  for ((i = 0; i < max; i++)); do
    ai="${a_parts[$i]-}"
    bi="${b_parts[$i]-}"

    if [ -z "$ai" ] && [ -n "$bi" ]; then echo -1; return 0; fi
    if [ -n "$ai" ] && [ -z "$bi" ]; then echo 1; return 0; fi
    if [ -z "$ai" ] && [ -z "$bi" ]; then echo 0; return 0; fi

    if [[ "$ai" =~ ^[0-9]+$ ]] && [[ "$bi" =~ ^[0-9]+$ ]]; then
      if [ "$ai" -gt "$bi" ]; then echo 1; return 0; fi
      if [ "$ai" -lt "$bi" ]; then echo -1; return 0; fi
      continue
    fi

    if [[ "$ai" =~ ^[0-9]+$ ]] && [[ ! "$bi" =~ ^[0-9]+$ ]]; then
      echo -1
      return 0
    fi

    if [[ ! "$ai" =~ ^[0-9]+$ ]] && [[ "$bi" =~ ^[0-9]+$ ]]; then
      echo 1
      return 0
    fi

    if [[ "$ai" > "$bi" ]]; then echo 1; return 0; fi
    if [[ "$ai" < "$bi" ]]; then echo -1; return 0; fi
  done

  echo 0
}

semver_sort_unique() {
  local line existing cmp inserted sorted_item
  local -a raw=() sorted=() next=()

  while IFS= read -r line; do
    line="$(normalize_version "$line")"
    [ -n "$line" ] || continue
    semver_validate "$line" || continue

    existing=0
    for sorted_item in "${raw[@]-}"; do
      if [ "$sorted_item" = "$line" ]; then
        existing=1
        break
      fi
    done
    [ "$existing" -eq 1 ] && continue
    raw+=("$line")
  done

  for line in "${raw[@]-}"; do
    if [ "${#sorted[@]}" -eq 0 ]; then
      sorted+=("$line")
      continue
    fi

    next=()
    inserted=0
    for sorted_item in "${sorted[@]}"; do
      cmp="$(semver_compare "$line" "$sorted_item")"
      if [ "$inserted" -eq 0 ] && [ "$cmp" -lt 0 ]; then
        next+=("$line")
        inserted=1
      fi
      next+=("$sorted_item")
    done

    if [ "$inserted" -eq 0 ]; then
      next+=("$line")
    fi

    sorted=("${next[@]}")
  done

  printf '%s\n' "${sorted[@]-}"
}

pick_latest_version() {
  local versions="$1"
  printf '%s\n' "$versions" | awk 'NF' | tail -n1
}

version_in_list() {
  local needle="$1"
  local list="$2"
  local item

  while IFS= read -r item; do
    [ -n "$item" ] || continue
    if [ "$item" = "$needle" ]; then
      return 0
    fi
  done <<<"$list"

  return 1
}

compute_pending_versions() {
  local versions="$1"
  local baseline="$2"
  local version cmp latest

  if [ -z "$versions" ]; then
    return 0
  fi

  if [ -z "$baseline" ]; then
    latest="$(pick_latest_version "$versions")"
    [ -n "$latest" ] && echo "$latest"
    return 0
  fi

  semver_validate "$baseline" || die "State baseline is not valid semver: $baseline"

  while IFS= read -r version; do
    [ -n "$version" ] || continue
    cmp="$(semver_compare "$version" "$baseline")"
    if [ "$cmp" -gt 0 ]; then
      echo "$version"
    fi
  done <<<"$versions"
}

json_array_from_newlines() {
  awk 'NF { print }' | jq -R . | jq -s .
}

hash_string() {
  local input="$1"

  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$input" | shasum -a 256 | awk '{print $1}'
    return 0
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$input" | sha256sum | awk '{print $1}'
    return 0
  fi

  if command -v openssl >/dev/null 2>&1; then
    printf '%s' "$input" | openssl dgst -sha256 | awk '{print $NF}'
    return 0
  fi

  printf '%s' "no-hash-tool"
}

latest_semver_from_text() {
  local payload="$1"
  local parsed

  parsed="$({ printf '%s' "$payload" | grep -Eo "$SEMVER_PATTERN" || true; } | sed 's/^v//' | semver_sort_unique | tail -n1)"
  [ -n "$parsed" ] || return 1
  printf '%s' "$parsed"
}

normalize_text_line() {
  local raw="$1"
  printf '%s' "$raw" | tr '\r\t' '  ' | sed -E 's/[[:space:]]+/ /g; s/^[[:space:]]+//; s/[[:space:]]+$//'
}

extract_codex_entry_lines_from_changelog() {
  local payload="$1"
  local include_prerelease="$2"
  local normalized codex_cli_lines codex_lines parsed
  local line version normalized_version

  normalized="$(printf '%s' "$payload" | sed 's/<[^>]*>/ /g' | tr '\r' '\n')"

  # Prefer Codex CLI-labelled lines to avoid unrelated semver values from shared site chrome/content.
  codex_cli_lines="$(printf '%s\n' "$normalized" | grep -Ei 'codex[[:space:]-]*cli' || true)"
  if [ -n "$codex_cli_lines" ]; then
    codex_lines="$codex_cli_lines"
  else
    codex_lines="$(printf '%s\n' "$normalized" | grep -Ei 'codex' || true)"
  fi
  [ -n "$codex_lines" ] || return 1

  while IFS= read -r line; do
    line="$(normalize_text_line "$line")"
    [ -n "$line" ] || continue

    parsed="$(printf '%s\n' "$line" | grep -Eo "$SEMVER_PATTERN" || true)"
    [ -n "$parsed" ] || continue

    while IFS= read -r version; do
      normalized_version="$(normalize_version "$version")"
      [ -n "$normalized_version" ] || continue
      semver_validate "$normalized_version" || continue

      if [ -z "$codex_cli_lines" ]; then
        # Fallback extraction is noisier; clamp to expected major range for Codex release identifiers.
        if ! printf '%s' "$normalized_version" | grep -Eq '^(0|1)\.'; then
          continue
        fi
      fi

      if [ "$include_prerelease" -eq 0 ] && [[ "$normalized_version" == *-* ]]; then
        continue
      fi

      printf '%s\t%s\n' "$normalized_version" "$line"
    done <<<"$parsed"
  done <<<"$codex_lines" | awk -F '\t' '!seen[$1 FS $2]++'
}

extract_codex_versions_from_changelog() {
  local payload="$1"
  local include_prerelease="$2"
  local entries

  entries="$(extract_codex_entry_lines_from_changelog "$payload" "$include_prerelease" || true)"
  [ -n "$entries" ] || return 1

  printf '%s\n' "$entries" | awk -F '\t' 'NF { print $1 }' | semver_sort_unique
}

filter_entries_by_versions() {
  local entries="$1"
  local versions="$2"
  local version summary

  while IFS=$'\t' read -r version summary; do
    [ -n "$version" ] || continue
    if version_in_list "$version" "$versions"; then
      printf '%s\t%s\n' "$version" "$summary"
    fi
  done <<<"$entries"
}

is_pipeline_relevant_change() {
  local summary_lc="$1"
  local include_pattern="${PM_SELF_UPDATE_RELEVANCE_INCLUDE_REGEX:-$DEFAULT_RELEVANCE_INCLUDE_PATTERN}"
  local exclude_pattern="${PM_SELF_UPDATE_RELEVANCE_EXCLUDE_REGEX:-$DEFAULT_RELEVANCE_EXCLUDE_PATTERN}"

  if [ -n "$exclude_pattern" ] && printf '%s' "$summary_lc" | grep -Eq "$exclude_pattern"; then
    return 1
  fi

  if [ -n "$include_pattern" ] && printf '%s' "$summary_lc" | grep -Eq "$include_pattern"; then
    return 0
  fi

  return 1
}

integration_plan_for_change() {
  local summary_lc="$1"
  local integration improvement

  if printf '%s' "$summary_lc" | grep -Eq 'approval|gate|workflow|plan|beads'; then
    integration="Update PM phase transitions and approval checks to align with this change."
    improvement="Reduces invalid handoffs and keeps orchestration flow deterministic."
  elif printf '%s' "$summary_lc" | grep -Eq 'state|checkpoint|schema|migration'; then
    integration="Update self-update state handling and checkpoint semantics."
    improvement="Improves reliability of version tracking and rollback safety."
  elif printf '%s' "$summary_lc" | grep -Eq 'test|qa|smoke|regression'; then
    integration="Extend smoke and regression coverage for the affected self-update path."
    improvement="Catches orchestration regressions before release."
  elif printf '%s' "$summary_lc" | grep -Eq 'agent|mcp|tool|command|cli|automation'; then
    integration="Adjust command routing and tool orchestration behavior for this upstream change."
    improvement="Keeps orchestrator automation compatible with Codex runtime updates."
  else
    integration="Review this changelog item in discovery and map it to orchestrator pipeline behavior."
    improvement="Ensures relevant upstream updates are integrated with explicit intent."
  fi

  printf '%s\t%s' "$integration" "$improvement"
}

entries_to_json_array() {
  local entries="$1"
  local tmp version summary normalized_summary obj

  tmp="$(mktemp)"

  while IFS=$'\t' read -r version summary; do
    [ -n "$version" ] || continue
    normalized_summary="$(normalize_text_line "$summary")"
    [ -n "$normalized_summary" ] || continue
    obj="$(jq -nc --arg version "$version" --arg change "$normalized_summary" '{version: $version, change: $change}')"
    printf '%s\n' "$obj" >>"$tmp"
  done <<<"$entries"

  if [ -s "$tmp" ]; then
    jq -cs '.' "$tmp"
  else
    echo "[]"
  fi

  rm -f "$tmp"
}

build_relevance_and_plan_json() {
  local entries="$1"
  local relevant_tmp ignored_tmp plan_tmp
  local version summary normalized_summary summary_lc reason obj plan_fields integration improvement

  relevant_tmp="$(mktemp)"
  ignored_tmp="$(mktemp)"
  plan_tmp="$(mktemp)"

  SELF_UPDATE_ENTRY_TOTAL=0
  SELF_UPDATE_RELEVANT_COUNT=0
  SELF_UPDATE_IGNORED_COUNT=0
  SELF_UPDATE_RELEVANT_JSON="[]"
  SELF_UPDATE_IGNORED_JSON="[]"
  SELF_UPDATE_PLAN_JSON="[]"

  while IFS=$'\t' read -r version summary; do
    [ -n "$version" ] || continue

    normalized_summary="$(normalize_text_line "$summary")"
    [ -n "$normalized_summary" ] || continue
    summary_lc="$(printf '%s' "$normalized_summary" | tr '[:upper:]' '[:lower:]')"

    SELF_UPDATE_ENTRY_TOTAL=$((SELF_UPDATE_ENTRY_TOTAL + 1))
    if is_pipeline_relevant_change "$summary_lc"; then
      reason="matches_pipeline_relevance_policy"
      obj="$(jq -nc --arg version "$version" --arg change "$normalized_summary" --arg reason "$reason" '{version: $version, change: $change, reason: $reason}')"
      printf '%s\n' "$obj" >>"$relevant_tmp"
      SELF_UPDATE_RELEVANT_COUNT=$((SELF_UPDATE_RELEVANT_COUNT + 1))

      plan_fields="$(integration_plan_for_change "$summary_lc")"
      integration="$(printf '%s' "$plan_fields" | cut -f1)"
      improvement="$(printf '%s' "$plan_fields" | cut -f2-)"
      obj="$(jq -nc --arg version "$version" --arg change "$normalized_summary" --arg integration "$integration" --arg improvement "$improvement" '{version: $version, change: $change, integration: $integration, expected_improvement: $improvement}')"
      printf '%s\n' "$obj" >>"$plan_tmp"
    else
      reason="filtered_non_pipeline_change"
      obj="$(jq -nc --arg version "$version" --arg change "$normalized_summary" --arg reason "$reason" '{version: $version, change: $change, reason: $reason}')"
      printf '%s\n' "$obj" >>"$ignored_tmp"
      SELF_UPDATE_IGNORED_COUNT=$((SELF_UPDATE_IGNORED_COUNT + 1))
    fi
  done <<<"$entries"

  if [ -s "$relevant_tmp" ]; then
    SELF_UPDATE_RELEVANT_JSON="$(jq -cs '.' "$relevant_tmp")"
  fi
  if [ -s "$ignored_tmp" ]; then
    SELF_UPDATE_IGNORED_JSON="$(jq -cs '.' "$ignored_tmp")"
  fi
  if [ -s "$plan_tmp" ]; then
    SELF_UPDATE_PLAN_JSON="$(jq -cs '.' "$plan_tmp")"
  fi

  rm -f "$relevant_tmp" "$ignored_tmp" "$plan_tmp"
}

fetch_url() {
  local url="$1"
  local payload_override="${2:-}"
  local timeout="${PM_SELF_UPDATE_TIMEOUT_SECONDS:-20}"

  if [ -n "$payload_override" ]; then
    printf '%s' "$payload_override"
    return 0
  fi

  curl -fsSL --max-time "$timeout" "$url"
}

fetch_release_effective_url() {
  local release_url="$1"
  local release_redirect_override="${PM_SELF_UPDATE_RELEASE_REDIRECT_URL:-}"
  local timeout="${PM_SELF_UPDATE_TIMEOUT_SECONDS:-20}"

  if [ -n "$release_redirect_override" ]; then
    printf '%s' "$release_redirect_override"
    return 0
  fi

  curl -fsSLI --max-time "$timeout" -o /dev/null -w '%{url_effective}' "$release_url"
}

fetch_npm_tags_payload() {
  local npm_url="$1"
  local npm_override="${PM_SELF_UPDATE_NPM_TAGS_PAYLOAD:-}"
  local timeout="${PM_SELF_UPDATE_TIMEOUT_SECONDS:-20}"

  if [ -n "$npm_override" ]; then
    printf '%s' "$npm_override"
    return 0
  fi

  curl -fsSL --max-time "$timeout" "$npm_url"
}

state_init_json_v2() {
  local checked_at="$1"

  cat <<EOF
{
  "schema_version": 2,
  "latest_processed_codex_version": "",
  "pending_codex_version": "",
  "pending_codex_versions": [],
  "pending_batch": {
    "from_version": "",
    "to_version": "",
    "versions": [],
    "entry_analysis": {
      "total_entries": 0,
      "relevant_entries": 0,
      "ignored_entries": 0,
      "entries": [],
      "relevant": [],
      "ignored": [],
      "integration_plan": []
    },
    "source_of_truth": "$DEFAULT_CHANGELOG_URL",
    "corroboration": {
      "release_version": "",
      "npm_latest": "",
      "npm_alpha": ""
    },
    "mismatch_flags": [],
    "batch_id": "",
    "generated_at": ""
  },
  "last_completed_batch": {},
  "last_checked_codex_version": "",
  "last_check": {
    "checked_at": "$checked_at",
    "changelog_version": "",
    "changelog_versions": [],
    "release_version": "",
    "npm_latest": "",
    "npm_alpha": "",
    "selected_version": "",
    "sources": [
      "$DEFAULT_CHANGELOG_URL",
      "$DEFAULT_RELEASE_URL",
      "$DEFAULT_NPM_TAGS_URL"
    ],
    "mismatch_flags": []
  },
  "feature_flags": {
    "include_prerelease": true,
    "strict_mismatch": false
  },
  "last_checkpoint_ref": "",
  "updated_at": "$checked_at"
}
EOF
}

migrate_state_v1_to_v2() {
  local state_file="$1"
  local now="$2"
  local tmp

  tmp="$(mktemp "${state_file}.tmp.XXXX")"

  jq \
    --arg now "$now" \
    --arg changelog_url "$DEFAULT_CHANGELOG_URL" \
    --arg release_url "$DEFAULT_RELEASE_URL" \
    --arg npm_url "$DEFAULT_NPM_TAGS_URL" \
    '
      .schema_version = 2 |
      .pending_codex_versions = (if (.pending_codex_version // "") == "" then [] else [(.pending_codex_version | ltrimstr("v"))] end) |
      .pending_batch = {
        from_version: (.latest_processed_codex_version // ""),
        to_version: (.pending_codex_version // "" | ltrimstr("v")),
        versions: (if (.pending_codex_version // "") == "" then [] else [(.pending_codex_version | ltrimstr("v"))] end),
        entry_analysis: {
          total_entries: (if (.pending_codex_version // "") == "" then 0 else 1 end),
          relevant_entries: (if (.pending_codex_version // "") == "" then 0 else 1 end),
          ignored_entries: 0,
          entries: (if (.pending_codex_version // "") == "" then [] else [{version: (.pending_codex_version | ltrimstr("v")), change: "legacy pending codex version"}] end),
          relevant: (if (.pending_codex_version // "") == "" then [] else [{version: (.pending_codex_version | ltrimstr("v")), change: "legacy pending codex version", reason: "legacy_migration_default_relevant"}] end),
          ignored: [],
          integration_plan: []
        },
        source_of_truth: $changelog_url,
        corroboration: {
          release_version: (.last_check.release_version // "" | ltrimstr("v")),
          npm_latest: "",
          npm_alpha: ""
        },
        mismatch_flags: [],
        batch_id: "",
        generated_at: (.updated_at // $now)
      } |
      .last_completed_batch = (.last_completed_batch // {}) |
      .last_check = {
        checked_at: (.last_check.checked_at // .updated_at // $now),
        changelog_version: (.last_check.changelog_version // "" | ltrimstr("v")),
        changelog_versions: (if (.last_check.changelog_version // "") == "" then [] else [(.last_check.changelog_version | ltrimstr("v"))] end),
        release_version: (.last_check.release_version // "" | ltrimstr("v")),
        npm_latest: "",
        npm_alpha: "",
        selected_version: (.last_check.selected_version // .pending_codex_version // "" | ltrimstr("v")),
        sources: [$changelog_url, $release_url, $npm_url],
        mismatch_flags: []
      } |
      .feature_flags = {
        include_prerelease: true,
        strict_mismatch: false
      } |
      .pending_codex_version = (.pending_codex_version // "" | ltrimstr("v")) |
      .latest_processed_codex_version = (.latest_processed_codex_version // "" | ltrimstr("v")) |
      .last_checked_codex_version = (.last_checked_codex_version // .last_check.selected_version // "" | ltrimstr("v")) |
      .updated_at = (.updated_at // $now)
    ' "$state_file" >"$tmp"

  mv "$tmp" "$state_file"
}

validate_state_file() {
  local state_file="$1"

  jq -e '
    .schema_version == 2 and
    (.latest_processed_codex_version | type == "string") and
    (.pending_codex_version | type == "string") and
    (.pending_codex_versions | type == "array") and
    (.pending_batch | type == "object") and
    (.pending_batch.from_version | type == "string") and
    (.pending_batch.to_version | type == "string") and
    (.pending_batch.versions | type == "array") and
    (.pending_batch.entry_analysis | type == "object") and
    (.pending_batch.entry_analysis.total_entries | type == "number") and
    (.pending_batch.entry_analysis.relevant_entries | type == "number") and
    (.pending_batch.entry_analysis.ignored_entries | type == "number") and
    (.pending_batch.entry_analysis.entries | type == "array") and
    (.pending_batch.entry_analysis.relevant | type == "array") and
    (.pending_batch.entry_analysis.ignored | type == "array") and
    (.pending_batch.entry_analysis.integration_plan | type == "array") and
    (.pending_batch.source_of_truth | type == "string") and
    (.pending_batch.corroboration | type == "object") and
    (.pending_batch.corroboration.release_version | type == "string") and
    (.pending_batch.corroboration.npm_latest | type == "string") and
    (.pending_batch.corroboration.npm_alpha | type == "string") and
    (.pending_batch.mismatch_flags | type == "array") and
    (.pending_batch.batch_id | type == "string") and
    (.pending_batch.generated_at | type == "string") and
    (.last_completed_batch | type == "object") and
    (.last_checked_codex_version | type == "string") and
    (.last_check | type == "object") and
    (.last_check.checked_at | type == "string") and
    (.last_check.changelog_version | type == "string") and
    (.last_check.changelog_versions | type == "array") and
    (.last_check.release_version | type == "string") and
    (.last_check.npm_latest | type == "string") and
    (.last_check.npm_alpha | type == "string") and
    (.last_check.selected_version | type == "string") and
    (.last_check.sources | type == "array") and
    (.last_check.mismatch_flags | type == "array") and
    (.feature_flags | type == "object") and
    (.feature_flags.include_prerelease | type == "boolean") and
    (.feature_flags.strict_mismatch | type == "boolean") and
    (.last_checkpoint_ref | type == "string") and
    (.updated_at | type == "string")
  ' "$state_file" >/dev/null
}

ensure_state_file() {
  local state_file="$1"
  local now schema

  now="$(now_utc)"
  mkdir -p "$(dirname "$state_file")"

  if [ ! -f "$state_file" ]; then
    state_init_json_v2 "$now" >"$state_file"
  fi

  schema="$(jq -r '.schema_version // 0' "$state_file" 2>/dev/null || echo 0)"
  if [ "$schema" = "1" ]; then
    migrate_state_v1_to_v2 "$state_file" "$now"
  fi

  if ! validate_state_file "$state_file"; then
    die "State file is invalid/corrupt and will not be mutated: $state_file"
  fi
}

state_get() {
  local state_file="$1"
  local expr="$2"
  jq -r "$expr" "$state_file"
}

state_update_with_args() {
  local state_file="$1"
  shift
  local tmp

  tmp="$(mktemp "${state_file}.tmp.XXXX")"
  jq "$@" "$state_file" >"$tmp"
  mv "$tmp" "$state_file"
}

checkpoint_commit() {
  local state_file="$1"
  local version="$2"
  local dry_run="$3"
  local root rel sha before_sha after_sha

  root="$(repo_root)"
  case "$state_file" in
    "$root"/*)
      rel="${state_file#"$root"/}"
      ;;
    *)
      die "State file must be inside git repository root to create checkpoint commit: $state_file"
      ;;
  esac

  if [ "$dry_run" -eq 1 ]; then
    echo "CHECKPOINT_DRY_RUN|state_file=$rel|version=$version"
    return 0
  fi

  git -C "$root" add -- "$rel"
  if git -C "$root" diff --cached --quiet -- "$rel"; then
    die "No staged state change found for checkpoint commit"
  fi

  before_sha="$(git -C "$root" rev-parse HEAD 2>/dev/null || true)"
  if ! git -C "$root" commit -m "chore(pm-self-update): checkpoint codex version $version" -- "$rel" >/dev/null; then
    return 1
  fi
  after_sha="$(git -C "$root" rev-parse HEAD 2>/dev/null || true)"
  if [ -z "$after_sha" ] || [ "$after_sha" = "$before_sha" ]; then
    return 1
  fi
  sha="$after_sha"
  echo "CHECKPOINT_CREATED|version=$version|commit=$sha|state_file=$rel"
}

assert_open_questions_empty() {
  local prd_path="$1"
  local body

  [ -f "$prd_path" ] || die "PRD path not found: $prd_path"

  body="$({
    awk '
      BEGIN { in_open=0 }
      /^## 14\. Open Questions/ { in_open=1; next }
      /^## / && in_open { exit }
      in_open { print }
    ' "$prd_path"
  })"

  if printf '%s' "$body" | grep -Eq '[^[:space:]]'; then
    die "PRD Open Questions must be empty before completion: $prd_path"
  fi
}

assert_prd_covers_versions() {
  local prd_path="$1"
  local versions="$2"
  local version content missing_list
  local -a missing=()

  [ -f "$prd_path" ] || die "PRD path not found: $prd_path"
  content="$(cat "$prd_path")"

  while IFS= read -r version; do
    [ -n "$version" ] || continue
    if ! grep -Fq "$version" <<<"$content" && ! grep -Fq "v$version" <<<"$content"; then
      missing+=("$version")
    fi
  done <<<"$versions"

  if [ "${#missing[@]}" -gt 0 ]; then
    missing_list="$(printf '%s,' "${missing[@]}" | sed 's/,$//')"
    die "PRD evidence missing pending versions: $missing_list"
  fi
}

print_help_output() {
  cat <<'EOF'
$pm help

Supported invocations:
- $pm plan: <feature request>
- $pm plan big feature: <feature request>
- $pm self-check
- $pm execution-mode show|set|reset
- $pm claude-contract validate-context|evaluate-response|run-loop
- $pm telemetry init-db|log-step|query-task|query-run
- $pm self-update
- $pm help

Required PM phase order:
Discovery -> PRD -> Awaiting PRD Approval -> Beads Planning -> Awaiting Beads Approval -> Team Lead Orchestration -> Implementation -> Post-Implementation Reviews -> Review Iteration -> Manual QA Smoke Tests -> Awaiting Final Review

Approval gates:
- PRD approval reply must be exactly: approved
- Beads approval reply must be exactly: approved
- Execution-mode gate runs before Discovery on both plan routes
- Execution-mode options are:
  - Dynamic Cross-Runtime
  - Main Runtime Only
- Outer runtime is inferred fresh from the running Codex or Claude session on every plan gate
- Interactive `/pm` plan runs should ask for execution mode on every new planning invocation and pass an explicit `--mode` to the helper gate
- Selected execution mode persists in .codex; direct helper usage may reuse it by default when no `--mode` is supplied
- `Dynamic Cross-Runtime` uses the opposite-provider MCP path for routed support roles and blocks when that path is unavailable
- `Main Runtime Only` keeps all roles on the detected outer runtime and does not require the opposite-provider MCP path
- If the plan gate reports `PLAN_ROUTE_BLOCKED` or `discovery_can_start=0`, do not enter Discovery or any downstream phase
- If the outer runtime cannot be positively identified, fail closed, emit `RUNTIME_DETECTION_ERROR`, and persist the run outcome in telemetry
- If a required routed MCP path later fails at runtime (for example `no supported agent type`), block the current phase and return control to PM with reason-specific remediation

Self-update policy:
- Manual-only invocation
- Changelog website is source-of-truth
- Stable + prerelease batch verification
- Filter non-pipeline changes and emit integration-plan suggestions for relevant updates
- Completion requires PRD evidence coverage for all pending versions

Self-check policy:
- Deterministic fixture suite with verbose artifact capture under `.codex/self-check-runs`
- Fail whole run when Claude registration, command executability, or session usability is unhealthy
- Artifact-layer defects must end `issues_detected`, never `clean`
- Persist structured snapshot evidence: command source, PATH override source, elapsed time, exit status/signal, timeout state, pid/process state, and partial stdout/stderr
- Print `SELF_CHECK_EVENT` warnings/errors directly to console while capturing artifact paths for diagnosis
- Outer healer may package repairs through normal PM flow only after self-check emits healer-ready artifacts
- Healer must not bypass approvals or perform ungated implementation during self-check

Runtime policy:
- Provider-neutral execution modes with runtime-inferred routing
- Claude usage is permitted only through claude-code MCP
- Codex secondary-runtime usage inside Claude is permitted only through codex-worker MCP
- Blocked routed-runtime modes or phases must not continue in degraded fallback
- Phase blocks must emit warning telemetry and phase error reporting

Issue reporting policy:
- Report issues explicitly when they occur (no silent failures)
- Non-critical issues should continue workflow execution
- End each phase with a Phase Error Summary (use "none" when clean)

Claude delegation contract:
- Validate context pack before external Claude invocation:
  - pm-command.sh claude-contract validate-context --context-file <json> --role <role>
- Require structured missing-context handshake marker in Claude responses:
  - CONTEXT_REQUEST|needed_fields=<csv>|questions=<numbered items>
- Parse response before accepting completion:
  - pm-command.sh claude-contract evaluate-response --response-file <txt> --session-id <id> --role <role>
- Optional wrapper for multi-step sessions:
  - pm-command.sh claude-contract run-loop --context-file <json> --response-file <txt> [--response-file <txt> ...] --session-id <id> --role <role>
EOF
}

run_execution_mode() {
  local action="${1:-show}"
  local state_file=""
  local mode=""
  local legacy_profile=""
  local selected_mode selected_label updated_at

  shift || true

  while [ $# -gt 0 ]; do
    case "$1" in
      --state-file)
        state_file="${2:-}"
        shift 2
        ;;
      --mode)
        mode="${2:-}"
        shift 2
        ;;
      --profile)
        legacy_profile="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown execution-mode argument: $1"
        ;;
    esac
  done

  [ -n "$state_file" ] || state_file="$(default_lead_model_state_file)"

  if [ "$action" = "reset" ]; then
    mkdir -p "$(dirname "$state_file")"
    if [ ! -f "$state_file" ] || ! validate_execution_mode_state_file "$state_file" >/dev/null 2>&1; then
      execution_mode_state_init_json "$(now_utc)" >"$state_file"
    fi
  else
    ensure_execution_mode_state_file "$state_file"
  fi

  if [ -z "$mode" ] && [ -n "$legacy_profile" ]; then
    mode="$legacy_profile"
  fi

  case "$action" in
    show)
      ;;
    set)
      [ -n "$mode" ] || die "--mode is required for execution-mode set"
      validate_execution_mode "$mode" || die "Invalid execution mode: $mode"
      execution_mode_state_set_mode "$state_file" "$mode" "manual_set"
      ;;
    reset)
      execution_mode_state_set_mode "$state_file" "$EXECUTION_MODE_DEFAULT" "manual_reset"
      ;;
    *)
      die "Unknown execution-mode action: $action"
      ;;
  esac

  selected_mode="$(execution_mode_state_get_mode "$state_file")"
  selected_label="$(execution_mode_label_for_mode "$selected_mode")"
  updated_at="$(execution_mode_state_get_updated_at "$state_file")"
  echo "EXECUTION_MODE_STATE|action=$action|mode=$selected_mode|label=$selected_label|state_file=$(display_path "$state_file")|updated_at=$updated_at"
}

run_lead_model() {
  run_execution_mode "$@"
}

run_plan_gate() {
  local route=""
  local state_file=""
  local mode_override=""
  local legacy_profile_override=""
  local selection_source=""
  local persisted_mode selected_mode selected_label
  local outer_runtime="" outer_runtime_source="" outer_runtime_detail=""
  local selected_main_runtime="" selected_main_model="" selected_main_reasoning_effort=""
  local block_reason="" block_remediation="" block_detail="" next_action="start_discovery"
  local requires_claude_mcp=0 requires_codex_worker_mcp=0
  local gate_started_at gate_ended_at gate_duration_ms
  local gate_start_ms gate_end_ms gate_run_id workspace_path metadata_json
  local claude_model claude_reasoning codex_model codex_reasoning

  gate_started_at="$(now_utc)"
  gate_start_ms="$(epoch_ms)"
  workspace_path="$(conductor_workspace_path)"
  gate_run_id="${PM_WORKFLOW_RUN_ID:-pm-plan-gate-$(date +%s)-$$}::${route:-pending}"

  while [ $# -gt 0 ]; do
    case "$1" in
      --route)
        route="${2:-}"
        shift 2
        ;;
      --mode)
        mode_override="${2:-}"
        shift 2
        ;;
      --lead-model)
        legacy_profile_override="${2:-}"
        shift 2
        ;;
      --state-file)
        state_file="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown plan gate argument: $1"
        ;;
    esac
  done

  [ -n "$route" ] || die "--route is required for plan gate"
  case "$route" in
    default|big-feature)
      ;;
    *)
      die "Invalid --route for plan gate: $route"
      ;;
  esac

  gate_run_id="${PM_WORKFLOW_RUN_ID:-pm-plan-gate-$(date +%s)-$$}::${route}"
  [ -n "$state_file" ] || state_file="$(default_lead_model_state_file)"
  ensure_execution_mode_state_file "$state_file"
  persisted_mode="$(execution_mode_state_get_mode "$state_file")"

  if [ -z "$mode_override" ] && [ -n "$legacy_profile_override" ]; then
    mode_override="$legacy_profile_override"
  fi

  if [ -n "$mode_override" ]; then
    validate_execution_mode "$mode_override" || die "Invalid execution mode override: $mode_override"
    execution_mode_state_set_mode "$state_file" "$mode_override" "plan_gate_override"
  fi

  selected_mode="$(execution_mode_state_get_mode "$state_file")"
  selected_label="$(execution_mode_label_for_mode "$selected_mode")"
  selection_source="$(execution_mode_selection_source "$mode_override")"
  codex_model="$(resolved_codex_model)"
  codex_reasoning="$(resolved_codex_reasoning_effort)"
  claude_model="$(resolved_claude_model)"
  claude_reasoning="$(resolved_claude_reasoning_effort)"

  if ! detect_outer_runtime; then
    block_reason="runtime_detection_failed"
    block_remediation="Run PM from a positively identifiable Codex or Claude session, or set PM_PLAN_GATE_RUNTIME_OVERRIDE=codex|claude in a controlled environment."
    block_detail="${OUTER_RUNTIME_LAST_DETAIL:-Unable to positively identify the outer runtime.}"
    outer_runtime_source="${OUTER_RUNTIME_LAST_SOURCE:-unresolved}"
    echo "RUNTIME_DETECTION_ERROR|run_id=$gate_run_id|route=$route|workspace_path=$workspace_path|detection_status=failed|reason=$block_reason|detail=$block_detail|remediation=$block_remediation|source=$outer_runtime_source"
    metadata_json="$(jq -nc --arg state_file "$(display_path "$state_file")" '{state_file: $state_file}')"
    telemetry_record_runtime_detection_run_nonblocking \
      "$gate_run_id" "$route" "$workspace_path" "" "$selected_mode" "failed" \
      "$block_reason" "$block_detail" "$block_remediation" "$outer_runtime_source" \
      "$gate_started_at" "$(now_utc)" "$metadata_json"
    echo "PLAN_ROUTE_BLOCKED|route=$route|selected_mode=$selected_mode|selected_label=$selected_label|selection_source=$selection_source|outer_runtime=|reason=$block_reason|remediation=$block_remediation|detail=$block_detail|next_action=fix_runtime_detection|discovery_can_start=0"
    return 1
  fi

  outer_runtime="${OUTER_RUNTIME_LAST_VALUE:-}"
  outer_runtime_source="${OUTER_RUNTIME_LAST_SOURCE:-detected}"
  outer_runtime_detail="${OUTER_RUNTIME_LAST_DETAIL:-Outer runtime detected successfully.}"
  echo "RUNTIME_DETECTION|run_id=$gate_run_id|route=$route|workspace_path=$workspace_path|outer_runtime=$outer_runtime|source=$outer_runtime_source|detail=$outer_runtime_detail"
  echo "EXECUTION_MODE_GATE|route=$route|question=Select execution mode before Discovery|options=$EXECUTION_MODE_OPTION_DYNAMIC;$EXECUTION_MODE_OPTION_MAIN_ONLY|persisted_mode=$persisted_mode|selected_mode=$selected_mode|selected_label=$selected_label|selection_source=$selection_source|outer_runtime=$outer_runtime|outer_runtime_source=$outer_runtime_source|codex_model=$codex_model|codex_reasoning_effort=$codex_reasoning|claude_model=$claude_model|claude_reasoning_effort=$claude_reasoning|state_file=$(display_path "$state_file")"

  case "$outer_runtime" in
    "$RUNTIME_PROVIDER_CODEX")
      selected_main_runtime="codex-native"
      selected_main_model="$codex_model"
      selected_main_reasoning_effort="$codex_reasoning"
      if [ "$selected_mode" = "$EXECUTION_MODE_DYNAMIC" ]; then
        requires_claude_mcp=1
      fi
      ;;
    "$RUNTIME_PROVIDER_CLAUDE")
      selected_main_runtime="claude-native"
      selected_main_model="$claude_model"
      selected_main_reasoning_effort="$claude_reasoning"
      if [ "$selected_mode" = "$EXECUTION_MODE_DYNAMIC" ]; then
        requires_codex_worker_mcp=1
      fi
      ;;
  esac

  if [ "$requires_claude_mcp" -eq 1 ] && ! claude_mcp_available; then
    block_reason="${CLAUDE_MCP_LAST_REASON:-claude_code_mcp_unavailable}"
    block_remediation="${CLAUDE_MCP_LAST_REMEDIATION:-$CLAUDE_MCP_REMEDIATION_MISSING}"
    block_detail="${CLAUDE_MCP_LAST_DETAIL:-Claude MCP unavailable for dynamic cross-runtime mode.}"
    next_action="fix_claude_mcp_or_switch_to_main_runtime_only"
    echo "PLAN_ROUTE_BLOCKED|route=$route|selected_mode=$selected_mode|selected_label=$selected_label|selection_source=$selection_source|outer_runtime=$outer_runtime|reason=$block_reason|remediation=$block_remediation|detail=$block_detail|next_action=$next_action|discovery_can_start=0"
    metadata_json="$(jq -nc --arg state_file "$(display_path "$state_file")" '{state_file: $state_file}')"
    telemetry_record_runtime_detection_run_nonblocking \
      "$gate_run_id" "$route" "$workspace_path" "$outer_runtime" "$selected_mode" "blocked" \
      "$block_reason" "$block_detail" "$block_remediation" "$outer_runtime_source" \
      "$gate_started_at" "$(now_utc)" "$metadata_json"
    return 1
  fi

  if [ "$requires_codex_worker_mcp" -eq 1 ] && ! codex_worker_mcp_available; then
    block_reason="${CODEX_WORKER_MCP_LAST_REASON:-codex_worker_mcp_unavailable}"
    block_remediation="${CODEX_WORKER_MCP_LAST_REMEDIATION:-$CODEX_WORKER_MCP_REMEDIATION_MISSING}"
    block_detail="${CODEX_WORKER_MCP_LAST_DETAIL:-Codex worker MCP unavailable for dynamic cross-runtime mode.}"
    next_action="fix_codex_worker_mcp_or_switch_to_main_runtime_only"
    echo "PLAN_ROUTE_BLOCKED|route=$route|selected_mode=$selected_mode|selected_label=$selected_label|selection_source=$selection_source|outer_runtime=$outer_runtime|reason=$block_reason|remediation=$block_remediation|detail=$block_detail|next_action=$next_action|discovery_can_start=0"
    metadata_json="$(jq -nc --arg state_file "$(display_path "$state_file")" '{state_file: $state_file}')"
    telemetry_record_runtime_detection_run_nonblocking \
      "$gate_run_id" "$route" "$workspace_path" "$outer_runtime" "$selected_mode" "blocked" \
      "$block_reason" "$block_detail" "$block_remediation" "$outer_runtime_source" \
      "$gate_started_at" "$(now_utc)" "$metadata_json"
    return 1
  fi

  echo "ROUTING_PROFILE|route=$route|mode=$selected_mode|selection_source=$selection_source|outer_runtime=$outer_runtime|outer_runtime_source=$outer_runtime_source|main_runtime=$selected_main_runtime|main_model=$selected_main_model|main_reasoning_effort=$selected_main_reasoning_effort|fallback_active=0"
  emit_routing_matrix_for_mode "$outer_runtime" "$selected_mode"

  gate_ended_at="$(now_utc)"
  gate_end_ms="$(epoch_ms)"
  gate_duration_ms="$((gate_end_ms - gate_start_ms))"
  metadata_json="$(jq -nc \
    --arg route "$route" \
    --arg selection_source "$selection_source" \
    --arg outer_runtime "$outer_runtime" \
    --arg outer_runtime_source "$outer_runtime_source" \
    --arg selected_mode "$selected_mode" \
    '{route: $route, selection_source: $selection_source, outer_runtime: $outer_runtime, outer_runtime_source: $outer_runtime_source, selected_mode: $selected_mode, fallback_active: 0}')"
  telemetry_record_event_nonblocking \
    "$(telemetry_new_event_id "plan-gate" "complete")" \
    "${PM_WORKFLOW_RUN_ID:-plan-gate}" \
    "${PM_TASK_ID:-}" \
    "plan.gate" \
    "" \
    "Plan Gate" \
    "Plan Gate" \
    "step_end" \
    "project_manager" \
    "project_manager" \
    "$selected_main_runtime" \
    "$outer_runtime" \
    "$selected_main_model" \
    "$gate_started_at" \
    "$gate_ended_at" \
    "$gate_duration_ms" \
    "${PM_PROMPT_TOKENS:-}" \
    "${PM_COMPLETION_TOKENS:-}" \
    "${PM_TOTAL_TOKENS:-}" \
    "${PM_USAGE_SOURCE:-$TELEMETRY_DEFAULT_USAGE_SOURCE}" \
    "${PM_USAGE_STATUS:-$TELEMETRY_DEFAULT_USAGE_STATUS}" \
    "success" \
    "" \
    "" \
    "" \
    "${PM_REQUEST_ID:-}" \
    "${PM_TRACE_ID:-}" \
    "${PM_SPAN_ID:-}" \
    "$metadata_json"
  telemetry_record_runtime_detection_run_nonblocking \
    "$gate_run_id" "$route" "$workspace_path" "$outer_runtime" "$selected_mode" "ready" \
    "" "$outer_runtime_detail" "" "$outer_runtime_source" "$gate_started_at" "$gate_ended_at" "$metadata_json"
  echo "PLAN_ROUTE_READY|route=$route|selected_mode=$selected_mode|selected_label=$selected_label|selection_source=$selection_source|outer_runtime=$outer_runtime|outer_runtime_source=$outer_runtime_source|discovery_can_start=1"
}

run_plan() {
  local subcommand="${1:-gate}"
  shift || true

  case "$subcommand" in
    gate)
      run_plan_gate "$@"
      ;;
    *)
      die "Unknown plan subcommand: $subcommand"
      ;;
  esac
}

run_claude_contract_validate_context() {
  local context_file=""
  local role="unspecified"
  local context_hash normalized_json clarifying_instruction
  local missing_csv
  local -a missing_fields=()

  while [ $# -gt 0 ]; do
    case "$1" in
      --context-file)
        context_file="${2:-}"
        shift 2
        ;;
      --role)
        role="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown claude-contract validate-context argument: $1"
        ;;
    esac
  done

  [ -n "$context_file" ] || die "--context-file is required for claude-contract validate-context"
  [ -f "$context_file" ] || die "Context file not found: $context_file"
  jq -e . "$context_file" >/dev/null 2>&1 || die "Context file is not valid JSON: $context_file"

  jq -e '(.feature_objective | type == "string") and ((.feature_objective | gsub("^\\s+|\\s+$"; "")) | length > 0)' "$context_file" >/dev/null 2>&1 || missing_fields+=("feature_objective")
  jq -e '(.prd_context | type == "string") and ((.prd_context | gsub("^\\s+|\\s+$"; "")) | length > 0)' "$context_file" >/dev/null 2>&1 || missing_fields+=("prd_context")
  jq -e '(.task_id | type == "string") and ((.task_id | gsub("^\\s+|\\s+$"; "")) | length > 0)' "$context_file" >/dev/null 2>&1 || missing_fields+=("task_id")
  jq -e '((.acceptance_criteria | type == "string") and ((.acceptance_criteria | gsub("^\\s+|\\s+$"; "")) | length > 0)) or ((.acceptance_criteria | type == "array") and (.acceptance_criteria | length > 0))' "$context_file" >/dev/null 2>&1 || missing_fields+=("acceptance_criteria")
  jq -e '(.implementation_status | type == "string") and ((.implementation_status | gsub("^\\s+|\\s+$"; "")) | length > 0)' "$context_file" >/dev/null 2>&1 || missing_fields+=("implementation_status")
  jq -e '(.changed_files | type == "array") and (.changed_files | length > 0)' "$context_file" >/dev/null 2>&1 || missing_fields+=("changed_files")
  jq -e '((.constraints | type == "string") and ((.constraints | gsub("^\\s+|\\s+$"; "")) | length > 0)) or ((.constraints | type == "array") and (.constraints | length > 0))' "$context_file" >/dev/null 2>&1 || missing_fields+=("constraints")
  jq -e 'has("evidence") and (.evidence != null)' "$context_file" >/dev/null 2>&1 || missing_fields+=("evidence")
  jq -e '(.clarifying_instruction | type == "string") and ((.clarifying_instruction | gsub("^\\s+|\\s+$"; "")) | length > 0)' "$context_file" >/dev/null 2>&1 || missing_fields+=("clarifying_instruction")

  clarifying_instruction="$(jq -r '.clarifying_instruction // ""' "$context_file")"
  if [[ "$clarifying_instruction" != *"$CLAUDE_CLARIFYING_INSTRUCTION"* ]]; then
    missing_fields+=("clarifying_instruction_phrase")
  fi

  if [ "${#missing_fields[@]}" -gt 0 ]; then
    missing_csv="$(printf '%s,' "${missing_fields[@]}" | sed 's/,$//')"
    echo "CLAUDE_CONTEXT_INVALID|role=$role|context_file=$(display_path "$context_file")|missing_fields=$missing_csv|required_fields=$CLAUDE_CONTEXT_REQUIRED_FIELDS_CSV"
    return 2
  fi

  normalized_json="$(jq -cS . "$context_file")"
  context_hash="$(hash_string "$normalized_json")"
  echo "CLAUDE_CONTEXT_VALID|role=$role|context_file=$(display_path "$context_file")|context_hash=$context_hash|required_fields=$CLAUDE_CONTEXT_REQUIRED_FIELDS_CSV"
}

run_claude_contract_evaluate_response() {
  local response_file=""
  local role="unspecified"
  local session_id="<unknown>"
  local request_line needed_fields questions

  while [ $# -gt 0 ]; do
    case "$1" in
      --response-file)
        response_file="${2:-}"
        shift 2
        ;;
      --role)
        role="${2:-}"
        shift 2
        ;;
      --session-id)
        session_id="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown claude-contract evaluate-response argument: $1"
        ;;
    esac
  done

  [ -n "$response_file" ] || die "--response-file is required for claude-contract evaluate-response"
  [ -f "$response_file" ] || die "Response file not found: $response_file"

  request_line="$(awk -v prefix="$CLAUDE_CONTEXT_REQUEST_PREFIX" 'index($0, prefix) == 1 { print; exit }' "$response_file" || true)"
  if [ -n "$request_line" ]; then
    needed_fields="$(pipe_kv_get "$request_line" "needed_fields" || true)"
    questions="$(pipe_kv_get "$request_line" "questions" || true)"
    needed_fields="$(sanitize_single_line "${needed_fields:-<unspecified>}")"
    questions="$(sanitize_single_line "${questions:-<unspecified>}")"
    echo "CLAUDE_HANDSHAKE|status=context_needed|role=$role|session_id=$session_id|needed_fields=$needed_fields|questions=$questions"
    return 3
  fi

  echo "CLAUDE_HANDSHAKE|status=complete|role=$role|session_id=$session_id"
}

run_claude_contract_run_loop() {
  local context_file=""
  local role="unspecified"
  local session_id="<unknown>"
  local max_rounds=6
  local validate_out validate_rc evaluate_out evaluate_rc
  local round=0 response_file
  local -a response_files=()

  while [ $# -gt 0 ]; do
    case "$1" in
      --context-file)
        context_file="${2:-}"
        shift 2
        ;;
      --response-file)
        response_files+=("${2:-}")
        shift 2
        ;;
      --role)
        role="${2:-}"
        shift 2
        ;;
      --session-id)
        session_id="${2:-}"
        shift 2
        ;;
      --max-rounds)
        max_rounds="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown claude-contract run-loop argument: $1"
        ;;
    esac
  done

  [[ "$max_rounds" =~ ^[0-9]+$ ]] || die "--max-rounds must be a positive integer"
  [ "$max_rounds" -ge 1 ] || die "--max-rounds must be >= 1"

  if validate_out="$(run_claude_contract_validate_context --context-file "$context_file" --role "$role")"; then
    validate_rc=0
  else
    validate_rc=$?
  fi
  [ -n "$validate_out" ] && echo "$validate_out"
  [ "$validate_rc" -eq 0 ] || return "$validate_rc"

  if [ "${#response_files[@]}" -eq 0 ]; then
    echo "CLAUDE_LOOP|status=ready|role=$role|session_id=$session_id|next_action=invoke_claude_mcp"
    return 0
  fi

  for response_file in "${response_files[@]}"; do
    round=$((round + 1))
    if [ "$round" -gt "$max_rounds" ]; then
      echo "CLAUDE_LOOP|status=max_rounds_exceeded|role=$role|session_id=$session_id|max_rounds=$max_rounds|responses_seen=$((round - 1))"
      return 5
    fi

    if evaluate_out="$(run_claude_contract_evaluate_response --response-file "$response_file" --session-id "$session_id" --role "$role")"; then
      evaluate_rc=0
    else
      evaluate_rc=$?
    fi
    [ -n "$evaluate_out" ] && echo "$evaluate_out"

    case "$evaluate_rc" in
      0)
        echo "CLAUDE_LOOP|status=complete|role=$role|session_id=$session_id|round=$round|responses_seen=$round"
        return 0
        ;;
      3)
        if [ "$round" -lt "${#response_files[@]}" ]; then
          echo "CLAUDE_LOOP|status=context_requested|role=$role|session_id=$session_id|round=$round|next_action=continue_session"
          continue
        fi
        echo "CLAUDE_LOOP|status=awaiting_context|role=$role|session_id=$session_id|round=$round|next_action=collect_and_continue"
        return 4
        ;;
      *)
        return "$evaluate_rc"
        ;;
    esac
  done

  echo "CLAUDE_LOOP|status=incomplete|role=$role|session_id=$session_id|responses_seen=$round|next_action=provide_more_responses"
  return 4
}

run_claude_contract() {
  local subcommand="${1:-}"
  shift || true

  case "$subcommand" in
    validate-context)
      run_claude_contract_validate_context "$@"
      ;;
    evaluate-response)
      run_claude_contract_evaluate_response "$@"
      ;;
    run-loop)
      run_claude_contract_run_loop "$@"
      ;;
    *)
      die "Unknown claude-contract subcommand: $subcommand"
      ;;
  esac
}

claude_wrapper_generated_session_id() {
  local role="$1"
  local objective="$2"
  local context_hash="$3"
  local seed

  seed="$(hash_string "${role}|${objective}|${context_hash}")"
  printf 'claude-wrapper-%s' "${seed:0:12}"
}

claude_wrapper_detect_unsupported_launcher() {
  local response_file="$1"
  grep -Eim1 "$CLAUDE_WRAPPER_UNSUPPORTED_LAUNCHER_PATTERN" "$response_file" || true
}

write_internal_claude_wrapper_prompt() {
  local template_path="$1"
  local prompt_file="$2"
  local objective="$3"
  local role="$4"
  local session_id="$5"
  local context_file="$6"
  local context_hash="$7"

  mkdir -p "$(dirname "$prompt_file")"

  {
    printf 'use agent swarm for %s\n\n' "$(sanitize_single_line "$objective")"
    cat "$template_path"
    printf '\n[Role: %s]\n' "$role"
    printf 'Wrapper session id: %s\n' "$session_id"
    printf 'Wrapper runtime: %s\n' "$CLAUDE_WRAPPER_RUNTIME"
    printf 'Context pack file: %s\n' "$(display_path "$context_file")"
    printf 'Context hash: %s\n' "$context_hash"
    printf '\nContext Pack JSON:\n'
    jq . "$context_file"
    printf '\n'
  } >"$prompt_file"
}

run_claude_wrapper_prepare() {
  local context_file=""
  local prompt_file=""
  local objective=""
  local role="unspecified"
  local session_id=""
  local validate_out validate_rc context_hash template_path

  while [ $# -gt 0 ]; do
    case "$1" in
      --context-file)
        context_file="${2:-}"
        shift 2
        ;;
      --prompt-file)
        prompt_file="${2:-}"
        shift 2
        ;;
      --objective)
        objective="${2:-}"
        shift 2
        ;;
      --role)
        role="${2:-}"
        shift 2
        ;;
      --session-id)
        session_id="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown claude-wrapper prepare argument: $1"
        ;;
    esac
  done

  [ -n "$context_file" ] || die "--context-file is required for claude-wrapper prepare"
  [ -n "$prompt_file" ] || die "--prompt-file is required for claude-wrapper prepare"
  [ -n "$objective" ] || die "--objective is required for claude-wrapper prepare"

  if validate_out="$(run_claude_contract_validate_context --context-file "$context_file" --role "$role")"; then
    validate_rc=0
  else
    validate_rc=$?
  fi
  [ -n "$validate_out" ] && echo "$validate_out"
  if [ "$validate_rc" -ne 0 ]; then
    echo "CLAUDE_WRAPPER_RESULT|status=invalid_context|role=$role|session_id=${session_id:-<pending>}|runtime=$CLAUDE_WRAPPER_RUNTIME|context_file=$(display_path "$context_file")|next_action=fix_context_pack"
    return "$validate_rc"
  fi

  context_hash="$(pipe_kv_get "$validate_out" "context_hash" || true)"
  [ -n "$context_hash" ] || die "Unable to derive context hash from claude-contract validation output"

  if [ -z "$session_id" ]; then
    session_id="$(claude_wrapper_generated_session_id "$role" "$objective" "$context_hash")"
  fi

  template_path="$(internal_claude_wrapper_template_path)"
  [ -f "$template_path" ] || die "Internal Claude wrapper template not found: $template_path"

  write_internal_claude_wrapper_prompt "$template_path" "$prompt_file" "$objective" "$role" "$session_id" "$context_file" "$context_hash"
  echo "CLAUDE_WRAPPER_READY|status=ready|role=$role|session_id=$session_id|runtime=$CLAUDE_WRAPPER_RUNTIME|context_file=$(display_path "$context_file")|context_hash=$context_hash|prompt_file=$(display_path "$prompt_file")|next_action=invoke_claude_mcp"
}

run_claude_wrapper_evaluate() {
  local context_file=""
  local response_file=""
  local role="unspecified"
  local session_id="<unknown>"
  local prepare_out prepare_rc context_hash runtime_error evaluate_out evaluate_rc
  local needed_fields questions response_hash

  while [ $# -gt 0 ]; do
    case "$1" in
      --context-file)
        context_file="${2:-}"
        shift 2
        ;;
      --response-file)
        response_file="${2:-}"
        shift 2
        ;;
      --role)
        role="${2:-}"
        shift 2
        ;;
      --session-id)
        session_id="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown claude-wrapper evaluate argument: $1"
        ;;
    esac
  done

  [ -n "$context_file" ] || die "--context-file is required for claude-wrapper evaluate"
  [ -n "$response_file" ] || die "--response-file is required for claude-wrapper evaluate"
  [ -f "$response_file" ] || die "Response file not found: $response_file"

  if prepare_out="$(run_claude_contract_validate_context --context-file "$context_file" --role "$role")"; then
    prepare_rc=0
  else
    prepare_rc=$?
  fi
  [ -n "$prepare_out" ] && echo "$prepare_out"
  if [ "$prepare_rc" -ne 0 ]; then
    echo "CLAUDE_WRAPPER_RESULT|status=invalid_context|role=$role|session_id=$session_id|runtime=$CLAUDE_WRAPPER_RUNTIME|context_file=$(display_path "$context_file")|next_action=fix_context_pack"
    return "$prepare_rc"
  fi

  context_hash="$(pipe_kv_get "$prepare_out" "context_hash" || true)"
  [ -n "$context_hash" ] || die "Unable to derive context hash from claude-contract validation output"

  runtime_error="$(claude_wrapper_detect_unsupported_launcher "$response_file")"
  if [ -n "$runtime_error" ]; then
    runtime_error="$(sanitize_single_line "$runtime_error")"
    echo "CLAUDE_WRAPPER_RESULT|status=runtime_error|error=unsupported_launcher|role=$role|session_id=$session_id|runtime=$CLAUDE_WRAPPER_RUNTIME|context_hash=$context_hash|response_file=$(display_path "$response_file")|detail=$runtime_error|next_action=return_to_parent"
    return 6
  fi

  if evaluate_out="$(run_claude_contract_evaluate_response --response-file "$response_file" --session-id "$session_id" --role "$role")"; then
    evaluate_rc=0
  else
    evaluate_rc=$?
  fi
  [ -n "$evaluate_out" ] && echo "$evaluate_out"

  case "$evaluate_rc" in
    0)
      response_hash="$(hash_string "$(cat "$response_file")")"
      echo "CLAUDE_WRAPPER_RESULT|status=complete|role=$role|session_id=$session_id|runtime=$CLAUDE_WRAPPER_RUNTIME|context_hash=$context_hash|response_file=$(display_path "$response_file")|response_hash=$response_hash|next_action=return_to_parent"
      ;;
    3)
      needed_fields="$(pipe_kv_get "$evaluate_out" "needed_fields" || true)"
      questions="$(pipe_kv_get "$evaluate_out" "questions" || true)"
      echo "CLAUDE_WRAPPER_RESULT|status=context_needed|role=$role|session_id=$session_id|runtime=$CLAUDE_WRAPPER_RUNTIME|context_hash=$context_hash|needed_fields=$(sanitize_single_line "${needed_fields:-<unspecified>}")|questions=$(sanitize_single_line "${questions:-<unspecified>}")|next_action=continue_session"
      ;;
    *)
      return "$evaluate_rc"
      ;;
  esac

  return "$evaluate_rc"
}

run_claude_wrapper_run() {
  local context_file=""
  local prompt_file=""
  local objective=""
  local role="unspecified"
  local session_id=""
  local max_rounds=6
  local prepare_out prepare_rc evaluate_out evaluate_rc
  local ready_line=""
  local round=0 response_file
  local -a response_files=()
  local -a prepare_args=()

  while [ $# -gt 0 ]; do
    case "$1" in
      --context-file)
        context_file="${2:-}"
        shift 2
        ;;
      --prompt-file)
        prompt_file="${2:-}"
        shift 2
        ;;
      --objective)
        objective="${2:-}"
        shift 2
        ;;
      --response-file)
        response_files+=("${2:-}")
        shift 2
        ;;
      --role)
        role="${2:-}"
        shift 2
        ;;
      --session-id)
        session_id="${2:-}"
        shift 2
        ;;
      --max-rounds)
        max_rounds="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown claude-wrapper run argument: $1"
        ;;
    esac
  done

  [[ "$max_rounds" =~ ^[0-9]+$ ]] || die "--max-rounds must be a positive integer"
  [ "$max_rounds" -ge 1 ] || die "--max-rounds must be >= 1"

  prepare_args=(--context-file "$context_file" --prompt-file "$prompt_file" --objective "$objective" --role "$role")
  if [ -n "$session_id" ]; then
    prepare_args+=(--session-id "$session_id")
  fi

  if prepare_out="$(run_claude_wrapper_prepare "${prepare_args[@]}")"; then
    prepare_rc=0
  else
    prepare_rc=$?
  fi
  [ -n "$prepare_out" ] && echo "$prepare_out"
  [ "$prepare_rc" -eq 0 ] || return "$prepare_rc"

  ready_line="$(awk 'index($0, "CLAUDE_WRAPPER_READY|") == 1 { print; exit }' <<<"$prepare_out" || true)"
  session_id="$(pipe_kv_get "$ready_line" "session_id" || true)"
  [ -n "$session_id" ] || die "Unable to derive session_id from claude-wrapper prepare output"

  if [ "${#response_files[@]}" -eq 0 ]; then
    return 0
  fi

  for response_file in "${response_files[@]}"; do
    round=$((round + 1))
    if [ "$round" -gt "$max_rounds" ]; then
      echo "CLAUDE_WRAPPER_RESULT|status=max_rounds_exceeded|role=$role|session_id=$session_id|runtime=$CLAUDE_WRAPPER_RUNTIME|max_rounds=$max_rounds|responses_seen=$((round - 1))|next_action=return_to_parent"
      return 5
    fi

    if evaluate_out="$(run_claude_wrapper_evaluate --context-file "$context_file" --response-file "$response_file" --role "$role" --session-id "$session_id")"; then
      evaluate_rc=0
    else
      evaluate_rc=$?
    fi
    [ -n "$evaluate_out" ] && echo "$evaluate_out"

    case "$evaluate_rc" in
      0|6)
        return "$evaluate_rc"
        ;;
      3)
        if [ "$round" -lt "${#response_files[@]}" ]; then
          echo "CLAUDE_WRAPPER_RESULT|status=context_requested|role=$role|session_id=$session_id|runtime=$CLAUDE_WRAPPER_RUNTIME|round=$round|next_action=continue_session"
          continue
        fi
        return 3
        ;;
      *)
        return "$evaluate_rc"
        ;;
    esac
  done

  echo "CLAUDE_WRAPPER_RESULT|status=incomplete|role=$role|session_id=$session_id|runtime=$CLAUDE_WRAPPER_RUNTIME|responses_seen=$round|next_action=provide_more_responses"
  return 4
}

run_claude_wrapper() {
  local subcommand="${1:-}"
  shift || true

  case "$subcommand" in
    prepare)
      run_claude_wrapper_prepare "$@"
      ;;
    evaluate)
      run_claude_wrapper_evaluate "$@"
      ;;
    run)
      run_claude_wrapper_run "$@"
      ;;
    *)
      die "Unknown claude-wrapper subcommand: $subcommand"
      ;;
  esac
}

run_telemetry() {
  local subcommand="${1:-}"
  shift || true

  case "$subcommand" in
    init-db)
      local dsn=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --dsn)
            dsn="${2:-}"
            shift 2
            ;;
          -h|--help)
            usage
            exit 0
            ;;
          *)
            die "Unknown telemetry init-db argument: $1"
            ;;
        esac
      done
      if [ -n "$dsn" ]; then
        PM_TELEMETRY_DSN="$dsn"
      fi
      telemetry_enabled || die "PM_TELEMETRY_DSN or --dsn is required for telemetry init-db"
      telemetry_init_db >/dev/null
      echo "TELEMETRY_DB_READY|table=$TELEMETRY_TABLE_NAME"
      ;;
    log-step)
      local dsn=""
      local event_id=""
      local workflow_run_id=""
      local task_id=""
      local step_id=""
      local parent_step_id=""
      local phase=""
      local step_name=""
      local event_type="step_event"
      local agent_role=""
      local invoked_by_role=""
      local runtime=""
      local provider=""
      local model=""
      local started_at=""
      local ended_at=""
      local duration_ms=""
      local prompt_tokens=""
      local completion_tokens=""
      local total_tokens=""
      local usage_source="$TELEMETRY_DEFAULT_USAGE_SOURCE"
      local usage_status="$TELEMETRY_DEFAULT_USAGE_STATUS"
      local status=""
      local error_or_warning_code=""
      local warning_message=""
      local remediation=""
      local request_id=""
      local trace_id=""
      local span_id=""
      local metadata_json="{}"

      while [ $# -gt 0 ]; do
        case "$1" in
          --dsn) dsn="${2:-}"; shift 2 ;;
          --event-id) event_id="${2:-}"; shift 2 ;;
          --workflow-run-id) workflow_run_id="${2:-}"; shift 2 ;;
          --task-id) task_id="${2:-}"; shift 2 ;;
          --step-id) step_id="${2:-}"; shift 2 ;;
          --parent-step-id) parent_step_id="${2:-}"; shift 2 ;;
          --phase) phase="${2:-}"; shift 2 ;;
          --step-name) step_name="${2:-}"; shift 2 ;;
          --event-type) event_type="${2:-}"; shift 2 ;;
          --agent-role) agent_role="${2:-}"; shift 2 ;;
          --invoked-by-role) invoked_by_role="${2:-}"; shift 2 ;;
          --runtime) runtime="${2:-}"; shift 2 ;;
          --provider) provider="${2:-}"; shift 2 ;;
          --model) model="${2:-}"; shift 2 ;;
          --started-at) started_at="${2:-}"; shift 2 ;;
          --ended-at) ended_at="${2:-}"; shift 2 ;;
          --duration-ms) duration_ms="${2:-}"; shift 2 ;;
          --prompt-tokens) prompt_tokens="${2:-}"; shift 2 ;;
          --completion-tokens) completion_tokens="${2:-}"; shift 2 ;;
          --total-tokens) total_tokens="${2:-}"; shift 2 ;;
          --usage-source) usage_source="${2:-}"; shift 2 ;;
          --usage-status) usage_status="${2:-}"; shift 2 ;;
          --status) status="${2:-}"; shift 2 ;;
          --error-or-warning-code) error_or_warning_code="${2:-}"; shift 2 ;;
          --warning-message) warning_message="${2:-}"; shift 2 ;;
          --remediation) remediation="${2:-}"; shift 2 ;;
          --request-id) request_id="${2:-}"; shift 2 ;;
          --trace-id) trace_id="${2:-}"; shift 2 ;;
          --span-id) span_id="${2:-}"; shift 2 ;;
          --metadata-json) metadata_json="${2:-}"; shift 2 ;;
          -h|--help)
            usage
            exit 0
            ;;
          *)
            die "Unknown telemetry log-step argument: $1"
            ;;
        esac
      done

      [ -n "$workflow_run_id" ] || die "--workflow-run-id is required for telemetry log-step"
      [ -n "$step_id" ] || die "--step-id is required for telemetry log-step"
      if [ -n "$dsn" ]; then
        PM_TELEMETRY_DSN="$dsn"
      fi
      telemetry_enabled || die "PM_TELEMETRY_DSN or --dsn is required for telemetry log-step"

      [ -n "$event_id" ] || event_id="$(telemetry_new_event_id "$step_id" "$event_type")"
      telemetry_record_event \
        "$event_id" \
        "$workflow_run_id" \
        "$task_id" \
        "$step_id" \
        "$parent_step_id" \
        "$phase" \
        "$step_name" \
        "$event_type" \
        "$agent_role" \
        "$invoked_by_role" \
        "$runtime" \
        "$provider" \
        "$model" \
        "$started_at" \
        "$ended_at" \
        "$duration_ms" \
        "$prompt_tokens" \
        "$completion_tokens" \
        "$total_tokens" \
        "$usage_source" \
        "$usage_status" \
        "$status" \
        "$error_or_warning_code" \
        "$warning_message" \
        "$remediation" \
        "$request_id" \
        "$trace_id" \
        "$span_id" \
        "$metadata_json"
      echo "TELEMETRY_RECORDED|event_id=$event_id|workflow_run_id=$workflow_run_id|step_id=$step_id|event_type=$event_type"
      ;;
    query-task)
      local dsn=""
      local task_id=""
      local workflow_run_id=""
      local limit="200"
      while [ $# -gt 0 ]; do
        case "$1" in
          --dsn) dsn="${2:-}"; shift 2 ;;
          --task-id) task_id="${2:-}"; shift 2 ;;
          --workflow-run-id) workflow_run_id="${2:-}"; shift 2 ;;
          --limit) limit="${2:-}"; shift 2 ;;
          -h|--help) usage; exit 0 ;;
          *) die "Unknown telemetry query-task argument: $1" ;;
        esac
      done
      [ -n "$task_id" ] || die "--task-id is required for telemetry query-task"
      [[ "$limit" =~ ^[0-9]+$ ]] || die "--limit must be a positive integer"
      if [ -n "$dsn" ]; then
        PM_TELEMETRY_DSN="$dsn"
      fi
      telemetry_enabled || die "PM_TELEMETRY_DSN or --dsn is required for telemetry query-task"
      telemetry_require_table
      telemetry_exec_sql "
SELECT
  event_id, workflow_run_id, task_id, step_id, parent_step_id, phase, step_name, event_type,
  agent_role, invoked_by_role, runtime, provider, model, started_at, ended_at, duration_ms,
  prompt_tokens, completion_tokens, total_tokens, usage_source, usage_status, status,
  error_or_warning_code, warning_message, remediation, request_id, trace_id, span_id, created_at
FROM ${TELEMETRY_TABLE_NAME}
WHERE task_id = :'task_id'
  AND (NULLIF(:'workflow_run_id','') IS NULL OR workflow_run_id = :'workflow_run_id')
ORDER BY created_at ASC
LIMIT NULLIF(:'limit','')::integer;
" -v task_id="$task_id" -v workflow_run_id="$workflow_run_id" -v limit="$limit"
      ;;
    query-run)
      local dsn=""
      local workflow_run_id=""
      local limit="500"
      while [ $# -gt 0 ]; do
        case "$1" in
          --dsn) dsn="${2:-}"; shift 2 ;;
          --workflow-run-id) workflow_run_id="${2:-}"; shift 2 ;;
          --limit) limit="${2:-}"; shift 2 ;;
          -h|--help) usage; exit 0 ;;
          *) die "Unknown telemetry query-run argument: $1" ;;
        esac
      done
      [ -n "$workflow_run_id" ] || die "--workflow-run-id is required for telemetry query-run"
      [[ "$limit" =~ ^[0-9]+$ ]] || die "--limit must be a positive integer"
      if [ -n "$dsn" ]; then
        PM_TELEMETRY_DSN="$dsn"
      fi
      telemetry_enabled || die "PM_TELEMETRY_DSN or --dsn is required for telemetry query-run"
      telemetry_require_table
      telemetry_exec_sql "
SELECT
  workflow_run_id, task_id, step_id, parent_step_id, phase, step_name, event_type,
  agent_role, invoked_by_role, runtime, provider, model, started_at, ended_at, duration_ms,
  prompt_tokens, completion_tokens, total_tokens, usage_source, usage_status, status,
  error_or_warning_code, warning_message, remediation, request_id, trace_id, span_id, metadata, created_at
FROM ${TELEMETRY_TABLE_NAME}
WHERE workflow_run_id = :'workflow_run_id'
ORDER BY created_at ASC
LIMIT NULLIF(:'limit','')::integer;
" -v workflow_run_id="$workflow_run_id" -v limit="$limit"
      ;;
    *)
      die "Unknown telemetry subcommand: $subcommand"
      ;;
  esac
}

run_self_update_check() {
  local state_file="$1"
  local changelog_url="$2"
  local release_url="$3"
  local npm_tags_url="$4"

  local now changelog_payload changelog_entries changelog_versions latest_changelog
  local current pending_versions pending_count pending_csv pending_json pending_entries pending_entries_json
  local relevance_total relevance_relevant relevance_ignored
  local relevance_total_json relevance_relevant_json relevance_ignored_json
  local relevant_changes_json ignored_changes_json integration_plan_json
  local changelog_json mismatch_json mismatch_csv batch_id to_version
  local release_effective_url release_version npm_payload npm_latest npm_alpha
  local include_state strict_state include_prerelease strict_mismatch
  local include_prerelease_json strict_mismatch_json
  local -a mismatch_flags=()

  ensure_state_file "$state_file"
  now="$(now_utc)"

  include_state="$(state_get "$state_file" '.feature_flags.include_prerelease')"
  strict_state="$(state_get "$state_file" '.feature_flags.strict_mismatch')"
  include_prerelease="$(resolve_bool_setting "PM_SELF_UPDATE_INCLUDE_PRERELEASE" "$include_state" 1)"
  strict_mismatch="$(resolve_bool_setting "PM_SELF_UPDATE_STRICT_MISMATCH" "$strict_state" 0)"

  changelog_payload="$(fetch_url "$changelog_url" "${PM_SELF_UPDATE_CHANGELOG_PAYLOAD:-}")" || die "Failed to fetch Codex changelog from $changelog_url"
  changelog_entries="$(extract_codex_entry_lines_from_changelog "$changelog_payload" "$include_prerelease" || true)"
  [ -n "$changelog_entries" ] || die "Failed to parse Codex changelog entries from payload"
  changelog_versions="$(printf '%s\n' "$changelog_entries" | awk -F '\t' 'NF { print $1 }' | semver_sort_unique)"
  [ -n "$changelog_versions" ] || die "Failed to parse Codex versions from changelog payload"
  latest_changelog="$(pick_latest_version "$changelog_versions")"

  release_version=""
  if release_effective_url="$(fetch_release_effective_url "$release_url" 2>/dev/null)"; then
    release_version="$(latest_semver_from_text "$release_effective_url" || true)"
    release_version="$(normalize_version "$release_version")"
  else
    warn "Release corroboration unavailable from $release_url"
  fi

  npm_latest=""
  npm_alpha=""
  if npm_payload="$(fetch_npm_tags_payload "$npm_tags_url" 2>/dev/null)"; then
    npm_latest="$(printf '%s' "$npm_payload" | jq -r '.latest // ""' 2>/dev/null || true)"
    npm_alpha="$(printf '%s' "$npm_payload" | jq -r '.alpha // .next // .canary // ""' 2>/dev/null || true)"
    npm_latest="$(normalize_version "$npm_latest")"
    npm_alpha="$(normalize_version "$npm_alpha")"
  else
    warn "npm corroboration unavailable from $npm_tags_url"
  fi

  if [ -n "$release_version" ] && ! version_in_list "$release_version" "$changelog_versions"; then
    mismatch_flags+=("release_not_in_changelog:$release_version")
  fi
  if [ -n "$npm_latest" ] && ! version_in_list "$npm_latest" "$changelog_versions"; then
    mismatch_flags+=("npm_latest_not_in_changelog:$npm_latest")
  fi
  if [ "$include_prerelease" -eq 1 ] && [ -n "$npm_alpha" ] && ! version_in_list "$npm_alpha" "$changelog_versions"; then
    mismatch_flags+=("npm_alpha_not_in_changelog:$npm_alpha")
  fi

  mismatch_csv=""
  if [ "${#mismatch_flags[@]}" -gt 0 ]; then
    mismatch_csv="$(printf '%s,' "${mismatch_flags[@]}" | sed 's/,$//')"
  fi

  if [ "$strict_mismatch" -eq 1 ] && [ -n "$mismatch_csv" ]; then
    die "Source corroboration mismatch under strict mode: $mismatch_csv"
  fi

  current="$(state_get "$state_file" '.latest_processed_codex_version')"
  current="$(normalize_version "$current")"
  if [ -n "$current" ]; then
    semver_validate "$current" || die "Invalid latest_processed_codex_version in state: $current"
  fi

  pending_versions="$(compute_pending_versions "$changelog_versions" "$current")"
  pending_count="$(printf '%s\n' "$pending_versions" | awk 'NF' | wc -l | tr -d ' ')"
  pending_entries="$(filter_entries_by_versions "$changelog_entries" "$pending_versions")"
  pending_entries_json="$(entries_to_json_array "$pending_entries")"
  build_relevance_and_plan_json "$pending_entries"
  relevance_total="$SELF_UPDATE_ENTRY_TOTAL"
  relevance_relevant="$SELF_UPDATE_RELEVANT_COUNT"
  relevance_ignored="$SELF_UPDATE_IGNORED_COUNT"
  relevant_changes_json="$SELF_UPDATE_RELEVANT_JSON"
  ignored_changes_json="$SELF_UPDATE_IGNORED_JSON"
  integration_plan_json="$SELF_UPDATE_PLAN_JSON"

  changelog_json="$(printf '%s\n' "$changelog_versions" | json_array_from_newlines)"
  mismatch_json="$(printf '%s\n' "$mismatch_csv" | tr ',' '\n' | json_array_from_newlines)"
  relevance_total_json="$relevance_total"
  relevance_relevant_json="$relevance_relevant"
  relevance_ignored_json="$relevance_ignored"
  include_prerelease_json="$([ "$include_prerelease" -eq 1 ] && echo true || echo false)"
  strict_mismatch_json="$([ "$strict_mismatch" -eq 1 ] && echo true || echo false)"

  if [ "$pending_count" -gt 0 ]; then
    to_version="$(pick_latest_version "$pending_versions")"
    pending_csv="$(printf '%s\n' "$pending_versions" | awk 'NF' | paste -sd, -)"
    pending_json="$(printf '%s\n' "$pending_versions" | json_array_from_newlines)"
    batch_id="$(hash_string "$pending_csv")"

    state_update_with_args "$state_file" \
      --arg now "$now" \
      --arg changelog_url "$changelog_url" \
      --arg release_url "$release_url" \
      --arg npm_url "$npm_tags_url" \
      --arg latest_changelog "$latest_changelog" \
      --arg release_version "$release_version" \
      --arg npm_latest "$npm_latest" \
      --arg npm_alpha "$npm_alpha" \
      --arg current "$current" \
      --arg to_version "$to_version" \
      --arg batch_id "$batch_id" \
      --argjson changelog_versions "$changelog_json" \
      --argjson pending_versions "$pending_json" \
      --argjson pending_entries "$pending_entries_json" \
      --argjson relevant_changes "$relevant_changes_json" \
      --argjson ignored_changes "$ignored_changes_json" \
      --argjson integration_plan "$integration_plan_json" \
      --argjson relevance_total "$relevance_total_json" \
      --argjson relevance_relevant "$relevance_relevant_json" \
      --argjson relevance_ignored "$relevance_ignored_json" \
      --argjson mismatch_flags "$mismatch_json" \
      --argjson include_prerelease "$include_prerelease_json" \
      --argjson strict_mismatch "$strict_mismatch_json" \
      '
        .pending_codex_versions = $pending_versions |
        .pending_codex_version = $to_version |
        .pending_batch = {
          from_version: (if ($current | length) > 0 then $current else "<none>" end),
          to_version: $to_version,
          versions: $pending_versions,
          entry_analysis: {
            total_entries: $relevance_total,
            relevant_entries: $relevance_relevant,
            ignored_entries: $relevance_ignored,
            entries: $pending_entries,
            relevant: $relevant_changes,
            ignored: $ignored_changes,
            integration_plan: $integration_plan
          },
          source_of_truth: $changelog_url,
          corroboration: {
            release_version: $release_version,
            npm_latest: $npm_latest,
            npm_alpha: $npm_alpha
          },
          mismatch_flags: $mismatch_flags,
          batch_id: $batch_id,
          generated_at: $now
        } |
        .last_checked_codex_version = $latest_changelog |
        .last_check.checked_at = $now |
        .last_check.changelog_version = $latest_changelog |
        .last_check.changelog_versions = $changelog_versions |
        .last_check.release_version = $release_version |
        .last_check.npm_latest = $npm_latest |
        .last_check.npm_alpha = $npm_alpha |
        .last_check.selected_version = $to_version |
        .last_check.sources = [$changelog_url, $release_url, $npm_url] |
        .last_check.mismatch_flags = $mismatch_flags |
        .feature_flags.include_prerelease = $include_prerelease |
        .feature_flags.strict_mismatch = $strict_mismatch |
        .updated_at = $now
      '

    echo "UPDATE_AVAILABLE|processed_version=${current:-<none>}|latest_version=$to_version|pending_count=$pending_count|from_version=${current:-<none>}|to_version=$to_version|changelog_version=$latest_changelog|release_version=${release_version:-<none>}|npm_latest=${npm_latest:-<none>}|npm_alpha=${npm_alpha:-<none>}"
    echo "PENDING_BATCH|versions=$pending_csv|batch_id=$batch_id"
    echo "RELEVANCE_SUMMARY|total_entries=$relevance_total|relevant_entries=$relevance_relevant|ignored_entries=$relevance_ignored"
    echo "RELEVANT_CHANGES_JSON|$relevant_changes_json"
    echo "IGNORED_CHANGES_JSON|$ignored_changes_json"
    echo "INTEGRATION_PLAN_JSON|$integration_plan_json"
    echo "SOURCE_OF_TRUTH|url=$changelog_url"
    if [ -n "$mismatch_csv" ]; then
      echo "SOURCE_MISMATCH|flags=$mismatch_csv"
    fi
    echo "PLAN_TRIGGER|$DEFAULT_PLAN_TRIGGER"
    echo "PLAN_CONTEXT|detected_version=$to_version|pending_count=$pending_count|relevant_count=$relevance_relevant|ignored_count=$relevance_ignored|batch_id=$batch_id"
    echo "GATE_REQUIRED|After PM flow completion, run: $SCRIPT_NAME self-update complete --approval approved --prd-approval approved --beads-approval approved --prd-path <approved-prd-path>"
    return 0
  fi

  state_update_with_args "$state_file" \
    --arg now "$now" \
    --arg changelog_url "$changelog_url" \
    --arg release_url "$release_url" \
    --arg npm_url "$npm_tags_url" \
    --arg latest_changelog "$latest_changelog" \
    --arg release_version "$release_version" \
    --arg npm_latest "$npm_latest" \
    --arg npm_alpha "$npm_alpha" \
    --argjson changelog_versions "$changelog_json" \
    --argjson pending_entries "$pending_entries_json" \
    --argjson relevant_changes "$relevant_changes_json" \
    --argjson ignored_changes "$ignored_changes_json" \
    --argjson integration_plan "$integration_plan_json" \
    --argjson relevance_total "$relevance_total_json" \
    --argjson relevance_relevant "$relevance_relevant_json" \
    --argjson relevance_ignored "$relevance_ignored_json" \
    --argjson mismatch_flags "$mismatch_json" \
    --argjson include_prerelease "$include_prerelease_json" \
    --argjson strict_mismatch "$strict_mismatch_json" \
    '
      .pending_codex_versions = [] |
      .pending_codex_version = "" |
      .pending_batch = {
        from_version: .latest_processed_codex_version,
        to_version: "",
        versions: [],
        entry_analysis: {
          total_entries: $relevance_total,
          relevant_entries: $relevance_relevant,
          ignored_entries: $relevance_ignored,
          entries: $pending_entries,
          relevant: $relevant_changes,
          ignored: $ignored_changes,
          integration_plan: $integration_plan
        },
        source_of_truth: $changelog_url,
        corroboration: {
          release_version: $release_version,
          npm_latest: $npm_latest,
          npm_alpha: $npm_alpha
        },
        mismatch_flags: $mismatch_flags,
        batch_id: "",
        generated_at: $now
      } |
      .last_checked_codex_version = $latest_changelog |
      .last_check.checked_at = $now |
      .last_check.changelog_version = $latest_changelog |
      .last_check.changelog_versions = $changelog_versions |
      .last_check.release_version = $release_version |
      .last_check.npm_latest = $npm_latest |
      .last_check.npm_alpha = $npm_alpha |
      .last_check.selected_version = $latest_changelog |
      .last_check.sources = [$changelog_url, $release_url, $npm_url] |
      .last_check.mismatch_flags = $mismatch_flags |
      .feature_flags.include_prerelease = $include_prerelease |
      .feature_flags.strict_mismatch = $strict_mismatch |
      .updated_at = $now
    '

  echo "NO_OP|processed_version=${current:-<none>}|latest_version=$latest_changelog|reason=up_to_date"
  echo "RELEVANCE_SUMMARY|total_entries=$relevance_total|relevant_entries=$relevance_relevant|ignored_entries=$relevance_ignored"
  echo "RELEVANT_CHANGES_JSON|$relevant_changes_json"
  echo "IGNORED_CHANGES_JSON|$ignored_changes_json"
  echo "INTEGRATION_PLAN_JSON|$integration_plan_json"
  echo "SOURCE_OF_TRUTH|url=$changelog_url"
  if [ -n "$mismatch_csv" ]; then
    echo "SOURCE_MISMATCH|flags=$mismatch_csv"
  fi
}

run_self_update_complete() {
  local state_file="$1"
  local approval="$2"
  local prd_approval="$3"
  local beads_approval="$4"
  local prd_path="$5"
  local dry_run="$6"

  local pending_versions pending_fallback sorted_pending target_version pending_count
  local now backup

  ensure_state_file "$state_file"

  [ "$approval" = "$APPROVAL_TOKEN" ] || die "Completion gate failed. Expected --approval $APPROVAL_TOKEN"
  [ "$prd_approval" = "$APPROVAL_TOKEN" ] || die "Completion gate failed. Expected --prd-approval $APPROVAL_TOKEN"
  [ "$beads_approval" = "$APPROVAL_TOKEN" ] || die "Completion gate failed. Expected --beads-approval $APPROVAL_TOKEN"

  assert_open_questions_empty "$prd_path"

  pending_versions="$(state_get "$state_file" '.pending_codex_versions[]?')"
  pending_fallback="$(state_get "$state_file" '.pending_codex_version')"
  if [ -z "$pending_versions" ] && [ -n "$pending_fallback" ]; then
    pending_versions="$pending_fallback"
  fi

  sorted_pending="$(printf '%s\n' "$pending_versions" | semver_sort_unique)"
  pending_count="$(printf '%s\n' "$sorted_pending" | awk 'NF' | wc -l | tr -d ' ')"
  [ "$pending_count" -gt 0 ] || die "No pending Codex version batch to complete"

  assert_prd_covers_versions "$prd_path" "$sorted_pending"

  target_version="$(pick_latest_version "$sorted_pending")"
  [ -n "$target_version" ] || die "Unable to determine target version from pending batch"

  now="$(now_utc)"

  if [ "$dry_run" -eq 1 ]; then
    echo "CHECKPOINT_DRY_RUN|state_file=${state_file##*/}|version=$target_version"
    echo "COMPLETE_DRY_RUN|latest_processed_codex_version=$target_version|pending_count=$pending_count"
    return 0
  fi

  backup="$(mktemp "${state_file}.backup.XXXX")"
  cp "$state_file" "$backup"

  state_update_with_args "$state_file" \
    --arg now "$now" \
    --arg target_version "$target_version" \
    --arg prd_path "$prd_path" \
    --argjson completed_versions "$(printf '%s\n' "$sorted_pending" | json_array_from_newlines)" \
    '
      .last_completed_batch = (
        .pending_batch + {
          completed_at: $now,
          completed_with_prd: $prd_path,
          completed_versions: $completed_versions
        }
      ) |
      .latest_processed_codex_version = $target_version |
      .pending_codex_versions = [] |
      .pending_codex_version = "" |
      .pending_batch = {
        from_version: $target_version,
        to_version: "",
        versions: [],
        entry_analysis: {
          total_entries: 0,
          relevant_entries: 0,
          ignored_entries: 0,
          entries: [],
          relevant: [],
          ignored: [],
          integration_plan: []
        },
        source_of_truth: .pending_batch.source_of_truth,
        corroboration: .pending_batch.corroboration,
        mismatch_flags: [],
        batch_id: "",
        generated_at: ""
      } |
      .last_checkpoint_ref = "codex-version-\($target_version)" |
      .updated_at = $now
    '

  if ! checkpoint_commit "$state_file" "$target_version" 0; then
    cp "$backup" "$state_file"
    if git -C "$(repo_root)" rev-parse --show-toplevel >/dev/null 2>&1; then
      local root rel
      root="$(repo_root)"
      case "$state_file" in
        "$root"/*) rel="${state_file#"$root"/}" ;;
        *) rel="" ;;
      esac
      if [ -n "$rel" ]; then
        git -C "$root" add -- "$rel" >/dev/null 2>&1 || true
      fi
    fi
    rm -f "$backup"
    die "Checkpoint commit failed; restored previous state"
  fi

  rm -f "$backup"
  echo "COMPLETE|latest_processed_codex_version=$target_version|pending_count=$pending_count"
}

run_self_update() {
  local mode="check"
  local state_file=""
  local approval=""
  local prd_approval=""
  local beads_approval=""
  local prd_path=""
  local dry_run=0
  local changelog_url="$DEFAULT_CHANGELOG_URL"
  local release_url="$DEFAULT_RELEASE_URL"
  local npm_tags_url="$DEFAULT_NPM_TAGS_URL"

  if [ $# -gt 0 ] && [ "$1" != "--" ] && [ "${1#--}" = "$1" ]; then
    mode="$1"
    shift
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
      --state-file)
        state_file="${2:-}"
        shift 2
        ;;
      --approval)
        approval="${2:-}"
        shift 2
        ;;
      --prd-approval)
        prd_approval="${2:-}"
        shift 2
        ;;
      --beads-approval)
        beads_approval="${2:-}"
        shift 2
        ;;
      --prd-path)
        prd_path="${2:-}"
        shift 2
        ;;
      --changelog-url)
        changelog_url="${2:-}"
        shift 2
        ;;
      --release-url)
        release_url="${2:-}"
        shift 2
        ;;
      --npm-tags-url)
        npm_tags_url="${2:-}"
        shift 2
        ;;
      --dry-run)
        dry_run=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown self-update argument: $1"
        ;;
    esac
  done

  [ -n "$state_file" ] || state_file="$(default_state_file)"

  case "$mode" in
    check)
      run_self_update_check "$state_file" "$changelog_url" "$release_url" "$npm_tags_url"
      ;;
    complete)
      [ -n "$approval" ] || die "--approval is required for self-update complete"
      [ -n "$prd_approval" ] || die "--prd-approval is required for self-update complete"
      [ -n "$beads_approval" ] || die "--beads-approval is required for self-update complete"
      [ -n "$prd_path" ] || die "--prd-path is required for self-update complete"
      run_self_update_complete "$state_file" "$approval" "$prd_approval" "$beads_approval" "$prd_path" "$dry_run"
      ;;
    *)
      die "Unknown self-update mode: $mode"
      ;;
  esac
}

TELEMETRY_MAIN_HOOK_ACTIVE=0
TELEMETRY_MAIN_CMD=""
TELEMETRY_MAIN_STARTED_AT=""
TELEMETRY_MAIN_START_MS=0
TELEMETRY_MAIN_WORKFLOW_RUN_ID=""
TELEMETRY_MAIN_TASK_ID=""
TELEMETRY_MAIN_STEP_ID=""
TELEMETRY_MAIN_EVENT_ID_END=""

telemetry_on_exit() {
  local rc=$?
  local ended_at ended_ms duration_ms status

  if [ "$TELEMETRY_MAIN_HOOK_ACTIVE" -eq 1 ] && [ "$TELEMETRY_MAIN_CMD" != "telemetry" ]; then
    ended_at="$(now_utc)"
    ended_ms="$(epoch_ms)"
    duration_ms="$((ended_ms - TELEMETRY_MAIN_START_MS))"
    status="success"
    if [ "$rc" -ne 0 ]; then
      status="failed"
    fi

    telemetry_record_event_nonblocking \
      "$TELEMETRY_MAIN_EVENT_ID_END" \
      "$TELEMETRY_MAIN_WORKFLOW_RUN_ID" \
      "$TELEMETRY_MAIN_TASK_ID" \
      "$TELEMETRY_MAIN_STEP_ID" \
      "" \
      "PM Command" \
      "pm-command $TELEMETRY_MAIN_CMD" \
      "command_end" \
      "project_manager" \
      "project_manager" \
      "${PM_RUNTIME:-}" \
      "${PM_TELEMETRY_PROVIDER:-codex}" \
      "${PM_MODEL:-}" \
      "$TELEMETRY_MAIN_STARTED_AT" \
      "$ended_at" \
      "$duration_ms" \
      "${PM_PROMPT_TOKENS:-}" \
      "${PM_COMPLETION_TOKENS:-}" \
      "${PM_TOTAL_TOKENS:-}" \
      "${PM_USAGE_SOURCE:-$TELEMETRY_DEFAULT_USAGE_SOURCE}" \
      "${PM_USAGE_STATUS:-$TELEMETRY_DEFAULT_USAGE_STATUS}" \
      "$status" \
      "${PM_ERROR_CODE:-}" \
      "" \
      "" \
      "${PM_REQUEST_ID:-}" \
      "${PM_TRACE_ID:-}" \
      "${PM_SPAN_ID:-}" \
      "{\"command\":\"$TELEMETRY_MAIN_CMD\",\"exit_code\":$rc}"
  fi
}

main() {
  require_tool curl
  require_tool jq
  require_tool git

  local cmd="${1:-help}"
  local event_id_start
  shift || true

  TELEMETRY_MAIN_CMD="$cmd"
  TELEMETRY_MAIN_STARTED_AT="$(now_utc)"
  TELEMETRY_MAIN_START_MS="$(epoch_ms)"
  TELEMETRY_MAIN_WORKFLOW_RUN_ID="${PM_WORKFLOW_RUN_ID:-pmcmd-$(date +%s)-$$}"
  TELEMETRY_MAIN_TASK_ID="${PM_TASK_ID:-}"
  TELEMETRY_MAIN_STEP_ID="pm-command:${cmd}"
  event_id_start="$(telemetry_new_event_id "$cmd" "start")"
  TELEMETRY_MAIN_EVENT_ID_END="$(telemetry_new_event_id "$cmd" "end")"

  if [ "$cmd" != "telemetry" ]; then
    TELEMETRY_MAIN_HOOK_ACTIVE=1
    telemetry_record_event_nonblocking \
      "$event_id_start" \
      "$TELEMETRY_MAIN_WORKFLOW_RUN_ID" \
      "$TELEMETRY_MAIN_TASK_ID" \
      "$TELEMETRY_MAIN_STEP_ID" \
      "" \
      "PM Command" \
      "pm-command $cmd" \
      "command_start" \
      "project_manager" \
      "project_manager" \
      "${PM_RUNTIME:-}" \
      "${PM_TELEMETRY_PROVIDER:-codex}" \
      "${PM_MODEL:-}" \
      "$TELEMETRY_MAIN_STARTED_AT" \
      "" \
      "" \
      "" \
      "" \
      "" \
      "${PM_USAGE_SOURCE:-$TELEMETRY_DEFAULT_USAGE_SOURCE}" \
      "${PM_USAGE_STATUS:-$TELEMETRY_DEFAULT_USAGE_STATUS}" \
      "in_progress" \
      "" \
      "" \
      "" \
      "${PM_REQUEST_ID:-}" \
      "${PM_TRACE_ID:-}" \
      "${PM_SPAN_ID:-}" \
      "{\"command\":\"$cmd\"}"
  fi

  trap telemetry_on_exit EXIT

  case "$cmd" in
    help)
      print_help_output
      ;;
    execution-mode)
      run_execution_mode "$@"
      ;;
    lead-model)
      run_lead_model "$@"
      ;;
    plan)
      run_plan "$@"
      ;;
    claude-contract)
      run_claude_contract "$@"
      ;;
    claude-wrapper)
      run_claude_wrapper "$@"
      ;;
    telemetry)
      run_telemetry "$@"
      ;;
    self-check)
      run_self_check "$@"
      ;;
    self-update)
      run_self_update "$@"
      ;;
    -h|--help)
      usage
      ;;
    *)
      die "Unknown command: $cmd"
      ;;
  esac
}

main "$@"
