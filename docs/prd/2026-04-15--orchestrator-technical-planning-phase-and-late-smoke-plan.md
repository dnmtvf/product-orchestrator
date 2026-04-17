# PRD

## Title
Technical Planning Phase And Late Smoke-Test Planning For PM Orchestrator

## Date
2026-04-15

## Owner
PM Orchestrator

## Problem
The current PM orchestrator pushes too much solution-shaping pressure into Discovery while also requiring smoke-test planning before a technical implementation plan exists. That creates the wrong sequencing for complex workflow changes:

- Discovery is currently questions-only and does not have a bounded way for technical reviewers to contribute implementable options.
- There is no dedicated Technical Planning phase between discovery and PRD creation.
- Smoke-test planning is currently produced during Discovery, even though the user wants that artifact to depend on a completed technical implementation plan.
- The current role map has no `tech_lead` role, so the requested multi-tech-lead planning pattern cannot be represented cleanly.

This makes the orchestrator weaker at separating product clarification from technical planning, and it prevents the final PRD and Beads plan from being anchored to one approved technical implementation plan. It also leaves an unnecessary human stop after PRD approval even when Beads decomposition is mechanically derived from the approved PRD.

## Context / Current State
Today the canonical phase order is:

`Discovery -> Technical Planning -> PRD -> Awaiting PRD Approval -> Beads Planning -> Team Lead Orchestration -> Implementation -> Post-Implementation Reviews -> Review Iteration -> Manual QA Smoke Tests -> Awaiting Final Review`

Current behavior also hard-codes these constraints:
- Discovery is questions-only and does not allow solution proposals.
- Discovery must generate a smoke-test plan and carry it into PRD creation.
- PRD creation must include a smoke-test subsection before PRD approval.
- Beads planning consumes the discovery/PRD smoke-test plan for the `Manual QA Smoke Tests` task.
- The routed-role registry defines `team_lead` but not `tech_lead`.

Discovery decisions captured for this feature:
- execution mode default for this planning run: `Dynamic Cross-Runtime`
- new canonical phase order should begin `Discovery -> Technical Planning -> PRD`
- PRD approval must be blocked until both the `Technical Implementation Plan` and `Smoke Test Plan` are written into the PRD
- PRD approval should be the last required human gate for the normal implementation flow
- Technical Planning should not start until discovery has exhausted open questions
- four parallel PM agents should reuse the existing `project_manager` role contract for now
- two discovery `tech_lead` agents may propose bounded implementation options
- Technical Planning should use four `tech_lead` agents and require consensus
- the technical output must live in a dedicated `Technical Implementation Plan` PRD section
- Beads planning must follow the approved technical plan verbatim
- smoke-test artifacts should be generated only after the technical implementation plan is completed
- big-feature dual-mode regression coverage should also move to the later smoke-planning step

## User / Persona
- Primary user: PM/workflow operator using `/pm plan` to design or modify orchestrator behavior
- Secondary user: maintainer implementing PM workflow contracts, role maps, prompts, and helper behavior
- Supporting user: implementation lead who needs Beads planning to inherit one approved technical plan without reinterpretation

## Goals
- Introduce a new canonical `Technical Planning` phase between Discovery and PRD creation.
- Keep Discovery focused on clarification while allowing bounded technical option input from discovery tech leads.
- Reuse the existing `project_manager` role as four collaborative PM instances during discovery.
- Add a new canonical `tech_lead` role for discovery and technical-planning work.
- Require two `tech_lead` agents during Discovery to help surface implementable options without replacing PM ownership.
- Require four `tech_lead` agents during Technical Planning to produce one consensus technical plan.
- Store that plan in a dedicated `Technical Implementation Plan` section in the PRD.
- Move smoke-test planning out of Discovery and generate it only after the technical implementation plan is complete.
- Require the PRD to include both `Technical Implementation Plan` and `Smoke Test Plan` before PRD approval.
- Require Beads planning to follow the approved technical plan verbatim.
- Move big-feature dual-mode regression planning (`conflict-aware`, `worktree-isolated`) into the later smoke-planning step.
- Remove the separate Beads approval gate so implementation proceeds autonomously after PRD approval and successful Beads planning.

## Non-Goals
- Changing the exact human approval token away from `approved`.
- Replacing the existing `team_lead` implementation-orchestration role with `tech_lead`.
- Allowing Beads planning to reinterpret or redesign the approved technical plan.
- Keeping the old discovery-generated smoke-test-plan behavior as a fallback path.
- Defining implementation-task details for this change inside the PRD itself; those belong to Beads planning.

## Scope

