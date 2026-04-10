"""
Insights API for Phase 3 analytics and coaching.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import User
from app.schemas import (
    CardResponse,
    CognitiveUpdateApplyRequest,
    CognitiveUpdatePreviewRequest,
    CognitiveUpdatePreviewResponse,
    InsightSnapshot,
    WeakConcept,
)
from app.services.cognitive_update import (
    apply_answer_enrichment,
    preview_cognitive_update,
)
from app.services.insight_service import build_insight_snapshot, list_weak_concepts

router = APIRouter(prefix="/insights", tags=["Insights"])


@router.get("/snapshot", response_model=InsightSnapshot)
async def get_insight_snapshot(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await build_insight_snapshot(db=db, user_id=current_user.id)


@router.get("/weak-concepts", response_model=list[WeakConcept])
async def get_weak_concepts(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await list_weak_concepts(db=db, user_id=current_user.id)


@router.post(
    "/cognitive-update/preview",
    response_model=CognitiveUpdatePreviewResponse,
)
async def preview_update(
    body: CognitiveUpdatePreviewRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    matches = await preview_cognitive_update(
        db=db,
        user_id=current_user.id,
        concept_name=body.concept_name,
        description=body.description,
        limit=body.limit,
    )
    return CognitiveUpdatePreviewResponse(matches=matches)


@router.post("/cognitive-update/apply", response_model=CardResponse)
async def apply_update(
    body: CognitiveUpdateApplyRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    card = await apply_answer_enrichment(
        db=db,
        user_id=current_user.id,
        card_id=body.card_id,
        new_evidence=body.new_evidence,
        event={
            "action": body.action,
            "source_concept_name": body.source_concept_name,
            "evidence": body.new_evidence,
        },
    )
    if card is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Card not found",
        )
    return card
