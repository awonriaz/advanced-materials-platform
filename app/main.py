from __future__ import annotations

from typing import Any

from fastapi import Depends, FastAPI, File, HTTPException, UploadFile, status
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from starlette.responses import Response

from app.auth import require_api_key, require_role
from app.blockchain import add_chain_event, validate_chain
from app.db import audit, get_conn, init_db, json_dumps, json_loads
from app.qc import inspect_image
from app.risk import assess_supply_risk, diversification_strategy
from app.schemas import CarbonEventCreate, CertificationValidationRequest, IncidentCreate, MaterialCreate, ProcessTelemetryCreate, RiskAssessRequest, ThreatSignalCreate, TraceEventCreate
from app.search import index_passport, search_passports
from app.compliance import compliance_report, validate_certification
from app.iot import predictive_quality_summary, process_optimization
from app.threat_detection import analyze_threat_signal
from app.settings import settings
from app.sustainability import lot_esg_summary

REQUEST_COUNTER = Counter("amscp_requests_total", "Total API requests", ["path"])
QC_SCORE = Histogram("amscp_qc_defect_score", "Observed quality defect scores")

app = FastAPI(
    title=settings.app_name,
    description="Exam-ready demo API for AI quality control, hash-chain traceability, ESG analytics, and supply-chain risk.",
    version="1.0.0",
)


@app.on_event("startup")
def startup() -> None:
    init_db()


@app.middleware("http")
async def metrics_middleware(request, call_next):  # type: ignore[no-untyped-def]
    REQUEST_COUNTER.labels(path=request.url.path).inc()
    return await call_next(request)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "environment": settings.app_env}


def _build_passport(lot_id: str) -> dict[str, Any]:
    with get_conn() as conn:
        material = conn.execute("SELECT * FROM materials WHERE lot_id = ?", (lot_id,)).fetchone()
        if not material:
            raise HTTPException(status_code=404, detail="Lot not found")
        chain_events = conn.execute("SELECT * FROM chain_events WHERE lot_id = ? ORDER BY id", (lot_id,)).fetchall()
        inspections = conn.execute("SELECT * FROM inspections WHERE lot_id = ? ORDER BY id", (lot_id,)).fetchall()
        risks = conn.execute("SELECT * FROM risk_assessments WHERE lot_id = ? ORDER BY id DESC", (lot_id,)).fetchall()
        process_events = conn.execute("SELECT * FROM process_events WHERE lot_id = ? ORDER BY id DESC", (lot_id,)).fetchall()
        certifications = conn.execute("SELECT * FROM certifications WHERE lot_id = ? ORDER BY id DESC", (lot_id,)).fetchall()
        threat_signals = conn.execute("SELECT * FROM threat_signals WHERE lot_id = ? ORDER BY id DESC", (lot_id,)).fetchall()
    passport = {
        "lot_id": lot_id,
        "material": {**material, "metadata": json_loads(material["metadata_json"])},
        "traceability": [{**e, "payload": json_loads(e["payload_json"])} for e in chain_events],
        "quality": [{**i, "features": json_loads(i["features_json"])} for i in inspections],
        "risk": [{**r, "factors": json_loads(r["factors_json"])} for r in risks],
        "process_telemetry": [{**e, "optimization": json_loads(e["optimization_json"])} for e in process_events],
        "certifications": [{**c, "controls": json_loads(c["controls_json"])} for c in certifications],
        "threat_signals": [{**t, "indicators": json_loads(t["indicators_json"]), "action": json_loads(t["action_json"])} for t in threat_signals],
        "sustainability": lot_esg_summary(lot_id),
        "chain_validation": validate_chain(lot_id),
    }
    passport["predictive_quality"] = predictive_quality_summary(passport["quality"], passport["process_telemetry"])
    passport["compliance"] = compliance_report(lot_id, passport)
    return passport


