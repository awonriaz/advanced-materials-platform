#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-amscp}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$REPO_ROOT"
source "$REPO_ROOT/scripts/lib/load_env.sh"
cd "$REPO_ROOT"

if ! command -v kind >/dev/null 2>&1; then
  echo "kind is required. Install kind first, then rerun this script."
  exit 1
fi
if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required. Install kubectl first, then rerun this script."
  exit 1
fi

if ! kind get clusters | grep -qx "$CLUSTER_NAME"; then
  kind create cluster --config k8s/kind-config.yaml --name "$CLUSTER_NAME"
fi

docker build -t amscp-api:local .
docker build -t amscp-tensorflow-qc:local -f services/tensorflow-qc/Dockerfile .
kind load docker-image amscp-api:local --name "$CLUSTER_NAME"
kind load docker-image amscp-tensorflow-qc:local --name "$CLUSTER_NAME"

kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-configmap.yaml
kubectl -n amscp create secret generic amscp-secret \
  --from-literal=API_KEY="$API_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/03-api.yaml
kubectl apply -f k8s/04-elasticsearch.yaml
kubectl apply -f k8s/05-tensorflow-qc.yaml
kubectl apply -f k8s/06-networkpolicy.yaml
kubectl apply -f k8s/07-hpa.yaml || true

kubectl -n amscp rollout status deploy/amscp-api --timeout=180s
kubectl -n amscp rollout status deploy/tensorflow-qc --timeout=300s || true
kubectl -n amscp get pods -o wide

echo "API: http://127.0.0.1:8000/health"
echo "Elasticsearch NodePort: http://127.0.0.1:9200"
