# Refactor PM Orchestrator: Droid CLI to Codex CLI Migration

## Date
2026-03-04

## Owner
PM Orchestrator

## Problem
The PM Orchestrator currently uses Droid CLI (MiniMax-M2.5) as the subagent runtime for 7 worker roles. This creates a dependency on the Droid CLI ecosystem and MiniMax model. The orchestrator needs to be refactored to eliminate Droid entirely, redistributing worker roles to either Codex CLI (gpt-5.3-codex xhigh) or Claude Code native Task tool based on a new role-to-runtime configuration.

## Context / Current State
The orchestrator currently has three spawning mechanisms:
1. **Claude Code Task tool** — 7 lead roles (PM, Team Lead, Senior Engineer, Researcher, Jazz Reviewer, Task Verification, AGENTS Compliance Reviewer) on Claude Opus 4.6
2. **Droid MCP server** — 7 worker roles (Librarian, Backend/Frontend/Security Engineers, Smoke Test Planner, Alternative PM, Manual QA) on MiniMax-M2.5 via custom bash wrapper (`scripts/droid-mcp-server`)
3. **Codex MCP server** — 1 role (Codex Reviewer) on gpt-5.3-codex xhigh via `codex mcp-server`

Droid infrastructure includes: `scripts/droid-mcp-server` (bash MCP wrapper), `scripts/setup-droid-user.sh` (user-level registration), `scripts/sync-mcp-to-droid.sh` (config sync), and a "Droid Worker Context Contract" referenced across all SKILL.md files.

## User / Persona
PM Orchestrator maintainers and users who run the `/pm` workflow in Claude Code.

## Goals
1. Eliminate all Droid CLI dependencies from the orchestrator
2. Reassign 11 roles to new runtimes per the target configuration
3. Introduce a shared `codex-worker` MCP server for 4 codex-native roles
4. Create a setup script for codex-worker MCP registration
5. Update all SKILL.md files, reference docs, and workflow instructions to reflect new runtime assignments
6. Delete all Droid-specific scripts and references

## Non-Goals
- Changing the PM workflow phases or approval gates
- Modifying Beads tracking or task decomposition logic
- Adding new agent roles
- Changing the skill directory structure
- Supporting multiple `codex mcp-server` instances (single shared instance for now)
- Backward compatibility with Droid (clean break, no fallbacks)

## Scope

### In-Scope
- Delete `scripts/droid-mcp-server`, `scripts/setup-droid-user.sh`, `scripts/sync-mcp-to-droid.sh`
- Create `scripts/setup-codex-user.sh` to register `codex-worker` MCP server
- Update 5 SKILL.md files (pm, pm-discovery, pm-create-prd, pm-beads-plan, pm-implement)
- Update `instructions/pm_workflow.md` model routing policy
- Update `CLAUDE.md` architecture description
- Update 11 reference files with new Model/Invocation headers and spawning instructions
- Remove "Droid Worker Context Contract" from all docs; replace with "Codex Worker Context Contract" for codex-native roles only
- Update `docs/` setup/prerequisites documentation
- Update `scripts/inject-workflow.sh` and `scripts/install-workflow.sh` if they reference droid setup

### Out-of-Scope
- Changes to `skills/agent-browser/`
- Changes to `.beads/` or Beads CLI usage
- Changes to PRD template or docs structure
- Changes to the self-update mechanism
- Changes to big-feature queue system

## Target Role Configuration

| Role | Runtime | Spawning Mechanism | Model | Change Type |
|---|---|---|---|---|
| project_manager | claude-code | Native (lead) | Not pinned | No change |
| team_lead | claude-code | Task tool `default` | Not pinned | No change |
| senior_engineer | codex-native | `codex-worker` MCP | gpt-5.3-codex xhigh | **Changed** (was claude-code) |
| librarian | claude-code | Task tool `default` | Not pinned | **Changed** (was droid) |
| smoke_test_planner | codex-native | `codex-worker` MCP | gpt-5.3-codex xhigh | **Changed** (was droid) |
| alternative_pm | codex-native | `codex-worker` MCP | gpt-5.3-codex xhigh | **Changed** (was droid) |
| researcher | claude-code | Task tool `default` | Not pinned | No change |
| backend_engineer | claude-code | Task tool `default` | Not pinned | **Changed** (was droid) |
| frontend_engineer | claude-code | Task tool `default` | Not pinned | **Changed** (was droid) |
| security_engineer | claude-code | Task tool `default` | Not pinned | **Changed** (was droid) |
| agents_compliance_reviewer | claude-code | Task tool `default` | Not pinned | **Changed** (was droid) |
| jazz_reviewer | codex-native | `codex-worker` MCP | gpt-5.3-codex xhigh | **Changed** (was claude-code) |
| codex_reviewer | claude-code | Task tool `default` | Not pinned | **Changed** (was codex MCP) |
| manual_qa | claude-code | Task tool `default` | Not pinned | **Changed** (was droid) |
| task_verification | claude-code | Task tool `default` | Not pinned | No change |