@app.get("/metrics")
def metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.post("/api/v1/materials", status_code=status.HTTP_201_CREATED)
def create_material(payload: MaterialCreate, identity: dict[str, str] = Depends(require_api_key)) -> dict[str, Any]:
    require_role(identity, {"admin", "supply-chain-manager", "qa-engineer"})
    try:
        with get_conn() as conn:
            conn.execute(
                "INSERT INTO materials(lot_id, material_type, supplier, origin_country, metadata_json) VALUES (?, ?, ?, ?, ?)",
                (payload.lot_id, payload.material_type, payload.supplier, payload.origin_country, json_dumps(payload.metadata)),
            )
        chain_event = add_chain_event(
            lot_id=payload.lot_id,
            event_type="MATERIAL_CREATED",
            actor=identity["actor"],
            location=payload.metadata.get("location", "Mumbai"),
            payload=payload.model_dump(),
        )
        audit(identity["actor"], "create_material", payload.lot_id, True, {"event_hash": chain_event["event_hash"]})
        return {"material": payload.model_dump(), "trace_event": chain_event}
    except Exception as exc:
        audit(identity["actor"], "create_material", payload.lot_id, False, {"error": str(exc)})
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.get("/api/v1/materials/{lot_id}/passport")
def get_material_passport(lot_id: str, identity: dict[str, str] = Depends(require_api_key)) -> dict[str, Any]:
    passport = _build_passport(lot_id)
    audit(identity["actor"], "read_passport", lot_id, True, {})
    return passport


@app.post("/api/v1/search/sync/{lot_id}")
def sync_passport_to_elasticsearch(lot_id: str, identity: dict[str, str] = Depends(require_api_key)) -> dict[str, Any]:
    require_role(identity, {"admin", "supply-chain-manager", "security-analyst"})
    passport = _build_passport(lot_id)
    result = index_passport(passport)
    ok = bool(result.get("index_response", {}).get("result") in {"created", "updated"} or result.get("index_response", {}).get("_id"))
    audit(identity["actor"], "sync_passport_to_elasticsearch", lot_id, ok, {"elasticsearch": result.get("index_response")})
    return result


@app.get("/api/v1/search/materials")
def search_materials(q: str, size: int = 10, identity: dict[str, str] = Depends(require_api_key)) -> dict[str, Any]:
    require_role(identity, {"admin", "supply-chain-manager", "qa-engineer", "sustainability-analyst", "risk-analyst", "security-analyst"})
    result = search_passports(q, size)
    audit(identity["actor"], "search_materials", q, bool(result.get("hits") or result.get("enabled") is False), {"query": q})
    return result


@app.post("/api/v1/trace/events", status_code=status.HTTP_201_CREATED)
def create_trace_event(payload: TraceEventCreate, identity: dict[str, str] = Depends(require_api_key)) -> dict[str, Any]:
    with get_conn() as conn:
        exists = conn.execute("SELECT lot_id FROM materials WHERE lot_id = ?", (payload.lot_id,)).fetchone()
    if not exists:
        raise HTTPException(status_code=404, detail="Lot not found")
    event = add_chain_event(
        lot_id=payload.lot_id,
        event_type=payload.event_type,
        actor=payload.actor or identity["actor"],
        location=payload.location,
        payload=payload.payload,
    )
    audit(identity["actor"], "create_trace_event", payload.lot_id, True, {"event_hash": event["event_hash"]})
    return event


