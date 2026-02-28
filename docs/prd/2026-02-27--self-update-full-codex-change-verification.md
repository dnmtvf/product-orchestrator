# PRD

## 1. Title, Date, Owner
- Title: Self-Update Full Codex Change Verification
- Date: 2026-02-27
- Owner: d

## 2. Problem
The current PM self-update check validates only a latest semantic version signal and does not verify the full set of latest Codex changes that should drive orchestration alignment updates.

Because of this, the pipeline can miss relevant upstream deltas (especially prerelease drift), advance checkpoint state without complete review coverage, and lack auditable evidence that alignment work actually considered all latest changes.

## 3. Context / Current State
Current helper behavior in `/Users/d/product-orchestrator/skills/pm/scripts/pm-command.sh`:
- `self-update check` fetches changelog and `releases/latest`, extracts semver, and selects one max version.
- State is single-version oriented (`latest_processed_codex_version`, `pending_codex_version`).
- `self-update complete` enforces approval tokens and PRD Open Questions emptiness, but does not prove complete upstream change coverage.

Observed external reality (as of 2026-02-26):
- Stable release track is `0.105.0`.
- Prerelease track has active `0.106.0-alpha.*` cadence.

Discovery decisions captured from user:
- Track stable + prerelease.
- Use Codex changelog website as source of truth.
- Self-update remains manually invoked, but may invoke PM planning route for implementation alignment.
- Completion proof is PRD-based.
- Process pending updates in one batch per cycle (for now).
- Rollout scope is this repository only.

Alternatives considered:
- Option A: Harden stable-only checks.
- Option B: Dual-track stable + prerelease awareness with strict governance.
- Option C: Fully autonomous scheduled update control plane.

Chosen direction:
- Option B adapted to user constraints (manual invocation, changelog source-of-truth, one-batch PRD proof).

## 4. User / Persona
- Primary: repository maintainers running PM workflow and self-update cycles.
- Secondary: PM orchestration agents that must produce auditable, deterministic update decisions.

## 5. Goals
- Verify all latest Codex changes relevant to self-update (stable + prerelease) from changelog-source-of-truth inputs.
- Produce deterministic, auditable evidence that PM alignment planning covered the pending change set.
- Keep manual invocation model while allowing self-update to trigger PM plan flow for implementation alignment.
- Support feature/config toggles to enable or disable prerelease-sensitive behaviors when needed.
- Preserve strict completion gates and avoid false checkpoint advancement.

## 6. Non-Goals
- Full autonomous/scheduled self-update execution.
- Organization-wide rollout to injected target repos in this iteration.
- Replacing PM approval gates with automatic approvals.

## 7. Scope (In/Out)
### In Scope
- Update self-update check logic in:
  - `/Users/d/product-orchestrator/skills/pm/scripts/pm-command.sh`
- Extend state/evidence handling under:
  - `/Users/d/product-orchestrator/.codex/pm-self-update-state.json`
- Update test coverage in:
  - `/Users/d/product-orchestrator/scripts/test-pm-command.sh`
- Update PM workflow/help docs as needed to match behavior in this repo.
- Implement change-set verification for stable + prerelease in one batch.
- Add config controls for enabling/disabling prerelease-sensitive behavior paths.

### Out of Scope
- Automatic background scheduler.
- Multi-repo propagation.
- Non-Codex runtime policy changes.

## 8. User Flow
### Happy Path
1. Maintainer runs `/pm self-update` (manual).
2. `self-update check` fetches/normalizes changelog-source-of-truth change entries and associated release metadata.
3. System computes pending change set (stable + prerelease) relative to processed baseline.
4. If pending set exists, system invokes PM planning route for alignment implementation.
5. PRD is produced/approved and explicitly documents coverage of all pending entries (one batch).
6. `self-update complete` validates approvals + PRD proof + empty Open Questions.
7. State is checkpointed and processed baseline advances to matched batch boundary.

