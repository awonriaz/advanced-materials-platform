from __future__ import annotations

import json
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

from app.settings import settings

SCHEMA = """
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

CREATE TABLE IF NOT EXISTS materials (
    lot_id TEXT PRIMARY KEY,
    material_type TEXT NOT NULL,
    supplier TEXT NOT NULL,
    origin_country TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    metadata_json TEXT NOT NULL DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS chain_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    lot_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    actor TEXT NOT NULL,
    location TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    previous_hash TEXT NOT NULL,
    event_hash TEXT NOT NULL UNIQUE,
    timestamp TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY(lot_id) REFERENCES materials(lot_id)
);

CREATE TABLE IF NOT EXISTS inspections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    lot_id TEXT NOT NULL,
    result TEXT NOT NULL,
    defect_score REAL NOT NULL,
    features_json TEXT NOT NULL,
    image_sha256 TEXT NOT NULL,
    timestamp TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY(lot_id) REFERENCES materials(lot_id)
);

CREATE TABLE IF NOT EXISTS carbon_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    lot_id TEXT NOT NULL,
    stage TEXT NOT NULL,
    co2e_kg REAL NOT NULL,
    energy_kwh REAL NOT NULL,
    water_l REAL NOT NULL,
    waste_kg REAL NOT NULL,
    timestamp TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY(lot_id) REFERENCES materials(lot_id)
);

CREATE TABLE IF NOT EXISTS risk_assessments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    lot_id TEXT,
    material_type TEXT NOT NULL,
    origin_country TEXT NOT NULL,
    supplier TEXT NOT NULL,
    risk_score REAL NOT NULL,
    level TEXT NOT NULL,
    factors_json TEXT NOT NULL,
    timestamp TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS incidents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    severity TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'OPEN',
    timestamp TEXT NOT NULL DEFAULT (datetime('now'))
);


CREATE TABLE IF NOT EXISTS process_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    lot_id TEXT NOT NULL,
    source TEXT NOT NULL,
    machine_id TEXT NOT NULL,
    line_id TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value REAL NOT NULL,
    unit TEXT NOT NULL,
    optimization_json TEXT NOT NULL,
    timestamp TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY(lot_id) REFERENCES materials(lot_id)
);

CREATE TABLE IF NOT EXISTS certifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    lot_id TEXT NOT NULL,
    standard TEXT NOT NULL,
    certificate_id TEXT NOT NULL,
    issuer TEXT NOT NULL,
    status TEXT NOT NULL,
    expires_at TEXT,
    evidence_hash TEXT,
    controls_json TEXT NOT NULL,
    timestamp TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY(lot_id) REFERENCES materials(lot_id)
);

CREATE TABLE IF NOT EXISTS threat_signals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    lot_id TEXT,
    source TEXT NOT NULL,
    signal_type TEXT NOT NULL,
    severity TEXT NOT NULL,
    description TEXT NOT NULL,
    indicators_json TEXT NOT NULL,
    action_json TEXT NOT NULL,
    timestamp TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    actor TEXT NOT NULL,
    role TEXT NOT NULL,
    action TEXT NOT NULL,
    resource TEXT NOT NULL,
    success INTEGER NOT NULL,
    detail_json TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
"""


def _dict_factory(cursor: sqlite3.Cursor, row: sqlite3.Row) -> dict[str, Any]:
    return {col[0]: row[idx] for idx, col in enumerate(cursor.description)}


@contextmanager
def get_conn() -> Iterator[sqlite3.Connection]:
    db_file = Path(settings.db_path)
    db_file.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_file), timeout=30)
    conn.row_factory = _dict_factory
    try:
        conn.execute("PRAGMA foreign_keys=ON")
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def init_db() -> None:
    with get_conn() as conn:
        conn.executescript(SCHEMA)


def json_dumps(value: dict[str, Any] | list[Any]) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def json_loads(value: str | None) -> Any:
    if not value:
        return {}
    return json.loads(value)


def audit(
    actor: str,
    role: str,
    action: str,
    resource: str,
    success: bool,
    detail: dict[str, Any]
) -> None:
    with get_conn() as conn:
        conn.execute(
            "INSERT INTO audit_logs(actor, role, action, resource, success, detail_json) VALUES (?, ?, ?, ?, ?, ?)",
            (actor, role, action, resource, 1 if success else 0, json_dumps(detail)),
        )
