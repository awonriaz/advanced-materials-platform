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
HDR=(-H "X-API-Key: ${API_KEY}" -H "X-Actor: ${ACTOR:-Awon Riaz}" -H "X-Role: ${ROLE:-admin}")

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
    echo "Recreate the simple sample dataset with: python scripts/generate_samples.py" >&2
    exit 1
  fi
}

step() { echo ""; echo "===== $1 ====="; }

require_file "$GOOD_IMG"
require_file "$DEFECT_IMG"

step "Level 6 integration demo: FastAPI + TensorFlow QC + Elasticsearch + Passport evidence"
echo "LOT_ID=$LOT_ID"
echo "Start stack first with: docker compose --profile full up -d --build"
wait_for "$BASE_URL/health" "AMSCP API"
wait_for "http://127.0.0.1:8501/health" "TensorFlow QC service"
wait_for "http://127.0.0.1:9200" "Elasticsearch"

step "1) API health check"
curl -sS "$BASE_URL/health" | python -m json.tool

step "2) Create strategic material lot"
curl -sS -X POST "$BASE_URL/api/v1/materials" \
  "${HDR[@]}" -H "Content-Type: application/json" \
  -d "{\"lot_id\":\"$LOT_ID\",\"material_type\":\"rare-earth magnet alloy\",\"supplier\":\"Strategic Minerals Ltd\",\"origin_country\":\"Australia\",\"metadata\":{\"location\":\"Mumbai Region\",\"use_case\":\"semiconductor manufacturing\"}}" | python -m json.tool

step "3) Record custody/provenance trace event"
curl -sS -X POST "$BASE_URL/api/v1/trace/events" \
  "${HDR[@]}" -H "Content-Type: application/json" \
  -d "{\"lot_id\":\"$LOT_ID\",\"event_type\":\"CUSTODY_TRANSFER\",\"location\":\"Mumbai QC Lab\",\"payload\":{\"from\":\"Port\",\"to\":\"QC Lab\",\"sealed_container\":true}}" | python -m json.tool

step "4) TensorFlow QC inspection: GOOD material should PASS"
curl -sS -X POST "$BASE_URL/api/v1/quality/tensorflow/inspect?lot_id=$LOT_ID" \
  "${HDR[@]}" \
  -F "file=@$GOOD_IMG" | python -m json.tool

step "5) TensorFlow QC inspection: DEFECTIVE material should FAIL"
curl -sS -X POST "$BASE_URL/api/v1/quality/tensorflow/inspect?lot_id=$LOT_ID" \
  "${HDR[@]}" \
  -F "file=@$DEFECT_IMG" | python -m json.tool

step "6) Predictive quality summary"
curl -sS "$BASE_URL/api/v1/quality/predictive/$LOT_ID" "${HDR[@]}" | python -m json.tool

step "7) Add ESG carbon/energy/water/waste evidence"
curl -sS -X POST "$BASE_URL/api/v1/esg/carbon" \
  "${HDR[@]}" -H "Content-Type: application/json" \
  -d "{\"lot_id\":\"$LOT_ID\",\"stage\":\"smelting\",\"co2e_kg\":1200,\"energy_kwh\":4100,\"water_l\":850,\"waste_kg\":17}" | python -m json.tool

step "8) ESG summary"
curl -sS "$BASE_URL/api/v1/esg/summary/$LOT_ID" "${HDR[@]}" | python -m json.tool

step "9) Strategic material risk assessment"
curl -sS -X POST "$BASE_URL/api/v1/risk/assess" \
  "${HDR[@]}" -H "Content-Type: application/json" \
  -d "{\"lot_id\":\"$LOT_ID\",\"material_type\":\"rare-earth\",\"origin_country\":\"Australia\",\"supplier\":\"Strategic Minerals Ltd\",\"supplier_score\":82,\"region_risk\":\"high\",\"single_source\":false,\"threat_intel_hits\":1}" | python -m json.tool

step "10) Diversification strategy"
curl -sS "$BASE_URL/api/v1/risk/diversification?material_type=rare-earth&current_region_risk=high&single_source=false" "${HDR[@]}" | python -m json.tool

step "11) MES/IoT process telemetry"
curl -sS -X POST "$BASE_URL/api/v1/iot/process-events" \
  "${HDR[@]}" -H "Content-Type: application/json" \
  -d "{\"lot_id\":\"$LOT_ID\",\"source\":\"OPC-UA\",\"machine_id\":\"FURNACE-01\",\"line_id\":\"LINE-A\",\"metric_name\":\"temperature_c\",\"metric_value\":872.5,\"unit\":\"C\"}" | python -m json.tool

step "12) Validate compliance certification evidence"
curl -sS -X POST "$BASE_URL/api/v1/compliance/certifications/validate" \
  "${HDR[@]}" -H "Content-Type: application/json" \
  -d "{\"lot_id\":\"$LOT_ID\",\"standard\":\"ISO9001\",\"certificate_id\":\"ISO9001-DEMO-$LOT_ID\",\"issuer\":\"Demo Certification Body\"}" | python -m json.tool

step "13) Compliance report"
curl -sS "$BASE_URL/api/v1/compliance/report/$LOT_ID" "${HDR[@]}" | python -m json.tool

step "14) Add cybersecurity threat signal"
curl -sS -X POST "$BASE_URL/api/v1/security/threat-signals" \
  "${HDR[@]}" -H "Content-Type: application/json" \
  -d "{\"lot_id\":\"$LOT_ID\",\"source\":\"ThreatIntel\",\"signal_type\":\"SUPPLIER_COMPROMISE\",\"severity\":\"HIGH\",\"description\":\"Supplier portal credential abuse indicator for linked supplier\",\"indicators\":[\"suspicious-login\",\"impossible-travel\"]}" | python -m json.tool

step "15) Create incident response record"
curl -sS -X POST "$BASE_URL/api/v1/security/incidents" \
  "${HDR[@]}" -H "Content-Type: application/json" \
  -d "{\"severity\":\"HIGH\",\"title\":\"Supplier portal compromise investigation\",\"description\":\"Investigate supplier access logs and quarantine related evidence until cleared.\"}" | python -m json.tool

step "16) Threat summary"
curl -sS "$BASE_URL/api/v1/security/threat-summary/$LOT_ID" "${HDR[@]}" | python -m json.tool

step "17) Digital Material Passport"
curl -sS "$BASE_URL/api/v1/materials/$LOT_ID/passport" "${HDR[@]}" | python -m json.tool

step "18) Sync passport to Elasticsearch"
curl -sS -X POST "$BASE_URL/api/v1/search/sync/$LOT_ID" "${HDR[@]}" | python -m json.tool

step "19) Search material/passport in Elasticsearch"
curl -sS "$BASE_URL/api/v1/search/materials?q=rare%20earth%20Australia&size=5" "${HDR[@]}" | python -m json.tool

step "20) Validate local SHA-256 hash-chain integrity"
curl -sS "$BASE_URL/api/v1/blockchain/validate?lot_id=$LOT_ID" "${HDR[@]}" | python -m json.tool

step "21) Show audit logs"
curl -sS "$BASE_URL/api/v1/security/audit?limit=20" "${HDR[@]}" | python -m json.tool

step "22) Metrics sample"
curl -sS "$BASE_URL/metrics" | head -40

echo ""
echo "[DONE] Level 6 demo completed for LOT_ID=$LOT_ID"
echo "Fabric advanced path: bash fabric/scripts/bootstrap_test_network.sh && bash fabric/scripts/deploy_material_passport.sh && bash fabric/scripts/invoke_material_demo.sh"