### Failure Paths
1. Changelog source unavailable or malformed: fail closed, no state advance.
2. Source mismatch beyond allowed reconciliation rules: fail closed, require manual review.
3. PRD proof does not cover all pending entries: completion blocked.
4. Open Questions not empty: completion blocked.
5. Invalid approval tokens: completion blocked.

## 9. Acceptance Criteria (testable)
1. `self-update check` identifies pending updates using stable + prerelease channels in one deterministic batch.
2. Changelog website remains source of truth; any auxiliary source is used only for corroboration and metadata.
3. `self-update check` output includes machine-readable pending-change coverage context sufficient for PRD planning.
4. Manual invocation remains required; no scheduled/background path is introduced.
5. Self-update flow can invoke PM planning route when pending updates are detected.
6. `self-update complete` requires:
   - `--approval approved`
   - `--prd-approval approved`
   - `--beads-approval approved`
   - PRD path whose Open Questions section is empty
   - PRD evidence that all pending entries in the batch were reviewed
7. State is not advanced if PRD coverage is incomplete or mismatch rules fail.
8. Config toggles exist to enable/disable prerelease-sensitive behavior paths.
9. Tests cover:
   - happy path batch detection/complete
   - malformed/missing source behavior
   - source disagreement handling
   - prerelease/stable ordering correctness
   - no-op reruns
10. Existing PM command routing remains unchanged:
   - `$pm plan: ...`
   - `$pm plan big feature: ...`
   - `$pm self-update`
   - `$pm help`

Smoke Test Plan (must-run):
- Happy path:
  - dual-track detection identifies pending batch correctly
  - PM plan trigger emitted/invoked correctly
  - completion succeeds only with full PRD coverage and approvals
- Unhappy path:
  - changelog fetch/parse failure blocks completion
  - incomplete PRD coverage blocks completion
  - invalid approvals block completion
  - source mismatch policy violation blocks completion
- Regression:
  - manual-only self-update preserved
  - codex-only runtime policy preserved
  - existing command routing and approval semantics unchanged

Post-implementation QA execution notes:
1. Run baseline script: `bash /Users/d/product-orchestrator/scripts/test-pm-command.sh`
2. Run must-run happy path cases.
3. Run must-run unhappy path cases.
4. Run regression suite.
5. If failures appear, create Beads fix tasks, remediate, and rerun failed groups plus baseline.

## 10. Success Metrics (measurable)
- 100% of self-update completions include PRD evidence covering all pending batch entries.
- 0 false-positive completion checkpoints when coverage is incomplete.
- 100% of failing source-truth or mismatch scenarios fail closed (no state advance).
- 100% pass rate for added stable+prerelease batch tests in CI/local quality gates.

## 11. BEADS
### Business
- Improves reliability of orchestrator alignment against Codex changes.
- Reduces operational risk from missed or partially reviewed upstream updates.

### Experience
- Maintainers get deterministic self-update behavior with explicit coverage proof.
- Workflow remains familiar: manual trigger plus existing PM approval gates.

### Architecture
- Transition from single pending version to pending change-set batch semantics.
- Maintain changelog-source-of-truth with deterministic reconciliation policy.
- Preserve codex-only runtime and command routing behavior.

### Data
- State persists pending batch context, processed baseline, and checkpoint references.
- PRD acts as completion proof artifact for reviewed pending entries.

### Security
- Fail closed on malformed/untrusted upstream data.
- No automated unsupervised execution path added.

## 12. Rollout / Migration / Rollback
- Rollout: implement in this repository only; enable stable + prerelease batch detection with changelog-source-of-truth logic.
- Migration: migrate existing single-version state to batch-aware representation without losing latest processed baseline.
- Rollback: revert to prior commit and restore prior state-file schema/content from git history.

## 13. Risks & Edge Cases
- Upstream changelog formatting drift can break parsing if not validated defensively.
- High prerelease cadence may increase noise; config toggles must control operational impact.
- Ambiguous source disagreement policy can lead to blocked updates or false confidence.
- Incomplete PRD evidence mapping can block completion if not clearly structured.

## 14. Open Questions
