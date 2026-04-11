"""
Offline sync helpers for Phase 4 push/pull flows.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timezone
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Card, MemoryState, Review, Source, SyncEvent, User
from app.schemas import (
    CardUpdate,
    SyncCardResponse,
    SyncErrorDetail,
    SyncEventEnvelope,
    SyncMemoryStateResponse,
)
from app.services.daily_review_queue import mark_daily_queue_completed
from app.services.insight_service import track_review_intelligence_signals
from app.services.review_scheduler import calculate_schedule

logger = logging.getLogger(__name__)


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _coerce_uuid(raw_value: object, *, field_name: str) -> UUID:
    if raw_value is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Missing required field `{field_name}`.",
        )
    try:
        return UUID(str(raw_value))
    except (TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Invalid UUID in `{field_name}`.",
        ) from exc


def _coerce_int(raw_value: object, *, field_name: str) -> int | None:
    if raw_value is None:
        return None
    try:
        return int(raw_value)
    except (TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Invalid integer in `{field_name}`.",
        ) from exc


def _coerce_str(raw_value: object, *, field_name: str) -> str | None:
    if raw_value is None:
        return None
    value = str(raw_value).strip()
    if not value:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Empty value in `{field_name}`.",
        )
    return value


async def _get_card_for_user(
    db: AsyncSession,
    *,
    user_id: UUID,
    card_id: UUID,
) -> Card:
    result = await db.execute(
        select(Card).where(Card.id == card_id, Card.user_id == user_id)
    )
    card = result.scalar_one_or_none()
    if card is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Card not found.",
        )
    return card


async def _get_card_with_source_title(
    db: AsyncSession,
    *,
    user_id: UUID,
    card_id: UUID,
) -> tuple[Card, str | None]:
    result = await db.execute(
        select(Card, Source.title)
        .join(Source, Source.id == Card.source_id)
        .where(Card.id == card_id, Card.user_id == user_id)
    )
    row = result.first()
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Card not found.",
        )
    return row


async def serialize_card(
    db: AsyncSession,
    *,
    user_id: UUID,
    card_id: UUID,
) -> SyncCardResponse:
    card, source_title = await _get_card_with_source_title(
        db,
        user_id=user_id,
        card_id=card_id,
    )
    return SyncCardResponse(
        id=card.id,
        source_id=card.source_id,
        source_title=source_title,
        card_type=card.card_type,
        question=card.question,
        answer=card.answer,
        difficulty=card.difficulty,
        is_active=card.is_active,
        tags=card.tags,
        updated_at=card.updated_at,
    )


def serialize_memory_state(memory_state: MemoryState) -> SyncMemoryStateResponse:
    return SyncMemoryStateResponse(
        card_id=memory_state.card_id,
        stability=memory_state.stability,
        difficulty=memory_state.difficulty,
        retrievability=memory_state.retrievability,
        reps=memory_state.reps,
        lapses=memory_state.lapses,
        state=memory_state.state,
        next_review_at=memory_state.next_review_at,
        last_review_at=memory_state.last_review_at,
        updated_at=memory_state.updated_at,
    )


async def apply_review_submission(
    *,
    db: AsyncSession,
    user: User,
    card_id: UUID,
    rating: str,
    response_time_ms: int | None,
    client_id: str | None,
    reviewed_at: datetime | None = None,
) -> tuple[Review, MemoryState, Card]:
    card = await _get_card_for_user(db, user_id=user.id, card_id=card_id)

    if client_id:
        existing_review = await _get_existing_review_by_client_id(
            db=db,
            user_id=user.id,
            client_id=client_id,
        )
        if existing_review is not None:
            memory_state = await _get_memory_state_for_user_card(
                db=db,
                user_id=user.id,
                card_id=card_id,
            )
            if memory_state is None:
                memory_state = MemoryState(user_id=user.id, card_id=card_id)
                db.add(memory_state)
                await db.flush()
            return existing_review, memory_state, card

    review_time = reviewed_at or utcnow()
    review = Review(
        user_id=user.id,
        card_id=card_id,
        rating=rating,
        response_time_ms=response_time_ms,
        reviewed_at=review_time,
        client_id=client_id,
        synced=True,
    )
    db.add(review)

    memory_state = await _get_memory_state_for_user_card(
        db=db,
        user_id=user.id,
        card_id=card_id,
    )
    if memory_state is None:
        memory_state = MemoryState(
            user_id=user.id,
            card_id=card_id,
        )
        db.add(memory_state)

    schedule = calculate_schedule(
        reps=memory_state.reps,
        lapses=memory_state.lapses,
        state=memory_state.state,
        stability=memory_state.stability,
        difficulty=memory_state.difficulty,
        last_review_at=memory_state.last_review_at,
        rating=rating,
        response_time_ms=response_time_ms,
        seed_difficulty=card.difficulty,
        now=review_time,
    )
    memory_state.stability = schedule.stability
    memory_state.difficulty = schedule.difficulty
    memory_state.retrievability = schedule.retrievability
    memory_state.reps = schedule.reps
    memory_state.lapses = schedule.lapses
    memory_state.state = schedule.state
    memory_state.last_review_at = schedule.last_review_at
    memory_state.next_review_at = schedule.next_review_at

    await mark_daily_queue_completed(
        db=db,
        user_id=user.id,
        card_id=card_id,
        completed_at=review_time,
    )
    await db.flush()
    await track_review_intelligence_signals(
        db=db,
        user_id=user.id,
        card=card,
        rating=rating,
        response_time_ms=response_time_ms,
        reviewed_at=review_time,
    )
    return review, memory_state, card


async def apply_card_edit_event(
    *,
    db: AsyncSession,
    user: User,
    payload: dict,
) -> Card:
    card_id = _coerce_uuid(payload.get("card_id"), field_name="card_id")
    card = await _get_card_for_user(db, user_id=user.id, card_id=card_id)
    update = CardUpdate(
        question=payload.get("question"),
        answer=payload.get("answer"),
        difficulty=payload.get("difficulty"),
        is_active=payload.get("is_active"),
        tags=payload.get("tags"),
    )
    update_data = update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(card, field, value)
    await db.flush()
    return card


async def apply_settings_update_event(
    *,
    db: AsyncSession,
    user: User,
    payload: dict,
) -> dict | None:
    next_preferences = dict(user.preferences or {})
    for key, value in payload.items():
        if key == "auth_provider":
            continue
        next_preferences[str(key)] = value
    user.preferences = next_preferences
    await db.flush()
    return user.preferences


@dataclass
class SyncPushResult:
    processed_event_ids: list[str]
    skipped_event_ids: list[str]
    errors: list[SyncErrorDetail]
    updated_cards: list[SyncCardResponse]
    updated_memory_states: list[SyncMemoryStateResponse]
    preferences: dict | None


def _error_detail(exc: Exception) -> str:
    if isinstance(exc, HTTPException):
        if isinstance(exc.detail, str):
            return exc.detail
        return "Sync event failed."
    return str(exc) or "Sync event failed."


async def _get_existing_review_by_client_id(
    *,
    db: AsyncSession,
    user_id: UUID,
    client_id: str,
) -> Review | None:
    result = await db.execute(
        select(Review)
        .where(
            Review.client_id == client_id,
            Review.user_id == user_id,
        )
        .order_by(Review.reviewed_at.desc(), Review.id.desc())
    )
    reviews = result.scalars().all()
    if len(reviews) > 1:
        logger.warning(
            "Duplicate review client_id rows detected user_id=%s client_id=%s count=%s",
            user_id,
            client_id,
            len(reviews),
        )
    return reviews[0] if reviews else None


async def _get_memory_state_for_user_card(
    *,
    db: AsyncSession,
    user_id: UUID,
    card_id: UUID,
) -> MemoryState | None:
    result = await db.execute(
        select(MemoryState)
        .where(
            MemoryState.user_id == user_id,
            MemoryState.card_id == card_id,
        )
        .order_by(MemoryState.updated_at.desc(), MemoryState.id.desc())
    )
    memory_states = result.scalars().all()
    if len(memory_states) > 1:
        logger.warning(
            "Duplicate memory_state rows detected user_id=%s card_id=%s count=%s",
            user_id,
            card_id,
            len(memory_states),
        )
    return memory_states[0] if memory_states else None


async def process_sync_push(
    *,
    db: AsyncSession,
    user: User,
    device_id: str,
    events: list[SyncEventEnvelope],
) -> SyncPushResult:
    processed_event_ids: list[str] = []
    skipped_event_ids: list[str] = []
    errors: list[SyncErrorDetail] = []
    updated_cards: dict[UUID, SyncCardResponse] = {}
    updated_memory_states: dict[UUID, SyncMemoryStateResponse] = {}
    preferences: dict | None = None

    for event in sorted(events, key=lambda item: item.client_timestamp):
        existing = await db.execute(
            select(SyncEvent).where(
                SyncEvent.user_id == user.id,
                SyncEvent.client_event_id == event.client_event_id,
            )
        )
        if existing.scalar_one_or_none() is not None:
            skipped_event_ids.append(event.client_event_id)
            continue

        try:
            async with db.begin_nested():
                if event.event_type == "review":
                    card_id = _coerce_uuid(
                        event.event_payload.get("card_id"),
                        field_name="card_id",
                    )
                    rating = _coerce_str(
                        event.event_payload.get("rating"),
                        field_name="rating",
                    )
                    response_time_ms = _coerce_int(
                        event.event_payload.get("response_time_ms"),
                        field_name="response_time_ms",
                    )
                    _, memory_state, card = await apply_review_submission(
                        db=db,
                        user=user,
                        card_id=card_id,
                        rating=rating or "good",
                        response_time_ms=response_time_ms,
                        client_id=event.client_event_id,
                        reviewed_at=event.client_timestamp,
                    )
                    updated_cards[card.id] = await serialize_card(
                        db,
                        user_id=user.id,
                        card_id=card.id,
                    )
                    updated_memory_states[card.id] = serialize_memory_state(
                        memory_state
                    )
                elif event.event_type == "card_edit":
                    card = await apply_card_edit_event(
                        db=db,
                        user=user,
                        payload=event.event_payload,
                    )
                    updated_cards[card.id] = await serialize_card(
                        db,
                        user_id=user.id,
                        card_id=card.id,
                    )
                elif event.event_type == "settings_update":
                    preferences = await apply_settings_update_event(
                        db=db,
                        user=user,
                        payload=event.event_payload,
                    )
                else:
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail=f"Unsupported event type `{event.event_type}`.",
                    )

                db.add(
                    SyncEvent(
                        user_id=user.id,
                        device_id=device_id,
                        event_type=event.event_type,
                        event_payload=event.event_payload,
                        client_timestamp=event.client_timestamp,
                        processed=True,
                        client_event_id=event.client_event_id,
                    )
                )
                await db.flush()
            processed_event_ids.append(event.client_event_id)
        except Exception as exc:
            logger.exception(
                "Sync push event failed user_id=%s device_id=%s client_event_id=%s event_type=%s",
                user.id,
                device_id,
                event.client_event_id,
                event.event_type,
            )
            errors.append(
                SyncErrorDetail(
                    client_event_id=event.client_event_id,
                    detail=_error_detail(exc),
                )
            )

    return SyncPushResult(
        processed_event_ids=processed_event_ids,
        skipped_event_ids=skipped_event_ids,
        errors=errors,
        updated_cards=list(updated_cards.values()),
        updated_memory_states=list(updated_memory_states.values()),
        preferences=preferences,
    )


async def list_changed_cards(
    *,
    db: AsyncSession,
    user_id: UUID,
    since: datetime | None,
) -> list[SyncCardResponse]:
    query = (
        select(Card, Source.title)
        .join(Source, Source.id == Card.source_id)
        .where(Card.user_id == user_id)
        .order_by(Card.updated_at.asc())
    )
    if since is not None:
        query = query.where(Card.updated_at > since)

    result = await db.execute(query)
    return [
        SyncCardResponse(
            id=card.id,
            source_id=card.source_id,
            source_title=source_title,
            card_type=card.card_type,
            question=card.question,
            answer=card.answer,
            difficulty=card.difficulty,
            is_active=card.is_active,
            tags=card.tags,
            updated_at=card.updated_at,
        )
        for card, source_title in result.all()
    ]


async def list_changed_memory_states(
    *,
    db: AsyncSession,
    user_id: UUID,
    since: datetime | None,
) -> list[SyncMemoryStateResponse]:
    query = (
        select(MemoryState)
        .where(MemoryState.user_id == user_id)
        .order_by(MemoryState.updated_at.asc())
    )
    if since is not None:
        query = query.where(MemoryState.updated_at > since)

    result = await db.execute(query)
    return [serialize_memory_state(row) for row in result.scalars().all()]
