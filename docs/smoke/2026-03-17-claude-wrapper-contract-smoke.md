# Claude Wrapper Contract Smoke

Date: 2026-03-17

## Scope

Smoke evidence for the approved internal Claude wrapper boundary:

- the public PM contract remains generic subagent launchers only
- source-repo and installed-repo helper paths stay explicit and valid for their documented context
- the internal Claude wrapper validates context, renders a deterministic prompt, and normalizes success, context-needed, and unsupported-launcher outcomes
- install and inject flows ship the internal wrapper asset into both Codex and Claude runtime trees

## Happy Path Results

### Wrapper Prepare Produces A Deterministic Prompt

Command:

```bash
./skills/pm/scripts/pm-command.sh claude-wrapper prepare \
  --context-file <valid-context.json> \
  --prompt-file <wrapper-prompt.md> \
  --objective "review retry policy and latency evidence" \
  --session-id wrap-run-1 \
  --role jazz_reviewer
```

Observed:

- `CLAUDE_CONTEXT_VALID|role=jazz_reviewer|...`
- `CLAUDE_WRAPPER_READY|status=ready|role=jazz_reviewer|session_id=wrap-run-1|runtime=claude-code-mcp`
- generated prompt begins with `use agent swarm for review retry policy and latency evidence`
- generated prompt includes the internal wrapper template, role label, runtime, and context-pack JSON

Result: pass

### Wrapper Run Completes With Structured Success Output

Command:

```bash
./skills/pm/scripts/pm-command.sh claude-wrapper run \
  --context-file <valid-context.json> \
  --prompt-file <wrapper-prompt.md> \
  --objective "review retry policy and latency evidence" \
  --response-file <complete-response.txt> \
  --session-id wrap-run-2 \
  --role jazz_reviewer
```

Observed:

- `CLAUDE_WRAPPER_READY|status=ready|...`
- `CLAUDE_HANDSHAKE|status=complete|role=jazz_reviewer|session_id=wrap-run-2`
- `CLAUDE_WRAPPER_RESULT|status=complete|role=jazz_reviewer|session_id=wrap-run-2|runtime=claude-code-mcp|...|next_action=return_to_parent`

Result: pass

## Unhappy Path Results

### Wrapper Preserves Same-Session Context Requests

Command:

```bash
./skills/pm/scripts/pm-command.sh claude-wrapper run \
  --context-file <valid-context.json> \
  --prompt-file <wrapper-prompt.md> \
  --objective "review retry policy and latency evidence" \
  --response-file <context-request-response.txt> \
  --response-file <complete-response.txt> \
  --session-id wrap-run-3 \
  --role jazz_reviewer
```

Observed:

- `CLAUDE_HANDSHAKE|status=context_needed|role=jazz_reviewer|session_id=wrap-run-3`
- `CLAUDE_WRAPPER_RESULT|status=context_needed|...|needed_fields=constraints,evidence|next_action=continue_session`
- `CLAUDE_WRAPPER_RESULT|status=context_requested|...|round=1|next_action=continue_session`
- final completion result stays on the same session id `wrap-run-3`

Result: pass

### Wrapper Reports Unsupported Launcher Failures Explicitly

Command:

```bash
./skills/pm/scripts/pm-command.sh claude-wrapper evaluate \
  --context-file <valid-context.json> \
  --response-file <unsupported-launcher-response.txt> \
  --session-id wrap-123 \
  --role jazz_reviewer
```

Observed:

- exit code `6`
- `CLAUDE_WRAPPER_RESULT|status=runtime_error|error=unsupported_launcher|role=jazz_reviewer|session_id=wrap-123|runtime=claude-code-mcp`
- `detail=Agent type 'general-purpose' not found`
- `next_action=return_to_parent`

Result: pass

## Regression Checks

### Helper Path Contract Remains Explicit

Command:

```bash
./scripts/test-pm-command.sh
```

Observed:

- active docs assert all three helper-path contexts:
  - source repo: `./skills/pm/scripts/pm-command.sh`
  - installed Codex repo: `./.codex/skills/pm/scripts/pm-command.sh`
  - installed Claude repo: `./.claude/skills/pm/scripts/pm-command.sh`
- wrapper prepare/evaluate/run regression cases passed
- script ended with `[test-pm-command] PASS`

Result: pass

### Wrapper Assets Ship Through Install And Inject Flows

Command:

```bash
./scripts/test-runtime-layout.sh
```

Observed:

- injector test created:
  - `.codex/skills/pm/references/internal-claude-wrapper.md`
  - `.claude/skills/pm/references/internal-claude-wrapper.md`
- installer `--sync-only` test created the same wrapper asset in both runtime trees
- script ended with `[test-runtime-layout] PASS`

Result: pass

## Outcome

The internal Claude wrapper remains an implementation detail behind the generic PM contract, its failure modes are explicit and machine-readable, and the documented helper paths now stay aligned across source-repo and installed-repo layouts.
