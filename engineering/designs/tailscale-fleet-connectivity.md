# Tailscale fleet connectivity (bootstrap, egress, private ingress)

## Objective

When the organization's tunnel provider is Tailscale (see
`plans/tailscale-tunnel-and-gateway-tls.md`), every new fleet joins the tailnet
during bootstrap and is connected in both directions:

- **Fleet → Streamtime.** The agent and fleet workloads reach the Streamtime
  gateway by its real tailnet name (`<host>.<tailnet>.ts.net:8443`), so TLS
  server names and Kong's SNI routes keep working.
- **Tailnet → fleet.** The fleet's shared-services ingress is private on the
  tailnet: the Kong gateway (consoles, Prometheus, Loki, Alertmanager, OpenCost,
  OTel, Kafka admin) gets a tailnet address, and the fleet's DNS records point at
  it instead of a public load balancer.

Ships in the same PR as the tunnel/onboarding work (#1393), by user decision.

## In scope

1. `charts/streamtime-tailscale` committed and published like other in-repo charts.
2. DNS for fleet → Streamtime works on standard CoreDNS **and** k3s/AKS
   (`coredns-custom`), chosen automatically.
3. The orchestrator installs the chart **before the agent** in
   `InstallStreamtimeAgentWorkflow`, using the fleet kubeconfig, because the
   agent itself needs the tailnet to reach the orchestrator.
4. Kong gateway exposed on the tailnet through a `loadBalancerClass: tailscale`
   Service; the public Kong LoadBalancer is not created.
5. Teardown: the chart is uninstalled after the agent's own teardown, and the
   operator's tailnet device is deleted through the Tailscale API.

## Out of scope

- kube-dns clusters (GKE default). The chart fails the install with a clear
  message; Tailscale fleets on GKE need CoreDNS or Cloud DNS work later.
- Per-fleet opt-out. Every fleet uses Tailscale while the org provider is
  Tailscale. A toggle can come later without changing the chart.
- Kubernetes API over the tailnet (operator API server proxy stays off).
- Kafka client listeners. Envoy Gateway serves Kafka only (CFK, Strimzi,
  WarpStream) and is unchanged: Kafka stays on its own load balancers. Shared
  services go through Kong, which is what moves to the tailnet.
- Other workloads that create their own LoadBalancers.
- Migrating existing fleets: they pick this up on the next agent reinstall /
  bootstrap rerun; nothing is changed on them automatically.

## Design

### Chart: `streamtime-tailscale`

- Upstream `tailscale-operator` 1.102.4 (aliased `operator`), OAuth from values,
  `operatorConfig.hostname = <org>-<fleet>-operator` (≤ 63 chars, DNS-safe).
- Egress targets → `ExternalName` Services annotated `tailscale.com/tailnet-fqdn`.
  Bootstrap passes one target: the Streamtime host, port 8443.
- `dns.mode`:
  - `auto` (bootstrap default): a hook Job inspects `kube-system/coredns`.
    If the Corefile imports `/etc/coredns/custom/*.override` (k3s, AKS) it
    writes the `streamtime-tailnet.override` key into `kube-system/coredns-custom`;
    otherwise it inserts a marked block into the Corefile's `.:53` server block.
    No CoreDNS ConfigMap (kube-dns) → the Job fails with a plain message.
  - `k3s-custom`: rendered `coredns-custom` ConfigMap (existing behaviour).
  - `coredns`: Corefile patch only.
  - `none`.
- The Corefile patch is idempotent (`# BEGIN streamtime-tailscale` …
  `# END streamtime-tailscale`), re-applied on upgrade, removed by a
  `pre-delete` hook, and followed by a CoreDNS rollout restart.
- Rewrites are exact-name only: nothing else in cluster DNS changes.

### Bootstrap inputs (backend → orchestrator)

Every agent install (dispatch and the cloud providers' child workflows alike)
reads the backend's worker-only `/setup/orchestrator/agent-config/` through
`TokenActivities.get_streamtime_agent_helm_values`. That response gains a
`tailscale` block, read once at workflow start:

```
tailscale:
  enabled: true            # false unless the tunnel provider is Tailscale
  chart_version, tailnet_domain, client_id, client_secret,
  streamtime_hostname, gateway_port, operator_tags, proxy_tags
```

The orchestrator turns it into chart values (`workflows/tailscale_fleet.py`):
operator hostname `<org>-<fleet>-operator`, one egress target for the
Streamtime host, `dns.mode: auto`. The OAuth secret reaches the orchestrator
the same way the BYOO orchestrator API key already does (worker-JWT endpoint). `tailscale_chart_version` is a GlobalConfiguration key seeded
to the chart's version by a data migration; missing → the dispatch fails loudly.

### Ingress on the tailnet

- **Kong.** `GatewayConfiguration` cannot set `loadBalancerClass`. With
  `kongGatewayApi.tailnet.enabled`, `fleet-manager-infra-shared`:
  - renders the Kong proxy Service as `ClusterIP` (no public load balancer);
  - runs a hook Job that copies the operator-created `kong-gateway-proxy`
    Service's selector and ports into `kong-gateway-tailnet`
    (`type: LoadBalancer`, `loadBalancerClass: tailscale`,
    `tailscale.com/hostname: <org>-<fleet>-ingress`).
  The bootstrap's load balancer lookup reads `kong-gateway-tailnet`, so the
  fleet gateway IP (and every fleet DNS record) becomes the tailnet IP. The
  agent already treats `100.64.0.0/10` as routable.

### Teardown

After `TeardownFleetClusterWorkflow` (which still runs through the agent over
the tailnet), the orchestrator uninstalls `streamtime-tailscale` with the fleet
kubeconfig (best effort), then deletes the operator device by hostname through
the Tailscale API. Proxy devices are removed by the operator when their
Services go away during the agent teardown.

## Tests

- Chart: helm-unittest suites for `auto`, `coredns`, `k3s-custom`, `none`; the
  Job script tested against sample Corefiles (kind/kubeadm, EKS, k3s) for
  insert, idempotent re-insert, and removal.
- Backend: agent-config returns the block only for Tailscale; device-name
  sanitization; infra-shared values only for Tailscale.
- Orchestrator (`./run-tests.sh`): chart installed before the worker chart;
  skipped when absent; teardown order and device cleanup.
- Live: a kind fleet with Tailscale — agent connects over the tailnet, fleet
  hostnames resolve to tailnet IPs from a tailnet device.

## Deviations

- **2026-10-06 — STDNS webhook keeps ownership records; Kafka clusters reuse the fleet
  certificate** (user decision, risks reviewed first).
  - *Webhook.* external-dns cancelled a cluster's batch after ~15 s while the webhook spent
    ~7 STDNS calls per record, after the A records and before their TXT ownership records,
    so external-dns never retried or deleted them. `applyChanges` now writes ownership
    (TXT) records first, one call per record (`stdnsclient.PutRecord`: forceOverwrite POST,
    careful path only on 409), up to `WEBHOOK_CONCURRENCY` (4) at once, and attempts every
    record before reporting an error. The cert-manager DNS-01 solver keeps the
    purge-first upsert. STDNS errors keep their status and text when the body is not
    JSON. external-dns gets `webhook-provider-read-timeout=1m`,
    `webhook-provider-write-timeout=2m`. infra-shared annotates a shared hostname on its
    first route only (the TXT owner was rewritten every minute).
  - *Certificates.* Each Kafka chart issued the same `*.<domain>` certificate as the fleet,
    exhausting Let's Encrypt's 5-per-week limit for those names (wet-gerbil). With
    `certManager.fleetCertificateNamespace` (set by the backend when the cluster's domain
    is the fleet's) the CFK/Strimzi/Warpstream charts render a copy request (ConfigMap
    `tls-kafka-external-copy`, label `streamtime.ai/secret-copy`) instead of a Certificate.
    The operator's SecretCopyReconciler copies the fleet's `tls-kafka-external` into the
    namespace (owned by the request, re-read every 10 min for renewals; Secrets read
    uncached, ConfigMap cache limited to requests). Only Secrets labelled
    `streamtime.ai/shareable=true` are copied; infra-shared's Certificate sets it via
    `secretTemplate` (no reissue). The deploy no longer waits for a per-cluster
    Certificate when reusing. Trade-off accepted: one wildcard key across the fleet's
    Kafka namespaces (each per-cluster key was already valid for the whole domain).

- **2026-10-06 — Kafka deletes remove their own Streamtime DNS records.** For STDNS
  domains the records were left to external-dns, which deletes only records it owns by
  TXT ownership record, and none are being written. Deleted clusters' records stayed in
  the shared `streamti.me` zone until Cloudflare's record quota was hit (female-turtle's
  records outlived it; wet-gerbil's new ones were rejected with `81045 Record quota
  exceeded`). New `DELETE /organizations/{org}/base-domains/{domain}/dns-records/{name}/`
  (STDNS base domains only, names under the domain only; 204 when already gone). The CFK,
  Strimzi, Warpstream and Redpanda delete workflows call it (activity
  `delete_stdns_dns_record`, `workflows/dns_cleanup.py`, patch
  `kafka-delete-stdns-dns-records`) for the hostnames they already compute for Route53.
  Still open: why external-dns writes no ownership records (likely the STDNS webhook).

- **2026-10-05 — the GatewayClass nudge runs during the install.** Tailnet installs of
  fleet-manager-infra-shared hung (working-tyrannosaurus, global-rabbit): GatewayClass `kong`
  stayed `Accepted=False` because Helm applies it before its GatewayConfiguration and the
  Gateway Operator never re-checks. The nudge was a `post-install` hook, which runs only
  after `helm install --wait`, and that wait never ended because `kong-tailnet-apply` waits for
  Kong. It is now a regular Job (`kong-gatewayclass-accept-<revision>`) that waits for the
  GatewayConfiguration and re-annotates the class until it is accepted (Role to read the
  GatewayConfiguration added).

- **2026-10-05 — Kafka HTTP endpoints on the cluster's Envoy gateway; the tailnet is for
  shared services only** (user decision). On Tailscale fleets the shared Kong is
  tailnet-only, so Kafka UI / REST / schema registry (HTTPRoutes on the shared Kong) were
  unreachable and the Strimzi workflow waited forever for a `kong-gateway-proxy` address.
  fleet-manager-strimzi now renders one HTTPS listener per endpoint (exact hostname,
  `tls-kafka-external`) on the cluster's Envoy gateway (`gatewayApi.http.enabled`, default
  on) and attaches the routes there; REST with basic auth stays on Kong. REST and schema
  registry get an Envoy `SecurityPolicy`: JWT from the cluster's OAuth issuer against its
  JWKS, and for built-in sign-in only tokens with scope `kafka:<cluster>`
  (`gatewayApi.jwks.requiredScopes`). On Tailscale the JWKS is fetched through the
  streamtime-tailscale egress backend (`egress.targets[].backend`: ClusterIP Service +
  ConfigMap + BackendTLSPolicy; Envoy rejects ExternalName/headless Services) with a
  ReferenceGrant rendered by the Kafka chart. The Strimzi workflow (patch
  `strimzi-kafka-http-on-envoy`) no longer waits on Kong: UI/REST/SR records take the Envoy
  address and shared services the fleet's recorded address. Verified live on
  deafening-planarian (401 without token, 403 wrong scope, 200 with token, UI login
  redirect, brokers still passthrough). Confluent and Redpanda still use Kong (follow-up).

- **2026-10-05 — data plane on Envoy, monitoring on shared Kong** (user decision,
  CLAUDE.md principle 13). Refines the entry above: only the data plane (brokers, REST,
  schema registry, MDS, Kafka Connect) moves to the cluster's Envoy gateway. Kafka UI and
  Control Center are monitoring, not critical, and stay on the fleet's shared Kong, so
  fleet-manager-strimzi no longer renders a `kafka-ui` Envoy listener and its DNS record
  takes the fleet's recorded shared-services address. CFK already served Schema Registry
  and MDS from Envoy; its workflow (patch `cfk-shared-kong-from-fleet`) now takes the
  Control Center and shared-services address from the fleet instead of waiting on
  `kong-gateway-proxy`. Kafka Connect (streamtime-kafkaconnect,
  streamtime-cfk-kafkaconnect) and Redpanda's HTTP endpoints are still on Kong (follow-up).

- **2026-10-05 — the OIDC issuer host reaches the gateway over the egress too.** Egress
  targets take `aliases`; the backend sets the Streamtime API host (from
  `fleet_manager_external_url`) on the gateway target, and the chart rewrites it to the
  same egress Service in cluster DNS (both `dns.mode` paths). Kafka UI login discovers
  `https://<API host>/oidc`, which did not resolve in fleets (seen live on sick-raven); the
  gateway serves the built-in certificate for that name. Separately, the Strimzi chart's
  UI init container imports every certificate of the OAuth bundle into the JVM truststore
  (`keytool -importcert` read only the first, so the UI trusted only the tailnet one).

- **2026-10-01 — Kafka out of scope (user correction).** An early draft also moved
  Kafka's Envoy gateways to the tailnet. Envoy serves Kafka only; shared services
  go through Kong, which is the ingress the user chose. Kafka charts are unchanged.
- **2026-10-01 — Settings reach the orchestrator through agent-config.** Cloud
  provider workflows start `InstallStreamtimeAgentWorkflow` as a child with their
  own input, so dispatch-time injection would miss them. The block is returned
  by `/setup/orchestrator/agent-config/` (worker JWT only) and read by
  `TokenActivities.get_streamtime_agent_helm_values` on every install path.
- **2026-10-01 — Egress readiness hook.** The orchestrator's Helm install does
  not `--wait`, and the pre-bootstrap discovery probe would fail if the agent
  started before the egress proxy. The chart's `egress-ready` hook blocks until
  each target's proxy has a ready endpoint (10 min).
- **2026-10-01 — Kong tailnet Service via hook.** Kong's `GatewayConfiguration`
  (v1beta1) exposes only `annotations`, `externalTrafficPolicy`, `name`, `type`
  for the proxy Service; no `loadBalancerClass`. Hence the copy-selector hook.
  Verified on a throwaway kind cluster against a stand-in proxy Service.
- **2026-10-01 — DNS verified on real clusters.** `auto` mode tested on throwaway
  kind clusters: standard Corefile insert/idempotent upgrade/removal, the
  k3s/AKS `coredns-custom` path (simulated import line), and the no-CoreDNS
  failure message.
- **2026-10-01 — Tracked bootstrap component (user request).** Tailscale is now the
  `streamtime_tailscale` bootstrap component (`install_phase: "pre_agent"`,
  conditional on the tunnel provider) instead of a side install:
  - shown in the fleet bootstrap list ("Private network (Tailscale)"), values
    viewable/overridable, recorded in installed components;
  - version resolved by package rules (`streamtime-ai/streamtime-tailscale`,
    ghcr and the local `registry:5000` tracked repos) — the
    `tailscale_chart_version` GlobalConfiguration key and its seed migration
    are removed;
  - operator, proxy and hook images listed in `registry_images.yaml` and pinned
    fully qualified in the chart (short names fail on OKE).
  The orchestrator installs it from compute-components before the agent and
  adds only `operator.oauth.clientSecret` (from the worker-only agent-config);
  the component values never contain the secret. The agent's bootstrap skips
  pre-agent components. A Tailscale fleet whose component has no supported
  package fails compute-components with a plain message instead of being
  skipped like other conditional components.
- **Known limitations.**
  - Value edits to the Tailscale component apply on the next agent reinstall,
    not through a component-scoped bootstrap update (that path runs on the agent).
  - The package rule has a lower bound only (`>=1.1.15`) until the chart's first
    release; pin it with the other in-repo charts then.
  - The Kong tailnet Service copies the proxy selector at each bootstrap; a Kong
    operator change to that selector between bootstraps leaves it stale.
- **2026-10-02 — Fleet DNS points at the tailnet IP.** With the Kong proxy
  ClusterIP, the Gateway advertised its ClusterIP and external-dns published
  that (found live: `shared-<fleet>.<domain> → 10.96.x`). The tailnet hook now
  waits for the tailnet IP and sets `external-dns.kubernetes.io/target` on the
  Gateway (Gateway API sources read this key, without `.alpha`). Verified live:
  the authoritative record moved to the tailnet IP.
- **2026-10-02 — No node ports.** LoadBalancer Services get node ports by
  default, which exposed Kong on every node address (found live:
  `<node>:31692` answered). The tailnet Service sets
  `allocateLoadBalancerNodePorts: false` and the hook removes node ports an
  earlier release allocated. Verified live: the only externally reachable
  Service on the fleet is the tailnet load balancer, with no node ports.
- **2026-10-02 — Kong certificate race (all ACME fleets).** Kong's control plane
  does not re-resolve the listener certificateRef when the ACME Secret appears
  after the Gateway, leaving every route 404 (`InvalidCertificateRef`) until a
  restart. `kong-gateway-cert-reconcile.yaml` (a regular Job, never a hook, so
  ACME delays cannot fail the release) waits for the Certificate, then nudges the
  Gateway and, if needed, restarts the Kong control plane. Not Tailscale-specific.
- **Observed, not changed:** external-dns crash-loops on this dev fleet because
  calls through the STDNS webhook exceed its request timeout (pre-existing; seen
  before this change). Records still converge between restarts.
- **2026-10-02 — Tailnet orchestrator address is authoritative.** Found live: a
  provider-less tunnel update (`scripts/dev-tunnels.sh`) replaced
  `orchestrator_tunnel_url` with `bore.pub:…` while the provider stayed
  Tailscale, so a new agent connected over a public tunnel. Now, with Tailscale
  as the provider, agents always get `<Streamtime tailnet host>:8443`, and an
  update that does not switch the provider can change the registry tunnel but
  not the orchestrator address. The agent's `STREAMTIME_URI` is informational
  (health reports; the agent makes no outbound API calls) and stays as is.
- **Test caveat.** A kind fleet on the Streamtime host can route to the host's
  tailnet IP through Docker Desktop, so it cannot prove tailnet-only
  connectivity; use a fleet off the host (cloud) for that.
- **2026-10-02 — Egress cleanup order (found on the first real delete).** Helm
  removed the operator in the same pass as the egress Service; the Service then
  hung on the operator's `tailscale.com/finalizer`, orphaning the proxy and its
  tailnet device. A pre-delete hook now deletes the egress Services and waits
  while the operator still runs. Egress proxies also get a per-fleet device name
  (`<org>-<fleet>-egress`) instead of the generic `tailscale-streamtime-gateway`
  every fleet would share. Verified on the delete: the chart, CoreDNS entry,
  operator device and ingress device were all removed by the existing steps.

- **2026-10-03 — Tailscale moves into the agent chart.** Superseded by
  `plans/tailscale-agent-dependency.md`.
  - The `streamtime_tailscale` pre-agent bootstrap component is removed.
    `charts/streamtime-tailscale` is now a conditional dependency of
    `charts/streamtime-agent`, and it installs and upgrades with the agent in
    automatic and manual modes.
  - A fleet delete no longer uninstalls Tailscale. It only deletes the
    fleet's tailnet devices.

- **2026-10-07 — cluster DNS uses a dedicated server block (OKE fix).** `dns.mode:
  auto` put the tailnet-name rewrites inside the Corefile's `.:53` block. OKE
  serves `cluster.local` from a separate server block, so `.:53` (forward only)
  could not answer the egress Service the rewrite points at: the tailnet name
  was NXDOMAIN and the agent waited in `wait-for-orchestrator` indefinitely.
  dns-sync now writes its own server block for exactly the tailnet names
  (rewrite, `kubernetes <clusterDomain>`, forward, cache): as the
  `streamtime-tailnet.server` key of `coredns-custom` where the Corefile imports
  `custom/*.server` (OKE's supported extension point; a block left in the
  Corefile by an earlier version is removed), or appended to the Corefile
  otherwise (kubeadm, kind, EKS). k3s and AKS keep the `*.override` key.
  Verified live on OKE (Oracle Linux 8, CRI-O): the name resolves, the agent
  connects, and its image is pulled over the tailnet registry with the CRI-O
  node-mirror certificate.
