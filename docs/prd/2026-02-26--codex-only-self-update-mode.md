# PRD

## 1. Title, Date, Owner
- Title: Codex-Only Orchestrator and Manual Self-Update Mode
- Date: 2026-02-26
- Owner: d

## 2. Problem
The orchestrator has diverged from a Codex-only runtime model by adding compatibility behavior for conductor.build and direct Claude Code runtime paths. This increases ambiguity in execution behavior and conflicts with the goal of a Codex-first pipeline.

The orchestrator also lacks a standardized self-update capability that inspects latest Codex changes and drives a full planning flow for alignment updates.

The current workflow lacks a discoverable `$pm help` command to show supported PM invocations and required phase steps, which increases operator error risk.

## 3. Context / Current State
Current scripts and docs include dual-runtime assumptions (`.codex` and `.claude`) and references to conductor compatibility. PM workflow content also includes Claude MCP usage in some phases. There is no persisted version checkpoint indicating which Codex version was last reviewed through the self-improvement process.

Latest local repo changes include a modified `AGENTS.md` and an in-progress PRD file. New implementation work must avoid overwriting unrelated latest local edits.

Alternatives considered:
- Hard cutover now (selected): remove non-Codex runtime compatibility with no fallback.
- Phased profile model: temporary legacy mode plus codex-only default.
- Provider abstraction layer for future multi-runtime support.

Selected rationale:
- User requires no fallbacks and explicit Codex-only compatibility now.

## 4. User / Persona
- Primary user: repository maintainers operating PM-driven feature delivery workflows.
- Secondary user: execution agents that run the PM plan flow and associated subagents.

## 5. Goals
- Enforce Codex-only runtime compatibility in orchestrator scripts/docs/workflow contracts.
- Keep Claude usage available only as MCP integration for subagents where required by current PM workflow.
- Add a manual self-update mode that runs full `pm plan:` workflow with task: inspect latest Codex changes.
- Use both official Codex changelog and Codex GitHub release surfaces as update inputs.
- Persist the latest Codex version that has completed the self-improvement flow and checkpoint each self-update via git commit.
- Add `$pm help` command support that prints core PM invocations and the required phase sequence.
- Update documentation to reflect codex-only runtime behavior, `$pm help` usage, and self-update flow.
- Preserve latest unrelated local repo changes during implementation.

## 6. Non-Goals
- Automatic/scheduled self-update execution.
- Silent auto-apply of architectural or behavioral changes without PM workflow approvals.
- Maintaining legacy fallback runtime profiles.

## 7. Scope (In/Out)
### In Scope
- Remove conductor.build compatibility behavior from orchestrator docs/scripts/workflow text.
- Remove direct Claude runtime compatibility paths from orchestrator runtime model.
- Preserve Claude via MCP path for PM subagent workflows.
- Implement manual self-update command/mode that:
  - fetches latest Codex changelog and GitHub release metadata,
  - compares against persisted processed version,
  - launches full `pm plan:` workflow for alignment planning,
  - updates persisted processed version only after standard PM flow completion gate,
  - creates a git commit checkpoint for each self-update run.
- Add/maintain durable state file for processed Codex version.
- Implement `$pm help` route/response that includes:
  - supported invocations (`$pm plan: ...`, `$pm plan big feature: ...`),
  - required phase order,
  - approval gate reminder (`approved` for PRD and Beads).
- Update docs in this repository for:
  - runtime policy and installation behavior,
  - command routing including `$pm help`,
  - self-update manual execution and checkpoint behavior.
- Ensure implementation does not overwrite unrelated latest changes (for example user-edited `AGENTS.md` content).

### Out of Scope
- Background daemon for update monitoring.
- Multi-provider runtime support.
- Non-PM shortcut path that bypasses PRD/Beads approval gates.

## 8. User Flow
### Happy Path
1. Maintainer runs manual self-update mode.
2. System reads official Codex changelog and Codex GitHub latest release.
3. System compares discovered version(s) with persisted `latest_processed_codex_version`.
4. If newer changes exist, system triggers full `pm plan:` workflow with task to inspect latest Codex changes and assess orchestrator alignment opportunities.
5. Standard PM process runs (Discovery -> PRD approval -> Beads approval -> implementation/review/QA).
6. On successful completion gate (same as existing PM plan flow), system updates stored processed Codex version and creates a commit checkpoint.
7. Maintainer runs `$pm help` and receives concise command invocations plus ordered phase steps.

