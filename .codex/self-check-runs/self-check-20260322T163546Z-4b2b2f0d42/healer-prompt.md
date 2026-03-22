use agent swarm for PM self-check healer: investigate run self-check-20260322T163546Z-4b2b2f0d42 for fixture happy-path and use the normal PM flow to package any orchestrator repairs.

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

Run ID: self-check-20260322T163546Z-4b2b2f0d42
Fixture case: happy-path
Synthetic task: Create a snake game
Summary file: .codex/self-check-runs/self-check-20260322T163546Z-4b2b2f0d42/summary.json
Healer context file: .codex/self-check-runs/self-check-20260322T163546Z-4b2b2f0d42/healer-context.json

Summary JSON:
{
  "run_id": "self-check-20260322T163546Z-4b2b2f0d42",
  "fixture_suite_version": "pm-self-check-v1",
  "fixture_case": "happy-path",
  "execution_mode": "main-runtime-only",
  "artifact_dir": ".codex/self-check-runs/self-check-20260322T163546Z-4b2b2f0d42",
  "synthetic_task": "Create a snake game",
  "status": "clean",
  "started_at": "2026-03-22T16:35:46Z",
  "completed_at": "2026-03-22T16:35:57Z",
  "claude_health": {
    "registration": "passed",
    "executability": "passed",
    "session_usability": "passed"
  },
  "child_plan_gate": {
    "status": "ready",
    "output_file": ".codex/self-check-runs/self-check-20260322T163546Z-4b2b2f0d42/child-plan-gate.txt"
  },
  "healer_prompt_file": ".codex/self-check-runs/self-check-20260322T163546Z-4b2b2f0d42/healer-prompt.md",
  "healer_context_file": ".codex/self-check-runs/self-check-20260322T163546Z-4b2b2f0d42/healer-context.json",
  "events": [
    {
      "run_id": "self-check-20260322T163546Z-4b2b2f0d42",
      "phase": "artifacts",
      "step": "claude_mcp_snapshot",
      "severity": "warning",
      "status": "failed",
      "code": "snapshot_capture_failed",
      "detail": "Unable to capture claude mcp list within timeout.",
      "remediation": "",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T163546Z-4b2b2f0d42/claude-mcp-list.txt",
      "created_at": "2026-03-22T16:35:54Z"
    },
    {
      "run_id": "self-check-20260322T163546Z-4b2b2f0d42",
      "phase": "health",
      "step": "claude_registration",
      "severity": "info",
      "status": "passed",
      "code": "claude_code_mcp_registered",
      "detail": "claude-code MCP registration is present.",
      "remediation": "",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T163546Z-4b2b2f0d42/codex-mcp-list.txt",
      "created_at": "2026-03-22T16:35:56Z"
    },
    {
      "run_id": "self-check-20260322T163546Z-4b2b2f0d42",
      "phase": "health",
      "step": "claude_executability",
      "severity": "info",
      "status": "passed",
      "code": "claude_code_mcp_executable",
      "detail": "claude-code command is executable in the current runtime.",
      "remediation": "",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T163546Z-4b2b2f0d42/codex-mcp-list.txt",
      "created_at": "2026-03-22T16:35:57Z"
    },
    {
      "run_id": "self-check-20260322T163546Z-4b2b2f0d42",
      "phase": "health",
      "step": "claude_session",
      "severity": "info",
      "status": "passed",
      "code": "claude_session_usable",
      "detail": "Claude session probe completed successfully.",
      "remediation": "",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T163546Z-4b2b2f0d42/claude-session-probe-eval.txt",
      "created_at": "2026-03-22T16:35:57Z"
    },
    {
      "run_id": "self-check-20260322T163546Z-4b2b2f0d42",
      "phase": "child_flow",
      "step": "plan_gate",
      "severity": "info",
      "status": "passed",
      "code": "plan_route_ready",
      "detail": "Child plan gate completed successfully.",
      "remediation": "",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T163546Z-4b2b2f0d42/child-plan-gate.txt",
      "created_at": "2026-03-22T16:35:57Z"
    },
    {
      "run_id": "self-check-20260322T163546Z-4b2b2f0d42",
      "phase": "fixture",
      "step": "synthetic_task",
      "severity": "info",
      "status": "passed",
      "code": "fixture_ready",
      "detail": "Synthetic task prepared: Create a snake game",
      "remediation": "",
      "artifact_path": "",
      "created_at": "2026-03-22T16:35:57Z"
    }
  ],
  "findings": [
    {
      "run_id": "self-check-20260322T163546Z-4b2b2f0d42",
      "phase": "artifacts",
      "step": "claude_mcp_snapshot",
      "severity": "warning",
      "status": "failed",
      "code": "snapshot_capture_failed",
      "detail": "Unable to capture claude mcp list within timeout.",
      "remediation": "",
      "artifact_path": ".codex/self-check-runs/self-check-20260322T163546Z-4b2b2f0d42/claude-mcp-list.txt",
      "created_at": "2026-03-22T16:35:54Z"
    }
  ]
}

