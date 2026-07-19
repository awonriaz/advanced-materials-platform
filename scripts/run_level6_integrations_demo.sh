#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -f "$ROOT_DIR/.env" ]] || bash "$ROOT_DIR/scripts/init_env.sh"
source "$ROOT_DIR/scripts/lib/load_env.sh"

BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"
TF_URL="${TF_URL:-http://127.0.0.1:8501}"
ES_URL="${ES_URL:-http://127.0.0.1:9200}"
LOT_ID="${LOT_ID:-LOT-L6-$(date +%s)}"
GOOD_IMG="${GOOD_IMG:-$ROOT_DIR/sample_data/good_material.png}"
DEFECT_IMG="${DEFECT_IMG:-$ROOT_DIR/sample_data/defective_material.png}"
RAW_JSON="${RAW_JSON:-false}"

HDR=(
  -H "X-API-Key: ${API_KEY}"
  -H "X-Actor: ${ACTOR:-Awon Riaz}"
  -H "X-Role: ${ROLE:-admin}"
)

JQ_COMMON='
def v($x):
  if $x == null then "N/A"
  elif ($x | type) == "array" then ($x | map(tostring) | join(", "))
  else ($x | tostring)
  end;

def p($label; $value):
  $label + ": " + v($value);

def trace($t):
  p("Trace event"; $t.event_type),
  p("Actor"; $t.actor),
  p("Location"; $t.location),
  p("Previous hash"; $t.previous_hash),
  p("Event hash"; $t.event_hash);

def audit_items:
  if type == "array" then .
  elif .logs? then .logs
  elif .audit_logs? then .audit_logs
  elif .items? then .items
  else []
  end;
'

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERROR] Missing command: $1"
    exit 1
  }
}

if [[ "$RAW_JSON" != "true" ]]; then
  require_command jq
fi

require_file() {
  [[ -f "$1" ]] || {
    echo "[ERROR] Missing file: $1"
    echo "Run: python scripts/generate_samples.py"
    exit 1
  }
}

wait_for() {
  local url="$1"
  local name="$2"

  for _ in {1..60}; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "[OK] $name"
      return 0
    fi
    sleep 2
  done

  echo "[ERROR] $name not ready: $url"
  exit 1
}

step() {
  echo ""
  echo "===== $1 ====="
  echo "Endpoint: $2"
}

show() {
  local json="$1"
  local filter="$2"

  if [[ "$RAW_JSON" == "true" ]]; then
    echo "$json" | python -m json.tool
  else
    echo "$json" | jq -r "$JQ_COMMON $filter"
  fi
}

get_api() {
  curl -sS "$BASE_URL$1" "${HDR[@]}"
}

post_json() {
  curl -sS -X POST "$BASE_URL$1" \
    "${HDR[@]}" \
    -H "Content-Type: application/json" \
    -d "$2"
}

post_file() {
  curl -sS -X POST "$BASE_URL$1" \
    "${HDR[@]}" \
    -F "file=@$2"
}

require_file "$GOOD_IMG"
require_file "$DEFECT_IMG"

echo ""
echo "===== Level 6 AMSCP Integration Demo ====="
echo "LOT_ID: $LOT_ID"
echo "Output mode: detailed summary"
echo "Raw JSON mode: RAW_JSON=true bash scripts/run_level6_integrations_demo.sh"

wait_for "$BASE_URL/health" "AMSCP API ready"
wait_for "$TF_URL/health" "TensorFlow QC ready"
wait_for "$ES_URL" "Elasticsearch ready"

step "1) API health check" "GET /health"
RESP=$(curl -sS "$BASE_URL/health")
show "$RESP" '
p("Status"; .status),
p("Environment"; .environment)
'

step "2) Create strategic material lot" "POST /api/v1/materials"
RESP=$(post_json "/api/v1/materials" "{
  \"lot_id\":\"$LOT_ID\",
  \"material_type\":\"rare-earth magnet alloy\",
  \"supplier\":\"Strategic Minerals Ltd\",
  \"origin_country\":\"Australia\",
  \"metadata\":{
    \"location\":\"Mumbai Region\",
    \"use_case\":\"semiconductor manufacturing\"
  }
}")
show "$RESP" '
p("Lot ID"; .material.lot_id),
p("Material type"; .material.material_type),
p("Supplier"; .material.supplier),
p("Origin country"; .material.origin_country),
p("Metadata location"; .material.metadata.location),
p("Metadata use case"; .material.metadata.use_case),
trace(.trace_event)
'

