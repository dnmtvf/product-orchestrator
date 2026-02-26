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

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool missing: $1"
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
assert_contains "$help_out" 'Approval gates:'

STATE_FILE="$TMPDIR/.codex/pm-self-update-state.json"
CHANGELOG_FIXTURE="Codex CLI 0.105.0"
RELEASE_FIXTURE_URL="https://github.com/openai/codex/releases/tag/rust-v0.105.0"
PRD_PATH="$TMPDIR/docs/prd/self-update.md"

mkdir -p "$(dirname "$PRD_PATH")"
cat >"$PRD_PATH" <<'EOF'
# PRD

## 1. Title, Date, Owner
- Title: Self-update test

## 14. Open Questions
EOF

echo "[test-pm-command] case: self-update check detects update"
check_out="$(
  PM_SELF_UPDATE_CHANGELOG_PAYLOAD="$CHANGELOG_FIXTURE" \
  PM_SELF_UPDATE_RELEASE_REDIRECT_URL="$RELEASE_FIXTURE_URL" \
  "$HELPER" self-update check
)"
assert_contains "$check_out" "UPDATE_AVAILABLE|"
assert_contains "$check_out" "PLAN_TRIGGER|/pm plan:"
assert_contains "$check_out" "latest_version=0.105.0"

jq -e '.pending_codex_version == "0.105.0"' "$STATE_FILE" >/dev/null || fail "pending version not written"
jq -e '.latest_processed_codex_version == ""' "$STATE_FILE" >/dev/null || fail "unexpected processed version"

echo "[test-pm-command] case: complete rejects invalid approval token"
if "$HELPER" self-update complete --approval nope --prd-approval approved --beads-approval approved --prd-path "$PRD_PATH" >/dev/null 2>&1; then
  fail "complete unexpectedly succeeded with invalid approval token"
fi

echo "[test-pm-command] case: dry-run does not mutate state"
dry_run_out="$("$HELPER" self-update complete --approval approved --prd-approval approved --beads-approval approved --prd-path "$PRD_PATH" --dry-run)"
assert_contains "$dry_run_out" "CHECKPOINT_DRY_RUN|"
jq -e '.latest_processed_codex_version == ""' "$STATE_FILE" >/dev/null || fail "dry-run mutated processed version"
jq -e '.pending_codex_version == "0.105.0"' "$STATE_FILE" >/dev/null || fail "dry-run mutated pending version"

echo "[test-pm-command] case: complete updates state and creates checkpoint commit"
printf 'keep-staged\n' > "$TMPDIR/unrelated.txt"
git add "$TMPDIR/unrelated.txt"

complete_out="$("$HELPER" self-update complete --approval approved --prd-approval approved --beads-approval approved --prd-path "$PRD_PATH")"
assert_contains "$complete_out" "CHECKPOINT_CREATED|"
assert_contains "$complete_out" "COMPLETE|latest_processed_codex_version=0.105.0"

jq -e '.latest_processed_codex_version == "0.105.0"' "$STATE_FILE" >/dev/null || fail "processed version not updated"
jq -e '.pending_codex_version == ""' "$STATE_FILE" >/dev/null || fail "pending version not cleared"

latest_commit_msg="$(git log -1 --pretty=%s)"
assert_contains "$latest_commit_msg" "chore(pm-self-update): checkpoint codex version 0.105.0"

commit_files="$(git show --name-only --pretty=format: HEAD)"
assert_contains "$commit_files" ".codex/pm-self-update-state.json"
if grep -Fq "unrelated.txt" <<<"$commit_files"; then
  fail "checkpoint commit included unrelated staged file"
fi

cached_after_commit="$(git diff --cached --name-only)"
assert_contains "$cached_after_commit" "unrelated.txt"

echo "[test-pm-command] case: re-check is explicit no-op when up-to-date"
noop_out="$(
  PM_SELF_UPDATE_CHANGELOG_PAYLOAD="$CHANGELOG_FIXTURE" \
  PM_SELF_UPDATE_RELEASE_REDIRECT_URL="$RELEASE_FIXTURE_URL" \
  "$HELPER" self-update check
)"
assert_contains "$noop_out" "NO_OP|"

echo "[test-pm-command] PASS"
