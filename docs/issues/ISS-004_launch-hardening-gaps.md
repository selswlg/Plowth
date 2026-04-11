# ISS-004: Launch hardening gaps remain across signing, security, and job infrastructure

| Field | Value |
|---|---|
| Status | In Progress |
| Severity | Major |
| Phase | Phase 4 |
| Created | 2026-04-11 |
| Owner | Unassigned |

## Summary

The app runs locally, and several launch hardening gaps are now partially addressed, but real production readiness still blocks on release credential provisioning and external job infrastructure.

## Evidence

- Android release signing now reads `mobile/android/key.properties` when provisioned, with `mobile/android/key.properties.example` checked in as the template.
- Backend CORS now uses explicit `CORS_ALLOW_ORIGINS`, and production mode rejects wildcard or missing origins in `backend/app/config.py` and `backend/app/main.py`.
- Background execution can now run in `in_process` or `external` mode, but the actual external worker/queue path is still not implemented.

## Impact

- Release builds still need a real upload keystore and release-build verification.
- Async generation reliability still depends on the final external worker/queue system being chosen and wired up.
- Production deployment safety is improved, but not fully closed until runtime config and job infrastructure are validated in a deployed environment.

## Required Work

- [x] Add proper Android release signing config and release build notes
- [x] Restrict CORS and formalize env-based production configuration
- [ ] Move async generation to the intended production infrastructure
- [x] Audit secret handling and deployment-time config
- [x] Add production hardening checklist to launch docs

## Validation

- [ ] Signed Android release build succeeds
- [ ] Production env rejects unknown origins
- [ ] Async generation works across service restarts in the chosen production job system
