# PRD

## Title
Deterministic Claude MCP Snapshot and Legacy droid-worker Cleanup for PM Self-Check

## Date
2026-03-22

## Owner
PM Orchestrator

## Problem
The PM self-check in the current Codex runtime proves that Claude MCP is usable for PM routing and session work, but it still fails the artifact snapshot step because `claude mcp list` hangs long enough to exceed the helper timeout.

That leaves the repo without a fully working Claude MCP solution for self-check:
- PM route gating succeeds in `Dynamic Cross-Runtime`
- Claude session usability passes
- the overall self-check still ends `issues_detected`
- the failure is caused by the snapshot path, not the Claude session path

The user also clarified that `droid-worker` is a legacy Claude MCP server and should be removed entirely rather than preserved as a supported path.

Users need self-check to complete cleanly in realistic environments where Claude has stale legacy MCP entries and other user-level Claude servers that may be slow, unauthenticated, or failed.

## Context / Current State
- In the current Codex runtime, `codex mcp list` shows `claude-code` enabled.
- `./skills/pm/scripts/pm-command.sh plan gate --route default --mode dynamic-cross-runtime` returns `PLAN_ROUTE_READY` and routes the expected support roles through `claude-code-mcp`.
- `./skills/pm/scripts/pm-command.sh self-check run --fixture-case happy-path --mode main-runtime-only` passes:
  - Claude registration
  - Claude executability
  - Claude session usability
- The same run fails `claude_mcp_snapshot` with:
  - `primary_code=snapshot_command_hung`
  - partial output `Checking MCP server health...`
- The helper currently hard-codes a 5-second outer timeout for both `codex mcp list` and `claude mcp list`.
- Official Claude Code docs document `MCP_TIMEOUT` as the startup timeout control for MCP commands.
- In the current environment:
  - plain `claude mcp list` hangs past 30 seconds
  - `claude mcp get context7` and `claude mcp get github` return quickly
  - `claude mcp get droid-worker` hangs unless `MCP_TIMEOUT` is set
  - `MCP_TIMEOUT=3000 claude mcp get droid-worker` returns in about 4 seconds with `Failed to connect`
  - `MCP_TIMEOUT=3000 claude mcp list` returns in about 6.5 seconds with explicit statuses, including `droid-worker ... Failed to connect`
  - a temp-home Claude config with `droid-worker` removed still let `claude mcp list` hang past 20 seconds, so the stale legacy server is a real defect but not the only reason the snapshot path is nondeterministic

### Confirmed Discovery Findings
- The broken behavior is reproducible in the current Codex runtime.
- The failure is not a missing Claude binary or missing `claude-code` MCP registration.
- The failure is not Claude session unusability.
- `droid-worker` is a stale legacy Claude MCP registration and should be removed from supported user setup.
- Removing `droid-worker` alone is not sufficient to guarantee a deterministic snapshot in the current environment.
- The failure is specific to the artifact snapshot contract using an unbounded Claude-side health check and an undersized helper-side timeout.
- One or more user-level Claude MCP servers can stall `claude mcp list`.
- The repo should not require users to manually prune arbitrary user-level Claude MCP servers just to get a clean PM self-check.

### Alternatives Considered
1. Increase the helper timeout only.
Rejected because Claude still uses its own longer per-server health timeout, so the command remains slow and environment-sensitive.

2. Remove legacy `droid-worker` registration and treat that as the full fix.
Rejected as a sole solution because the current temp-home probe still timed out after `droid-worker` removal, so the snapshot contract remains nondeterministic even after legacy cleanup.

3. Remove legacy `droid-worker` registration as an explicit cleanup step, but still harden snapshot capture.
Selected in part because the user confirmed `droid-worker` is obsolete and should no longer survive in supported setup or remediation paths.

4. Skip Claude MCP snapshot collection when session usability passes.
Rejected because the self-check contract still requires artifact evidence and should not silently reduce observability.

5. Bound Claude's own MCP startup timeout during snapshot capture and give the helper a separate outer timeout budget.
Selected because it keeps artifact capture intact, surfaces failing Claude servers explicitly, and makes the snapshot step deterministic in realistic environments.

