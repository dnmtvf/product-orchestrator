# PRD

## Title
Codex Subagent Compatibility Cleanup

## Date
2026-03-25

## Owner
PM Orchestrator

## Problem
The orchestrator is only partially aligned with current Codex subagent behavior. The public PM contract mostly uses the correct built-in agent types (`default`, `explorer`, `worker`), but active repo assets still carry older compatibility layers and stale runtime assumptions:

- active `opencode` workflow duplication is still copied, documented, and tested
- conductor-specific workspace compatibility remains in helper code, scripts, and smoke artifacts
- several active prompt/reference files still describe fixed Task-tool / Claude-only / `gpt-5.3-codex` execution details that no longer match the current routing matrix
- Librarian and Researcher are only buried inside the PM workflow instead of being available as reusable user-level Codex agents

This leaves the repo harder to maintain and makes it too easy for future work to drift away from the latest Codex subagent contract.

## Context / Current State
- Official Codex subagents documentation currently describes three built-in agent types: `default`, `worker`, and `explorer`, and supports custom agents defined under project `.codex/agents/` or user `~/.codex/agents/`.
- Official Codex changelog entries on 2026-03-16 introduced two directly relevant updates:
  - spawned subagents inherit sandbox and network restrictions more reliably
  - the multi-agent wait tool is standardized as `wait_agent`
- The same 2026-03-16 changelog notes `gpt-5.4-mini` as a lighter-weight option for many-subagent workloads, which reinforces avoiding stale hard-coded model assumptions in prompt files.
- Official Codex changelog on 2026-01-22 deprecated custom prompts in favor of skills/team-config based sharing, which argues against leaving reusable role behavior trapped in ad hoc prompt fragments.
- In this repository today:
  - `AGENTS.md`, `README.md`, install docs, installer scripts, and tests still reference `.config/opencode/instructions/pm_workflow.md`
  - `skills/pm/scripts/pm-command.sh` still includes conductor-specific workspace helpers that no longer drive runtime selection
  - `scripts/update-main-skills.sh` still defaults to a conductor workspace path
  - active reference prompts such as `skills/pm/references/librarian.md`, `skills/pm/references/senior-engineer.md`, and `skills/pm-implement/references/agents-compliance.md` contain stale fixed-runtime metadata
- Discovery decision from user:
  - expose `Librarian` and `Researcher` as user-level Codex custom agents, not as skills

## User / Persona
- PM orchestrator maintainers evolving the workflow package
- Codex users running `/pm` inside repositories that install this orchestrator
- Individual users who want reusable `Librarian` and `Researcher` agents outside the PM workflow

## Goals
- Remove active `opencode` workflow duplication from the live repository, installer flows, and tests.
- Remove conductor-specific compatibility paths from active helper logic and maintenance scripts.
- Align active prompt/reference/docs text with the current Codex subagent contract and current routing matrix.
- Keep the PM public orchestration contract on built-in generic agent types only.
- Extract `Librarian` and `Researcher` into optional user-level Codex custom agents installable under `~/.codex/agents/`.
- Ensure those extracted user-level agents do not become a hard dependency of the PM workflow.

## Non-Goals
- Replacing the PM public launcher contract with named custom agents.
- Redesigning execution-mode routing or Beads workflow semantics.
- Removing compatibility state migration for legacy `lead-model` state in the helper unless required by adjacent cleanup.
- Rewriting historical PRDs under `docs/prd/`.
- Broadly redesigning all discovery/implementation prompts beyond compatibility and reuse cleanup.

## Scope

### In-Scope
- Remove `.config/opencode/instructions/pm_workflow.md` from active source-of-truth claims, installer copy targets, install docs, and regression tests.
- Update `AGENTS.md`, `README.md`, `instructions/pm_workflow.md`, install docs, and installer scripts to treat `instructions/pm_workflow.md` as the only live workflow file.
- Remove or simplify conductor-specific helper/script behavior that no longer affects runtime detection:
  - unused workspace path helpers in `skills/pm/scripts/pm-command.sh`
  - conductor default path in `scripts/update-main-skills.sh`
- Update active prompt/reference files to remove stale fixed-runtime labels such as:
  - `Task tool`
  - `subagent_type: default`
  - `gpt-5.3-codex`
  - fixed `codex-worker MCP` claims when routing is now execution-mode dependent
- Add source-controlled templates for user-level custom agents:
  - `librarian`
  - `researcher`
- Add an install/update path that places those optional agents into `~/.codex/agents/`.
- Document that PM may continue to use built-in generic agents plus role-labeled prompts even when optional named user agents exist.
- Refresh or archive stale smoke/test artifacts when they still describe removed active contracts.

### Out-of-Scope
- Converting all PM support roles into named custom agents.
- Removing `.claude/skills/` support from target-repo installation.
- Switching user-level extraction to skill-based `$librarian` / `$researcher` invocation.
- Rewriting archival smoke notes that are intentionally preserved as historical evidence, unless they are still presented as current behavior.

## User Flow

### Happy Path
1. Maintainer updates the orchestrator package.
2. Active docs and installers reference only the live workflow file at `instructions/pm_workflow.md`.
3. PM continues to orchestrate work through built-in Codex agent types with role-labeled prompts.
4. A user can optionally install `librarian` and `researcher` custom agents into `~/.codex/agents/`.
5. The same user can invoke those agents outside the PM workflow for standalone research tasks.
6. PM remains portable because named user-level agents are optional additions, not required internals.

