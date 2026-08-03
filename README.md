# python-api

Basic FastAPI starter with Kubernetes + GitHub Actions CI/CD.

## Endpoints
- `GET /healthz`
- `GET /api/v1/hello`

## Run locally
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt
uvicorn app.main:app --reload --port 8080
```

## Test
```bash
pytest
```

## GitHub Secrets required
- `KUBE_CONFIG`: kubeconfig content for your k3s cluster.

## CI/CD behavior
- On push to `main`, workflow builds image and pushes to GHCR.
- Then deploys to `dev` overlay and waits for rollout.