## User / Persona
- PM workflow maintainers who need `/pm self-check` to be trustworthy.
- Operators running PM in Codex runtime with `Dynamic Cross-Runtime`.
- Engineers carrying stale legacy `droid-worker` user config or broader Claude MCP inventories who should not be blocked by unrelated Claude servers.

## Goals
- Make Claude MCP snapshot capture deterministic in the PM self-check.
- Remove legacy `droid-worker` from the supported Claude setup/remediation story.
- Allow clean self-check completion when Claude session usability is healthy and the snapshot command can finish within a bounded budget.
- Preserve visible reporting for failed or unauthenticated Claude-side servers in the snapshot artifact output.
- Avoid requiring manual edits to user-level Claude configuration just to satisfy PM self-check.
- Add regression coverage for the current hanging-server case.

## Non-Goals
- Broadly managing arbitrary user entries in `~/.claude.json`.
- Hiding failed or unauthenticated Claude MCP servers from snapshot output.
- Redesigning the PM Claude session probe contract.
- Changing the PM routing model for `Dynamic Cross-Runtime`.

## Scope

### In-Scope
- Update Claude snapshot capture in `skills/pm/scripts/pm-command.sh` to run with a bounded Claude-side MCP startup timeout.
- Increase or separate the helper-side outer timeout budget for the Claude snapshot step so bounded Claude runs can finish.
- Record the applied Claude MCP timeout policy in snapshot attempt evidence.
- Remove stale legacy `droid-worker` from supported setup/remediation docs and any repo-managed cleanup path that still mentions it as active.
- If self-check detects legacy `droid-worker`, surface it as targeted cleanup/remediation evidence instead of treating it as a supported server.
- Keep codex snapshot behavior deterministic and avoid regressing the existing Codex snapshot path.
- Add automated coverage for:
  - current hanging `claude mcp list` behavior
  - legacy `droid-worker` cleanup handling
  - bounded-timeout successful completion
  - preservation of non-clean server statuses in artifact output
- Add smoke evidence for the current Codex runtime after the fix.

### Out-of-Scope
- Fixing the external `droid-worker` server itself.
- Repairing third-party OAuth state such as `clickup` authentication.
- General Claude CLI troubleshooting unrelated to PM self-check snapshot behavior.

## User Flow

### Happy Path
1. Operator runs `/pm self-check` or the helper self-check command.
2. Self-check validates Claude registration, executability, and session usability.
3. If legacy `droid-worker` is present, self-check or setup guidance identifies it as obsolete cleanup rather than a supported runtime dependency.
4. Claude snapshot capture runs with a bounded Claude-side MCP timeout and a sufficient helper-side timeout budget.
5. `claude mcp list` completes and writes artifact evidence, even if some unrelated Claude servers report failed or unauthenticated.
6. Self-check exits `clean` when health checks, snapshot capture, and child plan gate all succeed.

### Failure Paths
1. Claude registration or executability is broken.
2. Self-check still exits `failed` with the current runtime-health contract.

3. Claude session probe is unusable.
4. Self-check still exits `failed`.

5. Claude snapshot capture exceeds the new bounded budget or exits nonzero.
6. Self-check exits `issues_detected` with artifact evidence and healer-ready output.

7. Legacy `droid-worker` is present in user config.
8. The repo treats it as obsolete cleanup and does not present it as an active supported dependency.

9. A user-level Claude server remains failed or unauthenticated but `claude mcp list` completes.
10. The artifact output records the server status without hanging the PM self-check.