@app.post("/api/v1/quality/inspect")
async def inspect_quality(lot_id: str, file: UploadFile = File(...), identity: dict[str, str] = Depends(require_api_key)) -> dict[str, Any]:
    require_role(identity, {"admin", "qa-engineer"})
    with get_conn() as conn:
        exists = conn.execute("SELECT lot_id FROM materials WHERE lot_id = ?", (lot_id,)).fetchone()
    if not exists:
        raise HTTPException(status_code=404, detail="Lot not found")

    image_bytes = await file.read()
    max_bytes = settings.max_upload_mb * 1024 * 1024
    if len(image_bytes) > max_bytes:
        raise HTTPException(status_code=413, detail=f"Upload exceeds {settings.max_upload_mb} MB")

    try:
        result = inspect_image(image_bytes, settings.qc_fail_threshold)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    QC_SCORE.observe(result["defect_score"])
    with get_conn() as conn:
        conn.execute(
            "INSERT INTO inspections(lot_id, result, defect_score, features_json, image_sha256) VALUES (?, ?, ?, ?, ?)",
            (lot_id, result["result"], result["defect_score"], json_dumps(result["features"]), result["image_sha256"]),
        )
    chain_event = add_chain_event(
        lot_id=lot_id,
        event_type="QUALITY_CHECK",
        actor=identity["actor"],
        location="QC Lab",
        payload={"filename": file.filename, **result},
    )
    audit(identity["actor"], "inspect_quality", lot_id, True, {"result": result["result"], "event_hash": chain_event["event_hash"]})
    return {"lot_id": lot_id, "inspection": result, "trace_event": chain_event}




@app.post("/api/v1/quality/tensorflow/inspect")
async def inspect_quality_with_tensorflow(lot_id: str, file: UploadFile = File(...), identity: dict[str, str] = Depends(require_api_key)) -> dict[str, Any]:
    """Proxy endpoint for the optional TensorFlow microservice.

    This lets the examiner see TensorFlow as a separate AI service without making
    the lightweight core API depend on the large TensorFlow runtime.
    """
    require_role(identity, {"admin", "qa-engineer"})
    if not settings.tensorflow_qc_url:
        raise HTTPException(status_code=503, detail="TENSORFLOW_QC_URL is not configured. Start docker compose --profile tensorflow up -d.")
    image_bytes = await file.read()
    import urllib.request
    import uuid

    boundary = f"----amscp{uuid.uuid4().hex}"
    filename = file.filename or "material.png"
    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'
        f"Content-Type: {file.content_type or 'application/octet-stream'}\r\n\r\n"
    ).encode("utf-8") + image_bytes + f"\r\n--{boundary}--\r\n".encode("utf-8")
    request = urllib.request.Request(
        f"{settings.tensorflow_qc_url.rstrip('/')}/inspect",
        data=body,
        method="POST",
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            import json
            tf_result = json.loads(response.read().decode("utf-8"))
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"TensorFlow service unavailable: {exc}") from exc

    with get_conn() as conn:
        exists = conn.execute("SELECT lot_id FROM materials WHERE lot_id = ?", (lot_id,)).fetchone()
    if not exists:
        raise HTTPException(status_code=404, detail="Lot not found")

    with get_conn() as conn:
        conn.execute(
            "INSERT INTO inspections(lot_id, result, defect_score, features_json, image_sha256) VALUES (?, ?, ?, ?, ?)",
            (lot_id, tf_result["result"], tf_result["defect_probability"] * 100, json_dumps(tf_result), tf_result["image_sha256"]),
        )
    chain_event = add_chain_event(
        lot_id=lot_id,
        event_type="TENSORFLOW_QUALITY_CHECK",
        actor=identity["actor"],
        location="TensorFlow QC Service",
        payload=tf_result,
    )
    audit(identity["actor"], "tensorflow_inspect_quality", lot_id, True, {"result": tf_result["result"], "event_hash": chain_event["event_hash"]})
    return {"lot_id": lot_id, "tensorflow_inspection": tf_result, "trace_event": chain_event}