### Failure Paths
1. Changelog/release fetch fails: self-update exits with error, no version checkpoint change.
2. Parsed version invalid or missing: self-update exits with actionable error, no checkpoint change.
3. PM flow not completed/approved: no processed-version update and no checkpoint commit.
4. Any non-Codex runtime path detected during execution: hard fail.

## 9. Acceptance Criteria (testable)
1. Runtime orchestration no longer includes conductor compatibility behavior.
2. Runtime orchestration no longer includes direct Claude runtime compatibility paths; Codex is the only runtime target.
3. Claude MCP integration remains functional for PM subagents that require it.
4. Self-update mode is manual-only and triggers full `pm plan:` workflow (not partial shortcut flow).
5. Self-update mode reads both:
   - https://developers.openai.com/codex/changelog/
   - https://github.com/openai/codex/releases/latest
6. Persisted `latest_processed_codex_version` is updated only after the completion gate used by current PM plan flow.
7. Each completed self-update run creates a git commit checkpoint capturing state/version update.
8. No fallback runtime mode is available after rollout.
9. `$pm help` output includes:
   - default planning invocation,
   - big-feature planning invocation,
   - ordered PM phase list,
   - exact approval gate response requirement (`approved`).
10. Documentation is updated to include codex-only runtime, self-update flow, and `$pm help` usage.
11. Latest unrelated local file changes are preserved during implementation (no overwrite of unrelated modified files).

Smoke Test Plan:
- Happy path:
  - Starting from older stored version with two newer upstream versions applies in order and ends at latest.
  - Re-run with unchanged upstream versions is explicit no-op.
  - Restart after success preserves state and avoids replay.
- Unhappy path:
  - Corrupt stored version causes fail-fast without state advance.
  - Upstream fetch timeout/5xx does not change state.
  - Malformed upstream version data does not produce false advances.
  - Mid-run failure leaves system resumable without incorrect completion mark.
- Regression:
  - Existing non-update PM operations behave unchanged.
  - Self-update-disabled path preserves baseline behavior.
  - Repeated runs remain idempotent (no duplicate side effects).
  - `$pm plan:` and `$pm plan big feature:` routing remains unchanged after adding `$pm help`.

## 10. Success Metrics (measurable)
- 100% of orchestrator runtime invocations use Codex-only runtime path.
- 0 successful executions through legacy fallback runtime paths.
- 100% of completed self-update runs produce a corresponding commit checkpoint.
- 100% of processed-version updates are traceable in git history.

## 11. BEADS
### Business
- Reduces operational ambiguity and maintenance cost by converging on one runtime path.
- Provides explicit audit trail of compatibility updates against Codex evolution.

### Experience
- Maintainers run a single explicit self-update entrypoint and receive deterministic behavior.
- PM flow remains consistent with existing approval gates.
- Maintainers can discover command usage and phase expectations quickly via `$pm help`.

### Architecture
- Single runtime target: Codex.
- Claude only via MCP interface for designated subagent tasks.
- Self-update orchestration hooks into existing `pm plan:` flow and reuse of current PM gates.
- Command routing includes explicit `$pm help` handler/response without changing existing plan-route semantics.

### Data
- Introduce persisted state artifact for `latest_processed_codex_version` and metadata (timestamp, sources, checkpoint reference).
- State updates are commit-backed for explicit checkpoints.

### Security
- Self-update inputs limited to official sources.
- Fail-closed behavior on invalid or unavailable upstream version metadata.
- No automatic background changes without human review/approval gates.

## 12. Rollout / Migration / Rollback
- Rollout:
  - Remove non-Codex runtime compatibility paths and conductor references.
  - Add manual self-update mode and processed-version state handling.
  - Add `$pm help` command behavior.
  - Update repository documentation for runtime policy and command routing.
  - Validate smoke tests and PM flow continuity.
- Migration:
  - Existing users transition immediately to codex-only runtime behavior (no fallback mode).
  - Claude runtime usage shifts/continues via MCP-only mechanism where needed.
- Rollback:
  - Revert to prior commit if production issues occur.
  - Restore previous state file version from git history.

## 13. Risks & Edge Cases
- Hard cutover can break users relying on removed legacy runtime behavior.
- Upstream changelog/release format drift may break parsing.
- Frequent Codex changes can increase update planning overhead.
- Incorrect completion-gate wiring could prematurely update processed-version checkpoint.
- `$pm help` output can drift from actual workflow behavior if docs/skill text are not updated in the same change.
- Unrelated local edits can be accidentally overwritten if file-scoping discipline is not enforced.

## 14. Open Questions
