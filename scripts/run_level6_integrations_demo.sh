#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "[INFO] .env not found; creating it with scripts/init_env.sh"
  bash "$ROOT_DIR/scripts/init_env.sh"
fi

source "$ROOT_DIR/scripts/lib/load_env.sh"

BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"
LOT_ID="${LOT_ID:-LOT-L6-$(date +%s)}"
GOOD_IMG="${GOOD_IMG:-$ROOT_DIR/sample_data/good_material.png}"
DEFECT_IMG="${DEFECT_IMG:-$ROOT_DIR/sample_data/defective_material.png}"
VERBOSE="${VERBOSE:-false}"

HDR=(-H "X-API-Key: ${API_KEY}" -H "X-Actor: ${ACTOR:-Awon Riaz}" -H "X-Role: ${ROLE:-admin}")

if [[ "$VERBOSE" != "true" ]] && ! command -v jq >/dev/null 2>&1; then
  echo "[ERROR] jq is required for compact output."
  echo "Install with: sudo apt install -y jq"
  echo "Or run full JSON mode with: VERBOSE=true bash scripts/run_level6_integrations_demo.sh"
  exit 1
fi

wait_for() {
  local url="$1"
  local name="$2"
  for _ in {1..60}; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "[OK] $name is ready"
      return 0
    fi
    sleep 2
  done
  echo "[ERROR] $name did not become ready: $url" >&2
  return 1
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "[ERROR] Missing demo image: $path" >&2
    echo "Recreate sample dataset with: python scripts/generate_samples.py" >&2
    exit 1
  fi
}

step() {
  echo ""
  echo "===== $1 ====="
}

show_json() {
  local json="$1"
  local filter="$2"

  if [[ "$VERBOSE" == "true" ]]; then
    echo "$json" | python -m json.tool
  else
    echo "$json" | jq -r "$filter"
  fi
}

require_file "$GOOD_IMG"
require_file "$DEFECT_IMG"

step "Level 6 integration demo"
echo "LOT_ID=$LOT_ID"
echo "Mode: compact"
echo "Full JSON mode: VERBOSE=true bash scripts/run_level6_integrations_demo.sh"

wait_for "$BASE_URL/health" "AMSCP API"
wait_for "http://127.0.0.1:8501/health" "TensorFlow QC service"
wait_for "http://127.0.0.1:9200" "Elasticsearch"

step "1) API health"
RESP=$(curl -sS "$BASE_URL/health")
show_json "$RESP" '
"API: " + .status,
"Environment: " + .environment
'

step "2) Create strategic material lot"
RESP=$(curl -sS -X POST "$BASE_URL/api/v1/materials" \
  "${HDR[@]}" -H "Content-Type: application/json" \
  -d "{\"lot_id\":\"$LOT_ID\",\"material_type\":\"rare-earth magnet alloy\",\"supplier\":\"Strategic Minerals Ltd\",\"origin_country\":\"Australia\",\"metadata\":{\"location\":\"Mumbai Region\",\"use_case\":\"semiconductor manufacturing\"}}")
show_json "$RESP" '
"Lot created: " + .material.lot_id,
"Material: " + .material.material_type,
"Supplier: " + .material.supplier,
"Origin: " + .material.origin_country,
"Trace event: " + .trace_event.event_type,
"Hash: " + (.trace_event.event_hash[0:16])
'

step "3) Record custody/provenance event"
RESP=$(curl -sS -X POST "$BASE_URL/api/v1/trace/events" \
  "${HDR[@]}" -H "Content-Type: application/json" \
  -d "{\"lot_id\":\"$LOT_ID\",\"event_type\":\"CUSTODY_TRANSFER\",\"location\":\"Mumbai QC Lab\",\"payload\":{\"from\":\"Port\",\"to\":\"QC Lab\",\"sealed_container\":true}}")
