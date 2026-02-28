#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SOURCE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'EOF'
Inject PM orchestrator workflow into a target repository (no submodule, no symlink).

This script copies orchestrator assets from a source directory into the target repo.
It is safe for repos that already have .claude folders:
- only managed PM skill folders are replaced
- replaced paths are moved into a timestamped backup directory

Usage:
  inject-workflow.sh --repo <path> [options]

Required:
  --repo PATH                    Target git repository path

Options:
  --source PATH                  Source orchestrator root (default: script parent dir)
  --skip-workflow-file           Do not copy pm_workflow.md to .config/opencode/instructions
  --if-exists MODE               How to handle existing managed skill dirs: replace|skip (default: replace)
  --dry-run                      Print actions only
  -h, --help                     Show this help

Managed skills injected:
  pm pm-discovery pm-create-prd pm-beads-plan pm-implement agent-browser

Examples:
  inject-workflow.sh --repo ~/my-app
  inject-workflow.sh --repo ~/my-app --source ~/product-orchestrator
  inject-workflow.sh --repo ~/my-app --if-exists skip
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

REPO_PATH=""
SOURCE_ROOT="$DEFAULT_SOURCE_ROOT"
COPY_WORKFLOW=1
IF_EXISTS="replace"
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      REPO_PATH="${2:-}"
      shift 2
      ;;
    --source)
      SOURCE_ROOT="${2:-}"
      shift 2
      ;;
    --no-claude|--no-codex)
      err "Legacy runtime flag '$1' is not supported. This injector is Codex-only."
      shift
      ;;
    --skip-workflow-file)
      COPY_WORKFLOW=0
      shift
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

[ -n "$REPO_PATH" ] || err "--repo is required"
case "$IF_EXISTS" in
  replace|skip) ;;
  *) err "--if-exists must be one of: replace, skip" ;;
esac

if [ ! -d "$REPO_PATH" ]; then
  err "Repo path does not exist: $REPO_PATH"
fi

REPO_PATH="$(cd "$REPO_PATH" && pwd)"
SOURCE_ROOT="$(cd "$SOURCE_ROOT" && pwd)"

if ! git -C "$REPO_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  err "Not a git repository: $REPO_PATH"
fi

SKILLS=(pm pm-discovery pm-create-prd pm-beads-plan pm-implement agent-browser)

[ -d "$SOURCE_ROOT/skills" ] || err "Missing source directory: $SOURCE_ROOT/skills"
for s in "${SKILLS[@]}"; do
  [ -f "$SOURCE_ROOT/skills/$s/SKILL.md" ] || err "Missing source skill: $SOURCE_ROOT/skills/$s/SKILL.md"
done

if [ "$COPY_WORKFLOW" -eq 1 ]; then
  [ -f "$SOURCE_ROOT/instructions/pm_workflow.md" ] || err "Missing source workflow file: $SOURCE_ROOT/instructions/pm_workflow.md"
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_ROOT="$REPO_PATH/.orchestrator-backups/$TIMESTAMP"
run mkdir -p "$BACKUP_ROOT"

replace_dir_from_source() {
  local src="$1"
  local dst="$2"
  local backup_base="$3"

  if [ ! -d "$src" ]; then
    err "Missing source directory: $src"
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ "$IF_EXISTS" = "skip" ]; then
      log "Skipping existing path: $dst"
      return
    fi

    local backup_target="$backup_base"
    run mkdir -p "$(dirname "$backup_target")"
    run mv "$dst" "$backup_target"
    log "Backed up existing path: $dst -> $backup_target"
  fi

  run mkdir -p "$(dirname "$dst")"
  run cp -R "$src" "$dst"
  log "Installed: $dst"
}

install_claude_runtime() {
  local runtime_root="$1"

  if [ -e "$runtime_root" ] && [ ! -d "$runtime_root" ]; then
    err "Runtime root exists but is not a directory: $runtime_root"
  fi

  run mkdir -p "$runtime_root"

  for s in "${SKILLS[@]}"; do
    local src="$SOURCE_ROOT/skills/$s"
    local dst="$runtime_root/$s"
    local bkp="$BACKUP_ROOT/claude/skills/$s"
    replace_dir_from_source "$src" "$dst" "$bkp"
  done
}

install_claude_runtime "$REPO_PATH/.claude/skills"

if [ "$COPY_WORKFLOW" -eq 1 ]; then
  WORKFLOW_SRC="$SOURCE_ROOT/instructions/pm_workflow.md"
  WORKFLOW_DST="$REPO_PATH/.config/opencode/instructions/pm_workflow.md"

  if [ -e "$WORKFLOW_DST" ] || [ -L "$WORKFLOW_DST" ]; then
    if [ "$IF_EXISTS" = "skip" ]; then
      log "Skipping existing workflow file: $WORKFLOW_DST"
    else
      run mkdir -p "$BACKUP_ROOT/workflow"
      run mv "$WORKFLOW_DST" "$BACKUP_ROOT/workflow/pm_workflow.md"
      log "Backed up existing workflow file: $WORKFLOW_DST"
      run mkdir -p "$(dirname "$WORKFLOW_DST")"
      run cp "$WORKFLOW_SRC" "$WORKFLOW_DST"
      log "Installed workflow file: $WORKFLOW_DST"
    fi
  else
    run mkdir -p "$(dirname "$WORKFLOW_DST")"
    run cp "$WORKFLOW_SRC" "$WORKFLOW_DST"
    log "Installed workflow file: $WORKFLOW_DST"
  fi
fi

SOURCE_COMMIT="unknown"
SOURCE_REMOTE="unknown"
SOURCE_DIRTY="unknown"
if git -C "$SOURCE_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  SOURCE_COMMIT="$(git -C "$SOURCE_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
  SOURCE_REMOTE="$(git -C "$SOURCE_ROOT" config --get remote.origin.url 2>/dev/null || echo unknown)"
  if [ -n "$(git -C "$SOURCE_ROOT" status --porcelain 2>/dev/null || true)" ]; then
    SOURCE_DIRTY="true"
  else
    SOURCE_DIRTY="false"
  fi
fi

MANIFEST="$REPO_PATH/.orchestrator-injected.json"
if [ "$DRY_RUN" -eq 0 ]; then
  cat > "$MANIFEST" <<EOF
{
  "installed_at": "$TIMESTAMP",
  "source_root": "$SOURCE_ROOT",
  "source_commit": "$SOURCE_COMMIT",
  "source_remote": "$SOURCE_REMOTE",
  "source_dirty": "$SOURCE_DIRTY",
  "managed_skills": ["pm", "pm-discovery", "pm-create-prd", "pm-beads-plan", "pm-implement", "agent-browser"],
  "runtime_mode": "codex-only",
  "install_codex": 1,
  "copied_workflow_file": $COPY_WORKFLOW
}
EOF
  log "Wrote manifest: $MANIFEST"
else
  echo "[dry-run] would write manifest: $MANIFEST"
fi

log "Completed successfully"
echo
echo "Backups: $BACKUP_ROOT"
echo "Next steps:"
echo "  1) Review: git -C \"$REPO_PATH\" status"
echo "  2) Commit copied skills/workflow/manifest"
echo "  3) Restart Codex session in target repo"
