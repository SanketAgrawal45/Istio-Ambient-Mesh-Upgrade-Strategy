# Migration Walkthrough

Each step below corresponds to a runnable script in [`/scripts`](../scripts). The commentary here explains the *why*; the scripts themselves are the *how* — read both, don't just run the scripts blind.

## Step 1 — Pre-Upgrade Checks

Run the built-in compatibility check before anything else. It's fast and it catches version-skew issues you don't want to discover halfway through a control plane swap.

```bash
./scripts/01-precheck.sh
```

This runs `istioctl x precheck` (cluster compatibility validation) and `istioctl version` (confirms exactly what you're running client-side and control-plane-side), then adds and refreshes the official Istio Helm repository. Double-check the reported control plane version matches your expected starting version before continuing — a stale local `istioctl` binary pointing at the wrong context is an easy way to waste an afternoon.

## Step 2 — Adopting Existing Resources into Helm

This is the step people skip and then regret. If Istio was installed via `istioctl install`, the cluster-wide RBAC and webhook resources have no Helm ownership metadata. If you run `helm upgrade --install` against them without adopting them first, Helm will refuse to touch them — or worse, silently create duplicates.

```bash
./scripts/02-adopt-base-resources.sh istio-base istio-system
```

This labels and annotates every relevant ServiceAccount, ClusterRole, ClusterRoleBinding, webhook configuration, and CRD so Helm recognizes them as its own. **This is a one-time operation** — double-check the release name matches what you intend to use going forward, since Helm's ownership check is based on this exact metadata.

## Step 3 — Install `istio-base` and the New Revisioned Istiod

```bash
./scripts/03-install-control-plane.sh 1-28 istio-system
```

This installs/upgrades the `istio-base` chart (CRDs everything else depends on), then deploys a fully independent `istiod-1-28` — deployment, service, and webhook set — alongside the legacy `istiod`, configured for the ambient profile. Nothing routes through it yet; that's intentional. You should end up with two `istiod` deployments running side by side.

## Step 4 — Adopt and Upgrade ztunnel

```bash
./scripts/04-adopt-upgrade-ztunnel.sh 1-28 istio-system
```

Same adoption pattern as Step 2, applied to the ztunnel DaemonSet, followed by the Helm upgrade itself. Because ztunnel is a DaemonSet, this briefly touches every node as a rolling update — not a hard cutover, but worth watching latency dashboards during this step regardless. The script finishes by confirming proxy health with `istioctl proxy-status` before you migrate any traffic.

## Step 5 — Migrate Namespaces to the New Revision

This is the actual cutover, and it's deliberately granular — one namespace at a time.

```bash
./scripts/05-migrate-namespace.sh checkout-staging 1-28
```

This applies a waypoint on the target revision, relabels the namespace, restarts its deployments so pods pick up the new config, and verifies with `istioctl proxy-status`. Repeat this per namespace, watching each one before moving to the next — there's no rule that says you have to migrate everything in one sitting.

Don't forget the ingress namespace itself:

```bash
kubectl label namespace istio-ingress istio.io/rev=1-28 --overwrite
```

### What actually happens when you relabel a namespace

"Just add a label" undersells the mechanics involved:

1. **istiod is watching, not polling.** Both control planes run a Kubernetes controller watching namespaces, pods, and Istio CRDs via the API server's watch mechanism — the label change is seen almost immediately.
2. **Ownership is decided per-resource, per-revision.** Each `istiod` only generates and pushes config for workloads whose effective revision matches its own. The two control planes aren't coordinating; they're independently deciding what's theirs.
3. **xDS pushes the new config down.** Istio talks to ztunnel and waypoint proxies over the xDS protocol (CDS, LDS, RDS, EDS). Once the new revision's `istiod` decides a workload belongs to it, it pushes updated config over the existing xDS connection.
4. **ztunnel doesn't need a restart for this.** It holds a persistent xDS connection and updates its view of the world in place — this is why ambient migrations don't require touching every pod just to move mTLS/identity to the new control plane.
5. **The rollout restart matters at the pod level.** `kubectl rollout restart` doesn't talk to Istio directly — it replaces pods, and new pods resolve their revision fresh from the moment they're scheduled. This is why L7-routed traffic through a waypoint benefits from the restart even though raw L4 traffic through ztunnel technically didn't need it.

If a workload looks "stuck" on the old revision after relabeling: check whether the pod was ever restarted, and check `istioctl proxy-status` for which `istiod` instance that specific proxy is actually connected to — not just what the namespace label says.

### Rolling back a namespace

Because the old control plane stays alive throughout the migration, rollback is symmetrical with the cutover — the same script, run in reverse:

```bash
./scripts/05-migrate-namespace.sh checkout-staging 1-25
```

This only works cleanly while the legacy `istiod`, its webhooks, and the old ztunnel/waypoint resources are still in place — which is exactly why cleanup (Step 7) should be the very last thing you do.

## Step 6 — Istio CNI and Ingress Gateway

The CNI plugin redirects pod traffic to ztunnel at the node level and the ingress gateway is your north-south entry point — both need the same adopt-then-upgrade treatment as everything else.

```bash
./scripts/06-adopt-upgrade-cni.sh istio-system
./scripts/07-adopt-upgrade-ingressgateway.sh 1-28 istio-ingress
```

The ingress gateway script **does not create a new gateway or endpoint** — it adopts the existing `istio-ingressgateway` resources (Deployment, Service, ServiceAccount, HPA) and upgrades them in place to the new revision, so your ALB target group, DNS, and TLS setup don't need to change at all.

## Step 7 — Cleaning Up the Old Control Plane

Only do this after every namespace, waypoint, ztunnel instance, the CNI, and ingress are all confirmed running on the new revision. This is not a step to rush — give it at least a full business cycle of observation before you delete anything.

```bash
./scripts/08-cleanup-legacy-control-plane.sh 1-28 --confirm
```

The script requires the explicit `--confirm` flag on purpose — it deletes the legacy `istiod` deployment/service/HPA and the old webhook configurations, then repoints the `istiod` PodDisruptionBudget's selector at the new revision's pods (an easy-to-miss detail — a dangling PDB selector becomes an orphaned object that shows up as a confusing alert weeks later during unrelated node maintenance).

---

⬅ [Back: Architecture and Strategy](01-architecture-and-strategy.md) &nbsp;|&nbsp; ➡ [Next: Troubleshooting](03-troubleshooting.md)
