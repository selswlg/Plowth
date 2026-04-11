# ISS-006: Backend sync API and reconciliation are missing

| Field | Value |
|---|---|
| Status | Closed |
| Severity | Critical |
| Phase | Phase 4 |
| Created | 2026-04-11 |
| Owner | Unassigned |
| Parent | [ISS-001](ISS-001_offline-sync-not-implemented.md) |

## Summary

The backend now exposes the sync contract required by the Phase 4 design.
`/sync/push` and `/sync/pull` exist, event processing is idempotent, and server-authoritative reconciliation now returns memory-state updates for accepted review events.

## Evidence

- `backend/app/models/__init__.py` defines `SyncEvent`.
- `backend/app/main.py` now registers the sync router.
- The implemented sync contract now matches the device-scoped push/pull design with pull deltas.
- Scripted sync evidence now exists at `docs/validation/phase4-sync-scripted-evidence-2026-04-11.md`.
- Manual device-path evidence now exists at `docs/validation/phase4-mobile-device-evidence-2026-04-12.md`.

## Impact

- The original backend sync API gap is closed.
- Remaining risk is limited to future regressions, not missing sync primitives.

## Required Work

- [x] Add sync request and response schemas for push and pull payloads
- [x] Add `/api/v1/sync/push` endpoint
- [x] Add `/api/v1/sync/pull` endpoint
- [x] Persist processed client events keyed by `client_event_id` and `device_id`
- [x] Skip duplicate events without generating duplicate reviews
- [x] Recompute or reconcile `MemoryState` from accepted review events
- [x] Return changed cards, memory states, and preferences for pull requests
- [x] Cover the sync API with backend tests

## Validation

- [x] Backend tests cover first-write and duplicate-write behavior for identical `client_event_id`
- [x] Backend tests cover a pull request that returns changes since `last_sync_at`
- [x] A manual or scripted sync push returns updated memory state payloads for accepted review events

## Implementation Notes

- `sync_service.py` now shares the review reconciliation path with the direct `/reviews` API.
- Push responses acknowledge processed and skipped event IDs and return updated card and memory-state payloads.
- Pull responses now return changed cards, memory states, and user preferences since the last sync timestamp.
- `backend/test_phase2_services.py` now includes unit coverage for duplicate client-event skipping and `since`-filtered pull delta queries.
- The backend sync path also now tolerates duplicate legacy rows in review-adjacent tables so replayed mobile events do not stall the queue.
