#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
APPROVAL_TOKEN="approved"
DEFAULT_CHANGELOG_URL="https://developers.openai.com/codex/changelog/"
DEFAULT_RELEASE_URL="https://github.com/openai/codex/releases/latest"
DEFAULT_NPM_TAGS_URL="https://registry.npmjs.org/-/package/@openai/codex/dist-tags"
DEFAULT_PLAN_TRIGGER="/pm plan: Inspect latest Codex changes and align orchestrator behavior with orchestration-mode runtime policy."
STATE_RELATIVE_PATH=".codex/pm-self-update-state.json"
LEAD_MODEL_STATE_RELATIVE_PATH=".codex/pm-lead-model-state.json"
LEAD_MODEL_SCHEMA_VERSION=1
LEAD_MODEL_PROFILE_FULL_CODEX="full-codex"
LEAD_MODEL_PROFILE_CODEX_MAIN="codex-main"
LEAD_MODEL_PROFILE_CLAUDE_MAIN="claude-main"
LEAD_MODEL_PROFILE_CODEX_LEGACY="codex-first"
LEAD_MODEL_PROFILE_CLAUDE_LEGACY="claude-first"
LEAD_MODEL_DEFAULT_PROFILE="$LEAD_MODEL_PROFILE_CODEX_MAIN"
LEAD_MODEL_OPTION_FULL_CODEX="Full Codex Orchestration"
LEAD_MODEL_OPTION_CODEX_MAIN="Codex as Main Agent"
LEAD_MODEL_OPTION_CLAUDE_MAIN="Claude as Main Orchestrator"
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
CLAUDE_CONTEXT_REQUEST_PREFIX="CONTEXT_REQUEST|"
CLAUDE_CONTEXT_REQUIRED_FIELDS_CSV="feature_objective,prd_context,task_id,acceptance_criteria,implementation_status,changed_files,constraints,evidence,clarifying_instruction"
CLAUDE_CLARIFYING_INSTRUCTION="If you have missing or ambiguous context, ask specific clarifying questions before final recommendations."
TELEMETRY_TABLE_NAME="pm_step_events"
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
  pm-command.sh lead-model show [--state-file PATH]
  pm-command.sh lead-model set --profile full-codex|codex-main|claude-main [--state-file PATH]
  pm-command.sh lead-model reset [--state-file PATH]
  pm-command.sh plan gate --route default|big-feature [--lead-model full-codex|codex-main|claude-main] [--state-file PATH]
  pm-command.sh claude-contract validate-context --context-file PATH [--role ROLE]
  pm-command.sh claude-contract evaluate-response --response-file PATH [--session-id ID] [--role ROLE]
  pm-command.sh claude-contract run-loop --context-file PATH [--response-file PATH ...] [--session-id ID] [--role ROLE] [--max-rounds N]
  pm-command.sh telemetry init-db [--dsn POSTGRES_DSN]
  pm-command.sh telemetry log-step --workflow-run-id ID --step-id ID [--event-id ID] [fields...]
  pm-command.sh telemetry query-task --task-id ID [--workflow-run-id ID] [--limit N]
  pm-command.sh telemetry query-run --workflow-run-id ID [--dsn POSTGRES_DSN] [--limit N]
  pm-command.sh self-update [check] [--state-file PATH] [--changelog-url URL] [--release-url URL] [--npm-tags-url URL]
  pm-command.sh self-update complete --approval approved --prd-approval approved --beads-approval approved --prd-path PATH [--state-file PATH] [--dry-run]

Commands:
  help          Print deterministic $pm help output.
  lead-model    Read/update persistent PM orchestration mode selection state.
  plan          Run plan-route orchestration mode gate and routing preflight.
  claude-contract Enforce Claude context-pack and missing-context handshake.
  telemetry     Persist/query PM step telemetry in PostgreSQL.
  self-update   Manual self-update orchestration. Defaults to check mode.

