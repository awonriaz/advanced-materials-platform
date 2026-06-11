# AMSCP Troubleshooting and Common Errors

## API key missing or unsafe
Symptom: app exits with `Missing or unsafe placeholder value for API_KEY`.

Fix:
```bash
bash scripts/init_env.sh
docker compose --profile full up -d --build
```

## Port already allocated
Symptom: Docker cannot bind 8000, 9200, 8501, 9090, or 1883.

Fix:
```bash
docker ps
docker compose --profile full --profile monitoring --profile iot --profile pytorch down
```
Or change host port mapping in `docker-compose.yml`.

## Docker memory issues on Small RAM
Do not run all profiles together. Use staged demos:
- Main: `--profile full`
- Fabric separately
- Kubernetes separately
- PyTorch optional
- Prometheus/MQTT optional

## Elasticsearch timeout
Wait for service health:
```bash
curl http://127.0.0.1:9200
docker logs amscp-elasticsearch
```
If RAM is low, stop optional services.

## TensorFlow service not ready
First run may train/load model.
```bash
docker logs amscp-tensorflow-qc
curl http://127.0.0.1:8501/health
```

## peer command not found
Fabric CLI binaries are not in PATH.
```bash
export FABRIC_SAMPLES_DIR=/c/fabric-samples
export PATH="$FABRIC_SAMPLES_DIR/bin:$PATH"
export FABRIC_CFG_PATH="$FABRIC_SAMPLES_DIR/config"
```

## OVERRIDE_ORG unbound variable
```bash
export OVERRIDE_ORG=""
```

## VERBOSE unbound variable
```bash
export VERBOSE=false
```

## Git Bash /data mount issue or Docker path conversion
Run Fabric in WSL2 if possible. If staying in Git Bash, use:
```bash
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'
```
Avoid repo paths with spaces.

## Fabric path with spaces
Move project to a simple path:
```text
C:\amscp
/home/awon/amscp
```

## fabric-nodeenv image missing
Re-run Fabric bootstrap and pull images:
```bash
bash fabric/scripts/bootstrap_test_network.sh
docker images | grep fabric
```

## ProposalResponsePayloads do not match
This usually means nondeterministic chaincode. Do not use `new Date()`, `Date.now()`, `Math.random()`, or random UUIDs inside chaincode endorsement logic. Use `ctx.stub.getTxTimestamp()` and deterministic JSON serialization.

## Swagger protected endpoint fails
Include headers:
```text
X-API-Key: value from .env
X-Actor: Awon Riaz
X-Role: admin
```

## Duplicate lot ID
Use a timestamped lot:
```bash
LOT_ID=LOT-L6-$(date +%s)
```

## Reset demo data
```bash
docker compose --profile full down
rm -rf data
docker compose --profile full up -d --build
```
