#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_SCRIPT="$ROOT_DIR/scripts/setup-global-orchestrator.sh"

fail() {
  echo "[test-global-bootstrap] FAIL: $*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool missing: $1"
}

assert_symlink_target() {
  local path="$1"
  local expected="$2"

  [ -L "$path" ] || fail "expected symlink: $path"
  [ "$(readlink "$path")" = "$expected" ] || fail "unexpected symlink target for $path"
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
require_tool python3

TMPDIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

export HOME="$TMPDIR/home"
mkdir -p "$HOME"
FAKE_BIN="$TMPDIR/bin"
mkdir -p "$FAKE_BIN"

cat >"$FAKE_BIN/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${HOME}/.fake-codex-mcp"
mkdir -p "$STATE_DIR"

cmd="${1:-}"
shift || true

case "$cmd" in
  auth)
    [ "${1:-}" = "status" ] || exit 64
    exit 0
    ;;
  mcp)
    sub="${1:-}"
    shift || true
    case "$sub" in
      add)
        name="${1:-}"
        shift || true
        [ "${1:-}" = "--" ] || exit 64
        shift || true
        command_path="${1:-}"
        printf '%s\n' "$command_path" >"$STATE_DIR/$name.command"
        mkdir -p "$HOME/.codex"
        cat >"$HOME/.codex/config.toml" <<CFG
[mcp_servers.$name]
command = "$command_path"
CFG
        exit 0
        ;;
      get)
        name="${1:-}"
        [ -f "$STATE_DIR/$name.command" ] || exit 1
        command_path="$(cat "$STATE_DIR/$name.command")"
        cat <<OUT
$name
  enabled: true
  transport: stdio
  command: $command_path
  args: -
  cwd: -
  env: -
  remove: codex mcp remove $name
OUT
        exit 0
        ;;
      remove)
        name="${1:-}"
        rm -f "$STATE_DIR/$name.command"
        exit 0
        ;;
      *)
        exit 64
        ;;
    esac
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "$FAKE_BIN/codex"

cat >"$FAKE_BIN/claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${HOME}/.fake-claude-mcp"
mkdir -p "$STATE_DIR"

if [ "${1:-}" = "mcp" ] && [ "${2:-}" = "add" ]; then
  name="${3:-}"
  shift 3 || true
  [ "${1:-}" = "--" ] || exit 64
  shift || true
  printf '%s\n' "$*" >"$STATE_DIR/$name.command"
  exit 0
fi

if [ "${1:-}" = "mcp" ] && [ "${2:-}" = "list" ]; then
  echo "Checking MCP server health..."
  if [ -f "$STATE_DIR/codex-worker.command" ]; then
    echo
    echo "codex-worker: $(cat "$STATE_DIR/codex-worker.command") - ✓ Connected"
  fi
  exit 0
fi

if [ "${1:-}" = "-p" ]; then
  agent_name=""
  session_id=""
  prompt=""
  shift || true
  while [ $# -gt 0 ]; do
    case "$1" in
      --agent)
        agent_name="${2:-}"
        shift 2
        ;;
      --session-id)
        session_id="${2:-}"
        shift 2
        ;;
      *)
        prompt="$1"
        shift
        ;;
    esac
  done
  printf 'Current phase: GLOBAL BOOTSTRAP TEST\nAgent: %s\nSession: %s\nPrompt: %s\nPhase Error Summary: none\n' "$agent_name" "$session_id" "$prompt"
  exit 0
fi

exit 0
EOF
chmod +x "$FAKE_BIN/claude"

export PATH="$FAKE_BIN:$PATH"

echo "[test-global-bootstrap] case: machine-level bootstrap creates global skills and MCP registration"
"$BOOTSTRAP_SCRIPT" >/dev/null

assert_symlink_target "$HOME/.codex/skills/pm" "$ROOT_DIR/skills/pm"
assert_symlink_target "$HOME/.codex/skills/pm-discovery" "$ROOT_DIR/skills/pm-discovery"
assert_symlink_target "$HOME/.codex/skills/pm-create-prd" "$ROOT_DIR/skills/pm-create-prd"
assert_symlink_target "$HOME/.codex/skills/pm-beads-plan" "$ROOT_DIR/skills/pm-beads-plan"
assert_symlink_target "$HOME/.codex/skills/pm-implement" "$ROOT_DIR/skills/pm-implement"
assert_symlink_target "$HOME/.codex/skills/agent-browser" "$ROOT_DIR/skills/agent-browser"
assert_symlink_target "$HOME/.claude/skills/pm" "$ROOT_DIR/skills/pm"
[ "$(codex mcp get claude-code | awk -F': ' '/^  command:/ {print $2}')" = "$HOME/.codex/skills/pm/scripts/claude-code-mcp" ] || fail "claude-code should point to stable global wrapper path"
claude mcp list | grep -q '^codex-worker:' || fail "codex-worker should be registered in Claude MCP list"
[ -f "$HOME/.codex/pm-orchestrator-bootstrap.json" ] || fail "bootstrap manifest should exist"

echo "[test-global-bootstrap] case: machine-level bootstrap is idempotent"
"$BOOTSTRAP_SCRIPT" >/dev/null
"$BOOTSTRAP_SCRIPT" --verify >/dev/null

echo "[test-global-bootstrap] case: global dispatcher syncs Claude agents into current repo context"
TARGET_REPO_RAW="$TMPDIR/target-repo"
make_repo "$TARGET_REPO_RAW"
TARGET_REPO="$(cd "$TARGET_REPO_RAW" && pwd)"
CLAUDE_COMMAND=claude \
TARGET_REPO="$TARGET_REPO" \
ROOT_DIR="$ROOT_DIR" \
DISPATCHER_SCRIPT="$HOME/.codex/skills/pm/scripts/claude-code-mcp-server.py" \
python3 - <<'PY'
import os
import sys
from pathlib import Path

dispatcher_script = Path(os.environ["DISPATCHER_SCRIPT"])
scripts_dir = dispatcher_script.parent
if str(scripts_dir) not in sys.path:
    sys.path.insert(0, str(scripts_dir))

from claude_agents_lib import run_claude_agent  # noqa: E402

result = run_claude_agent(
    dispatcher_script,
    role="project_manager",
    prompt="bootstrap smoke",
    cwd=os.environ["TARGET_REPO"],
)
expected_repo = str(Path(os.environ["TARGET_REPO"]).resolve())
expected_root = str(Path(os.environ["ROOT_DIR"]).resolve())
assert result["agent_name"] == "pm-project-manager"
assert result["repo_root"] == expected_repo
assert result["cwd"] == expected_repo
assert result["orchestrator_root"] == expected_root
PY
[ $? -eq 0 ] || fail "dispatcher JSON did not report expected repo/orchestrator roots"
[ -f "$TARGET_REPO/.claude/agents/pm-project-manager.md" ] || fail "expected lazy Claude agent bootstrap in target repo"
[ ! -e "$TARGET_REPO/.codex/skills/pm/SKILL.md" ] || fail "target repo should not require repo-local skill install for global bootstrap path"

echo "[test-global-bootstrap] case: global dispatcher fails closed outside git repos"
NON_REPO="$TMPDIR/non-repo"
mkdir -p "$NON_REPO"
if CLAUDE_COMMAND=claude python3 "$HOME/.codex/skills/pm/scripts/claude-code-mcp-server.py" run-agent --role project_manager --prompt "x" --cwd "$NON_REPO" >/dev/null 2>&1; then
  fail "dispatcher unexpectedly succeeded outside a git repo"
fi

echo "[test-global-bootstrap] PASS"
