# Beads Planning Rules

## PRD Slug Format
- Use `YYYY-MM-DD--kebab-slug` for PRD filenames in `docs/prd/`.

## Epic Naming
- Epic title must include the PRD slug and PRD path.
- Example: `Epic: 2026-02-26--example-feature (docs/prd/2026-02-26--example-feature.md)`.

## Task Decomposition
- Create atomic tasks only.
- Every task must include a clear Definition of Done (DoD).
- Every task must be linked with explicit dependencies using `bd dep` when order matters.

## Source Of Truth
- Use Beads (`bd`) as the execution source of truth.
- Keep `.beads/` committed in git.
