#!/usr/bin/env bash


set -euo pipefail

REVISION="${1:?Usage: $0 <revision e.g. 1-28> [namespace]}"
NAMESPACE="${2:-istio-system}"

echo "==> Installing/upgrading istio-base (CRDs)"
helm upgrade --install istio-base istio/base \
  -n "${NAMESPACE}" \
  --wait

helm status istio-base -n "${NAMESPACE}"

echo "==> Installing revisioned istiod: istiod-${REVISION}"
helm upgrade --install "istiod-${REVISION}" istio/istiod \
  -n "${NAMESPACE}" \
  --set revision="${REVISION}" \
  --set profile=ambient \
  --wait

helm status "istiod-${REVISION}" -n "${NAMESPACE}"

echo "==> Control plane installed. You should now have two istiod deployments running in ${NAMESPACE}."
kubectl get deploy -n "${NAMESPACE}" | grep istiod