Self-update modes:
  check         Build changelog-source-of-truth pending batch (stable + prerelease by default).
  complete      Advance processed version only after explicit approval gate and PRD evidence coverage.

Environment toggles:
  PM_SELF_UPDATE_INCLUDE_PRERELEASE=1|0   Include prerelease entries from changelog (default: 1)
  PM_SELF_UPDATE_STRICT_MISMATCH=1|0      Fail check when corroborative sources disagree with changelog (default: 0)
  PM_SELF_UPDATE_RELEVANCE_INCLUDE_REGEX   Override include regex for pipeline-relevant change filtering
  PM_SELF_UPDATE_RELEVANCE_EXCLUDE_REGEX   Override exclude regex for non-pipeline change filtering
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
  printf '%s' "$CODEX_PINNED_MODEL"
}

resolved_codex_reasoning_effort() {
  printf '%s' "$CODEX_PINNED_REASONING_EFFORT"
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

validate_lead_model_profile() {
  canonical_lead_model_profile "$1" >/dev/null 2>&1
}

canonical_lead_model_profile() {
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

lead_model_label_for_profile() {
  local profile="$1"
  local canonical_profile

  canonical_profile="$(canonical_lead_model_profile "$profile")" || return 1

  case "$canonical_profile" in
    "$LEAD_MODEL_PROFILE_FULL_CODEX")
      printf '%s' "$LEAD_MODEL_OPTION_FULL_CODEX"
      ;;
    "$LEAD_MODEL_PROFILE_CODEX_MAIN")
      printf '%s' "$LEAD_MODEL_OPTION_CODEX_MAIN"
      ;;
    "$LEAD_MODEL_PROFILE_CLAUDE_MAIN")
      printf '%s' "$LEAD_MODEL_OPTION_CLAUDE_MAIN"
      ;;
    *)
      return 1
      ;;
  esac
}

lead_model_state_init_json() {
  local now="$1"
  local default_label

  default_label="$(lead_model_label_for_profile "$LEAD_MODEL_DEFAULT_PROFILE")"

  cat <<EOF
{
  "schema_version": $LEAD_MODEL_SCHEMA_VERSION,
  "selected_profile": "$LEAD_MODEL_DEFAULT_PROFILE",
  "selected_label": "$default_label",
  "updated_at": "$now",
  "last_selected_by": "default_bootstrap"
}
EOF
}

validate_lead_model_state_file() {
  local state_file="$1"
  local profile

  jq -e '
    .schema_version == 1 and
    (.selected_profile | type == "string") and
    (.selected_label | type == "string") and
    (.updated_at | type == "string") and
    (.last_selected_by | type == "string")
  ' "$state_file" >/dev/null || return 1

  profile="$(jq -r '.selected_profile' "$state_file")"
  validate_lead_model_profile "$profile"
}

ensure_lead_model_state_file() {
  local state_file="$1"
  local now

  now="$(now_utc)"
  mkdir -p "$(dirname "$state_file")"

  if [ ! -f "$state_file" ]; then
    lead_model_state_init_json "$now" >"$state_file"
  fi

  if ! validate_lead_model_state_file "$state_file"; then
    die "Lead-model state file is invalid/corrupt and will not be mutated: $state_file"
  fi

  normalize_lead_model_state_file "$state_file"
}

lead_model_state_get_profile() {
  local state_file="$1"
  jq -r '.selected_profile' "$state_file"
}

lead_model_state_get_updated_at() {
  local state_file="$1"
  jq -r '.updated_at' "$state_file"
}

