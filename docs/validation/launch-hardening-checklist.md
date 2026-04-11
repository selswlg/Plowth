# Launch Hardening Checklist

> Last updated: 2026-04-11 KST

## Backend

- [ ] Set `APP_ENV=production`
- [ ] Set `APP_DEBUG=false`
- [ ] Replace `JWT_SECRET_KEY` with a real secret
- [ ] Set explicit `CORS_ALLOW_ORIGINS` for the deployed web/admin origins
- [ ] Choose `JOB_EXECUTION_MODE=external` once the real worker/queue system is live
- [ ] Verify `/health` reports the expected `env` and `job_execution_mode`

## Mobile Android

- [ ] Copy `mobile/android/key.properties.example` to `mobile/android/key.properties`
- [ ] Point `storeFile` at the real upload keystore
- [ ] Fill `storePassword`, `keyAlias`, and `keyPassword`
- [ ] Confirm `flutter build apk --release` or `flutter build appbundle --release` signs with the release key

## Final Validation

- [ ] Browser requests from approved origins succeed
- [ ] Browser requests from unknown origins are rejected
- [ ] Pending generation jobs still complete when the API runs with the chosen production job system
