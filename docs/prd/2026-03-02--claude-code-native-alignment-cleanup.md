# PRD

## 1. Title, Date, Owner
- Title: Claude Code Native Alignment Cleanup
- Date: 2026-03-02
- Owner: PM Orchestrator

## 2. Problem
The PM orchestrator contains residual OpenAI Codex and OpenCode references across workflow documentation, SKILL.md files, state files, and install scripts. These references conflict with the Claude Code runtime the orchestrator now targets. Specific failures:
- SKILL.md files specify incorrect subagent type names (`explorer`, `worker`) that don't match Claude Code's Task tool API (`Explore`, `default`)
- `instructions/pm_workflow.md` specifies `openai/gpt-5.3-codex` model routing and references non-existent `pm-*` named agents
- The self-update state file persists dead OpenAI Codex URLs
- The `"use agent swarm for ..."` prompt convention (from Kimi K2.5) has no meaning in Claude Code
- `CLAUDE.md` is too sparse for effective Claude Code session initialization
- `.config/opencode/` directory is an OpenCode-only artifact with no Claude Code purpose

## 3. Context / Current State
The orchestrator was originally built for OpenCode with Codex model routing. A hybrid Claude+Droid refactor (`5bba83a`) and subsequent Claude alignment fixes (`0bbfc0d`) updated the SKILL.md files to reference Claude Code patterns, but left `instructions/pm_workflow.md`, the state file, AGENTS.md, install docs, and several conventions in their Codex/OpenCode state. This creates a split-brain where Claude Code sessions see partially-aligned SKILL.md content while the "master spec" (`pm_workflow.md`) still says "Codex-first."

## 4. User / Persona
- PM orchestrator maintainers who evolve the skill set
- Claude Code users who install these skills into their repos via injection or submodule

## 5. Goals
- Make the repo fully Claude Code-native with zero Codex/OpenCode references in active files
- Fix subagent type names to match actual Claude Code Task tool API
- Remove the "use agent swarm" convention that has no Claude Code meaning
- Provide a complete CLAUDE.md for effective Claude Code session initialization
- Clean up stale self-update state

## 6. Non-Goals
- Fixing `extract_codex_versions_from_changelog` function in `pm-command.sh` (deferred — function naming and grep pattern will be addressed in a separate task)
- Redesigning the overall orchestration architecture
- Adding new features or capabilities
- Changing the Droid worker integration pattern
- Modifying big-feature queue workflow logic

## 7. Scope (In/Out)

### In Scope
1. **Delete `.config/opencode/` directory** — remove entirely (OpenCode-only artifact)
2. **Rewrite `instructions/pm_workflow.md`** — replace title, model routing, subagent names, and all Codex/OpenCode references with Claude Code equivalents
3. **Fix subagent types in all SKILL.md files** — `explorer` → `Explore`, `worker` → `default` for Claude Code Task tool contexts; keep "worker" when referring to Droid worker *roles*
4. **Remove "use agent swarm" convention** — delete all mandatory prompt prefix requirements and references across SKILL.md files and pm_workflow.md
5. **Update `AGENTS.md`** — change workflow source path from `.config/opencode/instructions/pm_workflow.md` to `instructions/pm_workflow.md`
6. **Enrich `CLAUDE.md`** — add project description, hybrid architecture summary, directory structure, available skills, and conventions
7. **Reset `.claude/pm-self-update-state.json`** — clear dead OpenAI URLs from `sources` field, update field names from `*codex*` to `*claude_code*`
8. **Update `docs/INSTALL_INJECT_WORKFLOW.md`** — remove `.codex` section header reference, remove `.config/opencode/` from copied files list
9. **Update `scripts/inject-workflow.sh`** — remove logic that copies `.config/opencode/` to target repos

### Out of Scope
- `pm-command.sh` function renaming or changelog parsing logic
- Droid MCP server script (`scripts/droid-mcp-server`)
- PRD template or beads.md content changes
- Big-feature queue manifest schema changes
- Reference prompt files (`references/*.md`) — unless they contain Codex/OpenCode/agent-swarm references

## 8. User Flow

### Happy Path
1. Maintainer pulls latest changes after this cleanup
2. All SKILL.md files reference correct Claude Code subagent types (`default`, `Explore`, `Plan`)
3. `instructions/pm_workflow.md` describes Claude Code-native model routing and orchestration
4. Claude Code sessions load enriched CLAUDE.md with full project context
5. `inject-workflow.sh` installs skills without copying `.config/opencode/`
6. Self-update state file reflects Claude Code URLs

### Failure Paths
1. If a SKILL.md frontmatter is malformed after edit → Claude Code fails to load the skill → caught by acceptance criteria #6
2. If subagent type is wrong (e.g., leftover `explorer`) → Task tool call fails at runtime → caught by acceptance criteria #3
3. If inject script still copies `.config/opencode/` → target repos get stale files → caught by acceptance criteria #8