lead_model_state_set_profile() {
  local state_file="$1"
  local profile="$2"
  local selected_by="$3"
  local canonical_profile label now tmp

  validate_lead_model_profile "$profile" || die "Invalid lead-model profile: $profile"
  canonical_profile="$(canonical_lead_model_profile "$profile")"
  label="$(lead_model_label_for_profile "$canonical_profile")"
  now="$(now_utc)"
  tmp="$(mktemp "${state_file}.tmp.XXXX")"

  jq \
    --arg profile "$canonical_profile" \
    --arg label "$label" \
    --arg selected_by "$selected_by" \
    --arg now "$now" \
    '
      .schema_version = 1 |
      .selected_profile = $profile |
      .selected_label = $label |
      .last_selected_by = $selected_by |
      .updated_at = $now
    ' "$state_file" >"$tmp"
  mv "$tmp" "$state_file"
}

normalize_lead_model_state_file() {
  local state_file="$1"
  local current_profile canonical_profile current_label canonical_label selected_by now tmp

  current_profile="$(jq -r '.selected_profile' "$state_file")"
  canonical_profile="$(canonical_lead_model_profile "$current_profile" || true)"
  [ -n "$canonical_profile" ] || die "Lead-model state file has unsupported profile: $state_file"

  current_label="$(jq -r '.selected_label' "$state_file")"
  canonical_label="$(lead_model_label_for_profile "$canonical_profile")"
  if [ "$current_profile" = "$canonical_profile" ] && [ "$current_label" = "$canonical_label" ]; then
    return 0
  fi

  selected_by="$(jq -r '.last_selected_by' "$state_file")"
  if [ -z "$selected_by" ] || [ "$selected_by" = "null" ]; then
    selected_by="legacy_profile_migration"
  fi
  now="$(now_utc)"
  tmp="$(mktemp "${state_file}.tmp.XXXX")"

  jq \
    --arg profile "$canonical_profile" \
    --arg label "$canonical_label" \
    --arg selected_by "$selected_by" \
    --arg now "$now" \
    '
      .schema_version = 1 |
      .selected_profile = $profile |
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
  CLAUDE_MCP_LAST_DETAIL="Claude MCP server is missing, disabled, or unhealthy. Falling back to codex-native runtime for mapped roles."
  CLAUDE_MCP_LAST_COMMAND=""
  CLAUDE_MCP_LAST_COMMAND_SOURCE=""
  CLAUDE_MCP_LAST_PATH_OVERRIDE=""
  CLAUDE_MCP_LAST_PATH_OVERRIDE_SOURCE=""

  if [ "$force_unavailable" -eq 1 ]; then
    return 1
  fi

  if [ "$force_available" -eq 1 ]; then
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

emit_routing_role() {
  local role="$1"
  local runtime="$2"
  local model="${3:-<unpinned>}"
  local reasoning_effort="${4:-<unpinned>}"
  local agent_type="$5"
  local role_class="$6"

  echo "ROUTING_ROLE|role=$role|class=$role_class|runtime=$runtime|model=$model|reasoning_effort=$reasoning_effort|agent_type=$agent_type"
}

emit_routing_matrix_for_profile_with_runtime_fallback() {
  local profile="$1"
  local from_runtime="$2"
  local to_runtime="$3"
  local to_model="$4"
  local to_reasoning_effort="$5"
  local line role_class role runtime model agent_type

  while IFS= read -r line; do
    case "$line" in
      ROUTING_ROLE\|*)
        runtime="$(pipe_kv_get "$line" "runtime" || true)"
        if [ "$runtime" = "$from_runtime" ]; then
          role="$(pipe_kv_get "$line" "role" || true)"
          role_class="$(pipe_kv_get "$line" "class" || true)"
          agent_type="$(pipe_kv_get "$line" "agent_type" || true)"
          emit_routing_role "$role" "$to_runtime" "$to_model" "$to_reasoning_effort" "$agent_type" "$role_class"
        else
          echo "$line"
        fi
        ;;
      *)
        echo "$line"
        ;;
    esac
  done < <(emit_routing_matrix_for_profile "$profile")
}

