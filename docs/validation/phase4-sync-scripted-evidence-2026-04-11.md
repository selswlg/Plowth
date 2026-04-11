# Phase 4 Sync Scripted Evidence

> Date: 2026-04-11 KST
> Method: `cd backend && venv\Scripts\python scripts\validate_phase4_sync.py`

## Scope

This run validates the local backend-backed sync contract without a separate uvicorn process.
It proves the API path for guest auth, CSV import, sync push, duplicate-event skipping, and sync pull deltas.

## Result

- Guest auth: pass
- CSV import with 5 cards: pass
- Sync push with 5 review events: pass
- Duplicate `client_event_id` skip: pass
- Sync pull delta for card and memory state updates: pass
- Review history count after sync push: `5`

## Output

```json
{
  "csv_import_ok": true,
  "duplicate_skip_ok": true,
  "duplicate_skipped_count": 1,
  "guest_auth_ok": true,
  "imported_card_count": 5,
  "notes": [],
  "offline_push_ok": true,
  "processed_event_count": 5,
  "pull_delta_ok": true,
  "pulled_card_count": 1,
  "pulled_memory_state_count": 1,
  "review_history_count": 5,
  "server_timestamp": "2026-04-11T09:10:50.164740Z"
}
```

## Remaining Gap

This does not replace the real device validation path.
The release gate still requires the manual checklist in [phase4-sync-manual-checklist.md](phase4-sync-manual-checklist.md) to confirm offline reviews stay visible in the app before reconnect and that the sync bar clears on a real reconnect without restart.
