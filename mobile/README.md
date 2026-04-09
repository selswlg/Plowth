# real_app

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