emit_routing_matrix_for_profile() {
  local profile="$1"
  local codex_model codex_reasoning_effort
  local canonical_profile

  codex_model="$(resolved_codex_model)"
  codex_reasoning_effort="$(resolved_codex_reasoning_effort)"
  canonical_profile="$(canonical_lead_model_profile "$profile")" || die "Unknown routing profile: $profile"

  case "$canonical_profile" in
    "$LEAD_MODEL_PROFILE_FULL_CODEX")
      emit_routing_role "project_manager" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "main"
      emit_routing_role "team_lead" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "main"
      emit_routing_role "pm_beads_plan_handoff" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "main"
      emit_routing_role "pm_implement_handoff" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "main"
      emit_routing_role "senior_engineer" "codex-native" "$codex_model" "$codex_reasoning_effort" "explorer" "sub"
      emit_routing_role "librarian" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "sub"
      emit_routing_role "smoke_test_planner" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "sub"
      emit_routing_role "alternative_pm" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "sub"
      emit_routing_role "researcher" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "sub"
      emit_routing_role "backend_engineer" "codex-native" "$codex_model" "$codex_reasoning_effort" "worker" "sub"
      emit_routing_role "frontend_engineer" "codex-native" "$codex_model" "$codex_reasoning_effort" "worker" "sub"
      emit_routing_role "security_engineer" "codex-native" "$codex_model" "$codex_reasoning_effort" "worker" "sub"
      emit_routing_role "agents_compliance_reviewer" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "sub"
      emit_routing_role "jazz_reviewer" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "sub"
      emit_routing_role "codex_reviewer" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "sub"
      emit_routing_role "manual_qa" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "sub"
      emit_routing_role "task_verification" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "sub"
      ;;
    "$LEAD_MODEL_PROFILE_CODEX_MAIN")
      emit_routing_role "project_manager" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "main"
      emit_routing_role "team_lead" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "main"
      emit_routing_role "pm_beads_plan_handoff" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "main"
      emit_routing_role "pm_implement_handoff" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "main"
      emit_routing_role "senior_engineer" "claude-code-mcp" "" "" "explorer" "sub"
      emit_routing_role "librarian" "claude-code-mcp" "" "" "default" "sub"
      emit_routing_role "smoke_test_planner" "claude-code-mcp" "" "" "default" "sub"
      emit_routing_role "alternative_pm" "claude-code-mcp" "" "" "default" "sub"
      emit_routing_role "researcher" "claude-code-mcp" "" "" "default" "sub"
      emit_routing_role "backend_engineer" "codex-native" "$codex_model" "$codex_reasoning_effort" "worker" "sub"
      emit_routing_role "frontend_engineer" "codex-native" "$codex_model" "$codex_reasoning_effort" "worker" "sub"
      emit_routing_role "security_engineer" "codex-native" "$codex_model" "$codex_reasoning_effort" "worker" "sub"
      emit_routing_role "agents_compliance_reviewer" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "sub"
      emit_routing_role "jazz_reviewer" "claude-code-mcp" "" "" "default" "sub"
      emit_routing_role "codex_reviewer" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "sub"
      emit_routing_role "manual_qa" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "sub"
      emit_routing_role "task_verification" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "sub"
      ;;
    "$LEAD_MODEL_PROFILE_CLAUDE_MAIN")
      emit_routing_role "project_manager" "claude-code-mcp" "" "" "default" "main"
      emit_routing_role "team_lead" "claude-code-mcp" "" "" "default" "main"
      emit_routing_role "pm_beads_plan_handoff" "claude-code-mcp" "" "" "default" "main"
      emit_routing_role "pm_implement_handoff" "claude-code-mcp" "" "" "default" "main"
      emit_routing_role "senior_engineer" "codex-native" "$codex_model" "$codex_reasoning_effort" "explorer" "sub"
      emit_routing_role "librarian" "claude-code-mcp" "" "" "default" "sub"
      emit_routing_role "smoke_test_planner" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "sub"
      emit_routing_role "alternative_pm" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "sub"
      emit_routing_role "researcher" "claude-code-mcp" "" "" "default" "sub"
      emit_routing_role "backend_engineer" "claude-code-mcp" "" "" "worker" "sub"
      emit_routing_role "frontend_engineer" "claude-code-mcp" "" "" "worker" "sub"
      emit_routing_role "security_engineer" "claude-code-mcp" "" "" "worker" "sub"
      emit_routing_role "agents_compliance_reviewer" "claude-code-mcp" "" "" "default" "sub"
      emit_routing_role "jazz_reviewer" "codex-native" "$codex_model" "$codex_reasoning_effort" "default" "sub"
      emit_routing_role "codex_reviewer" "claude-code-mcp" "" "" "default" "sub"
      emit_routing_role "manual_qa" "claude-code-mcp" "" "" "default" "sub"
      emit_routing_role "task_verification" "claude-code-mcp" "" "" "default" "sub"
      ;;
    *)
      die "Unknown routing profile: $profile"
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
- $pm lead-model show|set|reset
- $pm claude-contract validate-context|evaluate-response|run-loop
- $pm telemetry init-db|log-step|query-task|query-run
- $pm self-update
- $pm help

