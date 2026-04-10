"""
Migration-free Cognitive Update service.

The first implementation uses lexical similarity and records enrichment history
in Card.tags. A pgvector-backed matcher can replace the scoring layer later
without changing the API contract.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Card, Concept, Source, SourceChunk

TOKEN_PATTERN = re.compile(r"[A-Za-z0-9가-힣]{2,}")


@dataclass(frozen=True)
class CognitiveUpdateCardCandidate:
    card_id: UUID
    question: str
    answer_excerpt: str


@dataclass(frozen=True)
class CognitiveUpdateMatch:
    concept_id: UUID
    concept_name: str
    similarity: float
    suggested_action: str
    cards: list[CognitiveUpdateCardCandidate]


def _tokens(value: str | None) -> set[str]:
    return {token.lower() for token in TOKEN_PATTERN.findall(value or "")}


def concept_similarity(
    *,
    incoming_name: str,
    incoming_description: str | None,
    existing_name: str,
    existing_description: str | None,
) -> float:
    incoming = _tokens(f"{incoming_name} {incoming_description or ''}")
    existing = _tokens(f"{existing_name} {existing_description or ''}")
    if not incoming or not existing:
        return 0.0
    return len(incoming & existing) / len(incoming | existing)


def suggested_update_action(similarity: float) -> str:
    if similarity >= 0.55:
        return "reinforce"
    if similarity >= 0.25:
        return "keep_separate"
    return "skip_duplicate"


def merge_card_answer(existing_answer: str, new_evidence: str) -> str:
    existing = " ".join(existing_answer.split()).strip()
    evidence = " ".join(new_evidence.split()).strip()
    if not evidence:
        return existing_answer.strip()
    if evidence.lower() in existing.lower():
        return existing_answer.strip()
    return f"{existing_answer.strip()}\n\nUpdate: {evidence}"


def append_enrichment_history(tags: dict | None, *, event: dict) -> dict:
    next_tags = dict(tags or {})
    history = list(next_tags.get("enrichment_history") or [])
    history.append(event)
    next_tags["enrichment_history"] = history[-10:]
    return next_tags


def _answer_excerpt(value: str, limit: int = 120) -> str:
    normalized = " ".join(value.split()).strip()
    if len(normalized) <= limit:
        return normalized
    return f"{normalized[: limit - 3].rstrip()}..."


async def preview_cognitive_update(
    *,
    db: AsyncSession,
    user_id: UUID,
    concept_name: str,
    description: str | None = None,
    limit: int = 5,
) -> list[CognitiveUpdateMatch]:
    concept_result = await db.execute(
        select(Concept.id, Concept.name, Concept.description)
        .join(SourceChunk, SourceChunk.id == Concept.chunk_id)
        .join(Source, Source.id == SourceChunk.source_id)
        .where(Source.user_id == user_id)
    )

    scored: list[tuple[UUID, str, float]] = []
    for concept_id, existing_name, existing_description in concept_result.all():
        score = concept_similarity(
            incoming_name=concept_name,
            incoming_description=description,
            existing_name=existing_name,
            existing_description=existing_description,
        )
        if score > 0:
            scored.append((concept_id, existing_name, round(score, 4)))

    scored.sort(key=lambda row: row[2], reverse=True)
    selected = scored[:limit]
    if not selected:
        return []

    concept_ids = [concept_id for concept_id, _, _ in selected]
    card_result = await db.execute(
        select(Card).where(
            Card.user_id == user_id,
            Card.concept_id.in_(concept_ids),
            Card.is_active == True,
        )
    )
    cards_by_concept: dict[UUID, list[CognitiveUpdateCardCandidate]] = {}
    for card in card_result.scalars():
        if card.concept_id is None:
            continue
        cards_by_concept.setdefault(card.concept_id, []).append(
            CognitiveUpdateCardCandidate(
                card_id=card.id,
                question=card.question,
                answer_excerpt=_answer_excerpt(card.answer),
            )
        )

    return [
        CognitiveUpdateMatch(
            concept_id=concept_id,
            concept_name=name,
            similarity=score,
            suggested_action=suggested_update_action(score),
            cards=cards_by_concept.get(concept_id, [])[:3],
        )
        for concept_id, name, score in selected
    ]


async def apply_answer_enrichment(
    *,
    db: AsyncSession,
    user_id: UUID,
    card_id: UUID,
    new_evidence: str,
    event: dict,
) -> Card | None:
    card = await db.scalar(
        select(Card).where(Card.id == card_id, Card.user_id == user_id)
    )
    if card is None:
        return None

    card.answer = merge_card_answer(card.answer, new_evidence)
    card.tags = append_enrichment_history(card.tags, event=event)
    await db.flush()
    return card
