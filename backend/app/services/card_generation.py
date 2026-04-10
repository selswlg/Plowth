"""
Deterministic card generation pipeline for the Phase 2 MVP.

This keeps the orchestration boundary in place without depending on a live
model provider during local development.
"""

from __future__ import annotations

import math
import re
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import delete, or_, select, update

from app.config import get_settings
from app.database import async_session_factory
from app.models import (
    AIUsageLog,
    Card,
    Concept,
    ConceptRelation,
    Job,
    Source,
    SourceChunk,
)
from app.services.ai_orchestrator import CostController, ModelRouter, PromptManager

HEURISTIC_MODEL_NAME = "heuristic-phase2-v1"
MAX_CHUNKS = 6
MAX_CARDS = 10
TOKEN_PATTERN = re.compile(r"[\w\u4e00-\u9fff]{1,}", re.UNICODE)
SENTENCE_SPLIT_PATTERN = re.compile(r"(?<=[.!?。！？])\s+|\n+")
VOCABULARY_SEPARATOR_PATTERN = re.compile(r"\s*(?::|：|=|->|=>)\s*")
VOCABULARY_BULLET_PATTERN = re.compile(r"^\s*(?:[-*•]|\d+[.)])\s*")
settings = get_settings()
model_router = ModelRouter(
    high_model=settings.AI_MODEL_HIGH,
    low_model=HEURISTIC_MODEL_NAME,
)
prompt_manager = PromptManager()
cost_controller = CostController()


@dataclass
class _ConceptDraft:
    name: str
    description: str
    details: list[str]
    tags: list[str]


@dataclass(frozen=True)
class _VocabularyEntry:
    term: str
    meaning: str


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _contains_hangul(value: str) -> bool:
    return any("\uac00" <= char <= "\ud7a3" for char in value)


def _normalize_text(source: Source) -> str:
    if source.raw_content and source.raw_content.strip():
        return source.raw_content.strip()

    if source.source_type == "link" and source.url:
        title = source.title or "Linked material"
        return f"{title}\n{source.url}"

    if source.title and source.title.strip():
        return source.title.strip()

    raise ValueError("The source does not contain enough content to generate cards.")


def _split_sentences(text: str) -> list[str]:
    sentences = [
        part.strip() for part in SENTENCE_SPLIT_PATTERN.split(text) if part.strip()
    ]
    return sentences or [text.strip()]


def _chunk_text(text: str, max_chars: int = 450) -> list[str]:
    paragraphs = [part.strip() for part in re.split(r"\n\s*\n", text) if part.strip()]
    units = paragraphs or _split_sentences(text)

    chunks: list[str] = []
    buffer = ""

    for unit in units:
        candidate = unit if not buffer else f"{buffer}\n\n{unit}"
        if len(candidate) <= max_chars:
            buffer = candidate
            continue

        if buffer:
            chunks.append(buffer)
            buffer = ""

        if len(unit) <= max_chars:
            buffer = unit
            continue

        sentences = _split_sentences(unit)
        sentence_buffer = ""
        for sentence in sentences:
            candidate_sentence = (
                sentence if not sentence_buffer else f"{sentence_buffer} {sentence}"
            )
            if len(candidate_sentence) <= max_chars:
                sentence_buffer = candidate_sentence
                continue

            if sentence_buffer:
                chunks.append(sentence_buffer)
            sentence_buffer = sentence

        if sentence_buffer:
            buffer = sentence_buffer

    if buffer:
        chunks.append(buffer)

    return chunks[:MAX_CHUNKS]


def _keyword_candidates(text: str) -> list[str]:
    counts = Counter(token.lower() for token in TOKEN_PATTERN.findall(text))
    return [token for token, _ in counts.most_common(6)]


def _parse_vocabulary_entries(text: str) -> list[_VocabularyEntry]:
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if len(lines) < 3:
        return []

    entries: list[_VocabularyEntry] = []
    for line in lines:
        cleaned = VOCABULARY_BULLET_PATTERN.sub("", line).strip()
        match = VOCABULARY_SEPARATOR_PATTERN.search(cleaned)
        if match is None:
            continue

        term = cleaned[: match.start()].strip()
        meaning = cleaned[match.end() :].strip()
        if not term or not meaning:
            continue
        if len(term) > 80 or len(meaning) > 240:
            continue

        entries.append(_VocabularyEntry(term=term, meaning=meaning))

    minimum_matches = max(3, math.ceil(len(lines) * 0.6))
    if len(entries) < minimum_matches:
        return []

    return entries[:MAX_CARDS]


