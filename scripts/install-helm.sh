#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-tailscale}"
RELEASE="${RELEASE:-tailscale-operator}"
CHART="${CHART:-tailscale/tailscale-operator}"
CHART_VERSION="${CHART_VERSION:-1.96.5}"
VALUES_FILE="${VALUES_FILE:-/app/tailscale-operator/values.yaml}"
EXTRA_VALUES_FILE="${EXTRA_VALUES_FILE:-}"

if [[ -z "${TS_OAUTH_CLIENT_ID:-}" || -z "${TS_OAUTH_CLIENT_SECRET:-}" ]]; then
  cat >&2 <<'EOF'
Missing required OAuth credentials.

Set:
  export TS_OAUTH_CLIENT_ID='k...CNTRL'
  export TS_OAUTH_CLIENT_SECRET='tskey-client-k...CNTRL-...'

The Kubernetes operator cannot use a tskey-auth-* reusable auth key.
EOF
  exit 1
fi

kubectl apply -f /app/tailscale-operator/manifests/namespace.yaml

kubectl create secret generic operator-oauth \
  --namespace "${NAMESPACE}" \
  --from-literal=client_id="${TS_OAUTH_CLIENT_ID}" \
  --from-literal=client_secret="${TS_OAUTH_CLIENT_SECRET}" \
  --dry-run=client -o yaml | kubectl apply -f -

helm repo add tailscale https://pkgs.tailscale.com/helmcharts >/dev/null 2>&1 || true
helm repo update tailscale

helm_args=(
  upgrade --install "${RELEASE}" "${CHART}"
  --version "${CHART_VERSION}" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  -f "${VALUES_FILE}" \
)

if [[ -n "${EXTRA_VALUES_FILE}" ]]; then
  helm_args+=(-f "${EXTRA_VALUES_FILE}")
fi

helm_args+=(--wait)

helm "${helm_args[@]}"

kubectl -n "${NAMESPACE}" rollout status deploy/operator
kubectl -n "${NAMESPACE}" get pods,deploy,svc
