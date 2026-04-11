# Phase 4 Sync Manual Checklist

> Last updated: 2026-04-12 KST

## Purpose

This checklist is the release gate for the real offline-to-online user path.
Automated tests cover sync retry, duplicate protection, and pull deltas, but this checklist proves the behavior on a running app with a real local backend.

## Latest Recorded Pass

- Status: pass
- Evidence: [phase4-mobile-device-evidence-2026-04-12.md](phase4-mobile-device-evidence-2026-04-12.md)
- Environment: Android emulator against the local backend stack

## Preconditions

1. Start infra: `cd infra && docker-compose up -d`
2. Start backend: `cd backend && set AUTO_CREATE_TABLES=true && venv\Scripts\python -m uvicorn app.main:app --host 127.0.0.1 --port 8000`
3. Start mobile against the local API:
   - Android emulator: `cd mobile && flutter run`
   - Other targets when overriding manually: `cd mobile && flutter run --dart-define=PLOWTH_API_BASE_URL=http://127.0.0.1:8000/api/v1`
4. Use a fresh guest session on the device or emulator.
5. Ensure at least 5 reviewable cards exist and have been loaded once while online so they are cached locally.

## Device Validation

1. Confirm the sync bar shows a healthy state while online.
2. Disable network on the device or emulator.
3. Review 5 cards offline.
4. Confirm each review stays visible locally and the sync bar shows pending work.
5. Re-enable network without restarting the app.
6. Confirm the sync bar clears automatically within the reconnect window.
7. Re-open the Review and Home surfaces and confirm the reviewed cards are still consistent.
8. Restart the app and confirm the synced state persists.

## Expected Results

- Offline reviews do not disappear before reconnect.
- Pending count increases while offline.
- Reconnect triggers sync without a manual restart.
- Pending count returns to zero after sync.
- Review history and next-review scheduling remain consistent after app restart.

## Scripted Cross-Check

Run the scripted API proof after or before the device pass:

`cd backend && venv\Scripts\python scripts\validate_phase4_sync.py`

This validates:

- guest auth bootstrap
- CSV import for 5 cards
- sync push with 5 review events
- duplicate `client_event_id` skip behavior
- sync pull delta for card and memory-state updates

## Evidence To Record

- Validation date and operator
- Device or emulator used
- Whether the 5 offline reviews synced without restart
- Whether pending count returned to zero
- Output of `scripts\validate_phase4_sync.py`
- Any screenshots or logs for failure cases
