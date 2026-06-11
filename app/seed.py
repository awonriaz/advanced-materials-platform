from __future__ import annotations

from app.blockchain import add_chain_event
from app.db import get_conn, init_db, json_dumps


def seed() -> None:
    init_db()
    lot_id = "LOT-RE-0001"
    with get_conn() as conn:
        existing = conn.execute("SELECT lot_id FROM materials WHERE lot_id = ?", (lot_id,)).fetchone()
        if not existing:
            conn.execute(
                "INSERT INTO materials(lot_id, material_type, supplier, origin_country, metadata_json) VALUES (?, ?, ?, ?, ?)",
                (
                    lot_id,
                    "rare-earth",
                    "Strategic Minerals Ltd",
                    "Australia",
                    json_dumps({"grade": "NdPr oxide", "batch_weight_kg": 250, "location": "Mumbai Demo Warehouse"}),
                ),
            )
            add_chain_event(
                lot_id=lot_id,
                event_type="MATERIAL_CREATED",
                actor="seed-script",
                location="Mumbai Demo Warehouse",
                payload={"source": "seed", "purpose": "oral-exam-demo"},
            )
            add_chain_event(
                lot_id=lot_id,
                event_type="CERTIFICATION_VALIDATED",
                actor="seed-script",
                location="QC Lab",
                payload={"standard": "ISO 9001", "certificate_id": "CERT-DEMO-9001-001", "status": "VALID"},
            )
    print(f"Seed complete for {lot_id}")


if __name__ == "__main__":
    seed()
