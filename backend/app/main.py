"""
Plowth - AI Learning OS
FastAPI application entry point.
"""

from typing import cast

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import auth, cards, insights, jobs, reviews, sources, sync
from app.config import get_settings
from app.database import Base, engine
from app.services.card_generation import run_card_generation_job
from app.services.job_runner import JobScheduler, build_job_runner

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan hooks."""
    app.state.job_runner = build_job_runner(
        mode=settings.JOB_EXECUTION_MODE,
        card_generation_handler=run_card_generation_job,
    )
    if settings.AUTO_CREATE_TABLES:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    await cast(JobScheduler, app.state.job_runner).schedule_recoverable_jobs()
    yield
    await cast(JobScheduler, app.state.job_runner).shutdown()
    await engine.dispose()


app = FastAPI(
    title=f"{settings.APP_NAME} API",
    description="AI-powered learning operating system API server",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS is only relevant for browser-based clients. Native mobile apps do not use it,
# so we keep an explicit allow-list instead of a wildcard.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ALLOW_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers.
app.include_router(auth.router, prefix="/api/v1")
app.include_router(sources.router, prefix="/api/v1")
app.include_router(cards.router, prefix="/api/v1")
app.include_router(insights.router, prefix="/api/v1")
app.include_router(jobs.router, prefix="/api/v1")
app.include_router(reviews.router, prefix="/api/v1")
app.include_router(sync.router, prefix="/api/v1")


@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "app": settings.APP_NAME,
        "version": "0.1.0",
        "env": settings.APP_ENV,
        "job_execution_mode": settings.JOB_EXECUTION_MODE,
    }
