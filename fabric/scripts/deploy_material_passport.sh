#!/usr/bin/env bash
set -euo pipefail

# Git Bash fix: stop MSYS from rewriting Docker paths used by Fabric network.sh.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"
export OVERRIDE_ORG="${OVERRIDE_ORG:-}"
export VERBOSE="${VERBOSE:-false}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PARENT_DIR="$(dirname "$REPO_ROOT")"
FABRIC_SAMPLES_DIR="${FABRIC_SAMPLES_DIR:-$PARENT_DIR/fabric-samples}"
TEST_NETWORK="$FABRIC_SAMPLES_DIR/test-network"
CHAINCODE_SRC="$REPO_ROOT/fabric/chaincode/material-passport/javascript"
CHAINCODE_DST="$FABRIC_SAMPLES_DIR/chaincode/material-passport-javascript"
CHANNEL_NAME="${CHANNEL_NAME:-materialchannel}"
CC_NAME="${CC_NAME:-materialpassport}"

if [ ! -x "$TEST_NETWORK/network.sh" ]; then
  echo "Cannot find Fabric test network at $TEST_NETWORK"
  echo "Run: bash fabric/scripts/bootstrap_test_network.sh"
  exit 1
fi

rm -rf "$CHAINCODE_DST"
mkdir -p "$(dirname "$CHAINCODE_DST")"
cp -R "$CHAINCODE_SRC" "$CHAINCODE_DST"

export PATH="$FABRIC_SAMPLES_DIR/bin:$PATH"
export FABRIC_CFG_PATH="$FABRIC_SAMPLES_DIR/config"

cd "$TEST_NETWORK"
./network.sh down || true
./network.sh up createChannel -ca -c "$CHANNEL_NAME"
./network.sh deployCC -ccn "$CC_NAME" -ccp "../chaincode/material-passport-javascript" -ccl javascript -c "$CHANNEL_NAME"

echo "[Fabric] Chaincode deployed: $CC_NAME on channel $CHANNEL_NAME"
echo "[Fabric] Run demo invokes: bash $REPO_ROOT/fabric/scripts/invoke_material_demo.sh"
