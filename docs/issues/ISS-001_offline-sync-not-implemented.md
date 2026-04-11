# ISS-001: Offline sync is not implemented end-to-end

| Field | Value |
|---|---|
| Status | Closed |
| Severity | Critical |
| Phase | Phase 4 |
| Created | 2026-04-11 |
| Owner | Unassigned |

## Summary

Core offline sync plumbing is now implemented across backend and mobile, and the flow has a recorded local end-to-end validation pass.
The original Phase 4 sync blocker is closed.

## Evidence

- Backend now registers `/api/v1/sync/push` and `/api/v1/sync/pull` in `backend/app/main.py:51-58`.
- Mobile review submissions and card edits now enqueue sync events and reconcile through the shared sync path in `mobile/lib/features/study_repository.dart`.
- The app now runs a retry-based sync manager and exposes a visible sync status bar in `mobile/lib/features/sync_manager.dart` and `mobile/lib/main.dart`.
- Scripted sync evidence is recorded at `docs/validation/phase4-sync-scripted-evidence-2026-04-11.md`.
- Manual emulator evidence is recorded at `docs/validation/phase4-mobile-device-evidence-2026-04-12.md`.

## Impact

- The core offline review and reconnect path is now trusted for the local release gate.
- Remaining launch confidence is now limited by non-sync concerns such as launch hardening and OCR.

## Decomposition

This issue was executed through the following child issues:

- [ISS-006](ISS-006_backend-sync-api-and-reconciliation-missing.md): backend sync API, idempotent ingestion, and server-side reconciliation
- [ISS-007](ISS-007_mobile-sync-queue-and-reconnect-loop-missing.md): mobile event queue, reconnect loop, and local reconciliation
- [ISS-008](ISS-008_sync-status-ui-and-user-feedback-missing.md): sync status UI, error states, and user-visible recovery signals
- [ISS-009](ISS-009_offline-sync-end-to-end-validation-missing.md): end-to-end validation and regression coverage

## Sprint Breakdown

| Sprint | Focus | Issue | Exit Gate |
|---|---|---|---|
| Sprint 1 | Server sync foundations | ISS-006 | `/sync/push` and `/sync/pull` exist, accept device-scoped sync payloads, and reject duplicate `client_event_id` processing |
| Sprint 2 | Mobile queue and reconnect loop | ISS-007 | Reviews and card edits are queued locally, pushed on reconnect, and pulled changes are reconciled into Drift tables |
| Sprint 3 | Product surface and failure handling | ISS-008 | Users can see sync state, pending work, and recoverable failures without silent data loss |
| Sprint 4 | Validation and release gate | ISS-009 | Offline review flows, reconnect push/pull, and duplicate-event protection are covered by repeatable validation |

## Exit Criteria

- [x] ISS-006 is closed
- [x] ISS-007 is closed
- [x] ISS-008 is closed
- [x] ISS-009 is closed
- [x] Offline review submission no longer depends on a direct online-only `/reviews` call path
- [x] A reconnect sync run updates local state from server-authoritative memory state without duplicate review creation

## Validation

- [x] Submit at least 5 reviews offline, reconnect, and confirm automatic push
- [x] Confirm pulled `MemoryState` and card updates reconcile locally
- [x] Confirm duplicate client event IDs do not create duplicate server reviews

## Implementation Notes

- Backend `/api/v1/sync/push` and `/api/v1/sync/pull` are now registered.
- Mobile review submissions and card edits now enqueue local sync events and update the local cache before server reconciliation.
- A global sync status bar with retry support is now visible above the bottom navigation.
- The final local emulator pass also validated account/session boundaries after follow-up fixes for logout rotation and duplicate-row-tolerant server reconciliation.
