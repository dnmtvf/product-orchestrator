# Universal Claude Agent Source-of-Truth Sync

## Title
Universal Claude Agent Source-of-Truth Sync

## Date
2026-03-25

## Owner
PM Orchestrator

## Problem
The orchestrator keeps its role contracts in repo-owned prompt/reference files, but the active Claude MCP runtime does not currently consume those files as Claude project agents. The current `claude-code` MCP wrapper shells out to `claude -p --agent <name>`, maps generic PM launcher types to Claude agent names, and relies on Claude's runtime behavior at execution time.

That creates two gaps:
- changes to orchestrator role descriptions do not automatically become Claude project-agent definitions
- setup and install docs still describe a more generic `claude mcp serve` registration path, while the live Codex-side runtime in this repo uses a repo-owned wrapper command

The user goal is to make Claude-side agent behavior universal and repo-owned, ideally so that changing the orchestrator's agent description updates the Claude MCP path automatically. The plan must determine whether Claude project agents are compatible with the current wrapper and whether symlinks are the right mechanism.

## Context / Current State
- The current PM routing matrix sends several support/review roles through `claude-code-mcp` in `dynamic-cross-runtime` mode.
- The current `codex mcp list` output in this repo shows `claude-code` registered to a repo-owned wrapper command:
  - `/Users/d/.codex/worktrees/9d3c/product-orchestrator/skills/pm/scripts/claude-code-mcp`
- That wrapper launches a Python MCP server, which in turn shells out to:
  - `claude -p --agent <mapped-name> <prompt>`
- The wrapper currently maps generic PM launcher types to Claude agent names:
  - `default` -> `default`
  - `explorer` -> `Explore`
  - `worker` -> `general-purpose`
  - plus passthrough support for Claude-native names such as `Plan`
- Official Anthropic Claude Code docs confirm:
  - Claude supports project-scoped agents in `.claude/agents/*.md`
  - `claude --agent <name>` and `claude agents` use those definitions
  - project agents override lower-priority definitions when names collide
- Local runtime evidence confirms:
  - `claude --version` works in the current PM runtime
  - `claude agents` currently reports:
    - user agent: `default`
    - built-in agents: `Explore`, `general-purpose`, `Plan`, `statusline-setup`
  - this repo currently has no committed `.claude/agents/` directory
- The orchestrator's canonical role prompts currently live in repo-owned reference files such as:
  - `skills/pm/references/*.md`
  - `skills/pm-implement/references/*.md`
- Those canonical prompt files are not Claude project-agent files today:
  - they do not use Claude agent YAML frontmatter
  - they are organized by PM role contract, not by Claude agent name
- Install docs intentionally avoid symlink-dependent runtime assets for target repos:
  - `docs/INSTALL_INJECT_WORKFLOW.md`
  - `docs/INSTALL_SUBMODULE_WORKFLOW.md`
  - both explicitly say copied runtime assets are preferred over symlinks in installed repos
- Several active docs still instruct users to register Claude with:
  - `codex mcp add claude-code -- claude mcp serve`
  even though the live helper logic in `skills/pm/scripts/pm-command.sh` now computes a repo-owned wrapper path instead.

## User / Persona
- PM orchestrator maintainers who own runtime contracts and prompt files.
- Engineers running PM flows in Codex workspaces who need Claude-routed roles to follow repo-owned behavior.
- Operators installing the orchestrator into other repos and expecting setup docs to match the real runtime contract.

## Goals
- Confirm whether Claude project agents are compatible with the current Claude MCP wrapper path.
- Establish one repo-owned source of truth for Claude-facing agent descriptions and prompts.
- Ensure changes to the orchestrator's canonical role descriptions flow automatically into Claude-routed execution behavior.
- Ensure Claude project agents are demonstrably functional end-to-end by implementation completion, not just generated on disk.
- Keep the public PM launcher contract unchanged:
  - generic types only
  - role-labeled context
  - no public dependence on named Claude launcher APIs
- Align docs and setup instructions with the actual wrapper-based Claude MCP registration path and the chosen agent-sync mechanism.
- Keep source-repo and installed-target-repo behavior explicit and testable.

## Non-Goals
- Replacing the public PM contract with named Claude agents.
- Making `~/.claude/agents` the canonical shared source of truth.
- Requiring installed target repos to depend on symlinks across repo boundaries.
- Redesigning PM role prompts beyond what is needed to define a canonical sync source.
- Changing routing policy, approval gates, or Beads workflow as part of this work.

## Scope