@app.post("/api/v1/esg/carbon", status_code=status.HTTP_201_CREATED)
def add_carbon_event(payload: CarbonEventCreate, identity: dict[str, str] = Depends(require_api_key)) -> dict[str, Any]:
    require_role(identity, {"admin", "sustainability-analyst", "supply-chain-manager"})
    with get_conn() as conn:
        exists = conn.execute("SELECT lot_id FROM materials WHERE lot_id = ?", (payload.lot_id,)).fetchone()
        if not exists:
            raise HTTPException(status_code=404, detail="Lot not found")
        conn.execute(
            "INSERT INTO carbon_events(lot_id, stage, co2e_kg, energy_kwh, water_l, waste_kg) VALUES (?, ?, ?, ?, ?, ?)",
            (payload.lot_id, payload.stage, payload.co2e_kg, payload.energy_kwh, payload.water_l, payload.waste_kg),
        )
    event = add_chain_event(
        lot_id=payload.lot_id,
        event_type="ESG_EVENT",
        actor=identity["actor"],
        location="ESG Analytics",
        payload=payload.model_dump(),
    )
    summary = lot_esg_summary(payload.lot_id)
    audit(identity["actor"], "add_carbon_event", payload.lot_id, True, {"event_hash": event["event_hash"]})
    return {"summary": summary, "trace_event": event}


@app.get("/api/v1/esg/summary/{lot_id}")
def esg_summary(lot_id: str, identity: dict[str, str] = Depends(require_api_key)) -> dict[str, Any]:
    audit(identity["actor"], "read_esg_summary", lot_id, True, {})
    return lot_esg_summary(lot_id)


@app.post("/api/v1/risk/assess", status_code=status.HTTP_201_CREATED)
def risk_assessment(payload: RiskAssessRequest, identity: dict[str, str] = Depends(require_api_key)) -> dict[str, Any]:
    require_role(identity, {"admin", "risk-analyst", "supply-chain-manager"})
    result = assess_supply_risk(
        material_type=payload.material_type,
        origin_country=payload.origin_country,
        supplier_score=payload.supplier_score,
        region_risk=payload.region_risk,
        single_source=payload.single_source,
        threat_intel_hits=payload.threat_intel_hits,
    )
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO risk_assessments(lot_id, material_type, origin_country, supplier, risk_score, level, factors_json)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (payload.lot_id, payload.material_type, payload.origin_country, payload.supplier, result["risk_score"], result["level"], json_dumps(result["factors"])),
        )
    trace_event = None
    if payload.lot_id:
        with get_conn() as conn:
            exists = conn.execute("SELECT lot_id FROM materials WHERE lot_id = ?", (payload.lot_id,)).fetchone()
        if exists:
            trace_event = add_chain_event(
                lot_id=payload.lot_id,
                event_type="RISK_ASSESSMENT",
                actor=identity["actor"],
                location="Risk Engine",
                payload={**payload.model_dump(), **result},
            )
    audit(identity["actor"], "risk_assessment", payload.lot_id or "unlinked", True, result)
    return {"assessment": {**payload.model_dump(), **result}, "trace_event": trace_event}


@app.post("/api/v1/iot/process-events", status_code=status.HTTP_201_CREATED)
def ingest_process_event(payload: ProcessTelemetryCreate, identity: dict[str, str] = Depends(require_api_key)) -> dict[str, Any]:
    require_role(identity, {"admin", "qa-engineer", "supply-chain-manager"})
    with get_conn() as conn:
        exists = conn.execute("SELECT lot_id FROM materials WHERE lot_id = ?", (payload.lot_id,)).fetchone()
        if not exists:
            raise HTTPException(status_code=404, detail="Lot not found")
    optimization = process_optimization(payload.metric_name, payload.metric_value, payload.unit)
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO process_events(lot_id, source, machine_id, line_id, metric_name, metric_value, unit, optimization_json)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (payload.lot_id, payload.source, payload.machine_id, payload.line_id, payload.metric_name, payload.metric_value, payload.unit, json_dumps(optimization)),
        )
    event_type = "OPCUA_TELEMETRY" if payload.source == "OPC-UA" else "MQTT_TELEMETRY" if payload.source == "MQTT" else "MES_PROCESS_EVENT"
    trace_event = add_chain_event(
        lot_id=payload.lot_id,
        event_type=event_type,
        actor=identity["actor"],
        location=f"{payload.source}:{payload.line_id}:{payload.machine_id}",
        payload={**payload.model_dump(), "optimization": optimization},
    )
    audit(identity["actor"], "ingest_process_event", payload.lot_id, True, {"event_hash": trace_event["event_hash"], "optimization": optimization})
    return {"process_event": payload.model_dump(), "optimization": optimization, "trace_event": trace_event}


