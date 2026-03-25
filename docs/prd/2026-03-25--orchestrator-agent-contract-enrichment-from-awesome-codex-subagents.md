# PRD

## Title
Orchestrator Agent Contract Enrichment from `awesome-codex-subagents`

## Date
2026-03-25

## Owner
PM Orchestrator

## Problem
The current PM orchestrator has a complete routed role matrix, but the role contracts behind that matrix are uneven:

- several active roles have detailed prompts, while others remain thin or embedded only in `SKILL.md`
- multiple prompt headers still hardcode provider/model assumptions that no longer match the runtime-inferred execution-mode routing
- there is no single role-by-role enrichment plan tying the current orchestrator to the stronger contract patterns now available in `/Users/d/awesome-codex-subagents`

This creates drift between routing, prompt intent, and review expectations, which makes delegated behavior harder to reason about and harder to evolve safely.

## Context / Current State
- Active orchestrator roles are defined in [skills/pm/agents/model-routing.yaml](/Users/d/product-orchestrator/skills/pm/agents/model-routing.yaml).
- Most functional roles have markdown reference prompts under [skills/pm/references](/Users/d/product-orchestrator/skills/pm/references) or [skills/pm-implement/references](/Users/d/product-orchestrator/skills/pm-implement/references).
- `project_manager`, `pm_beads_plan_handoff`, and `pm_implement_handoff` are routed roles but do not have dedicated role reference files today.
- Discovery support roles are comparatively thin:
  - [skills/pm/references/senior-engineer.md](/Users/d/product-orchestrator/skills/pm/references/senior-engineer.md)
  - [skills/pm/references/librarian.md](/Users/d/product-orchestrator/skills/pm/references/librarian.md)
  - [skills/pm/references/smoke-test-planner.md](/Users/d/product-orchestrator/skills/pm/references/smoke-test-planner.md)
  - [skills/pm/references/alternative-pm.md](/Users/d/product-orchestrator/skills/pm/references/alternative-pm.md)
  - [skills/pm/references/researcher.md](/Users/d/product-orchestrator/skills/pm/references/researcher.md)
- Implementation roles already have stronger contracts because of the prior onboarding work in [docs/prd/2026-03-02--engineer-agent-onboarding-protocol.md](/Users/d/product-orchestrator/docs/prd/2026-03-02--engineer-agent-onboarding-protocol.md).
- Several current prompt headers are stale relative to the runtime-inferred matrix, for example:
  - [skills/pm/references/senior-engineer.md](/Users/d/product-orchestrator/skills/pm/references/senior-engineer.md)
  - [skills/pm/references/librarian.md](/Users/d/product-orchestrator/skills/pm/references/librarian.md)
  - [skills/pm-implement/references/backend-engineer.md](/Users/d/product-orchestrator/skills/pm-implement/references/backend-engineer.md)
  - [skills/pm-implement/references/frontend-engineer.md](/Users/d/product-orchestrator/skills/pm-implement/references/frontend-engineer.md)
  - [skills/pm-implement/references/security-engineer.md](/Users/d/product-orchestrator/skills/pm-implement/references/security-engineer.md)
  - [skills/pm-implement/references/agents-compliance.md](/Users/d/product-orchestrator/skills/pm-implement/references/agents-compliance.md)
  - [skills/pm-implement/references/codex-reviewer.md](/Users/d/product-orchestrator/skills/pm-implement/references/codex-reviewer.md)
- `/Users/d/awesome-codex-subagents` provides strong role-contract patterns that fit the current orchestrator, especially:
  - explicit working mode
  - focus areas
  - quality checks
  - return contract
  - clear "do not" boundaries
  - model/sandbox intent kept separate from workflow logic
- There is no project-scoped `.codex/agents/` catalog in this repo today, so the practical integration target is the existing PM prompt/reference system rather than named custom agents.

## User / Persona
- PM workflow maintainers who need the routed roles to stay internally consistent.
- Users running `/pm` who depend on predictable role behavior during discovery, implementation, review, and QA.

