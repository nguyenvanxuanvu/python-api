#!/usr/bin/env bash
# local-deploy.sh — mirrors the GitHub Actions ci-cd.yml flow locally.
# Usage: ./local-deploy.sh [dev|prod]   (default: dev)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
ENV="${1:-dev}"
NAMESPACE="python-api-${ENV}"
DEPLOYMENT="python-api"
SHA="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo 'local')"
IMAGE="python-api:${SHA}"

resolve_bin() {
  local preferred="$1"
  local name="$2"

  if [[ -x "$preferred" ]]; then
    echo "$preferred"
    return 0
  fi

  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi

  return 1
}

DOCKER="$(resolve_bin "${HOME}/.rd/bin/docker" docker || true)"
KUBECTL="$(resolve_bin "${HOME}/.rd/bin/kubectl" kubectl || true)"
KUSTOMIZE="$(resolve_bin "${HOME}/.local/bin/kustomize" kustomize || true)"

[[ -n "$DOCKER" ]] || fail "docker not found. Install Docker and ensure 'docker' is on PATH"
[[ -n "$KUBECTL" ]] || fail "kubectl not found. Install kubectl and ensure it is on PATH"
if ! command -v python3 >/dev/null 2>&1; then
  fail "python3 not found. Install Python 3 and ensure it is on PATH"
fi

# Colours
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; RESET='\033[0m'
step() { echo -e "\n${CYAN}==> $*${RESET}"; }
ok()   { echo -e "${GREEN}OK${RESET}"; }
fail() { echo -e "${RED}FAILED: $*${RESET}"; exit 1; }

# ── Step 1: Run tests ─────────────────────────────────────────────────────────
step "[CI] Run Python tests"
cd "$REPO_ROOT"

# Create venv if missing, or recreate if it is broken/stale
if [ ! -x ".venv/bin/python3" ]; then
  rm -rf .venv
  python3 -m venv .venv
fi
source .venv/bin/activate
python3 -m pip install --quiet --upgrade pip
python3 -m pip install --quiet -r requirements.txt -r requirements-dev.txt
PYTHONPATH="$REPO_ROOT" pytest || fail "Tests failed — fix before deploying"
deactivate
ok

# ── Step 2: Build image into containerd k8s.io namespace ─────────────────────
step "[CI] Build Docker image  →  ${IMAGE}"
"$DOCKER" build \
  -t "$IMAGE" \
  "$REPO_ROOT"
ok

# ── Step 3: Prepare kustomize overlay in /tmp (mirrors 'Set image' step) ─────
step "[CD] Prepare kustomize overlay for env=${ENV}"
TMP_K8S="/tmp/python-api-k8s-${SHA}"
rm -rf "$TMP_K8S"
cp -R "$REPO_ROOT/k8s" "$TMP_K8S"

cd "$TMP_K8S/overlays/${ENV}"

# Point kustomize at the local image
if [[ -n "$KUSTOMIZE" ]]; then
  "$KUSTOMIZE" edit set image APP_IMAGE="${IMAGE}"
else
  echo "kustomize not found; will apply overlay then set deployment image with kubectl"
fi
ok

# ── Step 4: Apply manifests (mirrors 'kubectl apply' step) ────────────────────
step "[CD] kubectl apply -k  (namespace: ${NAMESPACE})"
"$KUBECTL" apply -k "$TMP_K8S/overlays/${ENV}"

if [[ -z "$KUSTOMIZE" ]]; then
  step "[CD] Set deployment image  (namespace: ${NAMESPACE})"
  "$KUBECTL" set image "deployment/${DEPLOYMENT}" "api=${IMAGE}" -n "$NAMESPACE"
  ok
fi

ok

# Force pods to restart so they pick up any rebuilt local image with the same tag
step "[CD] Rollout restart  (namespace: ${NAMESPACE})"
"$KUBECTL" rollout restart "deployment/${DEPLOYMENT}" -n "$NAMESPACE"
ok

# ── Step 5: Wait for rollout (mirrors 'Wait for rollout' step) ────────────────
step "[CD] Wait for rollout  (timeout 120s)"
"$KUBECTL" rollout status "deployment/${DEPLOYMENT}" -n "$NAMESPACE" --timeout=120s
ok

# ── Step 6: Smoke check ───────────────────────────────────────────────────────
step "[CD] Smoke check — pods and service"
"$KUBECTL" get pods,svc -n "$NAMESPACE"

echo ""
echo -e "${GREEN}Deploy complete!${RESET}"
echo "Access the API with port-forward:"
echo "  kubectl -n ${NAMESPACE} port-forward svc/${DEPLOYMENT} 18081:80"
echo "  curl http://localhost:18081/healthz"
echo "  curl http://localhost:18081/api/v1/hello"
