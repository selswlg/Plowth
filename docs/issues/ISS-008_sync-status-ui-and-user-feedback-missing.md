# ISS-008: Sync status UI and user feedback are missing

| Field | Value |
|---|---|
| Status | Closed |
| Severity | Major |
| Phase | Phase 4 |
| Created | 2026-04-11 |
| Owner | Unassigned |
| Parent | [ISS-001](ISS-001_offline-sync-not-implemented.md) |

## Summary

The sync surface is now implemented and validated on the primary mobile flows.
Users can now tell whether work is pending, syncing, failed, or fully synced from the shared status bar.

## Evidence

- The shared sync status bar now renders above the bottom navigation in `mobile/lib/main.dart`.
- The sync state model and retry/error presentation are implemented in `mobile/lib/features/sync_manager.dart`.
- A manual Android emulator validation pass is recorded at `docs/validation/phase4-mobile-device-evidence-2026-04-12.md`.

## Impact

- The original user-feedback gap is removed.
- Remaining risk is limited to future regressions because dedicated widget coverage is still deferred.

## Required Work

- [x] Add a shared sync status model for `idle`, `pending`, `syncing`, `error`, and `synced`
- [x] Surface pending-event count and last successful sync timestamp in the mobile UI
- [x] Show recoverable failure messaging after bounded retry exhaustion
- [x] Add a manual retry action or equivalent recovery affordance
- [x] Ensure sync state is visible from the primary study or home flow, not only in debug tools
- [x] Decide to defer dedicated widget or integration tests for the sync status presentation as a non-blocking follow-up

## Validation

- [x] Pending offline work is visible in the UI before reconnect
- [x] A successful sync visibly clears the pending state
- [x] A forced failure path produces a recoverable error state instead of silent failure

## Implementation Notes

- The sync status bar is rendered globally above the bottom navigation, so the state is visible from Home, Review, Capture, and Insight.
- Dedicated widget coverage is still not present, but the launch-facing UI behavior is now manually validated and no longer blocks the sync stream.
