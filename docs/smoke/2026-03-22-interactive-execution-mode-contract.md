# Interactive Execution-Mode Contract Smoke Evidence

Date: 2026-03-22
Scope: interactive `/pm` execution-mode contract vs direct helper persisted-state behavior

## Execution
Commands executed:

```bash
./scripts/test-pm-command.sh

./skills/pm/scripts/pm-command.sh help

./skills/pm/scripts/pm-command.sh execution-mode show

./skills/pm/scripts/pm-command.sh plan gate --route default
```

## Results
- PASS | `./scripts/test-pm-command.sh` completed successfully after adding contract assertions for interactive `/pm` execution-mode selection wording and direct-helper persisted-state wording.
- PASS | `./skills/pm/scripts/pm-command.sh help` now states that interactive `/pm` plan runs should ask for execution mode on every new planning invocation and pass an explicit `--mode` to the helper gate.
- PASS | `./skills/pm/scripts/pm-command.sh help` also states that selected execution mode persists in `.codex` and direct helper usage may reuse it by default when no `--mode` is supplied.
- PASS | `./skills/pm/scripts/pm-command.sh execution-mode show` reported persisted mode `dynamic-cross-runtime`.
- PASS | direct helper invocation via `./skills/pm/scripts/pm-command.sh plan gate --route default` still returned `selection_source=persisted_state`, confirming the lower-level helper default remains intact while the interactive `/pm` contract is documented separately.
- PASS | direct helper invocation still resolved Codex outer runtime and preserved Codex-native main-role routing plus Claude-MCP-routed support-role mapping under `dynamic-cross-runtime`.

## Regression Checklist
- [x] PM skill contract says interactive `/pm plan` and `/pm plan big feature` runs must ask the execution-mode question on every new planning invocation.
- [x] Workflow instruction copies describe persisted execution-mode state as the default suggested interactive choice, not as permission to skip the interactive gate.
- [x] README distinguishes interactive `/pm` behavior from direct helper behavior.
- [x] Helper help text distinguishes interactive `/pm` behavior from direct helper behavior.
- [x] Direct helper plan-gate behavior still supports persisted-state selection when no explicit `--mode` is supplied.
- [x] Existing runtime-routing semantics remain unchanged.
