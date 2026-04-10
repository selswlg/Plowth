"""
Phase 3 insight aggregation and lightweight coaching signals.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    Card,
    Concept,
    DailyReviewQueue,
    LearningProfile,
    MemoryState,
    MistakePattern,
    Review,
)
from app.schemas import DailyInsight, InsightSnapshot, WeakConcept
from app.services.daily_review_queue import sync_daily_review_queue


@dataclass(frozen=True)
class CoachingTip:
    title: str
    message: str
    focus_topic: str | None = None


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _day_bounds(now: datetime) -> tuple[datetime, datetime]:
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    day_end = day_start + timedelta(days=1)
    return day_start, day_end


def _normalize_review_dates(values: list[date | datetime | str]) -> list[date]:
    normalized: set[date] = set()
    for value in values:
        if isinstance(value, datetime):
            normalized.add(value.date())
        elif isinstance(value, date):
            normalized.add(value)
        elif isinstance(value, str):
            normalized.add(date.fromisoformat(value))
    return sorted(normalized)


def calculate_streaks(
    review_dates: list[date | datetime | str],
    *,
    reference_date: date,
) -> tuple[int, int]:
    ordered = _normalize_review_dates(review_dates)
    if not ordered:
        return 0, 0

    longest_streak = 0
    streak = 0
    previous: date | None = None
    for review_date in ordered:
        if previous is not None and (review_date - previous).days == 1:
            streak += 1
        else:
            streak = 1
        longest_streak = max(longest_streak, streak)
        previous = review_date

    latest = ordered[-1]
    if (reference_date - latest).days > 1:
        return 0, longest_streak

    current_streak = 0
    expected = latest
    for review_date in reversed(ordered):
        if review_date == expected:
            current_streak += 1
            expected -= timedelta(days=1)
            continue
        if review_date < expected:
            break

    return current_streak, longest_streak


def build_coaching_tip(
    *,
    overview: DailyInsight,
    weak_concepts: list[WeakConcept],
) -> CoachingTip:
    if weak_concepts and weak_concepts[0].failure_count >= 3:
        concept_name = weak_concepts[0].concept_name
        return CoachingTip(
            title="Target one concept",
            message=(
                f'"{concept_name}" is costing the most recall. '
                "Review that concept first, then tighten any vague wording or add one clearer example."
            ),
            focus_topic=concept_name,
        )

    if (
        overview.accuracy_today is not None
        and overview.completed_today >= 4
        and overview.accuracy_today < 0.6
    ):
        return CoachingTip(
            title="Shorten the next set",
            message=(
                "Accuracy dipped today. Run a smaller review block and edit ambiguous cards "
                "before adding another capture batch."
            ),
        )

    pending_reviews = max(0, overview.total_due_today - overview.completed_today)
    if pending_reviews >= 8:
        return CoachingTip(
            title="Clear the queue first",
            message=(
                "The due queue is building up. Finish the pending review set before generating new cards "
                "so the schedule can stabilize."
            ),
        )

    if overview.streak_days >= 3:
        return CoachingTip(
            title="Protect the streak",
            message=(
                "Momentum is working for you. A short pass today is enough to keep the streak alive "
                "and reinforce older material."
            ),
        )

    return CoachingTip(
        title="Warm up recall",
        message=(
            "Start with one focused review pass, then inspect the weakest cards and sharpen their prompts "
            "before the next capture session."
        ),
    )


async def refresh_learning_profile(
    *,
    db: AsyncSession,
    user_id: UUID,
    now: datetime | None = None,
) -> LearningProfile:
    now = now or _utcnow()

    review_stats_result = await db.execute(
        select(
            func.count(Review.id),
            func.sum(
                case((Review.rating.in_(("good", "easy")), 1), else_=0)
            ),
            func.avg(Review.response_time_ms),
        ).where(Review.user_id == user_id)
    )
    total_reviews, strong_reviews, avg_response_time = review_stats_result.one()

    total_cards = await db.scalar(
        select(func.count(Card.id)).where(Card.user_id == user_id, Card.is_active == True)
    )

    review_dates_result = await db.execute(
        select(func.date(Review.reviewed_at))
        .where(Review.user_id == user_id)
        .order_by(func.date(Review.reviewed_at).asc())
    )
    review_dates = [row[0] for row in review_dates_result.all() if row[0] is not None]
    streak_days, longest_streak = calculate_streaks(
        review_dates,
        reference_date=now.date(),
    )

    best_hour = await db.scalar(
        select(func.extract("hour", Review.reviewed_at).label("review_hour"))
        .where(Review.user_id == user_id)
        .group_by("review_hour")
        .order_by(func.count(Review.id).desc(), "review_hour")
        .limit(1)
    )

    worst_hour = await db.scalar(
        select(func.extract("hour", Review.reviewed_at).label("review_hour"))
        .where(Review.user_id == user_id)
        .group_by("review_hour")
        .order_by(
            func.avg(
                case((Review.rating.in_(("good", "easy")), 1.0), else_=0.0)
            ).asc(),
            func.count(Review.id).desc(),
            "review_hour",
        )
        .limit(1)
    )

    result = await db.execute(
        select(LearningProfile).where(LearningProfile.user_id == user_id)
    )
    profile = result.scalar_one_or_none()
    if profile is None:
        profile = LearningProfile(user_id=user_id)
        db.add(profile)

    total_reviews = int(total_reviews or 0)
    strong_reviews = int(strong_reviews or 0)
    profile.total_reviews = total_reviews
    profile.total_cards = int(total_cards or 0)
    profile.avg_accuracy = (
        strong_reviews / total_reviews if total_reviews else 0.0
    )
    profile.avg_response_time_ms = int(avg_response_time or 0)
    profile.best_hour = int(best_hour) if best_hour is not None else None
    profile.worst_hour = int(worst_hour) if worst_hour is not None else None
    profile.streak_days = streak_days
    profile.longest_streak = longest_streak
    profile.profile_data = {
        "last_refreshed_at": now.isoformat(),
        "strong_reviews": strong_reviews,
    }
    await db.flush()
    return profile


async def _upsert_mistake_pattern(
    *,
    db: AsyncSession,
    user_id: UUID,
    concept_id: UUID,
    pattern_type: str,
    description: str,
    occurred_at: datetime,
) -> None:
    result = await db.execute(
        select(MistakePattern).where(
            MistakePattern.user_id == user_id,
            MistakePattern.concept_id == concept_id,
            MistakePattern.pattern_type == pattern_type,
            MistakePattern.resolved == False,
        )
    )
    pattern = result.scalar_one_or_none()
    if pattern is None:
        db.add(
            MistakePattern(
                user_id=user_id,
                concept_id=concept_id,
                pattern_type=pattern_type,
                description=description,
                occurrence_count=1,
                last_occurred_at=occurred_at,
            )
        )
        return

    pattern.description = description
    pattern.occurrence_count += 1
    pattern.last_occurred_at = occurred_at


async def track_review_intelligence_signals(
    *,
    db: AsyncSession,
    user_id: UUID,
    card: Card,
    rating: str,
    response_time_ms: int | None,
    reviewed_at: datetime,
) -> None:
    if card.concept_id is not None:
        concept_name = await db.scalar(
            select(Concept.name).where(Concept.id == card.concept_id)
        )
        concept_label = concept_name or "this concept"

        if rating == "again":
            await _upsert_mistake_pattern(
                db=db,
                user_id=user_id,
                concept_id=card.concept_id,
                pattern_type="forgetting",
                description=f'Recall broke down on "{concept_label}".',
                occurred_at=reviewed_at,
            )
        elif rating == "hard":
            await _upsert_mistake_pattern(
                db=db,
                user_id=user_id,
                concept_id=card.concept_id,
                pattern_type="confusion",
                description=f'"{concept_label}" still feels effortful under recall.',
                occurred_at=reviewed_at,
            )

        if response_time_ms is not None and response_time_ms >= 12000:
            await _upsert_mistake_pattern(
                db=db,
                user_id=user_id,
                concept_id=card.concept_id,
                pattern_type="slow_response",
                description=f'"{concept_label}" is taking too long to retrieve.',
                occurred_at=reviewed_at,
            )

        if rating in {"good", "easy"} and (response_time_ms or 0) <= 6000:
            resolved_result = await db.execute(
                select(MistakePattern).where(
                    MistakePattern.user_id == user_id,
                    MistakePattern.concept_id == card.concept_id,
                    MistakePattern.resolved == False,
                )
            )
            for pattern in resolved_result.scalars():
                pattern.resolved = True

    await refresh_learning_profile(db=db, user_id=user_id, now=reviewed_at)


async def list_weak_concepts(
    *,
    db: AsyncSession,
    user_id: UUID,
    limit: int = 5,
) -> list[WeakConcept]:
    failure_score = func.sum(case((Review.rating == "again", 2), else_=1))
    result = await db.execute(
        select(
            Concept.name,
            failure_score.label("failure_count"),
            func.max(Review.reviewed_at).label("last_failed_at"),
        )
        .join(Card, Card.concept_id == Concept.id)
        .join(Review, Review.card_id == Card.id)
        .where(
            Review.user_id == user_id,
            Review.rating.in_(("again", "hard")),
        )
        .group_by(Concept.id, Concept.name)
        .order_by(failure_score.desc(), func.max(Review.reviewed_at).desc())
        .limit(limit)
    )
    rows = result.all()
    if rows:
        return [
            WeakConcept(
                concept_name=name,
                failure_count=int(failure_count or 0),
                last_failed_at=last_failed_at,
            )
            for name, failure_count, last_failed_at in rows
        ]

    fallback_result = await db.execute(
        select(
            Concept.name,
            func.sum(MistakePattern.occurrence_count).label("failure_count"),
            func.max(MistakePattern.last_occurred_at).label("last_failed_at"),
        )
        .join(Concept, Concept.id == MistakePattern.concept_id)
        .where(
            MistakePattern.user_id == user_id,
            MistakePattern.resolved == False,
        )
        .group_by(Concept.id, Concept.name)
        .order_by(
            func.sum(MistakePattern.occurrence_count).desc(),
            func.max(MistakePattern.last_occurred_at).desc(),
        )
        .limit(limit)
    )
    return [
        WeakConcept(
            concept_name=name,
            failure_count=int(failure_count or 0),
            last_failed_at=last_failed_at,
        )
        for name, failure_count, last_failed_at in fallback_result.all()
    ]


async def build_insight_snapshot(
    *,
    db: AsyncSession,
    user_id: UUID,
    now: datetime | None = None,
) -> InsightSnapshot:
    now = now or _utcnow()
    day_start, day_end = _day_bounds(now)
    queue_date = await sync_daily_review_queue(
        db=db,
        user_id=user_id,
        now=now,
        limit=200,
    )

    due_counts = await db.execute(
        select(
            func.count(DailyReviewQueue.id),
            func.sum(
                case((DailyReviewQueue.status == "completed", 1), else_=0)
            ),
        ).where(
            DailyReviewQueue.user_id == user_id,
            DailyReviewQueue.queue_date == queue_date,
        )
    )
    total_due_today, completed_today = due_counts.one()

    review_stats = await db.execute(
        select(
            func.count(Review.id),
            func.sum(
                case((Review.rating.in_(("good", "easy")), 1), else_=0)
            ),
        ).where(
            Review.user_id == user_id,
            Review.reviewed_at >= day_start,
            Review.reviewed_at < day_end,
        )
    )
    total_reviews_today, strong_reviews_today = review_stats.one()

    memory_strength = await db.scalar(
        select(func.avg(MemoryState.retrievability))
        .join(Card, Card.id == MemoryState.card_id)
        .where(MemoryState.user_id == user_id, Card.is_active == True)
    )

    profile = await refresh_learning_profile(db=db, user_id=user_id, now=now)
    weak_concepts = await list_weak_concepts(db=db, user_id=user_id, limit=5)
    overview = DailyInsight(
        total_due_today=int(total_due_today or 0),
        completed_today=int(completed_today or 0),
        accuracy_today=(
            int(strong_reviews_today or 0) / int(total_reviews_today)
            if total_reviews_today
            else None
        ),
        streak_days=profile.streak_days,
        memory_strength=float(memory_strength or 0.0),
    )
    coaching_tip = build_coaching_tip(
        overview=overview,
        weak_concepts=weak_concepts,
    )
    return InsightSnapshot(
        overview=overview,
        weak_concepts=weak_concepts,
        coach_title=coaching_tip.title,
        coach_message=coaching_tip.message,
        focus_topic=coaching_tip.focus_topic,
    )
