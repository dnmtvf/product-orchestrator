---
name: pm-beads-plan
description: Convert an approved PRD into an unambiguous Beads tracking graph, then run a second approval gate with bdui task review before implementation handoff.
---

# PM Beads Plan (Strict)

## Current Phase
- **BEADS PLANNING** (and then **AWAITING BEADS APPROVAL**)

## Purpose
Convert an **APPROVED** PRD into an executable Beads graph:
- 1 Epic per PRD
- Atomic child tasks with Definition of Done (DoD)
- Explicit dependencies (`blocks` / `blocked-by`)
- Human review gate before implementation starts

## Subagent Launcher Compatibility (mandatory)
- Spawn only supported generic agent types: `default`, `explorer`, `worker`.
- Encode role in prompt payload for spawned subagents (for example: `[Role: Senior Engineer]`).
- Do not rely on custom named subagent launchers.
- Recommended launcher mapping for this phase:
  - `explorer`: Senior Engineer dependency and sequencing analysis.
  - `default`: Librarian and implementation handoff helper agents.

## Paired Support Agents (recommended)
Before locking the task graph, proactively consult:
1. **Senior Engineer** (`explorer`) for dependency correctness and implementation sequencing.
2. **Librarian** (`default`) for external constraints (API quotas, platform requirements, compliance notes).
3. **Smoke Test Planner output** from discovery/PRD for QA task coverage.

## Preconditions (hard gate)
Before planning, verify all of the following:
1. PRD path is provided and file exists.
2. User explicitly confirms PRD is approved.
3. PRD `Open Questions` section is empty.

If any precondition fails:
- **STOP**.
- State exactly what is missing.
- Ask only for the missing prerequisite(s).
- Do not generate epic/tasks/dependencies yet.

## Planning Rules
When preconditions pass:
- Beads initialization policy:
  - Normal repo (not a git worktree): if `.beads/` is missing, run `bd init`.
  - Git worktree: do not run `bd init` in the worktree (Beads blocks this). Initialize once in the main repository, then continue from the worktree.
  - If main-repo initialization is not available during this run, continue in planning mode with `bd --no-db` (JSONL under `.beads/`) and explicitly note this in output.
  - Worktree detection heuristic: `git rev-parse --git-dir` path contains `/worktrees/` (or `.git` file points to `.../.git/worktrees/...`).
- Big-feature worktree-isolated mode:
  - Add per-PRD task notes for isolated worktree execution boundaries.
  - Record integration/merge sequencing tasks where cross-PRD touch points exist.
  - Prefer Ralph-native worktree assumptions; external worktree tools are optional helpers only.
- Epic title format:
  - `<slug> (PRD: <path>)`
- Generate atomic tasks only:
  - each task independently completable
  - no vague "misc/refactor/fix later" tasks
- Each task must include:
  - clear scope
  - DoD (testable)
- Dependencies must be explicit:
  - define `blocks` / `blocked-by` relationships with `bd dep`
- Include a dedicated `Manual QA Smoke Tests` task in the epic:
  - consumes the discovery/PRD smoke-test plan
  - runs happy/unhappy/regression checks
  - includes browser-based smoke checks when needed
  - for big-feature route, includes dual-mode regression checks for `conflict-aware` and `worktree-isolated`

## bdui Review Gate (required)
After task graph is generated:
- Present [bdui](https://github.com/assimelha/bdui) as the primary visual review.
- If `bdui` is available, instruct to launch it from repo root.
- Always provide fallback list view:
  - `bd list --parent <epic-id> --pretty`
  - `bd graph <epic-id> --compact`
- Require explicit user response `approved` before implementation.

## Runnable Promotion Gate (mandatory for big-feature route)
- While waiting for Beads approval, manifest state must be `awaiting_beads_approval`.
- Promotion to `queued` is allowed only if all are true:
  - PRD approval gate exact reply is `approved`
  - Beads approval gate exact reply is `approved`
  - PRD `Open Questions` remains empty
- On gate violation, do not enqueue and keep explicit blocked state:
  - missing Beads approval -> `awaiting_beads_approval`
  - open questions reintroduced -> `approved` with `blocked_reason=open_questions`
- Promotion attempts must enforce idempotency key uniqueness (`<prd_slug>:<approval_version>`).

## Handoff to Implementation
When user responds `approved` at this gate:
- Automatically invoke `$pm-implement` with PRD path and epic ID.
- Do not ask the user to manually run the next command.
- Preferred orchestration path: invoke via generic `default` `spawn_agent` with role-labeled context (`[Role: PM Implement Handoff]`) and wait for completion.

## Minimal Repo Bootstrap (only if needed)
- Ensure `docs/beads.md` exists.
- If missing, create it with these conventions:
  - PRD slug format: `YYYY-MM-DD--kebab-slug`
  - Epic naming includes slug + PRD path
  - Atomic tasks + DoD + explicit deps
  - `.beads/` should be committed to git

## Output Requirements (every run)
Always include these sections, in order:
1. `Current phase: BEADS PLANNING` or `Current phase: AWAITING BEADS APPROVAL`
2. `PRD path`
3. `Epic name`
4. `Task list (with DoD)`
5. `Dependency list`
6. `Human-readable task graph`
7. `bdui review` (with repo link + fallback commands)
8. `What I need from you next`

## Invocation
- Trigger strongly on `$pm-beads-plan <request>`.
- Expect PRD path and approval confirmation.
