# PRD

## 1. Title, Date, Owner
- Title: Claude Alignment Fixes + Orchestration Simplification
- Date: 2026-03-01
- Owner: philadelphia

## 2. Problem
The hybrid Claude + Droid orchestrator refactor (`5bba83a`) introduced confirmed bugs and architectural gaps:
1. The Droid MCP server will not start as documented — the `--mcp` flag is required but omitted from every install command. The entire Droid worker tier is currently non-functional.
2. The SKILL.md still declares "Codex-first" runtime, inverting the hybrid architecture goal.
3. README and SETUP have no Droid setup instructions — users cannot onboard the worker tier.
4. The orchestration contract routes Claude-to-Claude communication through an MCP bridge (`claude mcp serve`) that was a Codex-era compatibility shim. Now that Claude Code is the outer runtime, the native Task tool is the idiomatic and preferred path.
5. The droid-mcp-server response builder has JSON injection risks from unescaped bash string interpolation.
6. Droid worker spawns lack a defined context contract — workers receive insufficient context to act independently and have no explicit invitation to ask questions before proceeding.
7. Several minor residual Codex references and annotation errors remain.

## 3. Context / Current State
- PM orchestrator runs on Claude Code (Sonnet 4.6 / Opus 4.6)
- Worker roles run on Droid CLI + MiniMax-M2.5, wrapped as an MCP server
- `scripts/droid-mcp-server` implements JSON-RPC-over-stdio MCP but requires `--mcp` argv[1] to enter server mode (line 183); the documented install command omits this flag → server exits immediately on launch
- `skills/pm/SKILL.md:116` reads "PM orchestration runtime remains Codex-first; Claude is external and optional" — inverted post-refactor
- `README.md` and `SETUP.md` have no Droid section (no prereqs, no env vars, no MCP registration)
- `claude mcp serve` is used for all Claude-to-Claude subagent spawning — this was a compatibility bridge for when the outer runtime was Codex; with Claude Code as the outer runtime, the native Task tool is available and preferred
- MCP protocol version `2024-11-05` is advertised; current spec is `2025-03-26`
- `droid-mcp-server` lines 60–71 interpolate bash variables directly into JSON strings (injection risk)
- Droid worker spawns carry no standardized context block and no prompt to ask clarifying questions

## 4. User / Persona
- Developer using Conductor with Claude Code CLI as the PM orchestrator runtime
- Wants Droid/MiniMax workers to execute implementation tasks autonomously
- Needs workers to have full context and be able to surface blockers before executing

## 5. Goals
- Fix the Droid MCP server so it starts correctly as documented
- Update MCP protocol version to `2025-03-26`
- Correct the Codex-first statement in SKILL.md
- Add complete Droid setup instructions to README and SETUP
- Resolve the placeholder path in model-routing.yaml
- Simplify the orchestration contract: native Task tool for Claude-to-Claude, `claude-code` MCP as fallback only
- Fix JSON injection in droid-mcp-server response builder
- Add model enforcement note for Opus 4.6 session requirement
- Fix Task Verification model annotation
- Define and enforce Droid agent context contract (full context block + invite questions)
- Fix minor residual issues (MCP_PREREQUISITES.md header, notifications/initialized, pm-command.sh Codex URLs)

## 6. Non-Goals
- Adding new MCPs to Droid config (user handles this separately)
- Changing PM workflow phases or approval gate logic
- Modifying Beads integration
- Developing or patching the Droid CLI itself or MiniMax API
- Adding new features beyond alignment fixes

## 7. Scope (In/Out)
### In Scope
- `scripts/droid-mcp-server`: `--mcp` flag fix, MCP protocol version update, JSON injection fix, `notifications/initialized` no-op handler
- `skills/pm/SKILL.md`: Fix Codex-first statement (line 116); update Claude MCP Contract section to establish Task tool as preferred Claude-to-Claude path with `claude-code` MCP as fallback; add Droid worker context contract definition
- `skills/pm/agents/model-routing.yaml`: Resolve `<path-to-droid-mcp-server>` placeholder to `./scripts/droid-mcp-server --mcp`; add model enforcement note
- `skills/pm-implement/references/task-verification.md`: Fix model annotation to Opus 4.6
- `README.md` and `SETUP.md`: Add Droid setup section (prereqs, env vars, MCP registration command)
- `docs/MCP_PREREQUISITES.md`: Update header from "Codex CLI" to "Claude Code CLI"; update install command to include `--mcp` flag
- `skills/pm/scripts/pm-command.sh`: Update Codex changelog/npm URL references to Claude Code sources
- All reference files that document the Droid worker spawn: add standardized context block template and "ask questions before proceeding" instruction

