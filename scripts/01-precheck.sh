#!/usr/bin/env bash

set -euo pipefail

echo "==> Running istioctl precheck"
istioctl x precheck

echo "==> Current istioctl / control plane versions"
istioctl version

echo "==> Adding and refreshing the Istio Helm repository"
helm repo add istio https://istio-release.storage.googleapis.com/charts 2>/dev/null || true
helm repo update istio

echo "==> Available Istio charts"
helm search repo istio

echo "==> Precheck complete. Confirm the control plane version above matches your expected starting version before continuing."
