# PRD

## 1. Title, Date, Owner
- Title: PM Token Telemetry And Claude Runtime Conformance
- Date: 2026-03-04
- Owner: PM Orchestrator

## 2. Problem
PM workflow runs consume tokens quickly, but there is no comprehensive per-task/per-step accounting to explain where quota is spent. Operators cannot reliably answer which step or subagent consumed what token volume and how long each step took.

Additionally, runtime routing policy is documented, but execution-time conformance is not explicit enough: roles configured for `claude-code-mcp` should default to Claude, and if Claude is unavailable, workflow should continue via codex-native fallback while reporting a clear warning.

## 3. Context / Current State
- PM routing profiles and role mappings are defined in:
  - `/Users/d/product-orchestrator/skills/pm/agents/model-routing.yaml`
- PM gate helper enforces lead-model selection and fail-fast behavior for `claude-first` when Claude MCP is unavailable:
  - `/Users/d/product-orchestrator/skills/pm/scripts/pm-command.sh`
- Current observability for PM execution is not persisted as step-level token telemetry in PostgreSQL.
- Target PostgreSQL instance is reachable and currently empty (no user tables), so telemetry schema can be introduced cleanly.

Alternatives considered:
1. Inline synchronous ledger writes only.
- Pros: fastest initial implementation.
- Cons: weaker resilience and correction path.
2. Full OTel-first external pipeline.
- Pros: standard tracing model.
- Cons: higher infra complexity for current goal.
3. Incremental Postgres event ledger with clear fallback and later reconciliation.
- Pros: good balance of speed, debuggability, and future correctness.
- Selected for this phase, with tokens/timings first and cost/reconciliation deferred.

## 4. User / Persona
- PM workflow operator running multi-agent feature delivery in Codex.
- Needs clear quota debugging per workflow task and step.

## 5. Goals
- Persist comprehensive per-step telemetry for PM workflow into PostgreSQL.
- Capture at minimum: workflow/task/step identity, agent and invoker identity, runtime/provider/model, start/end timestamps, token counts.
- Provide deterministic parent/child attribution across PM, subagent, and handoff steps.
- Enforce routing semantics explicitly:
  - If role is configured with `claude-code-mcp`, default to Claude invocation path.
  - If Claude is unavailable, fallback to codex-native spawn and emit warning with reason/remediation.
- Update workflow instructions and docs so fallback behavior and telemetry expectations are explicit for agents/operators.

## 6. Non-Goals
- Hard quota blocking/enforcement in this phase.
- Full billing/cost reconciliation pipeline in this phase.
- Replacing existing phase order, approval gates, or Beads workflow.

## 7. Scope (In/Out)
### In Scope
- Telemetry schema and writes for PM workflow execution events in PostgreSQL.
- Step-level logging for:
  - PM orchestration steps
  - subagent invocations
  - external Claude MCP calls
  - fallback-to-codex events
- Basic aggregated query/view support for per-task token and timing diagnostics.
- Runtime conformance updates in PM instructions/contracts:
  - Claude-configured roles default to Claude path
  - fallback behavior is explicit and non-blocking with warning
- Documentation updates across relevant PM docs and README-level guidance.
- Smoke test plan and evidence for telemetry and conformance behavior.

### Out of Scope
- Cost-in-USD accounting and pricing-table versioning.
- Cross-repository/global telemetry centralization.
- Automated anomaly alerting/notification pipelines.

## 8. User Flow
### Happy Path
1. User starts PM planning flow.
2. Workflow runs with configured routing profile.
3. For each step/task/subagent, system writes telemetry row(s) to PostgreSQL with IDs, model/runtime, token counts, and timing.
4. Roles mapped to `claude-code-mcp` invoke Claude path by default.
5. User can query per-task/per-step token and latency breakdown.

### Failure Paths
1. Claude mapped role cannot use Claude MCP (unavailable/errored).
2. System falls back to codex-native role execution.
3. System writes warning event including reason and remediation hint (`codex mcp add claude-code -- claude mcp serve`).
4. Workflow continues without phase break.

5. Telemetry DB write fails temporarily.
6. System emits explicit warning and continues workflow.
7. Missing telemetry for affected step is visible via warning event and phase summary.

## 9. Acceptance Criteria (testable)
1. PM workflow writes telemetry records to PostgreSQL for every executed step in Discovery, PRD, Beads planning, implementation orchestration, and review/QA phases.
2. Each telemetry record includes:
   - `workflow_run_id`, `task_id`, `step_id`, `parent_step_id` (nullable)
   - `phase`, `step_name`, `agent_role`, `invoked_by_role`
   - `runtime` (`claude-code-mcp` or `codex-native`)
   - `provider`, `model`
   - `started_at`, `ended_at`, `duration_ms`
   - `prompt_tokens`, `completion_tokens`, `total_tokens`
   - `status` and `error_or_warning_code` (nullable)
3. For roles configured as `claude-code-mcp`, runtime defaults to Claude invocation path when available.
4. If Claude path is unavailable for a mapped role, execution falls back to codex-native for that step and workflow does not hard-stop.
5. Each fallback emits a warning telemetry event with:
   - affected role
   - reason
   - remediation command
6. Querying by `task_id` returns full per-step token and timing timeline in execution order.
7. Querying by `workflow_run_id` returns parent/child invocation lineage.
8. Telemetry arithmetic is valid for all rows (`total_tokens = prompt_tokens + completion_tokens` when both parts are present).
9. PM docs and instructions explicitly describe Claude-default-with-fallback behavior and warning/reporting requirements.
10. Smoke tests cover happy path, unhappy path, and regression for telemetry completeness and routing conformance.

## 10. Success Metrics (measurable)
- 100% of executed PM steps have telemetry rows in normal operation.
- 100% of Claude-unavailable fallback events produce warning records with remediation.
- For sampled workflow runs, per-task token totals can be reconstructed from step records with 0 arithmetic mismatch.
- Operator can identify top token-consuming steps for a task/run using a single SQL query.

## 11. BEADS
### Business
- Reduces debugging time for quota overruns and improves predictability of PM workflow cost.

### Experience
- Operators can inspect exactly where tokens/time are consumed without guesswork.

### Architecture
- Introduce append-oriented PostgreSQL telemetry tables for workflow/task/step events.
- Include runtime-conformance event logging for Claude default and fallback execution paths.

### Data
- Store step-level usage and timing facts with lineage identifiers.
- Keep prompt text allowed in this private DB context.

### Security
- Database access remains restricted to owner-controlled environment.
- No new external sharing requirement.

## 12. Rollout / Migration / Rollback
- Rollout: add schema + instrumentation behind PM workflow execution path, then enable by default.
- Migration: initialize new tables/views in empty target DB and start logging new runs.
- Rollback: disable telemetry writes and revert conformance enforcement changes while preserving historical telemetry tables.

## 13. Risks & Edge Cases
- Risk: fallback path could mask prolonged Claude outages.
  - Mitigation: warning events + phase error summary visibility.
- Risk: missing token fields from some providers/models.
  - Mitigation: nullable detail fields and explicit `usage_source/status` columns.
- Risk: write amplification and DB latency.
  - Mitigation: append-only rows, indexed query paths, and limited v1 scope (tokens/timings only).
- Edge case: duplicated step events under retries.
  - Mitigation: idempotency key per step attempt and dedupe constraint.

## 14. Open Questions
