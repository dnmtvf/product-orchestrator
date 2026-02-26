#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
APPROVAL_TOKEN="approved"
DEFAULT_CHANGELOG_URL="https://developers.openai.com/codex/changelog/"
DEFAULT_RELEASE_URL="https://github.com/openai/codex/releases/latest"
STATE_RELATIVE_PATH=".codex/pm-self-update-state.json"

usage() {
  cat <<'EOF'
Codex-only PM command helper.

Usage:
  pm-command.sh help
  pm-command.sh self-update [check] [--state-file PATH] [--changelog-url URL] [--release-url URL]
  pm-command.sh self-update complete --approval approved --prd-approval approved --beads-approval approved --prd-path PATH [--state-file PATH] [--dry-run]

Commands:
  help          Print deterministic $pm help output.
  self-update   Manual self-update orchestration. Defaults to check mode.

Self-update modes:
  check         Fetch latest Codex versions from official sources, compare to state, and stage pending update.
  complete      Advance processed version only after explicit approval gate and create checkpoint commit.

Notes:
  - This workflow is manual-only. No scheduled/background triggers are provided.
  - Completion requires exact approval token: approved
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

now_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

normalize_version() {
  local value="$1"
  value="${value#v}"
  printf '%s' "$value"
}

latest_semver_from_text() {
  local payload="$1"
  local parsed
  parsed="$(printf '%s' "$payload" | grep -Eo 'v?[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?' | sed 's/^v//' | sort -Vu | tail -n1 || true)"
  [ -n "$parsed" ] || return 1
  printf '%s' "$parsed"
}

latest_codex_semver_from_changelog() {
  local payload="$1"
  local normalized parsed

  # Strip HTML tags first to avoid matching script/library versions in raw markup.
  normalized="$(printf '%s' "$payload" | sed 's/<[^>]*>/ /g' | tr '\r' '\n')"

  parsed="$(
    printf '%s' "$normalized" \
      | grep -Ei 'codex[[:space:]]+cli' \
      | grep -Eo 'v?[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?' \
      | sed 's/^v//' \
      | sort -Vu \
      | tail -n1 || true
  )"

  if [ -z "$parsed" ]; then
    parsed="$(
      printf '%s' "$normalized" \
        | grep -Ei 'codex' \
        | grep -Eo 'v?[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?' \
        | sed 's/^v//' \
        | sort -Vu \
        | tail -n1 || true
    )"
  fi

  [ -n "$parsed" ] || return 1
  printf '%s' "$parsed"
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

max_version() {
  local a="$1"
  local b="$2"
  printf '%s\n%s\n' "$a" "$b" | sort -V | tail -n1
}

version_gt() {
  local candidate="$1"
  local baseline="$2"

  if [ -z "$baseline" ]; then
    return 0
  fi

  local top
  top="$(max_version "$candidate" "$baseline")"
  [ "$top" = "$candidate" ] && [ "$candidate" != "$baseline" ]
}

state_init_json() {
  local checked_at="$1"
  cat <<EOF
{
  "schema_version": 1,
  "latest_processed_codex_version": "",
  "pending_codex_version": "",
  "last_checked_codex_version": "",
  "last_check": {
    "checked_at": "$checked_at",
    "changelog_version": "",
    "release_version": "",
    "selected_version": "",
    "sources": [
      "$DEFAULT_CHANGELOG_URL",
      "$DEFAULT_RELEASE_URL"
    ]
  },
  "last_checkpoint_ref": "",
  "updated_at": "$checked_at"
}
EOF
}

validate_state_file() {
  local state_file="$1"

  jq -e '
    .schema_version == 1 and
    (.latest_processed_codex_version | type == "string") and
    (.pending_codex_version | type == "string") and
    (.last_checked_codex_version | type == "string") and
    (.last_checkpoint_ref | type == "string") and
    (.updated_at | type == "string") and
    (.last_check | type == "object") and
    (.last_check.checked_at | type == "string") and
    (.last_check.changelog_version | type == "string") and
    (.last_check.release_version | type == "string") and
    (.last_check.selected_version | type == "string") and
    (.last_check.sources | type == "array")
  ' "$state_file" >/dev/null
}

ensure_state_file() {
  local state_file="$1"
  local now
  now="$(now_utc)"

  mkdir -p "$(dirname "$state_file")"

  if [ ! -f "$state_file" ]; then
    state_init_json "$now" >"$state_file"
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

state_update() {
  local state_file="$1"
  local jq_expr="$2"
  local tmp
  tmp="$(mktemp "${state_file}.tmp.XXXX")"

  jq "$jq_expr" "$state_file" >"$tmp"
  mv "$tmp" "$state_file"
}

checkpoint_commit() {
  local state_file="$1"
  local version="$2"
  local dry_run="$3"
  local root rel

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

  # Commit only the state file path to avoid sweeping unrelated staged files.
  git -C "$root" commit -m "chore(pm-self-update): checkpoint codex version $version" -- "$rel" >/dev/null
  local sha
  sha="$(git -C "$root" rev-parse HEAD)"
  echo "CHECKPOINT_CREATED|version=$version|commit=$sha|state_file=$rel"
}

assert_open_questions_empty() {
  local prd_path="$1"
  local body

  [ -f "$prd_path" ] || die "PRD path not found: $prd_path"

  body="$(
    awk '
      BEGIN { in_open=0 }
      /^## 14\. Open Questions/ { in_open=1; next }
      /^## / && in_open { exit }
      in_open { print }
    ' "$prd_path"
  )"

  if printf '%s' "$body" | grep -Eq '[A-Za-z0-9]'; then
    die "PRD Open Questions must be empty before completion: $prd_path"
  fi
}

