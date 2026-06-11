from __future__ import annotations

import hashlib
from typing import Any

from app.db import get_conn, json_dumps, json_loads

GENESIS_HASH = "0" * 64


def compute_event_hash(event: dict[str, Any]) -> str:
    canonical = json_dumps(event).encode("utf-8")
    return hashlib.sha256(canonical).hexdigest()


def latest_hash(lot_id: str) -> str:
    with get_conn() as conn:
        row = conn.execute(
            "SELECT event_hash FROM chain_events WHERE lot_id = ? ORDER BY id DESC LIMIT 1",
            (lot_id,),
        ).fetchone()
    return row["event_hash"] if row else GENESIS_HASH


def add_chain_event(
    *,
    lot_id: str,
    event_type: str,
    actor: str,
    location: str,
    payload: dict[str, Any],
) -> dict[str, Any]:
    previous_hash = latest_hash(lot_id)
    event_to_hash = {
        "lot_id": lot_id,
        "event_type": event_type,
        "actor": actor,
        "location": location,
        "payload": payload,
        "previous_hash": previous_hash,
    }
    event_hash = compute_event_hash(event_to_hash)
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO chain_events(lot_id, event_type, actor, location, payload_json, previous_hash, event_hash)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (lot_id, event_type, actor, location, json_dumps(payload), previous_hash, event_hash),
        )
    return {**event_to_hash, "event_hash": event_hash}


def validate_chain(lot_id: str | None = None) -> dict[str, Any]:
    params: tuple[Any, ...] = ()
    query = "SELECT * FROM chain_events"
    if lot_id:
        query += " WHERE lot_id = ?"
        params = (lot_id,)
    query += " ORDER BY lot_id, id ASC"

    with get_conn() as conn:
        rows = conn.execute(query, params).fetchall()

    previous_by_lot: dict[str, str] = {}
    errors: list[dict[str, Any]] = []
    for row in rows:
        expected_previous = previous_by_lot.get(row["lot_id"], GENESIS_HASH)
        if row["previous_hash"] != expected_previous:
            errors.append({"event_id": row["id"], "error": "previous_hash_mismatch"})
        expected_hash = compute_event_hash(
            {
                "lot_id": row["lot_id"],
                "event_type": row["event_type"],
                "actor": row["actor"],
                "location": row["location"],
                "payload": json_loads(row["payload_json"]),
                "previous_hash": row["previous_hash"],
            }
        )
        if row["event_hash"] != expected_hash:
            errors.append({"event_id": row["id"], "error": "event_hash_mismatch"})
        previous_by_lot[row["lot_id"]] = row["event_hash"]

    return {"valid": len(errors) == 0, "checked_events": len(rows), "errors": errors}
