<div align="center">

# Istio Ambient Mesh: istioctl → Helm Migration

### A production-tested, zero-downtime upgrade from Istio 1.25 to 1.28

<img src="assets/medium-cover-square.png" alt="Istio Ambient Mesh Upgrade — istioctl to Helm" width="320"/>

![Istio](https://img.shields.io/badge/Istio-1.25%20→%201.28-blueviolet)
![Ambient Mesh](https://img.shields.io/badge/Mesh%20Mode-Ambient-green)
![Helm](https://img.shields.io/badge/Managed%20by-Helm-0F1689)
![Kubernetes](https://img.shields.io/badge/Kubernetes-EKS-326CE5)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

</div>

---

## What this is

A revision-based runbook — and a set of runnable scripts — for migrating an Istio ambient mesh control plane from `istioctl`-managed to fully Helm-managed, upgrading versions in the process with zero mixed installs and minimal downtime.

Most Istio upgrade guides assume you're already on Helm. This one covers the harder, more common real-world starting point: a cluster where Istio was originally installed with `istioctl install`, and you need to move ownership to Helm *and* upgrade versions at the same time — without breaking anything that's currently serving traffic.

The core pattern — **parallel control planes via Helm revisions, adopt-then-upgrade for legacy resources, namespace-by-namespace cutover** — isn't specific to one version pair. It's demonstrated here on a real 1.25 → 1.28 migration, but applies to any Istio upgrade path with minor version-specific tweaks.

## Why this approach

- **Parallel control planes.** Old and new `istiod` run side by side. A bug in the new version doesn't touch namespaces still on the old one.
- **Namespace-by-namespace cutover.** Migrate one team's namespace, watch it, then move to the next.
- **A real rollback path.** Because the old control plane isn't deleted until the very end, rolling back is a label change — not a redeploy.
- **No mass pod restarts.** Ambient mode means ztunnel picks up namespace label changes without touching every pod — a key difference from sidecar-mode upgrades.

## Repo structure

```
.
├── README.md
├── LICENSE
├── docs/
│   ├── architecture-and-strategy.md          ← why revision-based upgrades, architecture diagrams
│   ├── migration-walkthrough.md              ← step-by-step guide, references the scripts below
│   ├── troubleshooting.md                    ← failure signatures, best practices, sidecar vs ambient
│   └── faq.md                                ← FAQ, references, further reading
├── scripts/
│   ├── 01-precheck.sh                           ← cluster compatibility check + Helm repo setup
│   ├── 02-adopt-base-resources.sh               ← adopt istioctl-created RBAC/webhooks into Helm
│   ├── 03-install-control-plane.sh              ← install istio-base + new revisioned istiod
│   ├── 04-adopt-upgrade-ztunnel.sh               ← adopt + upgrade the ztunnel DaemonSet
│   ├── 05-migrate-namespace.sh                  ← migrate (or roll back) a single namespace
│   ├── 06-adopt-upgrade-cni.sh                  ← adopt + upgrade the Istio CNI plugin
│   ├── 07-adopt-upgrade-ingressgateway.sh       ← adopt + upgrade the ingress gateway in place
│   └── 08-cleanup-legacy-control-plane.sh       ← remove the old control plane (requires --confirm)
└── assets/
    └── *.png                                    ← architecture diagrams
```

## Quickstart

```bash
git clone https://github.com/<your-username>/istio-ambient-mesh-upgrade.git
cd istio-ambient-mesh-upgrade
chmod +x scripts/*.sh

# 1. Validate cluster compatibility
./scripts/01-precheck.sh

# 2. Adopt existing istioctl-managed resources into Helm
./scripts/02-adopt-base-resources.sh istio-base istio-system

# 3. Install the new revisioned control plane (parallel to the old one)
./scripts/03-install-control-plane.sh 1-28 istio-system

# 4. Adopt and upgrade ztunnel
./scripts/04-adopt-upgrade-ztunnel.sh 1-28 istio-system

# 5. Migrate namespaces one at a time — repeat per namespace
./scripts/05-migrate-namespace.sh <your-namespace> 1-28

# 6. Adopt and upgrade the CNI plugin and ingress gateway
./scripts/06-adopt-upgrade-cni.sh istio-system
./scripts/07-adopt-upgrade-ingressgateway.sh 1-28 istio-ingress

# 7. Only once everything is confirmed healthy — clean up the legacy control plane
./scripts/08-cleanup-legacy-control-plane.sh 1-28 --confirm
```

Read [`docs/02-migration-walkthrough.md`](docs/02-migration-walkthrough.md) before running any of this against a real cluster — the scripts are the *how*, the docs explain the *why* and what to verify at each step.

## Documentation

| Doc | Covers |
|---|---|
| [Architecture and Strategy](docs/01-architecture-and-strategy.md) | Why revision-based upgrades, ambient mesh architecture, starting state |
| [Migration Walkthrough](docs/02-migration-walkthrough.md) | Step-by-step guide, what actually happens under the hood, rollback |
| [Troubleshooting](docs/03-troubleshooting.md) | Common failure signatures, best practices, sidecar vs. ambient trade-offs |
| [FAQ](docs/04-faq.md) | Common questions, references, further reading |

## Requirements

- Kubernetes cluster (tested on EKS 1.32; works on any conformant distribution)
- `kubectl`, `helm` (v3), and `istioctl` installed and pointed at your cluster
- Existing Istio installation in ambient mode, originally installed via `istioctl install`

## Contributing

Found a version-specific gotcha, a chart value that changed, or a step that didn't work for your cluster? Issues and PRs are welcome — this is meant to stay a living reference, not a one-time snapshot.

## License

Released under the [MIT License](LICENSE) — use it, adapt it, and share it freely.

---

<div align="center">

*If this saved you time, a ⭐ on the repo helps other engineers find it.*

`istio` `kubernetes` `service-mesh` `devops` `cloud-native` `helm` `ambient-mesh`

</div>