### Out of Scope
- PM workflow phase logic
- Beads integration changes
- Droid CLI source changes
- Adding or removing MCP servers from Droid config (user-managed)

## 8. User Flow
### Happy Path
1. Developer follows README Droid setup: installs Droid CLI, sets env vars, runs `claude mcp add droid-worker -- ./scripts/droid-mcp-server --mcp`
2. Developer starts Claude Code session (`--model claude-opus-4-6` for Opus lead roles)
3. PM orchestrator (running natively in Claude Code) spawns Claude subagents via **Task tool directly** — no MCP bridge needed
4. PM spawns Droid workers via `droid-worker` MCP tool with a structured context block: task, PRD reference, DoD, scope/changed files, constraints, and explicit "ask questions before proceeding"
5. Droid worker reads full context, asks clarifying questions if any, then executes autonomously
6. PM/Team Lead collects Droid output, merges into workflow

### Failure Paths
1. `droid-mcp-server` not running → Claude Code reports MCP tool call failure; PM reports blocked state explicitly, does not silently fall back
2. Droid worker has ambiguous task → worker asks questions via structured question block before executing
3. `droid exec` fails → server returns JSON-RPC error response (not silent `|| true` swallow)
4. Session ID used after MCP server restart → `droid_get_result` returns `{"error": "Session not found: ..."}` with clear message

## 9. Acceptance Criteria (testable)
1. `./scripts/droid-mcp-server --mcp` starts and responds to `initialize` with `protocolVersion: "2025-03-26"`
2. `./scripts/droid-mcp-server` (no args, non-TTY stdin) also starts MCP server mode (TTY detection fallback)
3. `claude mcp add droid-worker -- ./scripts/droid-mcp-server --mcp` appears in `claude mcp list` output
4. `droid_run_task` with a simple prompt returns valid JSON containing `session_id`
5. `droid_run_task` with `diff_summary` containing `"` characters returns valid parseable JSON (injection fix)
6. `droid_continue` with an invalid session ID returns `{"error": "Session not found: <id>"}` not a crash
7. `notifications/initialized` message produces no error output from droid-mcp-server
8. `skills/pm/SKILL.md:116` reads "PM orchestration runtime is Claude Code (Opus 4.6 for lead roles); Droid/MiniMax-M2.5 handles cost-effective worker tasks." (or equivalent Claude-first statement)
9. SKILL.md "Claude MCP Contract" section establishes Task tool as primary path and `claude-code` MCP as fallback
10. README.md includes Droid setup section with: prereqs, env vars, `claude mcp add droid-worker -- ./scripts/droid-mcp-server --mcp`, and role-to-model table
11. `model-routing.yaml:87` `mcp_server_command` resolves to `./scripts/droid-mcp-server --mcp` (no placeholder)
12. `task-verification.md` model annotation reads `Model: Claude Opus 4.6`
13. All Droid worker spawns in SKILL.md include a context block template covering: task title, PRD ref, DoD, scope, constraints, and the sentence "If anything is unclear, ask your questions before proceeding."
14. `docs/MCP_PREREQUISITES.md` header updated from "Codex CLI" to "Claude Code CLI"
15. `pm-command.sh` Codex changelog/npm URLs replaced with Claude Code equivalents

## 10. Success Metrics (measurable)
- Droid MCP: `droid_run_task` completes end-to-end without server-exit errors: 100% pass rate on smoke tests
- JSON safety: droid-mcp-server response builder produces valid JSON for 10/10 adversarial inputs (quotes, backslashes, newlines in fields)
- Codex references: zero occurrences of "Codex-first" or "codex mcp add" in skill files post-fix
- Task tool path: SKILL.md explicitly names Task tool as primary Claude-to-Claude path in at least 1 normative statement
- Worker context: every Droid worker spawn template includes "ask questions before proceeding" phrase

