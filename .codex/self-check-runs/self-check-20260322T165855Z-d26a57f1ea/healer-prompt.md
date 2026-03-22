use agent swarm for PM self-check healer: investigate run self-check-20260322T165855Z-d26a57f1ea for fixture happy-path and use the normal PM flow to package any orchestrator repairs.

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

Run ID: self-check-20260322T165855Z-d26a57f1ea
Fixture case: happy-path
Synthetic task: Create a snake game
Summary file: .codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/summary.json
Healer context file: .codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/healer-context.json

Summary JSON:
{
  "run_id": "self-check-20260322T165855Z-d26a57f1ea",
  "fixture_suite_version": "pm-self-check-v1",
  "fixture_case": "happy-path",
  "execution_mode": "main-runtime-only",
  "artifact_dir": ".codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea",
  "synthetic_task": "Create a snake game",
  "status": "issues_detected",
  "started_at": "2026-03-22T16:58:55Z",
  "completed_at": "2026-03-22T16:59:09Z",
  "claude_health": {
    "registration": "passed",
    "executability": "passed",
    "session_usability": "passed"
  },
  "child_plan_gate": {
    "status": "ready",
    "output_file": ".codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/child-plan-gate.txt"
  },
  "artifact_checks": {
    "codex_mcp_snapshot": {
      "step": "codex_mcp_snapshot",
      "runtime_kind": "codex",
      "execution_mode": "main-runtime-only",
      "run_id": "self-check-20260322T165855Z-d26a57f1ea",
      "status": "passed",
      "primary_code": "",
      "issue_codes": [],
      "detail": "Snapshot captured successfully.",
      "remediation": "",
      "command_path": "/opt/homebrew/bin/codex",
      "command_source": "default(command=codex)",
      "path_override_source": "<none>",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/codex-mcp-list.txt",
      "stdout_path": ".codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/codex-mcp-list.stdout.txt",
      "stderr_path": ".codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/codex-mcp-list.stderr.txt",
      "attempt_file": ".codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/codex-mcp-list.attempt.json",
      "started_at": "2026-03-22T16:58:55Z",
      "completed_at": "2026-03-22T16:58:57Z",
      "elapsed_ms": 2000,
      "exit_code": 0,
      "exit_signal": null,
      "timed_out": false,
      "pid": "89626",
      "process_state": "89626 89569 S    node /opt/homebrew/bin/codex mcp list",
      "partial_stdout": "Name Command Args Env Cwd Status Auth chrome-devtools npx -y chrome-devtools-mcp@latest --autoConnect - - enabled Unsupported claude-code c",
      "partial_stderr": "",
      "partial_combined_output": "Name Command Args Env Cwd Status Auth chrome-devtools npx -y chrome-devtools-mcp@latest --autoConnect - - enabled Unsupported claude-code c",
      "telemetry_complete": true
    },
    "claude_mcp_snapshot": {
      "step": "claude_mcp_snapshot",
      "runtime_kind": "claude",
      "execution_mode": "main-runtime-only",
      "run_id": "self-check-20260322T165855Z-d26a57f1ea",
      "status": "failed",
      "primary_code": "snapshot_command_hung",
      "issue_codes": [
        "snapshot_command_hung",
        "snapshot_partial_output"
      ],
      "detail": "Snapshot command exceeded timeout while collecting MCP state.",
      "remediation": "Inspect the snapshot attempt JSON plus stdout/stderr artifacts and fix the runtime or launcher path before rerunning self-check.",
      "command_path": "/Users/d/.local/bin/claude",
      "command_source": "/Users/d/.codex/config.toml",
      "path_override_source": "[shell_environment_policy.set] in /Users/d/.codex/config.toml",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/claude-mcp-list.txt",
      "stdout_path": ".codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/claude-mcp-list.stdout.txt",
      "stderr_path": ".codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/claude-mcp-list.stderr.txt",
      "attempt_file": ".codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/claude-mcp-list.attempt.json",
      "started_at": "2026-03-22T16:58:59Z",
      "completed_at": "2026-03-22T16:59:05Z",
      "elapsed_ms": 6000,
      "exit_code": null,
      "exit_signal": "TERM",
      "timed_out": true,
      "pid": "89798",
      "process_state": "89798 89569 S    /Users/d/.local/bin/claude mcp list",
      "partial_stdout": "Checking MCP server health...",
      "partial_stderr": "",
      "partial_combined_output": "Checking MCP server health...",
      "telemetry_complete": true
    }
  },
  "healer_prompt_file": ".codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/healer-prompt.md",
  "healer_context_file": ".codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/healer-context.json",
  "events": [
    {
      "run_id": "self-check-20260322T165855Z-d26a57f1ea",
      "phase": "artifacts",
      "step": "codex_mcp_snapshot",
      "severity": "info",
      "status": "passed",
      "code": "snapshot_capture_passed",
      "detail": "Snapshot capture completed successfully.",
      "remediation": "",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/codex-mcp-list.txt",
      "metadata": {},
      "created_at": "2026-03-22T16:58:57Z"
    },
    {
      "run_id": "self-check-20260322T165855Z-d26a57f1ea",
      "phase": "artifacts",
      "step": "claude_mcp_snapshot",
      "severity": "warning",
      "status": "failed",
      "code": "snapshot_command_hung",
      "detail": "Snapshot command exceeded timeout while collecting MCP state.",
      "remediation": "Inspect the snapshot attempt JSON plus stdout/stderr artifacts and fix the runtime or launcher path before rerunning self-check.",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/claude-mcp-list.txt",
      "metadata": {},
      "created_at": "2026-03-22T16:59:05Z"
    },
    {
      "run_id": "self-check-20260322T165855Z-d26a57f1ea",
      "phase": "health",
      "step": "claude_registration",
      "severity": "info",
      "status": "passed",
      "code": "claude_code_mcp_registered",
      "detail": "claude-code MCP registration is present.",
      "remediation": "",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/codex-mcp-list.txt",
      "metadata": {},
      "created_at": "2026-03-22T16:59:06Z"
    },
    {
      "run_id": "self-check-20260322T165855Z-d26a57f1ea",
      "phase": "health",
      "step": "claude_executability",
      "severity": "info",
      "status": "passed",
      "code": "claude_code_mcp_executable",
      "detail": "claude-code command is executable in the current runtime.",
      "remediation": "",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/codex-mcp-list.txt",
      "metadata": {},
      "created_at": "2026-03-22T16:59:08Z"
    },
    {
      "run_id": "self-check-20260322T165855Z-d26a57f1ea",
      "phase": "health",
      "step": "claude_session",
      "severity": "info",
      "status": "passed",
      "code": "claude_session_usable",
      "detail": "Claude session probe completed successfully.",
      "remediation": "",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/claude-session-probe-eval.txt",
      "metadata": {},
      "created_at": "2026-03-22T16:59:08Z"
    },
    {
      "run_id": "self-check-20260322T165855Z-d26a57f1ea",
      "phase": "child_flow",
      "step": "plan_gate",
      "severity": "info",
      "status": "passed",
      "code": "plan_route_ready",
      "detail": "Child plan gate completed successfully.",
      "remediation": "",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/child-plan-gate.txt",
      "metadata": {},
      "created_at": "2026-03-22T16:59:08Z"
    },
    {
      "run_id": "self-check-20260322T165855Z-d26a57f1ea",
      "phase": "fixture",
      "step": "synthetic_task",
      "severity": "info",
      "status": "passed",
      "code": "fixture_ready",
      "detail": "Synthetic task prepared: Create a snake game",
      "remediation": "",
      "artifact_path": "",
      "metadata": {},
      "created_at": "2026-03-22T16:59:08Z"
    }
  ],
  "findings": [
    {
      "run_id": "self-check-20260322T165855Z-d26a57f1ea",
      "phase": "artifacts",
      "step": "claude_mcp_snapshot",
      "severity": "warning",
      "status": "failed",
      "code": "snapshot_command_hung",
      "detail": "Snapshot command exceeded timeout while collecting MCP state.",
      "remediation": "Inspect the snapshot attempt JSON plus stdout/stderr artifacts and fix the runtime or launcher path before rerunning self-check.",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T165855Z-d26a57f1ea/claude-mcp-list.txt",
      "metadata": {},
      "created_at": "2026-03-22T16:59:05Z"
    }
  ]
}

