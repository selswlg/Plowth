"""
Jobs API: background task polling for source processing and other async work.
"""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import Job, User
from app.schemas import JobResponse

router = APIRouter(prefix="/jobs", tags=["Jobs"])


@router.get("", response_model=list[JobResponse])
async def list_jobs(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    source_id: UUID | None = None,
    limit: int = Query(20, ge=1, le=100),
):
    query = select(Job).where(Job.user_id == current_user.id)
    if source_id is not None:
        query = query.where(Job.source_id == source_id)

    result = await db.execute(query.order_by(Job.created_at.desc()).limit(limit))
    jobs = result.scalars().all()
    for job in jobs:
        if job.status in {"pending", "running"}:
            await request.app.state.job_runner.schedule(job.id)
    return jobs


@router.get("/{job_id}", response_model=JobResponse)
async def get_job(
    request: Request,
    job_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Job).where(Job.id == job_id, Job.user_id == current_user.id)
    )
    job = result.scalar_one_or_none()
    if job is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")
    if job.status in {"pending", "running"}:
        await request.app.state.job_runner.schedule(job.id)
    return job


@router.post("/{job_id}/retry", response_model=JobResponse)
async def retry_job(
    request: Request,
    job_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Job).where(Job.id == job_id, Job.user_id == current_user.id)
    )
    job = result.scalar_one_or_none()
    if job is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")
    if job.status != "failed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only failed jobs can be retried.",
        )

    job.status = "pending"
    job.error_message = None
    job.started_at = None
    job.completed_at = None
    await db.flush()
    await db.commit()
    await request.app.state.job_runner.schedule(job.id)
    return job
