# ISS-007: Mobile sync queue and reconnect loop are missing

| Field | Value |
|---|---|
| Status | Closed |
| Severity | Critical |
| Phase | Phase 4 |
| Created | 2026-04-11 |
| Owner | Unassigned |
| Parent | [ISS-001](ISS-001_offline-sync-not-implemented.md) |

## Summary

The mobile app now queues review and card-edit work locally, caches pulled cards and memory states, and runs a retry-based sync loop.
The real device UX path is now also recorded through the local Android emulator validation pass.

## Evidence

- `mobile/lib/core/database/app_database.dart` now stores pending sync events, cached cards, cached memory states, and sync metadata.
- `mobile/lib/features/study_repository.dart` now queues review submissions and card edits locally before server reconciliation.
- `mobile/lib/features/sync_manager.dart` now starts a reachability probe loop after offline failures and triggers a follow-up sync when the backend becomes reachable again.
- `mobile/test/sync_manager_test.dart` now covers offline retry state, reconnect-driven sync, pull reconciliation, and the processed-push/pull-failure regression path.
- `docs/validation/phase4-mobile-device-evidence-2026-04-12.md` records the manual Android emulator pass for queue persistence and reconnect behavior.

## Impact

- The original queue/reconnect gap is closed.
- Remaining risk is future regression coverage rather than missing reconnect behavior.

## Required Work

- [x] Queue review submission events locally instead of relying on direct online-only review submission
- [x] Queue card-edit and settings events through a shared sync event writer
- [x] Add connectivity monitoring that triggers sync when the device returns online
- [x] Implement push batching and retry policy from `pending_sync_events`
- [x] Persist `last_sync_at` and device identity consistently
- [x] Apply pulled cards, memory states, and settings into Drift tables
- [x] Mark local pending events as synced or failed with retry metadata
- [x] Add mobile tests for queueing, retry, and reconciliation behavior

## Validation

- [x] Airplane-mode review submissions are saved locally and remain visible before reconnect
- [x] Reconnect triggers push automatically without a manual app restart
- [x] Successful push removes or marks processed pending events
- [x] Pulled changes update local card and memory state records

## Implementation Notes

- The app now keeps a local cache of cards and memory states in Drift for offline review continuity.
- Sync retries now start a reachability probe loop after offline failures and trigger `syncNow()` again when the backend becomes reachable.
- Review queue and card editor now fall back to local cached data when the network is unavailable.
- `mobile/test/sync_manager_test.dart` now covers offline retry, reconnect-driven sync, pull reconciliation, and the regression where a failed pull could re-mark already processed events.
- The remaining follow-up is only deeper UI/test coverage, not missing queue or reconnect functionality.
