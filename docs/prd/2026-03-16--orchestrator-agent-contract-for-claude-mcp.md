# PRD

## 1. Title, Date, Owner
- Title: Preserve Orchestrator-Owned Agent Contract For Claude/MCP Routing
- Date: 2026-03-16
- Owner: PM Orchestrator

## 2. Problem
The orchestrator needs a clear canonical contract for agent execution when Claude is involved. The decision point is whether to make Claude-defined reusable agents the primary interface, or keep agent role, instructions, and runtime context owned by the orchestrator and passed explicitly over the launcher/MCP path.

Without a clear decision, the repo risks drifting into a split control plane where some behavior is defined in repo-owned prompts/contracts and other behavior is hidden inside runtime-specific Claude agent definitions. That would weaken portability, fallback behavior, and debugging.

There are also two concrete runtime issues to fix as part of that decision:
- Codex-native spawned agents should be explicitly standardized on `gpt-5.4` with `xhigh` reasoning for this orchestrator.
- The current `claude-code` MCP configuration is registered but not executable in the PM runtime because it launches `claude mcp serve` by bare command name while the Codex non-interactive login environment does not include `~/.local/bin` in `PATH`.
- The lead-model gate is currently only two-option and profile-based, but the orchestrator needs three explicit orchestration modes with distinct availability behavior.

## 3. Context / Current State
- The current PM workflow explicitly supports only generic launcher types: `default`, `explorer`, and `worker`.
- The current PM workflow explicitly requires role to be encoded in prompt payload, for example `[Role: Researcher Agent]`.
- Claude is treated as an external runtime reached through `claude-code` MCP, not as a launcher type or named-agent contract.
- The current lead-model gate exposes only two options, effectively `codex-first` and `claude-first`.
- The helper and docs repeatedly state that `codex mcp list` proves `claude-code` is configured, but does not prove the current runtime exposes a usable Claude launcher.
- When Claude is unavailable or unusable, roles mapped to `claude-code-mcp` must fall back to `codex-native` with explicit warning and remediation.
- External-Claude calls are already modeled as explicit context-pack exchanges with required fields and a `CONTEXT_REQUEST|...` missing-context handshake.
- Current codex-native model resolution falls back to `~/.codex/config.toml`, which in this environment already resolves to `model = "gpt-5.4"` and `model_reasoning_effort = "xhigh"`, but that requirement is not yet expressed as an orchestrator-specific invariant.
- Local diagnosis of the Claude MCP failure found:
  - `codex mcp list` reports `claude-code` as enabled.
  - `claude` is not available on the non-interactive PM runtime `PATH`.
  - `~/.local/bin/claude --version` and `~/.local/bin/claude mcp serve --help` both work.
  - `~/.zshrc` adds `~/.local/bin` to `PATH`, but the non-interactive login shell used here does not load that path, so `command = "claude"` is not resolvable at runtime.

Required gate behavior after this change:
1. `Full Codex Orchestration`
- All PM/orchestrator roles run codex-native.
- No Claude MCP dependency for orchestration.
2. `Codex as Main Agent`
- Main orchestrator roles run codex-native.
- Claude-routed support roles remain Claude-routed.
- Immediately after the user selects this mode, PM must check Claude MCP availability.
- If Claude MCP is unavailable or unusable, PM must throw a blocking error and ask whether the user wants to fall back to `Full Codex Orchestration`.
3. `Claude as Main Orchestrator`
- Main orchestrator roles run through Claude MCP.
- Existing Claude availability checks apply before execution.

Alternatives considered:
1. Make Claude-defined reusable agents the primary orchestrator contract.
- Pros: less repeated prompt text, stronger Claude-native specialization, cleaner reuse in Claude-only environments.
- Cons: conflicts with the repo's generic-launcher portability rule and weakens runtime fallback.
2. Keep everything fully orchestrator-defined and pass all role + task context every run.
- Pros: strongest portability and determinism.
- Cons: more prompt duplication and larger runtime payloads.
3. Hybrid: keep the orchestrator-owned role/context contract as the public interface, while allowing Claude-native reusable agents only as an internal backend optimization where runtime support is verified.
- Selected for this plan because it preserves portability and fallback while still allowing future Claude-native reuse behind the abstraction.

## 4. User / Persona
- PM workflow maintainers.
- Engineers using `/pm` orchestration in this repository.
- Operators who need predictable behavior across Codex-native and Claude-routed runs.