## User Flow

### Happy Path
1. User installs orchestrator skills into their Claude Code environment
2. User runs `scripts/setup-codex-user.sh` to register `codex-worker` MCP server
3. User invokes `/pm plan: ...` to start a workflow
4. PM spawns claude-code roles via native Task tool (11 roles)
5. PM spawns codex-native roles via `codex-worker` MCP tool calls (4 roles)
6. All phases complete without Droid dependencies

### Failure Paths
- **Codex CLI not installed:** `setup-codex-user.sh` detects missing `codex` binary and reports error with install instructions
- **`codex-worker` MCP unavailable at runtime:** Orchestrator reports blocked state with exact reason; does not silently fall back to Droid or any other runtime
- **Codex auth failure:** `codex-worker` MCP returns auth error; orchestrator surfaces it to user

## Acceptance Criteria
1. `grep -r "droid" skills/ instructions/ scripts/ CLAUDE.md AGENTS.md` returns zero matches (excluding git history)
2. `grep -r "MiniMax" skills/ instructions/ scripts/ CLAUDE.md AGENTS.md` returns zero matches
3. `scripts/droid-mcp-server`, `scripts/setup-droid-user.sh`, `scripts/sync-mcp-to-droid.sh` are deleted
4. `scripts/setup-codex-user.sh` exists and registers `codex-worker` MCP server via `claude mcp add codex-worker -- codex mcp-server`
5. All 5 SKILL.md files reference only `codex-worker` MCP (for codex-native roles) and Task tool (for claude-code roles) — no `droid-worker` references
6. All 11 modified reference files have correct Model/Invocation headers matching the target configuration table
7. `instructions/pm_workflow.md` model routing policy matches the target configuration table
8. "Codex Worker Context Contract" defined for codex-native roles with structured context block
9. Claude-code roles use natural prompt format (no structured context block required)
10. `codex_reviewer` reference updated from codex MCP 4-layer multi-turn to claude-code Task tool subagent
11. `senior_engineer` reference updated from claude-code Explore to codex-native
12. `jazz_reviewer` reference updated from claude-code Task tool to codex-native

## Success Metrics
- Zero Droid/MiniMax references in codebase (grep verification)
- All 15 agent roles have consistent runtime documentation
- `/pm` workflow executes end-to-end without Droid dependency
- Setup requires only `codex` CLI + `scripts/setup-codex-user.sh` (no `droid` CLI)

## BEADS

### Business
- Reduces runtime dependency from 3 systems (Claude + Droid + Codex) to 2 (Claude + Codex)
- Simplifies setup and onboarding for new users

### Experience
- Single setup script instead of separate droid + codex setup
- Clearer role-to-runtime mapping with only 2 runtimes

### Architecture
- **Claude-code roles (11):** Spawned via native Task tool with `subagent_type: "default"` and role-labeled prompts. No structured context block required — use natural prompt format.
- **Codex-native roles (4):** Spawned via shared `codex-worker` MCP server (`codex mcp-server`). Uses "Codex Worker Context Contract" with structured `--- CONTEXT ---` block. Tools exposed: `codex` (new conversation) and `codex-reply` (continue conversation).
- **Deleted:** `droid-mcp-server` bash wrapper, `setup-droid-user.sh`, `sync-mcp-to-droid.sh`, "Droid Worker Context Contract"
- **New:** `setup-codex-user.sh`, "Codex Worker Context Contract"
- MCP registration: `claude mcp add codex-worker -- codex mcp-server` (model and reasoning configured via `.codex/config.toml` or CLI flags)

### Data
- No data model changes. Beads tracking unchanged.

