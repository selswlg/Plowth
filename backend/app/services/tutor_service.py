"""
Phase 3 Tutor AI service with deterministic responses and cache support.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import AICache, AIUsageLog, Card, Concept, ConceptRelation, Source
from app.schemas import TutorResponse
from app.services.ai_orchestrator import CostController, PromptBundle

TUTOR_MODEL_NAME = "heuristic-phase3-tutor-v1"
CACHE_TTL_HOURS = 24
ALLOWED_TUTOR_REQUEST_TYPES = {"explain", "example", "related"}
cost_controller = CostController()


@dataclass(frozen=True)
class TutorContext:
    card_id: UUID
    question: str
    answer: str
    card_type: str
    difficulty: int
    source_title: str | None
    concept_name: str | None
    concept_description: str | None
    related_concepts: list[str]
    sibling_questions: list[str]


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _normalize_text(value: str) -> str:
    return " ".join(value.split()).strip()


def _truncate_words(value: str, max_words: int) -> str:
    words = _normalize_text(value).split()
    if len(words) <= max_words:
        return " ".join(words)
    return " ".join(words[:max_words]).strip()


def _concept_label(context: TutorContext) -> str:
    if context.concept_name:
        return context.concept_name
    question = context.question.strip().rstrip("?")
    if question:
        return _truncate_words(question, 8)
    return "this card"


def _build_explain_payload(context: TutorContext) -> dict[str, object]:
    concept_label = _concept_label(context)
    answer_excerpt = _truncate_words(context.answer, 26)
    description_excerpt = (
        _truncate_words(context.concept_description, 18)
        if context.concept_description
        else None
    )
    bullets = [
        f"Card type: {context.card_type}",
        f"Difficulty: {context.difficulty}/5",
    ]
    if context.source_title:
        bullets.insert(0, f"Source: {context.source_title}")
    if description_excerpt:
        bullets.append(f"Concept note: {description_excerpt}")

    return {
        "title": f"Why {concept_label} matters",
        "content": (
            f"{concept_label} is the core idea behind this card. "
            f"Keep the recall anchored on this point: {answer_excerpt}."
        ),
        "bullets": bullets,
        "related_concepts": context.related_concepts[:3],
    }


def _build_example_payload(context: TutorContext) -> dict[str, object]:
    concept_label = _concept_label(context)
    answer_excerpt = _truncate_words(context.answer, 24)
    anchor_label = context.source_title or "the source material"
    bullets = [
        f"Explain it as if teaching from {anchor_label}.",
        f"Start from the cue: {context.question.strip()}",
    ]
    if context.related_concepts:
        bullets.append(f"Bridge to: {context.related_concepts[0]}")

    return {
        "title": f"Concrete example for {concept_label}",
        "content": (
            f"If you had to explain {concept_label} out loud, use a simple example built from "
            f"the answer: {answer_excerpt}."
        ),
        "bullets": bullets,
        "related_concepts": context.related_concepts[:2],
    }


def _build_related_payload(context: TutorContext) -> dict[str, object]:
    concept_label = _concept_label(context)
    if context.related_concepts:
        return {
            "title": f"Related ideas around {concept_label}",
            "content": (
                f"{concept_label} connects most directly to "
                f"{', '.join(context.related_concepts[:3])}."
            ),
            "bullets": [f"Review next: {name}" for name in context.related_concepts[:4]],
            "related_concepts": context.related_concepts[:4],
        }

    if context.sibling_questions:
        return {
            "title": f"Nearby cards for {concept_label}",
            "content": (
                "There are no explicit concept links yet, so the strongest related context comes "
                "from neighboring cards in the same source."
            ),
            "bullets": context.sibling_questions[:4],
            "related_concepts": [],
        }

    return {
        "title": f"Related ideas around {concept_label}",
        "content": (
            f"No stored relations exist yet for {concept_label}. Add more cards from the same "
            "material to build a stronger concept graph."
        ),
        "bullets": [],
        "related_concepts": [],
    }


def build_tutor_payload(
    *,
    context: TutorContext,
    request_type: str,
) -> dict[str, object]:
    if request_type not in ALLOWED_TUTOR_REQUEST_TYPES:
        raise ValueError(f"Unsupported tutor request type: {request_type}")

    if request_type == "explain":
        return _build_explain_payload(context)
    if request_type == "example":
        return _build_example_payload(context)
    return _build_related_payload(context)


def _deserialize_cached_response(cache_row: AICache) -> TutorResponse:
    payload = cache_row.response_json
    return TutorResponse(
        card_id=cache_row.card_id,
        request_type=cache_row.request_type,
        title=str(payload.get("title", "")),
        content=str(payload.get("content", "")),
        bullets=[str(item) for item in payload.get("bullets", [])],
        related_concepts=[str(item) for item in payload.get("related_concepts", [])],
        cached=True,
        generated_at=datetime.fromisoformat(str(payload["generated_at"])),
        expires_at=cache_row.expires_at,
    )


async def _load_tutor_context(
    *,
    db: AsyncSession,
    user_id: UUID,
    card_id: UUID,
) -> TutorContext | None:
    result = await db.execute(
        select(Card, Source.title, Concept.name, Concept.description)
        .join(Source, Source.id == Card.source_id)
        .join(Concept, Concept.id == Card.concept_id, isouter=True)
        .where(Card.id == card_id, Card.user_id == user_id)
    )
    row = result.first()
    if row is None:
        return None

    card, source_title, concept_name, concept_description = row
    related_concepts: list[str] = []
    if card.concept_id is not None:
        relation_rows = await db.execute(
            select(ConceptRelation.concept_a_id, ConceptRelation.concept_b_id)
            .where(
                or_(
                    ConceptRelation.concept_a_id == card.concept_id,
                    ConceptRelation.concept_b_id == card.concept_id,
                )
            )
            .order_by(ConceptRelation.strength.desc())
        )
        concept_ids: list[UUID] = []
        for concept_a_id, concept_b_id in relation_rows.all():
            related_id = concept_b_id if concept_a_id == card.concept_id else concept_a_id
            if related_id not in concept_ids:
                concept_ids.append(related_id)

        if concept_ids:
            related_result = await db.execute(
                select(Concept.name).where(Concept.id.in_(concept_ids[:4]))
            )
            related_concepts = [name for name in related_result.scalars() if name]

    sibling_result = await db.execute(
        select(Card.question)
        .where(
            Card.user_id == user_id,
            Card.source_id == card.source_id,
            Card.id != card.id,
            Card.is_active == True,
        )
        .order_by(Card.created_at.desc())
        .limit(4)
    )
    sibling_questions = [_truncate_words(question, 14) for question in sibling_result.scalars()]

    return TutorContext(
        card_id=card.id,
        question=card.question,
        answer=card.answer,
        card_type=card.card_type,
        difficulty=card.difficulty,
        source_title=source_title,
        concept_name=concept_name,
        concept_description=concept_description,
        related_concepts=related_concepts,
        sibling_questions=sibling_questions,
    )


async def get_tutor_response(
    *,
    db: AsyncSession,
    user_id: UUID,
    card_id: UUID,
    request_type: str,
) -> TutorResponse | None:
    if request_type not in ALLOWED_TUTOR_REQUEST_TYPES:
        raise ValueError(f"Unsupported tutor request type: {request_type}")

    card_exists = await db.scalar(
        select(Card.id).where(Card.id == card_id, Card.user_id == user_id)
    )
    if card_exists is None:
        return None

    now = _utcnow()
    cache_result = await db.execute(
        select(AICache).where(
            AICache.card_id == card_id,
            AICache.request_type == request_type,
        )
    )
    cache_row = cache_result.scalar_one_or_none()
    if cache_row is not None and cache_row.expires_at > now:
        return _deserialize_cached_response(cache_row)

    context = await _load_tutor_context(db=db, user_id=user_id, card_id=card_id)
    if context is None:
        return None

    payload = build_tutor_payload(context=context, request_type=request_type)
    generated_at = now
    expires_at = now + timedelta(hours=CACHE_TTL_HOURS)
    response_json = {
        "title": payload["title"],
        "content": payload["content"],
        "bullets": payload["bullets"],
        "related_concepts": payload["related_concepts"],
        "generated_at": generated_at.isoformat(),
    }

    if cache_row is None:
        cache_row = AICache(
            card_id=card_id,
            request_type=request_type,
            response_json=response_json,
            model_used=TUTOR_MODEL_NAME,
            expires_at=expires_at,
        )
        db.add(cache_row)
    else:
        cache_row.response_json = response_json
        cache_row.model_used = TUTOR_MODEL_NAME
        cache_row.created_at = generated_at
        cache_row.expires_at = expires_at

    usage = cost_controller.estimate_generation_cost(
        model_used=TUTOR_MODEL_NAME,
        prompt=PromptBundle(
            system_prompt=f"Tutor request type: {request_type}",
            user_prompt=f"Question: {context.question}\nAnswer: {context.answer}",
        ),
        output_text=f"{payload['title']}\n{payload['content']}",
    )
    db.add(
        AIUsageLog(
            user_id=user_id,
            request_type=request_type,
            model_used=str(usage["model_used"]),
            input_tokens=int(usage["input_tokens"]),
            output_tokens=int(usage["output_tokens"]),
            cost_usd=float(usage["cost_usd"]),
        )
    )
    await db.flush()

    return TutorResponse(
        card_id=card_id,
        request_type=request_type,
        title=str(payload["title"]),
        content=str(payload["content"]),
        bullets=[str(item) for item in payload["bullets"]],
        related_concepts=[str(item) for item in payload["related_concepts"]],
        cached=False,
        generated_at=generated_at,
        expires_at=expires_at,
    )
