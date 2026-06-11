from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


class MaterialCreate(BaseModel):
    lot_id: str = Field(..., examples=["LOT-RE-0001"])
    material_type: str = Field(..., examples=["rare-earth"])
    supplier: str = Field(..., examples=["Strategic Minerals Ltd"])
    origin_country: str = Field(..., examples=["Australia"])
    metadata: dict[str, Any] = Field(default_factory=dict)


class TraceEventCreate(BaseModel):
    lot_id: str
    event_type: Literal[
        "MATERIAL_CREATED",
        "CUSTODY_TRANSFER",
        "QUALITY_CHECK",
        "CERTIFICATION_VALIDATED",
        "SHIPMENT_DISPATCHED",
        "RECEIVED",
        "ESG_EVENT",
        "RISK_ASSESSMENT",
        "INCIDENT_CREATED",
        "TENSORFLOW_QUALITY_CHECK",
        "PYTORCH_QUALITY_CHECK",
        "MES_PROCESS_EVENT",
        "MQTT_TELEMETRY",
        "OPCUA_TELEMETRY",
        "THREAT_SIGNAL_DETECTED",
    ]
    actor: str = "system"
    location: str = "Mumbai"
    payload: dict[str, Any] = Field(default_factory=dict)


class CarbonEventCreate(BaseModel):
    lot_id: str
    stage: str = Field(..., examples=["smelting"])
    co2e_kg: float = Field(..., ge=0)
    energy_kwh: float = Field(..., ge=0)
    water_l: float = Field(..., ge=0)
    waste_kg: float = Field(..., ge=0)


class RiskAssessRequest(BaseModel):
    lot_id: str | None = None
    material_type: str
    origin_country: str
    supplier: str
    supplier_score: float = Field(..., ge=0, le=100)
    region_risk: Literal["low", "medium", "high"] = "medium"
    single_source: bool = False
    threat_intel_hits: int = Field(default=0, ge=0)


class ProcessTelemetryCreate(BaseModel):
    lot_id: str
    source: Literal["MES", "MQTT", "OPC-UA", "SIMULATED"] = "MES"
    machine_id: str = Field(..., examples=["CNC-INSPECT-01"])
    line_id: str = Field(..., examples=["LINE-A"])
    metric_name: str = Field(..., examples=["temperature_c"])
    metric_value: float
    unit: str = Field(..., examples=["C"])


class CertificationValidationRequest(BaseModel):
    lot_id: str
    standard: Literal["ISO9001", "ISO14001", "GRI", "CUSTOM"]
    certificate_id: str
    issuer: str
    expires_at: str | None = None
    evidence_hash: str | None = None


class ThreatSignalCreate(BaseModel):
    lot_id: str | None = None
    source: Literal["SIEM", "IDS", "ThreatIntel", "SupplierPortal", "Manual"] = "ThreatIntel"
    signal_type: Literal["DATA_BREACH", "SUPPLIER_COMPROMISE", "ANOMALOUS_CUSTODY", "MALWARE", "CREDENTIAL_ABUSE", "GEO_DISRUPTION"]
    severity: Literal["LOW", "MEDIUM", "HIGH", "CRITICAL"]
    description: str
    indicators: list[str] = Field(default_factory=list)


class IncidentCreate(BaseModel):
    severity: Literal["LOW", "MEDIUM", "HIGH", "CRITICAL"]
    title: str
    description: str