step "3) Record custody/provenance trace event" "POST /api/v1/trace/events"
RESP=$(post_json "/api/v1/trace/events" "{
  \"lot_id\":\"$LOT_ID\",
  \"event_type\":\"CUSTODY_TRANSFER\",
  \"location\":\"Mumbai QC Lab\",
  \"payload\":{
    \"from\":\"Port\",
    \"to\":\"QC Lab\",
    \"sealed_container\":true
  }
}")
show "$RESP" '
p("Lot ID"; .lot_id),
p("From"; .payload.from),
p("To"; .payload.to),
p("Sealed container"; .payload.sealed_container),
trace(.)
'

step "4) TensorFlow QC inspection: GOOD material" "POST /api/v1/quality/tensorflow/inspect"
RESP=$(post_file "/api/v1/quality/tensorflow/inspect?lot_id=$LOT_ID" "$GOOD_IMG")
show "$RESP" '
p("Lot ID"; .lot_id),
p("Image"; .tensorflow_inspection.filename),
p("Model"; .tensorflow_inspection.model),
p("TensorFlow probability"; .tensorflow_inspection.tensorflow_probability),
p("CV anomaly score"; .tensorflow_inspection.cv_anomaly_score),
p("Defect probability"; .tensorflow_inspection.defect_probability),
p("Result"; .tensorflow_inspection.result),
p("Explanation"; .tensorflow_inspection.explainability_note),
p("Image SHA-256"; .tensorflow_inspection.image_sha256),
trace(.trace_event)
'

step "5) TensorFlow QC inspection: DEFECTIVE material" "POST /api/v1/quality/tensorflow/inspect"
RESP=$(post_file "/api/v1/quality/tensorflow/inspect?lot_id=$LOT_ID" "$DEFECT_IMG")
show "$RESP" '
p("Lot ID"; .lot_id),
p("Image"; .tensorflow_inspection.filename),
p("Model"; .tensorflow_inspection.model),
p("TensorFlow probability"; .tensorflow_inspection.tensorflow_probability),
p("CV anomaly score"; .tensorflow_inspection.cv_anomaly_score),
p("Defect probability"; .tensorflow_inspection.defect_probability),
p("Result"; .tensorflow_inspection.result),
p("Explanation"; .tensorflow_inspection.explainability_note),
p("Image SHA-256"; .tensorflow_inspection.image_sha256),
trace(.trace_event)
'

step "6) Predictive quality summary" "GET /api/v1/quality/predictive/{lot_id}"
RESP=$(get_api "/api/v1/quality/predictive/$LOT_ID")
show "$RESP" '
p("Inspection count"; .inspection_count),
p("Failed inspections"; .failed_inspections),
p("Defect rate percent"; .defect_rate_percent),
p("Average defect score"; .average_defect_score),
p("Process warning count"; .process_warning_count),
p("Prediction"; .prediction),
p("Recommended action"; .recommended_action)
'

step "7) Add ESG evidence" "POST /api/v1/esg/carbon"
RESP=$(post_json "/api/v1/esg/carbon" "{
  \"lot_id\":\"$LOT_ID\",
  \"stage\":\"smelting\",
  \"co2e_kg\":1200,
  \"energy_kwh\":4100,
  \"water_l\":850,
  \"waste_kg\":17
}")
show "$RESP" '
p("Lot ID"; .summary.lot_id),
p("Stage"; .trace_event.payload.stage),
p("CO2e kg"; .trace_event.payload.co2e_kg),
p("Energy kWh"; .trace_event.payload.energy_kwh),
p("Water L"; .trace_event.payload.water_l),
p("Waste kg"; .trace_event.payload.waste_kg),
p("Event count"; .summary.event_count),
p("Total CO2e kg"; .summary.total_co2e_kg),
p("Total energy kWh"; .summary.total_energy_kwh),
p("Total water L"; .summary.total_water_l),
p("Total waste kg"; .summary.total_waste_kg),
p("Circularity score percent"; .summary.circularity_score_percent),
p("ESG grade"; .summary.esg_grade),
trace(.trace_event)
'

