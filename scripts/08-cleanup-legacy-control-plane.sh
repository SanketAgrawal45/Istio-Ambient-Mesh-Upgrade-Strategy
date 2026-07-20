#!/usr/bin/env bash


set -euo pipefail

REVISION="${1:?Usage: $0 <new-revision e.g. 1-28> --confirm}"
CONFIRM_FLAG="${2:-}"
NAMESPACE="istio-system"

if [[ "${CONFIRM_FLAG}" != "--confirm" ]]; then
  echo "Refusing to run without explicit confirmation."
  echo "This deletes the legacy istiod control plane and its webhooks."
  echo "Only proceed once every namespace/waypoint/ztunnel/CNI/ingress is confirmed healthy on revision ${REVISION}."
  echo ""
  echo "Re-run as: $0 ${REVISION} --confirm"
  exit 1
fi

echo "==> Deleting legacy (non-revisioned) istiod deployment, service, HPA"
kubectl delete deployment istiod -n "${NAMESPACE}" --ignore-not-found
kubectl delete service istiod -n "${NAMESPACE}" --ignore-not-found
kubectl delete hpa istiod -n "${NAMESPACE}" --ignore-not-found

echo "==> Deleting legacy webhook configurations"
kubectl delete validatingwebhookconfiguration istiod-default-validator --ignore-not-found
kubectl delete mutatingwebhookconfiguration istio-sidecar-injector --ignore-not-found

echo "==> Repointing PodDisruptionBudget selector to istiod-${REVISION} pods"
kubectl patch pdb istiod -n "${NAMESPACE}" --type='json' \
  -p='[ { "op": "remove", "path": "/spec/selector/matchLabels/istio" } ]' || true

kubectl patch pdb istiod -n "${NAMESPACE}" --type='merge' -p "
{
  \"spec\": {
    \"selector\": {
      \"matchLabels\": {
        \"app\": \"istiod\",
        \"istio.io/rev\": \"${REVISION}\"
      }
    }
  }
}
"

echo "==> Cleanup complete. istiod-${REVISION} and its webhooks remain active."
