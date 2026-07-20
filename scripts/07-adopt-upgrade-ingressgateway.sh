#!/usr/bin/env bash


set -euo pipefail

REVISION="${1:?Usage: $0 <revision e.g. 1-28> [ingress-namespace]}"
NAMESPACE="${2:-istio-ingress}"
RELEASE_NAME="istio-ingressgateway"

echo "==> Adopting existing ingress gateway resources in '${NAMESPACE}'"

kubectl annotate deployment "${RELEASE_NAME}" -n "${NAMESPACE}" \
  meta.helm.sh/release-name="${RELEASE_NAME}" \
  meta.helm.sh/release-namespace="${NAMESPACE}" --overwrite
kubectl label deployment "${RELEASE_NAME}" -n "${NAMESPACE}" \
  app.kubernetes.io/managed-by=Helm --overwrite

kubectl annotate service "${RELEASE_NAME}" -n "${NAMESPACE}" \
  meta.helm.sh/release-name="${RELEASE_NAME}" \
  meta.helm.sh/release-namespace="${NAMESPACE}" --overwrite
kubectl label service "${RELEASE_NAME}" -n "${NAMESPACE}" \
  app.kubernetes.io/managed-by=Helm --overwrite

kubectl annotate sa "${RELEASE_NAME}-service-account" -n "${NAMESPACE}" \
  meta.helm.sh/release-name="${RELEASE_NAME}" \
  meta.helm.sh/release-namespace="${NAMESPACE}" --overwrite
kubectl label sa "${RELEASE_NAME}-service-account" -n "${NAMESPACE}" \
  app.kubernetes.io/managed-by=Helm --overwrite

kubectl annotate hpa "${RELEASE_NAME}" -n "${NAMESPACE}" \
  meta.helm.sh/release-name="${RELEASE_NAME}" \
  meta.helm.sh/release-namespace="${NAMESPACE}" --overwrite
kubectl label hpa "${RELEASE_NAME}" -n "${NAMESPACE}" \
  app.kubernetes.io/managed-by=Helm --overwrite

echo "==> Upgrading ingress gateway to revision ${REVISION}"
helm upgrade --install "${RELEASE_NAME}" istio/gateway \
  -n "${NAMESPACE}" \
  --set revision="${REVISION}" \
  --set service.type=NodePort \
  --wait \
  --timeout 10m

echo "==> Verifying"
helm status "${RELEASE_NAME}" -n "${NAMESPACE}"
kubectl get deploy,svc,hpa -n "${NAMESPACE}" | grep "${RELEASE_NAME}"

echo "==> Also remember to label the ingress namespace itself once workloads are confirmed healthy:"
echo "    kubectl label namespace ${NAMESPACE} istio.io/rev=${REVISION} --overwrite"
