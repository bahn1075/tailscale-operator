# Tailscale Operator on OCI OKE

This directory contains the deployment bundle for installing the Tailscale Kubernetes Operator into the `tailscale` namespace.

Important: the provided `tskey-auth-*` reusable auth key is not enough for the Kubernetes Operator. Current Tailscale docs require OAuth client credentials. The operator uses those credentials to call the Tailscale API and create auth keys for itself and managed devices.

## Source Docs

- https://tailscale.com/docs/kubernetes
- https://tailscale.com/docs/features/kubernetes-operator
- https://tailscale.com/docs/solutions/manage-multi-cluster-kubernetes-deployments-argocd

## Required Tailscale Admin Console Setup

1. Add the tag policy from `tailnet-policy-snippet.json` to the tailnet policy.
2. Create an OAuth client in **Trust credentials** with:
   - Write scopes: `Devices Core`, `Auth Keys`, `Services`
   - If the UI asks for tags, select `tag:k8s-operator`.
   - If the UI does not show a tag selector, use the required write scopes and make sure `tag:k8s-operator` exists in the tailnet policy.
3. Keep the OAuth client ID and secret available locally as environment variables.

## Install With Helm

```bash
export TS_OAUTH_CLIENT_ID='k...CNTRL'
export TS_OAUTH_CLIENT_SECRET='tskey-client-k...CNTRL-...'
/app/tailscale-operator/scripts/install-helm.sh
```

The script creates the `tailscale` namespace, creates `tailscale/operator-oauth`, and installs chart version `1.96.5` from `https://pkgs.tailscale.com/helmcharts`.

## Verify

```bash
/app/tailscale-operator/scripts/verify.sh
```

Also check the Tailscale Machines page for a device named `oci-oke-k8s-operator` tagged with `tag:k8s-operator`.

## Troubleshooting

If the pod shows `ImagePullBackOff` on OCI OKE with CRI-O, use fully-qualified image names. This bundle sets:

- `operatorConfig.image.repository: docker.io/tailscale/k8s-operator`
- `proxyConfig.image.repository: docker.io/tailscale/tailscale`

If the operator logs show `requested tags [tag:k8s-operator] are invalid or not permitted`, fix the Tailscale Admin Console configuration:

1. Ensure the tailnet policy contains the `tagOwners` block from `tailnet-policy-snippet.json`.
2. Ensure `tag:k8s-operator` is defined in the tailnet policy.
3. If the OAuth UI exposes tag selection, ensure the OAuth client was created with `tag:k8s-operator`.
4. Ensure the OAuth client has write scopes for `Devices Core`, `Auth Keys`, and `Services`.
5. After saving the tailnet policy or recreating the OAuth client, restart the operator:

```bash
kubectl -n tailscale rollout restart deploy/operator
kubectl -n tailscale logs deploy/operator --tail=80
```

## ArgoCD Application

`argocd/application.yaml` registers the operator as an ArgoCD `Application` in the `argocd` namespace. It deploys the official Tailscale Helm chart and reads this repository's `values.yaml` through ArgoCD multi-source Helm values. It does not store OAuth credentials. Before syncing the ArgoCD app, create `tailscale/operator-oauth`.

```bash
/app/tailscale-operator/scripts/apply-argocd-app.sh
```

The Application has no automated sync policy, so registering it is safe before credentials are present. Sync it manually after `operator-oauth` exists.

## Optional API Server Proxy

If this OKE cluster should expose its Kubernetes API over Tailscale for remote ArgoCD management, review `values-apiserver-proxy.yaml` and `tailnet-policy-apiserver-proxy-snippet.json`.

```bash
EXTRA_VALUES_FILE=/app/tailscale-operator/values-apiserver-proxy.yaml /app/tailscale-operator/scripts/install-helm.sh
```

For Helm, use both value files if enabling the proxy manually:

```bash
helm upgrade --install tailscale-operator tailscale/tailscale-operator \
  --version 1.96.5 \
  --namespace tailscale \
  --create-namespace \
  -f /app/tailscale-operator/values.yaml \
  -f /app/tailscale-operator/values-apiserver-proxy.yaml \
  --wait
```