@app.get("/api/v1/quality/predictive/{lot_id}")
def predictive_quality(lot_id: str, identity: dict[str, str] = Depends(require_api_key)) -> dict[str, Any]:
    require_role(identity, {"admin", "qa-engineer", "supply-chain-manager"})
    with get_conn() as conn:
        inspections = [{**i, "features": json_loads(i["features_json"])} for i in conn.execute("SELECT * FROM inspections WHERE lot_id = ? ORDER BY id DESC", (lot_id,)).fetchall()]
        process_events = [{**e, "optimization": json_loads(e["optimization_json"])} for e in conn.execute("SELECT * FROM process_events WHERE lot_id = ? ORDER BY id DESC", (lot_id,)).fetchall()]
    result = predictive_quality_summary(inspections, process_events)
    audit(identity["actor"], "predictive_quality", lot_id, True, result)
    return result


@app.post("/api/v1/compliance/certifications/validate", status_code=status.HTTP_201_CREATED)
def validate_material_certification(payload: CertificationValidationRequest, identity: dict[str, str] = Depends(require_api_key)) -> dict[str, Any]:
    require_role(identity, {"admin", "supply-chain-manager", "qa-engineer", "sustainability-analyst"})
    with get_conn() as conn:
        exists = conn.execute("SELECT lot_id FROM materials WHERE lot_id = ?", (payload.lot_id,)).fetchone()
        if not exists:
            raise HTTPException(status_code=404, detail="Lot not found")
    validation = validate_certification(payload.standard, payload.certificate_id, payload.issuer, payload.evidence_hash)
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO certifications(lot_id, standard, certificate_id, issuer, status, expires_at, evidence_hash, controls_json)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (payload.lot_id, payload.standard, payload.certificate_id, payload.issuer, validation["status"], payload.expires_at, validation["evidence_hash"], json_dumps(validation["controls"])),
        )
    trace_event = add_chain_event(
        lot_id=payload.lot_id,
        event_type="CERTIFICATION_VALIDATED",
        actor=identity["actor"],
        location="Compliance Engine",
        payload={**payload.model_dump(), **validation},
    )
    audit(identity["actor"], "validate_certification", payload.lot_id, validation["status"] == "VALIDATED", {"event_hash": trace_event["event_hash"], "standard": payload.standard})
    return {"validation": validation, "trace_event": trace_event}


@app.get("/api/v1/compliance/report/{lot_id}")
def get_compliance_report(lot_id: str, identity: dict[str, str] = Depends(require_api_key)) -> dict[str, Any]:
    require_role(identity, {"admin", "supply-chain-manager", "qa-engineer", "sustainability-analyst", "security-analyst"})
    passport = _build_passport(lot_id)
    report = compliance_report(lot_id, passport)
    audit(identity["actor"], "read_compliance_report", lot_id, True, {"score": report["compliance_score_percent"]})
    return report


