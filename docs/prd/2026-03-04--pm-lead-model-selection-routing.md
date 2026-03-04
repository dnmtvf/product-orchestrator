# PRD

## 1. Title, Date, Owner
- Title: PM Lead Model Selection And Role Routing
- Date: 2026-03-04
- Owner: PM Orchestrator

## 2. Problem
The PM orchestrator currently runs with a mostly static Codex-first routing policy and does not provide a runtime lead-model selector at workflow start. Users need per-run lead-model choice for all planning flows, with deterministic routing outcomes and explicit failure behavior when Claude MCP is unavailable.

## 3. Context / Current State
- `/pm plan:` and `/pm plan big feature:` are both supported entry routes.
- Role routing is documented in `skills/pm/agents/model-routing.yaml` and workflow docs, but lead-model selection is not a first-class startup gate.
- Two orchestration handoff roles are used in PM flow text (`PM Beads Plan Handoff`, `PM Implement Handoff`) but are not fully represented in role routing config.
- Existing constraints require Codex-first orchestration with optional Claude via `claude-code` MCP.

## 4. User / Persona
- PM workflow operators using Codex ecosystem who need controlled model routing behavior across orchestrator roles.

## 5. Goals
- Add a mandatory lead-model selection prompt at the start of all PM planning flows.
- Support exactly two lead-model options:
  - `GPT-5.3-Codex XHigh`
  - `Claude Opus 4.6 Thinking`
- Ensure selected main model controls main roles and handoff roles:
  - `project_manager`
  - `team_lead`
  - `pm_beads_plan_handoff`
  - `pm_implement_handoff`
- Persist selected lead model across sessions.
- Fail fast with blocked state when Claude-first is selected but `claude-code` MCP is unavailable.

## 6. Non-Goals
- Introducing additional lead-model options beyond the two listed.
- Replacing Beads flow, PRD gates, or PM phase order.
- Rewriting all role prompts beyond required routing behavior.

## 7. Scope (In/Out)
### In Scope
- Entry-gate prompt for lead-model selection across all PM planning routes.
- Routing policy updates for Codex-first and Claude-first workflows.
- Explicit role coverage including handoff roles and task verification role documentation.
- Persistence mechanism for lead-model selection across sessions.
- Deterministic fail-fast path for missing Claude MCP dependency.
- Documentation and smoke-test updates.

### Out of Scope
- New model providers.
- UI-level model picker outside PM orchestration entry flow.
- Changes to unrelated skill families.

## 8. User Flow
### Happy Path
1. User invokes `$pm plan:` or `$pm plan big feature:`.
2. Orchestrator asks for lead model with exactly two options.
3. User selects one option.
4. Selection is stored in persistent PM state.
5. Orchestrator applies routing map based on selected workflow profile.
6. Workflow continues in strict PM phase order.

### Failure Paths
1. User selects `Claude Opus 4.6 Thinking`, but `claude-code` MCP is not available.
2. Orchestrator stops immediately with blocked status and explicit remediation (`codex mcp add claude-code -- claude mcp serve`).
3. No downstream PM phase is started until dependency is satisfied.

