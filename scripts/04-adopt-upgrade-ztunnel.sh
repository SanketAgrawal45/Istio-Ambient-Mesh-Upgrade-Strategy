#!/usr/bin/env bash


set -euo pipefail

REVISION="${1:?Usage: $0 <revision e.g. 1-28> [namespace]}"
NAMESPACE="${2:-istio-system}"
RELEASE_NAME="ztunnel-${REVISION}"

echo "==> Adopting existing ztunnel resources into Helm release '${RELEASE_NAME}'"

kubectl annotate serviceaccount ztunnel \
  -n "${NAMESPACE}" \
  meta.helm.sh/release-name="${RELEASE_NAME}" \
  meta.helm.sh/release-namespace="${NAMESPACE}" \
  --overwrite
kubectl label serviceaccount ztunnel \
  -n "${NAMESPACE}" \
  app.kubernetes.io/managed-by=Helm \
  --overwrite

kubectl annotate daemonset ztunnel \
  -n "${NAMESPACE}" \
  meta.helm.sh/release-name="${RELEASE_NAME}" \
  meta.helm.sh/release-namespace="${NAMESPACE}" \
  --overwrite
kubectl label daemonset ztunnel \
  -n "${NAMESPACE}" \
  app.kubernetes.io/managed-by=Helm \
  --overwrite

echo "==> Upgrading ztunnel via Helm to revision ${REVISION}"
helm upgrade --install "${RELEASE_NAME}" istio/ztunnel \
  -n "${NAMESPACE}" \
  --set revision="${REVISION}" \
  --wait

echo "==> Verifying rollout"
kubectl get ds -n "${NAMESPACE}" | grep ztunnel
kubectl get pods -n "${NAMESPACE}" | grep ztunnel

echo "==> Confirming proxy health before any namespace migration"
istioctl ztunnel-config all
istioctl proxy-status
