# Kubernetes deployment notes

This folder contains the Kubernetes implementation evidence for the Level 6 architecture.

The API key is not stored in a YAML manifest. `deploy-kind.sh` reads it from the local `.env` file and creates the Kubernetes Secret at runtime:

```bash
kubectl -n amscp create secret generic amscp-secret \
  --from-literal=API_KEY="$API_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -
```

Run locally with Kind:

```bash
cp .env.example .env
# edit .env and set API_KEY
bash k8s/deploy-kind.sh
kubectl -n amscp get pods -o wide
```

Production changes:

- Use AWS EKS instead of Kind.
- Use ECR-hosted images instead of `:local` images.
- Use AWS Secrets Manager or External Secrets Operator instead of creating secrets manually.
- Replace `emptyDir` volumes with PersistentVolumeClaims backed by encrypted EBS.
- Keep API, Elasticsearch, and TensorFlow services private unless fronted by an authenticated ingress/load balancer.