### In-Scope
- Define whether the current wrapper can use Claude project agents.
- Choose the canonical source for Claude-facing role definitions.
- Define how `.claude/agents` artifacts are produced and kept in sync from repo-owned prompt sources.
- Decide whether built-in Claude agent names should be overridden at project scope or whether the wrapper should add an internal role-to-Claude-agent mapping.
- Update setup/install documentation so it reflects:
  - wrapper-based `claude-code` registration
  - project `.claude/agents` expectations
  - sync behavior for source repo and installed target repos
- Add validation or smoke coverage so agent drift is detectable.

### Out-of-Scope
- Broad prompt enrichment unrelated to Claude agent sync.
- User-global Claude customization outside this repo.
- A new public PM API that exposes named Claude agents to users.
- Runtime asset symlink strategies for injected/submodule target repos when copy/generation is sufficient.

## User Flow

### Happy Path
1. A maintainer updates a canonical orchestrator role prompt in the repo.
2. The repo's Claude-agent sync mechanism materializes the corresponding project agent definition under `.claude/agents/`.
3. `claude agents` in the repo shows the project agent as active for the relevant Claude agent name.
4. The `claude-code` MCP wrapper invokes `claude -p --agent <name> ...`.
5. Claude resolves the project agent definition automatically and executes with repo-owned instructions.
6. The same install/sync flow produces valid Claude-agent artifacts in injected or submodule-based target repos without manual per-repo copying.

### Failure Paths
1. The canonical prompt source changes but `.claude/agents` is not refreshed.
2. Claude runs a stale agent definition and routed role behavior drifts from repo intent.

3. The implementation relies on raw symlinks from source-repo prompt files into target repos.
4. Install or workspace environments with symlink limitations fail or become non-portable.

5. The wrapper continues to target built-in Claude agent names without project overrides or internal remapping.
6. Claude ignores the orchestrator's updated role contract and falls back to built-in behavior.

7. Docs continue to advertise `codex mcp add claude-code -- claude mcp serve` as the orchestrator setup path.
8. Users configure the wrong command and the live PM runtime diverges from documented setup.

## Acceptance Criteria
1. Discovery outcome is encoded in docs and implementation scope:
   - Claude project agents are compatible with the current wrapper because the wrapper uses `claude -p --agent ...`.
2. The repo has one explicit canonical source for Claude-facing role descriptions/prompts.
3. `.claude/agents/` artifacts are derived from that canonical source by a deterministic repo-owned mechanism.
4. The chosen sync mechanism does not require manual copy-paste duplication of agent descriptions.
5. The public PM launcher contract remains generic:
   - `default`
   - `explorer`
   - `worker`
6. Claude-routed execution uses project agent definitions only as an internal backend detail.
7. The implementation selects one of these internal strategies and documents it explicitly:
   - override the Claude agent names the wrapper already uses at project scope
   - or add an internal role-to-Claude-agent mapping layer while keeping the public PM contract generic
8. The implementation does not require installed target repos to depend on cross-repo symlinks.
9. If repo-local symlinks are used anywhere, they are limited to same-repo artifacts where the source files are already Claude-agent compatible and the behavior is covered by validation.
10. Source-repo docs and target-repo install docs both reflect the real orchestrator registration path for `claude-code`.
11. The following docs are updated as part of implementation:
   - `README.md`
   - `docs/MCP_PREREQUISITES.md`
   - `docs/INSTALL_INJECT_WORKFLOW.md`
   - `docs/INSTALL_SUBMODULE_WORKFLOW.md`
   - any active PM runtime-contract docs that still describe the stale bare-command setup
12. A validation path exists to catch drift between canonical prompt sources and `.claude/agents` artifacts.
13. Smoke coverage exists for:
   - happy path agent resolution
   - stale/missing agent artifacts
   - installed-target-repo sync behavior
14. Implementation is not considered complete unless Claude project agents are verified as actually runnable through a dummy end-to-end task, with the returned response checked against an expected token or expected structured content.
15. The dummy verification task must exercise the real Claude-agent resolution path used by the orchestrator rather than only checking file presence or `claude agents` listing output.
16. `Open Questions` is empty before implementation handoff.

## Success Metrics
- 100% of Claude project-agent definitions used by the orchestrator come from repo-owned canonical sources.
- 0 manual copy-only agent descriptions that can silently drift from the canonical prompt source.
- 0 active setup docs that describe the wrong `claude-code` registration command for the orchestrator runtime.
- 100% of smoke checks for Claude-agent sync and resolution pass in source-repo and installed-repo contexts.
- 100% of implementation-completion checks include a passing dummy Claude-agent task with verified response output.
- 0 public PM workflows require users to know or select named Claude agents directly.

## BEADS

### Business
- Reduces maintenance cost and runtime drift when Claude-routed behavior changes.

