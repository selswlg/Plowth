# Phase 4 Mobile Device Evidence

> Date: 2026-04-12 KST
> Operator: Local user-driven emulator validation session
> Device: Android emulator
> Backend: Local Docker PostgreSQL/Redis + local uvicorn server

## Scope

This run records the manual validation pass for the Phase 4 offline sync release gate and the mobile account/session lifecycle.
It complements the scripted backend proof in [phase4-sync-scripted-evidence-2026-04-11.md](phase4-sync-scripted-evidence-2026-04-11.md).

## Result

- Guest session bootstrap: pass
- Offline review queueing and local visibility before reconnect: pass
- Reconnect-driven sync without app restart: pass
- Sync status bar transition from `pending` to `syncing` to `synced`: pass
- Guest upgrade preserving local progress and sync queue: pass
- Logout to fresh guest session without prior-card bleed: pass
- Account A logout to Account B login without cross-account card or queue bleed: pass
- Final rerun after sync hardening fixes: pass

## Validation Notes

- Manual validation initially surfaced three defects during the session:
  - backend dotenv parsing for `CORS_ALLOW_ORIGINS`
  - explicit logout not rotating the device identity for a new guest session
  - backend sync push failing when duplicate legacy rows existed in review-related tables
- Those defects were fixed in the same session and the validation scenarios were rerun to completion.

## Evidence Summary

- Five offline reviews synced successfully after reconnect without restarting the app: yes
- Pending count returned to zero after reconnect: yes
- Review queue and home surfaces remained consistent after reconnect: yes
- Previous-account cards or pending events appeared in the next account after the fixes: no
- Session lifecycle regressions observed in the final pass: none

## Related Validation

- Manual checklist source: [phase4-sync-manual-checklist.md](phase4-sync-manual-checklist.md)
- Scripted sync proof: [phase4-sync-scripted-evidence-2026-04-11.md](phase4-sync-scripted-evidence-2026-04-11.md)
