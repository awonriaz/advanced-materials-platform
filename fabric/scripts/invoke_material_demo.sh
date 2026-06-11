#!/usr/bin/env bash
set -euo pipefail

# Git Bash fix and Fabric environment defaults.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"
export OVERRIDE_ORG="${OVERRIDE_ORG:-}"
export VERBOSE="${VERBOSE:-false}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PARENT_DIR="$(dirname "$REPO_ROOT")"
FABRIC_SAMPLES_DIR="${FABRIC_SAMPLES_DIR:-$PARENT_DIR/fabric-samples}"
TEST_NETWORK="$FABRIC_SAMPLES_DIR/test-network"
CHANNEL_NAME="${CHANNEL_NAME:-materialchannel}"
CC_NAME="${CC_NAME:-materialpassport}"

export PATH="$FABRIC_SAMPLES_DIR/bin:$PATH"
export FABRIC_CFG_PATH="$FABRIC_SAMPLES_DIR/config"

cd "$TEST_NETWORK"
# shellcheck disable=SC1091
source ./scripts/envVar.sh
setGlobals 1

peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile "$ORDERER_CA" \
  -C "$CHANNEL_NAME" -n "$CC_NAME" \
  --peerAddresses localhost:7051 --tlsRootCertFiles "$PEER0_ORG1_CA" \
  --peerAddresses localhost:9051 --tlsRootCertFiles "$PEER0_ORG2_CA" \
  -c '{"function":"CreateMaterialPassport","Args":["LOT-FABRIC-001","Rare Earth Magnet Alloy","Strategic Minerals Ltd","Australia","Mumbai Plant","[\"ISO-9001\",\"ISO-14001\"]"]}'

sleep 3

peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile "$ORDERER_CA" \
  -C "$CHANNEL_NAME" -n "$CC_NAME" \
  --peerAddresses localhost:7051 --tlsRootCertFiles "$PEER0_ORG1_CA" \
  --peerAddresses localhost:9051 --tlsRootCertFiles "$PEER0_ORG2_CA" \
  -c '{"function":"AddQualityInspection","Args":["LOT-FABRIC-001","qa-engineer","PASS","0.08","sha256-demo-image-hash","tensorflow-lightweight-cnn-material-qc"]}'

sleep 3

peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile "$ORDERER_CA" \
  -C "$CHANNEL_NAME" -n "$CC_NAME" \
  --peerAddresses localhost:7051 --tlsRootCertFiles "$PEER0_ORG1_CA" \
  --peerAddresses localhost:9051 --tlsRootCertFiles "$PEER0_ORG2_CA" \
  -c '{"function":"AddESGEvent","Args":["LOT-FABRIC-001","smelting","1200","4100","850","17"]}'

sleep 3

peer chaincode query -C "$CHANNEL_NAME" -n "$CC_NAME" -c '{"function":"ReadPassport","Args":["LOT-FABRIC-001"]}'

echo
echo "[Fabric] Demo complete. You showed immutable provenance, TensorFlow QC certification event, and ESG evidence on Hyperledger Fabric."