## Acceptance Criteria
1. In the current Codex runtime, the PM self-check no longer reports `snapshot_command_hung` for Claude snapshot capture when Claude session usability is healthy and `claude mcp list` can complete under the bounded timeout policy.
2. Claude snapshot capture uses an explicit bounded Claude-side MCP startup timeout rather than inheriting only the default Claude CLI timeout behavior.
3. Claude snapshot capture uses a helper-side outer timeout budget that is large enough to allow bounded `claude mcp list` completion in the current environment.
4. Snapshot attempt evidence records the applied timeout policy so artifact bundles explain why a command did or did not finish.
5. Supported repo docs and remediation paths no longer treat `droid-worker` as an active Claude MCP dependency.
6. If legacy `droid-worker` is still present in a user config, the repo surfaces it as obsolete cleanup guidance rather than as a supported runtime requirement.
7. Snapshot artifact output still includes failed or unauthenticated Claude-side servers instead of suppressing them.
8. Runtime-health failures still end `failed`; the change must not weaken the existing health contract.
7. Automated regression coverage fails without the new bounded-timeout behavior and passes with it.
8. Manual smoke evidence demonstrates a clean self-check in the current Codex runtime after the fix.

### Smoke Test Plan
- Happy path:
  - Run the helper self-check in the current Codex runtime and verify `status=clean`.
  - Verify the Claude snapshot artifact completes and includes explicit server statuses.
  - Verify legacy `droid-worker` cleanup/remediation is documented or surfaced correctly.
- Unhappy path:
  - Force a Claude snapshot timeout path and verify `issues_detected`.
  - Verify runtime-health failure still ends `failed`.
- Regression:
  - Verify a hanging Claude-side server no longer causes the happy-path self-check to end `issues_detected`.
  - Verify legacy `droid-worker` is no longer described as supported.
  - Verify bounded timeout metadata is present in the attempt artifact.
  - Verify Codex snapshot behavior is unchanged.

## Success Metrics
- 0 reproducible `snapshot_command_hung` results for the current Codex runtime happy-path self-check after the fix.
- 100% of successful Claude snapshot attempts record the applied timeout policy in artifact evidence.
- 100% of regressions covering the hanging-server case pass.
- 0 active repo docs or remediation paths describe `droid-worker` as a supported dependency for current PM runtimes.

## BEADS

### Business
- Restores trust in PM self-check as a prerequisite for larger PM runs.

### Experience
- Operators get a clean self-check when Claude is actually usable for PM work.
- Unrelated Claude-side server failures remain visible without breaking the PM pipeline.
- Legacy `droid-worker` stops confusing the supported runtime story.

### Architecture
- Keep the current health/session contract.
- Harden only the artifact snapshot execution policy for Claude.
- Treat legacy `droid-worker` cleanup as separate from snapshot determinism.
- Treat Claude-side MCP timeout control and helper-side timeout control as separate layers.

### Data
- Extend snapshot attempt evidence with the applied Claude MCP timeout setting and any related execution policy fields needed for debugging.

### Security
- Do not expose secrets from Claude config or MCP headers in artifacts, tests, or docs.
- Artifact evidence should report timeout policy and command source without leaking credential-bearing config values.

## Rollout / Migration / Rollback
- Rollout:
  - update helper snapshot capture
  - remove or deprecate legacy `droid-worker` references in supported setup/remediation
  - extend tests
  - run live smoke in current Codex runtime
- Migration:
  - no user migration required
- Rollback:
  - revert to the current snapshot policy if the bounded-timeout strategy causes false clean results or hides real runtime failures

## Risks & Edge Cases
- Risk: a too-small bounded Claude timeout could truncate legitimately slow but healthy servers.
  - Mitigation: separate Claude-side timeout from helper-side outer timeout and choose values based on measured current behavior.
- Risk: a too-large helper timeout could reintroduce long hangs.
  - Mitigation: keep the outer timeout bounded and verified by regression tests.
- Risk: users may still carry stale `droid-worker` registrations even after docs stop referencing them.
  - Mitigation: add explicit obsolete-cleanup messaging when detected.
- Edge case: Claude CLI behavior changes in a future release.
  - Mitigation: keep the policy explicit in code and evidence so future regressions are diagnosable.
- Edge case: `claude mcp list` completes but returns unexpected formatting.
  - Mitigation: use exit behavior and artifact completion as the pass condition rather than brittle output parsing for the snapshot step.

## Open Questions
None.
