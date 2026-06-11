from __future__ import annotations

from typing import Any


def process_optimization(metric_name: str, metric_value: float, unit: str) -> dict[str, Any]:
    """Return deterministic real-time MES/IIoT optimization advice.

    This is intentionally simple and explainable for the oral exam. In production,
    this would be replaced by streaming anomaly detection and closed-loop MES rules.
    """
    name = metric_name.strip().lower()
    level = "NORMAL"
    action = "Continue production and monitor trend."
    impact = "No immediate quality risk detected."

    if name in {"temperature_c", "furnace_temperature_c", "kiln_temperature_c"}:
        if metric_value >= 950:
            level = "CRITICAL"
            action = "Pause batch, notify QA, inspect furnace calibration, and quarantine affected material lot."
            impact = "High temperature can change microstructure and increase defect probability."
        elif metric_value >= 850:
            level = "WARNING"
            action = "Reduce furnace setpoint by 3-5%, increase inspection sampling, and verify sensor calibration."
            impact = "Elevated temperature can increase surface oxidation risk."
    elif name in {"vibration_mm_s", "spindle_vibration_mm_s"}:
        if metric_value >= 8:
            level = "CRITICAL"
            action = "Stop machine, check bearings/tooling, and route lot for additional dimensional inspection."
            impact = "High vibration can cause scratches, cracks, and dimensional instability."
        elif metric_value >= 4:
            level = "WARNING"
            action = "Schedule maintenance window and increase visual inspection frequency."
            impact = "Rising vibration trend may indicate tool wear."
    elif name in {"humidity_percent", "humidity_pct"}:
        if metric_value >= 70:
            level = "WARNING"
            action = "Activate dehumidification and protect moisture-sensitive material packaging."
            impact = "Humidity can affect corrosion-sensitive or semiconductor-grade materials."
    elif name in {"pressure_bar", "chamber_pressure_bar"}:
        if metric_value <= 0 or metric_value > 12:
            level = "CRITICAL"
            action = "Stop process, verify pressure vessel state, and start safety inspection workflow."
            impact = "Out-of-range pressure can affect process repeatability and safety."

    return {"level": level, "recommended_action": action, "quality_impact": impact, "metric": {"name": metric_name, "value": metric_value, "unit": unit}}


def predictive_quality_summary(inspections: list[dict[str, Any]], process_events: list[dict[str, Any]]) -> dict[str, Any]:
    total = len(inspections)
    failed = sum(1 for i in inspections if str(i.get("result", "")).upper() == "FAIL")
    avg_score = round(sum(float(i.get("defect_score", 0)) for i in inspections) / total, 2) if total else 0.0
    warning_events = [e for e in process_events if e.get("optimization", {}).get("level") in {"WARNING", "CRITICAL"}]
    defect_rate = round((failed / total) * 100, 2) if total else 0.0

    if defect_rate >= 30 or len(warning_events) >= 3:
        prediction = "HIGH_RISK_OF_QUALITY_DRIFT"
        recommendation = "Increase inspection frequency, quarantine recent lots, and run maintenance/root-cause analysis."
    elif defect_rate >= 10 or warning_events:
        prediction = "MODERATE_RISK_OF_QUALITY_DRIFT"
        recommendation = "Monitor process parameters, validate sensor calibration, and increase sampling temporarily."
    else:
        prediction = "STABLE_PROCESS"
        recommendation = "Continue normal monitoring."

    return {
        "inspection_count": total,
        "failed_inspections": failed,
        "defect_rate_percent": defect_rate,
        "average_defect_score": avg_score,
        "process_warning_count": len(warning_events),
        "prediction": prediction,
        "recommended_action": recommendation,
    }
