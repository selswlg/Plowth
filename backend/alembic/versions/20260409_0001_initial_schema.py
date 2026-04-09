"""Initial Plowth schema.

Revision ID: 20260409_0001
Revises:
Create Date: 2026-04-09 14:30:00
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = "20260409_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=True),
        sa.Column("hashed_password", sa.String(length=255), nullable=True),
        sa.Column("name", sa.String(length=100), nullable=True),
        sa.Column("auth_provider", sa.String(length=50), nullable=False),
        sa.Column("is_guest", sa.Boolean(), nullable=False),
        sa.Column("device_id", sa.String(length=255), nullable=True),
        sa.Column("preferences", sa.JSON(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_users_device_id", "users", ["device_id"], unique=False)
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "sources",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("title", sa.String(length=500), nullable=True),
        sa.Column("source_type", sa.String(length=50), nullable=False),
        sa.Column("raw_content", sa.Text(), nullable=True),
        sa.Column("url", sa.String(length=2000), nullable=True),
        sa.Column("file_path", sa.String(length=1000), nullable=True),
        sa.Column("status", sa.String(length=50), nullable=False),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column("metadata", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_sources_user_id", "sources", ["user_id"], unique=False)

    op.create_table(
        "source_chunks",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("source_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("chunk_index", sa.Integer(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("char_count", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["source_id"], ["sources.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_source_chunks_source_id", "source_chunks", ["source_id"], unique=False)

    op.create_table(
        "concepts",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("chunk_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("name", sa.String(length=500), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("category", sa.String(length=200), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["chunk_id"], ["source_chunks.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_concepts_chunk_id", "concepts", ["chunk_id"], unique=False)

    op.create_table(
        "cards",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("source_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("concept_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("card_type", sa.String(length=50), nullable=False),
        sa.Column("question", sa.Text(), nullable=False),
        sa.Column("answer", sa.Text(), nullable=False),
        sa.Column("difficulty", sa.Integer(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("tags", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["concept_id"], ["concepts.id"]),
        sa.ForeignKeyConstraint(["source_id"], ["sources.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_cards_concept_id", "cards", ["concept_id"], unique=False)
    op.create_index("ix_cards_source_id", "cards", ["source_id"], unique=False)
    op.create_index("ix_cards_user_id", "cards", ["user_id"], unique=False)

    op.create_table(
        "reviews",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("card_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("rating", sa.String(length=20), nullable=False),
        sa.Column("response_time_ms", sa.Integer(), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("synced", sa.Boolean(), nullable=False),
        sa.Column("client_id", sa.String(length=100), nullable=True),
        sa.ForeignKeyConstraint(["card_id"], ["cards.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_reviews_reviewed_at", "reviews", ["reviewed_at"], unique=False)
    op.create_index("ix_reviews_user_card", "reviews", ["user_id", "card_id"], unique=False)

    op.create_table(
        "memory_states",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("card_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("stability", sa.Float(), nullable=False),
        sa.Column("difficulty", sa.Float(), nullable=False),
        sa.Column("retrievability", sa.Float(), nullable=False),
        sa.Column("reps", sa.Integer(), nullable=False),
        sa.Column("lapses", sa.Integer(), nullable=False),
        sa.Column("state", sa.String(length=20), nullable=False),
        sa.Column("next_review_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_review_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["card_id"], ["cards.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_memory_next_review", "memory_states", ["next_review_at"], unique=False)
    op.create_index("ix_memory_user_card", "memory_states", ["user_id", "card_id"], unique=True)

    op.create_table(
        "mistake_patterns",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("concept_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("pattern_type", sa.String(length=100), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("occurrence_count", sa.Integer(), nullable=False),
        sa.Column("last_occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("resolved", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["concept_id"], ["concepts.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_mistake_patterns_user_id", "mistake_patterns", ["user_id"], unique=False)

    op.create_table(
        "learning_profiles",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("total_reviews", sa.Integer(), nullable=False),
        sa.Column("total_cards", sa.Integer(), nullable=False),
        sa.Column("avg_accuracy", sa.Float(), nullable=False),
        sa.Column("avg_response_time_ms", sa.Integer(), nullable=False),
        sa.Column("best_hour", sa.Integer(), nullable=True),
        sa.Column("worst_hour", sa.Integer(), nullable=True),
        sa.Column("streak_days", sa.Integer(), nullable=False),
        sa.Column("longest_streak", sa.Integer(), nullable=False),
        sa.Column("profile_data", sa.JSON(), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id"),
    )

    op.create_table(
        "interventions",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("trigger_type", sa.String(length=100), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("shown", sa.Boolean(), nullable=False),
        sa.Column("dismissed", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_interventions_user_id", "interventions", ["user_id"], unique=False)

    op.create_table(
        "jobs",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("job_type", sa.String(length=100), nullable=False),
        sa.Column("status", sa.String(length=50), nullable=False),
        sa.Column("source_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("result_summary", sa.JSON(), nullable=True),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["source_id"], ["sources.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_jobs_user_id", "jobs", ["user_id"], unique=False)

    op.create_table(
        "subscriptions",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("plan", sa.String(length=50), nullable=False),
        sa.Column("status", sa.String(length=50), nullable=False),
        sa.Column("ai_calls_used", sa.Integer(), nullable=False),
        sa.Column("ai_calls_limit", sa.Integer(), nullable=False),
        sa.Column("current_period_start", sa.DateTime(timezone=True), nullable=True),
        sa.Column("current_period_end", sa.DateTime(timezone=True), nullable=True),
        sa.Column("stripe_customer_id", sa.String(length=255), nullable=True),
        sa.Column("stripe_subscription_id", sa.String(length=255), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id"),
    )

    op.create_table(
        "concept_relations",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("concept_a_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("concept_b_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("relation_type", sa.String(length=50), nullable=False),
        sa.Column("strength", sa.Float(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["concept_a_id"], ["concepts.id"]),
        sa.ForeignKeyConstraint(["concept_b_id"], ["concepts.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("concept_a_id", "concept_b_id", name="uq_concept_pair"),
    )
    op.create_index(
        "ix_concept_relations_concept_a_id",
        "concept_relations",
        ["concept_a_id"],
        unique=False,
    )
    op.create_index(
        "ix_concept_relations_concept_b_id",
        "concept_relations",
        ["concept_b_id"],
        unique=False,
    )

    op.create_table(
        "daily_review_queue",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("card_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("queue_date", sa.Date(), nullable=False),
        sa.Column("priority", sa.Float(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["card_id"], ["cards.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_drq_user_date_status",
        "daily_review_queue",
        ["user_id", "queue_date", "status"],
        unique=False,
    )

    op.create_table(
        "sync_events",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("device_id", sa.String(length=255), nullable=False),
        sa.Column("event_type", sa.String(length=50), nullable=False),
        sa.Column("event_payload", sa.JSON(), nullable=False),
        sa.Column("client_timestamp", sa.DateTime(timezone=True), nullable=False),
        sa.Column("server_timestamp", sa.DateTime(timezone=True), nullable=False),
        sa.Column("processed", sa.Boolean(), nullable=False),
        sa.Column("client_event_id", sa.String(length=100), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "client_event_id", name="uq_sync_event"),
    )
    op.create_index(
        "ix_sync_user_timestamp",
        "sync_events",
        ["user_id", "server_timestamp"],
        unique=False,
    )

    op.create_table(
        "ai_cache",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("card_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("request_type", sa.String(length=50), nullable=False),
        sa.Column("response_json", sa.JSON(), nullable=False),
        sa.Column("model_used", sa.String(length=100), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["card_id"], ["cards.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("card_id", "request_type", name="uq_ai_cache_card_type"),
    )
    op.create_index("ix_ai_cache_card_id", "ai_cache", ["card_id"], unique=False)

    op.create_table(
        "ai_usage_log",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("request_type", sa.String(length=100), nullable=False),
        sa.Column("model_used", sa.String(length=100), nullable=False),
        sa.Column("input_tokens", sa.Integer(), nullable=False),
        sa.Column("output_tokens", sa.Integer(), nullable=False),
        sa.Column("cost_usd", sa.Float(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_ai_usage_user_date", "ai_usage_log", ["user_id", "created_at"], unique=False)


def downgrade() -> None:
    op.drop_table("ai_usage_log")
    op.drop_table("ai_cache")
    op.drop_table("sync_events")
    op.drop_table("daily_review_queue")
    op.drop_table("concept_relations")
    op.drop_table("subscriptions")
    op.drop_table("jobs")
    op.drop_table("interventions")
    op.drop_table("learning_profiles")
    op.drop_table("mistake_patterns")
    op.drop_table("memory_states")
    op.drop_table("reviews")
    op.drop_table("cards")
    op.drop_table("concepts")
    op.drop_table("source_chunks")
    op.drop_table("sources")
    op.drop_table("users")
