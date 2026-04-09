"""
SQLAlchemy ORM models for the Plowth application.

Tables (16 + 1):
- users: User accounts (includes guest support)
- sources: Learning materials uploaded by users
- source_chunks: Text chunks from sources
- concepts: Extracted concepts from chunks
- concept_relations: Connections between concepts (graph edges)
- cards: Flashcards generated from concepts
- reviews: Review history (append-only)
- memory_states: FSRS memory tracking per card per user
- daily_review_queue: Pre-computed daily review queue
- mistake_patterns: Detected mistake patterns
- learning_profiles: User learning analytics
- interventions: AI coach interventions log
- jobs: Async job tracking (card generation, etc.)
- subscriptions: User subscription status
- sync_events: Offline sync event log
- ai_cache: Cached AI responses per card
- ai_usage_log: AI cost tracking
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    String, Text, Integer, Float, Boolean, DateTime, Date,
    ForeignKey, Index, UniqueConstraint, JSON,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID

from app.database import Base


def utcnow():
    return datetime.now(timezone.utc)


def new_uuid():
    return uuid.uuid4()


# ─── Users ────────────────────────────────────────────────────────────────────

class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    email: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True, index=True)  # nullable for guests
    hashed_password: Mapped[str | None] = mapped_column(String(255), nullable=True)  # nullable for guests
    name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    auth_provider: Mapped[str] = mapped_column(String(50), default="email")  # email, google, apple, kakao, guest
    is_guest: Mapped[bool] = mapped_column(Boolean, default=False)
    device_id: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)  # for guest sessions
    preferences: Mapped[dict | None] = mapped_column(JSON, default=dict)  # includes learning_goal
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)

    # Relationships
    sources: Mapped[list["Source"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    cards: Mapped[list["Card"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    reviews: Mapped[list["Review"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    memory_states: Mapped[list["MemoryState"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    learning_profile: Mapped["LearningProfile | None"] = relationship(back_populates="user", uselist=False)
    subscription: Mapped["Subscription | None"] = relationship(back_populates="user", uselist=False)


# ─── Sources ──────────────────────────────────────────────────────────────────

class Source(Base):
    __tablename__ = "sources"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(500), nullable=True)
    source_type: Mapped[str] = mapped_column(String(50), nullable=False)  # text, pdf, link
    raw_content: Mapped[str | None] = mapped_column(Text, nullable=True)
    url: Mapped[str | None] = mapped_column(String(2000), nullable=True)
    file_path: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    status: Mapped[str] = mapped_column(String(50), default="uploaded")  # uploaded, analyzing, done, error
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    metadata_: Mapped[dict | None] = mapped_column("metadata", JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)

    # Relationships
    user: Mapped["User"] = relationship(back_populates="sources")
    chunks: Mapped[list["SourceChunk"]] = relationship(back_populates="source", cascade="all, delete-orphan")
    cards: Mapped[list["Card"]] = relationship(back_populates="source", cascade="all, delete-orphan")


# ─── Source Chunks ────────────────────────────────────────────────────────────

class SourceChunk(Base):
    __tablename__ = "source_chunks"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    source_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("sources.id"), nullable=False, index=True)
    chunk_index: Mapped[int] = mapped_column(Integer, nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    char_count: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    # Relationships
    source: Mapped["Source"] = relationship(back_populates="chunks")
    concepts: Mapped[list["Concept"]] = relationship(back_populates="chunk", cascade="all, delete-orphan")


# ─── Concepts ─────────────────────────────────────────────────────────────────

class Concept(Base):
    __tablename__ = "concepts"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    chunk_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("source_chunks.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(500), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    category: Mapped[str | None] = mapped_column(String(200), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    # Relationships
    chunk: Mapped["SourceChunk"] = relationship(back_populates="concepts")
    cards: Mapped[list["Card"]] = relationship(back_populates="concept", cascade="all, delete-orphan")


# ─── Cards ────────────────────────────────────────────────────────────────────

class Card(Base):
    __tablename__ = "cards"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    source_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("sources.id"), nullable=False, index=True)
    concept_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("concepts.id"), nullable=True, index=True)
    card_type: Mapped[str] = mapped_column(String(50), nullable=False)  # definition, principle, comparison, application
    question: Mapped[str] = mapped_column(Text, nullable=False)
    answer: Mapped[str] = mapped_column(Text, nullable=False)
    difficulty: Mapped[int] = mapped_column(Integer, default=3)  # 1-5
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    tags: Mapped[dict | None] = mapped_column(JSON, default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)

    # Relationships
    user: Mapped["User"] = relationship(back_populates="cards")
    source: Mapped["Source"] = relationship(back_populates="cards")
    concept: Mapped["Concept | None"] = relationship(back_populates="cards")
    reviews: Mapped[list["Review"]] = relationship(back_populates="card", cascade="all, delete-orphan")
    memory_state: Mapped["MemoryState | None"] = relationship(back_populates="card", uselist=False)


# ─── Reviews (append-only) ───────────────────────────────────────────────────

class Review(Base):
    __tablename__ = "reviews"
    __table_args__ = (
        Index("ix_reviews_user_card", "user_id", "card_id"),
        Index("ix_reviews_reviewed_at", "reviewed_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    card_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("cards.id"), nullable=False)
    rating: Mapped[str] = mapped_column(String(20), nullable=False)  # again, hard, good, easy
    response_time_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)
    reviewed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    synced: Mapped[bool] = mapped_column(Boolean, default=True)
    client_id: Mapped[str | None] = mapped_column(String(100), nullable=True)  # for idempotent sync

    # Relationships
    user: Mapped["User"] = relationship(back_populates="reviews")
    card: Mapped["Card"] = relationship(back_populates="reviews")


# ─── Memory States (FSRS) ────────────────────────────────────────────────────

class MemoryState(Base):
    __tablename__ = "memory_states"
    __table_args__ = (
        Index("ix_memory_user_card", "user_id", "card_id", unique=True),
        Index("ix_memory_next_review", "next_review_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    card_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("cards.id"), nullable=False)
    stability: Mapped[float] = mapped_column(Float, default=0.0)
    difficulty: Mapped[float] = mapped_column(Float, default=0.0)
    retrievability: Mapped[float] = mapped_column(Float, default=1.0)
    reps: Mapped[int] = mapped_column(Integer, default=0)
    lapses: Mapped[int] = mapped_column(Integer, default=0)
    state: Mapped[str] = mapped_column(String(20), default="new")  # new, learning, review, relearning
    next_review_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_review_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)

    # Relationships
    user: Mapped["User"] = relationship(back_populates="memory_states")
    card: Mapped["Card"] = relationship(back_populates="memory_state")


# ─── Mistake Patterns ────────────────────────────────────────────────────────

class MistakePattern(Base):
    __tablename__ = "mistake_patterns"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    concept_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("concepts.id"), nullable=True)
    pattern_type: Mapped[str] = mapped_column(String(100), nullable=False)  # confusion, forgetting, slow_response
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    occurrence_count: Mapped[int] = mapped_column(Integer, default=1)
    last_occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    resolved: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


# ─── Learning Profiles ───────────────────────────────────────────────────────

class LearningProfile(Base):
    __tablename__ = "learning_profiles"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), unique=True, nullable=False)
    total_reviews: Mapped[int] = mapped_column(Integer, default=0)
    total_cards: Mapped[int] = mapped_column(Integer, default=0)
    avg_accuracy: Mapped[float] = mapped_column(Float, default=0.0)
    avg_response_time_ms: Mapped[int] = mapped_column(Integer, default=0)
    best_hour: Mapped[int | None] = mapped_column(Integer, nullable=True)  # 0-23
    worst_hour: Mapped[int | None] = mapped_column(Integer, nullable=True)
    streak_days: Mapped[int] = mapped_column(Integer, default=0)
    longest_streak: Mapped[int] = mapped_column(Integer, default=0)
    profile_data: Mapped[dict | None] = mapped_column(JSON, default=dict)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)

    # Relationships
    user: Mapped["User"] = relationship(back_populates="learning_profile")


# ─── Interventions ────────────────────────────────────────────────────────────

class Intervention(Base):
    __tablename__ = "interventions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    trigger_type: Mapped[str] = mapped_column(String(100), nullable=False)  # repeated_failure, accuracy_drop, fatigue, reminder
    message: Mapped[str] = mapped_column(Text, nullable=False)
    shown: Mapped[bool] = mapped_column(Boolean, default=False)
    dismissed: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


# ─── Jobs (async task tracking) ──────────────────────────────────────────────

class Job(Base):
    __tablename__ = "jobs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    job_type: Mapped[str] = mapped_column(String(100), nullable=False)  # card_generation, pdf_processing, analysis
    status: Mapped[str] = mapped_column(String(50), default="pending")  # pending, running, completed, failed
    source_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("sources.id"), nullable=True)
    result_summary: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


# ─── Subscriptions ───────────────────────────────────────────────────────────

class Subscription(Base):
    __tablename__ = "subscriptions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), unique=True, nullable=False)
    plan: Mapped[str] = mapped_column(String(50), default="free")  # free, pro, vip
    status: Mapped[str] = mapped_column(String(50), default="active")  # active, cancelled, expired
    ai_calls_used: Mapped[int] = mapped_column(Integer, default=0)
    ai_calls_limit: Mapped[int] = mapped_column(Integer, default=50)  # free tier default
    current_period_start: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    current_period_end: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    stripe_customer_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    stripe_subscription_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)

    # Relationships
    user: Mapped["User"] = relationship(back_populates="subscription")


# ─── Concept Relations (graph edges) ─────────────────────────────────────────

class ConceptRelation(Base):
    __tablename__ = "concept_relations"
    __table_args__ = (
        UniqueConstraint("concept_a_id", "concept_b_id", name="uq_concept_pair"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    concept_a_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("concepts.id"), nullable=False, index=True)
    concept_b_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("concepts.id"), nullable=False, index=True)
    relation_type: Mapped[str] = mapped_column(String(50), nullable=False)  # prerequisite, similar, opposite, part_of
    strength: Mapped[float] = mapped_column(Float, default=0.5)  # 0.0~1.0
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


# ─── Daily Review Queue ──────────────────────────────────────────────────────

class DailyReviewQueue(Base):
    __tablename__ = "daily_review_queue"
    __table_args__ = (
        Index("ix_drq_user_date_status", "user_id", "queue_date", "status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    card_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("cards.id"), nullable=False)
    queue_date: Mapped[datetime] = mapped_column(Date, nullable=False)
    priority: Mapped[float] = mapped_column(Float, default=0.5)  # urgency score, higher = first
    status: Mapped[str] = mapped_column(String(20), default="pending")  # pending, completed, skipped
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


# ─── Sync Events ─────────────────────────────────────────────────────────────

class SyncEvent(Base):
    __tablename__ = "sync_events"
    __table_args__ = (
        UniqueConstraint("user_id", "client_event_id", name="uq_sync_event"),
        Index("ix_sync_user_timestamp", "user_id", "server_timestamp"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    device_id: Mapped[str] = mapped_column(String(255), nullable=False)
    event_type: Mapped[str] = mapped_column(String(50), nullable=False)  # review, card_edit, card_create, settings
    event_payload: Mapped[dict] = mapped_column(JSON, nullable=False)
    client_timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    server_timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    processed: Mapped[bool] = mapped_column(Boolean, default=False)
    client_event_id: Mapped[str] = mapped_column(String(100), nullable=False)  # idempotent key


# ─── AI Cache ────────────────────────────────────────────────────────────────

class AICache(Base):
    __tablename__ = "ai_cache"
    __table_args__ = (
        UniqueConstraint("card_id", "request_type", name="uq_ai_cache_card_type"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    card_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("cards.id"), nullable=False, index=True)
    request_type: Mapped[str] = mapped_column(String(50), nullable=False)  # explain, example, related
    response_json: Mapped[dict] = mapped_column(JSON, nullable=False)
    model_used: Mapped[str] = mapped_column(String(100), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


# ─── AI Usage Log ────────────────────────────────────────────────────────────

class AIUsageLog(Base):
    __tablename__ = "ai_usage_log"
    __table_args__ = (
        Index("ix_ai_usage_user_date", "user_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    request_type: Mapped[str] = mapped_column(String(100), nullable=False)  # card_generation, explain, example, related, coaching
    model_used: Mapped[str] = mapped_column(String(100), nullable=False)
    input_tokens: Mapped[int] = mapped_column(Integer, default=0)
    output_tokens: Mapped[int] = mapped_column(Integer, default=0)
    cost_usd: Mapped[float] = mapped_column(Float, default=0.0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
