use agent swarm for PM self-check healer: investigate run self-check-20260322T180750Z-dc931ec886 for fixture happy-path and use the normal PM flow to package any orchestrator repairs.

# PM Self-Check Healer

You are the outer healer agent for a PM self-check run.

Rules:
- Read the provided healer context JSON and summary JSON before making any recommendation.
- Treat `SELF_CHECK_EVENT` findings and the artifact bundle as the authoritative record for this run.
- If the summary status is `clean`, report that no repair plan is needed and stop.
- If the summary status is `issues_detected`, use the normal PM flow to package repair work from the captured evidence.
- Do not bypass PRD approval, Beads approval, or any other existing PM gate.
- Do not implement repairs directly as part of self-check unless a later approved PM flow explicitly authorizes implementation.
- If Claude health failed, report the run as blocked and do not continue into repair packaging.

Expected output:
- Short findings summary grouped by the captured issue codes.
- Explicit statement whether repair work is needed.
- Exact PM planning trigger or repair recommendation grounded in the artifact bundle.
- List of artifact files consulted.

Run ID: self-check-20260322T180750Z-dc931ec886
Fixture case: happy-path
Synthetic task: Create a snake game
Summary file: .codex/self-check-runs/self-check-20260322T180750Z-dc931ec886/summary.json
Healer context file: .codex/self-check-runs/self-check-20260322T180750Z-dc931ec886/healer-context.json