def build_vocabulary_card_payloads(text: str) -> list[dict]:
    entries = _parse_vocabulary_entries(text)
    return [
        {
            "term": entry.term,
            "meaning": entry.meaning,
            "card_type": "definition",
            "question": f'What does "{entry.term}" mean?',
            "answer": entry.meaning,
            "difficulty": 2,
            "tags": _keyword_candidates(f"{entry.term} {entry.meaning}"),
        }
        for entry in entries
    ]


def infer_domain_hint(text: str) -> str:
    """Classify material into a lightweight domain without schema changes."""
    if _parse_vocabulary_entries(text):
        return "language"

    lower = text.lower()
    code_markers = (
        "def ",
        "class ",
        "function ",
        "return ",
        "import ",
        "select ",
        "const ",
        "let ",
        "=>",
        "```",
    )
    if any(marker in lower for marker in code_markers):
        return "code"

    language_markers = (
        "vocabulary",
        "grammar",
        "pronunciation",
        "conjugation",
        "translation",
        "synonym",
        "antonym",
    )
    if any(marker in lower for marker in language_markers):
        return "language"

    exam_markers = (
        "exam",
        "quiz",
        "test",
        "formula",
        "definition",
        "theorem",
        "license",
        "certification",
    )
    if any(marker in lower for marker in exam_markers):
        return "exam"

    return "general"


def _domain_subtype(domain_hint: str, draft: _ConceptDraft) -> str:
    text = f"{draft.name} {draft.description}".lower()
    if domain_hint == "code":
        if any(marker in text for marker in ("syntax", "function", "class", "return")):
            return "syntax"
        return "implementation"
    if domain_hint == "language":
        if any(marker in text for marker in ("word", "vocabulary", "synonym")):
            return "vocabulary"
        return "grammar"
    if domain_hint == "exam":
        return "recall"
    return "concept"


def _truncate_words(text: str, max_words: int) -> str:
    words = text.split()
    if len(words) <= max_words:
        return text.strip()
    return " ".join(words[:max_words]).strip()


def infer_source_title(raw_text: str) -> str:
    """Infer a stable local title without requiring a model call."""
    text = " ".join(raw_text.split()).strip()
    if not text:
        return "Captured material"

    if _parse_vocabulary_entries(raw_text):
        return "Vocabulary list"

    first_sentence = _split_sentences(text)[0]
    if ":" in first_sentence:
        head, _, _ = first_sentence.partition(":")
        head = head.strip()
        if 3 <= len(head) <= 80:
            return head

    title = _truncate_words(first_sentence, 8)
    if len(title) > 80:
        return f"{title[:77].rstrip()}..."
    return title or "Captured material"


def _infer_concept_name(text: str, fallback_index: int) -> str:
    first_sentence = _split_sentences(text)[0]
    if ":" in first_sentence:
        head, _, _ = first_sentence.partition(":")
        head = head.strip()
        if 3 <= len(head) <= 80:
            return head

    words = first_sentence.split()
    if words:
        return _truncate_words(first_sentence, 8)

    return f"Concept {fallback_index}"


def _build_concept_draft(chunk_text: str, chunk_index: int) -> _ConceptDraft:
    sentences = _split_sentences(chunk_text)
    description = " ".join(sentences[:2]).strip()
    details = [sentence.strip() for sentence in sentences[2:] if sentence.strip()]
    tags = _keyword_candidates(chunk_text)
    return _ConceptDraft(
        name=_infer_concept_name(chunk_text, chunk_index),
        description=description or chunk_text.strip(),
        details=details,
        tags=tags,
    )


def _estimate_difficulty(description: str, details: list[str]) -> int:
    complexity_score = len(description) + sum(len(item) for item in details[:2])
    if complexity_score < 80:
        return 2
    if complexity_score < 180:
        return 3
    if complexity_score < 320:
        return 4
    return 5


