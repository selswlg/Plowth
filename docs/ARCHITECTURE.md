# Plowth Architecture

> High-level system architecture and current implementation boundaries.
> Last updated: 2026-04-11 KST

## Product Loop

`Capture -> Generate -> Review -> Analyze -> Explain -> Insight`

## System Overview

- Mobile: Flutter app for onboarding, capture, review, insight, and local persistence.
- Backend API: FastAPI app exposing auth, sources, cards, jobs, reviews, and insights.
- Background work: local `JobRunner` for async card generation today; target production path remains Cloud Tasks plus Cloud Run jobs.
- Data stores: PostgreSQL for relational state, Redis for cache/queue support, and Drift/SQLite on device for local metadata and pending sync events.
- AI layer: orchestrator abstractions plus deterministic or cached behavior today, with model slots reserved for generation, tutor, and embedding flows.

## Runtime Components

| Layer | Current implementation | Planned production direction |
|---|---|---|
| Mobile | Flutter + Dio + SharedPreferences + Drift | Same app, with full sync, push, and billing surfaces added |
| API | FastAPI + SQLAlchemy async + Alembic | Same |
| Background jobs | In-process `JobRunner` | Cloud Tasks / Cloud Run Jobs |
| Database | PostgreSQL 16 | Cloud SQL |
| Cache | Redis 7 | Memorystore |
| AI | Orchestrator abstractions + heuristics/cached tutor | Vendor-swappable multi-model stack |

## Core Backend Modules

- `backend/app/api/auth.py`: guest, register, login, upgrade, refresh, profile
- `backend/app/api/sources.py`: `text`, `csv`, `link`, and `pdf` capture entrypoints
- `backend/app/api/jobs.py`: async job polling and retry
- `backend/app/api/cards.py`: card CRUD and tutor actions
- `backend/app/api/reviews.py`: review queue, submission, summary, history
- `backend/app/api/insights.py`: insight snapshot and cognitive update preview/apply

## Core Data Flow

1. The user submits material from mobile.
2. Backend creates a `Source`.
3. `text`, `link`, and `pdf` create a `Job`; `csv` imports cards directly.
4. Card generation writes `Concept`, `Card`, and generation metadata.
5. Review submissions update `Review`, `MemoryState`, daily queue state, and mistake/profile signals.
6. Insight and tutor endpoints read aggregated review and concept state.
7. Cognitive update can enrich existing card answers and append audit history to `Card.tags`.

## Key Data Domains

| Area | Tables |
|---|---|
| Auth/User | `users`, `subscriptions` |
| Source ingestion | `sources`, `source_chunks`, `jobs` |
| Learning graph | `concepts`, `concept_relations`, `cards` |
| Review/Scheduling | `reviews`, `memory_states`, `daily_review_queue` |
| Intelligence | `mistake_patterns`, `learning_profiles`, `interventions`, `ai_cache`, `ai_usage_log` |
| Sync | `sync_events` on server, `pending_sync_events` and `sync_metadata` on mobile |

## Mobile Architecture

- App shell: onboarding into a 5-tab main shell (`Home`, `Review`, `Capture`, `Insight`, `Profile`)
- Session layer: guest-first token bootstrap, refresh, and reset on invalidation
- Study repository: typed API boundary for sources, cards, reviews, insights, and jobs
- Local database: session metadata and future sync queue storage
- UI state: screen-local state plus repository-driven fetch/submit flows

## Current Boundaries

- Implemented: `text`, `csv`, `link`, and selectable-text `pdf` capture; async generation; review loop; insight snapshot; cached tutor; cognitive update
- Deferred: full offline sync, billing, push notifications, scanned PDF/OCR, production background infra, richer Phase 3 analytics and coaching

## Document Map

- Product requirements: [PRD](PRD.md)
- Current execution status: [STATUS](STATUS.md)
- Historical changes: [CHANGELOG](CHANGELOG.md)
- Capture design: [designs/capture-flow.md](designs/capture-flow.md)
- Sync design: [designs/sync-strategy.md](designs/sync-strategy.md)
- Context handoff: [HANDOFF](HANDOFF.md)
