"""
Daily review queue generation and completion helpers.
"""

from __future__ import annotations

from datetime import date, datetime, timezone
from uuid import UUID

from sqlalchemy import and_, delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Card, ConceptRelation, DailyReviewQueue, MemoryState, MistakePattern


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _priority_for_card(
    *,
    memory_state: MemoryState | None,
    relation_count: int,
    weakness_count: int,
    now: datetime,
) -> float:
    if memory_state is None:
        return 100.0 + relation_count * 2 + weakness_count * 4

    overdue_bonus = 0.0
    if memory_state.next_review_at is not None:
        overdue_hours = max(
            0.0, (now - memory_state.next_review_at).total_seconds() / 3600
        )
        overdue_bonus = overdue_hours * 0.4

    lapse_bonus = memory_state.lapses * 5
    state_bonus = {
        "relearning": 18.0,
        "learning": 12.0,
        "review": 6.0,
        "new": 4.0,
    }.get(memory_state.state, 4.0)
    relation_bonus = relation_count * 1.5
    weakness_bonus = weakness_count * 4
    difficulty_bonus = memory_state.difficulty
    return (
        state_bonus
        + overdue_bonus
        + lapse_bonus
        + relation_bonus
        + weakness_bonus
        + difficulty_bonus
    )


async def sync_daily_review_queue(
    *,
    db: AsyncSession,
    user_id: UUID,
    now: datetime | None = None,
    limit: int = 200,
) -> date:
    now = now or _utcnow()
    queue_date = now.date()

    relation_count_subquery = (
        select(
            ConceptRelation.concept_a_id.label("concept_id"),
            func.count(ConceptRelation.id).label("relation_count"),
        )
        .group_by(ConceptRelation.concept_a_id)
        .subquery()
    )
    weakness_count_subquery = (
        select(
            MistakePattern.concept_id.label("concept_id"),
            func.coalesce(func.sum(MistakePattern.occurrence_count), 0).label(
                "weakness_count"
            ),
        )
        .where(MistakePattern.user_id == user_id, MistakePattern.resolved == False)
        .group_by(MistakePattern.concept_id)
        .subquery()
    )

    result = await db.execute(
        select(
            Card,
            MemoryState,
            func.coalesce(relation_count_subquery.c.relation_count, 0),
            func.coalesce(weakness_count_subquery.c.weakness_count, 0),
        )
        .join(
            MemoryState,
            and_(MemoryState.card_id == Card.id, MemoryState.user_id == user_id),
            isouter=True,
        )
        .join(
            relation_count_subquery,
            relation_count_subquery.c.concept_id == Card.concept_id,
            isouter=True,
        )
        .join(
            weakness_count_subquery,
            weakness_count_subquery.c.concept_id == Card.concept_id,
            isouter=True,
        )
        .where(Card.user_id == user_id, Card.is_active == True)
        .where(or_(MemoryState.id == None, MemoryState.next_review_at <= now))
        .order_by(MemoryState.next_review_at.asc().nulls_first(), Card.created_at.asc())
        .limit(limit)
    )
    due_rows = result.all()
    due_card_ids = {card.id for card, _, _, _ in due_rows}

    existing_rows = await db.execute(
        select(DailyReviewQueue).where(
            DailyReviewQueue.user_id == user_id,
            DailyReviewQueue.queue_date == queue_date,
        )
    )
    existing_by_card = {row.card_id: row for row in existing_rows.scalars()}

    stale_pending_ids = [
        row.id
        for row in existing_by_card.values()
        if row.status == "pending" and row.card_id not in due_card_ids
    ]
    if stale_pending_ids:
        await db.execute(
            delete(DailyReviewQueue).where(DailyReviewQueue.id.in_(stale_pending_ids))
        )

    for card, memory_state, relation_count, weakness_count in due_rows:
        priority = _priority_for_card(
            memory_state=memory_state,
            relation_count=int(relation_count or 0),
            weakness_count=int(weakness_count or 0),
            now=now,
        )
        existing = existing_by_card.get(card.id)
        if existing is None:
            db.add(
                DailyReviewQueue(
                    user_id=user_id,
                    card_id=card.id,
                    queue_date=queue_date,
                    priority=priority,
                    status="pending",
                )
            )
            continue

        if existing.status == "pending":
            existing.priority = priority
            continue

        if existing.status == "completed":
            existing.status = "pending"
            existing.completed_at = None
            existing.priority = priority

    await db.flush()
    return queue_date


async def mark_daily_queue_completed(
    *,
    db: AsyncSession,
    user_id: UUID,
    card_id: UUID,
    completed_at: datetime | None = None,
) -> None:
    completed_at = completed_at or _utcnow()
    queue_date = completed_at.date()
    result = await db.execute(
        select(DailyReviewQueue).where(
            DailyReviewQueue.user_id == user_id,
            DailyReviewQueue.card_id == card_id,
            DailyReviewQueue.queue_date == queue_date,
        )
    )
    row = result.scalar_one_or_none()
    if row is None:
        return

    row.status = "completed"
    row.completed_at = completed_at
