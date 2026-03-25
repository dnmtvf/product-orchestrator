#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRAPPER="$ROOT_DIR/skills/pm/scripts/claude-code-mcp"

fail() {
  echo "[test-claude-code-mcp] FAIL: $*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool missing: $1"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

require_tool python3
require_tool bash

TMPDIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

FAKE_CLAUDE="$TMPDIR/claude"
cat >"$FAKE_CLAUDE" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "mcp" ] && [ "${2:-}" = "list" ]; then
  printf 'claude-code enabled via fake wrapper\n'
  exit 0
fi

if [ "${1:-}" = "-p" ]; then
  shift
  agent=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --agent)
        agent="${2:-}"
        shift 2
        ;;
      --model|--name)
        shift 2
        ;;
      *)
        prompt="$1"
        shift
        ;;
    esac
  done

  case "$agent" in
    default|Explore|general-purpose|Plan)
      :
      ;;
    *)
      echo "unsupported agent: $agent" >&2
      exit 7
      ;;
  esac

  if [[ "${prompt:-}" == *"BACKGROUND_TOKEN"* ]]; then
    sleep 1
  fi
  printf '%s\n' "${prompt##*: }"
  exit 0
fi

echo "fake claude: unsupported args: $*" >&2
exit 9
EOF
chmod +x "$FAKE_CLAUDE"

echo "[test-claude-code-mcp] case: wrapper passes through mcp list to the real claude binary"
list_out="$(PM_CLAUDE_WRAPPER_REAL_BIN="$FAKE_CLAUDE" "$WRAPPER" mcp list)"
assert_contains "$list_out" 'claude-code enabled via fake wrapper'

echo "[test-claude-code-mcp] case: wrapper serves Agent and TaskOutput and maps generic launcher types"
wrapper_probe_out="$(
  PM_CLAUDE_WRAPPER_REAL_BIN="$FAKE_CLAUDE" python3 - <<'PY' "$WRAPPER"
import json
import os
import subprocess
import sys
import time

wrapper = sys.argv[1]
proc = subprocess.Popen([wrapper], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)

def send(payload):
    proc.stdin.write(json.dumps(payload) + "\n")
    proc.stdin.flush()

def recv():
    line = proc.stdout.readline()
    if not line:
        raise RuntimeError(proc.stderr.read() or "wrapper returned no output")
    return json.loads(line)

send({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-03-26", "capabilities": {}, "clientInfo": {"name": "test", "version": "1"}}})
print(json.dumps(recv()))
send({"jsonrpc": "2.0", "method": "notifications/initialized"})
send({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
print(json.dumps(recv()))

for req_id, launcher, token in [
    (3, "default", "SYNC_DEFAULT_TOKEN"),
    (4, "explorer", "SYNC_EXPLORER_TOKEN"),
    (5, "worker", "SYNC_WORKER_TOKEN"),
]:
    send({"jsonrpc": "2.0", "id": req_id, "method": "tools/call", "params": {"name": "Agent", "arguments": {"description": "test", "prompt": f"Return exactly this token and nothing else: {token}", "subagent_type": launcher}}})
    print(json.dumps(recv()))

send({"jsonrpc": "2.0", "id": 6, "method": "tools/call", "params": {"name": "Agent", "arguments": {"description": "test", "prompt": "Return exactly this token and nothing else: BACKGROUND_TOKEN", "subagent_type": "default", "run_in_background": True}}})
started = recv()
print(json.dumps(started))
task_text = started["result"]["content"][0]["text"]
task_id = task_text.split("task ", 1)[1].split(".", 1)[0]

send({"jsonrpc": "2.0", "id": 7, "method": "tools/call", "params": {"name": "TaskOutput", "arguments": {"task_id": task_id, "block": True, "timeout": 5000}}})
print(json.dumps(recv()))

proc.kill()
proc.wait()
PY
)"
assert_contains "$wrapper_probe_out" '"name": "pm-orchestrator/claude-code-mcp"'
assert_contains "$wrapper_probe_out" '"name": "Agent"'
assert_contains "$wrapper_probe_out" '"name": "TaskOutput"'
assert_contains "$wrapper_probe_out" 'SYNC_DEFAULT_TOKEN'
assert_contains "$wrapper_probe_out" 'SYNC_EXPLORER_TOKEN'
assert_contains "$wrapper_probe_out" 'SYNC_WORKER_TOKEN'
assert_contains "$wrapper_probe_out" 'BACKGROUND_TOKEN'

echo "[test-claude-code-mcp] PASS"
