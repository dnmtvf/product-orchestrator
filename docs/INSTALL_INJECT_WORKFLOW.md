# Install PM Workflow By Injection (No Submodule, No Symlink)

Use this mode when you want to copy the current orchestrator version directly into a target repo.

## Managed Runtime Layout

The injector copies repo-local runtime assets into the target repo. It does not rely on global skill folders or symlinks.

The managed runtime roots are:
- `.codex/skills/`
- `.claude/skills/`

## Behavior with existing runtime folders
The injector is safe for repos that already contain these folders:
- It only manages these skill folders:
  - `pm`
  - `pm-discovery`
  - `pm-create-prd`
  - `pm-beads-plan`
  - `pm-implement`
  - `agent-browser`
- Other skills/files in `.codex/skills` and `.claude/skills` are left untouched.
- If a managed folder already exists, it is moved to a timestamped backup and replaced (default mode).

## Prerequisites
- Configure MCP servers first: `docs/MCP_PREREQUISITES.md`

## Script
- `/Users/d/product-orchestrator/scripts/inject-workflow.sh`

## One-time install

```bash
/Users/d/product-orchestrator/scripts/inject-workflow.sh \
  --repo /path/to/target-repo
```

Optional source override:

```bash
/Users/d/product-orchestrator/scripts/inject-workflow.sh \
  --repo /path/to/target-repo \
  --source /path/to/product-orchestrator
```

## Existing-path strategy
Default strategy: `replace` (backup + replace managed paths).

To avoid replacing existing managed paths:

```bash
/Users/d/product-orchestrator/scripts/inject-workflow.sh \
  --repo /path/to/target-repo \
  --if-exists skip
```

## Dry run

```bash
/Users/d/product-orchestrator/scripts/inject-workflow.sh \
  --repo /path/to/target-repo \
  --dry-run
```

## What gets copied
- `.codex/skills/{pm,pm-discovery,pm-create-prd,pm-beads-plan,pm-implement,agent-browser}`
- `.claude/skills/{pm,pm-discovery,pm-create-prd,pm-beads-plan,pm-implement,agent-browser}`
- PM helper script is included under both `.codex/skills/pm/scripts/pm-command.sh` and `.claude/skills/pm/scripts/pm-command.sh`
- `instructions/pm_workflow.md`
- `.orchestrator-injected.json` (metadata: source path, commit, timestamp)

## Backups and rollback
Backups are written to:
- `<repo>/.orchestrator-backups/<timestamp>/...`

Rollback:
1. Move backed-up folders/files back to original paths.
2. Remove copied managed folders if needed.
3. Restart the matching Codex or Claude session.

## Update model
This mode is copy-based. After orchestrator changes, run injector again to refresh target repo.
