#!/usr/bin/env bash
# Loads repository .env into the current shell without printing secrets.
# Usage from another script:
#   ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
#   source "$ROOT_DIR/scripts/lib/load_env.sh"

if [[ -z "${ROOT_DIR:-}" ]]; then
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[ERROR] Missing environment file: $ENV_FILE" >&2
  echo "Create it first: cp .env.example .env" >&2
  echo "Then set API_KEY inside .env. Do not commit .env." >&2
  exit 1
fi

set -a
# The .env file is a local deployment file owned by the operator. It must contain simple KEY=value lines.
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

if [[ -z "${API_KEY:-}" ]]; then
  echo "[ERROR] API_KEY is not set. Add API_KEY to $ENV_FILE." >&2
  exit 1
fi
