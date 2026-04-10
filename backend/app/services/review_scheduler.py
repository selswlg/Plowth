"""
FSRS-inspired scheduler used for the Phase 2 MVP.

The full production implementation can later swap this module for a dedicated
library without changing the API contract.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone


@dataclass
class ScheduleUpdate:
    stability: float
    difficulty: float
    retrievability: float
    reps: int
    lapses: int
    state: str
    next_review_at: datetime
    last_review_at: datetime


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _clamp(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(maximum, value))


def calculate_schedule(
    *,
    reps: int | None,
    lapses: int | None,
    state: str | None,
    stability: float | None,
    difficulty: float | None,
    last_review_at: datetime | None,
    rating: str,
    response_time_ms: int | None,
    seed_difficulty: int = 3,
    now: datetime | None = None,
) -> ScheduleUpdate:
    now = now or _utcnow()
    previous_reps = reps or 0
    previous_lapses = lapses or 0
    previous_state = state or "new"
    previous_stability = (
        stability
        if stability is not None and stability > 0
        else max(0.25, seed_difficulty * 0.35)
    )
    previous_difficulty = (
        difficulty
        if difficulty is not None and difficulty > 0
        else float(seed_difficulty + 3)
    )

    elapsed_days = 0.0
    if last_review_at is not None:
        elapsed = max(0.0, (now - last_review_at).total_seconds())
        elapsed_days = elapsed / 86400

    retrievability = (
        math.exp(-elapsed_days / max(previous_stability, 0.1))
        if last_review_at is not None
        else 1.0
    )

    response_factor = 1.0
    if response_time_ms is not None:
        if response_time_ms <= 3500:
            response_factor = 1.1
        elif response_time_ms >= 15000:
            response_factor = 0.88
        elif response_time_ms >= 10000:
            response_factor = 0.95

    difficulty_delta = {
        "again": 1.1,
        "hard": 0.35,
        "good": -0.15,
        "easy": -0.45,
    }[rating]
    if response_time_ms is not None and response_time_ms >= 12000:
        difficulty_delta += 0.2

    next_difficulty = _clamp(previous_difficulty + difficulty_delta, 1.0, 10.0)
    next_reps = previous_reps + 1
    next_lapses = previous_lapses + (1 if rating == "again" else 0)

    if rating == "again":
        next_stability = _clamp(previous_stability * 0.35 * response_factor, 0.08, 3.0)
        interval = timedelta(minutes=10 if previous_reps == 0 else 30)
        next_state = "relearning" if previous_reps > 0 else "learning"
    else:
        growth = {
            "hard": 0.9,
            "good": 1.35,
            "easy": 1.8,
        }[rating]
        recall_factor = max(0.7, 1.3 - (1.0 - retrievability))
        difficulty_factor = max(0.65, 1.2 - next_difficulty / 12)
        next_stability = _clamp(
            previous_stability
            * growth
            * recall_factor
            * difficulty_factor
            * response_factor,
            0.2,
            365.0,
        )

        if previous_reps == 0:
            interval = {
                "hard": timedelta(hours=8),
                "good": timedelta(days=1),
                "easy": timedelta(days=3),
            }[rating]
        else:
            interval_days = {
                "hard": max(0.35, next_stability * 0.6),
                "good": max(1.0, next_stability),
                "easy": max(2.0, next_stability * 1.5),
            }[rating]
            interval = timedelta(days=interval_days)

        next_state = "learning" if next_reps < 2 else "review"
        if previous_state == "relearning" and rating in {"good", "easy"}:
            next_state = "review"

    return ScheduleUpdate(
        stability=next_stability,
        difficulty=next_difficulty,
        retrievability=_clamp(retrievability, 0.0, 1.0),
        reps=next_reps,
        lapses=next_lapses,
        state=next_state,
        next_review_at=now + interval,
        last_review_at=now,
    )