## Goals
- Align role prompt documentation with the runtime-inferred execution-mode routing contract.
- Enrich each active orchestrator role with stronger task boundaries, quality checks, and output contracts using relevant patterns from `awesome-codex-subagents`.
- Add explicit coverage for routed roles that currently lack dedicated reference artifacts.
- Preserve all existing PM gates, approval semantics, and Beads workflow rules.

## Non-Goals
- Replacing the PM workflow with named custom Codex agents.
- Making `.codex/agents/` a required installation or runtime dependency.
- Changing execution-mode routing semantics in [skills/pm/agents/model-routing.yaml](/Users/d/product-orchestrator/skills/pm/agents/model-routing.yaml).
- Adding new product/runtime phases or relaxing approval gates.
- Rewriting existing prompts wholesale when targeted enrichment is sufficient.

## Scope

### In-Scope
- Refresh current prompt headers so they describe the active runtime profile contract instead of stale fixed-provider/model assumptions.
- Enrich these existing role references with awesome-style sections where useful:
  - [skills/pm/references/senior-engineer.md](/Users/d/product-orchestrator/skills/pm/references/senior-engineer.md)
  - [skills/pm/references/librarian.md](/Users/d/product-orchestrator/skills/pm/references/librarian.md)
  - [skills/pm/references/smoke-test-planner.md](/Users/d/product-orchestrator/skills/pm/references/smoke-test-planner.md)
  - [skills/pm/references/alternative-pm.md](/Users/d/product-orchestrator/skills/pm/references/alternative-pm.md)
  - [skills/pm/references/researcher.md](/Users/d/product-orchestrator/skills/pm/references/researcher.md)
  - [skills/pm/references/manual-qa-smoke.md](/Users/d/product-orchestrator/skills/pm/references/manual-qa-smoke.md)
  - [skills/pm-implement/references/team-lead.md](/Users/d/product-orchestrator/skills/pm-implement/references/team-lead.md)
  - [skills/pm-implement/references/backend-engineer.md](/Users/d/product-orchestrator/skills/pm-implement/references/backend-engineer.md)
  - [skills/pm-implement/references/frontend-engineer.md](/Users/d/product-orchestrator/skills/pm-implement/references/frontend-engineer.md)
  - [skills/pm-implement/references/security-engineer.md](/Users/d/product-orchestrator/skills/pm-implement/references/security-engineer.md)
  - [skills/pm-implement/references/agents-compliance.md](/Users/d/product-orchestrator/skills/pm-implement/references/agents-compliance.md)
  - [skills/pm-implement/references/jazz.md](/Users/d/product-orchestrator/skills/pm-implement/references/jazz.md)
  - [skills/pm-implement/references/codex-reviewer.md](/Users/d/product-orchestrator/skills/pm-implement/references/codex-reviewer.md)
  - [skills/pm-implement/references/task-verification.md](/Users/d/product-orchestrator/skills/pm-implement/references/task-verification.md)
  - [skills/pm-implement/references/manual-qa-smoke.md](/Users/d/product-orchestrator/skills/pm-implement/references/manual-qa-smoke.md)
- Add dedicated prompt artifacts or equivalent canonical prompt sections for:
  - `project_manager`
  - `pm_beads_plan_handoff`
  - `pm_implement_handoff`
- Add a documented role-to-inspiration mapping so future maintainers can see which `awesome-codex-subagents` patterns were intentionally adopted.

### Out-of-Scope
- Changing the role list in the routing matrix.
- Introducing named agent launchers or custom launcher types.
- Importing `awesome-codex-subagents` `.toml` files directly as runtime dependencies.
- Replacing the existing engineer onboarding, code-scanning, or 4-layer checklist protocol.

## User Flow

### Happy Path
1. Maintainer updates the orchestrator role references using this PRD.
2. Each routed role has either a dedicated reference file or a clearly documented canonical prompt block.
3. Role references use runtime-agnostic headers aligned to the active execution-mode profile.
4. Each role exposes a stronger operating contract: working mode, focus, quality checks, return schema, and negative scope.
5. PM, Team Lead, and reviewers behave more consistently across sessions and runtime modes without changing the workflow itself.