### In-Scope
- Rewrite the canonical phase order in workflow source files to:
  - `Discovery -> Technical Planning -> PRD -> Awaiting PRD Approval -> Beads Planning -> Team Lead Orchestration -> Implementation -> Post-Implementation Reviews -> Review Iteration -> Manual QA Smoke Tests -> Awaiting Final Review`
- Update discovery rules so that:
  - Discovery remains PM-owned
  - four `project_manager`-role agents collaborate during Discovery
  - two `tech_lead` agents are allowed to propose bounded implementation options
  - Discovery must continue asking questions until clarifications are exhausted before Technical Planning can start
- Introduce a new `Technical Planning` phase that:
  - runs before PRD creation
  - uses four `tech_lead` agents
  - requires consensus across those four agents
  - allows Librarian and Researcher support when needed
  - outputs one approved technical implementation plan
- Update PRD rules so that:
  - the PRD is created after Technical Planning
  - the PRD contains a dedicated `Technical Implementation Plan` section
  - the smoke-test artifact is generated after the technical plan is completed and is saved into the PRD
  - PRD approval is blocked until both sections exist
- Update Beads planning rules so the approved technical implementation plan is treated as binding input
- Remove the separate Beads approval gate and make bdui review informational only
- Update big-feature planning rules so dual-mode regression coverage is generated in the later smoke-planning step instead of Discovery
- Add new role-contract, routing, and prompt-source support for `tech_lead`

### Out-of-Scope
- Changing the downstream implementation/review/manual-QA phase order after Beads planning
- Replacing consensus with majority vote or a tie-break owner for technical planning
- Allowing Technical Planning to proceed while discovery ambiguity remains unresolved
- Preserving current smoke-test-plan placement in Discovery for compatibility

## User Flow

### Happy Path
1. User starts `/pm plan: ...`.
2. The plan gate resolves execution mode and runtime routing.
3. Discovery begins with four collaborating PM-role agents and two `tech_lead` agents.
4. PM agents own clarification; discovery tech leads contribute bounded implementation options and challenge assumptions.
5. Discovery continues until open questions are exhausted.
6. Workflow enters `Technical Planning`.
7. Four `tech_lead` agents produce and review one technical implementation plan until consensus is reached.
8. Librarian and Researcher are consulted if technical planning needs external or deep investigation support.
9. The workflow creates the PRD, including a dedicated `Technical Implementation Plan` section populated from the approved technical plan.
10. After the technical plan is complete, the workflow generates the `Smoke Test Plan` and writes it into the PRD.
11. PRD approval is requested only after both sections are present and `Open Questions` are empty.
12. After approval, Beads planning consumes the approved PRD, follows the technical plan verbatim, and hands off directly into implementation.

### Failure Paths
- If Discovery still has unresolved questions, Technical Planning cannot start.
- If the four `tech_lead` agents fail to reach consensus, the workflow remains in Technical Planning and requests further clarification or support input.
- If the PRD is drafted without the `Technical Implementation Plan` or `Smoke Test Plan`, PRD approval is blocked.
- If Beads planning attempts to deviate from the approved technical plan, the workflow treats that as a contract violation and blocks until the plan or PRD is corrected.
- If big-feature dual-mode regression coverage is missing from the later smoke-planning step, PRD approval is blocked.

## Acceptance Criteria
1. The canonical workflow source files define `Technical Planning` as a first-class phase between Discovery and PRD.
2. Discovery support rules are updated so four instances of the existing `project_manager` role collaborate during Discovery.
3. Discovery rules are updated so exactly two `tech_lead` agents may contribute bounded implementation options during Discovery.
4. Discovery no longer produces the final smoke-test artifact.
5. Discovery cannot hand off to Technical Planning until clarification questions are exhausted.
6. A new canonical `tech_lead` role exists in the role contracts and routing map.
7. Technical Planning uses four `tech_lead` agents and defines consensus as the decision rule.
8. Technical Planning may consult Librarian and Researcher when needed.
9. PRD creation occurs after Technical Planning completes.
10. The PRD template and PRD-creation rules include a dedicated `Technical Implementation Plan` section.
11. The workflow generates the `Smoke Test Plan` only after the technical implementation plan is complete.
12. PRD approval is blocked until both `Technical Implementation Plan` and `Smoke Test Plan` are present in the PRD.
13. Beads planning treats the approved technical plan as binding input and follows it verbatim.
14. Beads planning no longer waits for a separate Beads approval reply before implementation starts.
15. Big-feature workflows move dual-mode regression coverage generation from Discovery to the later smoke-planning step.
16. Discovery-, PRD-, Beads-, implementation-, and helper-text contracts are updated so they no longer reference discovery-owned smoke-test planning.

