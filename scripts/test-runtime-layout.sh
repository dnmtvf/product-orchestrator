#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INJECTOR="$ROOT_DIR/scripts/inject-workflow.sh"
INSTALLER="$ROOT_DIR/scripts/install-workflow.sh"
USER_AGENT_INSTALLER="$ROOT_DIR/scripts/install-user-codex-agents.sh"

fail() {
  echo "[test-runtime-layout] FAIL: $*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool missing: $1"
}

assert_file() {
  local path="$1"
  [ -f "$path" ] || fail "expected file to exist: $path"
}

assert_not_file() {
  local path="$1"
  [ ! -f "$path" ] || fail "expected file to not exist: $path"
}

make_repo() {
  local path="$1"

  mkdir -p "$path"
  git -C "$path" init -q
  git -C "$path" config user.name "pm-test"
  git -C "$path" config user.email "pm-test@example.com"
  printf 'seed\n' >"$path/README.md"
  git -C "$path" add README.md
  git -C "$path" commit -q -m "init"
}

require_tool git
require_tool jq
require_tool bash

TMPDIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

echo "[test-runtime-layout] case: injector installs dual-runtime layout"
INJECT_TARGET="$TMPDIR/inject-target"
make_repo "$INJECT_TARGET"
"$INJECTOR" --repo "$INJECT_TARGET" --source "$ROOT_DIR" >/dev/null

assert_file "$INJECT_TARGET/.codex/skills/pm/SKILL.md"
assert_file "$INJECT_TARGET/.claude/skills/pm/SKILL.md"
assert_file "$INJECT_TARGET/.codex/skills/pm/scripts/pm-command.sh"
assert_file "$INJECT_TARGET/.claude/skills/pm/scripts/pm-command.sh"
assert_file "$INJECT_TARGET/.codex/skills/pm/references/internal-claude-wrapper.md"
assert_file "$INJECT_TARGET/.claude/skills/pm/references/internal-claude-wrapper.md"
assert_file "$INJECT_TARGET/instructions/pm_workflow.md"
assert_not_file "$INJECT_TARGET/.config/opencode/instructions/pm_workflow.md"
jq -e '.runtime_mode == "dual"' "$INJECT_TARGET/.orchestrator-injected.json" >/dev/null || fail "inject manifest should record dual runtime mode"

echo "[test-runtime-layout] case: installer sync-only installs dual-runtime layout"
INSTALL_TARGET="$TMPDIR/install-target"
make_repo "$INSTALL_TARGET"
mkdir -p "$INSTALL_TARGET/.orchestrator"
cp -R "$ROOT_DIR/skills" "$INSTALL_TARGET/.orchestrator/skills"
cp -R "$ROOT_DIR/instructions" "$INSTALL_TARGET/.orchestrator/instructions"
"$INSTALLER" --repo "$INSTALL_TARGET" --sync-only >/dev/null

assert_file "$INSTALL_TARGET/.codex/skills/pm/SKILL.md"
assert_file "$INSTALL_TARGET/.claude/skills/pm/SKILL.md"
assert_file "$INSTALL_TARGET/.codex/skills/pm/scripts/pm-command.sh"
assert_file "$INSTALL_TARGET/.claude/skills/pm/scripts/pm-command.sh"
assert_file "$INSTALL_TARGET/.codex/skills/pm/references/internal-claude-wrapper.md"
assert_file "$INSTALL_TARGET/.claude/skills/pm/references/internal-claude-wrapper.md"
assert_file "$INSTALL_TARGET/instructions/pm_workflow.md"
assert_not_file "$INSTALL_TARGET/.config/opencode/instructions/pm_workflow.md"

echo "[test-runtime-layout] case: user agent installer copies standalone Codex custom agents"
USER_AGENT_TARGET="$TMPDIR/user-agent-target"
"$USER_AGENT_INSTALLER" --dest "$USER_AGENT_TARGET" >/dev/null

assert_file "$USER_AGENT_TARGET/librarian.toml"
assert_file "$USER_AGENT_TARGET/researcher.toml"

echo "[test-runtime-layout] PASS"
