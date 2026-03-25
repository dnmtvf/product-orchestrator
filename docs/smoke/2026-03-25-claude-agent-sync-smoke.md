# Claude Agent Sync Smoke

## Date
2026-03-25

## Scope
- Verify repo-owned PM role prompts sync into Claude project agents.
- Verify the repo-owned `claude-code-mcp` wrapper resolves those agents through the real MCP stdio path.
- Verify a dummy task returns an explicitly checked response token.

## Commands Run

```bash
cd /Users/d/product-orchestrator
./skills/pm/scripts/sync-claude-agents.py --check
claude agents
./scripts/test-claude-agent-mcp-smoke.py
```

## Expected Results
- `sync-claude-agents.py --check` reports zero drift.
- `claude agents` lists the generated `pm-*` project agents.
- `test-claude-agent-mcp-smoke.py` passes through the real MCP wrapper path and verifies token `CLAUDE_AGENT_MCP_SMOKE_OK`.

## Observed Results
- `sync-claude-agents.py --check` returned `CLAUDE_AGENT_SYNC|status=ok|check=1|...|drift=0`.
- `claude agents` reported `22 active agents` with these project agents present:
  - `pm-agents-compliance-reviewer`
  - `pm-alternative-pm`
  - `pm-backend-engineer`
  - `pm-beads-plan-handoff`
  - `pm-codex-reviewer`
  - `pm-frontend-engineer`
  - `pm-implement-handoff`
  - `pm-jazz-reviewer`
  - `pm-librarian`
  - `pm-manual-qa`
  - `pm-project-manager`
  - `pm-researcher`
  - `pm-security-engineer`
  - `pm-senior-engineer`
  - `pm-smoke-test-planner`
  - `pm-task-verification`
  - `pm-team-lead`
- `./scripts/test-claude-agent-mcp-smoke.py` returned:

```text
[test-claude-agent-mcp-smoke] PASS: agent=pm-project-manager role=project_manager token=CLAUDE_AGENT_MCP_SMOKE_OK
```

## Wrapper Path Verified
- MCP client transport: stdio
- Wrapper command: `./skills/pm/scripts/claude-code-mcp`
- Tool invoked: `run_role_prompt`
- Resolved Claude project agent: `pm-project-manager`
- Verified token: `CLAUDE_AGENT_MCP_SMOKE_OK`

## Conclusion
- Claude project agents are functional through the repo-owned wrapper path.
- The internal role-to-Claude-agent mapping is active.
- Drift detection and end-to-end dummy verification both passed in the source repo.
