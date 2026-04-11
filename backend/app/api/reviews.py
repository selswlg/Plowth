"""
Reviews API: submit reviews and get review queue.
"""

from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import Card, DailyReviewQueue, MemoryState, Review, Source, User
from app.schemas import ReviewCreate, ReviewQueueCard, ReviewResponse, ReviewSessionSummary
from app.services.daily_review_queue import mark_daily_queue_completed, sync_daily_review_queue
from app.services.sync_service import apply_review_submission

router = APIRouter(prefix="/reviews", tags=["Reviews"])


@router.get("/queue", response_model=list[ReviewQueueCard])
async def get_review_queue(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    limit: int = Query(50, ge=1, le=200),
):
    """Get today's review queue — cards due for review."""
    now = datetime.now(timezone.utc)
    queue_date = await sync_daily_review_queue(
        db=db,
        user_id=current_user.id,
        now=now,
        limit=limit,
    )

    result = await db.execute(
        select(DailyReviewQueue, Card, MemoryState, Source.title)
        .join(Card, Card.id == DailyReviewQueue.card_id)
        .join(Source, Source.id == Card.source_id)
        .join(
            MemoryState,
            and_(
                MemoryState.card_id == Card.id,
                MemoryState.user_id == current_user.id,
            ),
            isouter=True,
        )
        .where(
            DailyReviewQueue.user_id == current_user.id,
            DailyReviewQueue.queue_date == queue_date,
            DailyReviewQueue.status == "pending",
        )
        .order_by(
            DailyReviewQueue.priority.desc(),
            MemoryState.next_review_at.asc().nulls_first(),
            Card.created_at.asc(),
        )
        .limit(limit)
    )
    rows = result.all()

    return [
        ReviewQueueCard(
            id=card.id,
            source_id=card.source_id,
            source_title=source_title,
            question=card.question,
            answer=card.answer,
            card_type=card.card_type,
            difficulty=card.difficulty,
            tags=card.tags,
            state=memory_state.state if memory_state else "new",
            next_review_at=memory_state.next_review_at if memory_state else None,
            reps=memory_state.reps if memory_state else 0,
            lapses=memory_state.lapses if memory_state else 0,
        )
        for _, card, memory_state, source_title in rows
    ]


@router.post("", response_model=ReviewResponse, status_code=status.HTTP_201_CREATED)
async def submit_review(
    body: ReviewCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Submit a review for a card (append-only)."""
    review, _, _ = await apply_review_submission(
        db=db,
        user=current_user,
        card_id=body.card_id,
        rating=body.rating,
        response_time_ms=body.response_time_ms,
        client_id=body.client_id,
    )
    return review


@router.get("/history", response_model=list[ReviewResponse])
async def get_review_history(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    card_id: UUID | None = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
):
    """Get review history, optionally filtered by card."""
    query = select(Review).where(Review.user_id == current_user.id)

    if card_id:
        query = query.where(Review.card_id == card_id)

    query = query.order_by(Review.reviewed_at.desc()).offset(skip).limit(limit)
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/summary/today", response_model=ReviewSessionSummary)
async def get_today_review_summary(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.now(timezone.utc)
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    day_end = day_start.replace(hour=23, minute=59, second=59, microsecond=999999)

    result = await db.execute(
        select(Review.rating, Review.response_time_ms).where(
            Review.user_id == current_user.id,
            Review.reviewed_at >= day_start,
            Review.reviewed_at <= day_end,
        )
    )
    rows = result.all()

    total_cards = len(rows)
    again_count = sum(1 for rating, _ in rows if rating == "again")
    hard_count = sum(1 for rating, _ in rows if rating == "hard")
    good_count = sum(1 for rating, _ in rows if rating == "good")
    easy_count = sum(1 for rating, _ in rows if rating == "easy")
    response_times = [response_time for _, response_time in rows if response_time is not None]
    avg_response_time_ms = (
        sum(response_times) / len(response_times) if response_times else None
    )
    accuracy_rate = (
        (good_count + easy_count) / total_cards if total_cards else 0.0
    )

    return ReviewSessionSummary(
        total_cards=total_cards,
        again_count=again_count,
        hard_count=hard_count,
        good_count=good_count,
        easy_count=easy_count,
        avg_response_time_ms=avg_response_time_ms,
        accuracy_rate=accuracy_rate,
    )
