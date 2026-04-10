# plowth_app

AI-powered learning operating system

## Local API

The app expects the FastAPI backend at:

- Android emulator: `http://10.0.2.2:8000/api/v1`
- iOS simulator / desktop: `http://127.0.0.1:8000/api/v1`

Override it when needed:

```bash
flutter run --dart-define=PLOWTH_API_BASE_URL=http://127.0.0.1:8000/api/v1
```

## Current mobile scope

- onboarding flow
- guest session creation through `POST /auth/guest`
- local persistence for onboarding state, device id, and auth tokens
## 2026-04-11 Update

- Current flow includes onboarding, guest session creation, access-token refresh before study API calls, home snapshot, titleless text capture, CSV file import with column mapping, URL capture, PDF upload, transient capture status feedback, Review tab auto-refresh, domain-aware review labels, domain-specific card editing from Home, Cognitive Update in Insight, home generation status, review flow, and local persistence.
- Phase 3 now starts with the Insight snapshot tab: daily metrics, weak concepts, and coaching guidance.
- Local checks completed:
  - `flutter test` -> 8 tests passing
  - `flutter analyze` -> no issues found
- Known gaps: Android signing, full sync completion, and scanned PDF/OCR capture.