### Smoke Test Plan
- Happy path:
  - Verify Discovery runs with four PM-role agents and two discovery `tech_lead` agents.
  - Verify Technical Planning runs with four `tech_lead` agents and does not advance until consensus is reached.
  - Verify PRD creation occurs after Technical Planning and includes `Technical Implementation Plan`.
  - Verify the workflow generates `Smoke Test Plan` only after the technical plan exists.
  - Verify PRD approval is blocked until both sections are present.
  - Verify Beads planning consumes the approved technical plan without deviation.
- Unhappy path:
  - Verify Technical Planning does not start while discovery questions remain unresolved.
  - Verify PRD approval is blocked when `Technical Implementation Plan` is missing.
  - Verify PRD approval is blocked when `Smoke Test Plan` is missing.
  - Verify Beads planning blocks when its proposed graph conflicts with the approved technical plan.
  - Verify lack of consensus among the four `tech_lead` agents blocks Technical Planning.
- Regression:
  - Verify existing `approved` approval-token semantics remain unchanged for PRD approval.
  - Verify `team_lead` remains the implementation-orchestration role after Beads planning.
  - Verify big-feature `conflict-aware` and `worktree-isolated` coverage now appears in the later smoke-planning step rather than Discovery.
  - Verify manual QA still executes the approved smoke-test plan after implementation.

## Success Metrics
- 100% of `/pm plan` runs for this updated workflow enter `Technical Planning` before PRD creation.
- 0 approved PRDs under the new workflow lack either `Technical Implementation Plan` or `Smoke Test Plan`.
- 0 Beads plans under the new workflow deviate from the approved technical plan without being blocked.
- 100% of technical-planning runs use four `tech_lead` agents with explicit consensus outcome.
- 100% of discovery runs under the new workflow stop producing final smoke-test artifacts.

## BEADS

### Business
- Improves separation between product clarification and technical design.
- Gives maintainers one authoritative technical plan before task decomposition begins.
- Reduces churn from generating test plans before the technical design exists.

### Experience
- Discovery stays focused on understanding the request while still getting bounded technical challenge.
- Technical Planning becomes the clear place where implementation design is created and stress-tested.
- PRD approval reflects the actual technical plan and the actual smoke-test plan that will drive downstream work.

### Architecture
- Add a first-class `Technical Planning` phase and route it explicitly in workflow contracts.
- Reuse the current `project_manager` role for multi-PM discovery collaboration.
- Introduce a new `tech_lead` role with canonical prompt source and routing entries.
- Move smoke-test-plan ownership from Discovery to the post-technical-planning PRD step.
- Make Beads planning an execution-decomposition phase that consumes the approved technical plan rather than redesigning it.

### Data
- Update workflow source files, phase skill files, helper-script phase text, and routing contracts to persist the new phase order.
- Update the PRD template to add at least:
  - `Technical Implementation Plan`
  - `Smoke Test Plan`
- If big-feature queue state or telemetry references phase names, extend those records to recognize `Technical Planning`.

### Security
- No new secret or credential flows are introduced by this change.
- Consensus-based technical planning should still preserve fail-closed behavior when required technical clarification is missing.
- Binding Beads to the approved technical plan reduces silent scope drift between planning and execution.

## Rollout / Migration / Rollback
- Rollout:
  - update workflow source of truth first
  - update skill contracts and role maps second
  - update PRD template and helper text together
  - then add or update any prompt/reference files for `tech_lead`
- Migration:
  - existing PRDs remain valid historical artifacts
  - new workflow applies to future planning runs after the contract update lands
  - existing discovery smoke-planning references must be removed or rewritten consistently across all affected files
- Rollback:
  - restore the old phase order
  - remove `Technical Planning`
  - move smoke-test planning back into Discovery and PRD creation
  - drop `tech_lead` role usage from discovery and technical-planning contracts

## Risks & Edge Cases
- Discovery plus Technical Planning adds more coordination overhead; if not bounded carefully, planning latency will increase.
- Consensus across four `tech_lead` agents can stall if the workflow does not define how to continue when agreement is hard to reach.
- Reusing `project_manager` four times in Discovery may create duplicated questioning unless the orchestration contract explicitly partitions work.
- The new rule that Discovery must finish clarifications before Technical Planning starts must be expressed without relying solely on the PRD `Open Questions` section, because the PRD is now created later.
- Moving smoke-test planning later requires consistent changes across Discovery, PRD, Beads, helper text, and manual-QA assumptions; partial updates would leave the workflow internally contradictory.
- Big-feature queue/state contracts may need additional phase/state language if they currently assume the old phase order only.

## Open Questions
None.
