"""
Scripted Phase 4 sync validation against the local Postgres-backed app.

This uses the FastAPI app in-process through ASGITransport, so it does not need
an external uvicorn server. It does require the local Postgres stack to be up.
"""

from __future__ import annotations

import asyncio
import io
import json
import os
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import uuid4

import httpx

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

# Ensure the app can create tables in a fresh local database.
os.environ.setdefault("AUTO_CREATE_TABLES", "true")
os.environ["APP_DEBUG"] = "false"

from app.database import Base, engine  # noqa: E402
from app.main import app  # noqa: E402


@dataclass
class ValidationResult:
    guest_auth_ok: bool
    csv_import_ok: bool
    offline_push_ok: bool
    duplicate_skip_ok: bool
    pull_delta_ok: bool
    review_history_count: int
    imported_card_count: int
    processed_event_count: int
    duplicate_skipped_count: int
    pulled_card_count: int
    pulled_memory_state_count: int
    server_timestamp: str
    notes: list[str]


async def _create_tables() -> None:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def _authorized_headers(
    client: httpx.AsyncClient,
    device_id: str,
) -> dict[str, str]:
    response = await client.post(
        "/api/v1/auth/guest",
        json={"device_id": device_id, "learning_goal": "exam"},
    )
    response.raise_for_status()
    payload = response.json()
    token = payload["access_token"]
    return {"Authorization": f"Bearer {token}"}


async def _import_csv_cards(
    client: httpx.AsyncClient,
    headers: dict[str, str],
) -> tuple[list[dict], dict]:
    csv_content = io.BytesIO(
        (
            "Question,Answer\n"
            "What is ATP?,Cell energy currency.\n"
            "What is osmosis?,Passive water movement.\n"
            "What is mitosis?,Cell division for growth.\n"
            "What is diffusion?,Movement down a concentration gradient.\n"
            "What is a mitochondrion?,An organelle that helps produce ATP.\n"
        ).encode("utf-8")
    )
    response = await client.post(
        "/api/v1/sources/csv/import",
        headers=headers,
        data={"question_column": "0", "answer_column": "1"},
        files={"file": ("phase4_sync_validation.csv", csv_content, "text/csv")},
    )
    response.raise_for_status()
    import_payload = response.json()

    cards_response = await client.get("/api/v1/cards", headers=headers, params={"limit": 10})
    cards_response.raise_for_status()
    return cards_response.json(), import_payload


def _build_review_events(cards: list[dict]) -> list[dict]:
    base_time = datetime.now(timezone.utc) - timedelta(minutes=5)
    ratings = ["good", "again", "good", "easy", "hard"]
    response_times = [1800, 4200, 2100, 1600, 3500]
    events: list[dict] = []
    for index, card in enumerate(cards[:5]):
        events.append(
            {
                "client_event_id": f"sync-validation-{index + 1}-{uuid4().hex[:8]}",
                "event_type": "review",
                "event_payload": {
                    "card_id": card["id"],
                    "rating": ratings[index],
                    "response_time_ms": response_times[index],
                },
                "client_timestamp": (base_time + timedelta(seconds=index)).isoformat(),
            }
        )
    return events


async def _push_events(
    client: httpx.AsyncClient,
    headers: dict[str, str],
    device_id: str,
    events: list[dict],
) -> dict:
    response = await client.post(
        "/api/v1/sync/push",
        headers=headers,
        json={"device_id": device_id, "events": events},
    )
    response.raise_for_status()
    return response.json()


async def _review_history_count(
    client: httpx.AsyncClient,
    headers: dict[str, str],
) -> int:
    response = await client.get("/api/v1/reviews/history", headers=headers, params={"limit": 20})
    response.raise_for_status()
    return len(response.json())


async def _make_remote_changes(
    client: httpx.AsyncClient,
    headers: dict[str, str],
    cards: list[dict],
) -> None:
    patch_response = await client.patch(
        f"/api/v1/cards/{cards[0]['id']}",
        headers=headers,
        json={"answer": "Cell energy currency updated on server.", "difficulty": 4},
    )
    patch_response.raise_for_status()

    review_response = await client.post(
        "/api/v1/reviews",
        headers=headers,
        json={
            "card_id": cards[1]["id"],
            "rating": "good",
            "response_time_ms": 1900,
            "client_id": f"server-direct-{uuid4().hex[:8]}",
        },
    )
    review_response.raise_for_status()


async def _pull_changes(
    client: httpx.AsyncClient,
    headers: dict[str, str],
    device_id: str,
    since_timestamp: str,
) -> dict:
    response = await client.get(
        "/api/v1/sync/pull",
        headers=headers,
        params={"device_id": device_id, "since": since_timestamp},
    )
    response.raise_for_status()
    return response.json()


async def run_validation() -> ValidationResult:
    await _create_tables()

    device_id = f"phase4-device-{uuid4().hex}"
    transport = httpx.ASGITransport(app=app)
    notes: list[str] = []

    async with httpx.AsyncClient(
        transport=transport,
        base_url="http://plowth.local",
        timeout=30.0,
    ) as client:
        headers = await _authorized_headers(client, device_id=device_id)
        cards, import_payload = await _import_csv_cards(client, headers=headers)
        events = _build_review_events(cards)

        push_payload = await _push_events(
            client,
            headers=headers,
            device_id=device_id,
            events=events,
        )
        history_count = await _review_history_count(client, headers=headers)

        duplicate_payload = await _push_events(
            client,
            headers=headers,
            device_id=device_id,
            events=[events[0]],
        )

        server_timestamp = push_payload["server_timestamp"]
        await _make_remote_changes(client, headers=headers, cards=cards)
        pull_payload = await _pull_changes(
            client,
            headers=headers,
            device_id=device_id,
            since_timestamp=server_timestamp,
        )

    processed_event_ids = push_payload.get("processed_event_ids", [])
    skipped_event_ids = duplicate_payload.get("skipped_event_ids", [])
    pulled_cards = pull_payload.get("changes", {}).get("cards", [])
    pulled_memory_states = pull_payload.get("changes", {}).get("memory_states", [])

    if history_count < 5:
        notes.append("Expected at least 5 review history rows after sync push.")
    if len(processed_event_ids) != 5:
        notes.append("Expected 5 processed sync events in the first push.")
    if len(skipped_event_ids) != 1:
        notes.append("Expected one skipped duplicate event in the second push.")
    if not pulled_cards:
        notes.append("Expected at least one changed card in sync pull.")
    if not pulled_memory_states:
        notes.append("Expected at least one changed memory state in sync pull.")

    return ValidationResult(
        guest_auth_ok=True,
        csv_import_ok=import_payload.get("card_count", 0) >= 5,
        offline_push_ok=len(processed_event_ids) == 5 and not push_payload.get("errors"),
        duplicate_skip_ok=len(skipped_event_ids) == 1,
        pull_delta_ok=bool(pulled_cards) and bool(pulled_memory_states),
        review_history_count=history_count,
        imported_card_count=import_payload.get("card_count", 0),
        processed_event_count=len(processed_event_ids),
        duplicate_skipped_count=len(skipped_event_ids),
        pulled_card_count=len(pulled_cards),
        pulled_memory_state_count=len(pulled_memory_states),
        server_timestamp=server_timestamp,
        notes=notes,
    )


async def _main() -> ValidationResult:
    try:
        return await run_validation()
    finally:
        await engine.dispose()


def main() -> None:
    result = asyncio.run(_main())
    print(json.dumps(asdict(result), indent=2, sort_keys=True))
    if result.notes:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
