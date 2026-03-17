# PRD

## 1. Title, Date, Owner
- Title: Codex Subagent Wrapper Contract For Claude MCP
- Date: 2026-03-17
- Owner: PM Orchestrator

## 2. Problem
The orchestrator needs a clear answer to two related questions:
- whether it already uses Codex subagents in the sense described by OpenAI's Codex subagent documentation
- whether a general Codex-side wrapper subagent should be introduced for Claude MCP roles

Today the repo mixes multiple execution models across active files. Some documents describe Claude Code Task-tool agents and named workflow agents, while the current PM skill and routing matrix describe a generic Codex launcher contract with Claude treated as an external MCP runtime. Without a single canonical contract, future changes risk introducing a split control plane where role behavior is partly owned by repo prompts and partly hidden inside runtime-specific agent definitions.

There is also a concrete path-contract inconsistency: some workflow docs and commands expect the PM helper at `./.codex/skills/pm/scripts/pm-command.sh`, while this source repository currently exposes the live helper at `./skills/pm/scripts/pm-command.sh`. That mismatch makes it unclear which path is canonical in the source repo versus injected target repos.

## 3. Context / Current State
- Official Codex documentation confirms that Codex supports native subagent orchestration and custom project-scoped agents defined under `.codex/agents/*.toml` or `~/.codex/agents/*.toml`.
- Official Codex documentation also confirms that custom agents can override `model`, `model_reasoning_effort`, `sandbox_mode`, and `mcp_servers`, and that approval/runtime failures surface back to the parent workflow.
- This repository does not currently define any project-level Codex custom agents. There is no `.codex/agents/` directory in the repo.
- The current PM skill contract says PM must launch only generic agent types: `default`, `explorer`, and `worker`, and must encode role identity in the prompt payload.
- The current routing matrix defines `codex-native` as `spawn_agent` with generic types only, and defines `claude-code-mcp` as an external runtime rather than a launcher type.
- The PM skill and workflow explicitly reject `mcp__claude-code__Agent` / implicit `general-purpose` launching as the PM contract.
- `instructions/pm_workflow.md` still describes `Task(...)`-style orchestration and named workflow pseudo-agents such as `pm-research`, `pm-docs`, and `pm-team-lead`, which conflicts with the generic-launcher contract in `skills/pm/SKILL.md`.
- `CLAUDE.md` still describes a Claude Code Task-tool architecture with `default`, `Explore`, and `Plan` subagent types and `gpt-5.3-codex` references, which conflicts with the current Codex-native `gpt-5.4` + `xhigh` routing matrix.
- Live runtime evidence for this planning session:
  - `codex mcp list` reports `claude-code` as enabled.
  - `claude --version` succeeds in the PM runtime.
  - `~/.codex/config.toml` already pins Codex-native execution to `gpt-5.4` and `xhigh`.
- This means the older March 16 diagnosis that Claude was broken specifically because `claude` was missing from PATH is at least partially stale in the current environment.

Selected framing from discovery:
1. The repo already uses Codex-native subagents for roles mapped to `codex-native`.
2. It does not currently use Codex custom named agents as its public orchestration interface.
3. A general Codex wrapper subagent for Claude MCP is technically plausible, but only as an internal abstraction, not as a new public API contract.

## 4. User / Persona
- PM workflow maintainers.
- Engineers running `/pm` plans in Codex workspaces.
- Operators who need deterministic behavior across Codex-native and Claude-routed executions.

## 5. Goals
- Record the verified current state of subagent usage in this repository.
- Keep the public orchestrator contract generic and orchestrator-owned:
  - generic launcher types only
  - explicit role labels in prompt/context
  - explicit task/runtime context passed at invocation time
- Define the allowed shape of a reusable Codex-side Claude wrapper agent:
  - internal implementation detail only
  - stable structured output and error reporting
  - no public dependence on named Claude launchers
- Align active docs and workflow files to one execution model.
- Resolve the PM helper path inconsistency so source-repo and installed-repo expectations are explicit and testable.
- Preserve explicit Claude MCP failure handling, including context-pack validation and no silent fallback inside Claude-dependent modes.

