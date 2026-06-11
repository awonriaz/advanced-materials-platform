from __future__ import annotations

from typing import Any

from app.db import get_conn


def esg_grade(total_co2e_kg: float, total_waste_kg: float) -> str:
    if total_co2e_kg <= 50 and total_waste_kg <= 5:
        return "A"
    if total_co2e_kg <= 200 and total_waste_kg <= 25:
        return "B"
    if total_co2e_kg <= 500 and total_waste_kg <= 75:
        return "C"
    return "D"


def circularity_score(reused_kg: float, waste_kg: float) -> float:
    denominator = reused_kg + waste_kg
    if denominator <= 0:
        return 0.0
    return round((reused_kg / denominator) * 100.0, 2)


def lot_esg_summary(lot_id: str) -> dict[str, Any]:
    with get_conn() as conn:
        rows = conn.execute("SELECT * FROM carbon_events WHERE lot_id = ? ORDER BY id", (lot_id,)).fetchall()
    total_co2e = round(sum(float(r["co2e_kg"]) for r in rows), 4)
    total_energy = round(sum(float(r["energy_kwh"]) for r in rows), 4)
    total_water = round(sum(float(r["water_l"]) for r in rows), 4)
    total_waste = round(sum(float(r["waste_kg"]) for r in rows), 4)
    reused = round(sum(float(r["waste_kg"]) for r in rows if r["stage"].lower() in {"reuse", "recycling", "remanufacturing"}), 4)
    return {
        "lot_id": lot_id,
        "event_count": len(rows),
        "total_co2e_kg": total_co2e,
        "total_energy_kwh": total_energy,
        "total_water_l": total_water,
        "total_waste_kg": total_waste,
        "circularity_score_percent": circularity_score(reused, total_waste),
        "esg_grade": esg_grade(total_co2e, total_waste),
    }