@app.post("/api/v1/security/threat-signals", status_code=status.HTTP_201_CREATED)
def ingest_threat_signal(payload: ThreatSignalCreate, identity: dict[str, str] = Depends(require_api_key)) -> dict[str, Any]:
    require_role(identity, {"admin", "security-analyst"})
    analysis = analyze_threat_signal(payload.signal_type, payload.severity, payload.indicators)
    incident_id = None
    with get_conn() as conn:
        cursor = conn.execute(
            """
            INSERT INTO threat_signals(lot_id, source, signal_type, severity, description, indicators_json, action_json)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (payload.lot_id, payload.source, payload.signal_type, payload.severity, payload.description, json_dumps(payload.indicators), json_dumps(analysis)),
        )
        signal_id = cursor.lastrowid
        if analysis["threat_score"] >= 70:
            cursor = conn.execute(
                "INSERT INTO incidents(severity, title, description) VALUES (?, ?, ?)",
                (payload.severity, f"Automated threat response: {payload.signal_type}", payload.description),
            )
            incident_id = cursor.lastrowid
    trace_event = None
    if payload.lot_id:
        with get_conn() as conn:
            exists = conn.execute("SELECT lot_id FROM materials WHERE lot_id = ?", (payload.lot_id,)).fetchone()
        if exists:
            trace_event = add_chain_event(
                lot_id=payload.lot_id,
                event_type="THREAT_SIGNAL_DETECTED",
                actor=identity["actor"],
                location=payload.source,
                payload={**payload.model_dump(), "analysis": analysis, "incident_id": incident_id},
            )
    audit(identity["actor"], "ingest_threat_signal", payload.lot_id or "global", True, {"signal_id": signal_id, "incident_id": incident_id, "analysis": analysis})
    return {"signal_id": signal_id, "incident_id": incident_id, "analysis": analysis, "trace_event": trace_event}


@app.get("/api/v1/security/threat-summary/{lot_id}")
def threat_summary(lot_id: str, identity: dict[str, str] = Depends(require_api_key)) -> dict[str, Any]:
    require_role(identity, {"admin", "security-analyst", "supply-chain-manager"})
    with get_conn() as conn:
        rows = conn.execute("SELECT * FROM threat_signals WHERE lot_id = ? ORDER BY id DESC", (lot_id,)).fetchall()
    items = [{**r, "indicators": json_loads(r["indicators_json"]), "action": json_loads(r["action_json"])} for r in rows]
    max_score = max([int(i["action"].get("threat_score", 0)) for i in items], default=0)
    return {"lot_id": lot_id, "signals": items, "max_threat_score": max_score, "requires_attention": max_score >= 70}


@app.get("/api/v1/risk/diversification")
def get_diversification_strategy(material_type: str, current_region_risk: str = "medium", single_source: bool = False, identity: dict[str, str] = Depends(require_api_key)) -> dict[str, Any]:
    require_role(identity, {"admin", "risk-analyst", "supply-chain-manager"})
    if current_region_risk not in {"low", "medium", "high"}:
        raise HTTPException(status_code=400, detail="current_region_risk must be low, medium, or high")
    result = diversification_strategy(material_type, current_region_risk, single_source)
    audit(identity["actor"], "diversification_strategy", material_type, True, result)
    return result


@app.post("/api/v1/security/incidents", status_code=status.HTTP_201_CREATED)
def create_incident(payload: IncidentCreate, identity: dict[str, str] = Depends(require_api_key)) -> dict[str, Any]:
    require_role(identity, {"admin", "security-analyst"})
    with get_conn() as conn:
        cursor = conn.execute(
            "INSERT INTO incidents(severity, title, description) VALUES (?, ?, ?)",
            (payload.severity, payload.title, payload.description),
        )
        incident_id = cursor.lastrowid
    audit(identity["actor"], "create_incident", str(incident_id), True, payload.model_dump())
    return {"incident_id": incident_id, "status": "OPEN", **payload.model_dump()}


@app.get("/api/v1/security/audit")
def list_audit_logs(limit: int = 50, identity: dict[str, str] = Depends(require_api_key)) -> dict[str, Any]:
    require_role(identity, {"admin", "security-analyst"})
    safe_limit = min(max(limit, 1), 200)
    with get_conn() as conn:
        rows = conn.execute("SELECT * FROM audit_logs ORDER BY id DESC LIMIT ?", (safe_limit,)).fetchall()
    return {"items": [{**r, "detail": json_loads(r["detail_json"])} for r in rows]}


@app.get("/api/v1/blockchain/validate")
def blockchain_validate(lot_id: str | None = None, identity: dict[str, str] = Depends(require_api_key)) -> dict[str, Any]:
    audit(identity["actor"], "validate_chain", lot_id or "all", True, {})
    return validate_chain(lot_id)