Summary JSON:
{
  "run_id": "self-check-20260322T180750Z-dc931ec886",
  "fixture_suite_version": "pm-self-check-v1",
  "fixture_case": "happy-path",
  "execution_mode": "main-runtime-only",
  "artifact_dir": ".codex/self-check-runs/self-check-20260322T180750Z-dc931ec886",
  "synthetic_task": "Create a snake game",
  "status": "clean",
  "started_at": "2026-03-22T18:07:50Z",
  "completed_at": "2026-03-22T18:08:02Z",
  "claude_health": {
    "registration": "passed",
    "executability": "passed",
    "session_usability": "passed"
  },
  "child_plan_gate": {
    "status": "ready",
    "output_file": ".codex/self-check-runs/self-check-20260322T180750Z-dc931ec886/child-plan-gate.txt"
  },
  "artifact_checks": {
    "codex_mcp_snapshot": {
      "step": "codex_mcp_snapshot",
      "runtime_kind": "codex",
      "execution_mode": "main-runtime-only",
      "run_id": "self-check-20260322T180750Z-dc931ec886",
      "status": "passed",
      "primary_code": "",
      "issue_codes": [],
      "detail": "Snapshot captured successfully.",
      "remediation": "",
      "command_path": "/opt/homebrew/bin/codex",
      "command_source": "default(command=codex)",
      "path_override_source": "<none>",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T180750Z-dc931ec886/codex-mcp-list.txt",
      "stdout_path": ".codex/self-check-runs/self-check-20260322T180750Z-dc931ec886/codex-mcp-list.stdout.txt",
      "stderr_path": ".codex/self-check-runs/self-check-20260322T180750Z-dc931ec886/codex-mcp-list.stderr.txt",
      "attempt_file": ".codex/self-check-runs/self-check-20260322T180750Z-dc931ec886/codex-mcp-list.attempt.json",
      "started_at": "2026-03-22T18:07:50Z",
      "completed_at": "2026-03-22T18:07:52Z",
      "elapsed_ms": 2000,
      "exit_code": 0,
      "exit_signal": null,
      "timed_out": false,
      "pid": "79500",
      "process_state": "79500 79438 S    node /opt/homebrew/bin/codex mcp list",
      "timeout_seconds": 5,
      "command_env_overrides": "<none>",
      "partial_stdout": "Name Command Args Env Cwd Status Auth chrome-devtools npx -y chrome-devtools-mcp@latest --autoConnect - - enabled Unsupported claude-code c",
      "partial_stderr": "",
      "partial_combined_output": "Name Command Args Env Cwd Status Auth chrome-devtools npx -y chrome-devtools-mcp@latest --autoConnect - - enabled Unsupported claude-code c",
      "telemetry_complete": true
    },
    "claude_mcp_snapshot": {
      "step": "claude_mcp_snapshot",
      "runtime_kind": "claude",
      "execution_mode": "main-runtime-only",
      "run_id": "self-check-20260322T180750Z-dc931ec886",
      "status": "passed",
      "primary_code": "",
      "issue_codes": [],
      "detail": "Snapshot captured successfully.",
      "remediation": "",
      "command_path": "/Users/d/.local/bin/claude",
      "command_source": "/Users/d/.codex/config.toml",
      "path_override_source": "[shell_environment_policy.set] in /Users/d/.codex/config.toml",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T180750Z-dc931ec886/claude-mcp-list.txt",
      "stdout_path": ".codex/self-check-runs/self-check-20260322T180750Z-dc931ec886/claude-mcp-list.stdout.txt",
      "stderr_path": ".codex/self-check-runs/self-check-20260322T180750Z-dc931ec886/claude-mcp-list.stderr.txt",
      "attempt_file": ".codex/self-check-runs/self-check-20260322T180750Z-dc931ec886/claude-mcp-list.attempt.json",
      "started_at": "2026-03-22T18:07:53Z",
      "completed_at": "2026-03-22T18:07:58Z",
      "elapsed_ms": 5000,
      "exit_code": 0,
      "exit_signal": null,
      "timed_out": false,
      "pid": "79662",
      "process_state": "79662 79438 S    /Users/d/.local/bin/claude mcp list",
      "timeout_seconds": 12,
      "command_env_overrides": "MCP_TIMEOUT=3000",
      "partial_stdout": "Checking MCP server health... claude.ai Google Calendar: https://gcal.mcp.claude.com/mcp - ! Needs authentication claude.ai Gmail: https://gmail.mcp.claude.com/mcp - ! Needs authentication context7: npx -y @upstash/context7-mcp - ✓ Connected playwright: npx -y @playwright/mcp@latest - ✓ Connected chrome-devtools: npx -y chrome-devtools-mcp@latest --autoConnect - ✓ Connected serena: uvx --fr",
      "partial_stderr": "",
      "partial_combined_output": "Checking MCP server health... claude.ai Google Calendar: https://gcal.mcp.claude.com/mcp - ! Needs authentication claude.ai Gmail: https://gmail.mcp.claude.com/mcp - ! Needs authentication context7: npx -y @upstash/context7-mcp - ✓ Connected playwright: npx -y @playwright/mcp@latest - ✓ Connected chrome-devtools: npx -y chrome-devtools-mcp@latest --autoConnect - ✓ Connected serena: uvx --fr",
      "telemetry_complete": true
    }
  },
  "healer_prompt_file": ".codex/self-check-runs/self-check-20260322T180750Z-dc931ec886/healer-prompt.md",
  "healer_context_file": ".codex/self-check-runs/self-check-20260322T180750Z-dc931ec886/healer-context.json",
  "events": [
    {
      "run_id": "self-check-20260322T180750Z-dc931ec886",
      "phase": "artifacts",
      "step": "codex_mcp_snapshot",
      "severity": "info",
      "status": "passed",
      "code": "snapshot_capture_passed",
      "detail": "Snapshot capture completed successfully.",
      "remediation": "",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T180750Z-dc931ec886/codex-mcp-list.txt",
      "metadata": {},
      "created_at": "2026-03-22T18:07:52Z"
    },
    {
      "run_id": "self-check-20260322T180750Z-dc931ec886",
      "phase": "artifacts",
      "step": "claude_mcp_snapshot",
      "severity": "info",
      "status": "passed",
      "code": "snapshot_capture_passed",
      "detail": "Snapshot capture completed successfully.",
      "remediation": "",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T180750Z-dc931ec886/claude-mcp-list.txt",
      "metadata": {},
      "created_at": "2026-03-22T18:07:59Z"
    },
    {
      "run_id": "self-check-20260322T180750Z-dc931ec886",
      "phase": "health",
      "step": "claude_registration",
      "severity": "info",
      "status": "passed",
      "code": "claude_code_mcp_registered",
      "detail": "claude-code MCP registration is present.",
      "remediation": "",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T180750Z-dc931ec886/codex-mcp-list.txt",
      "metadata": {},
      "created_at": "2026-03-22T18:08:00Z"
    },
    {
      "run_id": "self-check-20260322T180750Z-dc931ec886",
      "phase": "health",
      "step": "claude_executability",
      "severity": "info",
      "status": "passed",
      "code": "claude_code_mcp_executable",
      "detail": "claude-code command is executable in the current runtime.",
      "remediation": "",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T180750Z-dc931ec886/codex-mcp-list.txt",
      "metadata": {},
      "created_at": "2026-03-22T18:08:01Z"
    },
    {
      "run_id": "self-check-20260322T180750Z-dc931ec886",
      "phase": "health",
      "step": "claude_session",
      "severity": "info",
      "status": "passed",
      "code": "claude_session_usable",
      "detail": "Claude session probe completed successfully.",
      "remediation": "",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T180750Z-dc931ec886/claude-session-probe-eval.txt",
      "metadata": {},
      "created_at": "2026-03-22T18:08:01Z"
    },
    {
      "run_id": "self-check-20260322T180750Z-dc931ec886",
      "phase": "child_flow",
      "step": "plan_gate",
      "severity": "info",
      "status": "passed",
      "code": "plan_route_ready",
      "detail": "Child plan gate completed successfully.",
      "remediation": "",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T180750Z-dc931ec886/child-plan-gate.txt",
      "metadata": {},
      "created_at": "2026-03-22T18:08:02Z"
    },
    {
      "run_id": "self-check-20260322T180750Z-dc931ec886",
      "phase": "fixture",
      "step": "synthetic_task",
      "severity": "info",
      "status": "passed",
      "code": "fixture_ready",
      "detail": "Synthetic task prepared: Create a snake game",
      "remediation": "",
      "artifact_path": "",
      "metadata": {},
      "created_at": "2026-03-22T18:08:02Z"
    }
  ],
  "findings": []
}

