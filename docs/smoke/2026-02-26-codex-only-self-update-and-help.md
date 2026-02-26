# Manual QA Smoke Report

Date: 2026-02-26
Scope: Codex-only runtime enforcement, manual self-update flow, `$pm help` command output, and docs/routing regression.

## Happy Path
- PASS: `$pm help` output contains default planning invocation, big-feature invocation, and ordered phase guidance.
- PASS: `self-update check` detects newer Codex version from both official sources and emits `PLAN_TRIGGER|/pm plan:`.
- PASS: `self-update check` uses deterministic trigger string matching documented PM command routing.
- PASS: `self-update complete --approval approved --prd-approval approved --beads-approval approved --prd-path ... --dry-run` passes completion gate and emits checkpoint action preview.

## Unhappy Path
- PASS: Unknown command fails with explicit error (`Unknown command`).
- PASS: Invalid completion token is rejected (`--approval` must be exact `approved`).
- PASS: Dry-run completion does not mutate persisted self-update state.

## Regression
- PASS: Command routing contract remains in workflow docs and PM skill:
  - `$pm plan:` default single-PRD path
  - `$pm plan big feature:` explicit big-feature path
  - `$pm help` route present
  - `$pm self-update` manual route present
- PASS: Installer/injector remain Codex-only and reject legacy runtime flags.
- PASS: Live-source parsing returns current Codex version (`0.105.0`) from both changelog and releases on this run.

## Automated Coverage
Executed: `scripts/test-pm-command.sh`
- PASS: help output contract
- PASS: update-available detection
- PASS: approval gate enforcement
- PASS: checkpoint commit behavior in isolated git repo
- PASS: checkpoint commit scopes only state file and does not sweep unrelated staged files
- PASS: no-op behavior when already up to date

## Evidence Summary
All smoke checks in scope passed for this run. No defects found in smoke scope.
Epic `product-orchestrator-3ln` remains open intentionally pending user final review.
