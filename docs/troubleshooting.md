# Troubleshooting, Best Practices, and Trade-offs

## Quick Troubleshooting Reference

A few failure signatures come up often enough during this kind of migration that it's worth keeping a mental checklist:

| Symptom | Likely cause | Where to look |
|---|---|---|
| `proxy-status` shows `STALE` for a proxy | Proxy lost its xDS connection, or is pointed at a revision that isn't healthy | `istioctl proxy-status`, then check the relevant `istiod` pod logs |
| Workload traffic breaks right after relabeling a namespace | Pods never restarted, so waypoint/L7 routing still resolved against old config | `kubectl rollout restart deployment -n <namespace>` |
| `helm upgrade` fails with an ownership error | Resource wasn't adopted (missing `meta.helm.sh` annotations) before the Helm install | `kubectl get <resource> -o yaml \| grep meta.helm.sh` |
| mTLS handshake failures between two migrated workloads | One side's ztunnel hasn't received updated identity/cert config yet | `istioctl ztunnel-config all`, check ztunnel logs on the relevant node |
| Ingress traffic drops during the gateway upgrade | HPA or readiness probes not accounting for the rolling update window | `kubectl get deploy,hpa -n istio-ingress`, watch pod readiness during rollout |
| New namespace migration doesn't seem to take effect | Namespace label set, but a waypoint wasn't applied for the new revision | `istioctl waypoint list -A` — confirm the waypoint itself is on the new revision |

If none of these match what you're seeing, `istioctl analyze` is worth running before digging into raw Envoy config — it catches a surprising number of misconfigurations that would otherwise take a while to spot manually.

## Common Mistakes

- **Mixing install methods.** If a resource was created by `istioctl`, don't try to `helm upgrade` it without adopting it first. Helm's three-way merge doesn't know about resources it doesn't own, and you'll either get an error or a silent duplicate.
- **Skipping the rollout restart after relabeling a namespace.** The label change alone won't move already-running pods onto the new control plane's config for every code path — always pair it with `kubectl rollout restart`.
- **Deleting the old control plane too early.** Give namespaces real production traffic time on the new revision before tearing down the fallback. The whole value of revision-based migration evaporates if you delete your rollback path on day one.
- **Forgetting the PDB selector cleanup.** It won't break anything immediately, but it will confuse whoever's on call later.

## Security and Scalability Notes

Nothing about this migration changes your mTLS posture — ztunnel keeps enforcing L4 identity throughout, and STRICT mTLS policies apply to both revisions independently. Just don't leave a namespace half-migrated (some workloads on the old revision, some on the new) for longer than necessary; verify `proxy-status` after every namespace move rather than batching several before checking.

ztunnel being a DaemonSet means its resource footprint scales with node count, not pod count — one of ambient mode's real advantages over sidecars at high pod density. Waypoints, on the other hand, do scale with L7 traffic volume per namespace — keep an eye on waypoint CPU/memory if you're migrating a namespace with heavy east-west traffic.

## Sidecar vs. Ambient: A Quick Comparison

If you're still deciding whether ambient mode is worth this migration effort at all, here's the trade-off in short form:

| | Sidecar Mode | Ambient Mode |
|---|---|---|
| Per-pod overhead | One Envoy sidecar per pod | None — ztunnel runs per node |
| Pod restart on mesh join | Required (injection) | Not required for L4 |
| L7 policy | Always available per pod | Requires an explicit waypoint |
| Upgrade granularity | Namespace, via injection | Namespace, without pod restarts for L4 |
| Resource footprint | Scales with pod count | Scales mostly with node count |

Neither is strictly better — if every namespace in your mesh needs L7 policy everywhere, ambient's waypoint model adds a layer of components you have to manage. If most of your traffic only needs mTLS and identity, ambient's overhead savings are substantial.

---

⬅ [Back: Migration Walkthrough](02-migration-walkthrough.md) &nbsp;|&nbsp; ➡ [Next: FAQ](04-faq.md)
