# ISS-010: Phase 3 intelligence depth remains limited

| Field | Value |
|---|---|
| Status | Open |
| Severity | Major |
| Phase | Phase 3 |
| Created | 2026-04-11 |
| Owner | Unassigned |

## Summary

The repository includes an initial Phase 3 intelligence slice, but the current insight and tutor behavior is still shallow.
Richer mistake analytics, stronger coaching logic, and a more capable tutor path are still missing.

## Evidence

- `docs/STATUS.md:15` still marks Phase 3 as in progress and calls out richer analytics plus stronger tutor/coaching as missing.
- `backend/app/schemas/__init__.py:294-299` limits the insight snapshot to `overview`, `weak_concepts`, and a single coach message.
- `backend/app/services/insight_service.py:93-147` builds coaching tips from a small set of deterministic heuristics.
- `backend/app/services/tutor_service.py:18` still uses `heuristic-phase3-tutor-v1` rather than a deeper tutor orchestration path.

## Impact

- Insight output remains useful but narrow, which limits product differentiation and long-term retention value.
- Tutor responses may feel repetitive or thin on complex material.
- Phase 3 completion is overstated unless the deeper intelligence slice is tracked and finished explicitly.

## Required Work

- [ ] Expand insight output beyond the current overview and weak-concept summary
- [ ] Add richer mistake analytics and trend views grounded in review history
- [ ] Strengthen coaching generation beyond the current rule-based heuristic slice
- [ ] Replace or augment the deterministic tutor payload path with a stronger grounded tutor flow
- [ ] Add backend and product-level validation for the deeper intelligence behaviors

## Validation

- [ ] Insight responses expose materially richer learning signals than the current snapshot contract
- [ ] Tutor responses improve on the current deterministic baseline for at least explain/example/related flows
- [ ] Product docs and phase tracking can mark Phase 3 complete with evidence instead of a qualitative estimate