## 11. BEADS
### Business
- Droid worker tier becomes actually functional (was completely blocked by the `--mcp` bug)
- Developer confidence: clear docs reduce setup friction for new contributors

### Experience
- Workers have enough context to act autonomously and surface blockers early (before wasted execution)
- Native Task tool path removes unnecessary MCP round-trip overhead for Claude-to-Claude calls

### Architecture
- Claude Code is the authoritative outer runtime; Task tool is the primary subagent spawn mechanism
- `claude-code` MCP is a compatibility fallback for non-Claude-Code environments only
- Droid MCP server is a well-defined stdio JSON-RPC server with safe JSON construction and explicit error propagation
- Droid context contract is standardized across all worker spawns: task + DoD + scope + constraints + Q&A invite

### Data
- No persistent data changes; droid-mcp-server session state remains in-process (ephemeral by design, documented)

### Security
- JSON injection eliminated from droid-mcp-server response builder (jq-escaped values)
- No new attack surface introduced

## 12. Rollout / Migration / Rollback
- Rollout: apply file edits in this repo; re-register Droid MCP with updated command; test smoke suite
- Migration: users with existing `claude mcp add droid-worker` registrations must re-add with `--mcp` flag (`claude mcp remove droid-worker && claude mcp add droid-worker -- ./scripts/droid-mcp-server --mcp`)
- Rollback: revert git changes; `claude mcp remove droid-worker` if needed

## 13. Risks & Edge Cases
- `claude mcp serve` model inheritance: lead roles inherit ambient session model; if session is started without `--model claude-opus-4-6`, lead roles run on the session default (Sonnet). Mitigation: document requirement in README; no automated enforcement possible without Claude Code API changes.
- Droid CLI `--output-format json` flag: not independently verified. If Droid does not support this flag, `droid exec` fails silently (mitigated by JSON injection fix and better error propagation). Workaround documented in SETUP.
- MCP backward compatibility: updating `protocolVersion` to `2025-03-26` in the server may reveal capability mismatches if Claude Code's MCP client requests capabilities not implemented by the bash server. Fallback: keep `2024-11-05` if integration tests show breakage.
- Session state loss: droid-mcp-server session state is in-process only. If MCP server restarts mid-workflow, `droid_continue` calls will fail. Documented as known limitation; durable session storage is out of scope.

## 14. Open Questions

## 15. Smoke Test Plan
### Happy Path
| Test | Steps | Pass Condition |
|---|---|---|
| MCP server starts | `./scripts/droid-mcp-server --mcp` then send `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{...}}` | Returns `{"protocolVersion":"2025-03-26",...}` |
| MCP registration | `claude mcp add droid-worker -- ./scripts/droid-mcp-server --mcp` | `claude mcp list` shows droid-worker |
| Task tool Claude-to-Claude | PM spawns Senior Engineer via Task tool (no MCP bridge) | Agent runs and returns output |
| Droid task with context | Spawn Droid worker with full context block | Worker acknowledges context, asks 0 questions, executes |

### Unhappy Path
| Test | Steps | Pass Condition |
|---|---|---|
| Invalid session ID | Call `droid_get_result` with nonexistent ID | `{"error":"Session not found:..."}` |
| JSON injection | Pass `diff_summary` with `"` and `\n` chars | Response is valid parseable JSON |
| No `--mcp` flag | `./scripts/droid-mcp-server` with TTY stdin | Prints usage (expected); with non-TTY stdin, enters MCP mode |
| `notifications/initialized` | Send `{"method":"notifications/initialized"}` to MCP server | No error output; message silently accepted |

### Regression
| Test | Pass Condition |
|---|---|
| Existing PM workflow phases unaffected | Full `/pm plan: test` run completes Discovery → PRD → Beads without errors |
| Approval gates unchanged | `approved` still the required exact token |
| Beads integration unchanged | `bd` commands work as before |