### Failure Paths
- Enrichment copies `awesome-codex-subagents` patterns too literally and breaks PM-specific gates or escalation rules.
- Prompt updates preserve old hardcoded runtime headers, leaving routing/docs drift unresolved.
- New prompt artifacts are added for missing roles but not wired into the canonical skill references.
- Prompt growth increases verbosity/token use without improving decision quality.

## Acceptance Criteria
1. Every active role in [skills/pm/agents/model-routing.yaml](/Users/d/product-orchestrator/skills/pm/agents/model-routing.yaml) has either:
   - a dedicated reference file, or
   - an explicitly documented canonical prompt block in the owning skill file.
2. No active role reference claims a fixed provider/model that conflicts with runtime-inferred routing.
3. Each enriched role contract includes, where applicable:
   - working mode
   - focus areas
   - quality checks
   - return/output contract
   - negative scope or "do not" boundaries
4. Existing PM invariants remain unchanged:
   - exact `approved` approval token
   - `Open Questions` must be empty before execution
   - Beads remains the execution source of truth
5. Existing engineer onboarding sections remain intact in:
   - [skills/pm-implement/references/backend-engineer.md](/Users/d/product-orchestrator/skills/pm-implement/references/backend-engineer.md)
   - [skills/pm-implement/references/frontend-engineer.md](/Users/d/product-orchestrator/skills/pm-implement/references/frontend-engineer.md)
   - [skills/pm-implement/references/security-engineer.md](/Users/d/product-orchestrator/skills/pm-implement/references/security-engineer.md)
6. Reviewer outputs remain actionable and findings-first for:
   - AGENTS Compliance Reviewer
   - Jazz Reviewer
   - Codex Reviewer
   - Task Verification
7. The repo documents, in one place, which `awesome-codex-subagents` inspirations were applied to which orchestrator roles.

## Success Metrics
- 0 prompt-header/runtime mismatches for active roles.
- 100% role coverage across the routed role matrix.
- Reduced prompt variance between discovery, implementation, review, and QA roles.
- Clearer role maintenance path for future prompt updates because source inspirations are documented.

## BEADS

### Business
- Lowers maintenance friction for the PM orchestrator by making role behavior easier to audit and evolve.

### Experience
- Users get more predictable role behavior without changing how `/pm` is invoked.

### Architecture
- Keep runtime routing in [skills/pm/agents/model-routing.yaml](/Users/d/product-orchestrator/skills/pm/agents/model-routing.yaml).
- Keep workflow control in `SKILL.md` files.
- Strengthen role behavior at the prompt-reference layer.
- Avoid introducing named custom-agent dependencies into the execution path.

### Data
- No product data model changes.
- Adds prompt/reference metadata only.

### Security
- Preserve existing approval gates and security review responsibilities.
- Improve clarity around auth, validation, secrets, and abuse-path expectations in security-sensitive roles.

## Rollout / Migration / Rollback
- Rollout on a normal feature branch with prompt/reference-only file edits.
- Migrate role references incrementally but land them in one coherent change so the routed matrix and prompt docs stay aligned.
- Rollback by reverting the reference-file updates and any added role-mapping documentation.

## Risks & Edge Cases
- Prompt bloat can reduce signal if awesome-inspired sections are copied without adapting them to PM-specific workflow constraints.
- Some `awesome-codex-subagents` roles are close but not exact matches; enrichment must borrow patterns, not identity.
- Main routed roles without dedicated reference files can stay under-specified if the extraction step is skipped.
- Review roles can lose their current strict output schema if generalized too far.

## Smoke Test Plan

### Happy Path
- Verify every routed role has a canonical prompt source after the update.
- Verify enriched prompts include working mode, focus, quality checks, and return contract where intended.
- Verify PM discovery, implementation, review, and QA references all remain internally consistent.