Required PM phase order:
Discovery -> PRD -> Awaiting PRD Approval -> Beads Planning -> Awaiting Beads Approval -> Team Lead Orchestration -> Implementation -> Post-Implementation Reviews -> Review Iteration -> Manual QA Smoke Tests -> Awaiting Final Review

Approval gates:
- PRD approval reply must be exactly: approved
- Beads approval reply must be exactly: approved
- Lead-model gate runs before Discovery on both plan routes
- Lead-model options are:
  - Full Codex Orchestration
  - Codex as Main Agent
  - Claude as Main Orchestrator
- Codex-native orchestrator roles are pinned to `gpt-5.4` with `xhigh` reasoning effort
- Selected orchestration mode persists in .codex and is reused by default
- `Codex as Main Agent` checks Claude MCP immediately after selection and offers fallback to `Full Codex Orchestration` when unavailable
- `Claude as Main Orchestrator` fails before Discovery when Claude MCP is unavailable or unusable
- If the plan gate reports `PLAN_ROUTE_BLOCKED` or `discovery_can_start=0`, do not enter Discovery or any downstream phase
- If a required Claude-routed role later fails at runtime (for example `no supported agent type`), block the current phase and return control to PM with reason-specific remediation

Self-update policy:
- Manual-only invocation
- Changelog website is source-of-truth
- Stable + prerelease batch verification
- Filter non-pipeline changes and emit integration-plan suggestions for relevant updates
- Completion requires PRD evidence coverage for all pending versions

Runtime policy:
- Orchestration-mode-driven runtime (`codex-main` default, `full-codex` and `claude-main` optional)
- Claude usage is permitted only through claude-code MCP
- Claude availability requires both a healthy `codex mcp list` entry and an executable configured command in the actual PM runtime
- Blocked Claude-dependent modes or phases must not continue in degraded fallback
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