## 5. Goals
- Keep the orchestrator-owned role/context contract as the canonical public interface for agent execution.
- Standardize all codex-native spawned orchestrator roles on `gpt-5.4` with `xhigh` reasoning.
- Replace the current two-option lead-model gate with three explicit orchestration modes.
- Preserve generic launcher compatibility and codex-native fallback behavior across sessions and runtimes.
- Make Claude usage explicit through prompt/session contracts and validated context packs.
- Make the `claude-code` MCP runtime executable in the actual PM environment, not merely registered in `codex mcp list`.
- Make `Codex as Main Agent` perform an immediate Claude MCP availability check after selection and offer fallback to `Full Codex Orchestration` when Claude is unavailable or unusable.
- Allow future Claude-native reusable agents only as an internal implementation detail behind the existing contract, not as a new top-level dependency.

## 6. Non-Goals
- Making named Claude agents the required public interface for PM workflow execution.
- Removing codex-native fallback for roles mapped to `claude-code-mcp`.
- Replacing the existing context-pack and missing-context handshake with implicit runtime-specific behavior.
- Implementing a Claude-only orchestrator that drops generic launcher compatibility.
- Leaving codex-native model selection undefined or environment-dependent for this orchestrator after the change.

## 7. Scope (In/Out)
### In Scope
- Clarify and preserve the canonical agent contract for PM orchestration:
  - generic launcher only
  - role encoded in prompt/context
  - explicit task/runtime context passed at invocation time
  - explicit fallback semantics
- Pin codex-native spawned orchestrator roles to `gpt-5.4` and `xhigh`.
- Replace the PM plan lead-model selector with three explicit options:
  - `Full Codex Orchestration`
  - `Codex as Main Agent`
  - `Claude as Main Orchestrator`
- Define routing semantics for each option and persist the selected orchestration mode across sessions.
- Require `Codex as Main Agent` to check Claude MCP immediately after selection and, on failure, block progression and ask the user whether to fall back to `Full Codex Orchestration`.
- Fix or harden the `claude-code` MCP launch contract so PM can actually execute Claude from the runtime it runs in.
- Document that Claude-defined reusable agents, if used later, are backend-specific optimizations behind the orchestrator contract.
- Validate the recommendation against current repo routing, prerequisites, and Claude context-pack behavior.
- Define smoke coverage for happy path, unhappy path, and regression around launcher availability, role propagation, and fallback.

### Out of Scope
- Building a new named-agent registry as a required dependency for this repo.
- Removing existing PM routing/profile logic.
- Reworking implementation/review roles beyond what is required to preserve the contract.
- Broad PM workflow redesign unrelated to agent-definition ownership.
- Changing the Claude-side model choice for `claude-code` roles beyond whatever the Claude runtime already configures.

## 8. User Flow
### Happy Path
1. User starts `/pm plan: ...` and selects or reuses one persisted orchestration mode:
   - `Full Codex Orchestration`
   - `Codex as Main Agent`
   - `Claude as Main Orchestrator`
2. PM launches only generic agent types and passes explicit role labels in prompt payloads.
3. Any codex-native spawned role uses `gpt-5.4` with `xhigh`.
4. Mode semantics apply:
   - `Full Codex Orchestration`: PM routes all orchestrator roles codex-native.
   - `Codex as Main Agent`: PM routes main roles codex-native and Claude support roles through Claude MCP.
   - `Claude as Main Orchestrator`: PM routes main orchestrator roles through Claude MCP.
5. If a role is mapped to `claude-code-mcp`, PM validates the required context-pack and invokes Claude through the explicit MCP contract.
6. Claude responds without requesting missing context, and PM continues normally.
7. If a future Claude-native reusable agent is used internally, it is addressed behind the same outer role/context contract and remains invisible to the public PM interface.

### Failure Paths
1. User selects `Codex as Main Agent`, but `claude-code` is unavailable or unusable.
2. PM immediately checks Claude MCP availability, throws an explicit blocking error, and asks whether the user wants to fall back to `Full Codex Orchestration`.
3. If the user declines fallback, PM stops before Discovery.

4. User selects `Claude as Main Orchestrator`, but `claude-code` is unavailable or unusable.
5. PM fails before Discovery with an explicit reason and remediation because the selected main orchestrator runtime is not executable.

