# Orchestrator Role Contracts

This document is the canonical routed-role map for the PM orchestrator.

- Routing source of truth: [skills/pm/agents/model-routing.yaml](/Users/d/product-orchestrator/skills/pm/agents/model-routing.yaml)
- Workflow source of truth: [instructions/pm_workflow.md](/Users/d/product-orchestrator/instructions/pm_workflow.md) and [.config/opencode/instructions/pm_workflow.md](/Users/d/product-orchestrator/.config/opencode/instructions/pm_workflow.md)
- Prompt-source rule: every active routed role must have one canonical prompt source. If a phase wrapper duplicates or mirrors that prompt, the wrapper must point back to the canonical source instead of creating an independent contract.
- Inspiration rule: `awesome-codex-subagents` is source material for role-contract patterns only. Its `.toml` agents are not runtime dependencies for this orchestrator.
- Claude agent sync rule: PM role prompts stay canonical in the reference files below, `skills/pm/agents/claude-agent-map.json` is the internal role-to-Claude-agent mapping contract, and `skills/pm/scripts/sync-claude-agents.py` deterministically materializes `.claude/agents/*.md`.
- Claude wrapper rule: `skills/pm/scripts/claude-code-mcp` auto-syncs `.claude/agents` before invoking `claude -p --agent <resolved-name>`, so the public PM launcher contract can remain generic while Claude uses repo-owned project agents internally.

## Role Map
| Role | Canonical Prompt Source | Recommended Launcher | Primary Inspiration |
|---|---|---|---|
| `project_manager` | [skills/pm/references/project-manager.md](/Users/d/product-orchestrator/skills/pm/references/project-manager.md) | `default` | `project-manager`, `product-manager` |
| `team_lead` | [skills/pm-implement/references/team-lead.md](/Users/d/product-orchestrator/skills/pm-implement/references/team-lead.md) | `default` | `multi-agent-coordinator`, `task-distributor`, `context-manager` |
| `pm_beads_plan_handoff` | [skills/pm/references/pm-beads-plan-handoff.md](/Users/d/product-orchestrator/skills/pm/references/pm-beads-plan-handoff.md) | `default` | `workflow-orchestrator`, `task-distributor`, `context-manager` |
| `pm_implement_handoff` | [skills/pm/references/pm-implement-handoff.md](/Users/d/product-orchestrator/skills/pm/references/pm-implement-handoff.md) | `default` | `workflow-orchestrator`, `multi-agent-coordinator`, `agent-organizer` |
| `senior_engineer` | [skills/pm/references/senior-engineer.md](/Users/d/product-orchestrator/skills/pm/references/senior-engineer.md) | `explorer` | `code-mapper`, `architect-reviewer` |
| `librarian` | [skills/pm/references/librarian.md](/Users/d/product-orchestrator/skills/pm/references/librarian.md) | `default` | `docs-researcher`, `search-specialist`, `documentation-engineer` |
| `smoke_test_planner` | [skills/pm/references/smoke-test-planner.md](/Users/d/product-orchestrator/skills/pm/references/smoke-test-planner.md) | `default` | `qa-expert`, `test-automator`, `browser-debugger` |
| `alternative_pm` | [skills/pm/references/alternative-pm.md](/Users/d/product-orchestrator/skills/pm/references/alternative-pm.md) | `default` | `product-manager`, `project-manager` |
| `researcher` | [skills/pm/references/researcher.md](/Users/d/product-orchestrator/skills/pm/references/researcher.md) | `default` | `research-analyst`, `docs-researcher`, `search-specialist` |
| `backend_engineer` | [skills/pm-implement/references/backend-engineer.md](/Users/d/product-orchestrator/skills/pm-implement/references/backend-engineer.md) | `worker` | `backend-developer` |
| `frontend_engineer` | [skills/pm-implement/references/frontend-engineer.md](/Users/d/product-orchestrator/skills/pm-implement/references/frontend-engineer.md) | `worker` | `frontend-developer`, `accessibility-tester` |
| `security_engineer` | [skills/pm-implement/references/security-engineer.md](/Users/d/product-orchestrator/skills/pm-implement/references/security-engineer.md) | `worker` | `security-auditor`, `security-engineer`, `penetration-tester` |
| `agents_compliance_reviewer` | [skills/pm-implement/references/agents-compliance.md](/Users/d/product-orchestrator/skills/pm-implement/references/agents-compliance.md) | `default` | `compliance-auditor`, `reviewer` |
| `jazz_reviewer` | [skills/pm-implement/references/jazz.md](/Users/d/product-orchestrator/skills/pm-implement/references/jazz.md) | `default` | `reviewer`, `architect-reviewer` |
| `codex_reviewer` | [skills/pm-implement/references/codex-reviewer.md](/Users/d/product-orchestrator/skills/pm-implement/references/codex-reviewer.md) | `default` | `code-reviewer`, `architect-reviewer`, `reviewer` |
| `manual_qa` | [skills/pm-implement/references/manual-qa-smoke.md](/Users/d/product-orchestrator/skills/pm-implement/references/manual-qa-smoke.md) | `default` | `qa-expert`, `browser-debugger`, `accessibility-tester` |
| `task_verification` | [skills/pm-implement/references/task-verification.md](/Users/d/product-orchestrator/skills/pm-implement/references/task-verification.md) | `default` | `reviewer`, `test-automator`, `error-detective` |

## Notes
- [skills/pm/references/manual-qa-smoke.md](/Users/d/product-orchestrator/skills/pm/references/manual-qa-smoke.md) is a phase-level mirror for PM wiring. The canonical `manual_qa` role contract is the implementation-phase prompt above and the PM copy must stay aligned with it.
- Main and handoff roles use dedicated prompt files so their intent is no longer implicit in `SKILL.md` prose alone.

## Verification Commands
Use these commands from repo root when checking routed-role coverage and stale runtime headers:

```bash
rg -n 'project_manager|team_lead|pm_beads_plan_handoff|pm_implement_handoff|senior_engineer|librarian|smoke_test_planner|alternative_pm|researcher|backend_engineer|frontend_engineer|security_engineer|agents_compliance_reviewer|jazz_reviewer|codex_reviewer|manual_qa|task_verification' skills/pm/agents/model-routing.yaml

rg -n '^\*\*Runtime profile:\*\*|^\*\*Recommended launcher:\*\*' skills/pm/references skills/pm-implement/references

rg -n '\*\*Model: gpt|\*\*Model: Claude Code|\*\*Model: Codex-native' skills/pm/references skills/pm-implement/references
```

Expected result:
- the first command confirms the active routed-role set
- the second confirms prompt headers use runtime-profile wording
- the third should return no matches for active role references
