#!/usr/bin/env bash
# DEPRECATED: This script is deprecated in favor of setup-droid-user.sh
# The PM orchestrator now uses user-level droid-worker configuration.
# This script is kept for backward compatibility but redirects to the new script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Delegate to new setup script if it exists
if [ -f "$SCRIPT_DIR/setup-droid-user.sh" ]; then
  exec "$SCRIPT_DIR/setup-droid-user.sh"
fi

# Fallback: do nothing (user-level config is now the default)
echo "[configure-conductor] DEPRECATED: User-level droid configuration is now automatic."
echo "[configure-conductor] No action needed. Use ./scripts/setup-droid-user.sh if you need to reconfigure."
exit 0
