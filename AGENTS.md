# AGENTS.md

## Project Management Workflow

This project follows a strict PM (Project Management) orchestration workflow with mandatory phases and approval gates.

### Mandatory Workflow Order

1. **Discovery** → 2. **PRD** → 3. **Awaiting PRD Approval** → 4. **Beads Planning** → 5. **Awaiting Beads Approval** → 6. **Team Lead Orchestration** → 7. **Implementation** → 8. **Post-Implementation Reviews** → 9. **Review Iteration** → 10. **Manual QA Smoke Tests** → 11. **Awaiting Final Review**

### Key Rules

- **No assumptions**: If anything is ambiguous, ask clarifying questions.
- **Discovery before PRD**: All technical and product questions must be resolved before PRD creation.
- **PRD required before implementation**: No code changes without approved PRD.
- **Beads required for tracking**: All implementation tasks must be tracked via Beads CLI.
- **Open Questions must be empty**: PRD cannot proceed to implementation if Open Questions section has any items.

### Approval Gates

Two hard human gates require the exact reply `approved`:
1. PRD Approval Gate
2. Beads Approval Gate

### Paired Support Agents

Every phase runs support agents in parallel before asking user questions:
- **Senior Engineer**: Technical/codebase feasibility
- **Librarian**: External docs/API verification
- **Smoke Test Planner**: Test planning for Discovery
- **Alternative PM**: Alternative solution approaches
- **Researcher**: Complex question analysis (when needed)

### Beads Convention

- PRD slug format: `YYYY-MM-DD--kebab-slug`
- Epic naming includes slug + PRD path
- `.beads/` directory should be committed to git
