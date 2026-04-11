# Plowth Changelog

## 2026-04-12

### Changes

- Hardened the mobile account/session boundary so explicit logout clears user-scoped local sync state, rotates device identity for the next guest session, and prevents prior-account cache or queue bleed.
- Hardened the mobile sync loop so push-response errors are surfaced in the sync status bar and debug logs instead of silently remaining pending.
- Hardened backend sync reconciliation against duplicate legacy rows in review-adjacent tables so replayed review events no longer fail with `scalar_one_or_none()`-style errors.
- Fixed backend dotenv parsing so comma-separated `CORS_ALLOW_ORIGINS` values load correctly under `pydantic-settings`.
- Recorded the passing local Android emulator validation evidence for offline reconnect sync and mobile account lifecycle flows.

### Validation

- `cd mobile && flutter analyze` -> no issues found after the sync/account boundary fixes
- `cd mobile && flutter test` -> 23 tests passing after session reset and push-error surfacing coverage
- `cd backend && python -m pytest backend/test_phase2_services.py -q` -> 34 tests passing after duplicate-row-tolerant sync reconciliation changes
- `cd backend && python -m pytest backend/test_launch_hardening.py -q` -> 6 tests passing after dotenv CORS parsing coverage
- Local Android emulator manual pass -> offline review reconnect sync, guest upgrade, logout-to-new-guest, and cross-account login transitions all completed without visible regressions

### Decisions

- Closed the Phase 4 sync validation and mobile account/profile validation issues based on recorded local device evidence instead of leaving implementation-complete work in a validation-pending state.

---

## 2026-04-11

### Changes

- Migrated the docs system to the proposed 3-tier structure: `STATUS`, `CHANGELOG`, `PRD`, `ARCHITECTURE`, `designs/`, `issues/`, and `decisions/`.
- Moved the PRD and design docs into stable paths and updated README/HANDOFF references to the new structure.
- Initialized the issue tracker with the current launch blockers: offline sync, mobile account/profile completion, billing, launch hardening, and scanned PDF/OCR support.
- Decomposed the offline sync blocker into child issues for backend sync APIs, mobile queue/reconnect flow, sync status UI, and end-to-end validation.
- Implemented the first Phase 4 sync slice: backend `/sync/push` and `/sync/pull`, shared review reconciliation, mobile offline queueing and local cache, retry-based sync loop, and a visible sync status bar.
- Updated sync issue tracking to reflect implemented-vs-validated status more accurately and added a dedicated issue for remaining Phase 3 intelligence depth work.
- Added reachability-based reconnect monitoring in mobile sync and automated regression coverage for sync retry, reconciliation, duplicate-event skipping, and pull delta behavior.
- Added a repeatable Phase 4 sync validation script plus a manual device checklist, and recorded a passing scripted local-stack sync evidence run.
- Reordered the active priorities so billing/subscription follows the remaining non-billing launch blockers instead of blocking current execution.
- Implemented the mobile account/profile surface: onboarding register/login sheets, guest upgrade/profile UI, learning-goal preference updates, and repository coverage for register/login/upgrade persistence.
- Hardened launch config with explicit CORS allow-lists, production-mode config guards, release-signing scaffolding via `key.properties`, a launch checklist, and a switchable `JOB_EXECUTION_MODE` for future external workers.
- Landed structured text capture expansion, transient capture submission feedback, home generation status, review auto-refresh, generation-in-progress messaging, token refresh/session reset handling, vocabulary-list generation, and scheduler null-state hardening.

### Validation

- `cd backend && python -m unittest test_phase2_services.py` -> 29 tests passing
- `cd mobile && flutter test` -> 8 tests passing
- `cd mobile && flutter analyze` -> no issues found
- `docker ps --filter name=plowth --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"` -> local PostgreSQL/Redis containers healthy
- `cd backend && python -B -m unittest test_phase2_services.py` -> 29 tests passing after sync changes
- `cd backend && python -B -m unittest test_phase2_services.py` -> 32 tests passing after sync validation coverage
- `cd backend && python -B - <<...` importing `app.main` -> `/api/v1/sync/push` and `/api/v1/sync/pull` registered
- `cd backend && venv\Scripts\python scripts\validate_phase4_sync.py` -> guest auth, CSV import, 5-event sync push, duplicate skip, and pull delta checks passed on the local Postgres-backed app
- `cd mobile && flutter analyze` -> no issues found after sync changes
- `cd mobile && flutter test` -> 12 tests passing after sync and local scheduler coverage
- `cd mobile && flutter test` -> 14 tests passing after sync manager reconnect/regression coverage
- `cd mobile && flutter analyze` -> no issues found after account/profile surface implementation
- `cd mobile && flutter test` -> 17 tests passing after adding account/session repository coverage
- `cd backend && python -B -m unittest test_launch_hardening.py` -> 5 tests passing for CORS parsing, production config guards, and job runner mode selection
- `cd backend && python -B -m unittest test_phase2_services.py` -> 32 tests still passing after launch-hardening config changes
- `cd backend && python -B - <<...` importing `app.main` -> explicit CORS origin list and `JOB_EXECUTION_MODE=in_process` resolved as expected

### Decisions

- Adopted the 3-tier docs system defined in [ADR-001](decisions/ADR-001_docs-system-redesign.md).
- Adopted autonomous documentation maintenance by default, including phase transitions when supported by repository state and validation evidence, in [ADR-002](decisions/ADR-002_agent-docs-autonomy.md).
- Initialized the issue tracker empty and kept roadmap/backlog items in `STATUS.md` until they become issue-shaped work.

---

## 2026-04-10

### Changes

- Stabilized the text capture flow: removed title input, aligned wording with product language, moved long polling responsibility out of Capture, and surfaced generation status on Home.
- Implemented Phase C CSV import, Phase D link ingest, and Phase E text-based PDF ingest.
- Implemented Phase F domain metadata and editor follow-up, Phase G concept-level priority signals, and Phase H cognitive update preview/apply.
- Added the first Phase 3 slice: insight snapshot, learning-profile/mistake tracking, and deterministic cached tutor actions.

### Validation

- Backend validation progressed from 11 to 24 passing tests across the implementation slices, and the FastAPI app loaded with 35 routes by the end of day.
- `flutter analyze` passed after each major mobile slice.
- `flutter test` reached 8 passing tests after the Phase F editor follow-up.

### Decisions

- Fixed the source ingest contract to `text|csv|link|pdf`, with dedicated CSV preview/import endpoints and multipart PDF upload.
- Deferred pgvector-based matching, image/OCR ingest, APKG import, Share Sheet, Clipboard capture, and full production sync hardening to later phases.

---

## 2026-04-09

### Changes

- Established the initial project handoff, sync strategy, PRD draft, and baseline repository documentation.

### Validation

- Initial local stack and repository structure were verified as the starting point for Phase 1 and Phase 2 implementation.

### Decisions

- Chose Plowth as the product identity, Flutter as the mobile stack, FastAPI as the backend stack, and a multi-model AI architecture with vendor-swappable slots.
