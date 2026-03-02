# PRD: MCP Configuration Synchronization

## Title
MCP Configuration Synchronization (Codex → Droid)

## Date
2025-03-02

## Owner
PM Orchestrator

## Problem
Currently, MCP (Model Context Protocol) server configurations exist across three environments:
- Codex IDE: Fully configured with 10 MCP servers
- Claude Code: Already synced with Codex
- Droid CLI: No MCPs configured

This creates an inconsistent development experience where Droid workers lack access to the same tools available in Codex and Claude Code.

## Context / Current State

**Source of Truth:** `/Users/d/.codex/config.toml` contains 10 MCP servers:
- context7 (npx)
- deepwiki (HTTP)
- chrome-devtools (npx)
- playwright (npx)
- serena (uvx)
- firecrawl (npx, with FIRECRAWL_API_KEY)
- github (HTTP, with GITHUB_PERSONAL_ACCESS_TOKEN)
- clickup (HTTP)
- exa (HTTP)
- excalidraw (HTTP)

**Target State:** `/Users/d/.factory/mcp.json` should have identical MCP configuration.

**User Decisions (from Discovery):**
1. Droid config: Direct write to `~/.factory/mcp.json` (bypassing CLI)
2. Sensitive data: Keep hardcoded values (no env var conversion)
3. claude-code server: Skip in sync (not applicable for Droid)
4. Rollback: Create timestamped backups before overwriting

## User / Persona
Developer who uses all three tools (Codex, Claude Code, Droid) and wants consistent MCP availability across environments.

## Goals
1. Sync all 10 MCP servers from Codex to Droid configuration
2. Preserve existing configuration functionality in all environments
3. Create timestamped backups before modifications
4. Validate MCP configurations after sync

## Non-Goals
- Converting hardcoded API keys to environment variables
- Implementing ongoing sync automation
- Modifying Codex or Claude Code configurations
- Creating source-of-truth manifest pattern

## Scope

### In-Scope
- Parse Codex `config.toml` MCP server definitions
- Generate Droid-compatible `mcp.json` format
- Create timestamped backups of existing config files
- Write new MCP configuration to `~/.factory/mcp.json`
- Validate Droid MCP server discovery after sync

### Out-of-Scope
- Modifying Claude Code configuration (already synced)
- Implementing continuous sync between environments
- Environment variable refactoring
- CLI-based Droid MCP management (using direct file writes)

## User Flow

### Happy Path
1. Developer runs sync script
2. Script reads Codex config and creates backup
3. Script generates Droid MCP configuration JSON
4. Script writes to `~/.factory/mcp.json`
5. Droid starts and all 10 MCP servers are discoverable
6. Developer verifies each MCP works via ToolSearch

### Failure Paths
- Invalid Codex config: Script reports error and exits without modifying files
- Missing required tools: Script warns but continues (MCPs fail at runtime)
- Backup failure: Script stops and reports error

## Acceptance Criteria
1. All 10 MCP servers from Codex are present in Droid `mcp.json`
2. Timestamped backups created: `~/.factory/mcp.json.backup-YYYYMMDD-HHMMSS`
3. Droid CLI can discover all MCP servers via tool listing
4. Each MCP server responds to basic ToolSearch query
5. Original Codex and Claude Code configs remain unchanged

## Success Metrics
- 10/10 MCP servers successfully synced to Droid
- 0 configuration errors during sync
- All MCPs discoverable and responsive in Droid after sync

## BEADS

### Business
- Consistent tool availability across development environments
- Reduced configuration drift between Codex, Claude Code, and Droid

### Experience
- One-time sync operation with clear success/failure feedback
- Backup mechanism for safe recovery

### Architecture
- Direct file write to Droid `mcp.json` (not using CLI commands)
- TOML-to-JSON conversion for MCP server definitions
- Schema validation per Librarian research findings

### Data
- Input: Codex TOML configuration
- Output: Droid JSON configuration
- Backup: Timestamped copies of existing `mcp.json`

### Security
- Keep hardcoded API keys (GITHUB_PERSONAL_ACCESS_TOKEN, FIRECRAWL_API_KEY) as-is
- No exposure of credentials to external systems
- Backup files have same permissions as originals

## Rollout / Migration / Rollback

### Rollout
1. Run sync script (to be created)
2. Verify MCP discovery in Droid
3. Run smoke tests

### Rollback
1. Restore from timestamped backup:
   ```bash
   cp ~/.factory/mcp.json.backup-YYYYMMDD-HHMMSS ~/.factory/mcp.json
   ```
2. Restart Droid CLI

## Risks & Edge Cases

| Risk | Mitigation |
|-------|------------|
| Invalid TOML syntax | Parse validation before any file writes |
| Missing npx/uvx commands | Warn user; continue (runtime errors will occur) |
| Backup file creation failure | Stop sync and report error |
| Droid JSON schema incompatibility | Validate JSON structure before write |
| Concurrent config modifications | Document script should be run when tools not active |

## Test Plan (from Smoke Test Planner)

### Happy-path tests
1. Droid MCP Server Discovery - All 10 MCPs discoverable
2. NPM-based MCP Functionality - context7, playwright, chrome-devtools, firecrawl respond
3. HTTP-based MCP Functionality - deepwiki, github, clickup, exa, excalidraw respond
4. Python-based MCP Functionality - serena responds
5. Environment Variable Propagation - FIRECRAWL_API_KEY, GITHUB_PERSONAL_ACCESS_TOKEN work

### Unhappy-path tests
1. Invalid Codex MCP Configuration - Sync detects and fails gracefully
2. Missing Command/Args for stdio MCP - Validation catches before write
3. Droid Settings JSON Malformation - Validation error

### Regression tests
1. Codex Config Unchanged - Source remains read-only
2. Claude Code Session State Preserved - Existing MCPs still work
3. MCP Tool Selection Still Works - ToolSearch returns relevant MCPs

## Open Questions
None