## 9. Acceptance Criteria (testable)
1. `grep -ri "codex" instructions/ AGENTS.md CLAUDE.md docs/INSTALL_INJECT_WORKFLOW.md` returns zero matches
2. `grep -ri "opencode" instructions/ AGENTS.md CLAUDE.md docs/INSTALL_INJECT_WORKFLOW.md skills/` returns zero matches (excluding git history)
3. `grep -rn "subagent_type.*explorer\|subagent_type.*worker\|: .explorer.\|: .worker." skills/` returns zero matches in Task tool subagent contexts
4. `grep -ri "use agent swarm" skills/ instructions/` returns zero matches
5. `.config/opencode/` directory does not exist
6. All SKILL.md files have valid YAML frontmatter (parseable by any YAML parser)
7. `.claude/pm-self-update-state.json` contains no `openai.com` or `openai/codex` URLs and field names use `claude_code` not `codex`
8. `scripts/inject-workflow.sh` does not reference `.config/opencode` in its copy targets
9. `CLAUDE.md` contains at minimum: project description, architecture summary, available skills list, directory structure overview
10. `AGENTS.md` line 13 references `instructions/pm_workflow.md` (not `.config/opencode/`)
11. `instructions/pm_workflow.md` specifies `claude-opus-4-6` (not `openai/gpt-5.3-codex`) for model routing
12. `docs/INSTALL_INJECT_WORKFLOW.md` has no `.codex` directory references

## 10. Success Metrics (measurable)
- Zero Codex/OpenCode grep matches across in-scope files (binary pass/fail)
- Zero incorrect subagent type references in SKILL.md files (binary pass/fail)
- CLAUDE.md word count > 100 (enriched from current 23 lines)

## 11. BEADS

### Business
- Eliminates confusion for new contributors/users encountering stale Codex references
- Unblocks correct self-update state tracking

### Experience
- Claude Code sessions start with richer project context via enriched CLAUDE.md
- Skill invocations use correct subagent types, preventing runtime errors

### Architecture
- Single source of truth: `instructions/pm_workflow.md` aligned with SKILL.md files, both targeting Claude Code
- No more split-brain between OpenCode and Claude Code conventions
- Subagent type mapping: Senior Engineer → `Explore`, all Claude-native roles → `default`, Droid workers → via MCP (not Task tool)

### Data
- `.claude/pm-self-update-state.json` schema reset with correct URLs and field names

### Security
- No security impact — this is a documentation/configuration cleanup

## 12. Rollout / Migration / Rollback
- **Rollout:** Single branch, all changes committed together. Run `inject-workflow.sh` on target repos to propagate.
- **Migration:** Target repos that previously received `.config/opencode/` from injection can safely delete it manually or will stop receiving it on next inject.
- **Rollback:** `git revert` the commit. Re-run injector from previous version if target repos need rollback.

## 13. Risks & Edge Cases
- **Risk:** Reference prompt files (`references/*.md`) may contain "agent swarm" or Codex references not caught in initial audit → **Mitigation:** Run grep across all `references/` directories as part of implementation.
- **Risk:** `inject-workflow.sh` may have `.config/opencode` logic interleaved with other copy logic → **Mitigation:** Read the full script and test with `--dry-run` after changes.
- **Risk:** The `pm-command.sh` extraction function still greps for "codex" → **Mitigation:** Documented as out-of-scope; tracked as a separate follow-up task.
- **Edge case:** The state file field rename (`codex_version` → `claude_code_version`) could break the `migrate_state_v1_to_v2` function → **Mitigation:** Review migration function before renaming fields.

## 14. Open Questions
(none)

## 15. Smoke Test Plan

### Happy Path Tests
- [ ] `grep -ri "codex\|opencode" instructions/ skills/ AGENTS.md CLAUDE.md docs/INSTALL_INJECT_WORKFLOW.md` returns zero matches
- [ ] All 5 SKILL.md files have parseable YAML frontmatter
- [ ] `instructions/pm_workflow.md` references `claude-opus-4-6` model routing
- [ ] CLAUDE.md has project description, architecture, skills, directory structure sections

### Unhappy Path Tests
- [ ] `scripts/inject-workflow.sh --dry-run --repo /tmp/test-repo` does not mention `.config/opencode/` in output
- [ ] `.claude/pm-self-update-state.json` contains no `openai.com` URLs

### Regression Tests
- [ ] All SKILL.md `name` and `description` frontmatter fields preserved
- [ ] Phase gate rules (approval tokens, Open Questions) preserved in `pm_workflow.md`
- [ ] Beads integration references preserved
- [ ] Droid worker context contract preserved (role-level "worker" references are correct)
- [ ] Big-feature queue workflow logic unchanged

## 16. Alternatives Considered
| Option | Description | Tradeoff |
|--------|------------|----------|
| **A: Full cleanup (chosen)** | Remove OpenCode entirely, go Claude Code-native | Clean codebase; no backward compat for OpenCode |
| B: Dual-runtime support | Keep .config/opencode/ synced alongside Claude Code | More maintenance; confusing source of truth |
| C: Minimal fix | Only fix subagent types and state file | Leaves stale Codex references for future confusion |
