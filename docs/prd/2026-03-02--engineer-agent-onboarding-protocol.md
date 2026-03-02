# Engineer Agent Onboarding & Implementation Protocol

## Date
2026-03-02

## Owner
PM Orchestrator

## Problem
Engineer subagents (Backend, Frontend, Security) are spawned with minimal context — just a role definition, scope, and basic rules (~15-20 lines each). They receive a task context block from Team Lead but have no instruction to:
- Read project-level rules (CLAUDE.md, AGENTS.md) before starting work
- Scan actual code files for style conventions and patterns
- Apply a structured implementation thinking framework
- Ask Team Lead when they encounter ambiguity instead of guessing

This leads to engineers working blind to project conventions, producing code that may not match existing patterns, and silently making assumptions when context is insufficient.

## Context / Current State
- Three engineer reference files exist: `backend-engineer.md`, `frontend-engineer.md`, `security-engineer.md` in `skills/pm-implement/references/`
- Each is ~15-20 lines with role, scope, and basic rules
- Team Lead already has a "Droid Worker Context Contract" that provides task-level context (task title, ID, PRD, DoD, in-scope files, constraints, current state)
- Team Lead's prompt says "answer technical implementation questions directly for the engineering subagents" — but engineer prompts don't instruct agents to actually ask
- No existing onboarding, code-scanning, or implementation framework exists in engineer prompts

## User / Persona
- **PM Orchestrator maintainer** — wants engineer agents to produce higher-quality, convention-aligned code with fewer review iterations
- **Team Lead agent** — needs engineers to self-orient and ask questions early rather than deliver wrong-assumption code late

## Goals
1. Engineers read CLAUDE.md and AGENTS.md when picking up a new task to internalize project rules
2. Engineers scan in-scope files AND neighboring/related files for code style and patterns before implementing
3. Engineers apply a mandatory 4-layer checklist (architecture, syntax, composition, logic) before writing code
4. Engineers ask Team Lead on both hard blockers and soft ambiguity — never guess

## Non-Goals
- Changing the Team Lead prompt structure (only adding guidance for handling engineer questions)
- Changing model routing (engineers stay on their current runtime)
- Adding new engineer agent types
- Changing the Droid Worker Context Contract structure

## Scope

### In-Scope
- Update `backend-engineer.md` with onboarding protocol, code scanning, 4-layer checklist, and ask-Team-Lead escalation
- Update `frontend-engineer.md` with the same
- Update `security-engineer.md` with the same (adapted to security focus)
- Update `team-lead.md` to document expectation of engineer questions and response protocol
- Update `SKILL.md` (pm-implement) to document the new engineer onboarding and implementation protocol

### Out-of-Scope
- Changes to other agent prompts (Jazz, AGENTS Compliance, Librarian, etc.)
- Changes to model routing or launcher types
- Changes to the Droid Worker Context Contract template
- Changes to PM skill files outside pm-implement

## User Flow

### Happy Path
1. Team Lead spawns engineer with task context block
2. Engineer reads CLAUDE.md and AGENTS.md from the project root
3. Engineer scans in-scope files and samples neighboring files for code patterns/style
4. Engineer produces a 4-layer checklist assessment (architecture, syntax, composition, logic)
5. If anything is unclear at any layer, engineer asks Team Lead before proceeding
6. Team Lead answers or escalates to PM
7. Engineer implements task aligned with project conventions and checklist layers
8. Engineer reports completion with progress update

### Failure Paths
- CLAUDE.md or AGENTS.md not found → engineer proceeds with context block only and flags missing files to Team Lead
- Code scanning finds conflicting patterns → engineer asks Team Lead which pattern to follow
- Engineer identifies ambiguity during implementation → stops, asks Team Lead, waits for answer before continuing

## Acceptance Criteria
1. All three engineer reference files contain an onboarding section that instructs reading CLAUDE.md and AGENTS.md
2. All three engineer reference files contain a code scanning section that instructs broad file sampling (in-scope + neighboring)
3. All three engineer reference files contain a mandatory 4-layer checklist (architecture, syntax, composition, logic) with explicit output requirements
4. All three engineer reference files contain an ask-Team-Lead section covering both hard blockers and soft ambiguity
5. `team-lead.md` documents the expectation of receiving engineer questions and the response protocol
6. `SKILL.md` (pm-implement) references the new engineer onboarding protocol in the Team Lead Orchestration section
7. All changes are backward-compatible with existing Droid Worker Context Contract

## Success Metrics
- Engineer agents produce convention-aligned code (measurable via fewer review iteration tasks)
- Engineers ask clarifying questions instead of guessing (measurable via Team Lead interaction logs)
- 4-layer checklist is present in engineer output before implementation begins

## BEADS

### Business
- Reduces review iteration cycles → faster feature delivery
- Higher first-pass code quality from engineer agents

### Experience
- Team Lead gets structured engineer questions instead of wrong-assumption deliverables
- PM gets fewer escalations from avoidable ambiguity

### Architecture
- Changes are contained to 5 files in `skills/pm-implement/`
- No structural changes to agent spawning, model routing, or context contracts
- Adds protocol layers on top of existing Droid Worker Context Contract

### Data
- No data model changes
- No schema changes

### Security
- Security Engineer prompt gets the same onboarding protocol, reinforcing security-awareness during code scanning
- No new attack surfaces

## Rollout / Migration / Rollback
- Direct file updates — no migration needed
- Rollback: revert the 5 file changes via git

## Risks & Edge Cases
- **Token budget**: Broad code scanning (in-scope + neighboring files) adds tokens to MiniMax-M2.5 context. Mitigation: instruct engineers to scan patterns/signatures, not read entire files line-by-line.
- **Over-asking**: Engineers with low ambiguity threshold may over-ask Team Lead. Mitigation: instruct engineers to batch questions and provide their best-guess alongside the question.
- **Missing CLAUDE.md/AGENTS.md**: Some target projects may not have these files. Mitigation: instruct engineers to flag missing files and proceed with available context.

## Smoke Test Plan

### Happy Path
- Verify each engineer reference file contains all 4 new sections (onboarding, code scanning, 4-layer checklist, ask-Team-Lead)
- Verify team-lead.md references engineer question handling
- Verify SKILL.md references engineer onboarding protocol

### Unhappy Path
- Verify engineer prompt handles missing CLAUDE.md/AGENTS.md gracefully (fallback instruction present)
- Verify engineer prompt handles conflicting code patterns (escalation instruction present)

### Regression
- Verify existing Droid Worker Context Contract block is unchanged
- Verify existing Team Lead responsibilities are preserved (no removals)
- Verify existing engineer scope/rules sections are preserved (additions only)

## Open Questions
