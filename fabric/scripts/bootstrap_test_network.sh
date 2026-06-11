#!/usr/bin/env bash
set -euo pipefail

# This script prepares the official Hyperledger Fabric sample network beside this repository.
# It requires Docker, Docker Compose plugin, curl, git, and Node.js/npm for JavaScript chaincode packaging.
# Git Bash fix: stop MSYS from rewriting Docker paths such as /var/run and /data.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PARENT_DIR="$(dirname "$REPO_ROOT")"
FABRIC_SAMPLES_DIR="${FABRIC_SAMPLES_DIR:-$PARENT_DIR/fabric-samples}"

if [ ! -d "$FABRIC_SAMPLES_DIR" ]; then
  echo "[Fabric] Cloning fabric-samples into $FABRIC_SAMPLES_DIR"
  git clone https://github.com/hyperledger/fabric-samples.git "$FABRIC_SAMPLES_DIR"
fi

cd "$FABRIC_SAMPLES_DIR"
if [ ! -d "bin" ] || [ ! -d "config" ]; then
  echo "[Fabric] Downloading Fabric binaries and Docker images using the official install script"
  for attempt in 1 2; do
    if curl -sSL https://bit.ly/2ysbOFE | bash -s -- -s; then
      break
    fi
    echo "[Fabric] Download attempt $attempt failed; cleaning partial bin/config and retrying if possible"
    rm -rf bin config
    if [ "$attempt" -eq 2 ]; then
      echo "[Fabric] Download failed twice. Check internet connection and run this script again." >&2
      exit 1
    fi
  done
fi

export PATH="$FABRIC_SAMPLES_DIR/bin:$PATH"
export FABRIC_CFG_PATH="$FABRIC_SAMPLES_DIR/config"

echo "[Fabric] Test network directory: $FABRIC_SAMPLES_DIR/test-network"
echo "[Fabric] Next: bash fabric/scripts/deploy_material_passport.sh"
