# ISS-002: Mobile account and profile surface is incomplete

| Field | Value |
|---|---|
| Status | Closed |
| Severity | Major |
| Phase | Phase 4 |
| Created | 2026-04-11 |
| Owner | Unassigned |

## Summary

The backend already exposes register, login, guest upgrade, and profile flows, and the mobile surface now implements and locally validates those entry points.

## Evidence

- Backend auth routes exist in `backend/app/api/auth.py:27-60` and `backend/app/api/auth.py:106-152`.
- The onboarding flow now opens register/login sheets in `mobile/lib/features/onboarding/onboarding_screen.dart`.
- The Profile tab now loads a real account screen with guest upgrade, learning-goal preferences, and logout in `mobile/lib/features/auth/account_screen.dart`.
- Automated mobile repository coverage for register/login/upgrade now exists in `mobile/test/session_repository_test.dart`.
- A recorded Android emulator validation pass now exists at `docs/validation/phase4-mobile-device-evidence-2026-04-12.md`.

## Impact

- The major product-surface gap is removed, and the core lifecycle is now validated on the local device path.
- Remaining risk is limited to future regressions rather than missing lifecycle functionality.

## Required Work

- [x] Add register and login screens on mobile
- [x] Add guest-upgrade UI using the existing backend endpoint
- [x] Replace the placeholder Profile tab with a real account/preferences surface
- [x] Add session/account state transitions that preserve local progress
- [x] Add mobile validation for register, login, upgrade, logout, and session restore flows

## Validation

- [x] Guest user can register/upgrade without losing study data on a manual device pass
- [x] Registered user can log in on a fresh app session or device
- [x] Profile/preferences changes persist and reload correctly through the new account surface