show_json "$RESP" '
"Event: " + .event_type,
"Location: " + .location,
"From: " + .payload.from,
"To: " + .payload.to,
"Hash: " + (.event_hash[0:16])
'

step "4) TensorFlow QC: GOOD material"
RESP=$(curl -sS -X POST "$BASE_URL/api/v1/quality/tensorflow/inspect?lot_id=$LOT_ID" \
  "${HDR[@]}" \
  -F "file=@$GOOD_IMG")
show_json "$RESP" '
"Image: " + .tensorflow_inspection.filename,
"Result: " + .tensorflow_inspection.result,
"Defect probability: " + (.tensorflow_inspection.defect_probability|tostring),
"Explanation: " + .tensorflow_inspection.explainability_note,
"Trace hash: " + (.trace_event.event_hash[0:16])
'

step "5) TensorFlow QC: DEFECTIVE material"
RESP=$(curl -sS -X POST "$BASE_URL/api/v1/quality/tensorflow/inspect?lot_id=$LOT_ID" \
  "${HDR[@]}" \
  -F "file=@$DEFECT_IMG")
show_json "$RESP" '
"Image: " + .tensorflow_inspection.filename,
"Result: " + .tensorflow_inspection.result,
"Defect probability: " + (.tensorflow_inspection.defect_probability|tostring),
"Explanation: " + .tensorflow_inspection.explainability_note,
"Trace hash: " + (.trace_event.event_hash[0:16])
'

step "6) Predictive quality summary"
RESP=$(curl -sS "$BASE_URL/api/v1/quality/predictive/$LOT_ID" "${HDR[@]}")
show_json "$RESP" '
"Inspections: " + (.inspection_count|tostring),
"Failed: " + (.failed_inspections|tostring),
"Defect rate: " + (.defect_rate_percent|tostring) + "%",
"Prediction: " + .prediction,
"Action: " + .recommended_action
'

step "7) ESG carbon/energy/water/waste evidence"
RESP=$(curl -sS -X POST "$BASE_URL/api/v1/esg/carbon" \
  "${HDR[@]}" -H "Content-Type: application/json" \
  -d "{\"lot_id\":\"$LOT_ID\",\"stage\":\"smelting\",\"co2e_kg\":1200,\"energy_kwh\":4100,\"water_l\":850,\"waste_kg\":17}")
show_json "$RESP" '
"Stage: " + .trace_event.payload.stage,
"CO2e kg: " + (.summary.total_co2e_kg|tostring),
"Energy kWh: " + (.summary.total_energy_kwh|tostring),
"Water L: " + (.summary.total_water_l|tostring),
"Waste kg: " + (.summary.total_waste_kg|tostring),
"ESG grade: " + .summary.esg_grade,
"Trace hash: " + (.trace_event.event_hash[0:16])
'

step "8) ESG summary"
RESP=$(curl -sS "$BASE_URL/api/v1/esg/summary/$LOT_ID" "${HDR[@]}")
show_json "$RESP" '
"Events: " + (.event_count|tostring),
"Total CO2e kg: " + (.total_co2e_kg|tostring),
"Total energy kWh: " + (.total_energy_kwh|tostring),
"ESG grade: " + .esg_grade
'

step "9) Strategic material risk assessment"
RESP=$(curl -sS -X POST "$BASE_URL/api/v1/risk/assess" \
  "${HDR[@]}" -H "Content-Type: application/json" \
  -d "{\"lot_id\":\"$LOT_ID\",\"material_type\":\"rare-earth\",\"origin_country\":\"Australia\",\"supplier\":\"Strategic Minerals Ltd\",\"supplier_score\":82,\"region_risk\":\"high\",\"single_source\":false,\"threat_intel_hits\":1}")
show_json "$RESP" '
"Material: " + .assessment.material_type,
"Origin: " + .assessment.origin_country,
"Risk score: " + (.assessment.risk_score|tostring),
"Risk level: " + .assessment.level,
"Trace hash: " + (.trace_event.event_hash[0:16])
'