## 6. Non-Goals
- Replacing the public PM contract with project-defined custom named agents.
- Treating a Codex wrapper agent as officially guaranteed to be a perfect API-equivalent substitute for all built-in agents.
- Directly orchestrating PM phases through Claude CLI or `mcp__claude-code__Agent` / implicit `general-purpose`.
- Broad redesign of the PM workflow unrelated to subagent/Claude contract cleanup.

## 7. Scope (In/Out)
### In Scope
- Document the difference between:
  - Codex-native generic subagents already used by the repo
  - Codex custom named agents supported by official docs
  - Claude MCP as an external runtime behind the orchestrator contract
- Specify whether a reusable Claude wrapper agent is allowed and where the abstraction boundary lives.
- Normalize the contract for Claude-routed roles:
  - context-pack validation
  - explicit failure reporting
  - explicit remediation
  - no hidden launcher assumptions
- Update conflicting docs so the repo no longer advertises incompatible execution models.
- Standardize or explicitly document helper script path expectations for:
  - this source repository
  - injected/installed target repositories
- Add smoke coverage for wrapper success, wrapper failure, and routing conformance.

### Out of Scope
- Making Codex custom agents mandatory for all PM roles.
- Changing the selected lead-model profile semantics beyond what current routing already defines.
- Replacing the role-labeled prompt contract with runtime-specific hidden instructions.
- Building a new named-agent registry as a public dependency.

## 8. User Flow
### Happy Path
1. User runs `/pm plan: ...`.
2. PM runs the lead-model gate and resolves the active routing profile.
3. For `codex-native` roles, PM spawns only generic Codex subagents (`default`, `explorer`, `worker`) with explicit role labels and task context.
4. For Claude-routed roles, PM keeps the same outer contract and either:
   - invokes the documented Claude MCP path directly under the current generic-role contract, or
   - if implemented, spawns one internal Codex wrapper agent that owns Claude invocation, context validation, and normalized result formatting.
5. If Claude succeeds, the parent PM workflow receives structured results without depending on Claude-specific launcher names.

### Failure Paths
1. A Claude-routed role is selected, but the Claude runtime is unavailable or reports an unsupported launcher error.
2. PM blocks the phase, reports the reason explicitly, and follows the configured remediation path for the active lead-model profile.
3. A wrapper agent is present but hides too much behavior or bypasses prompt/context requirements.
4. That implementation is rejected as non-conformant because it creates a split control plane.
5. Docs continue to describe incompatible launch semantics.
6. Contributors implement against the wrong model and introduce regressions in routing or fallback behavior.

## 9. Acceptance Criteria
1. Repository docs explicitly state that current PM orchestration uses generic agent types `default`, `explorer`, and `worker` as the public launcher contract.
2. Repository docs explicitly state that this repo does not currently depend on `.codex/agents/*.toml` custom agents as the public PM interface.
3. Repository docs explicitly distinguish Codex-native subagents from Codex custom named agents.
4. Repository docs explicitly state that Claude remains an external MCP runtime, not a launcher type.
5. If a reusable Claude wrapper agent is introduced, docs state that it is an internal implementation detail behind the existing generic contract.
6. No active workflow file requires public dependence on named workflow agents such as `pm-research`, `pm-docs`, or `pm-team-lead`.
7. No active workflow file describes Claude Code Task-tool subagent types as the canonical runtime when the current routing matrix says otherwise.
8. Claude-routed role execution continues to require:
   - explicit context-pack validation
   - explicit error reporting
   - explicit remediation
9. No active PM contract allows `mcp__claude-code__Agent` / implicit `general-purpose` launching as the supported orchestration path.
10. Documentation reflects current live runtime evidence instead of stale PATH-only failure assumptions.
11. Active docs and helper references clearly distinguish:
   - source-repo helper path
   - injected target-repo helper path
   - any path rewriting performed by installer/injector workflows
12. No active command examples point to a helper path that is invalid for the context in which it is documented.
13. A smoke-test plan exists for happy path, unhappy path, and regression around wrapper routing and runtime failure behavior.
14. `Open Questions` remains empty before any implementation handoff.

### Smoke Test Plan
- Happy path:
  - Verify `/pm plan: ...` resolves the correct lead-model profile and routing matrix.
  - Verify generic agent spawning remains the only public orchestrator contract.
  - Verify a Claude wrapper, if present, is spawned and controlled by Codex while keeping a uniform outer role contract.
  - Verify successful Claude-routed execution returns structured output plus runtime/session metadata sufficient for debugging.
  - Verify helper-path command examples are valid in both the source repo and an injected target repo.