run_lead_model() {
  local action="${1:-show}"
  local state_file=""
  local profile=""
  local selected_profile selected_label updated_at codex_model codex_reasoning_effort

  shift || true

  while [ $# -gt 0 ]; do
    case "$1" in
      --state-file)
        state_file="${2:-}"
        shift 2
        ;;
      --profile)
        profile="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown lead-model argument: $1"
        ;;
    esac
  done

  [ -n "$state_file" ] || state_file="$(default_lead_model_state_file)"

  if [ "$action" = "reset" ]; then
    mkdir -p "$(dirname "$state_file")"
    if [ ! -f "$state_file" ] || ! validate_lead_model_state_file "$state_file" >/dev/null 2>&1; then
      lead_model_state_init_json "$(now_utc)" >"$state_file"
    fi
  else
    ensure_lead_model_state_file "$state_file"
  fi

  case "$action" in
    show)
      ;;
    set)
      [ -n "$profile" ] || die "--profile is required for lead-model set"
      validate_lead_model_profile "$profile" || die "Invalid lead-model profile: $profile"
      lead_model_state_set_profile "$state_file" "$profile" "manual_set"
      ;;
    reset)
      lead_model_state_set_profile "$state_file" "$LEAD_MODEL_DEFAULT_PROFILE" "manual_reset"
      ;;
    *)
      die "Unknown lead-model action: $action"
      ;;
  esac

  selected_profile="$(lead_model_state_get_profile "$state_file")"
  selected_label="$(lead_model_label_for_profile "$selected_profile")"
  updated_at="$(lead_model_state_get_updated_at "$state_file")"
  codex_model="$(resolved_codex_model)"
  codex_reasoning_effort="$(resolved_codex_reasoning_effort)"
  echo "LEAD_MODEL_STATE|action=$action|profile=$selected_profile|label=$selected_label|codex_model=$codex_model|codex_reasoning_effort=$codex_reasoning_effort|state_file=$(display_path "$state_file")|updated_at=$updated_at"
}

