#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<'EOF'
Install PM orchestrator workflow into a target repository using:
- git submodule (source of truth)
- copied runtime skill folders (no symlinks)

Usage:
  install-workflow.sh --repo <path> --orchestrator-url <git-url> [options]
  install-workflow.sh --repo <path> --sync-only [options]

Required:
  --repo PATH                  Target git repository path

Required unless --sync-only:
  --orchestrator-url URL       Git URL for product-orchestrator repo

Options:
  --submodule-path PATH        Submodule mount path inside target repo (default: .orchestrator)
  --branch NAME                Branch to track when adding submodule (optional)
  --sync-only                  Skip submodule add/update metadata; only copy from existing submodule
  --no-claude                  Skip install to .claude/skills
  --no-codex                   Skip install to .codex/skills
  -h, --help                   Show this help

Examples:
  install-workflow.sh --repo ~/my-app --orchestrator-url git@github.com:myorg/product-orchestrator.git
  install-workflow.sh --repo ~/my-app --orchestrator-url git@github.com:myorg/product-orchestrator.git --branch main
  install-workflow.sh --repo ~/my-app --sync-only
EOF
}

log() {
  echo "[$SCRIPT_NAME] $*"
}

err() {
  echo "[$SCRIPT_NAME] ERROR: $*" >&2
  exit 1
}

REPO_PATH=""
ORCHESTRATOR_URL=""
SUBMODULE_PATH=".orchestrator"
BRANCH=""
SYNC_ONLY=0
INSTALL_CLAUDE=1
INSTALL_CODEX=1

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      REPO_PATH="${2:-}"
      shift 2
      ;;
    --orchestrator-url)
      ORCHESTRATOR_URL="${2:-}"
      shift 2
      ;;
    --submodule-path)
      SUBMODULE_PATH="${2:-}"
      shift 2
      ;;
    --branch)
      BRANCH="${2:-}"
      shift 2
      ;;
    --sync-only)
      SYNC_ONLY=1
      shift
      ;;
    --no-claude)
      INSTALL_CLAUDE=0
      shift
      ;;
    --no-codex)
      INSTALL_CODEX=0
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
[ "$INSTALL_CLAUDE" -eq 1 ] || [ "$INSTALL_CODEX" -eq 1 ] || err "At least one runtime must be enabled (remove --no-claude/--no-codex)"

if [ ! -d "$REPO_PATH" ]; then
  err "Repo path does not exist: $REPO_PATH"
fi

REPO_PATH="$(cd "$REPO_PATH" && pwd)"

if ! git -C "$REPO_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  err "Not a git repository: $REPO_PATH"
fi

if [ "$SYNC_ONLY" -eq 0 ] && [ -z "$ORCHESTRATOR_URL" ]; then
  err "--orchestrator-url is required unless --sync-only is used"
fi

SKILLS=(pm pm-discovery pm-create-prd pm-beads-plan pm-implement agent-browser)

if [ "$SYNC_ONLY" -eq 0 ]; then
  SUBMODULE_GIT_PATH="$REPO_PATH/$SUBMODULE_PATH/.git"

  if [ -e "$SUBMODULE_GIT_PATH" ] || [ -f "$SUBMODULE_GIT_PATH" ]; then
    log "Submodule already present at $SUBMODULE_PATH, syncing URL/branch metadata"
    git -C "$REPO_PATH" config -f .gitmodules "submodule.$SUBMODULE_PATH.url" "$ORCHESTRATOR_URL"
    if [ -n "$BRANCH" ]; then
      git -C "$REPO_PATH" config -f .gitmodules "submodule.$SUBMODULE_PATH.branch" "$BRANCH"
    fi
    git -C "$REPO_PATH" submodule sync -- "$SUBMODULE_PATH"
  else
    log "Adding submodule $ORCHESTRATOR_URL at $SUBMODULE_PATH"
    if [ -n "$BRANCH" ]; then
      git -C "$REPO_PATH" submodule add -b "$BRANCH" "$ORCHESTRATOR_URL" "$SUBMODULE_PATH"
    else
      git -C "$REPO_PATH" submodule add "$ORCHESTRATOR_URL" "$SUBMODULE_PATH"
    fi
  fi

  git -C "$REPO_PATH" submodule update --init --recursive "$SUBMODULE_PATH"
fi

SOURCE_SKILLS_DIR="$REPO_PATH/$SUBMODULE_PATH/skills"
[ -d "$SOURCE_SKILLS_DIR" ] || err "Missing submodule skills directory: $SOURCE_SKILLS_DIR"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_ROOT="$REPO_PATH/.orchestrator-backups/$TIMESTAMP"
mkdir -p "$BACKUP_ROOT"

install_runtime_skills() {
  local runtime_name="$1"
  local runtime_dir="$2"

  mkdir -p "$runtime_dir"
  local runtime_backup="$BACKUP_ROOT/$runtime_name"
  mkdir -p "$runtime_backup"

  for skill in "${SKILLS[@]}"; do
    local src="$SOURCE_SKILLS_DIR/$skill"
    local dst="$runtime_dir/$skill"

    [ -d "$src" ] || err "Missing source skill: $src"

    if [ -e "$dst" ] || [ -L "$dst" ]; then
      mv "$dst" "$runtime_backup/$skill"
    fi

    cp -R "$src" "$dst"
    log "Installed $skill -> $runtime_dir/$skill"
  done
}

if [ "$INSTALL_CLAUDE" -eq 1 ]; then
  install_runtime_skills "claude" "$REPO_PATH/.claude/skills"
fi

if [ "$INSTALL_CODEX" -eq 1 ]; then
  install_runtime_skills "codex" "$REPO_PATH/.codex/skills"
fi

WORKFLOW_SRC="$REPO_PATH/$SUBMODULE_PATH/instructions/pm_workflow.md"
WORKFLOW_DST="$REPO_PATH/.config/opencode/instructions/pm_workflow.md"

if [ -f "$WORKFLOW_SRC" ]; then
  mkdir -p "$(dirname "$WORKFLOW_DST")"
  cp "$WORKFLOW_SRC" "$WORKFLOW_DST"
  log "Installed workflow file -> $WORKFLOW_DST"
else
  log "Warning: workflow source missing: $WORKFLOW_SRC"
fi

log "Completed successfully"
echo
echo "Backups saved under: $BACKUP_ROOT"
echo "Next steps:"
echo "  1) Review changes: git -C \"$REPO_PATH\" status"
echo "  2) Commit submodule + runtime skill files + workflow file"
echo "  3) Restart Codex/Claude session in that repo so skills are re-indexed"
