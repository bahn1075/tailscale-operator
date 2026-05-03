#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-tailscale}"

kubectl get namespace "${NAMESPACE}"
kubectl -n "${NAMESPACE}" get secret operator-oauth
kubectl -n "${NAMESPACE}" get deploy operator
kubectl -n "${NAMESPACE}" rollout status deploy/operator
kubectl get ingressclass tailscale
kubectl get crd proxyclasses.tailscale.com connectors.tailscale.com proxygroups.tailscale.com dnsconfigs.tailscale.com recorders.tailscale.com