- Unhappy path:
  - Verify `codex-main` blocks before Discovery when Claude is unavailable and offers only the documented fallback path.
  - Verify `claude-main` blocks before Discovery when Claude is unavailable.
  - Verify unsupported-launcher failures such as `Agent type 'general-purpose' not found` are surfaced explicitly and do not silently reroute.
  - Verify incomplete context produces validation failure or `CONTEXT_REQUEST|...` and same-session continuation.
  - Verify source-repo docs do not instruct users to run a target-repo-only helper path that does not exist locally.
- Regression:
  - Verify `full-codex` remains operable without Claude.
  - Verify doc updates do not reintroduce Task-tool/named-agent language that conflicts with the routing matrix.
  - Verify role labels, prompt prefixes, and context-pack validation remain part of the public contract.

## 10. Success Metrics
- 0 active workflow files describe conflicting public launcher contracts.
- 100% of active PM docs align on generic public launchers plus external Claude MCP.
- 100% of Claude-routed role docs preserve explicit validation/error/remediation behavior.
- 0 public PM interfaces depend on project-defined named custom agents.
- 0 stale docs claim Claude PATH failure as the current diagnosed blocker when runtime evidence shows otherwise.
- 0 active docs contain helper-path examples that are invalid for their documented context.

## 11. BEADS
### Business
- Reduces workflow breakage caused by contributors implementing against the wrong orchestration contract.

### Experience
- Maintainers can reason about PM behavior from repo-owned docs instead of hidden runtime assumptions.

### Architecture
- Keep the public control plane generic and role-driven.
- Allow a reusable Claude wrapper only as an internal adapter layer.
- Preserve explicit separation between Codex-native spawning and Claude MCP execution.

### Data
- Preserve inspectable context-pack inputs and structured failure/success outputs for Claude-routed work.

### Security
- Avoid hidden runtime-specific behavior becoming a required public dependency for PM workflow execution.

## 12. Rollout / Migration / Rollback
- Rollout:
  - align workflow docs and references to one contract
  - optionally implement an internal Claude wrapper only after contract alignment
- Migration:
  - remove or rewrite stale references to named workflow agents and Claude Task-tool-first architecture
  - normalize helper-path references or document the source-vs-installed distinction explicitly
  - keep the outer PM interface unchanged for users
- Rollback:
  - revert documentation and wrapper changes
  - continue using the explicit orchestrator-owned contract only

## 13. Risks & Edge Cases
- Risk: contributors interpret official Codex custom-agent support as a requirement to expose named agents publicly, which would conflict with current PM policy.
- Risk: an internal Claude wrapper grows hidden behavior and recreates the split-control-plane problem this plan is trying to prevent.
- Risk: stale docs in `CLAUDE.md` and `instructions/pm_workflow.md` continue to compete with the routing matrix and recent PM skill contract.
- Risk: if helper-path normalization is ambiguous, future contributors may fix docs in one repo context while breaking the installed target-repo contract.
- Risk: runtime evidence changes again, so availability assumptions must be validated from the actual PM environment rather than copied forward from older PRDs.
- Edge case: Codex custom agents may be able to emulate a stable parent-facing output contract, but official docs do not guarantee full lifecycle/API equivalence with built-in agents in every runtime.

## 14. Open Questions
None.

## 15. Alternatives Considered
### Option A: Make Codex custom agents the new public PM contract
- Pros:
  - Cleaner Codex-native ergonomics in Codex-only environments.
  - Less repeated prompt text per invocation.
- Cons:
  - Conflicts with current PM policy.
  - Weakens portability and debugging.
  - Would require broad contract and doc changes.
- Status: Rejected.

### Option B: Keep the generic public contract and do not add a wrapper
- Pros:
  - Best portability.
  - Lowest abstraction risk.
- Cons:
  - More duplication in Claude-routed execution logic.
- Status: Acceptable fallback.

### Option C: Keep the generic public contract and add one internal Codex wrapper for Claude MCP
- Pros:
  - Centralizes Claude invocation, validation, and error normalization.
  - Preserves the current public interface.
- Cons:
  - Adds abstraction that must stay transparent.
  - Requires strong conformance tests to avoid contract drift.
- Status: Selected direction if implementation proceeds.
