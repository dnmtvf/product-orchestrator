# Migration Matrix: 2026-03-04 Codex-Compatible Agent/Role/Skill Sync

## Source Delta
- Source repo: `/Users/d/my-projects/product-orchestrator-v2`
- Range: `deee9c32d01030a9254bd0b2736cdbe0dd6da437..origin/main`
- Scope patterns:
  - `AGENTS.md`
  - `skills/**/SKILL.md`
  - `skills/**/references/*.md`
  - `skills/**/agents/*.yaml`
  - `.config/opencode/instructions/pm_workflow.md`
  - `instructions/pm_workflow.md`

## Denylist (must not be introduced)
- `droid-worker`
- `droid`
- `MiniMax`
- `setup-droid-user`
- `/pm install droid mcp`
- `runtime: droid`

## Dirty Target Overlap (manual merge required)
- `.config/opencode/instructions/pm_workflow.md`
- `skills/pm/SKILL.md`

## Classification Matrix
| File | Denylist Hits In Upstream Diff | Class | Rationale |
|---|---:|---|---|
| `.config/opencode/instructions/pm_workflow.md` | 0 | `exclude` | Upstream deletes canonical workflow source used by this repo; keep target policy intact. |
| `AGENTS.md` | 0 | `cherry-pick` | Policy-sensitive file; port only additive/compatible lines. |
| `instructions/pm_workflow.md` | 3 | `exclude` | Non-canonical path for this repo; includes runtime drift. |
| `skills/pm-beads-plan/SKILL.md` | 1 | `cherry-pick` | Mixed compatible + runtime-specific changes. |
| `skills/pm-create-prd/SKILL.md` | 1 | `cherry-pick` | Mixed compatible + runtime-specific changes. |
| `skills/pm-discovery/SKILL.md` | 5 | `cherry-pick` | Mixed compatible + runtime-specific changes. |
| `skills/pm-discovery/references/alternative-pm.md` | 1 | `cherry-pick` | Mixed compatible + runtime-specific changes. |
| `skills/pm-discovery/references/smoke-test-planner.md` | 1 | `cherry-pick` | Mixed compatible + runtime-specific changes. |
| `skills/pm-implement/SKILL.md` | 1 | `cherry-pick` | Mixed compatible + runtime-specific changes. |
| `skills/pm-implement/references/agents-compliance.md` | 1 | `cherry-pick` | Mixed compatible + runtime-specific changes. |
| `skills/pm-implement/references/backend-engineer.md` | 1 | `cherry-pick` | Mixed compatible + runtime-specific changes. |
| `skills/pm-implement/references/codex-reviewer.md` | 0 | `copy` | New Codex-focused file; no denylist content detected. |
| `skills/pm-implement/references/frontend-engineer.md` | 1 | `cherry-pick` | Mixed compatible + runtime-specific changes. |
| `skills/pm-implement/references/jazz.md` | 0 | `copy` | No denylist content detected; copy candidate pending semantic check. |
| `skills/pm-implement/references/manual-qa-smoke.md` | 1 | `cherry-pick` | Mixed compatible + runtime-specific changes. |
| `skills/pm-implement/references/security-engineer.md` | 1 | `cherry-pick` | Mixed compatible + runtime-specific changes. |
| `skills/pm-implement/references/task-verification.md` | 0 | `copy` | No denylist content detected; copy candidate pending semantic check. |
| `skills/pm-implement/references/team-lead.md` | 5 | `cherry-pick` | Mixed compatible + runtime-specific changes. |
| `skills/pm/SKILL.md` | 22 | `cherry-pick` | Heavy mixed changes + local dirty overlap; manual selective merge required. |
| `skills/pm/agents/model-routing.yaml` | 21 | `exclude` | Upstream routing is hybrid Droid/Claude; recreate Codex-only version in B7. |
| `skills/pm/references/alternative-pm.md` | 2 | `cherry-pick` | Mixed compatible + runtime-specific changes. |
| `skills/pm/references/librarian.md` | 1 | `cherry-pick` | Mixed compatible + runtime-specific changes. |
| `skills/pm/references/manual-qa-smoke.md` | 1 | `cherry-pick` | Mixed compatible + runtime-specific changes. |
| `skills/pm/references/researcher.md` | 0 | `copy` | No denylist content detected; copy candidate pending semantic check. |
| `skills/pm/references/senior-engineer.md` | 0 | `copy` | No denylist content detected; copy candidate pending semantic check. |
| `skills/pm/references/smoke-test-planner.md` | 2 | `cherry-pick` | Mixed compatible + runtime-specific changes. |

## Task Mapping
- `product-orchestrator-mrs.1 (B0)` fulfills this matrix and denylist contract.
- `product-orchestrator-mrs.2-.9` must use this matrix as the source of truth.