### Unhappy Path
- Verify stale fixed-provider/model wording is removed from active role references.
- Verify missing-role coverage (`project_manager`, `pm_beads_plan_handoff`, `pm_implement_handoff`) is addressed explicitly.
- Verify no prompt loses required PM-specific escalation or blocking behavior.

### Regression
- Verify execution-mode gate behavior is unchanged.
- Verify approval-gate wording remains exact.
- Verify engineer onboarding and review output schemas are preserved.

## Alternatives Considered
1. Header cleanup only.
This is too small. It fixes routing drift but leaves role-contract quality uneven.

2. Directly import `awesome-codex-subagents` TOML agents into `.codex/agents/`.
This was rejected because the current orchestrator executes through generic launcher types plus role-labeled prompts, not named project agents.

3. Hybrid enrichment of current prompt references using `awesome-codex-subagents` patterns.
This is the selected approach because it improves the active contracts without changing the runtime architecture.

## Agent Enrichment Matrix
| Current Role | Primary Inspiration From `awesome-codex-subagents` | Planned Enrichment |
|---|---|---|
| `project_manager` | `project-manager`, `product-manager` | Add an explicit main-role reference covering sequencing, risk, scope control, and decision gates. |
| `pm_beads_plan_handoff` | `workflow-orchestrator`, `task-distributor`, `context-manager` | Add a handoff contract focused on decomposition, queue readiness, and artifact completeness. |
| `pm_implement_handoff` | `workflow-orchestrator`, `multi-agent-coordinator`, `agent-organizer` | Add a handoff contract for implementation kickoff, dependency handoff, and integration checkpoints. |
| `senior_engineer` | `code-mapper`, `architect-reviewer` | Strengthen path-mapping, branch-risk identification, confidence marking, and next-check guidance. |
| `librarian` | `docs-researcher`, `search-specialist`, `documentation-engineer` | Preserve multi-source/official-doc policy while tightening source ranking, version notes, and return schema. |
| `smoke_test_planner` | `qa-expert`, `test-automator`, `browser-debugger` | Add risk-based coverage framing, integration-edge emphasis, and explicit browser evidence expectations. |
| `alternative_pm` | `product-manager`, `project-manager` | Add clearer option ranking, scope-cut guidance, and now/next/later framing. |
| `researcher` | `research-analyst`, `docs-researcher`, `search-specialist` | Add confidence-rated claims, evidence quality language, and stronger no-recommendation behavior when evidence is weak. |
| `team_lead` | `multi-agent-coordinator`, `task-distributor`, `context-manager` | Add clearer workstream contracts, dependency/wait rules, and integration-risk checkpoints. |
| `backend_engineer` | `backend-developer` | Keep onboarding protocol and add stronger service-boundary, idempotency, and failure-semantics focus. |
| `frontend_engineer` | `frontend-developer`, `accessibility-tester` | Keep onboarding protocol and add explicit accessibility, state-transition, and async-edge checks. |
| `security_engineer` | `security-auditor`, `security-engineer`, `penetration-tester` | Keep onboarding protocol and sharpen threat framing, exploit prerequisites, and containment guidance. |
| `agents_compliance_reviewer` | `compliance-auditor`, `reviewer` | Add stronger evidence/traceability expectations while preserving strict AGENTS rule checking. |
| `jazz_reviewer` | `reviewer`, `architect-reviewer` | Keep persona but improve critique structure so findings stay specific, reproducible, and risk-ranked. |
| `codex_reviewer` | `code-reviewer`, `architect-reviewer`, `reviewer` | Preserve 4-layer passes and strengthen expected evidence, severity discipline, and residual-risk reporting. |
| `manual_qa` | `qa-expert`, `browser-debugger`, `accessibility-tester` | Add clearer execution prerequisites, UI evidence expectations, and optional accessibility follow-up checks. |
| `task_verification` | `reviewer`, `test-automator`, `error-detective` | Add clearer accept/reject criteria, evidence quality expectations, and failure-path validation. |

## Open Questions
None.
