# AMSCP – Advanced Materials Supply Chain Platform

**Topic 116:** Building a Comprehensive Advanced Materials Supply Chain Platform with AI-Driven Quality Control, Blockchain Traceability, and Sustainability Analytics for Strategic Industries.

This is a codebase from scratch that adds a strong synthetic QC dataset, stable TensorFlow/CV classification, complete runbook, Docker Compose, Kubernetes/Kind manifests, Hyperledger Fabric chaincode, optional Ethereum artifact, GitHub Actions, Spark ESG batch analytics, Ansible EC2 bootstrap, observability, and security documentation.

The live demo path focuses on **FastAPI + TensorFlow QC + Elasticsearch + SQLite/hash-chain + Digital Material Passport**. Fabric, Kubernetes, Spark, MQTT/OPC-UA, PyTorch, and AWS are included as implementation evidence or staged enterprise paths where appropriate.


## Main endpoints

```text
GET  /health
GET  /metrics
POST /api/v1/materials
GET  /api/v1/materials/{lot_id}/passport
POST /api/v1/search/sync/{lot_id}
GET  /api/v1/search/materials
POST /api/v1/trace/events
POST /api/v1/quality/inspect
POST /api/v1/quality/tensorflow/inspect
POST /api/v1/esg/carbon
GET  /api/v1/esg/summary/{lot_id}
POST /api/v1/risk/assess
GET  /api/v1/risk/diversification
POST /api/v1/iot/process-events
GET  /api/v1/quality/predictive/{lot_id}
POST /api/v1/compliance/certifications/validate
GET  /api/v1/compliance/report/{lot_id}
POST /api/v1/security/threat-signals
GET  /api/v1/security/threat-summary/{lot_id}
POST /api/v1/security/incidents
GET  /api/v1/security/audit
GET  /api/v1/blockchain/validate
```


## Quick start: Windows Git Bash / WSL / Linux

```bash
cd amscp
bash scripts/init_env.sh
python scripts/generate_sample_qc_dataset.py --overwrite
python scripts/prepare_demo_assets.py

docker compose --profile full up -d --build
```

Health checks:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8501/health
curl http://127.0.0.1:9200
```

Run the complete exam workflow:

```bash
bash scripts/run_level6_integration_demo.sh
```

Compatibility wrappers are also included:

```bash
bash scripts/run_level6_integrations_demo.sh
```

---

## TensorFlow QC dataset and model

The project includes a deterministic synthetic dataset for exam/training evidence. It is not a production-grade industrial inspection dataset.

```text
sample_data/images/train/good        24 images
sample_data/images/train/defective   24 images
sample_data/images/val/good           8 images
sample_data/images/val/defective      8 images
sample_data/images/test/good          8 images
sample_data/images/test/defective     8 images
sample_data/labels.csv
```

Persistent demo images:

```text
sample_data/demo/good_material_demo.png
sample_data/demo/defective_material_demo.png
sample_data/good_material.png
sample_data/defective_material.png
```

Stable source files:

```text
sample_data/images/test/good/good_silicon_wafer_0102.png
sample_data/images/test/defective/defective_titanium_alloy_0118.png
```

Training:

```bash
pip install tensorflow==2.16.1 keras==3.3.3 pillow numpy
python scripts/train_material_qc_model.py
python scripts/evaluate_material_qc_model.py
```

The TensorFlow service uses:

```python
IMG_SIZE = int(os.getenv("IMG_SIZE", "128"))
MODEL_PATH = Path(os.getenv("MODEL_PATH", "/app/models/material_qc.keras"))
DEFECT_THRESHOLD = float(os.getenv("DEFECT_THRESHOLD", "0.60"))
```

The service returns:

```text
filename
image_sha256
model
tensorflow_probability
cv_anomaly_score
defect_probability
result
explainability_note
```

The final decision is service-equivalent and exam-defendable: **TensorFlow probability + explainable CV anomaly score -> PASS/FAIL**. This avoids the weak-demo-model problem where raw TensorFlow output alone may stay near 0.53 for all images. The CV guard ensures obvious synthetic test defects fail correctly while good material images pass.

Expected stable result:

```text
good_material_demo.png      -> PASS
defective_material_demo.png -> FAIL
```

---

## Security model

- `.env` is ignored by Git.
- `.env.example` contains no real secrets.
- `scripts/init_env.sh` and `scripts/init_env.ps1` generate local demo secrets without printing them.
- The API fails closed if `API_KEY` is missing or unsafe.
- Kubernetes uses a Secret created at deploy time.
- GitHub Actions uses an ephemeral CI API key.
- Elasticsearch and TensorFlow ports are bound to localhost in Docker Compose.

---

## Docker Compose profiles

```bash
# Full exam demo: API + TensorFlow QC + Elasticsearch + Prometheus
bash scripts/init_env.sh
docker compose --profile full up -d --build

# Optional IoT broker
CONFIG ONLY: docker compose --profile iot up -d

# Optional PyTorch alternate QC service
CONFIG ONLY: docker compose --profile pytorch up -d --build
```

The core oral-exam demo uses the `full` profile. PyTorch, MQTT/OPC-UA, Spark, Kubernetes, and AWS are included as optional/staged enterprise evidence, not required for the main live demo.

---

## Hyperledger Fabric

Fabric is kept separate because it is heavier than the Docker API stack. Use it as the permissioned blockchain trust-layer demonstration.

```bash
export FABRIC_SAMPLES_DIR=/c/fabric-samples
bash fabric/scripts/bootstrap_test_network.sh
bash fabric/scripts/deploy_material_passport.sh
bash fabric/scripts/invoke_material_demo.sh
```

Fabric demonstrates:

- permissioned multi-organization provenance,
- chaincode-based material passport evidence,
- TensorFlow QC evidence event,
- ESG evidence event,
- final `QUALITY_APPROVED` passport state,
- deterministic transaction timestamp handling.

---

## Kubernetes / Kind

```bash
bash scripts/init_env.sh
bash k8s/deploy-kind.sh
kubectl -n amscp get pods -o wide
```

Kubernetes demonstrates Deployments, Services, ConfigMap, Secret, probes, resource limits, NetworkPolicy, HPA, and local Kind path. Production would replace Kind with EKS, local images with ECR, SQLite with RDS, local Elasticsearch with OpenSearch, and local secrets with AWS Secrets Manager.

---

## Spark ESG batch analytics

FastAPI ESG endpoints record live/demo ESG events. Spark batch analytics represent enterprise-scale reporting over CSV/data-lake inputs.

```bash
python analytics/spark_esg_batch.py
```

Input:

```text
data/carbon_events.csv
```

Output groups CO2e, energy, water, and waste by `lot_id`.

---

## Oral exam positioning

Use this statement if asked why some services are optional:

> The core live demo proves the integrated platform path with FastAPI, TensorFlow QC, Elasticsearch, SQLite/hash-chain, audit logs, ESG, risk, compliance, security, IoT, and Digital Material Passport. Hyperledger Fabric is demonstrated separately as the permissioned blockchain trust layer. Kubernetes, Spark, PyTorch, MQTT/OPC-UA, Ansible, and AWS are included as staged enterprise deployment evidence to avoid overloading an 8 GB exam machine while preserving the complete Level 6 architecture.

