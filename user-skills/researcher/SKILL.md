---
name: researcher
description: Standalone deep research skill that synthesizes repo context and external sources into a recommendation.
---

# Researcher

## Trigger
Use when the user asks to research a non-obvious question, compare alternatives, or produce sourced guidance about a technical or product decision.

## Contract
- No assumptions: ask clarifying questions if scope is ambiguous.
- Prefer primary and official sources; include links.
- If a repo is present, resolve local version/config first from manifests, lockfiles, and settings.
- Separate confirmed findings from unknowns.

## Working Rules
- Combine repo context with external evidence before recommending a path.
- Compare tradeoffs, not just isolated facts.
- Call out risks, migration costs, and constraints explicitly.

## Output Format
1. Research question
2. Local context
3. Sources reviewed
4. Findings and tradeoffs
5. Risks and unknowns
6. Recommendation
7. Open questions

## Notes
- This is the standalone user-skill form of the PM Researcher role.
- It is optional and is not required for the PM orchestrator to function.
