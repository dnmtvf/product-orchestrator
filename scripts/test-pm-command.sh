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

TMPDIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

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
assert_contains "$help_out" '$pm self-update'
assert_contains "$help_out" 'Self-update policy:'
assert_contains "$help_out" 'Filter non-pipeline changes and emit integration-plan suggestions'

STATE_FILE="$TMPDIR/.claude/pm-self-update-state.json"
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
assert_contains "$commit_files" '.claude/pm-self-update-state.json'
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
