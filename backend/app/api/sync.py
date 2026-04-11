"""
Sync API: push local events and pull server-authoritative changes.
"""

from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import User
from app.schemas import SyncPullChanges, SyncPullResponse, SyncPushRequest, SyncPushResponse
from app.services.sync_service import list_changed_cards, list_changed_memory_states, process_sync_push, utcnow

router = APIRouter(prefix="/sync", tags=["Sync"])


@router.post("/push", response_model=SyncPushResponse)
async def push_sync_events(
    body: SyncPushRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await process_sync_push(
        db=db,
        user=current_user,
        device_id=body.device_id,
        events=body.events,
    )
    return SyncPushResponse(
        processed=len(result.processed_event_ids),
        skipped=len(result.skipped_event_ids),
        errors=result.errors,
        processed_event_ids=result.processed_event_ids,
        skipped_event_ids=result.skipped_event_ids,
        updated_cards=result.updated_cards,
        updated_memory_states=result.updated_memory_states,
        preferences=result.preferences,
        server_timestamp=utcnow(),
    )


@router.get("/pull", response_model=SyncPullResponse)
async def pull_sync_changes(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    since: datetime | None = Query(None),
    device_id: str | None = Query(None),
):
    del device_id
    server_timestamp = utcnow()
    cards = await list_changed_cards(
        db=db,
        user_id=current_user.id,
        since=since,
    )
    memory_states = await list_changed_memory_states(
        db=db,
        user_id=current_user.id,
        since=since,
    )
    preferences = (
        current_user.preferences
        if since is None or current_user.updated_at > since
        else None
    )
    return SyncPullResponse(
        server_timestamp=server_timestamp,
        changes=SyncPullChanges(
            cards=cards,
            memory_states=memory_states,
            preferences=preferences,
        ),
    )
