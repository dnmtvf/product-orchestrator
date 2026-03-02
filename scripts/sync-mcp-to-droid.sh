#!/bin/bash
# MCP Configuration Sync Script
# Syncs MCP servers from Codex config.toml to Droid mcp.json
set -euo pipefail

SOURCE_CONFIG="$HOME/.codex/config.toml"
TARGET_CONFIG="$HOME/.factory/mcp.json"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
BACKUP_CONFIG="$HOME/.factory/mcp.json.backup-$TIMESTAMP"

echo "=== MCP Configuration Sync ==="
echo "Source: $SOURCE_CONFIG"
echo "Target: $TARGET_CONFIG"
echo ""

# Verify source exists
if [[ ! -f "$SOURCE_CONFIG" ]]; then
    echo "ERROR: Source config not found: $SOURCE_CONFIG"
    exit 1
fi

# Verify backup can be created
if [[ -f "$TARGET_CONFIG" ]]; then
    echo "Creating backup: $BACKUP_CONFIG"
    if ! cp "$TARGET_CONFIG" "$BACKUP_CONFIG"; then
        echo "ERROR: Backup failed"
        exit 1
    fi
    # Verify backup is valid and non-empty
    BACKUP_SIZE=$(stat -f%z "$BACKUP_CONFIG" 2>/dev/null || stat -c%s "$BACKUP_CONFIG")
    if [[ $BACKUP_SIZE -eq 0 ]]; then
        echo "WARNING: Backup file is empty (config may not have existed)"
    fi
else
    echo "Target config does not exist, skipping backup"
fi

# Generate Droid-compatible JSON config
echo "Generating Droid configuration..."
python3 << 'PYTHON_SCRIPT'
import tomli
import json
import sys

try:
    import tomllib as tomllib
except ImportError:
    import tomli as tomllib

try:
    with open(sys.argv[1], "r") as f:
        config = tomllib.load(f)
except Exception as e:
    print(f"Error parsing TOML: {e}", file=sys.stderr)
    sys.exit(1)

mcp_servers = {}
mcp_servers_config = config.get("mcp_servers", {})

# GitHub token for header expansion (read from env)
import os
github_token = os.environ.get("GITHUB_PERSONAL_ACCESS_TOKEN", "")

for name, server_config in mcp_servers_config.items():
    # Skip claude-code MCP as per user decision
    if name == "claude-code":
        continue
    
    mcp_entry = {}
    
    # Determine type based on config structure
    if "command" in server_config:
        mcp_entry["type"] = "stdio"
        mcp_entry["command"] = server_config["command"]
        if "args" in server_config:
            # Ensure args is a list
            args = server_config["args"]
            if isinstance(args, str):
                args = [args]
            mcp_entry["args"] = args
        # Handle env subsection
        if "env" in server_config:
            mcp_entry["env"] = server_config["env"]
    elif "url" in server_config:
        mcp_entry["type"] = "http"
        mcp_entry["url"] = server_config["url"]
        # Convert bearer_token_env_var to headers
        if "bearer_token_env_var" in server_config:
            var_name = server_config["bearer_token_env_var"]
            mcp_entry["headers"] = {
                "Authorization": f"Bearer ${{{var_name}}}"
            }
    
    mcp_servers[name] = mcp_entry

output = {"mcpServers": mcp_servers}
print(json.dumps(output, indent=2))
PYTHON_SCRIPT

"$HOME/.codex/config.toml" > /tmp/mcp-sync.json.tmp

# Write new config
echo "Writing to: $TARGET_CONFIG"
mv /tmp/mcp-sync.json.tmp "$TARGET_CONFIG"

echo ""
echo "=== Sync Complete ==="
echo "MCPs synced: $(python3 -c "import json; print(len(json.load(open('$TARGET_CONFIG'))['mcpServers']))")"
echo "Backup at: $BACKUP_CONFIG"
