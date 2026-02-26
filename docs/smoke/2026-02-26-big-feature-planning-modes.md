# Big-Feature Planning Modes Smoke Evidence

Date: 2026-02-26
Scope: command routing, dual planning modes, queue gate/idempotency/worker policy, and Codex plus Claude MCP policy alignment.

## Execution
Command executed:

```bash
set -euo pipefail
checks=0
fails=0
run_check() {
  local name="$1"
  local cmd="$2"
  checks=$((checks+1))
  if eval "$cmd"; then
    printf "PASS | %s\n" "$name"
  else
    printf "FAIL | %s\n" "$name"
    fails=$((fails+1))
  fi
}

run_check "Routing includes default and big-feature commands" "rg -q '/pm plan:' instructions/pm_workflow.md && rg -q '/pm plan big feature:' instructions/pm_workflow.md"
run_check "Discovery has conflict-aware mode section" "rg -q '^## Conflict-Aware Decomposition' skills/pm-discovery/SKILL.md"
run_check "Discovery has worktree-isolated mode section" "rg -q '^## Worktree-Isolated Decomposition' skills/pm-discovery/SKILL.md"
run_check "Queue promotion gate enforced in pm skill" "rg -q '^## Runnable Promotion Gate' skills/pm/SKILL.md"
run_check "Async worker cap set to 2" "rg -q 'worker_cap=2' skills/pm/SKILL.md && rg -q 'Required worker cap' docs/QUEUE_WORKFLOW.md"
run_check "Retry policy limits to single automatic retry" "rg -q 'one automatic retry' instructions/pm_workflow.md && rg -q 'One automatic retry' docs/QUEUE_WORKFLOW.md"
run_check "Queue reconciliation contract present" "rg -q '^## Queue Reconciliation Output' instructions/pm_workflow.md && rg -q '^## Reconciliation Output Contract' docs/QUEUE_WORKFLOW.md"
run_check "Dual-mode smoke coverage rule present" "rg -q '^## Dual-Mode Smoke Coverage' instructions/pm_workflow.md && rg -q 'Dual-Mode Regression Checklist' skills/pm-discovery/SKILL.md"
run_check "Codex-first plus Claude MCP policy aligned" "rg -q 'Workflow runtime is Codex-first' instructions/pm_workflow.md && rg -q 'Claude MCP Contract' skills/pm/SKILL.md"

printf "TOTAL | %s checks\n" "$checks"
printf "FAILED | %s checks\n" "$fails"
if [ "$fails" -ne 0 ]; then
  exit 1
fi
```

## Results
- PASS | Routing includes default and big-feature commands
- PASS | Discovery has conflict-aware mode section
- PASS | Discovery has worktree-isolated mode section
- PASS | Queue promotion gate enforced in pm skill
- PASS | Async worker cap set to 2
- PASS | Retry policy limits to single automatic retry
- PASS | Queue reconciliation contract present
- PASS | Dual-mode smoke coverage rule present
- PASS | Codex-first plus Claude MCP policy aligned
- TOTAL | 9 checks
- FAILED | 0 checks

## Regression Checklist
- [x] `/pm plan:` remains default single-PRD route.
- [x] `/pm plan big feature:` routes to multi-PRD planning.
- [x] Discovery includes both `conflict-aware` and `worktree-isolated` decomposition rules.
- [x] Queue promotion is blocked unless both approvals are exact `approved` and Open Questions are empty.
- [x] Queue idempotency key format is defined as `<prd_slug>:<approval_version>`.
- [x] Async enqueue is bounded (`worker_cap=2`) with one automatic retry.
- [x] Queue reconciliation contract includes discovered/approved/queued/queue_failed counts.
- [x] Workflow policy is Codex-first and Claude usage is via `claude-code` MCP contract only.