### Failure Paths
1. `opencode` copy targets remain in installers or tests.
2. Target repos continue receiving duplicate workflow files and drift persists.

3. Conductor-specific code paths remain active.
4. Maintainers keep debugging dead compatibility logic that no longer affects runtime behavior.

5. Extracted user-level agents become a hidden PM dependency.
6. The public PM contract drifts away from generic built-in agents and becomes harder to reason about.

7. Reusable agent definitions collide with unrelated skill naming or stale prompt content.
8. Users get inconsistent behavior between PM-managed roles and standalone user-level agents.

## Acceptance Criteria
1. Active repository docs and install instructions identify `instructions/pm_workflow.md` as the sole live workflow file.
2. `scripts/inject-workflow.sh` and `scripts/install-workflow.sh` stop copying `.config/opencode/instructions/pm_workflow.md`.
3. Active regression tests stop asserting that `.config/opencode/instructions/pm_workflow.md` exists in injected/installed targets.
4. `AGENTS.md` no longer points at `.config/opencode/instructions/pm_workflow.md`.
5. No active non-PRD repo file requires `.config/opencode/instructions/pm_workflow.md` to stay in sync with `instructions/pm_workflow.md`.
6. `skills/pm/scripts/pm-command.sh` no longer contains unused conductor workspace compatibility helpers.
7. `scripts/update-main-skills.sh` no longer defaults to a conductor workspace path.
8. Active prompt/reference files no longer advertise stale fixed runtime metadata such as `Task tool`, `subagent_type: default`, `gpt-5.3-codex`, or unconditional `codex-worker MCP` routing when the routing matrix is execution-mode dependent.
9. Source-controlled Codex custom-agent definitions exist for `librarian` and `researcher`.
10. A documented install path exists for placing those agent definitions into `~/.codex/agents/`.
11. PM docs explicitly state that those user-level named agents are optional conveniences and not part of the required PM public contract.
12. Active docs use current Codex multi-agent terminology, including `wait_agent` where tool naming is referenced.
13. Tests or smoke coverage exist for:
  - installer no longer copying `opencode` workflow files
  - optional user-level custom-agent installation
  - PM public contract remaining generic-agent based

## Success Metrics
- 0 active non-PRD files reference `.config/opencode/instructions/pm_workflow.md` as a required live artifact.
- 0 active non-PRD files reference conductor workspace compatibility as current runtime behavior.
- 0 active prompt/reference files advertise stale fixed-runtime metadata that contradicts the current routing matrix.
- 2 reusable user-level custom agents (`librarian`, `researcher`) are available from a documented installation path.
- 0 PM execution paths require those named user-level agents to exist.

## BEADS

### Business
- Reduces maintenance cost by removing dead compatibility layers and duplicated workflow surfaces.

### Experience
- Makes PM behavior easier to reason about.
- Gives the user reusable standalone research agents outside the orchestrator.

### Architecture
- Preserve the PM public contract as built-in generic agents plus role-labeled prompts.
- Treat user-level custom agents as optional adjuncts for standalone use.
- Keep installation/update paths explicit and source-controlled.

### Data
- No product data-model changes are required.
- Installer manifests and helper state may need small updates if paths or naming change.

### Security
- User-level custom agents must inherit or explicitly declare safe sandbox/network settings compatible with current Codex behavior.
- Removing dead compatibility logic should not weaken current runtime gating or approval behavior.

## Rollout / Migration / Rollback
- Rollout:
  - update source repo docs, scripts, prompts, and tests
  - add optional user-agent templates plus installer flow
  - verify fresh injection/install into a temp target repo
- Migration:
  - target repos stop receiving `.config/opencode/...` on next install/update
  - optional user agents are installed separately into `~/.codex/agents/`
- Rollback:
  - revert the cleanup commit(s)
  - reinstall previous orchestrator version into target repos
  - remove optional user-level custom agents if necessary

## Risks & Edge Cases
- Risk: some stale smoke docs are historical records rather than active guidance.
  - Mitigation: either archive them explicitly or update only the files still presented as current contract evidence.
- Risk: user-level custom agents drift away from PM-owned role prompts over time.
  - Mitigation: source them from shared repo templates and document one update path.
- Risk: removing `opencode` copies breaks a consumer that still depends on the duplicate path.
  - Mitigation: verify target-repo installation and call out the breaking change in install docs.
- Risk: over-specifying models in user-level custom agents could age poorly as Codex defaults evolve.
  - Mitigation: avoid unnecessary hard pins unless there is a measured reason.

## Open Questions
None.

## Discovery Smoke Test Plan
- Happy path:
  - inject/install a temp target repo and verify only `instructions/pm_workflow.md` is installed as the workflow file
  - verify PM docs still describe built-in generic agent types as the public contract
  - install `librarian` and `researcher` into `~/.codex/agents/` from the documented path and verify the files land in the expected user directory
- Unhappy path:
  - verify tests fail if any active installer or doc reintroduces `.config/opencode/...`
  - verify stale prompt metadata grep checks catch `Task tool`, `subagent_type`, or `gpt-5.3-codex` regressions in active prompt files
- Regression:
  - verify `scripts/test-pm-command.sh` and `scripts/test-runtime-layout.sh` still pass after the cleanup
  - verify PM helper plan gate behavior is unchanged for execution-mode routing and runtime detection