run_plan_gate() {
  local route=""
  local state_file=""
  local lead_model_override=""
  local persisted_profile selected_profile selected_label selected_main_runtime selected_main_model selected_main_reasoning_effort
  local codex_model codex_reasoning_effort
  local requires_claude_mcp=0
  local claude_available=0
  local block_reason=""
  local block_remediation=""
  local block_detail=""
  local fallback_profile=""
  local fallback_label=""
  local fallback_offer=0
  local next_action="start_discovery"
  local gate_started_at gate_ended_at gate_duration_ms
  local gate_start_ms gate_end_ms

  gate_started_at="$(now_utc)"
  gate_start_ms="$(epoch_ms)"

  while [ $# -gt 0 ]; do
    case "$1" in
      --route)
        route="${2:-}"
        shift 2
        ;;
      --lead-model)
        lead_model_override="${2:-}"
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

  [ -n "$state_file" ] || state_file="$(default_lead_model_state_file)"
  ensure_lead_model_state_file "$state_file"
  persisted_profile="$(lead_model_state_get_profile "$state_file")"

  if [ -n "$lead_model_override" ]; then
    validate_lead_model_profile "$lead_model_override" || die "Invalid lead-model profile: $lead_model_override"
    lead_model_state_set_profile "$state_file" "$lead_model_override" "plan_gate_override"
  fi

  selected_profile="$(lead_model_state_get_profile "$state_file")"
  selected_label="$(lead_model_label_for_profile "$selected_profile")"
  codex_model="$(resolved_codex_model)"
  codex_reasoning_effort="$(resolved_codex_reasoning_effort)"

  echo "LEAD_MODEL_GATE|route=$route|question=Select orchestration mode before Discovery|options=$LEAD_MODEL_OPTION_FULL_CODEX;$LEAD_MODEL_OPTION_CODEX_MAIN;$LEAD_MODEL_OPTION_CLAUDE_MAIN|persisted_profile=$persisted_profile|selected_profile=$selected_profile|selected_label=$selected_label|codex_model=$codex_model|codex_reasoning_effort=$codex_reasoning_effort|state_file=$(display_path "$state_file")"

  case "$selected_profile" in
    "$LEAD_MODEL_PROFILE_FULL_CODEX")
      selected_main_runtime="codex-native"
      selected_main_model="$codex_model"
      selected_main_reasoning_effort="$codex_reasoning_effort"
      ;;
    "$LEAD_MODEL_PROFILE_CODEX_MAIN")
      selected_main_runtime="codex-native"
      selected_main_model="$codex_model"
      selected_main_reasoning_effort="$codex_reasoning_effort"
      requires_claude_mcp=1
      ;;
    "$LEAD_MODEL_PROFILE_CLAUDE_MAIN")
      selected_main_runtime="claude-code-mcp"
      selected_main_model="$UNPINNED_MODEL_VALUE"
      selected_main_reasoning_effort="$UNPINNED_REASONING_VALUE"
      requires_claude_mcp=1
      ;;
    *)
      die "Unsupported selected lead-model profile: $selected_profile"
      ;;
  esac

  if [ "$requires_claude_mcp" -eq 1 ] && claude_mcp_available; then
    claude_available=1
  fi

  if [ "$requires_claude_mcp" -eq 1 ] && [ "$claude_available" -eq 0 ]; then
    block_reason="${CLAUDE_MCP_LAST_REASON:-claude_code_mcp_unavailable}"
    block_remediation="${CLAUDE_MCP_LAST_REMEDIATION:-$CLAUDE_MCP_REMEDIATION_MISSING}"
    block_detail="${CLAUDE_MCP_LAST_DETAIL:-Claude MCP unavailable. Discovery cannot start for this orchestration mode.}"
    case "$selected_profile" in
      "$LEAD_MODEL_PROFILE_CODEX_MAIN")
        fallback_profile="$LEAD_MODEL_PROFILE_FULL_CODEX"
        fallback_label="$LEAD_MODEL_OPTION_FULL_CODEX"
        fallback_offer=1
        next_action="ask_user_for_full_codex_fallback"
        ;;
      "$LEAD_MODEL_PROFILE_CLAUDE_MAIN")
        next_action="fix_claude_mcp_or_choose_supported_mode"
        ;;
    esac
    echo "PLAN_ROUTE_BLOCKED|route=$route|selected_profile=$selected_profile|selected_label=$selected_label|reason=$block_reason|remediation=$block_remediation|detail=$block_detail|fallback_offer=$fallback_offer|fallback_profile=$fallback_profile|fallback_label=$fallback_label|next_action=$next_action|discovery_can_start=0"
    telemetry_record_event_nonblocking \
      "$(telemetry_new_event_id "plan-gate" "blocked")" \
      "${PM_WORKFLOW_RUN_ID:-plan-gate}" \
      "${PM_TASK_ID:-}" \
      "plan.gate.blocked" \
      "" \
      "Plan Gate" \
      "Plan Gate Blocked" \
      "warning" \
      "project_manager" \
      "project_manager" \
      "$selected_main_runtime" \
      "codex" \
      "$selected_main_model" \
      "$gate_started_at" \
      "" \
      "" \
      "" \
      "" \
      "" \
      "$TELEMETRY_DEFAULT_USAGE_SOURCE" \
      "missing_runtime" \
      "warning" \
      "$block_reason" \
      "$block_detail" \
      "$block_remediation" \
      "" \
      "" \
      "" \
      "{\"route\":\"$route\",\"selected_profile\":\"$selected_profile\",\"fallback_offer\":$fallback_offer}"
    return 1
  fi

  echo "ROUTING_PROFILE|route=$route|profile=$selected_profile|main_runtime=$selected_main_runtime|main_model=$selected_main_model|main_reasoning_effort=$selected_main_reasoning_effort|fallback_active=0"
  emit_routing_matrix_for_profile "$selected_profile"

  gate_ended_at="$(now_utc)"
  gate_end_ms="$(epoch_ms)"
  gate_duration_ms="$((gate_end_ms - gate_start_ms))"
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
    "${PM_TELEMETRY_PROVIDER:-codex}" \
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
    "{\"route\":\"$route\",\"fallback_active\":0}"
  echo "PLAN_ROUTE_READY|route=$route|selected_profile=$selected_profile|selected_label=$selected_label|discovery_can_start=1"
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
    lead-model)
      run_lead_model "$@"
      ;;
    plan)
      run_plan "$@"
      ;;
    claude-contract)
      run_claude_contract "$@"
      ;;
    telemetry)
      run_telemetry "$@"
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
