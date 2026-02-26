# Install PM Workflow Into Another Repo (Submodule, No Symlinks)

This setup makes `product-orchestrator` the independently updatable source via git submodule, while installing runtime skills into the target repo as regular folders (copied, not symlinked).

## Prerequisites
- Configure MCP servers first: `docs/MCP_PREREQUISITES.md`

## What gets installed in target repo
- Submodule: `<repo>/.orchestrator` (configurable)
- Copied skills:
  - `<repo>/.codex/skills/{pm,pm-discovery,pm-create-prd,pm-beads-plan,pm-implement,agent-browser}`
  - PM helper script: `<repo>/.codex/skills/pm/scripts/pm-command.sh`
- Workflow file:
  - `<repo>/.config/opencode/instructions/pm_workflow.md`

## Why submodule + copy
- Submodule gives independent versioning/fetching/updating of orchestrator logic.
- Copy mode avoids symlink limitations in some environments (including some container/workspace setups).
- Tradeoff: after submodule updates, run sync again to refresh copied skill folders.

## One-time install
From `product-orchestrator` repo:

```bash
./scripts/install-workflow.sh \
  --repo /path/to/target-repo \
  --orchestrator-url git@github.com:<org>/product-orchestrator.git
```

Optional:

```bash
./scripts/install-workflow.sh \
  --repo /path/to/target-repo \
  --orchestrator-url git@github.com:<org>/product-orchestrator.git \
  --branch main \
  --submodule-path .orchestrator
```

## Update flow (after orchestrator changes)
In target repo, update submodule and re-sync copied files:

```bash
git -C /path/to/target-repo submodule update --init --recursive .orchestrator
./scripts/install-workflow.sh --repo /path/to/target-repo --sync-only
```

Or if running from another working directory, call script by absolute path.

## Workspace bootstrap usage
In workspace bootstrap/startup for each repo:
1. `git submodule update --init --recursive`
2. Run installer in `--sync-only` mode (or full mode if submodule not yet configured)
3. Restart session so skill indexes refresh

## Backups and rollback
Each install creates backups in target repo:
- `<repo>/.orchestrator-backups/<timestamp>/codex/...`

Rollback:
1. Move backed-up folders back into `.codex/skills`
2. Revert/adjust submodule changes
3. Restart session

## Notes
- `AGENTS.md` alone does not register skills for slash/tool invocation.
- Keep this script under version control so all teams use the same install process.
