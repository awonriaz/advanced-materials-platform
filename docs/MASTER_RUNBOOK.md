## 1. Prerequisites

### Windows host

Install:

- VS Code
- Git for Windows / Git Bash
- Docker Desktop with WSL2 backend
- Python 3.11+
- Optional: kubectl and kind for Kubernetes demo
- Optional but recommended for Fabric: WSL Ubuntu

### Docker Desktop settings

Avoid running every heavy component at the same time. For the exam, use Docker Compose full stack for the main demo, then run Fabric separately.

Recommended Docker Desktop memory: 6 GB if possible.

---

## 2. Open the project

### Git Bash

```bash
cd /c/Users/YOUR_NAME/amscp
code .
```

### WSL Ubuntu

```bash
cd /mnt/c/Users/YOUR_NAME/amscp
code .
```

---

## 3. Create the secure local `.env`

Do this before Docker Compose. This avoids the error: `.env not found`.

### Git Bash / WSL / EC2 Ubuntu

```bash
bash scripts/init_env.sh
```

### PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\init_env.ps1
```

Expected:

```text
[OK] .env is ready. API_KEY and MQTT_PASSWORD are set but were not printed.
```

Verify `.env` is ignored by Git:

```bash
git check-ignore .env
git ls-files .env
```

Expected: first command prints `.env`; second command prints nothing.

---


## 4. Optional Python virtual environment for tests/scripts

### Git Bash on Windows

```bash
python -m venv .venv
source .venv/Scripts/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
```

### WSL/Ubuntu

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
```

Run tests:

```bash
bash scripts/init_env.sh
python -m pytest -q
```

Expected: core tests pass.

---

## 5. Run Docker Compose full stack

This starts:

- FastAPI API on `8000`
- TensorFlow QC service on `8501`
- Elasticsearch on `9200`

```bash
bash scripts/init_env.sh
docker compose --profile full up -d --build
docker compose --profile full ps
```

Health checks:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8501/health
curl http://127.0.0.1:9200
```

Expected:

- API returns `status: ok`
- TensorFlow service returns `model_loaded: true`
- Elasticsearch returns cluster/version JSON

---

## 6. Direct TensorFlow QC check

```bash
curl -sS -X POST http://127.0.0.1:8501/inspect \
  -F "file=@sample_data/good_material.png" | python -m json.tool

curl -sS -X POST http://127.0.0.1:8501/inspect \
  -F "file=@sample_data/defective_material.png" | python -m json.tool
```

Expected:

```text
good_material.png      -> PASS
defective_material.png -> FAIL
```

The response includes:

- `filename`
- `image_sha256`
- `model`
- `tensorflow_probability`
- `cv_anomaly_score`
- `defect_probability`
- `result`
- `explainability_note`

---

## 7. Run the full Level 6 workflow script

```bash
bash scripts/run_level6_integrations_demo.sh
```

The script demonstrates:

1. API health check
2. Create strategic material lot
3. Custody/provenance trace event
4. TensorFlow QC on good image
5. TensorFlow QC on defective image
6. Predictive quality summary
7. ESG carbon/energy/water/waste evidence
8. ESG summary
9. Strategic risk assessment
10. Diversification strategy
11. MES/IoT process telemetry
12. Certification validation
13. Compliance report
14. Threat signal
15. Incident response record
16. Threat summary
17. Digital Material Passport
18. Elasticsearch sync
19. Elasticsearch search
20. SHA-256 hash-chain validation
21. Audit logs
22. Metrics sample

This is the main oral-exam demonstration path.

---

## 8. Swagger UI manual testing

Open:

```text
http://127.0.0.1:8000/docs
```

Use headers when executing protected endpoints:

```text
X-API-Key: value from .env
X-Actor: Awon Riaz
X-Role: admin
```

---

## 10. Spark ESG batch analytics

Spark path demonstrates enterprise-scale ESG aggregation separately from the live FastAPI ESG endpoint.

```bash
python analytics/spark_esg_batch.py
```

Explanation:

- FastAPI ESG endpoint = live/demo event capture
- Spark ESG batch = enterprise-scale aggregation of CO2e, energy, water and waste by `lot_id`

---

## 11. Hyperledger Fabric demo

Run Fabric separately from the main Docker Compose demo because Fabric is heavier and can be sensitive on Windows Git Bash.

### Recommended WSL/Ubuntu or EC2 Ubuntu path

```bash
export FABRIC_SAMPLES_DIR=$HOME/fabric-samples
bash fabric/scripts/bootstrap_test_network.sh
bash fabric/scripts/deploy_material_passport.sh
bash fabric/scripts/invoke_material_demo.sh
```

### Git Bash path

```bash
export FABRIC_SAMPLES_DIR=/c/fabric-samples
bash fabric/scripts/bootstrap_test_network.sh
bash fabric/scripts/deploy_material_passport.sh
bash fabric/scripts/invoke_material_demo.sh
```

The Fabric scripts keep the same deploy/invoke architecture:

- `bootstrap_test_network.sh` prepares official Fabric samples, binaries and images
- `deploy_material_passport.sh` creates `materialchannel` and deploys `materialpassport` chaincode
- `invoke_material_demo.sh` creates a material passport, adds QC evidence, adds ESG evidence and reads the final passport

If Fabric download fails due to network reset, rerun `bootstrap_test_network.sh`. The script retries and cleans partial `bin/config` folders.

---

## 12. Kubernetes / Kind evidence

Stop heavy Docker Compose services first if RAM is low:

```bash
docker compose --profile full --profile full-plus --profile iot --profile pytorch down
bash scripts/init_env.sh
bash k8s/deploy-kind.sh
kubectl -n amscp get pods -o wide
kubectl -n amscp get svc
```

If port forwarding is needed:

```bash
kubectl -n amscp port-forward svc/amscp-api 8000:8000
curl http://127.0.0.1:8000/health
```

Production mapping:

- Kind → AWS EKS
- SQLite demo → RDS PostgreSQL
- Elasticsearch demo → Amazon OpenSearch
- local `.env`/K8s Secret → AWS Secrets Manager
- local Docker images → ECR
- direct local ports → ALB + WAF + TLS

---

## 13. Optional profiles

### Prometheus

```bash
docker compose --profile full-plus up -d prometheus
curl http://127.0.0.1:8000/metrics | head
```

### MQTT/Mosquitto

```bash
docker compose --profile iot up -d mosquitto
python scripts/publish_mqtt_demo.py
```

### PyTorch QC

```bash
docker compose --profile pytorch up -d --build
curl http://127.0.0.1:8601/health
```

PyTorch is an optional alternate QC model service. It is not required for the core live exam demo because TensorFlow + CV already satisfy the AI QC requirement.

---

## 14. Troubleshooting

### `.env not found`

```bash
bash scripts/init_env.sh
```

Then rerun Docker Compose.

### TensorFlow service slow startup

First startup may train a small demo model from `sample_data`. Wait and retry:

```bash
docker logs amscp-tensorflow-qc --tail 100
dash 2>/dev/null || true
curl http://127.0.0.1:8501/health
```

### Elasticsearch not ready

Wait 30–60 seconds:

```bash
docker logs amscp-elasticsearch --tail 50
curl http://127.0.0.1:9200
```

### Git Bash Fabric `/data` or path errors

The Fabric scripts export Git Bash path-conversion guards inside the relevant scripts. If Windows still causes issues, run Fabric from WSL Ubuntu.