step "10) Diversification strategy"
RESP=$(curl -sS "$BASE_URL/api/v1/risk/diversification?material_type=rare-earth&current_region_risk=high&single_source=false" "${HDR[@]}")
show_json "$RESP" '
"Material: " + .material_type,
"Current region risk: " + .current_region_risk,
"Actions:",
(.recommended_diversification_actions[] | "- " + .)
'

step "11) MES/IoT process telemetry"
RESP=$(curl -sS -X POST "$BASE_URL/api/v1/iot/process-events" \
  "${HDR[@]}" -H "Content-Type: application/json" \
  -d "{\"lot_id\":\"$LOT_ID\",\"source\":\"OPC-UA\",\"machine_id\":\"FURNACE-01\",\"line_id\":\"LINE-A\",\"metric_name\":\"temperature_c\",\"metric_value\":872.5,\"unit\":\"C\"}")
show_json "$RESP" '
"Source: " + .process_event.source,
"Machine: " + .process_event.machine_id,
"Metric: " + .process_event.metric_name + "=" + (.process_event.metric_value|tostring) + .process_event.unit,
"Optimization level: " + .optimization.level,
"Action: " + .optimization.recommended_action,
"Trace hash: " + (.trace_event.event_hash[0:16])
'

step "12) Validate compliance certification"
RESP=$(curl -sS -X POST "$BASE_URL/api/v1/compliance/certifications/validate" \
  "${HDR[@]}" -H "Content-Type: application/json" \
  -d "{\"lot_id\":\"$LOT_ID\",\"standard\":\"ISO9001\",\"certificate_id\":\"ISO9001-DEMO-$LOT_ID\",\"issuer\":\"Demo Certification Body\"}")
show_json "$RESP" '
"Standard: " + .validation.standard,
"Certificate: " + .validation.certificate_id,
"Status: " + .validation.status,
"Evidence hash: " + (.validation.evidence_hash[0:16]),
"Trace hash: " + (.trace_event.event_hash[0:16])
'

step "13) Compliance report"
RESP=$(curl -sS "$BASE_URL/api/v1/compliance/report/$LOT_ID" "${HDR[@]}")
show_json "$RESP" '
"Compliance score: " + (.compliance_score_percent|tostring) + "%",
"Checks:",
(.checks[] | "- " + .standard + " | " + .control + " | " + .status)
'

step "14) Add cybersecurity threat signal"
RESP=$(curl -sS -X POST "$BASE_URL/api/v1/security/threat-signals" \
  "${HDR[@]}" -H "Content-Type: application/json" \
  -d "{\"lot_id\":\"$LOT_ID\",\"source\":\"ThreatIntel\",\"signal_type\":\"SUPPLIER_COMPROMISE\",\"severity\":\"HIGH\",\"description\":\"Supplier portal credential abuse indicator for linked supplier\",\"indicators\":[\"suspicious-login\",\"impossible-travel\"]}")
show_json "$RESP" '
"Signal ID: " + (.signal_id|tostring),
"Incident ID: " + (.incident_id|tostring),
"Threat score: " + (.analysis.threat_score|tostring),
"Category: " + .analysis.category,
"Detected: " + (.analysis.detected|tostring),
"Trace hash: " + (.trace_event.event_hash[0:16])
'

step "15) Create incident response record"
RESP=$(curl -sS -X POST "$BASE_URL/api/v1/security/incidents" \
  "${HDR[@]}" -H "Content-Type: application/json" \
  -d "{\"severity\":\"HIGH\",\"title\":\"Supplier portal compromise investigation\",\"description\":\"Investigate supplier access logs and quarantine related evidence until cleared.\"}")
show_json "$RESP" '
"Incident ID: " + (.incident_id|tostring),
"Severity: " + .severity,
"Status: " + .status,
"Title: " + .title
'