step "8) ESG summary" "GET /api/v1/esg/summary/{lot_id}"
RESP=$(get_api "/api/v1/esg/summary/$LOT_ID")
show "$RESP" '
p("Lot ID"; .lot_id),
p("Event count"; .event_count),
p("Total CO2e kg"; .total_co2e_kg),
p("Total energy kWh"; .total_energy_kwh),
p("Total water L"; .total_water_l),
p("Total waste kg"; .total_waste_kg),
p("Circularity score percent"; .circularity_score_percent),
p("ESG grade"; .esg_grade)
'

step "9) Strategic material risk assessment" "POST /api/v1/risk/assess"
RESP=$(post_json "/api/v1/risk/assess" "{
  \"lot_id\":\"$LOT_ID\",
  \"material_type\":\"rare-earth\",
  \"origin_country\":\"Australia\",
  \"supplier\":\"Strategic Minerals Ltd\",
  \"supplier_score\":82,
  \"region_risk\":\"high\",
  \"single_source\":false,
  \"threat_intel_hits\":1
}")
show "$RESP" '
p("Lot ID"; .assessment.lot_id),
p("Material type"; .assessment.material_type),
p("Origin country"; .assessment.origin_country),
p("Supplier"; .assessment.supplier),
p("Supplier score"; .assessment.supplier_score),
p("Region risk"; .assessment.region_risk),
p("Single source"; .assessment.single_source),
p("Threat intel hits"; .assessment.threat_intel_hits),
p("Risk score"; .assessment.risk_score),
p("Level"; .assessment.level),
p("Material criticality factor"; .assessment.factors.material_criticality),
p("Region risk weight"; .assessment.factors.region_risk_weight),
p("Supplier penalty"; .assessment.factors.supplier_penalty),
p("Single source penalty"; .assessment.factors.single_source_penalty),
p("Threat intel penalty"; .assessment.factors.threat_intel_penalty),
trace(.trace_event)
'

step "10) Diversification strategy" "GET /api/v1/risk/diversification"
RESP=$(get_api "/api/v1/risk/diversification?material_type=rare-earth&current_region_risk=high&single_source=false")
show "$RESP" '
p("Material type"; .material_type),
p("Criticality weight"; .criticality_weight),
p("Current region risk"; .current_region_risk),
p("Single source"; .single_source),
"Recommended actions:",
(.recommended_diversification_actions[]? | "- " + .)
'

step "11) MES/IoT process telemetry" "POST /api/v1/iot/process-events"
RESP=$(post_json "/api/v1/iot/process-events" "{
  \"lot_id\":\"$LOT_ID\",
  \"source\":\"OPC-UA\",
  \"machine_id\":\"FURNACE-01\",
  \"line_id\":\"LINE-A\",
  \"metric_name\":\"temperature_c\",
  \"metric_value\":872.5,
  \"unit\":\"C\"
}")
show "$RESP" '
p("Lot ID"; .process_event.lot_id),
p("Source"; .process_event.source),
p("Machine ID"; .process_event.machine_id),
p("Line ID"; .process_event.line_id),
p("Metric name"; .process_event.metric_name),
p("Metric value"; .process_event.metric_value),
p("Unit"; .process_event.unit),
p("Optimization level"; .optimization.level),
p("Quality impact"; .optimization.quality_impact),
p("Recommended action"; .optimization.recommended_action),
trace(.trace_event)
'

