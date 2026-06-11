#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
ROTATE="${1:-}"

if [[ ! -f "$ENV_FILE" ]]; then
  cp "$ROOT_DIR/.env.example" "$ENV_FILE"
fi

get_value() {
  local key="$1"
  grep "^${key}=" "$ENV_FILE" 2>/dev/null | tail -n 1 | cut -d= -f2- || true
}

set_value() {
  local key="$1"
  local value="$2"
  python - "$ENV_FILE" "$key" "$value" <<'PYINNER'
from pathlib import Path
import sys
path = Path(sys.argv[1])
key = sys.argv[2]
value = sys.argv[3]
lines = path.read_text(encoding='utf-8').splitlines() if path.exists() else []
out = []
replaced = False
for line in lines:
    if line.startswith(f"{key}=") and not replaced:
        out.append(f"{key}={value}")
        replaced = True
    else:
        out.append(line)
if not replaced:
    out.append(f"{key}={value}")
path.write_text('\n'.join(out) + '\n', encoding='utf-8')
PYINNER
}

generate_secret() {
  python - <<'PYINNER'
import secrets
print(secrets.token_urlsafe(48))
PYINNER
}

is_blocked() {
  local v="${1:-}"
  [[ -z "$v" || "$v" == "change-this-demo-key" || "$v" == "your-api-key" || "$v" == "paste-your-api-key-here" || "$v" == "replace-me" ]]
}

api_key="$(get_value API_KEY)"
mqtt_password="$(get_value MQTT_PASSWORD)"

if [[ "$ROTATE" == "--rotate" ]] || is_blocked "$api_key"; then
  set_value API_KEY "$(generate_secret)"
fi

if [[ -z "$(get_value MQTT_USERNAME)" ]]; then
  set_value MQTT_USERNAME "amscp_demo"
fi

if [[ "$ROTATE" == "--rotate" || -z "$mqtt_password" ]]; then
  set_value MQTT_PASSWORD "$(generate_secret)"
fi

chmod 600 "$ENV_FILE" 2>/dev/null || true
echo "[OK] .env is ready. API_KEY and MQTT_PASSWORD are set but were not printed."
