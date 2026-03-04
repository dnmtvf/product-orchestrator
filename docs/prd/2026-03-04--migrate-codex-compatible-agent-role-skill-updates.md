# PRD

## 1. Title, Date, Owner
- Title: Migrate Codex-Compatible Agent Configuration, Roles, and Skill Descriptions from `product-orchestrator-v2`
- Date: 2026-03-04
- Owner: PM Orchestrator

## 2. Problem
`/Users/d/product-orchestrator` needs agent-role and skill-description updates from the latest `product-orchestrator-v2` history, but upstream includes runtime changes (notably Droid-related) that conflict with this repository’s Codex-first policy and current workflow constraints.

## 3. Context / Current State
- Current target HEAD: `deee9c3`.
- Source local `main`: `deee9c3` (same as target).
- Source `origin/main`: 12 commits ahead of `deee9c3`.
- The relevant upstream delta touches policy/skill/reference files; part of that delta introduces Droid runtime contracts and path changes that must not be copied into this repo.
- User-selected migration mode: `origin/main delta` + `Codex-compatible only`.

## 4. User / Persona
- PM workflow maintainers.
- Engineers using `/pm` orchestration in this repository.

## 5. Goals
- Migrate Codex-compatible updates for agent configuration, role prompts, and skill descriptions from source `origin/main`.
- Keep this repository’s Codex-first runtime behavior and existing PM gate semantics intact.
- Produce a scoped, auditable migration that excludes non-target runtime changes.

## 6. Non-Goals
- Introducing Droid runtime/tooling contracts (`droid-worker`, Droid setup/install flows, MiniMax references).
- Switching canonical workflow source away from `.config/opencode/instructions/pm_workflow.md`.
- Migrating unrelated scripts, infra/docs, or broad orchestrator refactors outside agent config/roles/skills description scope.

## 7. Scope (In/Out)
### In Scope
- Codex-compatible updates in:
  - `skills/pm/SKILL.md`
  - `skills/pm-implement/SKILL.md`
  - `skills/pm-discovery/SKILL.md`
  - `skills/pm-create-prd/SKILL.md`
  - `skills/pm-beads-plan/SKILL.md`
  - `skills/pm/references/*.md`
  - `skills/pm-discovery/references/*.md`
  - `skills/pm-implement/references/*.md`
  - `AGENTS.md` (only compatible policy text)
  - `skills/pm/agents/model-routing.yaml` only if reduced to Codex-compatible routing

### Out of Scope
- Any direct introduction of Droid-specific runtime instructions or setup paths.
- Changes requiring non-Codex runtime as primary execution path.
- Script/install workflow migrations not required for agent role/skill-description parity.

## 8. User Flow
### Happy Path
1. Extract upstream scoped diff from `deee9c3..origin/main` in source repo.
2. Filter out Droid-specific/runtime-incompatible hunks.
3. Apply remaining Codex-compatible changes to target repo.
4. Validate route/gate behavior and role-reference integrity.
5. Land scoped migration with clear commit history.

### Failure Paths
1. A file contains mixed Codex-compatible and Droid-specific edits in the same hunk.
2. Applying compatible hunks breaks PM gate invariants or role reference links.
3. New files are introduced but are unusable without excluded runtime dependencies.

## 9. Acceptance Criteria (testable)
1. Migration source is exactly `deee9c3..origin/main` from `/Users/d/my-projects/product-orchestrator-v2`.
2. Final target diff is limited to agreed scope files only.
3. No newly added target lines introduce Droid runtime/tooling contracts (`droid-worker`, `MiniMax`, Droid setup/install commands).
4. PM workflow gate behavior remains unchanged where required:
   - exact token `approved` for PRD/Beads gates
   - `Open Questions` must be empty before execution
5. All referenced role prompt files and skill references resolve to existing files after migration.
6. Smoke-test plan coverage is present for happy path, unhappy path, and regression checks.

## 10. Success Metrics (measurable)
- 100% of changed files are within scoped allowlist.
- 0 policy regressions in AGENTS/PM gate requirements.
- 0 missing role-reference files after migration.
- 0 Droid-runtime token introductions in migrated hunks.

## 11. BEADS
### Business
- Keeps orchestrator behavior current where beneficial without destabilizing runtime policy.

### Experience
- Maintainers get improved role/skill guidance while preserving expected `/pm` behavior.

### Architecture
- Path-scoped migration with compatibility filtering; no runtime platform swap.

### Data
- No product data model changes; only workflow/prompt/config text assets.

### Security
- Avoids introducing unreviewed external runtime dependencies and command paths.

## 12. Rollout / Migration / Rollback
- Rollout: apply scoped compatible changes on a dedicated branch in `/Users/d/product-orchestrator`.
- Migration: use allowlist + hunk filtering from source `deee9c3..origin/main`.
- Rollback: revert migration commit(s) if gate behavior or role execution quality regresses.

## 13. Risks & Edge Cases
- Mixed hunks can hide incompatible runtime text in otherwise useful files.
- New reviewer-role files may imply tooling not currently available in this environment.
- Upstream removed `.config/.../pm_workflow.md`; importing that behavior would violate current repo contract.

## 14. Open Questions
None.
