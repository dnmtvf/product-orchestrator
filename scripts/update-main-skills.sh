#!/usr/bin/env bash
# Update PM Orchestrator skills from main branch
# This script updates the stable main workspace to latest main branch

set -euo pipefail

MAIN_WORKSPACE="${MAIN_SKILLS_WORKSPACE:-/Users/d/conductor/workspaces/product-orchestrator/main}"
GLOBAL_SKILLS="${GLOBAL_SKILLS_DIR:-$HOME/.claude/skills}"

usage() {
  cat <<'EOF'
Update PM Orchestrator stable skills workspace to latest main branch.

Usage:
  ./scripts/update-main-skills.sh [--verify]

Options:
  --verify    Check if global skills point to main, exit with status code
  -h, --help  Show this help

The stable convention:
  - Global skills at ~/.claude/skills/ must point to main workspace
  - Main workspace at ~/workspaces/product-orchestrator/main tracks main branch
  - Only deviate when explicitly testing unstable versions

Examples:
  ./scripts/update-main-skills.sh        # Pull latest main
  ./scripts/update-main-skills.sh --verify  # Check if pointing to main
EOF
}

VERIFY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --verify)
      VERIFY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

check_main_workspace() {
  if [ ! -d "$MAIN_WORKSPACE/.git" ]; then
    echo "ERROR: Main workspace not found at $MAIN_WORKSPACE" >&2
    return 1
  fi

  if ! git -C "$MAIN_WORKSPACE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ERROR: Not a git repository: $MAIN_WORKSPACE" >&2
    return 1
  fi

  local current_branch
  current_branch=$(git -C "$MAIN_WORKSPACE" branch --show-current 2>/dev/null || echo "unknown")
  if [ "$current_branch" != "main" ]; then
    echo "WARNING: Main workspace is on branch '$current_branch' (expected 'main')" >&2
  fi

  return 0
}

check_global_skills() {
  if [ ! -d "$GLOBAL_SKILLS" ]; then
    echo "ERROR: Global skills directory not found: $GLOBAL_SKILLS" >&2
    return 1
  fi

  local required_skills=(
    "pm"
    "pm-discovery"
    "pm-create-prd"
    "pm-beads-plan"
    "pm-implement"
    "agent-browser"
  )

  local issues=0
  for skill in "${required_skills[@]}"; do
    local skill_path="$GLOBAL_SKILLS/$skill"
    if [ ! -L "$skill_path" ]; then
      echo "ERROR: $skill is not a symlink" >&2
      ((issues++))
      continue
    fi

    local target
    target=$(readlink "$skill_path")
    if [[ ! "$target" == *"$MAIN_WORKSPACE"* ]]; then
      echo "ERROR: $skill does not point to main workspace: $target" >&2
      ((issues++))
    fi
  done

  if [ $issues -gt 0 ]; then
    return 1
  fi

  return 0
}

if [ "$VERIFY" -eq 1 ]; then
  if check_main_workspace && check_global_skills; then
    echo "OK: Global skills correctly point to main workspace"
    exit 0
  else
    echo "FAIL: Global skills configuration issues detected"
    exit 1
  fi
fi

# Verify before updating
if ! check_main_workspace; then
  echo "Aborting: main workspace check failed"
  exit 1
fi

echo "Updating main workspace..."
cd "$MAIN_WORKSPACE"
git fetch origin main
git reset --hard origin/main
git clean -fd

echo "Main workspace updated to latest main branch"
echo ""
echo "Verifying global skills configuration..."
if check_global_skills; then
  echo "OK: Global skills correctly point to main workspace"
else
  echo "WARNING: Global skills have issues - check symlink configuration"
fi

echo ""
echo "Restart Claude Code for changes to take effect"