def _build_cards_for_concept(
    draft: _ConceptDraft,
    *,
    domain_hint: str = "general",
) -> list[dict]:
    is_korean = _contains_hangul(f"{draft.name} {draft.description}")
    difficulty = _estimate_difficulty(draft.description, draft.details)

    if is_korean:
        definition_question = f'"{draft.name}"의 핵심 개념은 무엇인가요?'
        principle_question = f'"{draft.name}"가 중요한 이유는 무엇인가요?'
        application_question = f'"{draft.name}"를 적용하거나 떠올릴 예시는 무엇인가요?'
    else:
        definition_question = f'What is the core idea behind "{draft.name}"?'
        principle_question = f'Why does "{draft.name}" matter in this material?'
        application_question = (
            f'What example or application best illustrates "{draft.name}"?'
        )

    if domain_hint == "code" and not is_korean:
        definition_question = f'What does "{draft.name}" do in this code context?'
        application_question = f'How would you use or debug "{draft.name}"?'
    elif domain_hint == "language" and not is_korean:
        definition_question = f'What should you remember about "{draft.name}"?'
        application_question = f'How would you use "{draft.name}" in a sentence?'
    elif domain_hint == "exam" and not is_korean:
        principle_question = f'What exam trap or key rule matters for "{draft.name}"?'

    cards = [
        {
            "card_type": "definition",
            "question": definition_question,
            "answer": draft.description,
            "difficulty": difficulty,
        }
    ]

    if draft.details:
        cards.append(
            {
                "card_type": "principle",
                "question": principle_question,
                "answer": draft.details[0],
                "difficulty": min(5, difficulty + 1),
            }
        )
    elif len(draft.description) > 120:
        cards.append(
            {
                "card_type": "application",
                "question": application_question,
                "answer": draft.description,
                "difficulty": min(5, difficulty + 1),
            }
        )

    return cards


def _relation_strength(left: _ConceptDraft, right: _ConceptDraft) -> tuple[str, float]:
    shared = set(left.tags) & set(right.tags)
    if shared:
        return "similar", min(0.95, 0.45 + len(shared) * 0.12)
    return "prerequisite", 0.35


async def _cleanup_partial_generation_data(source_id: UUID) -> None:
    async with async_session_factory() as db:
        concept_result = await db.execute(
            select(Concept.id)
            .join(SourceChunk, Concept.chunk_id == SourceChunk.id)
            .where(SourceChunk.source_id == source_id)
        )
        concept_ids = list(concept_result.scalars())

        if concept_ids:
            await db.execute(
                delete(ConceptRelation).where(
                    or_(
                        ConceptRelation.concept_a_id.in_(concept_ids),
                        ConceptRelation.concept_b_id.in_(concept_ids),
                    )
                )
            )

        await db.execute(delete(Card).where(Card.source_id == source_id))
        if concept_ids:
            await db.execute(delete(Concept).where(Concept.id.in_(concept_ids)))
        await db.execute(delete(SourceChunk).where(SourceChunk.source_id == source_id))
        await db.commit()


