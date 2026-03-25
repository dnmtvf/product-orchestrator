#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
CLAUDE_HOME_DIR="${CLAUDE_HOME:-$HOME/.claude}"
CODEX_SKILLS_DIR="$CODEX_HOME_DIR/skills"
CLAUDE_SKILLS_DIR="$CLAUDE_HOME_DIR/skills"
GLOBAL_CLAUDE_WRAPPER_PATH="$CODEX_SKILLS_DIR/pm/scripts/claude-code-mcp"
BOOTSTRAP_MANIFEST_PATH="$CODEX_HOME_DIR/pm-orchestrator-bootstrap.json"
REQUIRED_SKILLS=(
  pm
  pm-discovery
  pm-create-prd
  pm-beads-plan
  pm-implement
  agent-browser
)

log() {
  echo "[$SCRIPT_NAME] $*"
}

err() {
  echo "[$SCRIPT_NAME] ERROR: $*" >&2
  exit 1
}

usage() {
  cat <<EOF
Machine-level PM orchestrator bootstrap.

Usage:
  $SCRIPT_NAME [--verify]

Behavior:
  - links global Codex skills under $CODEX_SKILLS_DIR
  - links global Claude skills under $CLAUDE_SKILLS_DIR
  - registers codex mcp server 'claude-code' at $GLOBAL_CLAUDE_WRAPPER_PATH
  - ensures claude mcp server 'codex-worker' is registered
  - records active orchestrator checkout metadata at $BOOTSTRAP_MANIFEST_PATH

Options:
  --verify   Check current bootstrap state and exit nonzero if drift is found
  -h|--help  Show this help
EOF
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || err "Required tool not found: $1"
}

ensure_codex_auth() {
  if codex login status >/dev/null 2>&1; then
    return 0
  fi
  if codex auth status >/dev/null 2>&1; then
    return 0
  fi
  err "Codex is not authenticated. Run: codex login"
}

ensure_dir() {
  mkdir -p "$1"
}

ensure_skill_link() {
  local destination_root="$1"
  local skill_name="$2"
  local source_path="$REPO_ROOT/skills/$skill_name"
  local destination_path="$destination_root/$skill_name"

  [ -d "$source_path" ] || err "Missing orchestrator skill source: $source_path"

  if [ -L "$destination_path" ]; then
    local current_target
    current_target="$(readlink "$destination_path")"
    if [ "$current_target" = "$source_path" ]; then
      return 0
    fi
    rm "$destination_path"
  elif [ -e "$destination_path" ]; then
    err "Refusing to replace non-symlink skill path: $destination_path"
  fi

  ln -s "$source_path" "$destination_path"
}

codex_get_claude_wrapper() {
  codex mcp get claude-code 2>/dev/null | awk -F': ' '/^  command:/ {print $2}'
}

register_codex_claude_code() {
  local current_command

  current_command="$(codex_get_claude_wrapper || true)"
  if [ "$current_command" != "$GLOBAL_CLAUDE_WRAPPER_PATH" ]; then
    if codex mcp get claude-code >/dev/null 2>&1; then
      codex mcp remove claude-code >/dev/null
    fi
    codex mcp add claude-code -- "$GLOBAL_CLAUDE_WRAPPER_PATH" >/dev/null
  fi

  current_command="$(codex_get_claude_wrapper || true)"
  [ "$current_command" = "$GLOBAL_CLAUDE_WRAPPER_PATH" ] || err "codex mcp claude-code command mismatch: $current_command"
}

claude_has_codex_worker() {
  claude mcp list 2>/dev/null | grep -q '^codex-worker:'
}

register_claude_codex_worker() {
  if ! claude_has_codex_worker; then
    claude mcp add codex-worker -- codex mcp-server >/dev/null
  fi
  claude_has_codex_worker || err "Verification failed: codex-worker not found in claude mcp list"
}

write_manifest() {
  local codex_wrapper_command
  codex_wrapper_command="$(codex_get_claude_wrapper || true)"
  ensure_dir "$CODEX_HOME_DIR"
  cat >"$BOOTSTRAP_MANIFEST_PATH" <<EOF
{
  "orchestrator_root": "$REPO_ROOT",
  "codex_skills_dir": "$CODEX_SKILLS_DIR",
  "claude_skills_dir": "$CLAUDE_SKILLS_DIR",
  "claude_code_command": "$codex_wrapper_command",
  "global_latest": true
}
EOF
}

verify_skill_links() {
  local destination_root="$1"
  local runtime_name="$2"
  local skill_name

  for skill_name in "${REQUIRED_SKILLS[@]}"; do
    local destination_path="$destination_root/$skill_name"
    local expected_target="$REPO_ROOT/skills/$skill_name"
    [ -L "$destination_path" ] || err "$runtime_name skill is not symlinked: $destination_path"
    [ "$(readlink "$destination_path")" = "$expected_target" ] || err "$runtime_name skill points to unexpected target: $destination_path"
  done
}

run_verify() {
  verify_skill_links "$CODEX_SKILLS_DIR" "Codex"
  verify_skill_links "$CLAUDE_SKILLS_DIR" "Claude"
  [ "$(codex_get_claude_wrapper || true)" = "$GLOBAL_CLAUDE_WRAPPER_PATH" ] || err "codex mcp claude-code is not registered to $GLOBAL_CLAUDE_WRAPPER_PATH"
  claude_has_codex_worker || err "claude mcp codex-worker is not registered"
  [ -f "$BOOTSTRAP_MANIFEST_PATH" ] || err "Bootstrap manifest missing: $BOOTSTRAP_MANIFEST_PATH"
  log "Verification passed"
}

VERIFY_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --verify)
      VERIFY_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown argument: $1"
      ;;
  esac
done

require_tool git
require_tool codex
require_tool claude
ensure_codex_auth

if [ "$VERIFY_ONLY" -eq 1 ]; then
  run_verify
  exit 0
fi

ensure_dir "$CODEX_SKILLS_DIR"
ensure_dir "$CLAUDE_SKILLS_DIR"

for skill_name in "${REQUIRED_SKILLS[@]}"; do
  ensure_skill_link "$CODEX_SKILLS_DIR" "$skill_name"
  ensure_skill_link "$CLAUDE_SKILLS_DIR" "$skill_name"
done

register_codex_claude_code
register_claude_codex_worker
write_manifest
run_verify

log "Bootstrap complete"
log "Codex skills -> $CODEX_SKILLS_DIR"
log "Claude skills -> $CLAUDE_SKILLS_DIR"
log "claude-code command -> $GLOBAL_CLAUDE_WRAPPER_PATH"
