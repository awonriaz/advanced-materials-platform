from __future__ import annotations

from typing import Any

CRITICAL_MATERIAL_WEIGHTS = {
    "rare-earth": 30,
    "semiconductor": 25,
    "titanium-alloy": 20,
    "lithium": 22,
    "cobalt": 22,
    "graphite": 18,
}

REGION_RISK_WEIGHTS = {
    "high": 30,
    "medium": 15,
    "low": 5,
}


def score_to_level(score: float) -> str:
    if score >= 70:
        return "CRITICAL"
    if score >= 45:
        return "HIGH"
    if score >= 25:
        return "MEDIUM"
    return "LOW"


def assess_supply_risk(
    *,
    material_type: str,
    origin_country: str,
    supplier_score: float,
    region_risk: str = "medium",
    single_source: bool = False,
    threat_intel_hits: int = 0,
) -> dict[str, Any]:
    normalized_material = material_type.strip().lower()
    normalized_region = region_risk.strip().lower()
    supplier_score = max(0.0, min(100.0, float(supplier_score)))
    material_weight = CRITICAL_MATERIAL_WEIGHTS.get(normalized_material, 10)
    region_weight = REGION_RISK_WEIGHTS.get(normalized_region, 15)
    supplier_penalty = (100.0 - supplier_score) * 0.25
    concentration_penalty = 20 if single_source else 0
    threat_penalty = min(max(threat_intel_hits, 0) * 7, 21)
    score = round(min(100.0, material_weight + region_weight + supplier_penalty + concentration_penalty + threat_penalty), 2)
    return {
        "risk_score": score,
        "level": score_to_level(score),
        "factors": {
            "material_criticality": material_weight,
            "origin_country": origin_country,
            "region_risk_weight": region_weight,
            "supplier_penalty": round(supplier_penalty, 2),
            "single_source_penalty": concentration_penalty,
            "threat_intel_penalty": threat_penalty,
        },
    }



def diversification_strategy(material_type: str, current_region_risk: str = "medium", single_source: bool = False) -> dict[str, object]:
    normalized = material_type.strip().lower()
    criticality = CRITICAL_MATERIAL_WEIGHTS.get(normalized, 10)
    actions: list[str] = []
    if criticality >= 25:
        actions.append("Maintain at least two qualified suppliers in different geopolitical regions.")
        actions.append("Keep strategic safety stock based on production criticality and lead time.")
    if current_region_risk == "high":
        actions.append("Shift a percentage of new purchase orders to low/medium-risk regions after qualification.")
        actions.append("Increase supplier audit frequency and require updated compliance evidence.")
    if single_source:
        actions.append("Start alternate supplier onboarding and dual-source certification workflow.")
    if not actions:
        actions.append("Continue quarterly supplier risk review and monitor threat-intelligence feeds.")
    return {
        "material_type": normalized,
        "criticality_weight": criticality,
        "current_region_risk": current_region_risk,
        "single_source": single_source,
        "recommended_diversification_actions": actions,
    }
