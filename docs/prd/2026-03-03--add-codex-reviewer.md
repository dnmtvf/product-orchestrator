# Add Codex Reviewer Agent to Post-Implementation Review Pipeline

## Date
2026-03-03

## Owner
PM Orchestrator

## Problem
The post-implementation review pipeline currently has two reviewers (AGENTS Compliance and Jazz), both running on Claude Opus 4.6. There is no cross-model review layer. Adding a Codex reviewer powered by OpenAI's gpt-5.3-codex at xhigh reasoning effort provides an independent, multi-layer code review covering architecture, syntax, composition, and logic — catching issues that a single-model review ecosystem might miss.

## Context / Current State
- Post-implementation review runs two parallel reviewers: AGENTS Compliance (Claude, via Task tool with `subagent_type: "default"`) and Jazz (Claude Opus 4.6 via Task tool).
- The pipeline already has an MCP contract pattern for external model access (`claude mcp add <name> -- <command>`).
- Codex CLI supports `codex mcp-server` — the direct equivalent of `claude mcp serve`.
- The Droid MCP server (`scripts/droid-mcp-server`) provides a working template for custom MCP server wrappers.
- Engineers already produce a 4-layer checklist (architecture/syntax/composition/logic) during onboarding; this feature adds an automated post-implementation review using the same layers.

## User / Persona
- **PM Orchestrator**: needs broader review coverage and cross-model validation.
- **Team Lead**: needs structured, actionable findings from a third reviewer to feed into the iteration loop.
- **Engineers**: benefit from independent multi-layer review feedback before final QA.

## Goals
1. Add a Codex reviewer agent that runs gpt-5.3-codex at xhigh reasoning effort.
2. Spawn the Codex reviewer via `codex mcp-server` as an MCP server (mirroring the Claude MCP pattern).
3. Review implemented code across 4 layers: architecture, syntax, composition, logic (single agent, 4 sequential passes).
4. Run Codex reviewer in parallel with Jazz and AGENTS Compliance reviewers.
5. Produce structured, actionable findings that feed into Team Lead's review iteration loop.
6. Graceful degradation: if Codex MCP is unavailable, log a warning and continue with existing reviewers.

## Non-Goals
- Replacing Jazz or AGENTS Compliance reviewers.
- Running 4 parallel micro-agents (one per layer) — use sequential passes within a single agent.
- Building a custom wrapper script — use the native `codex mcp-server` command directly.
- Modifying the Codex CLI itself or managing Codex CLI installation (prerequisite).

## Scope

### In-Scope
- New Codex MCP Contract section in `skills/pm/SKILL.md` and `skills/pm-implement/SKILL.md`.
- New reference file `skills/pm-implement/references/codex-reviewer.md`.
- Update `skills/pm-implement/references/team-lead.md` to include Codex reviewer in parallel spawn.
- Update post-implementation review sections in both SKILL.md files from dual-agent to triple-agent.
- Update launcher compatibility and recommended launcher mapping sections.
- Update CLAUDE.md architecture section to document Codex reviewer role.

### Out-of-Scope
- Codex CLI installation automation.
- Codex authentication/token management.
- Custom MCP server wrapper scripts.
- Changes to Discovery, PRD, or Beads Planning phases.

## User Flow

### Happy Path
1. Implementation completes and all tasks pass verification.
2. Team Lead spawns three reviewers in parallel:
   - AGENTS Compliance Reviewer (existing, via Task tool)
   - Jazz Reviewer (existing, via Task tool)
   - Codex Reviewer (new, via `codex-reviewer` MCP tool call)
3. Codex reviewer receives changed files list, feature context, and constraints.
4. Codex reviewer runs 4 sequential layer passes (architecture → syntax → composition → logic).
5. Codex reviewer returns structured findings per layer.
6. Team Lead collects all three reviewer outputs, waits for all to complete.
7. Team Lead creates Beads iteration tasks for actionable findings from all three reviewers.
8. Iteration loop proceeds as normal.

### Failure Paths
- **Codex MCP not registered**: Team Lead logs warning "Codex reviewer unavailable: MCP server not configured", continues with Jazz + AGENTS Compliance only.
- **Codex CLI not installed**: MCP server fails to start; Team Lead logs warning with exact error, continues with existing reviewers.
- **Authentication failure**: Codex MCP returns error; Team Lead logs the auth error, continues with existing reviewers.
- **Timeout**: Codex xhigh reasoning exceeds time limit; Team Lead logs timeout, continues with existing reviewers' results only.
- **Malformed response**: Team Lead skips Codex findings, logs the parse error, continues with existing reviewers.

## Acceptance Criteria
1. `codex-reviewer` MCP server is documented with setup command: `claude mcp add codex-reviewer -- codex mcp-server`.
2. Codex reviewer reference file exists at `skills/pm-implement/references/codex-reviewer.md` with 4-layer review prompt.
3. `skills/pm-implement/SKILL.md` post-implementation review section spawns 3 reviewers in parallel.
4. `skills/pm/SKILL.md` post-implementation review section lists 3 reviewers.
5. Team Lead reference includes Codex reviewer in parallel spawn list (point 11).
6. Codex reviewer output format matches the existing finding schema (Finding ID, Severity, File path, Layer, Critique, Required fix).
7. Graceful degradation is documented: if Codex MCP is unavailable, pipeline continues with existing reviewers and logs a warning.
8. Launcher compatibility sections updated to include Codex reviewer spawn via `codex-reviewer` MCP tool call.
9. CLAUDE.md architecture section lists Codex reviewer as a worker role.

