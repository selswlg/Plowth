"""
Sources API: CRUD for learning materials (text, PDF, links).
"""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import Job, Source, User
from app.schemas import SourceCreate, SourceCreateResponse, SourceDetail, SourceResponse

router = APIRouter(prefix="/sources", tags=["Sources"])


@router.post("", response_model=SourceCreateResponse, status_code=status.HTTP_201_CREATED)
async def create_source(
    body: SourceCreate,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Upload a new learning material."""
    if body.source_type != "text":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            # Keep runtime text-only for Phase 2 stability. Revisit when the
            # PDF/link ingestion pipeline is implemented end-to-end.
            detail="Phase 2 currently supports text capture only.",
        )

    if body.source_type == "text" and not body.raw_content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="raw_content is required for text sources",
        )

    existing_result = await db.execute(
        select(Source, Job)
        .join(
            Job,
            and_(
                Job.source_id == Source.id,
                Job.job_type == "card_generation",
            ),
        )
        .where(
            Source.user_id == current_user.id,
            Source.source_type == body.source_type,
            Source.title == body.title,
            Source.raw_content == body.raw_content,
            Job.status.in_(("pending", "running")),
        )
        .order_by(Job.created_at.desc())
        .limit(1)
    )
    existing = existing_result.first()
    if existing is not None:
        source, job = existing
        await request.app.state.job_runner.schedule(job.id)
        return SourceCreateResponse(
            id=source.id,
            title=source.title,
            source_type=source.source_type,
            status=source.status,
            created_at=source.created_at,
            updated_at=source.updated_at,
            job_id=job.id,
        )

    source = Source(
        user_id=current_user.id,
        title=body.title,
        source_type=body.source_type,
        raw_content=body.raw_content,
        url=body.url,
        status="analyzing",
    )
    db.add(source)
    await db.flush()

    job = Job(
        user_id=current_user.id,
        job_type="card_generation",
        status="pending",
        source_id=source.id,
        result_summary={"phase": "phase2"},
    )
    db.add(job)
    await db.flush()
    await db.commit()
    await request.app.state.job_runner.schedule(job.id)

    return SourceCreateResponse(
        id=source.id,
        title=source.title,
        source_type=source.source_type,
        status=source.status,
        created_at=source.created_at,
        updated_at=source.updated_at,
        job_id=job.id,
    )


@router.get("", response_model=list[SourceResponse])
async def list_sources(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    """List user's learning materials."""
    result = await db.execute(
        select(Source)
        .where(Source.user_id == current_user.id)
        .order_by(Source.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    return result.scalars().all()


@router.get("/{source_id}", response_model=SourceDetail)
async def get_source(
    source_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get details of a specific source."""
    result = await db.execute(
        select(Source).where(Source.id == source_id, Source.user_id == current_user.id)
    )
    source = result.scalar_one_or_none()
    if not source:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Source not found")
    return source


@router.delete("/{source_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_source(
    source_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a source and its associated cards."""
    result = await db.execute(
        select(Source).where(Source.id == source_id, Source.user_id == current_user.id)
    )
    source = result.scalar_one_or_none()
    if not source:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Source not found")

    await db.delete(source)