## 9. Acceptance Criteria (testable)
1. On every `/pm plan:` and `/pm plan big feature:` invocation, lead-model selection is prompted before Discovery actions begin.
2. Selection options are exactly `GPT-5.3-Codex XHigh` and `Claude Opus 4.6 Thinking`.
3. Selected value persists across sessions and is reused by default until changed.
4. `pm_beads_plan_handoff` and `pm_implement_handoff` follow selected main model/runtime.
5. Codex-first workflow role routing matches below matrix:
   - `project_manager`: Main, `codex-native`, `gpt-5.3-codex`
   - `team_lead`: Main, `codex-native`, `gpt-5.3-codex`
   - `pm_beads_plan_handoff`: Main, `codex-native`, `gpt-5.3-codex`
   - `pm_implement_handoff`: Main, `codex-native`, `gpt-5.3-codex`
   - `senior_engineer`: Sub, `claude-code-mcp`, not pinned
   - `librarian`: Sub, `claude-code-mcp`, not pinned
   - `smoke_test_planner`: Sub, `claude-code-mcp`, not pinned
   - `alternative_pm`: Sub, `claude-code-mcp`, not pinned
   - `researcher`: Sub, `claude-code-mcp`, not pinned
   - `backend_engineer`: Sub, `codex-native`, `gpt-5.3-codex`
   - `frontend_engineer`: Sub, `codex-native`, `gpt-5.3-codex`
   - `security_engineer`: Sub, `codex-native`, `gpt-5.3-codex`
   - `agents_compliance_reviewer`: Sub, `codex-native`, `gpt-5.3-codex`
   - `jazz_reviewer`: Sub, `claude-code-mcp`, not pinned
   - `codex_reviewer`: Sub, `codex-native`, `gpt-5.3-codex`
   - `manual_qa`: Sub, `codex-native`, `gpt-5.3-codex`
   - `task_verification`: Sub, `codex-native` default policy (not explicitly pinned)
6. Claude-first workflow role routing matches below matrix:
   - `project_manager`: Main, `claude-code-mcp`, not pinned
   - `team_lead`: Main, `claude-code-mcp`, not pinned
   - `pm_beads_plan_handoff`: Main, `claude-code-mcp`, not pinned
   - `pm_implement_handoff`: Main, `claude-code-mcp`, not pinned
   - `senior_engineer`: Sub, `codex-native`, `gpt-5.3-codex`
   - `librarian`: Sub, `claude-code-mcp`, not pinned
   - `smoke_test_planner`: Sub, `codex-native`, `gpt-5.3-codex`
   - `alternative_pm`: Sub, `codex-native`, `gpt-5.3-codex`
   - `researcher`: Sub, `claude-code-mcp`, not pinned
   - `backend_engineer`: Sub, `claude-code-mcp`, not pinned
   - `frontend_engineer`: Sub, `claude-code-mcp`, not pinned
   - `security_engineer`: Sub, `claude-code-mcp`, not pinned
   - `agents_compliance_reviewer`: Sub, `claude-code-mcp`, not pinned
   - `jazz_reviewer`: Sub, `codex-native`, `gpt-5.3-codex`
   - `codex_reviewer`: Sub, `claude-code-mcp`, not pinned
   - `manual_qa`: Sub, `claude-code-mcp`, not pinned
   - `task_verification`: Sub, `claude-code-mcp`, not pinned
7. If Claude-first is selected and `claude-code` MCP is unavailable, orchestrator returns blocked state and does not continue.

## 10. Success Metrics (measurable)
- 100% of PM planning invocations show lead-model selection gate.
- 0 cases where workflow continues after Claude-first selection without MCP availability.
- 100% role-routing matrix conformance in smoke tests for both workflow profiles.

## 11. BEADS
### Business
- Improves operator control of orchestration quality/speed profile.

### Experience
- Clear startup choice with deterministic routing outcomes.

### Architecture
- Introduce explicit lead-model profile state and role-to-runtime mapping by profile.
- Keep routing source of truth in PM skill docs/config with test coverage.

### Data
- Persist selected lead-model profile in PM state across sessions.

### Security
- No new external secrets.
- Fail-fast gating prevents silent fallback to unintended runtime.

## 12. Rollout / Migration / Rollback
- Rollout: land behind PM orchestration entry logic for both planning routes.
- Migration: initialize persistent selection from current Codex-first default for existing users.
- Rollback: remove selection gate and revert static routing docs/config to prior codex-first map.

## 13. Risks & Edge Cases
- Risk: Divergence between docs and executable routing behavior.
  - Mitigation: add smoke tests for both profiles and key roles.
- Risk: stale persisted selection causing confusion.
  - Mitigation: echo active profile at flow start and allow override prompt.
- Edge case: partial MCP setup or runtime outage.
  - Mitigation: strict preflight and blocked state with explicit remediation.

## 14. Open Questions
