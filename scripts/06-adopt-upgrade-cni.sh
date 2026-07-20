#!/usr/bin/env bash


set -euo pipefail

NAMESPACE="${1:-istio-system}"
RELEASE_NAME="istio-cni"

echo "==> Adopting istio-cni ServiceAccount and DaemonSet"
kubectl label serviceaccount istio-cni \
  -n "${NAMESPACE}" \
  app.kubernetes.io/managed-by=Helm --overwrite
kubectl annotate serviceaccount istio-cni \
  -n "${NAMESPACE}" \
  meta.helm.sh/release-name="${RELEASE_NAME}" \
  meta.helm.sh/release-namespace="${NAMESPACE}" --overwrite

kubectl label daemonset istio-cni-node \
  -n "${NAMESPACE}" \
  app.kubernetes.io/managed-by=Helm --overwrite
kubectl annotate daemonset istio-cni-node \
  -n "${NAMESPACE}" \
  meta.helm.sh/release-name="${RELEASE_NAME}" \
  meta.helm.sh/release-namespace="${NAMESPACE}" --overwrite

echo "==> Adopting istio-cni-config ConfigMap"
kubectl label configmap istio-cni-config \
  -n "${NAMESPACE}" \
  app.kubernetes.io/managed-by=Helm --overwrite
kubectl annotate configmap istio-cni-config \
  -n "${NAMESPACE}" \
  meta.helm.sh/release-name="${RELEASE_NAME}" \
  meta.helm.sh/release-namespace="${NAMESPACE}" --overwrite

echo "==> Adopting CNI ClusterRoles and ClusterRoleBindings"
for r in \
  clusterrole/istio-cni \
  clusterrole/istio-cni-ambient \
  clusterrole/istio-cni-repair-role \
  clusterrolebinding/istio-cni \
  clusterrolebinding/istio-cni-ambient \
  clusterrolebinding/istio-cni-repair-rolebinding
do
  kubectl annotate "$r" \
    meta.helm.sh/release-name="${RELEASE_NAME}" \
    meta.helm.sh/release-namespace="${NAMESPACE}" \
    --overwrite
  kubectl label "$r" \
    app.kubernetes.io/managed-by=Helm \
    --overwrite
done

echo "==> Installing/upgrading istio-cni with ambient profile"
helm upgrade --install istio-cni istio/cni \
  -n "${NAMESPACE}" \
  --set profile=ambient \
  --wait

echo "==> Restarting ztunnel to pick up refreshed CNI wiring"
kubectl rollout restart daemonset ztunnel -n "${NAMESPACE}"

echo "==> Verifying"
kubectl get ds -n "${NAMESPACE}" | grep istio-cni
kubectl get sa,cm -n "${NAMESPACE}" | grep istio-cni
helm status istio-cni -n "${NAMESPACE}"