### Experience
- Maintainers update one repo-owned prompt source instead of hand-editing separate Claude agent files.
- Operators follow setup docs that match the real runtime contract.

### Architecture
- Keep PM's public contract generic and orchestrator-owned.
- Use Claude project agents only as an internal compatibility layer behind the wrapper.
- Prefer deterministic generation/sync over raw symlink dependency for portable installed repos.
- Allow project-scope overriding of wrapper-targeted agent names only when it is explicit and tested.

### Data
- Treat canonical prompt files and generated `.claude/agents` artifacts as traceable, comparable repo assets.
- Add drift detection so mismatches are visible before runtime execution.

### Security
- Avoid hidden user-global agent behavior becoming the runtime source of truth.
- Keep setup deterministic and repo-scoped rather than dependent on undocumented local user config.

## Rollout / Migration / Rollback
- Rollout:
  - implement the chosen canonical-source + sync mechanism
  - add project `.claude/agents` support
  - update docs and smoke coverage
- Migration:
  - distinguish generic Anthropic `claude mcp serve` guidance from the orchestrator's repo-owned wrapper registration
  - move any Claude-facing prompt duplication under the canonical sync mechanism
  - keep target-repo installers copy/generation based rather than symlink dependent
- Rollback:
  - remove project `.claude/agents` integration
  - fall back to the current wrapper-plus-inline-prompt behavior
  - preserve the generic PM public contract

## Risks & Edge Cases
- Risk: a direct symlink plan is chosen without first converting the source files into Claude-agent-compatible Markdown with required frontmatter.
- Risk: project agent overrides collide with user-level agents or built-ins in ways that are not explicitly tested.
- Risk: wrapper behavior and docs continue to drift because registration logic now lives in helper code while older docs still show the bare `claude mcp serve` command.
- Risk: install flows that intentionally avoid symlinks are undermined by a solution that only works in the source repo.
- Risk: only `default` is overridden while other wrapper-targeted names (`Explore`, `general-purpose`, optionally `Plan`) remain built-in, producing partial sync and confusing behavior.
- Edge case: the repo may choose an internal role-to-Claude-agent mapping instead of overriding built-in names; this is valid only if the public PM interface remains unchanged and the mapping is explicit, deterministic, and covered by tests.
- Edge case: built-in name overriding may work for some agent names but not all; implementation must verify actual runtime precedence with `claude agents` and smoke tests instead of assuming symmetry.

## Open Questions
None.

## Alternatives Considered

### Option 1: Direct symlink from current orchestrator prompt files into `.claude/agents/`
- Pros:
  - immediate auto-update behavior in the source repo
  - minimal moving parts if the source files are already Claude-agent compatible
- Cons:
  - the current canonical files are not Claude-agent files
  - installed target repos intentionally avoid symlink-dependent runtime assets
  - weak portability for copy-based install modes
- Status: Rejected as the universal mechanism.

### Option 2: Keep the current wrapper and do nothing about project agents
- Pros:
  - lowest implementation effort
  - no new repo layout
- Cons:
  - Claude behavior remains decoupled from repo-owned agent definitions
  - docs remain misleading
  - no automatic update path when role descriptions change
- Status: Rejected.

### Option 3: Repo-owned canonical prompts plus deterministic `.claude/agents` sync
- Pros:
  - preserves one source of truth
  - works with source repo and copy-based installed repos
  - keeps PM public contract generic
  - allows either project-scope built-in-name overrides or internal mapped agent names
- Cons:
  - requires sync/generation logic and validation
  - adds one more repo-managed artifact surface
- Status: Selected.

## Smoke Test Plan
- Happy path:
  - Verify `claude agents` in the source repo shows the expected project agent definitions as active.
  - Verify the `claude-code` MCP wrapper resolves the expected project agent when invoked through the PM path.
  - Verify changing the canonical prompt source and rerunning the sync step updates the Claude project agent artifact deterministically.
  - Verify an installed target repo gets the same working `.claude/agents` artifacts after install/sync.
  - Verify a dummy Claude-agent task runs end-to-end through the real orchestrator/wrapper path and returns an expected response that is explicitly checked.
- Unhappy path:
  - Delete or stale one generated `.claude/agents` file and verify validation fails clearly.
  - Verify target-repo install still works in a mode where symlinks are not relied on.
  - Verify docs no longer tell users to register the wrong `claude-code` command.
  - Verify the dummy functional test fails clearly when agent sync is stale or the resolved Claude agent is not actually active.
- Regression:
  - Verify PM still exposes only generic launcher types publicly.
  - Verify Claude-routed behavior does not silently fall back to user-global agents when project agents are expected.
  - Verify wrapper contract and setup docs stay aligned with helper output.
