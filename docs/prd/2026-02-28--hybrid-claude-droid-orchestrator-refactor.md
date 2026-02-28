# PRD

## 1. Title, Date, Owner
- Title: Hybrid Claude + Droid Orchestrator Refactor
- Date: 2026-02-28
- Owner: philadelphia

## 2. Problem
The current PM orchestrator is built for Codex as the runtime. It uses Claude through MCP as an optional external agent. The user wants to switch to a hybrid architecture where:
- Claude Opus 4.6 serves as the main orchestrator and lead roles (PM, Team Lead, Reviewer, Researcher)
- Droid CLI with MiniMax-M2.5 model serves as the worker runtime for implementation tasks
- Droid should be exposed as an MCP server for integration with Claude Code/Conductor

## 3. Context / Current State
Currently:
- Orchestrator uses Codex (`codex mcp add`, `.codex/` paths)
- Agent configs in `skills/pm/agents/openai.yaml` specify OpenAI models
- Claude is accessed via `claude-code` MCP server as optional external agent
- No Droid integration exists
- All subagents run on the same model (OpenAI or Claude via MCP)

Desired state:
- Orchestrator runs on Claude Code (not Codex)
- Lead roles use Claude Opus 4.6
- Worker roles use Droid CLI with MiniMax-M2.5
- Droid exposed as MCP server for task execution

## 4. User / Persona
- Developer using Conductor.build with Claude Code CLI
- Wants cost-effective parallel implementation via MiniMax-M2.5 workers
- Needs Opus 4.6 for high-quality orchestration and review

## 5. Goals
- Replace all Codex references with Claude Code conventions
- Create Droid MCP server wrapper for worker task execution
- Configure agent roles with correct model assignments (Opus vs Droid+M2.5)
- Update skill definitions to use Claude Code syntax
- Enable worktree-isolated worker execution via Conductor

## 6. Non-Goals
- Change the PM workflow phases or approval gates
- Modify Beads integration
- Add new workflow features beyond model/agent routing
- Migrate existing PRDs or beads data

## 7. Scope (In/ Scope)
### In Scope
- Update `skills/pm/SKILL.md` to replace Codex references with Claude Code
- Update all `agents/openai.yaml` files to use Opus 4.6 or Droid+M2.5
- Create Droid MCP server wrapper script (headless exec mode)
- Update `skills/pm/references/` role prompts to reflect model assignments
- Update `.codex/` directory references to `.claude/` or remove
- Update README.md and SETUP.md for new runtime

### Out of Scope
- Modifying PM workflow logic
- Adding new features to orchestrator
- Converting existing PRDs or beads
- Changing the approval gate mechanics

## 8. User Flow
### Happy Path
1. User invokes `/pm plan: refactor orchestrator for Claude + Droid`
2. PM creates PRD → User approves
3. Beads plan created → User approves
4. Team Lead (Opus) orchestrates:
   - Spawns Backend/Frontend/Security Engineers via Droid MCP
   - Droid workers execute with MiniMax-M2.5
   - Team Lead reviews output
5. Review agents (Opus + Droid) verify quality
6. Manual QA runs smoke tests
7. User approves final delivery

### Failure Paths
1. Droid MCP unavailable → Report blocked state, cannot proceed with workers
2. Worker fails twice → Escalate to Opus for resolution
3. MiniMax API issues → Worker reports failure, Team Lead decides retry/escalate

## 9. Acceptance Criteria (testable)
1. All Codex references replaced with Claude Code in skill files
2. `skills/pm/agents/openai.yaml` updated with correct model per role
3. Droid MCP wrapper script created at `scripts/droid-mcp-server` (or similar)
4. MCP server can be added via `claude mcp add droid-worker -- <path-to-script>`
5. Role reference files updated with model annotations
6. README.md reflects new setup instructions
7. Existing PM workflow phases still functional

## 10. Success Metrics (measurable)
- All skill files: Zero Codex references remaining
- Agent config: 13 roles mapped correctly (4 Opus, 9 Droid+M2.5)
- Droid MCP: Can spawn worker and receive JSON output
- Workflow: Full PM cycle completes successfully

## 11. BEADS
### Business
- Cost reduction: MiniMax-M2.5 is significantly cheaper than Opus for implementation work
- Throughput: Parallel worker execution via Droid

### Experience
- Consistent quality from Opus in lead roles
- Fast, cheap workers for implementation

### Architecture
- Claude Code as orchestrator runtime
- Droid CLI in headless mode as worker runtime
- MCP server wrapper for Droid task execution

### Data
- No data changes required

### Security
- Droid workers run in isolated worktrees (managed by Conductor)
- MCP tool permissions limited to task execution scope

## 12. Rollout / Migration / Rollback
- Rollout: Update skill files, create MCP wrapper, test full cycle
- Migration: Update local setup docs, update any CI configs
- Rollback: Revert git changes to restore Codex compatibility

## 13. Risks & Edge Cases
- MiniMax API downtime: Workers fail, need escalation path
- MCP server integration: May need debugging for JSON output parsing
- Model routing: Ensure correct model per role, prevent cross-contamination
- Droid autonomy: Using --auto high requires isolated/disposable contexts

## 14. Open Questions