step "12) Validate compliance certification evidence" "POST /api/v1/compliance/certifications/validate"
RESP=$(post_json "/api/v1/compliance/certifications/validate" "{
  \"lot_id\":\"$LOT_ID\",
  \"standard\":\"ISO9001\",
  \"certificate_id\":\"ISO9001-DEMO-$LOT_ID\",
  \"issuer\":\"Demo Certification Body\"
}")
show "$RESP" '
p("Standard"; .validation.standard),
p("Certificate ID"; .validation.certificate_id),
p("Issuer"; .validation.issuer),
p("Status"; .validation.status),
p("Evidence hash"; .validation.evidence_hash),
"Controls:",
((.validation.controls // [])[]? | "- " + (.control // "N/A") + " | " + (.evidence // "N/A")),
trace(.trace_event)
'

step "13) Compliance report" "GET /api/v1/compliance/report/{lot_id}"
RESP=$(get_api "/api/v1/compliance/report/$LOT_ID")
show "$RESP" '
p("Lot ID"; .lot_id),
p("Compliance score percent"; .compliance_score_percent),
"Checks:",
(.checks[]? | "- " + (.standard // "N/A") + " | " + (.control // "N/A") + " | " + (.status // "N/A"))
'

step "14) Add cybersecurity threat signal" "POST /api/v1/security/threat-signals"
RESP=$(post_json "/api/v1/security/threat-signals" "{
  \"lot_id\":\"$LOT_ID\",
  \"source\":\"ThreatIntel\",
  \"signal_type\":\"SUPPLIER_COMPROMISE\",
  \"severity\":\"HIGH\",
  \"description\":\"Supplier portal credential abuse indicator for linked supplier\",
  \"indicators\":[\"suspicious-login\",\"impossible-travel\"]
}")
show "$RESP" '
p("Signal ID"; .signal_id),
p("Incident ID"; .incident_id),
p("Threat score"; .analysis.threat_score),
p("Detected"; .analysis.detected),
p("Category"; .analysis.category),
"Recommended workflow:",
(.analysis.recommended_workflow[]? | "- " + .),
trace(.trace_event)
'

step "15) Create manual SOC follow-up incident response record" "POST /api/v1/security/incidents"
RESP=$(post_json "/api/v1/security/incidents" "{
  \"severity\":\"HIGH\",
  \"title\":\"Manual SOC follow-up for supplier portal compromise\",
  \"description\":\"Investigate supplier access logs and quarantine related evidence until cleared.\"
}")
show "$RESP" '
p("Incident ID"; .incident_id),
p("Status"; .status),
p("Severity"; .severity),
p("Title"; .title),
p("Description"; .description)
'

step "16) Threat summary" "GET /api/v1/security/threat-summary/{lot_id}"
RESP=$(get_api "/api/v1/security/threat-summary/$LOT_ID")
show "$RESP" '
p("Lot ID"; .lot_id),
p("Signals linked to lot"; ((.signals // []) | length)),
p("Max threat score"; .max_threat_score),
p("Requires attention"; .requires_attention),
p("Signal type"; ((.signals // [])[0].signal_type)),
p("Severity"; ((.signals // [])[0].severity)),
p("Source"; ((.signals // [])[0].source)),
p("Indicators"; (((.signals // [])[0].indicators) // []))
'

step "17) Digital Material Passport summary" "GET /api/v1/materials/{lot_id}/passport"
RESP=$(get_api "/api/v1/materials/$LOT_ID/passport")
show "$RESP" '
p("Lot ID"; .lot_id),
"Material identity:",
"- Material type: " + v(.material.material_type),
"- Supplier: " + v(.material.supplier),
"- Origin country: " + v(.material.origin_country),
"- Metadata location: " + v(.material.metadata.location),
"- Metadata use case: " + v(.material.metadata.use_case),
p("Traceability event count"; ((.traceability // []) | length)),
"Trace event types:",
((.traceability // [])[]? | "- " + (.event_type // "N/A")),
p("Quality record count"; ((.quality // []) | length)),
p("Latest quality result"; ((.quality // [])[-1].result)),
p("Failed inspection count"; ((.quality // []) | map(select(.result == "FAIL")) | length)),
p("Risk record count"; ((.risk // []) | length)),
p("Latest risk level"; ((.risk // [])[-1].level)),
p("ESG grade"; .sustainability.esg_grade),
p("Compliance score percent"; .compliance.compliance_score_percent),
p("Process telemetry record count"; ((.process_telemetry // []) | length)),
p("Certification record count"; ((.certifications // []) | length)),
p("Threat signal count"; ((.threat_signals // []) | length)),
p("Max threat score"; (([ (.threat_signals // [])[]?.action.threat_score // empty ] | max) // 0)),
p("Hash-chain valid"; .chain_validation.valid),
p("Hash-chain checked events"; .chain_validation.checked_events),
p("Hash-chain error count"; ((.chain_validation.errors // []) | length)),
p("Predictive quality"; .predictive_quality.prediction),
p("Predictive action"; .predictive_quality.recommended_action),
p("Release status"; .release_decision.status),
p("Releasable"; .release_decision.releasable),
"Release reasons:",
((.release_decision.reasons // [])[]? | "- " + .)
'

step "18) Sync passport to Elasticsearch" "POST /api/v1/search/sync/{lot_id}"
RESP=$(curl -sS -X POST "$BASE_URL/api/v1/search/sync/$LOT_ID" "${HDR[@]}")

show "$RESP" '
  p("Ensure index result"; .ensure_index.result),
  p("Ensure index ok"; .ensure_index.ok),
  p("Index"; .index_response._index),
  p("Document ID"; .index_response._id),
  p("Sync result"; .index_response.result),
  p("Index error"; .index_response.error),
  p("Shards successful"; .index_response._shards.successful),
  p("Indexed lot ID"; .document.lot_id),
  p("Indexed material type"; .document.material_type),
  p("Indexed supplier"; .document.supplier),
  p("Indexed origin country"; .document.origin_country),
  p("Indexed quality result"; .document.quality_result),
  p("Indexed risk level"; .document.risk_level),
  p("Indexed ESG grade"; .document.esg_grade)
'

if [[ "$RAW_JSON" != "true" ]]; then
  echo "$RESP" | jq -e '
    (.index_response.result == "created")
    or (.index_response.result == "updated")
    or (.index_response._id != null)
  ' >/dev/null || {
    echo "[ERROR] Elasticsearch sync failed. Full response:"
    echo "$RESP" | jq .
    exit 1
  }
fi


step "19) Search current material/passport in Elasticsearch" "GET /api/v1/search/materials"
RESP=$(get_api "/api/v1/search/materials?q=$LOT_ID&size=3")

show "$RESP" '
  if (.ok == false or .error? != null) then
    p("Search error"; .error)
  elif (.hits.hits? != null) then
    p("Search hit count"; (.hits.total.value // (.hits.hits | length))),
    (.hits.hits[]? | "- Lot ID: " + (._source.lot_id // ._id // "N/A") + " | Material: " + (._source.material_type // "N/A") + " | Supplier: " + (._source.supplier // "N/A") + " | Quality: " + (._source.quality_result // "N/A") + " | Risk: " + (._source.risk_level // "N/A") + " | ESG: " + (._source.esg_grade // "N/A"))
  else
    "Search endpoint returned but no Elasticsearch hits structure was found"
  end
'

if [[ "$RAW_JSON" != "true" ]]; then
  echo "$RESP" | jq -e --arg LOT_ID "$LOT_ID" '
    (.hits.hits // []) | any((._source.lot_id == $LOT_ID) or (._id == $LOT_ID))
  ' >/dev/null || {
    echo "[ERROR] Elasticsearch search did not return the current LOT_ID. Full response:"
    echo "$RESP" | jq .
    exit 1
  }
fi

step "20) Validate local SHA-256 hash-chain integrity" "GET /api/v1/blockchain/validate"
RESP=$(get_api "/api/v1/blockchain/validate?lot_id=$LOT_ID")
show "$RESP" '
p("Valid"; .valid),
p("Checked events"; .checked_events),
p("Errors count"; ((.errors // []) | length)),
if (((.errors // []) | length) > 0) then
  "Errors:",
  ((.errors // [])[]? | "- " + tostring)
else
  empty
end
'

step "21) Audit log summary" "GET /api/v1/security/audit"
RESP=$(get_api "/api/v1/security/audit?limit=20")
show "$RESP" '
p("Audit entries returned"; (audit_items | length)),
"Latest audit actions:",
(audit_items[0:3][]? |
  "- Actor: " + v(.actor // .user)
  + " | Role: " + v(.role)
  + " | Action: " + v(.action // .event_type // .path)
  + " | Status: " + v(.status // .status_code)
  + " | Timestamp: " + v(.timestamp // .created_at))
'

step "22) Metrics endpoint" "GET /metrics"
if [[ "$RAW_JSON" == "true" ]]; then
  curl -sS "$BASE_URL/metrics" | head -40
else
  curl -fsS "$BASE_URL/metrics" >/dev/null
  echo "Metrics endpoint: OK"
  echo "Prometheus-compatible metrics: reachable"
fi

echo ""
echo "[DONE] Level 6 demo completed for LOT_ID=$LOT_ID"
echo ""
echo "Summary:"
echo "- Material, custody, QC, ESG, risk, IoT, compliance, cybersecurity, passport, search, hash-chain, audit, and metrics completed."
echo "- Raw JSON mode: RAW_JSON=true bash scripts/run_level6_integrations_demo.sh"
echo "- Fabric path: bash fabric/scripts/bootstrap_test_network.sh && bash fabric/scripts/deploy_material_passport.sh && bash fabric/scripts/invoke_material_demo.sh"
