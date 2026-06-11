from __future__ import annotations

import json
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

from app.settings import settings


def _request(method: str, path: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
    if not settings.elasticsearch_url:
        return {"enabled": False, "error": "ELASTICSEARCH_URL is not configured"}

    base = settings.elasticsearch_url.rstrip("/")
    url = f"{base}/{path.lstrip('/')}"
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=body,
        method=method,
        headers={"Content-Type": "application/json", "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=settings.elasticsearch_timeout_seconds) as response:
            raw = response.read().decode("utf-8")
            return json.loads(raw) if raw else {"ok": True}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        return {"enabled": True, "ok": False, "status": exc.code, "error": detail}
    except Exception as exc:  # Elasticsearch is optional in small demo mode.
        return {"enabled": True, "ok": False, "error": str(exc)}


def ensure_index() -> dict[str, Any]:
    mapping = {
        "mappings": {
            "properties": {
                "lot_id": {"type": "keyword"},
                "material_type": {"type": "keyword"},
                "supplier": {"type": "keyword"},
                "origin_country": {"type": "keyword"},
                "quality_result": {"type": "keyword"},
                "risk_level": {"type": "keyword"},
                "esg_grade": {"type": "keyword"},
            "predictive_quality": {"type": "keyword"},
            "compliance_score": {"type": "float"},
                "combined_text": {"type": "text"},
                "passport": {"type": "object", "enabled": True},
            }
        }
    }
    return _request("PUT", settings.search_index, mapping)


def passport_to_search_doc(passport: dict[str, Any]) -> dict[str, Any]:
    material = passport.get("material", {})
    quality = passport.get("quality", [])
    risk = passport.get("risk", [])
    sustainability = passport.get("sustainability", {})

    quality_result = quality[-1]["result"] if quality else "NOT_INSPECTED"
    risk_level = risk[0]["level"] if risk else "UNKNOWN"
    esg_grade = sustainability.get("esg_grade", "UNKNOWN")
    combined_text = " ".join(
        str(x)
        for x in [
            passport.get("lot_id"),
            material.get("material_type"),
            material.get("supplier"),
            material.get("origin_country"),
            quality_result,
            risk_level,
            esg_grade,
        ]
        if x is not None
    )

    return {
        "lot_id": passport.get("lot_id"),
        "material_type": material.get("material_type"),
        "supplier": material.get("supplier"),
        "origin_country": material.get("origin_country"),
        "quality_result": quality_result,
        "risk_level": risk_level,
        "esg_grade": esg_grade,
        "combined_text": combined_text,
        "passport": passport,
    }


def index_passport(passport: dict[str, Any]) -> dict[str, Any]:
    ensure = ensure_index()
    doc = passport_to_search_doc(passport)
    lot_id = urllib.parse.quote(str(passport["lot_id"]), safe="")
    response = _request("PUT", f"{settings.search_index}/_doc/{lot_id}", doc)
    return {"ensure_index": ensure, "index_response": response, "document": doc}


def search_passports(query: str, size: int = 10) -> dict[str, Any]:
    safe_size = max(1, min(size, 50))
    payload = {
        "size": safe_size,
        "query": {
            "multi_match": {
                "query": query,
                "fields": ["combined_text^3", "material_type^2", "supplier", "origin_country", "risk_level", "esg_grade"],
            }
        },
    }
    return _request("GET", f"{settings.search_index}/_search", payload)
