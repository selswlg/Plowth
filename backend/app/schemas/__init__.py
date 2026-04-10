"""
Pydantic schemas for request/response validation.
"""

from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, EmailStr, Field


# ─── Auth ─────────────────────────────────────────────────────────────────────

class UserRegister(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    name: str | None = Field(None, max_length=100)


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class TokenRefresh(BaseModel):
    refresh_token: str


class GuestRequest(BaseModel):
    device_id: str = Field(min_length=10, max_length=255)
    learning_goal: str | None = Field(None, max_length=200)  # from onboarding step 3


class GuestUpgradeRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    name: str | None = Field(None, max_length=100)


class UserResponse(BaseModel):
    id: UUID
    email: str | None
    name: str | None
    auth_provider: str
    is_guest: bool
    preferences: dict | None
    created_at: datetime

    model_config = {"from_attributes": True}


# ─── Sources ──────────────────────────────────────────────────────────────────

class SourceCreate(BaseModel):
    title: str | None = Field(None, max_length=500)
    source_type: str = Field(
        "text",
        pattern="^(text|csv|pdf|link)$",
        description=(
            "Supported source type contract. Text is handled by /sources; "
            "CSV uses /sources/csv/*; PDF/link remain follow-up runtime paths."
        ),
    )
    raw_content: str | None = None
    url: str | None = Field(None, max_length=2000)


class SourceResponse(BaseModel):
    id: UUID
    title: str | None
    source_type: str
    status: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class SourceCreateResponse(SourceResponse):
    job_id: UUID | None = None


class SourceDetail(SourceResponse):
    raw_content: str | None
    url: str | None
    error_message: str | None
    metadata_: dict | None = Field(None, alias="metadata_")


class CsvPreviewResponse(BaseModel):
    columns: list[str]
    sample_rows: list[dict[str, str]]
    row_count: int


class CsvImportResponse(BaseModel):
    source_id: UUID
    title: str | None
    source_type: str
    status: str
    card_count: int
    skipped_count: int
    row_count: int
    columns: list[str]


# ─── Cards ────────────────────────────────────────────────────────────────────

class CardCreate(BaseModel):
    source_id: UUID
    concept_id: UUID | None = None
    card_type: str = Field("definition", pattern="^(definition|principle|comparison|application)$")
    question: str = Field(min_length=5, max_length=1000)
    answer: str = Field(min_length=3, max_length=2000)
    difficulty: int = Field(3, ge=1, le=5)


class CardUpdate(BaseModel):
    question: str | None = Field(None, min_length=5, max_length=1000)
    answer: str | None = Field(None, min_length=3, max_length=2000)
    difficulty: int | None = Field(None, ge=1, le=5)
    is_active: bool | None = None


class CardResponse(BaseModel):
    id: UUID
    source_id: UUID
    concept_id: UUID | None
    card_type: str
    question: str
    answer: str
    difficulty: int
    is_active: bool
    tags: dict | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


# ─── Reviews ──────────────────────────────────────────────────────────────────

class ReviewCreate(BaseModel):
    card_id: UUID
    rating: str = Field(pattern="^(again|hard|good|easy)$")
    response_time_ms: int | None = Field(None, ge=0)
    client_id: str | None = Field(None, max_length=100)  # for idempotent sync


class ReviewResponse(BaseModel):
    id: UUID
    card_id: UUID
    rating: str
    response_time_ms: int | None
    reviewed_at: datetime

    model_config = {"from_attributes": True}


class ReviewQueueCard(BaseModel):
    id: UUID
    source_id: UUID
    source_title: str | None
    question: str
    answer: str
    card_type: str
    difficulty: int
    tags: dict | None = None
    state: str
    next_review_at: datetime | None
    reps: int
    lapses: int


class ReviewSessionSummary(BaseModel):
    total_cards: int
    again_count: int
    hard_count: int
    good_count: int
    easy_count: int
    avg_response_time_ms: float | None
    accuracy_rate: float  # (good + easy) / total


# ─── Jobs ─────────────────────────────────────────────────────────────────────

class JobResponse(BaseModel):
    id: UUID
    job_type: str
    status: str
    source_id: UUID | None
    result_summary: dict | None
    error_message: str | None
    created_at: datetime
    completed_at: datetime | None

    model_config = {"from_attributes": True}


# ─── Insights ─────────────────────────────────────────────────────────────────

class DailyInsight(BaseModel):
    total_due_today: int
    completed_today: int
    accuracy_today: float | None
    streak_days: int
    memory_strength: float  # average retrievability


class WeakConcept(BaseModel):
    concept_name: str
    failure_count: int
    last_failed_at: datetime | None


class InsightSnapshot(BaseModel):
    overview: DailyInsight
    weak_concepts: list[WeakConcept]
    coach_title: str
    coach_message: str
    focus_topic: str | None = None


class CognitiveUpdatePreviewRequest(BaseModel):
    concept_name: str = Field(min_length=2, max_length=500)
    description: str | None = Field(None, max_length=2000)
    limit: int = Field(5, ge=1, le=10)


class CognitiveUpdateCardCandidate(BaseModel):
    card_id: UUID
    question: str
    answer_excerpt: str


class CognitiveUpdateMatch(BaseModel):
    concept_id: UUID
    concept_name: str
    similarity: float
    suggested_action: str
    cards: list[CognitiveUpdateCardCandidate]


class CognitiveUpdatePreviewResponse(BaseModel):
    matches: list[CognitiveUpdateMatch]


class CognitiveUpdateApplyRequest(BaseModel):
    card_id: UUID
    new_evidence: str = Field(min_length=3, max_length=2000)
    source_concept_name: str | None = Field(None, max_length=500)
    action: str = Field("reinforce", pattern="^(reinforce|keep_separate|skip_duplicate)$")


class TutorResponse(BaseModel):
    card_id: UUID
    request_type: str
    title: str
    content: str
    bullets: list[str]
    related_concepts: list[str]
    cached: bool
    generated_at: datetime
    expires_at: datetime
