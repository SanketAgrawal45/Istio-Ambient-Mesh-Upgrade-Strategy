# FAQ

**Does ambient mode require restarting every pod during an upgrade?**
No — that's the main advantage over sidecar mode. ztunnel picks up namespace label changes without pod restarts for L4 traffic. Waypoint-routed L7 traffic and some revision-specific behavior still benefit from a `kubectl rollout restart`, though.

**What happens if I delete the old istiod before confirming all namespaces moved?**
You lose your rollback path. Any namespace still pinned to the old revision will lose its control plane connection, which typically shows up as `STALE` proxies and eventually stale config being served to those workloads. Always confirm with `istioctl proxy-status` first.

**Do I need a waypoint for every namespace in ambient mode?**
Only if that namespace needs L7 policy, routing, or auth. Namespaces that only need mTLS and workload identity can run on ztunnel alone, without a waypoint at all.

**Is this upgrade path specific to EKS?**
No — the Helm and `istioctl` commands are the same on any conformant Kubernetes distribution. EKS-specific details here are limited to the underlying Kubernetes version compatibility, which `istioctl x precheck` will flag regardless of where you're running.

---

⬅ [Back: Troubleshooting](03-troubleshooting.md) &nbsp;|&nbsp; ⬆ [Back to README](../README.md)
