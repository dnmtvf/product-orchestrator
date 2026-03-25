# Product Orchestrator

`product-orchestrator` is a strict PM workflow package for Codex workspaces.
It installs PM skills plus a workflow policy file into target repositories so feature delivery follows fixed gates:

- Discovery before PRD
- PRD approval before implementation
- Beads-based execution tracking
- Beads approval before implementation handoff
- PRD `Open Questions` must be empty before execution

The workflow source of truth in this repo is:

- `instructions/pm_workflow.md`
- copied into target repos as `instructions/pm_workflow.md`

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
- Optional standalone user-skill templates:
  - `user-skills/librarian`
  - `user-skills/researcher`

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

`codex mcp list` only proves that `claude-code` is configured/enabled. It does not prove the current Codex runtime exposes a usable Claude launcher for PM orchestration.

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

## Optional standalone Codex user skills

For standalone reuse outside `/pm`, this repository ships optional Codex user skills for `librarian` and `researcher`.

- Verified user-level install surface in this environment: `~/.codex/skills`
- These standalone skills are optional conveniences and are not required by the PM orchestrator
- The PM public contract remains built-in generic subagent types plus role-labeled prompts

Install them into your user-level Codex skills directory:

```bash
/Users/d/product-orchestrator/scripts/install-user-codex-skills.sh
```

Use `--dest` for a custom target or test fixture:

```bash
/Users/d/product-orchestrator/scripts/install-user-codex-skills.sh \
  --dest /tmp/codex-user-skills
```

## What gets installed into the target repo

- `.codex/skills/{pm,pm-discovery,pm-create-prd,pm-beads-plan,pm-implement,agent-browser}`
- `.claude/skills/{pm,pm-discovery,pm-create-prd,pm-beads-plan,pm-implement,agent-browser}`
- `instructions/pm_workflow.md`
- helper copies at `.codex/skills/pm/scripts/pm-command.sh` and `.claude/skills/pm/scripts/pm-command.sh`
- Backup snapshots under `.orchestrator-backups/<timestamp>/`

Injection mode also writes:

- `.orchestrator-injected.json`

## Helper path contract

Use the PM helper path that matches where you are running:

- Source repo or submodule checkout: `./skills/pm/scripts/pm-command.sh`
- Installed target repo from Codex: `./.codex/skills/pm/scripts/pm-command.sh`
- Installed target repo from Claude: `./.claude/skills/pm/scripts/pm-command.sh`

## How to use the orchestrator

1. Open a session in the target repo.
2. Start the workflow with `/pm` and your request.
3. On every new interactive `/pm plan` or `/pm plan big feature` run, let the helper infer the outer runtime from the active Codex or Claude session, then ask you to select execution mode before Discovery starts:
   - `Dynamic Cross-Runtime`
   - `Main Runtime Only`
   - Persisted execution-mode state should be used only as the default suggested choice for the interactive prompt.
4. Respond to discovery clarification questions.
5. Approve PRD by replying exactly `approved`.
6. Review Beads plan and approve by replying exactly `approved`.
7. Let implementation, review iteration, and manual QA complete.

Example:

```text
/pm plan: Add multi-tenant project switching to the dashboard with role-based access.
```

Help command:

```text
/pm help
```

Self-check command:

```text
/pm self-check
```

The self-check route runs the built-in deterministic PM fixture suite, prints verbose `SELF_CHECK_EVENT` diagnostics to console, and writes an artifact bundle under `.codex/self-check-runs/<run-id>/`. Claude health is mandatory for this route: unhealthy registration, command executability, or session usability fails the whole run. Broken artifact capture does not stay `clean`: self-check downgrades to `issues_detected`, records structured snapshot evidence and issue codes, and still emits healer-ready artifacts so the outer healer can package repairs through the normal PM flow without bypassing approvals.

Execution-mode commands:

```text
/pm execution-mode show
/pm execution-mode set --mode dynamic-cross-runtime
/pm execution-mode set --mode main-runtime-only
/pm execution-mode reset
```

Direct helper note:
- Interactive `/pm` planning should always ask for execution mode on each new planning run.
- Direct helper usage (`./skills/pm/scripts/pm-command.sh plan gate ...`) may still reuse persisted execution-mode state when no explicit `--mode` override is supplied.

Big-feature mode example:

```text
/pm plan big feature: Build a new orchestrator workflow that decomposes a large initiative into multiple PRDs and prepares async Ralph queue execution.
```

Big-feature mode selector:
- `conflict-aware`: discovery enforces anti-conflict boundaries between PRDs.
- `worktree-isolated`: each PRD is planned for isolated worktree execution context.
- If not provided in the request, PM asks for mode selection during discovery.
- Execution-mode gate still runs before Discovery and applies to both plan routes.
- Worktree note: Ralph already uses worktrees for parallel execution; external tools (for example Worktrunk) are optional helpers.
- Queue behavior: each PRD enters async enqueue only after both approvals and empty `Open Questions`; worker cap is 2 with single auto-retry.

Manual self-update mode:
- Check latest Codex changes and stage pending version:
  - `./skills/pm/scripts/pm-command.sh self-update check`
- Check output also includes:
  - pipeline relevance filtering (`RELEVANCE_SUMMARY`, `RELEVANT_CHANGES_JSON`, `IGNORED_CHANGES_JSON`)
  - integration proposals for relevant items (`INTEGRATION_PLAN_JSON`)
