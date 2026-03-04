#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

log() {
  echo "[$SCRIPT_NAME] $*"
}

err() {
  echo "[$SCRIPT_NAME] ERROR: $*" >&2
  exit 1
}

# 1. Check if codex CLI is installed
if ! command -v codex >/dev/null 2>&1; then
  err "codex CLI is not installed. Install it with one of:
  npm install -g @openai/codex
  brew install --cask codex"
fi

log "codex CLI found: $(command -v codex)"

# 2. Check codex auth status
if ! codex auth status >/dev/null 2>&1; then
  err "codex is not authenticated. Run: codex login"
fi

log "codex auth: OK"

# 3. Register codex-worker MCP server
log "Registering codex-worker MCP server..."
claude mcp add codex-worker -- codex mcp-server

log "codex-worker MCP server registered"

# 4. Verify registration
if ! claude mcp list 2>/dev/null | grep -q codex-worker; then
  err "Verification failed: codex-worker not found in claude mcp list"
fi

log "Verification: codex-worker is registered"

# 5. Success
echo
log "Setup complete. codex-worker MCP server is ready to use."