async def _generate_cards_for_source(source: Source, job: Job) -> dict:
    raw_text = _normalize_text(source)
    vocabulary_entries = _parse_vocabulary_entries(raw_text)
    provided_title = bool(source.title and source.title.strip())
    source_title = (
        source.title.strip() if provided_title else infer_source_title(raw_text)
    )
    domain_hint = "language" if vocabulary_entries else infer_domain_hint(raw_text)
    chunks = (
        [f"{entry.term}: {entry.meaning}" for entry in vocabulary_entries]
        if vocabulary_entries
        else _chunk_text(raw_text)
    )
    if not chunks:
        raise ValueError("Unable to split the source into meaningful chunks.")

    selected_model = model_router.select_model(
        task_type="card_generation",
        content_length=len(raw_text),
    )
    prompt_bundle = prompt_manager.build_card_generation_prompt(
        title=source_title,
        raw_text=raw_text,
    )

    async with async_session_factory() as db:
        source = await db.scalar(select(Source).where(Source.id == source.id))
        job = await db.scalar(select(Job).where(Job.id == job.id))
        if source is None or job is None:
            raise ValueError("Source generation context could not be loaded.")
        existing_metadata = source.metadata_ or {}
        if not source.title:
            source.title = source_title

        concept_rows: list[tuple[Concept, _ConceptDraft]] = []
        total_cards = 0

        for chunk_index, chunk_text in enumerate(chunks):
            chunk = SourceChunk(
                source_id=source.id,
                chunk_index=chunk_index,
                content=chunk_text,
                char_count=len(chunk_text),
            )
            db.add(chunk)
            await db.flush()

            if vocabulary_entries:
                entry = vocabulary_entries[chunk_index]
                draft = _ConceptDraft(
                    name=entry.term,
                    description=entry.meaning,
                    details=[],
                    tags=_keyword_candidates(chunk_text),
                )
                concept_category = "vocabulary"
            else:
                draft = _build_concept_draft(chunk_text, chunk_index + 1)
                concept_category = "generated"

            concept = Concept(
                chunk_id=chunk.id,
                name=draft.name,
                description=draft.description,
                category=concept_category,
            )
            db.add(concept)
            await db.flush()
            concept_rows.append((concept, draft))

            domain_subtype = (
                "vocabulary"
                if vocabulary_entries
                else _domain_subtype(domain_hint, draft)
            )
            card_payloads = (
                [
                    {
                        "card_type": "definition",
                        "question": f'What does "{draft.name}" mean?',
                        "answer": draft.description,
                        "difficulty": 2,
                    }
                ]
                if vocabulary_entries
                else _build_cards_for_concept(draft, domain_hint=domain_hint)
            )
            for card_payload in card_payloads:
                if total_cards >= MAX_CARDS:
                    break

                tags = {
                    "keywords": draft.tags,
                    "domain_hint": domain_hint,
                    "domain_subtype": domain_subtype,
                    "source_type": source.source_type,
                }
                if vocabulary_entries:
                    tags["domain_fields"] = {
                        "translation_hint": draft.description,
                    }

                db.add(
                    Card(
                        user_id=source.user_id,
                        source_id=source.id,
                        concept_id=concept.id,
                        card_type=card_payload["card_type"],
                        question=card_payload["question"],
                        answer=card_payload["answer"],
                        difficulty=card_payload["difficulty"],
                        tags=tags,
                    )
                )
                total_cards += 1

        for index in range(len(concept_rows) - 1):
            left_concept, left_draft = concept_rows[index]
            right_concept, right_draft = concept_rows[index + 1]
            relation_type, strength = _relation_strength(left_draft, right_draft)
            db.add(
                ConceptRelation(
                    concept_a_id=left_concept.id,
                    concept_b_id=right_concept.id,
                    relation_type=relation_type,
                    strength=strength,
                )
            )

        source.status = "done"
        source.error_message = None
        source.metadata_ = {
            **existing_metadata,
            "chunk_count": len(chunks),
            "concept_count": len(concept_rows),
            "card_count": total_cards,
            "domain_hint": domain_hint,
            "generator": HEURISTIC_MODEL_NAME,
            "input_pattern": (
                "vocabulary_list" if vocabulary_entries else "concept_notes"
            ),
            "title_strategy": existing_metadata.get("title_strategy")
            or ("provided" if provided_title else "heuristic"),
        }
        job.status = "completed"
        job.result_summary = source.metadata_
        job.completed_at = _utcnow()
        output_text = "\n".join(
            f"{concept.name}: {concept.description}" for concept, _ in concept_rows
        )
        usage = cost_controller.estimate_generation_cost(
            model_used=selected_model,
            prompt=prompt_bundle,
            output_text=output_text,
        )
        db.add(
            AIUsageLog(
                user_id=source.user_id,
                request_type="card_generation",
                model_used=str(usage["model_used"]),
                input_tokens=int(usage["input_tokens"]),
                output_tokens=int(usage["output_tokens"]),
                cost_usd=float(usage["cost_usd"]),
            )
        )

        await db.commit()
        return source.metadata_


async def run_card_generation_job(job_id: UUID) -> None:
    async with async_session_factory() as db:
        claim_time = _utcnow()
        claim_result = await db.execute(
            update(Job)
            .where(Job.id == job_id, Job.status == "pending")
            .values(
                status="running",
                started_at=claim_time,
                completed_at=None,
                error_message=None,
            )
            .returning(Job.source_id)
        )
        source_id = claim_result.scalar_one_or_none()
        if source_id is None:
            return

        source = await db.scalar(select(Source).where(Source.id == source_id))
        if source is None:
            failed_job = await db.scalar(select(Job).where(Job.id == job_id))
            if failed_job is not None:
                failed_job.status = "failed"
                failed_job.error_message = "Source not found."
                failed_job.completed_at = _utcnow()
            await db.commit()
            return

        source.status = "analyzing"
        source.error_message = None
        await db.commit()

    try:
        await _cleanup_partial_generation_data(source.id)
        async with async_session_factory() as refresh_db:
            claimed_job = await refresh_db.scalar(select(Job).where(Job.id == job_id))
            claimed_source = await refresh_db.scalar(
                select(Source).where(Source.id == source.id)
            )
        if claimed_job is None or claimed_source is None:
            return
        await _generate_cards_for_source(claimed_source, claimed_job)
    except Exception as exc:
        async with async_session_factory() as failure_db:
            failed_job = await failure_db.scalar(select(Job).where(Job.id == job_id))
            if failed_job is None:
                return

            failed_source = await failure_db.scalar(
                select(Source).where(Source.id == failed_job.source_id)
            )
            failed_job.status = "failed"
            failed_job.error_message = str(exc)
            failed_job.completed_at = _utcnow()
            if failed_source is not None:
                failed_source.status = "error"
                failed_source.error_message = str(exc)
            await failure_db.commit()
