"""
Cards API: CRUD for flashcards.
"""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import User, Card
from app.schemas import CardCreate, CardResponse, CardUpdate, TutorResponse
from app.services.tutor_service import ALLOWED_TUTOR_REQUEST_TYPES, get_tutor_response

router = APIRouter(prefix="/cards", tags=["Cards"])


@router.post("", response_model=CardResponse, status_code=status.HTTP_201_CREATED)
async def create_card(
    body: CardCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a manual flashcard."""
    card = Card(
        user_id=current_user.id,
        source_id=body.source_id,
        concept_id=body.concept_id,
        card_type=body.card_type,
        question=body.question,
        answer=body.answer,
        difficulty=body.difficulty,
    )
    db.add(card)
    await db.flush()
    return card


@router.get("", response_model=list[CardResponse])
async def list_cards(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    source_id: UUID | None = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    active_only: bool = True,
):
    """List user's flashcards, optionally filtered by source."""
    query = select(Card).where(Card.user_id == current_user.id)

    if source_id:
        query = query.where(Card.source_id == source_id)
    if active_only:
        query = query.where(Card.is_active == True)

    query = query.order_by(Card.created_at.desc()).offset(skip).limit(limit)
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/{card_id}", response_model=CardResponse)
async def get_card(
    card_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get a specific card."""
    result = await db.execute(
        select(Card).where(Card.id == card_id, Card.user_id == current_user.id)
    )
    card = result.scalar_one_or_none()
    if not card:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Card not found")
    return card


@router.get("/{card_id}/tutor/{request_type}", response_model=TutorResponse)
async def get_card_tutor_response(
    card_id: UUID,
    request_type: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get a cached tutor response for a card."""
    if request_type not in ALLOWED_TUTOR_REQUEST_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported tutor request type.",
        )

    response = await get_tutor_response(
        db=db,
        user_id=current_user.id,
        card_id=card_id,
        request_type=request_type,
    )
    if response is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Card not found")
    return response


@router.patch("/{card_id}", response_model=CardResponse)
async def update_card(
    card_id: UUID,
    body: CardUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update a card's content."""
    result = await db.execute(
        select(Card).where(Card.id == card_id, Card.user_id == current_user.id)
    )
    card = result.scalar_one_or_none()
    if not card:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Card not found")

    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(card, field, value)

    await db.flush()
    return card


@router.delete("/{card_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_card(
    card_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a card."""
    result = await db.execute(
        select(Card).where(Card.id == card_id, Card.user_id == current_user.id)
    )
    card = result.scalar_one_or_none()
    if not card:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Card not found")

    await db.delete(card)
