# PRD

## 1. Title, Date, Owner
- Title: PM Big Feature Mode With Multi-PRD Ralph Queue
- Date: 2026-02-26
- Owner: Product Orchestrator PM Workflow

## 2. Problem
The current PM workflow is optimized for one feature -> one PRD execution. For large feature requests, this creates oversized PRDs, lower clarity, and delayed execution readiness. We need a dedicated big-feature mode that decomposes one large request into multiple PRDs, runs scoped discovery for each PRD, and prepares a Ralph queue asynchronously without blocking on full implementation.

## 3. Context / Current State
Current default flow is linear and single-PRD oriented (`Discovery -> PRD -> approvals -> implementation`).
Required repo constraints already exist: strict phase order, exact `approved` gates, Beads as source of truth, and empty PRD Open Questions before execution.
Ralph execution is tracker-native (`run --epic` for Beads family, `run --prd` for JSON) and does not provide a single built-in multi-PRD queue command. Ralph parallel execution already uses git worktrees per worker and cleanup semantics, so queue orchestration and mode selection must be implemented by PM workflow without conflicting lifecycle managers.

## 4. User / Persona
- Primary: Product lead or engineer using PM orchestration to plan and prepare large feature delivery.
- Secondary: Team leads running prepared Ralph queue workloads.

## 5. Goals
- Add a separate explicit command for large feature planning: `$pm plan big feature:`.
- Keep `$pm plan:` as the default single-PRD flow.
- Support two big-feature planning modes:
  - `conflict-aware`: discovery must split PRDs to minimize cross-PRD file/ownership conflicts.
  - `worktree-isolated`: each PRD executes in isolated git worktree context.
- Use parent discovery once for the large feature and delta discovery per PRD.
- For each PRD, enforce required gates and enqueue as runnable only after Beads approval.
- Prepare queue asynchronously with bounded concurrency (worker cap `2`).
- Use bounded retry policy: one automatic retry, then manual intervention.

## 6. Non-Goals
- Replacing the default single-PRD `$pm plan:` behavior.
- Changing core Ralph internals.
- Implementing full feature code execution in this phase.

## 7. Scope (In/Out)
### In Scope
- New PM command path for big features.
- Dual planning modes for big features: `conflict-aware` and `worktree-isolated`.
- Discovery-time conflict analysis to minimize PRD overlap in file ownership and dependency chains.
- PRD decomposition model and per-PRD lifecycle states.
- Async queue preparation pipeline for approved PRDs.
- Queue manifest state and idempotency behavior.
- Worktree strategy aligned with Ralph parallel worktree model.
- Documentation and skill/workflow updates required to support the new mode.

### Out of Scope
- New external workflow platform adoption (Temporal/Step Functions) for this PRD.
- Replacing Ralph-native worktree execution with a separate mandatory worktree orchestrator.
- Multi-repository orchestration.
- UI dashboard implementation beyond existing CLI/PM outputs.

## 8. User Flow
### Happy Path
1. User runs `$pm plan big feature:` with idea, context, and requirements.
2. PM runs parent discovery once, including support agents, and asks for planning mode selection (`conflict-aware` or `worktree-isolated`).
3. PM decomposes into multiple PRD candidates.
4. If mode is `conflict-aware`, discovery adds explicit anti-conflict boundaries (ownership/file touch/dependency constraints) for each PRD.
5. If mode is `worktree-isolated`, PM assigns isolated worktree execution context per PRD (aligned with Ralph parallel worktree behavior).
6. For each PRD: run delta discovery, create/update PRD, resolve Open Questions, request PRD approval (`approved`), generate Beads plan, request Beads approval (`approved`).
7. After Beads approval, PM creates queue entry with canonical queue unit = Beads epic ID and marks runnable.
8. PM continues with next PRD while queue preparation runs asynchronously.
9. Completion condition: all PRDs are enqueued, selectable, and pass preflight readiness checks.

### Failure Paths
1. PRD has unresolved Open Questions: PRD stays blocked and is not queued.
2. User does not reply with exact `approved`: gate remains blocked.
3. Queue preparation fails: one automatic retry runs; if still failing, PRD marked failed and requires manual intervention.
4. Duplicate enqueue attempt: idempotency key prevents duplicate runnable queue entries.
5. Preflight fails for enqueued PRD: item stays non-runnable until issue resolved.

## 9. Acceptance Criteria (testable)
1. `$pm plan:` continues to execute single-PRD flow unchanged.
2. `$pm plan big feature:` triggers multi-PRD mode.
3. Big-feature mode supports exactly two planning modes: `conflict-aware` and `worktree-isolated`.
4. Parent discovery runs once per big-feature request.
5. Delta discovery runs per generated PRD.
6. In `conflict-aware` mode, each PRD includes explicit anti-conflict constraints captured during discovery.
7. In `worktree-isolated` mode, each PRD is assigned isolated worktree execution context compatible with Ralph parallel worktrees.
8. Each PRD must pass PRD approval gate and Beads approval gate before runnable queue promotion.
9. Queue unit for runnable work is Beads epic ID.
10. Queue preparation executes asynchronously with max workers set to `2`.
11. Queue-ready status requires: enqueued + selectable tasks + passing preflight (`doctor`) checks.
12. Enqueue failures perform one automatic retry only.
13. Second failure requires manual intervention and does not auto-loop.
14. Idempotency prevents duplicate runnable entries per PRD approval version.
15. Final output includes a reconciliation report: PRDs discovered, approved, queued, failed.

## 10. Success Metrics (measurable)
- Queue readiness coverage: 100% of approved PRDs reach runnable queue-ready or explicit failed/manual-intervention state.
- Duplicate enqueue rate: 0 duplicate runnable entries for same PRD approval version.
- Throughput: at least 2 PRDs can be in async queue-prep lifecycle concurrently (bounded by worker cap 2).
- Gate integrity: 0 runnable promotions without both required approvals.

## 11. BEADS
### Business
- Faster planning-to-execution readiness for large features without sacrificing gate quality.

### Experience
- Users get one explicit command for big features and predictable per-PRD approval checkpoints.

### Architecture
- Add multi-PRD orchestration path and persisted queue state with idempotent transitions.
- Use Ralph-native worktree isolation as the primary execution model for `worktree-isolated` mode.
- Keep external worktree tooling (for example Worktrunk) optional and non-authoritative over Ralph execution state.

### Data
- Track per-PRD state, approval version, epic ID, enqueue status, retry count, and failure reason.

### Security
- Preserve existing approval gates and auditability; do not bypass human approvals.

## 12. Rollout / Migration / Rollback
- Rollout: introduce `$pm plan big feature:` behind explicit command path only.
- Migration: none required for existing single-PRD users.
- Rollback: disable big-feature command path and retain single-PRD flow.

## 13. Risks & Edge Cases
- Policy drift between workflow and skill files can cause inconsistent behavior.
- Missing subagent/tool runtime support can block swarm steps.
- Retry/idempotency bugs can cause dropped or duplicate queue items.
- Preflight or dependency issues can leave PRDs queued but non-runnable.
- Long approval delays can stall full queue readiness.
- Running an additional worktree manager in parallel with Ralph-native worktrees can introduce branch/worktree lifecycle conflicts.
- Worktree-isolated mode increases disk usage and repository housekeeping overhead.

## 14. Open Questions
