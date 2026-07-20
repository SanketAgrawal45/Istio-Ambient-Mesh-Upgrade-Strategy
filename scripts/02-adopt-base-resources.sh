#!/usr/bin/env bash


set -euo pipefail

RELEASE_NAME="${1:-istio-base}"
NAMESPACE="${2:-istio-system}"

echo "==> Adopting cluster-wide resources into Helm release '${RELEASE_NAME}' (namespace: ${NAMESPACE})"

# ServiceAccount
kubectl annotate serviceaccount istio-reader-service-account \
  -n "${NAMESPACE}" \
  meta.helm.sh/release-name="${RELEASE_NAME}" \
  meta.helm.sh/release-namespace="${NAMESPACE}" --overwrite

kubectl label serviceaccount istio-reader-service-account \
  -n "${NAMESPACE}" \
  app.kubernetes.io/managed-by=Helm --overwrite

# ClusterRoles
for cr in $(kubectl get clusterrole | grep istio | awk '{print $1}'); do
  kubectl label clusterrole "$cr" app.kubernetes.io/managed-by=Helm --overwrite
  kubectl annotate clusterrole "$cr" \
    meta.helm.sh/release-name="${RELEASE_NAME}" \
    meta.helm.sh/release-namespace="${NAMESPACE}" --overwrite
done

# ClusterRoleBindings
for crb in $(kubectl get clusterrolebinding | grep istio | awk '{print $1}'); do
  kubectl label clusterrolebinding "$crb" app.kubernetes.io/managed-by=Helm --overwrite
  kubectl annotate clusterrolebinding "$crb" \
    meta.helm.sh/release-name="${RELEASE_NAME}" \
    meta.helm.sh/release-namespace="${NAMESPACE}" --overwrite
done

# ValidatingWebhookConfigurations
for wh in $(kubectl get validatingwebhookconfiguration | grep istio | awk '{print $1}'); do
  kubectl label validatingwebhookconfiguration "$wh" \
    app.kubernetes.io/managed-by=Helm --overwrite
  kubectl annotate validatingwebhookconfiguration "$wh" \
    meta.helm.sh/release-name="${RELEASE_NAME}" \
    meta.helm.sh/release-namespace="${NAMESPACE}" --overwrite
done

# MutatingWebhookConfigurations
for wh in $(kubectl get mutatingwebhookconfiguration | grep istio | awk '{print $1}'); do
  kubectl label mutatingwebhookconfiguration "$wh" \
    app.kubernetes.io/managed-by=Helm --overwrite
  kubectl annotate mutatingwebhookconfiguration "$wh" \
    meta.helm.sh/release-name="${RELEASE_NAME}" \
    meta.helm.sh/release-namespace="${NAMESPACE}" --overwrite
done

# CustomResourceDefinitions
for crd in $(kubectl get crds -l chart=istio -o name && \
             kubectl get crds -l app.kubernetes.io/part-of=istio -o name); do
  kubectl label "$crd" "app.kubernetes.io/managed-by=Helm" --overwrite
  kubectl annotate "$crd" \
    "meta.helm.sh/release-name=${RELEASE_NAME}" \
    "meta.helm.sh/release-namespace=${NAMESPACE}" --overwrite
done

echo "==> Adoption complete. Verify release name matches what you'll use in 'helm upgrade --install' next."
