#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
APPROVAL_TOKEN="approved"
DEFAULT_CHANGELOG_URL="https://developers.openai.com/codex/changelog/"
DEFAULT_RELEASE_URL="https://github.com/openai/codex/releases/latest"
DEFAULT_NPM_TAGS_URL="https://registry.npmjs.org/-/package/@openai/codex/dist-tags"
DEFAULT_PLAN_TRIGGER="/pm plan: Inspect latest Codex changes and align orchestrator behavior with Codex-only runtime policy."
STATE_RELATIVE_PATH=".codex/pm-self-update-state.json"
SEMVER_PATTERN='v?[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?'

usage() {
  cat <<'EOF'
Codex-only PM command helper.

Usage:
  pm-command.sh help
  pm-command.sh self-update [check] [--state-file PATH] [--changelog-url URL] [--release-url URL] [--npm-tags-url URL]
  pm-command.sh self-update complete --approval approved --prd-approval approved --beads-approval approved --prd-path PATH [--state-file PATH] [--dry-run]

Commands:
  help          Print deterministic $pm help output.
  self-update   Manual self-update orchestration. Defaults to check mode.

Self-update modes:
  check         Build changelog-source-of-truth pending batch (stable + prerelease by default).
  complete      Advance processed version only after explicit approval gate and PRD evidence coverage.

Environment toggles:
  PM_SELF_UPDATE_INCLUDE_PRERELEASE=1|0   Include prerelease entries from changelog (default: 1)
  PM_SELF_UPDATE_STRICT_MISMATCH=1|0      Fail check when corroborative sources disagree with changelog (default: 0)

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

now_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
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
  [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.+][0-9A-Za-z.-]+)?([+][0-9A-Za-z.-]+)?$ ]]
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
  local -a raw sorted next

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

extract_codex_versions_from_changelog() {
  local payload="$1"
  local include_prerelease="$2"
  local normalized codex_cli_lines codex_lines parsed

  normalized="$(printf '%s' "$payload" | sed 's/<[^>]*>/ /g' | tr '\r' '\n')"

  # Prefer Codex CLI-labelled lines to avoid unrelated semver values from shared site chrome/content.
  codex_cli_lines="$(printf '%s\n' "$normalized" | grep -Ei 'codex[[:space:]-]*cli' || true)"
  if [ -n "$codex_cli_lines" ]; then
    codex_lines="$codex_cli_lines"
  else
    codex_lines="$(printf '%s\n' "$normalized" | grep -Ei 'codex' || true)"
  fi
  [ -n "$codex_lines" ] || return 1

  parsed="$({ printf '%s\n' "$codex_lines" | grep -Eo "$SEMVER_PATTERN" || true; } | sed 's/^v//')"
  [ -n "$parsed" ] || return 1

  if [ -z "$codex_cli_lines" ]; then
    # Fallback extraction is noisier; clamp to expected major range for Codex release identifiers.
    parsed="$(printf '%s\n' "$parsed" | grep -E '^(0|1)\.' || true)"
    [ -n "$parsed" ] || return 1
  fi

  if [ "$include_prerelease" -eq 0 ]; then
    parsed="$(printf '%s\n' "$parsed" | grep -Ev '-' || true)"
    [ -n "$parsed" ] || return 1
  fi

  printf '%s\n' "$parsed" | semver_sort_unique
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
  local root rel sha

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

  git -C "$root" commit -m "chore(pm-self-update): checkpoint codex version $version" -- "$rel" >/dev/null
  sha="$(git -C "$root" rev-parse HEAD)"
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

  if printf '%s' "$body" | grep -Eq '[A-Za-z0-9]'; then
    die "PRD Open Questions must be empty before completion: $prd_path"
  fi
}

assert_prd_covers_versions() {
  local prd_path="$1"
  local versions="$2"
  local version content missing_list
  local -a missing

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
- $pm self-update
- $pm help

Required PM phase order:
Discovery -> PRD -> Awaiting PRD Approval -> Beads Planning -> Awaiting Beads Approval -> Team Lead Orchestration -> Implementation -> Post-Implementation Reviews -> Review Iteration -> Manual QA Smoke Tests -> Awaiting Final Review

Approval gates:
- PRD approval reply must be exactly: approved
- Beads approval reply must be exactly: approved

Self-update policy:
- Manual-only invocation
- Changelog website is source-of-truth
- Stable + prerelease batch verification
- Completion requires PRD evidence coverage for all pending versions

Runtime policy:
- Codex-only runtime execution path
- Claude usage is permitted only through claude-code MCP
EOF
}

run_self_update_check() {
  local state_file="$1"
  local changelog_url="$2"
  local release_url="$3"
  local npm_tags_url="$4"

  local now changelog_payload changelog_versions latest_changelog
  local current pending_versions pending_count pending_csv pending_json
  local changelog_json mismatch_json mismatch_csv batch_id to_version
  local release_effective_url release_version npm_payload npm_latest npm_alpha
  local include_state strict_state include_prerelease strict_mismatch
  local include_prerelease_json strict_mismatch_json
  local -a mismatch_flags

  ensure_state_file "$state_file"
  now="$(now_utc)"

  include_state="$(state_get "$state_file" '.feature_flags.include_prerelease')"
  strict_state="$(state_get "$state_file" '.feature_flags.strict_mismatch')"
  include_prerelease="$(resolve_bool_setting "PM_SELF_UPDATE_INCLUDE_PRERELEASE" "$include_state" 1)"
  strict_mismatch="$(resolve_bool_setting "PM_SELF_UPDATE_STRICT_MISMATCH" "$strict_state" 0)"

  changelog_payload="$(fetch_url "$changelog_url" "${PM_SELF_UPDATE_CHANGELOG_PAYLOAD:-}")" || die "Failed to fetch Codex changelog from $changelog_url"
  changelog_versions="$(extract_codex_versions_from_changelog "$changelog_payload" "$include_prerelease" || true)"
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

  changelog_json="$(printf '%s\n' "$changelog_versions" | json_array_from_newlines)"
  mismatch_json="$(printf '%s\n' "$mismatch_csv" | tr ',' '\n' | json_array_from_newlines)"
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
    echo "SOURCE_OF_TRUTH|url=$changelog_url"
    if [ -n "$mismatch_csv" ]; then
      echo "SOURCE_MISMATCH|flags=$mismatch_csv"
    fi
    echo "PLAN_TRIGGER|$DEFAULT_PLAN_TRIGGER"
    echo "PLAN_CONTEXT|detected_version=$to_version|pending_count=$pending_count|batch_id=$batch_id"
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
