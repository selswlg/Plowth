# ADR-001: Adopt the 3-tier docs system

| Field | Value |
|---|---|
| Status | Accepted |
| Date | 2026-04-11 |
| Scope | Repository documentation |

## Context

The old docs layout concentrated current state, review history, validation logs, progress tracking, and open items into `docs/STATUS_LOG.md`.
That made day-to-day scanning slow, mixed current state with historical detail, and left no dedicated place for issue or decision tracking.

## Options

1. Keep the flat docs layout and continue appending to `STATUS_LOG.md`
2. Split only `STATUS_LOG.md` into `STATUS.md` and `CHANGELOG.md`
3. Adopt the proposed 3-tier system with strategy, design, and operations docs separated

## Decision

Adopt option 3.

The repository now uses:

- Tier 1: `README.md`, `docs/PRD.md`, `docs/ARCHITECTURE.md`
- Tier 2: `docs/HANDOFF.md`, `docs/designs/*`
- Tier 3: `docs/STATUS.md`, `docs/CHANGELOG.md`, `docs/issues/*`, `docs/decisions/*`

## Rationale

- Current state needs a short dashboard, not an append-only log.
- Historical changes should stay append-only without polluting the dashboard.
- Design docs should live under a dedicated directory and be easy to discover by feature.
- Issues and decisions need stable one-file-per-topic locations.

## Consequences

- `docs/STATUS_LOG.md` is retired in favor of `docs/STATUS.md` and `docs/CHANGELOG.md`.
- Design and PRD docs move to stable English filenames and directory-based grouping.
- README and HANDOFF become link hubs into the new docs structure instead of carrying duplicated operational detail.
