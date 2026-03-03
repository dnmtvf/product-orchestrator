#!/usr/bin/env bash
# Configure Conductor environment for PM orchestrator workflow
# This script sets up global Claude Code settings required for Conductor workspaces

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

log() {
  echo "[$SCRIPT_NAME] $*"
}

configure_mcp_approval() {
  local settings_file="$HOME/.claude/settings.json"

  log "Configuring MCP auto-approval for all project servers..."

  if ! command -v jq >/dev/null 2>&1; then
    log "Warning: jq not found. Cannot auto-configure MCP approval."
    echo "Manual step required: Run this command to enable all project MCP servers in Conductor:"
    echo "  claude config set -g enableAllProjectMcpServers true"
    return 0
  fi

  # Create settings.json if it doesn't exist
  if [ ! -f "$settings_file" ]; then
    mkdir -p "$(dirname "$settings_file")"
    echo '{"enableAllProjectMcpServers":true}' > "$settings_file"
    log "Created $settings_file with enableAllProjectMcpServers: true"
    return 0
  fi

  # Check if already enabled
  if jq -e '.enableAllProjectMcpServers == true' "$settings_file" >/dev/null 2>&1; then
    log "enableAllProjectMcpServers already true (skipping)"
    return 0
  fi

  # Add/enable the setting
  local updated
  updated=$(jq '.enableAllProjectMcpServers = true' "$settings_file")
  echo "$updated" > "$settings_file"
  log "Set enableAllProjectMcpServers: true in $settings_file"
}

usage() {
  cat <<'EOF'
Configure Conductor environment for PM orchestrator workflow.

Usage:
  configure-conductor.sh [options]

Options:
  -h, --help    Show this help message

This script configures global Claude Code settings required for running
PM orchestrator workflows in Conductor workspaces:

  - enableAllProjectMcpServers: true (allows .mcp.json servers to load
    without interactive approval in Conductor's non-interactive environment)

Run this script once per machine/user account.
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    configure_mcp_approval
    log "Configuration complete"
    ;;
  *)
    echo "Unknown argument: $1" >&2
    usage >&2
    exit 1
    ;;
esac
