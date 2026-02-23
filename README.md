# Product Orchestrator

`product-orchestrator` is a strict PM workflow package for Codex/Claude workspaces.
It installs PM skills plus a workflow policy file into target repositories so feature delivery follows fixed gates:

- Discovery before PRD
- PRD approval before implementation
- Beads-based execution tracking
- Beads approval before implementation handoff
- PRD `Open Questions` must be empty before execution

The workflow source of truth in this repo is:

- `instructions/pm_workflow.md`

## What this repository contains

- Skills:
  - `skills/pm`
  - `skills/pm-discovery`
  - `skills/pm-create-prd`
  - `skills/pm-beads-plan`
  - `skills/pm-implement`
  - `skills/agent-browser`
- Install scripts:
  - `scripts/inject-workflow.sh`
  - `scripts/install-workflow.sh`
- Setup docs:
  - `docs/MCP_PREREQUISITES.md`
  - `docs/INSTALL_INJECT_WORKFLOW.md`
  - `docs/INSTALL_SUBMODULE_WORKFLOW.md`

## Prerequisites

1. Codex CLI and Git installed.
2. Target repository is a Git repo.
3. Required MCP servers are configured:

```bash
codex mcp add claude-code -- claude mcp serve
codex mcp add context7 -- npx -y @upstash/context7-mcp
codex mcp add firecrawl --env FIRECRAWL_API_KEY=YOUR_KEY -- npx -y firecrawl-mcp
codex mcp add deepwiki --url https://mcp.deepwiki.com/mcp
codex mcp add exa --url https://mcp.exa.ai/mcp
codex mcp list
```

## Setup

### Option A: Direct injection (no submodule)

Best when you want to copy current orchestrator content directly into a target repo.

```bash
/Users/d/product-orchestrator/scripts/inject-workflow.sh \
  --repo /path/to/target-repo
```

Useful variants:

```bash
# Dry run
/Users/d/product-orchestrator/scripts/inject-workflow.sh \
  --repo /path/to/target-repo \
  --dry-run

# Keep existing managed skill folders instead of replacing
/Users/d/product-orchestrator/scripts/inject-workflow.sh \
  --repo /path/to/target-repo \
  --if-exists skip
```

### Option B: Submodule + copy

Best when you want the orchestrator versioned independently and updatable by submodule.

```bash
/Users/d/product-orchestrator/scripts/install-workflow.sh \
  --repo /path/to/target-repo \
  --orchestrator-url git@github.com:<org>/product-orchestrator.git
```

Sync updates after orchestrator changes:

```bash
git -C /path/to/target-repo submodule update --init --recursive .orchestrator
/Users/d/product-orchestrator/scripts/install-workflow.sh \
  --repo /path/to/target-repo \
  --sync-only
```

## What gets installed into the target repo

- `.claude/skills/{pm,pm-discovery,pm-create-prd,pm-beads-plan,pm-implement,agent-browser}`
- `.codex/skills/{pm,pm-discovery,pm-create-prd,pm-beads-plan,pm-implement,agent-browser}`
- `.config/opencode/instructions/pm_workflow.md`
- Backup snapshots under `.orchestrator-backups/<timestamp>/`

Injection mode also writes:

- `.orchestrator-injected.json`

## How to use the orchestrator

1. Open a session in the target repo.
2. Start the workflow with `/pm` and your request.
3. Respond to discovery clarification questions.
4. Approve PRD by replying exactly `approved`.
5. Review Beads plan and approve by replying exactly `approved`.
6. Let implementation, review iteration, and manual QA complete.

Example:

```text
/pm Add multi-tenant project switching to the dashboard with role-based access.
```

## Fixed phase order

`Discovery -> PRD -> Awaiting PRD Approval -> Beads Planning -> Awaiting Beads Approval -> Team Lead Orchestration -> Implementation -> Post-Implementation Reviews -> Review Iteration -> Manual QA Smoke Tests -> Awaiting Final Review`

## Beads as source of truth

Execution is tracked in Beads (`bd`) and `.beads/` should stay committed in Git.
Common commands:

```bash
bd ready --parent <epic-id> --pretty
bd list --parent <epic-id> --pretty
bd graph <epic-id> --compact
```

## Troubleshooting

- `/pm` does not invoke:
  - confirm skill folders exist under `.claude/skills` or `.codex/skills`
  - restart Codex/Claude session so skill indexes reload
- Workflow blocks on missing tooling:
  - run `codex mcp list` and confirm required MCP servers are enabled
- Beads planning issues in worktrees:
  - initialize Beads in main repo first, then continue in worktree

## Notes

- `AGENTS.md` rules are mandatory in each workspace.
- Referencing skills in `AGENTS.md` alone does not make them invocable.
- Shipping (`git commit`/`git push`) should happen only after verification and explicit user approval.