## Success Metrics
- Post-implementation reviews catch additional issues across the 4 layers that were not caught by Jazz or AGENTS Compliance.
- No increase in pipeline failure rate (graceful degradation prevents blocking).
- Team Lead iteration loop handles 3 reviewer outputs without special-case branching.

## BEADS

### Business
- Cross-model review reduces risk of shipping bugs that a single model ecosystem might miss.
- Structured 4-layer review provides comprehensive coverage matching the engineer onboarding checklist.

### Experience
- No change to user-facing workflow — the third reviewer runs automatically in parallel.
- Graceful degradation means users are never blocked by Codex availability issues.

### Architecture
- **Codex MCP Contract**: mirrors the existing Claude MCP Contract pattern.
  - Setup: `claude mcp add codex-reviewer -- codex mcp-server`
  - Config: project `.codex/config.toml` with `model = "gpt-5.3-codex"` and `model_reasoning_effort = "xhigh"`
  - Invocation: via `codex-reviewer` MCP tool call from Team Lead or PM orchestrator.
- **Single agent, 4 sequential MCP calls**: one MCP session via `codex` (first call) then 3x `codex-reply` (subsequent calls). Each call focuses on one layer (architecture → syntax → composition → logic), and subsequent calls receive prior findings for cross-reference.
- **Parallel with existing reviewers**: Team Lead spawns all 3 reviewers simultaneously.
- **Files modified**:
  - `skills/pm/SKILL.md` — add Codex MCP Contract, update reviewer sections and launcher mapping
  - `skills/pm-implement/SKILL.md` — update review orchestration from dual to triple agent
  - `skills/pm-implement/references/codex-reviewer.md` — new reference file
  - `skills/pm-implement/references/team-lead.md` — add Codex to reviewer spawn list
  - `CLAUDE.md` — add Codex reviewer to architecture section

### Data
- No new data stores. Codex findings flow through existing Beads comment and task creation patterns.
- Finding output schema adds a `layer` field (architecture/syntax/composition/logic) to the standard finding format.

### Security
- Codex MCP server runs locally via stdio — no network exposure.
- Code is sent to OpenAI's API (same security posture as using any OpenAI product).
- Authentication handled by Codex CLI's existing auth mechanism (`codex login` or API key).

## Rollout / Migration / Rollback
- **Rollout**: Add MCP registration, reference file, and skill file updates. No migration needed.
- **Prerequisite**: Codex CLI must be installed (`npm install -g @openai/codex` or `brew install --cask codex`) and authenticated.
- **Rollback**: Remove `codex-reviewer` MCP registration (`claude mcp remove codex-reviewer`), revert skill files to dual-reviewer. Graceful degradation means the pipeline works without Codex even if the skill files reference it.

## Risks & Edge Cases
| Risk | Severity | Mitigation |
|------|----------|------------|
| gpt-5.3-codex xhigh is slow (minutes per pass, 4 passes total) | Medium | Set reasonable timeouts; graceful degradation continues without Codex |
| Codex MCP server tool schema changes | Low | Reference file documents expected tool names; update if schema changes |
| 4-layer review produces contradictory findings across layers | Low | Team Lead is arbiter; contradictions are flagged in iteration tasks |
| Cost of xhigh reasoning across 4 passes | Medium | Cost is justified by review quality; can downgrade to `high` if needed |
| Codex findings overlap with Jazz/AGENTS findings | Low | Team Lead deduplicates during iteration task creation |

## Smoke Test Plan

### Happy Path
- **HP-1**: Codex MCP server starts and completes MCP initialize handshake.
- **HP-2**: Codex reviewer receives review request and returns structured findings across all 4 layers.
- **HP-3**: Codex reviewer returns clean report when no issues found.
- **HP-4**: Team Lead creates iteration tasks from Codex findings alongside Jazz/AGENTS findings.

### Unhappy Path
- **UP-1**: Pipeline continues with warning when codex binary is missing.
- **UP-2**: Pipeline continues with warning on model timeout.
- **UP-3**: Pipeline continues with warning on malformed response.
- **UP-4**: Pipeline continues with warning on authentication failure.

### Regression
- **RG-1**: Jazz reviewer still works correctly in parallel with Codex.
- **RG-2**: AGENTS Compliance reviewer still works correctly in parallel with Codex.
- **RG-3**: Team Lead iteration loop handles 3 reviewers (finding attribution is correct per reviewer).
- **RG-4**: Pipeline works normally when Codex reviewer is disabled/unconfigured.

## Alternatives Considered
1. **Wrapper script instead of native MCP server**: Adds a maintainable abstraction layer but introduces unnecessary indirection since `codex mcp-server` already provides structured MCP access natively.
2. **4 parallel micro-agents (one per layer)**: 4x token cost, marginal latency benefit since review is not on the critical user-wait path, and prevents cross-layer reference in findings. Rejected.
3. **Route through Droid MCP proxy**: Muddies Droid's responsibility (it becomes a generic model proxy). Codex CLI's native MCP server is the cleaner integration. Rejected.
4. **Direct Bash CLI exec per review**: No session state, cold-starts, unstructured output. MCP server is strictly better. Rejected.

## Open Questions
(none)
