#!/usr/bin/env bash


set -euo pipefail

NAMESPACE="${1:?Usage: $0 <namespace> <revision e.g. 1-28>}"
REVISION="${2:?Usage: $0 <namespace> <revision e.g. 1-28>}"

echo "==> Current waypoints in the mesh"
istioctl waypoint list -A || true

echo "==> Applying waypoint for '${NAMESPACE}' on revision ${REVISION}"
istioctl waypoint apply \
  -n "${NAMESPACE}" \
  --revision "${REVISION}"

echo "==> Relabeling namespace '${NAMESPACE}' to revision ${REVISION}"
kubectl label namespace "${NAMESPACE}" istio.io/rev="${REVISION}" --overwrite

echo "==> Restarting deployments in '${NAMESPACE}' so pods pick up the new revision"
kubectl rollout restart deployment -n "${NAMESPACE}"

echo "==> Waiting for rollout to finish"
kubectl rollout status deployment -n "${NAMESPACE}" --timeout=5m

echo "==> Verifying proxy status"
istioctl proxy-status | grep "${NAMESPACE}" || istioctl proxy-status

echo "==> Done. '${NAMESPACE}' is now on revision ${REVISION}."
echo "    If anything looks wrong, roll back with:"
echo "    $0 ${NAMESPACE} <previous-revision>"
