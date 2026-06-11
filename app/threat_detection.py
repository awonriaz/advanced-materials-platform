from __future__ import annotations

from typing import Any

SEVERITY_SCORE = {"LOW": 15, "MEDIUM": 35, "HIGH": 70, "CRITICAL": 95}


def analyze_threat_signal(signal_type: str, severity: str, indicators: list[str]) -> dict[str, Any]:
    base = SEVERITY_SCORE[severity]
    indicator_boost = min(len(indicators) * 3, 15)
    score = min(base + indicator_boost, 100)

    if score >= 90:
        workflow = [
            "Open critical incident",
            "Isolate affected supplier integration/API credentials",
            "Freeze custody transfer for linked lots",
            "Notify security analyst, supply-chain manager, and compliance owner",
            "Preserve logs and begin forensic review",
        ]
    elif score >= 70:
        workflow = [
            "Open high-severity incident",
            "Require secondary approval for linked lot release",
            "Increase inspection and chain validation frequency",
            "Review supplier access and recent custody events",
        ]
    elif score >= 35:
        workflow = [
            "Create security watch item",
            "Monitor supplier and lot events",
            "Request additional evidence if signal repeats",
        ]
    else:
        workflow = ["Log for trend analysis", "No immediate containment required"]

    return {
        "threat_score": score,
        "detected": score >= 35,
        "category": signal_type,
        "recommended_workflow": workflow,
    }