6. User selects `Full Codex Orchestration`.
7. PM must not require Claude MCP for any orchestrator role in that run.

8. `claude-code` is installed only under `~/.local/bin`, but the PM runtime `PATH` does not include that directory.
9. Bare-command launch of `claude mcp serve` fails even though the binary exists.
10. PM must treat that as a configuration/runtime defect and require either an executable absolute path or environment parity fix before considering Claude available.

11. Required context-pack fields are missing.
12. Validation fails or Claude returns `CONTEXT_REQUEST|...`.
13. PM gathers the missing fields and continues in the same session.

14. A change introduces dependence on named Claude launcher types or `mcp__claude-code__Agent` / implicit `general-purpose`.
15. PM treats that path as non-conformant and rejects it for orchestrator use.

## 9. Acceptance Criteria (testable)
1. PM orchestration continues to assume only generic launcher types: `default`, `explorer`, and `worker`.
2. `/pm plan` presents exactly three orchestration-mode options:
   - `Full Codex Orchestration`
   - `Codex as Main Agent`
   - `Claude as Main Orchestrator`
3. The selected orchestration mode persists across sessions until explicitly changed.
4. All codex-native spawned orchestrator roles run with `model = gpt-5.4` and `reasoning_effort = xhigh`.
5. `Full Codex Orchestration` runs without requiring Claude MCP for any orchestrator role in that plan run.
6. `Codex as Main Agent` keeps main orchestrator roles codex-native but requires Claude MCP availability for Claude-routed support roles.
7. Immediately after the user selects `Codex as Main Agent`, PM checks Claude MCP availability before Discovery starts.
8. If that immediate check fails, PM throws an explicit blocking error, provides remediation, and asks whether the user wants to fall back to `Full Codex Orchestration`.
9. If the user accepts fallback, PM switches to `Full Codex Orchestration` and continues; if the user declines fallback, PM stops before Discovery.
10. `Claude as Main Orchestrator` routes main orchestrator roles through Claude MCP; if Claude MCP is unavailable or unusable, PM fails before Discovery with explicit remediation.
11. Role identity remains explicit in prompt/context payloads and is not implied by launcher type or Claude-side named-agent existence.
12. Roles mapped to `claude-code-mcp` continue to use explicit prompt/session contracts and context-pack validation before invocation.
13. The `claude-code` MCP runtime is considered available only when the PM runtime can actually execute the configured Claude command, not merely when `codex mcp list` shows the server as enabled.
14. The `claude-code` launch path is hardened so the PM runtime can successfully resolve the configured command in a non-interactive session, for example by using an absolute executable path or an environment-level `PATH` fix that applies to Codex runtime launches.
15. No PM phase requires custom named Claude launcher types or direct `mcp__claude-code__Agent` / implicit `general-purpose` launching.
16. Any future Claude-native reusable-agent support is implemented only behind the existing orchestrator-owned role/context contract.
17. PRD and supporting docs clearly distinguish:
   - stable specialization that may live in backend-specific Claude subagents
   - task-specific context that must still be sent explicitly at runtime

### Smoke Test Plan
- Happy path:
  - Verify `/pm plan: ...` presents the three required orchestration-mode options.
  - Verify `Full Codex Orchestration` completes Discovery without needing Claude MCP.
  - Verify `Codex as Main Agent` routes main roles to codex-native and Claude support roles to Claude MCP.
  - Verify `Claude as Main Orchestrator` routes main roles through Claude MCP.
  - Verify `/pm plan: ...` launches only generic agent types.
  - Verify codex-native spawned roles resolve to `gpt-5.4` and `xhigh`.
  - Verify role labels such as `[Role: Researcher Agent]` appear in prompts.
  - Verify Claude-routed steps use explicit `use agent swarm for ...` prompt prefixes and valid context-pack checks.
  - Verify the configured Claude command is executable from the same non-interactive runtime environment PM uses.
- Unhappy path:
  - Select `Codex as Main Agent` with Claude unavailable.
  - Verify PM immediately checks Claude availability after selection.
  - Verify PM throws a blocking error and asks whether to fall back to `Full Codex Orchestration`.
  - Verify accepting fallback switches to `Full Codex Orchestration` and allows Discovery to proceed.
  - Verify declining fallback stops before Discovery.
  - Select `Claude as Main Orchestrator` with Claude unavailable.
  - Verify PM fails before Discovery with a clear error instead of falling back.
  - Simulate `claude` missing from runtime `PATH` while the binary still exists elsewhere on disk.
  - Verify PM reports runtime launch-path failure rather than treating `codex mcp list` as sufficient proof of availability.
  - Verify incomplete context produces `CONTEXT_REQUEST|...` and same-session continuation.
