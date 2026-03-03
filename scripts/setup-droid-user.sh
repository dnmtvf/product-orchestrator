#!/bin/bash
# Setup Droid MCP server at user level
# This script configures droid-worker once for all repos

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DROID_SCRIPT_SOURCE="$REPO_ROOT/scripts/droid-mcp-server"
DROID_SCRIPT_DEST="$HOME/.local/bin/droid-mcp-server"
CLAUDE_CONFIG="$HOME/.claude.json"

log() {
    echo "[setup-droid-user] $1"
}

# Ensure ~/.local/bin exists
mkdir -p "$HOME/.local/bin"

# Copy droid-mcp-server to user bin
cp "$DROID_SCRIPT_SOURCE" "$DROID_SCRIPT_DEST"
chmod +x "$DROID_SCRIPT_DEST"
log "Copied droid-mcp-server to $DROID_SCRIPT_DEST"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    log "ERROR: jq is required but not installed"
    log "Install with: brew install jq"
    exit 1
fi

# Add droid-worker to ~/.claude.json if not present
if [[ -f "$CLAUDE_CONFIG" ]]; then
    if jq -e '.mcpServers["droid-worker"]' "$CLAUDE_CONFIG" >/dev/null 2>&1; then
        log "droid-worker already configured in $CLAUDE_CONFIG"
    else
        # Add droid-worker to mcpServers
        tmp_file=$(mktemp)
        jq '.mcpServers["droid-worker"] = {type: "stdio", command: "'"$DROID_SCRIPT_DEST"'", args: ["--mcp"], env: {}}' "$CLAUDE_CONFIG" > "$tmp_file"
        mv "$tmp_file" "$CLAUDE_CONFIG"
        log "Added droid-worker to $CLAUDE_CONFIG"
    fi
else
    # Create new config with droid-worker
    jq -n '{mcpServers: {droid-worker: {type: "stdio", command: "'"$DROID_SCRIPT_DEST"'", args: ["--mcp"], env: {}}}}' > "$CLAUDE_CONFIG"
    log "Created $CLAUDE_CONFIG with droid-worker configuration"
fi

log "Setup complete! droid-worker is now available in all repos."
log "Restart any active Claude Code sessions to load the new MCP server."
