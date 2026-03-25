# PRD

## Title
Machine-Level Global Orchestrator Bootstrap

## Date
2026-03-25

## Owner
PM Orchestrator

## Problem
The current PM orchestrator setup requires repo-local installation or injection of runtime assets into each target repository before `dynamic-cross-runtime` can work. That creates unnecessary friction for the desired operator workflow: set up a fresh Mac once, clone the orchestrator once, run one setup command, and then use `/pm` with Claude/Codex dynamic runtime in any repo on that machine.

## Context / Current State
Today, the supported setup path is repo-centric:
- install or inject `.codex/skills/...`, `.claude/skills/...`, and `.claude/agents/...` into each target repo
- register `claude-code` for the active runtime path using a repo-owned wrapper
- rely on wrapper-local path resolution that binds Claude agent sync to the wrapper repo root

This works, but it couples runtime readiness to per-repo installation. The current Claude wrapper resolves repo root from the wrapper script location and syncs `.claude/agents` there, so one global MCP registration cannot safely serve arbitrary repos without a dispatcher layer. There is already partial global-skill convention on the Claude side, but not a complete machine-level bootstrap path for dynamic runtime.

## User / Persona
- Primary user: operator/developer setting up a new Mac for daily PM orchestration work
- Secondary user: engineer switching across many repos who wants `/pm` to work without per-repo setup churn

## Goals
- Provide one machine-level bootstrap flow for a fresh Mac after Codex and Claude Code are installed.
- Make `dynamic-cross-runtime` usable across arbitrary repos on that machine without manual per-repo install commands.
- Keep the orchestrator source of truth in one canonical checkout and use that checkout as the active global version.
- Allow lazy first-use repo bootstrap when runtime requires repo-local state such as `.claude/agents` or `.beads`.
- Preserve the existing strict PM workflow, approval gates, and dynamic-runtime routing semantics.
- Update docs so the supported setup story is machine-level first, not repo-install first.

## Non-Goals
- Per-repo orchestrator version pinning.
- Supporting multiple active orchestrator versions on the same machine by default.
- Requiring zero repo writes under all circumstances. Lazy bootstrap into the current repo is allowed.
- Replacing repo-specific project rules such as `AGENTS.md`, `CLAUDE.md`, or app-specific repository policy files.

## Scope

### In-Scope
- A machine-level setup script that:
  - verifies Codex and Claude prerequisites
  - installs or links global orchestrator skills for Codex and Claude runtimes
  - registers required MCP servers once at user level
  - installs a stable user-level `claude-code` dispatcher path
- A global `claude-code` dispatcher that:
  - detects the current repo from `cwd`
  - resolves the active orchestrator checkout/version
  - materializes or refreshes repo-local `.claude/agents` on first use when needed
  - runs Claude in the current repo context
- A machine-level dynamic-runtime contract for arbitrary repos on the same Mac
- Documentation and smoke coverage for the new setup path

### Out-of-Scope
- Automatic migration of every previously installed target repo to a new layout
- Cross-machine fleet management
- Background daemons or persistent services
- Support for non-git directories as first-class PM workspaces unless explicitly bootstrapped

## User Flow

### Happy Path
1. User starts on a fresh Mac with Codex and Claude Code installed.
2. User clones the orchestrator repo once.
3. User runs one machine-level setup script from the orchestrator checkout.
4. The setup script installs global skills, registers required MCP servers, and configures a stable global Claude dispatcher.
5. User opens any git repo and invokes `/pm`.
6. The orchestrator detects the repo context, lazily bootstraps required repo-local runtime artifacts if missing, and proceeds with normal PM phase gating.
7. Under `dynamic-cross-runtime`, Codex and Claude routed roles work without manual repo-level install commands.

### Failure Paths
- If Codex CLI or Claude Code is missing, setup fails with precise remediation.
- If the global dispatcher cannot identify a supported repo root, PM blocks before Discovery and prints the reason.
- If lazy repo bootstrap cannot create required runtime artifacts, PM blocks with explicit remediation instead of silently degrading.
- If the Claude or Codex MCP runtime is registered but the launcher is unusable, the existing fail-closed routing gate still blocks the affected phase.

## Acceptance Criteria
- A single documented machine-level setup command exists and succeeds on a fresh Mac with Codex and Claude Code already installed.
- That setup command installs the orchestrator for both Codex and Claude runtime discovery at the user level.
- `claude-code` is registered once at user level and points to a stable global dispatcher path rather than a repo-bound wrapper path.
- In a repo that has never been manually installed with orchestrator assets, invoking PM from that repo under `dynamic-cross-runtime` either:
  - succeeds after lazy bootstrap of required repo-local runtime artifacts, or
  - fails closed with structured remediation if a hard prerequisite is missing.
- The global dispatcher uses the current repo context rather than the dispatcher checkout path when syncing/running Claude project agents.
- The supported machine-level setup path is documented in README/setup/install docs and clearly distinguished from legacy repo-install flows.
- Manual smoke coverage proves the target UX end to end:
  - fresh-machine-style setup from one orchestrator checkout
  - open a second repo with no manual orchestrator install
  - run a dummy PM Claude-routed task through the real `claude-code` MCP path
  - verify the response and the lazy repo bootstrap artifacts

## Success Metrics
- New-machine setup requires one orchestrator bootstrap command instead of a per-repo install step.
- A previously unprepared repo can enter PM dynamic runtime on first use without manual injection/install commands.
- Docs no longer describe repo-install as the primary operator story for machine-wide usage.
- Smoke evidence exists for the fresh-Mac/global-bootstrap scenario.

## BEADS

### Business
- Reduce setup friction and operator error for multi-repo PM orchestration.
- Make the orchestrator easier to adopt as a daily machine-level tool.

### Experience
- One setup flow per machine.
- `/pm` should feel available everywhere after machine setup.
- Failures must remain explicit, deterministic, and actionable.

### Architecture
- Introduce a stable user-level dispatcher for `claude-code`.
- Separate machine-level bootstrap from repo-local lazy materialization.
- Keep one canonical orchestrator checkout as the active global version.
- Preserve existing runtime-routing and fail-closed behavior.

### Data
- Repo-local lazy bootstrap may write or refresh:
  - `.claude/agents/`
  - `.beads/` when execution tracking must initialize
  - any minimal runtime metadata required by the supported PM bootstrap contract
- Machine-level setup may write or update:
  - user-level Codex config
  - user-level Claude/Codex skill links

### Security
- No hidden background services.
- All repo writes must be deterministic and limited to declared bootstrap/runtime paths.
- Setup must not silently weaken MCP approval or runtime safety checks.

## Rollout / Migration / Rollback
- Rollout:
  - add machine-level bootstrap without removing current repo-install flows immediately
  - document machine-level bootstrap as the preferred path
  - keep repo-install flows as fallback/compatibility during migration
- Migration:
  - existing repo-installed setups continue to function
  - new setup may coexist with old repo-installed copies during transition
- Rollback:
  - remove global skill links and user-level MCP registrations
  - fall back to current repo-install flow

## Risks & Edge Cases
- Global-latest semantics mean all repos on a machine pick up orchestrator changes together; this must be explicit and documented.
- Some repos may lack expected PM bootstrap files or permissions for lazy bootstrap.
- Claude/Codex runtime discovery may differ between shells, apps, and spawned MCP processes.
- Repo-local lazy bootstrap must not stomp existing user-managed `.claude/agents` unexpectedly.
- Repos with special policies in `AGENTS.md` or `CLAUDE.md` still need those files respected by PM after global setup.

## Open Questions
None.
