#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_DEST="${CODEX_HOME:-$HOME/.codex}/skills"
SKILLS=(librarian researcher)

usage() {
  cat <<'EOF'
Install optional standalone Codex user skills into the user skill directory.

Usage:
  install-user-codex-skills.sh [options]

Options:
  --dest PATH         Destination skill root (default: $CODEX_HOME/skills or ~/.codex/skills)
  --if-exists MODE    replace|skip (default: replace)
  --dry-run           Print actions only
  -h, --help          Show this help

Installed skills:
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
BACKUP_ROOT="$(dirname "$DEST")/skill-backups/$TIMESTAMP"

for skill in "${SKILLS[@]}"; do
  [ -f "$SOURCE_ROOT/user-skills/$skill/SKILL.md" ] || err "Missing source skill: $SOURCE_ROOT/user-skills/$skill/SKILL.md"
done

run mkdir -p "$DEST"

install_skill() {
  local skill="$1"
  local src="$SOURCE_ROOT/user-skills/$skill"
  local dst="$DEST/$skill"
  local backup="$BACKUP_ROOT/$skill"

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ "$IF_EXISTS" = "skip" ]; then
      log "Skipping existing skill: $dst"
      return
    fi
    run mkdir -p "$BACKUP_ROOT"
    run mv "$dst" "$backup"
    log "Backed up existing skill: $dst -> $backup"
  fi

  run cp -R "$src" "$dst"
  log "Installed skill: $dst"
}

for skill in "${SKILLS[@]}"; do
  install_skill "$skill"
done

log "Completed successfully"
echo
echo "Restart Codex to pick up new skills."
