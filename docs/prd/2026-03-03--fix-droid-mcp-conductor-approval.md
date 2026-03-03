# Fix Droid MCP Server Loading in Conductor Workspaces

## Date
2026-03-03

## Owner
PM Orchestrator

## Problem
The `droid-worker` MCP server fails to load in Conductor workspaces. Conductor runs Claude Code agents in parallel non-interactive workspaces where project-level `.mcp.json` servers require user approval that never surfaces. The server handshakes successfully but gets killed ~25ms later because no approval record exists. This blocks all Droid worker roles (Librarian, Smoke Test Planner, Alternative PM, Backend/Frontend/Security Engineers, Manual QA) from running during PM workflows in Conductor.

## Context / Current State
- `droid-worker` is configured in the project's `.mcp.json` (project scope) with a relative path: `./scripts/droid-mcp-server`
- Claude Code requires interactive user approval for project-scoped MCP servers from `.mcp.json`
- Conductor's non-interactive environment never surfaces this approval dialog
- MCP logs confirm: connect → handshake ✓ → `STDIO connection dropped after 0s` → `JSON Parse error` → tools fetch timeout
- All 10 globally-scoped MCP servers (configured in `~/.claude.json`) load fine in Conductor
- Droid CLI v0.65.0 is installed and fully functional
- The `droid-mcp-server` script works correctly when tested directly
- Neither `install-workflow.sh` nor `inject-workflow.sh` handle MCP registration or approval settings

## User / Persona
PM Orchestrator operators running `/pm` workflows in Conductor workspaces. They expect Droid worker roles to run automatically without manual MCP server approval steps.

## Goals
1. Droid worker MCP tools (`droid_run_task`, `droid_continue`, `droid_get_result`) load reliably in Conductor workspaces
2. Install scripts configure MCP approval settings so new setups work out of the box
3. Existing documentation reflects the updated setup flow

## Non-Goals
- Changing Conductor's MCP handling behavior
- Modifying the `droid-mcp-server` script itself (it works correctly)
- Adding droid-worker at global user scope in `~/.claude.json` (duplicates project config)
- Supporting MCP approval for arbitrary untrusted project servers

## Scope

### In-Scope
- Create `scripts/configure-conductor.sh` to set `enableAllProjectMcpServers: true` in `~/.claude/settings.json`
- Update `install-workflow.sh` to call `configure-conductor.sh` during installation
- Update `inject-workflow.sh` to call `configure-conductor.sh` during injection
- Update `docs/MCP_PREREQUISITES.md` with Conductor-specific setup notes
- Update `SETUP.md` with the approval setting requirement

### Out-of-Scope
- Modifying `scripts/droid-mcp-server` (not the root cause)
- Targeted `enabledMcpjsonServers: ["droid-worker"]` (sufficient but more complex)
- Changes to `~/.claude.json` global mcpServers section

## User Flow

### Happy Path
1. Operator runs `install-workflow.sh` or `inject-workflow.sh` on a target repo
2. Script calls `configure-conductor.sh` which sets `enableAllProjectMcpServers: true` in `~/.claude/settings.json`
3. Operator starts a Conductor workspace pointing to the target repo
4. Claude Code reads the project `.mcp.json`, finds `droid-worker`
5. Claude Code checks settings → `enableAllProjectMcpServers: true` → all project MCP servers approved
6. MCP server starts, handshakes, and stays alive
7. PM workflow invokes Droid worker roles successfully

### Failure Paths
- `~/.claude/settings.json` does not exist → `configure-conductor.sh` creates it with the setting
- `~/.claude/settings.json` exists but has `enableAllProjectMcpServers: false` → script sets to `true`
- `jq` is not installed → script warns and prints manual instructions

## Acceptance Criteria
1. `~/.claude/settings.json` contains `"enableAllProjectMcpServers": true` after running `configure-conductor.sh`
2. `install-workflow.sh` and `inject-workflow.sh` call `configure-conductor.sh` during execution
3. In a Conductor workspace with `.mcp.json` containing `droid-worker`, the MCP server's tools appear in `ToolSearch` results
4. `configure-conductor.sh` is idempotent: running twice does not cause errors
5. `docs/MCP_PREREQUISITES.md` documents the Conductor approval requirement
6. `SETUP.md` references the approval setting in the Droid worker setup section

## Success Metrics
- Droid worker MCP tools load in 100% of Conductor workspace sessions that have `.mcp.json` configured
- Zero manual approval steps required for `droid-worker` in Conductor or headless Claude Code sessions

## BEADS

### Business
Unblocks the hybrid orchestration model (Claude Opus leads + MiniMax workers) in Conductor environments. Without this fix, all Droid worker roles are non-functional in Conductor, forcing fallback to Claude-only execution at higher cost.

### Experience
Transparent to the operator. Install scripts handle the setup; no manual `settings.json` editing required.

### Architecture
- Uses Claude Code's native `enableAllProjectMcpServers` setting (documented in Claude Code settings)
- Settings file: `~/.claude/settings.json` (user-level settings, applies to all projects)
- No changes to the MCP server protocol or script
- Install scripts use `jq` for JSON manipulation (already a prerequisite for `droid-mcp-server`)

### Data
- Modified file: `~/.claude/settings.json` (JSON, typically <1KB)
- No database or schema changes

### Security
- `enableAllProjectMcpServers: true` auto-approves ALL project-level MCP servers from any `.mcp.json`
- This is a permissive setting — operators should only use it if they trust the repositories they work with
- For targeted approval, use `enabledMcpjsonServers: ["server-name"]` instead

## Rollout / Migration / Rollback
- **Rollout**: Run `configure-conductor.sh` or use `install-workflow.sh`/`inject-workflow.sh` which call it automatically. Existing setups can manually run the script or use `claude config set -g enableAllProjectMcpServers true`.
- **Migration**: No data migration. Settings file change is additive.
- **Rollback**: Set `enableAllProjectMcpServers: false` in `~/.claude/settings.json` or remove the key.

## Risks & Edge Cases
| Risk | Mitigation |
|------|------------|
| `jq` not installed on target machine | Scripts already require `jq` for `droid-mcp-server`; warn and provide manual fallback |
| `~/.claude/settings.json` has non-standard format | Use `jq` for safe JSON manipulation; validate before writing |
| `enableAllProjectMcpServers: true` is overly permissive | Document security implications; operators should only use with trusted repositories |
| User has `disabledMcpjsonServers` entries | Document that `disabled` takes precedence over `enableAllProjectMcpServers` |

## Smoke Tests

### Happy Path
- Run `configure-conductor.sh` → verify `~/.claude/settings.json` contains `enableAllProjectMcpServers: true`
- Run `install-workflow.sh` → verify it calls `configure-conductor.sh`
- Start Conductor workspace → `ToolSearch "droid"` returns `droid_run_task` tool
- Run `/pm plan:` → Droid worker roles (Smoke Test Planner, Alternative PM) execute via MCP

### Unhappy Path
- Set `enableAllProjectMcpServers: false` → verify MCP server fails to load (connection drops)
- Run install script without `jq` → verify warning message and manual instructions are printed

### Regression
- Other MCP servers (exa, context7, deepwiki, etc.) continue loading normally
- Claude Code native (non-Conductor) sessions still work with interactive approval

## Open Questions
(none)