print_help_output() {
  cat <<'EOF'
$pm help

Supported invocations:
- $pm plan: <feature request>
- $pm plan big feature: <feature request>
- $pm self-update
- $pm help

Required PM phase order:
Discovery -> PRD -> Awaiting PRD Approval -> Beads Planning -> Awaiting Beads Approval -> Team Lead Orchestration -> Implementation -> Post-Implementation Reviews -> Review Iteration -> Manual QA Smoke Tests -> Awaiting Final Review

Approval gates:
- PRD approval reply must be exactly: approved
- Beads approval reply must be exactly: approved

Runtime policy:
- Codex-only runtime execution path
- Claude usage is permitted only through claude-code MCP
EOF
}

run_self_update_check() {
  local state_file="$1"
  local changelog_url="$2"
  local release_url="$3"
  local changelog_payload_override="${PM_SELF_UPDATE_CHANGELOG_PAYLOAD:-}"
  local now changelog_payload changelog_version release_effective_url release_version selected current

  ensure_state_file "$state_file"
  now="$(now_utc)"

  changelog_payload="$(fetch_url "$changelog_url" "$changelog_payload_override")" || die "Failed to fetch Codex changelog from $changelog_url"
  changelog_version="$(latest_codex_semver_from_changelog "$changelog_payload" || true)"
  [ -n "$changelog_version" ] || die "Failed to parse version from Codex changelog payload"

  release_effective_url="$(fetch_release_effective_url "$release_url")" || die "Failed to resolve latest Codex release URL from $release_url"
  release_version="$(latest_semver_from_text "$release_effective_url" || true)"
  [ -n "$release_version" ] || die "Failed to parse version from Codex release redirect URL: $release_effective_url"

  changelog_version="$(normalize_version "$changelog_version")"
  release_version="$(normalize_version "$release_version")"
  selected="$(max_version "$changelog_version" "$release_version")"
  current="$(state_get "$state_file" '.latest_processed_codex_version')"

  if version_gt "$selected" "$current"; then
    state_update "$state_file" "
      .pending_codex_version = \"$selected\" |
      .last_checked_codex_version = \"$selected\" |
      .last_check.checked_at = \"$now\" |
      .last_check.changelog_version = \"$changelog_version\" |
      .last_check.release_version = \"$release_version\" |
      .last_check.selected_version = \"$selected\" |
      .last_check.sources = [\"$changelog_url\", \"$release_url\"] |
      .updated_at = \"$now\"
    "

    echo "UPDATE_AVAILABLE|processed_version=${current:-<none>}|latest_version=$selected|changelog_version=$changelog_version|release_version=$release_version"
    echo "PLAN_TRIGGER|/pm plan: Inspect latest Codex changes and align orchestrator behavior with Codex-only runtime policy."
    echo "PLAN_CONTEXT|detected_version=$selected"
    echo "GATE_REQUIRED|After PM flow completion, run: $SCRIPT_NAME self-update complete --approval approved --prd-approval approved --beads-approval approved --prd-path <approved-prd-path>"
    return 0
  fi

  state_update "$state_file" "
    .pending_codex_version = \"\" |
    .last_checked_codex_version = \"$selected\" |
    .last_check.checked_at = \"$now\" |
    .last_check.changelog_version = \"$changelog_version\" |
    .last_check.release_version = \"$release_version\" |
    .last_check.selected_version = \"$selected\" |
    .last_check.sources = [\"$changelog_url\", \"$release_url\"] |
    .updated_at = \"$now\"
  "

  echo "NO_OP|processed_version=${current:-<none>}|latest_version=$selected|reason=up_to_date"
}

run_self_update_complete() {
  local state_file="$1"
  local approval="$2"
  local prd_approval="$3"
  local beads_approval="$4"
  local prd_path="$5"
  local dry_run="$6"
  local pending now backup

  ensure_state_file "$state_file"

  [ "$approval" = "$APPROVAL_TOKEN" ] || die "Completion gate failed. Expected --approval $APPROVAL_TOKEN"
  [ "$prd_approval" = "$APPROVAL_TOKEN" ] || die "Completion gate failed. Expected --prd-approval $APPROVAL_TOKEN"
  [ "$beads_approval" = "$APPROVAL_TOKEN" ] || die "Completion gate failed. Expected --beads-approval $APPROVAL_TOKEN"
  assert_open_questions_empty "$prd_path"

  pending="$(state_get "$state_file" '.pending_codex_version')"
  [ -n "$pending" ] || die "No pending Codex version to complete"
  pending="$(normalize_version "$pending")"
  now="$(now_utc)"

  if [ "$dry_run" -eq 1 ]; then
    echo "CHECKPOINT_DRY_RUN|state_file=${state_file##*/}|version=$pending"
    echo "COMPLETE_DRY_RUN|latest_processed_codex_version=$pending"
    return 0
  fi

  backup="$(mktemp "${state_file}.backup.XXXX")"
  cp "$state_file" "$backup"

  state_update "$state_file" "
    .latest_processed_codex_version = \"$pending\" |
    .pending_codex_version = \"\" |
    .last_checkpoint_ref = \"codex-version-$pending\" |
    .updated_at = \"$now\"
  "

  if ! checkpoint_commit "$state_file" "$pending" 0; then
    cp "$backup" "$state_file"
    rm -f "$backup"
    die "Checkpoint commit failed; restored previous state"
  fi

  rm -f "$backup"
  echo "COMPLETE|latest_processed_codex_version=$pending"
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
      run_self_update_check "$state_file" "$changelog_url" "$release_url"
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

main() {
  require_tool curl
  require_tool jq
  require_tool git

  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    help)
      print_help_output
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
