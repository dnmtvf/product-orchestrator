# Manual QA Smoke Report

Date: 2026-02-27
Scope: Self-update full Codex change verification (stable + prerelease batch flow), source-of-truth/mismatch policy, completion gates, and PM route/help regression.

## Happy Path
- PASS: `self-update check` detects deterministic pending batch from changelog payload with stable + prerelease entries.
- PASS: check output includes machine-readable planning context (`UPDATE_AVAILABLE`, `PENDING_BATCH`, `PLAN_TRIGGER`, `PLAN_CONTEXT`).
- PASS: prerelease feature toggle works (`PM_SELF_UPDATE_INCLUDE_PRERELEASE=0` narrows pending batch to stable-only).
- PASS: `self-update complete` succeeds only with exact approval tokens and PRD evidence covering all pending batch versions.
- PASS: checkpoint commit scopes only state file and preserves unrelated staged files.

## Unhappy Path
- PASS: malformed changelog payload fails closed (no state advance).
- PASS: incomplete PRD evidence blocks completion (`PRD evidence missing pending versions`).
- PASS: strict mismatch mode fails closed when corroborative sources disagree (`PM_SELF_UPDATE_STRICT_MISMATCH=1`).
- PASS: invalid completion approvals are rejected by required token gates.

## Regression
- PASS: command routing remains unchanged:
  - `$pm plan: ...`
  - `$pm plan big feature: ...`
  - `$pm self-update`
  - `$pm help`
- PASS: self-update remains manual-only.
- PASS: changelog remains source of truth; release/npm remain corroborative only.
- PASS: no-op rerun emits explicit `NO_OP|...` when processed baseline is current.
- PASS: live-source check on 2026-02-27 resolves changelog latest to `0.106.0` (no false promotion to non-CLI semver noise).

## Automated Coverage
Executed: `bash /Users/d/product-orchestrator/scripts/test-pm-command.sh`
- PASS: help output contract
- PASS: bootstrap + dual-track batch detection
- PASS: non-CLI semver noise is ignored during changelog parsing
- PASS: prerelease toggle behavior
- PASS: PRD batch coverage enforcement
- PASS: approval token gate enforcement
- PASS: dry-run immutability
- PASS: checkpoint commit behavior
- PASS: mismatch policy behavior (non-strict + strict)
- PASS: malformed source fail-closed behavior
- PASS: no-op rerun behavior

## Evidence Summary
Smoke scope passed for this run with no open defects.
