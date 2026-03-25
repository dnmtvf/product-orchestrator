#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_DEST="${CODEX_HOME:-$HOME/.codex}/agents"
AGENTS=(librarian researcher)

usage() {
  cat <<'EOF'
Install optional standalone Codex custom agents into the user agent directory.

Usage:
  install-user-codex-agents.sh [options]

Options:
  --dest PATH         Destination agent root (default: $CODEX_HOME/agents or ~/.codex/agents)
  --if-exists MODE    replace|skip (default: replace)
  --dry-run           Print actions only
  -h, --help          Show this help

Installed agents:
  librarian researcher
EOF
}

log() {
  echo "[$SCRIPT_NAME] $*"
}

err() {
  echo "[$SCRIPT_NAME] ERROR: $*" >&2
  exit 1
}

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

DEST="$DEFAULT_DEST"
IF_EXISTS="replace"
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dest)
      DEST="${2:-}"
      shift 2
      ;;
    --if-exists)
      IF_EXISTS="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
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

case "$IF_EXISTS" in
  replace|skip) ;;
  *)
    err "--if-exists must be one of: replace, skip"
    ;;
esac

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_ROOT="$(dirname "$DEST")/agent-backups/$TIMESTAMP"

for agent in "${AGENTS[@]}"; do
  [ -f "$SOURCE_ROOT/user-agents/$agent.toml" ] || err "Missing source agent: $SOURCE_ROOT/user-agents/$agent.toml"
done

run mkdir -p "$DEST"

install_agent() {
  local agent="$1"
  local src="$SOURCE_ROOT/user-agents/$agent.toml"
  local dst="$DEST/$agent.toml"
  local backup="$BACKUP_ROOT/$agent.toml"

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ "$IF_EXISTS" = "skip" ]; then
      log "Skipping existing agent: $dst"
      return
    fi
    run mkdir -p "$BACKUP_ROOT"
    run mv "$dst" "$backup"
    log "Backed up existing agent: $dst -> $backup"
  fi

  run cp "$src" "$dst"
  log "Installed agent: $dst"
}

for agent in "${AGENTS[@]}"; do
  install_agent "$agent"
done

log "Completed successfully"
echo
echo "Restart Codex to pick up new custom agents."
