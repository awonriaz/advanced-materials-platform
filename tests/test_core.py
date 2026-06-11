from pathlib import Path

from PIL import Image, ImageDraw

from app import blockchain
from app.db import get_conn, init_db, json_dumps
from app.qc import inspect_image
from app.risk import assess_supply_risk
from app.settings import settings
from app.sustainability import lot_esg_summary


def _set_db_path(tmp_path: Path) -> None:
    object.__setattr__(settings, "db_path", str(tmp_path / "test.db"))
    init_db()


def _create_lot(lot_id: str = "TEST-LOT-1") -> None:
    with get_conn() as conn:
        conn.execute(
            "INSERT INTO materials(lot_id, material_type, supplier, origin_country, metadata_json) VALUES (?, ?, ?, ?, ?)",
            (lot_id, "rare-earth", "Test Supplier", "Australia", json_dumps({})),
        )


def _png_bytes(defective: bool = False) -> bytes:
    img = Image.new("L", (128, 128), 150)
    if defective:
        draw = ImageDraw.Draw(img)
        draw.ellipse((40, 40, 85, 85), fill=10)
        draw.line((10, 110, 118, 20), fill=5, width=4)
    from io import BytesIO
    buf = BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def test_quality_control_scores_defective_higher() -> None:
    good = inspect_image(_png_bytes(False), threshold=32.0)
    bad = inspect_image(_png_bytes(True), threshold=32.0)
    assert good["result"] == "PASS"
    assert bad["result"] == "FAIL"
    assert bad["defect_score"] > good["defect_score"]


def test_blockchain_validation(tmp_path: Path) -> None:
    _set_db_path(tmp_path)
    _create_lot()
    blockchain.add_chain_event(lot_id="TEST-LOT-1", event_type="MATERIAL_CREATED", actor="test", location="lab", payload={"a": 1})
    blockchain.add_chain_event(lot_id="TEST-LOT-1", event_type="QUALITY_CHECK", actor="test", location="lab", payload={"result": "PASS"})
    result = blockchain.validate_chain("TEST-LOT-1")
    assert result["valid"] is True
    assert result["checked_events"] == 2


def test_risk_assessment_levels() -> None:
    result = assess_supply_risk(
        material_type="rare-earth",
        origin_country="DemoCountry",
        supplier_score=40,
        region_risk="high",
        single_source=True,
        threat_intel_hits=3,
    )
    assert result["risk_score"] >= 70
    assert result["level"] == "CRITICAL"


def test_esg_summary(tmp_path: Path) -> None:
    _set_db_path(tmp_path)
    _create_lot()
    with get_conn() as conn:
        conn.execute(
            "INSERT INTO carbon_events(lot_id, stage, co2e_kg, energy_kwh, water_l, waste_kg) VALUES (?, ?, ?, ?, ?, ?)",
            ("TEST-LOT-1", "smelting", 100.0, 50.0, 20.0, 4.0),
        )
    summary = lot_esg_summary("TEST-LOT-1")
    assert summary["total_co2e_kg"] == 100.0
    assert summary["event_count"] == 1
    assert summary["esg_grade"] in {"A", "B", "C", "D"}
