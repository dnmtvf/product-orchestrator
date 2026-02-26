# Multi-PRD Queue Workflow Contract

This document defines the persisted queue state model for `$pm plan big feature:` runs.

## Queue Manifest Location
- Feature queue manifests live under `docs/prd/_queue/`.
- One manifest file per big-feature run:
  - `docs/prd/_queue/<feature-slug>.json`

## Canonical Queue Unit
- Queue unit for runnable work is Beads epic ID.
- Each manifest item must map one PRD to exactly one canonical queue handle.

## Required State Model
Per-PRD lifecycle states:
- `pending`
- `in_discovery`
- `awaiting_prd_approval`
- `awaiting_beads_approval`
- `approved`
- `queued`
- `queue_failed`

## Runnable Promotion Rule
- PRD can be promoted to `queued` only after:
  - PRD approval gate = exact `approved`
  - Beads approval gate = exact `approved`
  - PRD `Open Questions` is empty
- If promotion is blocked, keep explicit non-runnable state:
  - missing PRD approval -> `awaiting_prd_approval`
  - missing Beads approval -> `awaiting_beads_approval`
  - open questions remaining -> `approved` with `blocked_reason=open_questions`

## Idempotency Contract
- Idempotency key format:
  - `<prd_slug>:<approval_version>`
- `approval_version` increments when an already-approved PRD is edited and re-approved.
- Queue promotion must reject duplicate idempotency keys.
- Queue promotion must reject duplicate active runnable entries for the same PRD slug.

## Async Worker Contract
- Queue enqueue is asynchronous with bounded concurrency.
- Required worker cap: `2` concurrent enqueue workers.
- Workers may pick only PRDs that satisfy Runnable Promotion Rule.
- Worker ordering should be deterministic to keep retries reproducible.

## Retry Policy
- One automatic retry on enqueue failure.
- If retry fails, set state to `queue_failed` and require manual intervention.

## Queue-Ready Definition
A PRD is queue-ready only if all are true:
- state is `queued`
- queue handle is present
- readiness checks pass (selectable work + `doctor` preflight)

## Reconciliation Output Contract
At end of big-feature planning, output both:
- Per-PRD reconciliation rows:
  - `prd_slug`, `state`, `epic_id`, `blocked_reason`, `last_error`
- Aggregate counts:
  - `discovered`
  - `approved`
  - `queued`
  - `queue_failed`

## Recommended Manifest Schema
```json
{
  "feature_slug": "2026-02-26--example-big-feature",
  "mode": "conflict-aware",
  "created_at": "2026-02-26T00:00:00Z",
  "updated_at": "2026-02-26T00:00:00Z",
  "worker_cap": 2,
  "items": [
    {
      "prd_slug": "2026-02-26--example-prd-a",
      "prd_path": "docs/prd/2026-02-26--example-prd-a.md",
      "epic_id": "product-orchestrator-w123",
      "state": "awaiting_prd_approval",
      "approval_version": 1,
      "idempotency_key": "2026-02-26--example-prd-a:1",
      "retry_count": 0,
      "blocked_reason": "",
      "last_error": "",
      "readiness": {
        "selectable": false,
        "doctor_pass": false
      }
    }
  ]
}
```