### Security
- Codex CLI requires authentication (`codex login`). Setup script should verify auth status.
- Codex sandbox policy for worker roles: `workspace-write` (matches droid's `--auto high` autonomy level).
- No new secrets or credentials beyond existing Codex CLI auth.

## Rollout / Migration / Rollback
- **Rollout:** Single PR with all changes. No phased migration.
- **Migration:** Users re-run `scripts/setup-codex-user.sh` after updating. Old `droid-worker` MCP registration can be manually removed via `claude mcp remove droid-worker`.
- **Rollback:** Git revert of the PR restores Droid-based architecture.

## Risks & Edge Cases
1. **Codex MCP serialization:** Single shared `codex-worker` server serializes parallel calls during discovery (3 codex-native roles). Acceptable for now; can split into multiple instances later if latency is problematic.
2. **codex_reviewer behavioral change:** Moving from codex multi-turn 4-layer review to Claude Task tool subagent changes the review mechanics. The 4-layer sequential pattern must be reimplemented as explicit prompt instructions within a single Claude subagent.
3. **senior_engineer behavioral change:** Moving from Claude Explore subagent to codex-native changes the tool access pattern. Codex agents have their own tool ecosystem (shell, apply patches, MCP tools) rather than Claude Code's (Read, Edit, Grep, Glob). Reference prompt may need adaptation.
4. **Setup prerequisite:** Users must have `codex` CLI installed and authenticated before running setup. Script should check and fail clearly.

## Smoke Test Plan

### Happy Path
- [ ] Spawn each codex-native role (senior_engineer, smoke_test_planner, alternative_pm, jazz_reviewer) via `codex-worker` MCP and verify output returned
- [ ] Spawn each claude-code role via Task tool and verify output returned
- [ ] Run `/pm plan:` end-to-end through discovery phase with all paired agents
- [ ] Verify `scripts/setup-codex-user.sh` registers `codex-worker` MCP successfully

### Unhappy Path
- [ ] `codex-worker` MCP unavailable → verify orchestrator reports blocked state (not silent fallback)
- [ ] `codex` CLI not installed → verify setup script reports clear error
- [ ] Codex auth expired → verify error surfaces to user

### Regression
- [ ] `grep -r "droid" skills/ instructions/ scripts/ CLAUDE.md` returns zero matches
- [ ] `grep -r "MiniMax" skills/ instructions/ scripts/ CLAUDE.md` returns zero matches
- [ ] All 15 agent role references are self-consistent (Model header matches SKILL.md spawning instructions)

## File Impact Summary

### Deletions (3 files)
- `scripts/droid-mcp-server`
- `scripts/setup-droid-user.sh`
- `scripts/sync-mcp-to-droid.sh`

### New Files (1 file)
- `scripts/setup-codex-user.sh`

### Modified SKILL/Workflow Files (7 files)
- `skills/pm/SKILL.md`
- `skills/pm-discovery/SKILL.md`
- `skills/pm-create-prd/SKILL.md`
- `skills/pm-beads-plan/SKILL.md`
- `skills/pm-implement/SKILL.md`
- `instructions/pm_workflow.md`
- `CLAUDE.md`

### Modified Reference Files (11 files)
- `skills/pm/references/senior-engineer.md` — claude-code → codex-native
- `skills/pm/references/librarian.md` — droid → claude-code
- `skills/pm/references/smoke-test-planner.md` — droid → codex-native
- `skills/pm/references/alternative-pm.md` — droid → codex-native
- `skills/pm/references/manual-qa-smoke.md` — droid → claude-code
- `skills/pm-implement/references/backend-engineer.md` — droid → claude-code
- `skills/pm-implement/references/frontend-engineer.md` — droid → claude-code
- `skills/pm-implement/references/security-engineer.md` — droid → claude-code
- `skills/pm-implement/references/codex-reviewer.md` — codex MCP → claude-code
- `skills/pm-implement/references/jazz.md` — claude-code → codex-native
- `skills/pm-implement/references/agents-compliance.md` — droid → claude-code

### Modified Setup/Doc Files (up to 4 files)
- `scripts/inject-workflow.sh` (if references droid setup)
- `scripts/install-workflow.sh` (if references droid setup)
- `docs/` setup documentation (if exists)

### Unchanged Reference Files (4 files)
- `skills/pm/references/researcher.md` — stays claude-code
- `skills/pm-implement/references/team-lead.md` — stays claude-code
- `skills/pm-implement/references/task-verification.md` — stays claude-code
- `skills/pm-implement/references/manual-qa-smoke.md` (pm-implement copy) — check if exists separately

## Open Questions
(none)
