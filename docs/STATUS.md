# Plowth Status Dashboard

> Last updated: 2026-04-12 KST

## One-line Status

**Phase 4 sync and the mobile account/profile lifecycle have now passed local device-side validation; the remaining launch blockers are hardening, OCR, deeper intelligence, and deferred billing work.**

## Phase Progress

| Phase | Status | Progress | Blocker |
|---|---|---:|---|
| Phase 1 Foundation + Onboarding | Done | 100% | None |
| Phase 2 Core Loop | Done | 100% | None |
| Phase 3 Intelligence | In Progress | 60% | Richer analytics, stronger tutor/coaching, and OCR are still missing |
| Phase 4 Polish & Launch | In Progress | 65% | External job infrastructure, release credential provisioning, OCR coverage, and billing still remain |

## Current Snapshot

- Backend: auth, capture ingest (`text`, `csv`, `link`, text-based `pdf`), async generation jobs, card CRUD, review queue/submission, sync push/pull APIs, insight snapshot, cognitive update, cached tutor endpoints, env-based CORS, production-mode config guards, and duplicate-row-tolerant sync reconciliation are implemented.
- Mobile: onboarding, guest session bootstrap, email register/login sheets, guest upgrade/profile surface, offline review/card-edit queueing, local sync cache, reconnect-aware sync monitoring, sync status bar, home snapshot, capture flows, review flow, Insight tab, domain-aware card editing, tutor actions, release-signing scaffolding, and device-validated account/session transitions are implemented.
- Infra: local PostgreSQL/Redis stack is available through Docker Compose; local background work currently uses the in-process `JobRunner`.
- Docs: status, changelog, issues, decisions, and validation evidence now include both scripted and manual Phase 4 validation records.

## Open Issues

| ID | Title | Severity | Owner | Link |
|---|---|---|---|---|
| ISS-004 | Launch hardening gaps remain across signing, security, and job infrastructure | Major | Unassigned | [Details](issues/ISS-004_launch-hardening-gaps.md) |
| ISS-005 | Scanned PDF and OCR ingest are still unsupported | Major | Unassigned | [Details](issues/ISS-005_scanned-pdf-ocr-ingest-missing.md) |
| ISS-010 | Phase 3 intelligence depth remains limited | Major | Unassigned | [Details](issues/ISS-010_phase-3-intelligence-depth-remains-limited.md) |
| ISS-003 | Billing and subscription integration is missing | Major | Unassigned | [Details](issues/ISS-003_billing-and-subscription-integration-missing.md) |

## Current Priorities

- [ ] ISS-004: finish launch hardening by provisioning the release keystore and replacing in-process jobs with the real worker/queue path
- [ ] ISS-005: decide and implement the OCR path for scanned PDFs
- [ ] ISS-010: deepen insight analytics and tutor/coaching beyond the current deterministic slice
- [ ] ISS-003: defer billing/subscription integration until the core non-billing launch blockers are closed

## Known Risks

- Phase 4 sync and account/session transitions now have a recorded local emulator validation pass, but dedicated sync-status widget coverage is still missing.
- Production concerns remain open: actual release keystore provisioning, deployed-origin verification, and non-local background job infrastructure.
- OCR and deeper intelligence are still outside the validated launch path.

## Quick Links

- [PRD](PRD.md) | [Architecture](ARCHITECTURE.md) | [Handoff](HANDOFF.md)
- [Capture Design](designs/capture-flow.md) | [Sync Strategy](designs/sync-strategy.md)
- [Phase 4 Sync Checklist](validation/phase4-sync-manual-checklist.md) | [Phase 4 Sync Scripted Evidence](validation/phase4-sync-scripted-evidence-2026-04-11.md) | [Phase 4 Mobile Device Evidence](validation/phase4-mobile-device-evidence-2026-04-12.md) | [Launch Hardening Checklist](validation/launch-hardening-checklist.md)
- [Issues](issues/_INDEX.md) | [Changelog](CHANGELOG.md) | [ADR-001](decisions/ADR-001_docs-system-redesign.md) | [ADR-002](decisions/ADR-002_agent-docs-autonomy.md)
