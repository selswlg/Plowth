"""
In-process job runner for Phase 2 background work.

This is not a replacement for Cloud Tasks, but it gives the local stack durable
recovery by re-scheduling pending/running jobs on startup and on job polling.
"""

from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from typing import Protocol
from uuid import UUID

from sqlalchemy import select, update

from app.database import async_session_factory
from app.models import Job

JobHandler = Callable[[UUID], Awaitable[None]]


class JobScheduler(Protocol):
    async def schedule(self, job_id: UUID) -> bool: ...

    async def schedule_recoverable_jobs(self) -> int: ...

    async def shutdown(self) -> None: ...


class JobRunner:
    def __init__(self, *, card_generation_handler: JobHandler) -> None:
        self._card_generation_handler = card_generation_handler
        self._tasks: dict[UUID, asyncio.Task[None]] = {}
        self._lock = asyncio.Lock()

    async def schedule(self, job_id: UUID) -> bool:
        async with self._lock:
            task = self._tasks.get(job_id)
            if task is not None and not task.done():
                return False

            scheduled_task = asyncio.create_task(self._run(job_id))
            self._tasks[job_id] = scheduled_task
            scheduled_task.add_done_callback(lambda _: self._tasks.pop(job_id, None))
            return True

    async def schedule_recoverable_jobs(self) -> int:
        async with async_session_factory() as db:
            await db.execute(
                update(Job)
                .where(Job.job_type == "card_generation", Job.status == "running")
                .values(status="pending", started_at=None)
            )
            await db.commit()
            result = await db.execute(
                select(Job.id).where(
                    Job.job_type == "card_generation",
                    Job.status == "pending",
                )
            )
            job_ids = list(result.scalars())

        scheduled = 0
        for job_id in job_ids:
            if await self.schedule(job_id):
                scheduled += 1
        return scheduled

    async def shutdown(self) -> None:
        tasks = [task for task in self._tasks.values() if not task.done()]
        if not tasks:
            return
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        self._tasks.clear()

    async def _run(self, job_id: UUID) -> None:
        await self._card_generation_handler(job_id)


class ExternalJobRunner:
    """Production-oriented no-op scheduler.

    Pending jobs remain in the database for an external worker / queue system to
    pick up. The API stays compatible without pretending that local in-process
    execution is available.
    """

    async def schedule(self, job_id: UUID) -> bool:
        _ = job_id
        return False

    async def schedule_recoverable_jobs(self) -> int:
        return 0

    async def shutdown(self) -> None:
        return None


def build_job_runner(
    *,
    mode: str,
    card_generation_handler: JobHandler,
) -> JobScheduler:
    if mode == "external":
        return ExternalJobRunner()
    return JobRunner(card_generation_handler=card_generation_handler)