step "16) Threat summary"
RESP=$(curl -sS "$BASE_URL/api/v1/security/threat-summary/$LOT_ID" "${HDR[@]}")
show_json "$RESP" '
"Signals: " + (.signals|length|tostring),
"Max threat score: " + (.max_threat_score|tostring),
"Requires attention: " + (.requires_attention|tostring)
'

step "17) Digital Material Passport summary"
RESP=$(curl -sS "$BASE_URL/api/v1/materials/$LOT_ID/passport" "${HDR[@]}")
show_json "$RESP" '
"Lot: " + .lot_id,
"Material: " + .material.material_type,
"Supplier: " + .material.supplier,
"Origin: " + .material.origin_country,
"Trace events: " + (.traceability|length|tostring),
"Quality records: " + (.quality|length|tostring),
"Risk level: " + ((.risk[0].level // "N/A")|tostring),
"ESG grade: " + .sustainability.esg_grade,
"Compliance score: " + (.compliance.compliance_score_percent|tostring) + "%",
"Hash-chain valid: " + (.chain_validation.valid|tostring)
'

step "18) Sync passport to Elasticsearch"
RESP=$(curl -sS -X POST "$BASE_URL/api/v1/search/sync/$LOT_ID" "${HDR[@]}")
show_json "$RESP" '
"Index: " + .index_response._index,
"Document ID: " + .index_response._id,
"Sync result: " + .index_response.result,
"Shards successful: " + (.index_response._shards.successful|tostring)
'

step "19) Search material/passport in Elasticsearch"
RESP=$(curl -sS "$BASE_URL/api/v1/search/materials?q=rare%20earth%20Australia&size=5" "${HDR[@]}")
show_json "$RESP" '
if (.hits.hits? != null) then
  "Search hits: " + ((.hits.total.value // (.hits.hits|length))|tostring),
  (.hits.hits[]? | "- " + (._id|tostring) + " | " + (._source.material_type // "material") + " | " + (._source.risk_level // "risk N/A"))
elif (.results? != null) then
  "Search results: " + (.results|length|tostring),
  (.results[]? | "- " + (.lot_id // .id // "result"))
else
  "Search endpoint returned successfully"
end
'

step "20) Validate local SHA-256 hash-chain integrity"
RESP=$(curl -sS "$BASE_URL/api/v1/blockchain/validate?lot_id=$LOT_ID" "${HDR[@]}")
show_json "$RESP" '
"Valid: " + (.valid|tostring),
"Checked events: " + (.checked_events|tostring),
"Errors: " + ((.errors|length)|tostring)
'

step "21) Audit log summary"
RESP=$(curl -sS "$BASE_URL/api/v1/security/audit?limit=20" "${HDR[@]}")
show_json "$RESP" '
if type == "array" then
  "Audit entries: " + (length|tostring)
elif (.logs? != null) then
  "Audit entries: " + (.logs|length|tostring)
elif (.audit_logs? != null) then
  "Audit entries: " + (.audit_logs|length|tostring)
elif (.items? != null) then
  "Audit entries: " + (.items|length|tostring)
else
  "Audit endpoint returned successfully"
end
'

step "22) Metrics endpoint"
if [[ "$VERBOSE" == "true" ]]; then
  curl -sS "$BASE_URL/metrics" | head -40
else
  curl -fsS "$BASE_URL/metrics" >/dev/null
  echo "Metrics endpoint: OK"
fi

echo ""
echo "[DONE] Level 6 demo completed for LOT_ID=$LOT_ID"
echo "Full JSON evidence mode:"
echo "VERBOSE=true bash scripts/run_level6_integrations_demo.sh"
echo ""
echo "Fabric advanced path:"
echo "bash fabric/scripts/bootstrap_test_network.sh && bash fabric/scripts/deploy_material_passport.sh && bash fabric/scripts/invoke_material_demo.sh"