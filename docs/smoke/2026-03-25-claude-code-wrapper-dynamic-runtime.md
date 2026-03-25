# Claude Code Wrapper Dynamic Runtime Smoke

Date: 2026-03-25

## Scope

Verify that Codex-outer `dynamic-cross-runtime` works again after replacing the raw `claude mcp serve` launcher dependency with the repo-owned `claude-code-mcp` wrapper.

## Automated Coverage

Commands:

```bash
./scripts/test-claude-code-mcp.sh
./scripts/test-runtime-layout.sh
./scripts/test-pm-command.sh
```

Observed:

- `test-claude-code-mcp` passed, proving the wrapper server exposes `Agent` and `TaskOutput`, maps `default` / `explorer` / `worker`, and passes through `mcp list`.
- `test-runtime-layout` passed, proving the wrapper command ships into both `.codex/skills/pm/scripts/` and `.claude/skills/pm/scripts/`.
- `test-pm-command` passed after the launcher timeout increase to `30000ms`.

Result: pass

## Live Runtime Proof

### Direct Claude MCP Agent Calls

Configured command from `~/.codex/config.toml`:

```text
/Users/d/.codex/worktrees/9d3c/product-orchestrator/skills/pm/scripts/claude-code-mcp
```

Observed live MCP results:

- `default` returned exact token `DYNAMIC_DEFAULT_1774431967`
- `explorer` returned exact token `DYNAMIC_EXPLORER_1774431982`
- `worker` returned exact token `DYNAMIC_WORKER_1774431992`
- server info was `pm-orchestrator/claude-code-mcp`

Result: pass

### Dynamic Plan Gate

Command:

```bash
./skills/pm/scripts/pm-command.sh plan gate --route default --mode dynamic-cross-runtime
```

Observed:

- outer runtime detected as `codex`
- Claude-routed support roles stayed on `claude-code-mcp`
- final line was `PLAN_ROUTE_READY|...|discovery_can_start=1`

Result: pass

### Dynamic Self-Check

Command:

```bash
./skills/pm/scripts/pm-command.sh self-check run --mode dynamic-cross-runtime
```

Observed:

- run id `self-check-20260325T094735Z-0ddd490f47`
- `claude_health.registration=passed`
- `claude_health.executability=passed`
- `claude_health.session_usability=passed`
- `claude_health.launcher_candidate=default`
- `artifact_checks.claude_mcp_snapshot.command_path=/Users/d/.codex/worktrees/9d3c/product-orchestrator/skills/pm/scripts/claude-code-mcp`
- `artifact_checks.claude_launcher_probe.server_info.name=pm-orchestrator/claude-code-mcp`
- final status `clean`

Result: pass

## Residual Observation

`codex mcp get claude-code` and `codex mcp list` still displayed the old `claude mcp serve` command text even after `~/.codex/config.toml` changed to the wrapper command. The PM helper and live self-check both used the wrapper path successfully, so this looks like a Codex CLI display/cache defect rather than a PM runtime blocker.