- The command outputs a required planning trigger in this format:
  - `/pm plan: Inspect latest Codex changes and align orchestrator behavior with runtime-inferred execution-mode policy.`
- After full PM completion gate succeeds, finalize processed version checkpoint:
  - `./skills/pm/scripts/pm-command.sh self-update complete --approval approved --prd-approval approved --beads-approval approved --prd-path docs/prd/<approved-prd>.md`

Manual self-check mode:
- List built-in fixtures:
  - `./skills/pm/scripts/pm-command.sh self-check fixtures`
- Run the deterministic harness:
  - `./skills/pm/scripts/pm-command.sh self-check run --mode main-runtime-only`
- The harness writes artifacts under `.codex/self-check-runs/<run-id>/`.
- Healthy runtime plus healthy artifact capture ends `clean`.
- Unhealthy Claude registration, executability, or session usability ends `failed`.
- Broken artifact capture with otherwise usable runtime ends `issues_detected`, writes per-snapshot attempt JSON plus stdout/stderr artifacts, and still emits `SELF_CHECK_HEALER_READY` so the outer healer can package repairs through the normal PM flow.
- Legacy `droid-worker` is obsolete. If self-check surfaces `legacy_droid_worker_detected`, remove it from user-scope Claude config with `claude mcp remove droid-worker -s user`; current PM runtimes do not use it.

## Fixed phase order

`Discovery -> PRD -> Awaiting PRD Approval -> Beads Planning -> Awaiting Beads Approval -> Team Lead Orchestration -> Implementation -> Post-Implementation Reviews -> Review Iteration -> Manual QA Smoke Tests -> Awaiting Final Review`

## Beads as source of truth

Execution is tracked in Beads (`bd`) and `.beads/` should stay committed in Git.
For big-feature queue mode, persist queue state in `docs/prd/_queue/<feature-slug>.json` using the contract in `docs/QUEUE_WORKFLOW.md`.
Runtime policy is execution-mode driven with `dynamic-cross-runtime` default and `main-runtime-only` as the single-runtime alternative.
The public orchestration contract uses only generic subagent types (`default`, `explorer`, `worker`).
Required PM support, handoff, implementation, review, and QA subagents should launch by default whenever the active runtime/tool policy permits delegation; only platform/runtime policy failures should force the documented local fallback path.
Claude remains an external MCP runtime rather than a public launcher type, and any Codex-side Claude wrapper is internal-only if implemented.
Codex-native roles resolve model and reasoning effort from `.codex/config.toml`, then `~/.codex/config.toml`, with `gpt-5.4` / `xhigh` as the fallback.
Claude-native roles resolve model and effort from `.claude/settings.local.json`, `.claude/settings.json`, then `~/.claude/settings.json`, with `<unpinned>` as the fallback.
Selection precedence is explicit `--mode` override, then persisted execution-mode state. Outer runtime is inferred fresh on every gate run.
`Main Runtime Only` requires no opposite-provider MCP runtime.
`Dynamic Cross-Runtime` on Codex checks Claude MCP availability immediately and blocks with remediation to fix `claude-code` or switch to `Main Runtime Only`.
`Dynamic Cross-Runtime` on Claude checks `codex-worker` availability immediately and blocks with remediation to fix `codex-worker` or switch to `Main Runtime Only`.
Claude availability requires both a healthy `codex mcp list` entry and an executable configured command in the PM runtime. That executability can come from an absolute `command`, from `[shell_environment_policy.set].PATH`, or from `[mcp_servers.claude-code.env].PATH`.
`codex-worker` availability in Claude requires both a healthy `claude mcp list` entry and an executable `codex` command in the Claude runtime.
Use `codex mcp add claude-code -- claude mcp serve` when the server is actually missing. If the server is enabled but the launcher is unusable, report that limitation, block the routed phase, and do not continue in degraded fallback.
Use `claude mcp add codex-worker -- codex mcp-server` when the Claude-side Codex runtime is actually missing. If `codex-worker` is enabled but `codex` is not executable in the Claude runtime, block before Discovery and fix that runtime instead of continuing.
Telemetry helpers are available in PM command helper:
- `./skills/pm/scripts/pm-command.sh telemetry init-db --dsn <postgres-dsn>`
- `./skills/pm/scripts/pm-command.sh telemetry log-step --workflow-run-id <id> --step-id <id> ...`
- `./skills/pm/scripts/pm-command.sh telemetry query-task --task-id <id> --dsn <postgres-dsn>`
- `./skills/pm/scripts/pm-command.sh telemetry query-run --workflow-run-id <id> --dsn <postgres-dsn>`
Smoke evidence for dual planning modes is tracked in `docs/smoke/2026-02-26-big-feature-planning-modes.md`.
Common commands:

```bash
bd ready --parent <epic-id> --pretty
bd list --parent <epic-id> --pretty
bd graph <epic-id> --compact
```

## Troubleshooting

- `/pm` does not invoke:
  - confirm skill folders exist under `.codex/skills` for Codex sessions or `.claude/skills` for Claude sessions
  - restart the matching runtime session so skill indexes reload
- Workflow blocks on missing tooling:
  - run `codex mcp list` and confirm required MCP servers are enabled
- Beads planning issues in worktrees:
  - initialize Beads in main repo first, then continue in worktree

## Notes

- `AGENTS.md` rules are mandatory in each workspace.
- Referencing skills in `AGENTS.md` alone does not make them invocable.
- Shipping (`git commit`/`git push`) should happen only after verification and explicit user approval.
