# Global Bootstrap Smoke

## Date
2026-03-25

## Goal
Verify the machine-level bootstrap path on a real user environment:
- one canonical orchestrator checkout
- one user-level `claude-code` registration
- one second git repo with no orchestrator files installed
- one real Claude-routed dummy task through the global wrapper

## Machine-level bootstrap verification

Command:

```bash
./scripts/setup-global-orchestrator.sh --verify
```

Observed result:

```text
[setup-global-orchestrator.sh] Verification passed
```

Additional checks:

```text
codex mcp get claude-code
  command: /Users/d/.codex/skills/pm/scripts/claude-code-mcp

claude mcp list
  codex-worker: codex mcp-server - ✓ Connected
```

## Second-repo smoke

Temporary git repo:

```text
/var/folders/x9/7khmhvfd7874d4cycdcyspkr0000gn/T/global-bootstrap-smoke.wfJCFT
```

Repo preparation:
- initialized a new git repo
- committed `README.md`
- did not inject or install orchestrator runtime files into that repo

Smoke command:

```bash
CLAUDE_CODE_WRAPPER="$HOME/.codex/skills/pm/scripts/claude-code-mcp" \
TEST_REPO_CWD="/var/folders/x9/7khmhvfd7874d4cycdcyspkr0000gn/T/global-bootstrap-smoke.wfJCFT" \
./scripts/test-claude-agent-mcp-smoke.py
```

Observed result:

```text
[test-claude-agent-mcp-smoke] PASS: agent=pm-project-manager role=project_manager token=CLAUDE_AGENT_MCP_SMOKE_OK
```

## Verified outcomes

- The global wrapper at `~/.codex/skills/pm/scripts/claude-code-mcp` accepted the MCP stdio request.
- The wrapper resolved the current repo from `TEST_REPO_CWD` instead of from the orchestrator checkout path.
- Claude executed the `project_manager` role through the real path and returned the required token `CLAUDE_AGENT_MCP_SMOKE_OK`.
- Lazy repo bootstrap materialized managed Claude agents under:
  - `/var/folders/x9/7khmhvfd7874d4cycdcyspkr0000gn/T/global-bootstrap-smoke.wfJCFT/.claude/agents/`
- Verified generated file:
  - `/var/folders/x9/7khmhvfd7874d4cycdcyspkr0000gn/T/global-bootstrap-smoke.wfJCFT/.claude/agents/pm-project-manager.md`
- No repo-local `.codex/skills` install was required for the second repo.

## Conclusion

The fresh-Mac-style operator path is proven for the implemented scope:
- machine-level bootstrap succeeds
- user-level `claude-code` registration is stable
- a previously unprepared second repo can execute a real Claude-routed PM task
- required managed `.claude/agents` files appear lazily in that repo
