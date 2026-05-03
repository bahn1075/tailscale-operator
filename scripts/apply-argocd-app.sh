#!/usr/bin/env bash
set -euo pipefail

kubectl apply -f /app/tailscale-operator/argocd/application.yaml
kubectl -n argocd get application tailscale-operator
