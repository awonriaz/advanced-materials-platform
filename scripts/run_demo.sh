#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib/load_env.sh"

API_URL="${API_URL:-http://127.0.0.1:8000}"
LOT_ID="${LOT_ID:-LOT-RE-0001}"
HDR=(-H "X-API-Key: ${API_KEY}" -H "X-Actor: ${ACTOR:-Awon Riaz}" -H "X-Role: ${ROLE:-admin}")

printf '\n1) Health check\n'
curl -s "${API_URL}/health" | python -m json.tool

printf '\n2) Create material lot\n'
curl -s -X POST "${API_URL}/api/v1/materials" "${HDR[@]}" -H "Content-Type: application/json" \
  -d "{\"lot_id\":\"$LOT_ID\",\"material_type\":\"rare-earth\",\"supplier\":\"Strategic Minerals Ltd\",\"origin_country\":\"Australia\",\"metadata\":{\"grade\":\"NdPr oxide\",\"batch_weight_kg\":250,\"location\":\"Mumbai Demo Warehouse\"}}" \
  | python -m json.tool || true

printf '\n3) Add custody transfer\n'
curl -s -X POST "${API_URL}/api/v1/trace/events" "${HDR[@]}" -H "Content-Type: application/json" \
  -d "{\"lot_id\":\"$LOT_ID\",\"event_type\":\"CUSTODY_TRANSFER\",\"actor\":\"Warehouse Operator\",\"location\":\"Mumbai Demo Warehouse\",\"payload\":{\"from\":\"Supplier\",\"to\":\"QC Lab\",\"condition\":\"sealed\"}}" \
  | python -m json.tool

printf '\n4) Run AI quality control on good sample\n'
curl -s -X POST "${API_URL}/api/v1/quality/inspect?lot_id=$LOT_ID" "${HDR[@]}" \
  -F "file=@${ROOT_DIR}/sample_data/good_material.png" | python -m json.tool

printf '\n5) Run AI quality control on defective sample\n'
curl -s -X POST "${API_URL}/api/v1/quality/inspect?lot_id=$LOT_ID" "${HDR[@]}" \
  -F "file=@${ROOT_DIR}/sample_data/defective_material.png" | python -m json.tool

printf '\n6) Add ESG/carbon event\n'
curl -s -X POST "${API_URL}/api/v1/esg/carbon" "${HDR[@]}" -H "Content-Type: application/json" \
  -d "{\"lot_id\":\"$LOT_ID\",\"stage\":\"smelting\",\"co2e_kg\":120.5,\"energy_kwh\":450,\"water_l\":900,\"waste_kg\":12.4}" | python -m json.tool

printf '\n7) Run strategic material risk assessment\n'
curl -s -X POST "${API_URL}/api/v1/risk/assess" "${HDR[@]}" -H "Content-Type: application/json" \
  -d "{\"lot_id\":\"$LOT_ID\",\"material_type\":\"rare-earth\",\"origin_country\":\"Australia\",\"supplier\":\"Strategic Minerals Ltd\",\"supplier_score\":82,\"region_risk\":\"low\",\"single_source\":true,\"threat_intel_hits\":1}" | python -m json.tool

printf '\n8) Validate blockchain hash chain\n'
curl -s "${API_URL}/api/v1/blockchain/validate?lot_id=$LOT_ID" "${HDR[@]}" | python -m json.tool

printf '\n9) Digital material passport\n'
curl -s "${API_URL}/api/v1/materials/$LOT_ID/passport" "${HDR[@]}" | python -m json.tool
