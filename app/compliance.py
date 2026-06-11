from __future__ import annotations

from hashlib import sha256
from typing import Any

STANDARD_CONTROLS: dict[str, list[dict[str, str]]] = {
    "ISO9001": [
        {"control": "Traceable lot identity", "evidence": "material lot + chain events"},
        {"control": "Quality inspection record", "evidence": "AI/CV inspection + result hash"},
        {"control": "Nonconformance handling", "evidence": "FAIL result triggers quality hold recommendation"},
    ],
    "ISO14001": [
        {"control": "Environmental aspect tracking", "evidence": "CO2e, energy, water, waste records"},
        {"control": "Lifecycle impact monitoring", "evidence": "ESG summary and circularity score"},
    ],
    "GRI": [
        {"control": "Sustainability disclosure data", "evidence": "carbon and waste metrics"},
        {"control": "Supplier/material accountability", "evidence": "digital passport and provenance"},
    ],
    "CUSTOM": [
        {"control": "Customer-specific certification rule", "evidence": "uploaded certificate metadata and evidence hash"},
    ],
}


def normalize_evidence_hash(certificate_id: str, issuer: str, evidence_hash: str | None) -> str:
    if evidence_hash and len(evidence_hash.strip()) >= 16:
        return evidence_hash.strip()
    return sha256(f"{certificate_id}|{issuer}".encode("utf-8")).hexdigest()


def validate_certification(standard: str, certificate_id: str, issuer: str, evidence_hash: str | None) -> dict[str, Any]:
    controls = STANDARD_CONTROLS.get(standard, STANDARD_CONTROLS["CUSTOM"])
    normalized_hash = normalize_evidence_hash(certificate_id, issuer, evidence_hash)
    status = "VALIDATED" if certificate_id.strip() and issuer.strip() else "REJECTED"
    return {
        "standard": standard,
        "certificate_id": certificate_id,
        "issuer": issuer,
        "status": status,
        "evidence_hash": normalized_hash,
        "controls": controls,
    }


def compliance_report(lot_id: str, passport: dict[str, Any]) -> dict[str, Any]:
    quality_pass = any(str(q.get("result", "")).upper() == "PASS" for q in passport.get("quality", []))
    has_traceability = bool(passport.get("traceability"))
    esg = passport.get("sustainability", {})
    chain_valid = bool(passport.get("chain_validation", {}).get("valid"))
    certifications = passport.get("certifications", [])

    checks = [
        {"standard": "ISO9001", "control": "quality inspection evidence", "status": "PASS" if quality_pass else "MISSING"},
        {"standard": "ISO9001", "control": "traceable custody/provenance", "status": "PASS" if has_traceability and chain_valid else "MISSING"},
        {"standard": "ISO14001", "control": "carbon/water/waste lifecycle data", "status": "PASS" if esg.get("event_count", 0) > 0 else "MISSING"},
        {"standard": "GRI", "control": "sustainability disclosure metrics", "status": "PASS" if esg.get("event_count", 0) > 0 else "MISSING"},
        {"standard": "CERTIFICATION", "control": "validated certification metadata", "status": "PASS" if certifications else "MISSING"},
    ]
    score = round(sum(1 for c in checks if c["status"] == "PASS") / len(checks) * 100, 2)
    return {"lot_id": lot_id, "compliance_score_percent": score, "checks": checks}
