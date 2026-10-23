# Local registry over the tailnet

## Objective

When fleets connect over Tailscale, Streamtime's local registry (`registry:5000`)
is still reached through a public registry tunnel (Cloudflare). A
`registry_over_tailnet` switch in the Tailscale settings puts the registry on the
same private path. Fleets then pull charts and images from the Streamtime tailnet
address through the gateway, with no rate limit and no Cloudflare.

## In scope

- The `tailscale_registry_over_tailnet` setting:
  - saved with the Tailscale settings;
  - reported by the tunnel config;
  - cleared by setup reset.
- The registry rewrite (`resolve_registry_tunnel_host`) becomes tailnet-aware:
  `<streamtime tailnet address>:8443` when the switch is on. Every reader goes
  through it, and the tunnel config exposes it as `registry_host`.
- Kong's registry route (`/v2`, no rate limit) also matches the tailnet
  address. A disabled or changed address is removed.
- In-cluster chart pulls (the agent) reach the address through the existing
  CoreDNS rewrite and egress proxy. The agent trusts the gateway certificate
  (`gatewayCA` → `SSL_CERT_DIR`).
- Node image pulls run in the node's container runtime, which can use neither
  cluster DNS nor the tailnet. A `registryMirror` DaemonSet in the bundled
  Tailscale chart does two things on each node:
  - maps the address to the egress proxy pod in `/etc/hosts`;
  - writes containerd `certs.d/<host:port>/hosts.toml` with the gateway
    certificate.
  It refreshes these every 30 seconds and removes them when stopped.
- The orchestrator pulls charts from `registry:5000` locally when the target is
  the tailnet address, because it cannot reach its own host's tailnet address.
  Images use the tailnet address.
- Manual install: the bootstrap config returns `registry_host`,
  `registry_over_tailnet` and `registry_ca_pem`.
  - The instructions rewrite local registry addresses to it, as automatic
    installs do.
  - On the tailnet they add `--ca-file gateway-ca.crt`, show the certificate,
    and say to run the commands from a machine on the tailnet.
  - Incomplete settings return a plain-language 400, before any API key is
    created.
- UI:
  - the switch, which hides the registry tunnel field when on;
  - the Tailscale setup steps and tag settings are collapsible.

## Out of scope

- Registries other than Streamtime's local one; public images are unchanged.
- The in-fleet pull-through cache (roadmap step 5).
- Container runtimes other than containerd with `config_path`. The DaemonSet
  logs a warning there.

## Approach

1. Setting, rewrite resolver, `registry_host` and `tailnet_registry_host` in
   the tunnel config and agent config.
2. Kong overlay: registry route hosts.
3. Tailscale chart: the `registryMirror` DaemonSet. Agent chart: `gatewayCA`.
   Backend: send both when the switch is on.
4. Orchestrator: transport mapping, and the effective host for the agent's
   `streamtime.uri`.
5. Prove it live on k3-badami with the Cloudflare registry tunnel stopped:
   - Kong serves `/v2` on the tailnet address;
   - the agent image and charts pull over the tailnet;
   - node `/etc/hosts` and `hosts.toml` are present, and removed when the
     DaemonSet goes.

## Deviations

_None._

- **2026-10-07 — node mirror supports CRI-O and RKE2; no stray directories.**
  The mirror trusted the gateway certificate only in containerd's `certs.d`, so
  on CRI-O nodes (OKE, OpenShift) pulls from the tailnet registry failed TLS.
  It now also writes `/etc/containers/certs.d/<host:port>/ca.crt` on nodes with
  `/etc/crio` (CRI-O reads it on each pull), adds RKE2's containerd path, logs
  once which runtime it found (or a warning that pulls will fail), mounts `/etc`
  plus `registryMirror.hostRoots` (`/var/lib/rancher`) instead of creating a
  containerd directory per candidate path on every node, and schedules on Linux
  nodes only. Not handled by a DaemonSet: immutable nodes (Bottlerocket, Talos),
  places a privileged DaemonSet cannot run (GKE Autopilot, EKS Fargate, PSA
  baseline/restricted), and managed nodes where containerd ignores `certs.d`.
  Open checks: EKS AL2023 with containerd 2.1 (transfer service),
  GKE COS (`config_path`; GKE prefers `registryHosts` node config), AKS and
  DOKS (`config_path`).