- Regression:
  - Verify `Full Codex Orchestration` remains usable even when Claude MCP is missing.
  - Verify no session depends on locally pre-created Claude-only named agents.
  - Verify restored Claude availability resumes mapped routing for the Claude-dependent modes without changing the outer role contract.

## 10. Success Metrics (measurable)
- 0 PM phases require custom named launcher types.
- 100% of `/pm plan` runs present the three required orchestration-mode options.
- 100% of codex-native spawned orchestrator roles resolve to `gpt-5.4` and `xhigh`.
- 100% of Claude-routed steps use explicit context-pack validation before invocation.
- 100% of `Codex as Main Agent` selections perform an immediate Claude MCP availability check before Discovery.
- 100% of failed `Codex as Main Agent` selections present an explicit fallback offer to `Full Codex Orchestration`.
- 100% of `Claude as Main Orchestrator` runs fail before Discovery when Claude MCP is unavailable or unusable.
- 100% of `Full Codex Orchestration` runs remain operable when Claude MCP is unavailable.
- 0 false-positive Claude availability states where `codex mcp list` reports enabled but the configured Claude command is not executable from the PM runtime.
- 0 regressions in cross-session behavior caused by dependence on local Claude-only agent definitions.

## 11. BEADS
### Business
- Keeps orchestration behavior predictable across environments and reduces breakage from runtime-specific agent assumptions.

### Experience
- PM maintainers and operators can reason about agent behavior from repo-owned contracts instead of hidden runtime configuration.

### Architecture
- Preserve generic launcher abstraction and explicit role/context contracts as the control plane.
- Pin codex-native spawned roles to one orchestrator-standard model/reasoning pair: `gpt-5.4` + `xhigh`.
- Replace the current two-profile lead-model gate with a three-mode orchestration selector that has explicit fail-fast semantics for Claude-dependent modes.
- Treat Claude-native reusable agents, if introduced, as private backend mappings behind that control plane.
- Separate MCP registration health from actual Claude command executability in the PM runtime.

### Data
- Maintain explicit context-pack fields and missing-context handshake so runtime inputs remain inspectable and reproducible.

### Security
- Avoid hidden runtime-specific behavior becoming a required dependency for workflow execution.
- Preserve explicit fallback and validation behavior for safer degraded operation.

## 12. Rollout / Migration / Rollback
- Rollout: keep the current orchestrator-owned contract as canonical and align docs/PRDs with that decision.
- Migration:
  - replace the current two-option lead-model selector with the three explicit orchestration modes
  - pin codex-native spawned roles to `gpt-5.4` + `xhigh`
  - harden the `claude-code` MCP launch path so the PM runtime can execute it
  - if Claude-native reusable agents are added later, map them internally behind existing role/context contracts and parity-check behavior before enablement
- Rollback: disable any internal Claude-native agent mapping and continue using the explicit orchestrator-owned prompt/context contract only.

## 13. Risks & Edge Cases
- Risk: future contributors may treat Anthropic's Claude-native subagent model as the public contract and accidentally bypass this repo's generic-launcher/fallback rules.
- Risk: behavior drift if Claude-native reusable agents are introduced internally without parity testing against repo-owned role prompts.
- Risk: the difference between `Full Codex Orchestration` and `Codex as Main Agent` can be implemented incorrectly unless role-routing boundaries are made explicit in docs and tests.
- Risk: path/documentation inconsistencies can obscure the real contract. During this planning run, the documented helper path `./.codex/skills/pm/scripts/pm-command.sh` did not exist in the repo root, while the live helper was present at `./skills/pm/scripts/pm-command.sh`.
- Risk: Claude appears healthy in configuration output but remains unusable because command executability depends on the non-interactive runtime environment, not the user's interactive shell setup.
- Edge case: Claude is configured and healthy in `codex mcp list`, but the current runtime still exposes no supported Claude launcher. The workflow must continue to treat that as runtime unavailability and fall back cleanly.

## 14. Open Questions
None.
