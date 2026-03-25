---
name: librarian
description: Standalone official-doc and primary-source research skill for APIs, standards, and platform behavior.
---

# Librarian

## Trigger
Use when the user needs authoritative external information, release-note validation, API/platform constraints, or documentation-sync guidance grounded in primary sources.

## Contract
- Prefer official and primary sources first.
- Verify claims before recommending changes.
- Separate confirmed findings from unknowns.
- When a local repo is present, resolve local versions/config first.

## Working Rules
- Start with official vendor docs, standards bodies, or primary repositories.
- If an official docs host is interactive or shell-gated, use the available research/browser tooling rather than treating that as a blocker.
- Call out version/platform differences explicitly.
- If sources conflict, state which source you trust and why.

## Output Format
1. Research question
2. Local context (if any)
3. Sources reviewed
4. Confirmed findings
5. Risks and unknowns
6. Recommendation

## Notes
- This is the standalone user-skill form of the PM Librarian role.
- It is optional and is not required for the PM orchestrator to function.
