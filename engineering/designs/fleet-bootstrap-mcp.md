# Fleet-bootstrap MCP (enable AI)

## Objective

When **Enable AI** is on in fleet Basic Configuration, bootstrap installs
[containers/kubernetes-mcp-server](https://github.com/containers/kubernetes-mcp-server)
in-cluster on the fleet (shared-services Kong + shared-credentials). The
existing control-plane MCP (`/organizations/{org}/mcp/`) exposes that server’s
tools as a namespaced leaf, so the chat harness and external clients (Claude
Desktop, Cursor) keep talking to **one** Streamtime MCP endpoint. Tools may
read and write, subject to fleet ServiceAccount RBAC and org permissions.
No kubeconfig is mounted, stored, or required at call time — including fleets
that were joined by hand (BYOK).

Build it in three gates. Do not start the next gate until the previous gate’s
checks have passed.

1. **Fleet bootstrap.** The server is installed, reached through shared Kong,
   and talks to the API server as its ServiceAccount.
2. **POC.** Prove the fold: one org MCP tool list that both the chat harness
   and an external client can call. Measure it. Stop or go.
3. **Full effort.** Permissions, investigations, cache, failure isolation, and
   the product edges. Only after the POC records a go.

## Decision: one org MCP, two adapters, in-cluster identity

| Layer | Role |
|---|---|
| **Fleet** | Elective bootstrap. kubernetes-mcp-server over Streamable HTTP at `/mcp`, behind the fleet’s shared Kong. Identity is the pod ServiceAccount. |
| **Control-plane** | One public MCP. A request-scoped provider adds that fleet’s tools under `fleet_<identifier>_`. |
| **Chat harness** | In-process adapter over the same provider. No second URL, no fleet password. |
| **Claude Desktop / Cursor** | The org MCP URL they already use. Same tool names. Fleet credentials never leave the backend. |

Laptop `npx kubernetes-mcp-server` (stdio + kubeconfig) is not the product path.

### Why not mount the remote server on `flm_mcp`

`flm_mcp` is one process-wide FastMCP app (`mcp_server/server.py`),
`stateless_http=True`, shared by every organization. A `ProxyProvider` /
`mount()` attached to it would publish one org’s fleets on every other org’s
`tools/list`. The chat harness would still miss them: it builds pydantic-ai
tools from `mcp_server.registry.list_tool_specs()`, not from
`flm_mcp.list_tools()` (`assistant_harness._mcp_tools_for_agent`).

### Why not give Claude a second URL

The fleet endpoint is Kong basic-auth under the fleet’s existing shared
monitoring consumer — the same credential that fronts `/metrics`, `/logs`,
`/otel` and `/alerts` — not a per-fleet one. That password is a service
principal. Handing it to Claude Desktop (or the browser) is the exposure
`kafka_admin` was built to avoid. A kubeconfig in the desktop client has the
same problem, and a BYOK kubeconfig can be stale after the agent is installed.

## Decisions

- **Tool prefix:** `fleet_<identifier>_`, dashes in the identifier replaced
  with underscores. Identifiers cannot contain underscores, so the prefix
  round-trips. Example: fleet `prod-a`, upstream `pods_list` →
  `fleet_prod_a_pods_list`. Descriptions say which fleet, in plain language.
- **ServiceAccount:** custom ClusterRole, not `edit` and not cluster-admin.
  get/list/watch on workloads, pods/log, events, nodes, namespaces.
  The write verbs follow the fleet’s access mode: **read-only** (the default)
  grants only get/list/watch and no pods/exec; **read-write** (experimental)
  adds create/update/patch/delete on pods, deployments, statefulsets,
  daemonsets, jobs, cronjobs, configmaps, services, and create on pods/exec.
  No Secrets, in either mode. No Role, RoleBinding, ClusterRole, or
  ClusterRoleBinding writes, in either mode. Upstream `denied_resources` denies
  Secrets as well.
- **Toolsets:** `core` only. The upstream default also enables `config`, which
  views and edits kubeconfig. Leave `config` off. Helm stays off: Helm release
  storage is Secrets, which this ClusterRole denies.
- **Listing:** per request, for the authenticated org only, with a short
  in-process cache (about 60s, keyed by org + fleet + endpoint). A fleet with
  AI off, or with no recorded endpoint, contributes nothing. A fleet that does
  not answer is omitted; the org MCP still starts and still lists. `tools/call`
  re-checks `enable_ai` and the endpoint so a cached name cannot fire after
  AI is turned off. Cache and the omit-on-failure behavior are full-effort.
  The POC lists one fleet, live, with no cache.
- **Investigations** (full effort) get read-only leaf tools for the alert’s
  fleet only. Mutating upstream tools are marked `read_only=False` by our
  name list (delete, exec, create, update, patch, scale, install, uninstall),
  not by trusting upstream hints. The service role still cannot write.
- **No kubeconfig on the pod.** `cluster_provider_strategy = "in-cluster"`.
  `kubeconfig` unset. No kubeconfig volume. No `KUBECONFIG`. Do not copy the
  BYOK join secret.

## In scope

- Helm chart, catalogue packages, `enable_ai`, shared-credentials, endpoint,
  install and uninstall (step 1)
- A POC that folds one fleet’s tools into the org MCP and the chat harness
  (step 2)
- The production leaf: both adapters, permissions, investigations, cache
  (step 3, after a POC go)

## Out of scope

- Replacing control-plane bookkeeping tools
- A second MCP URL, or putting fleet credentials in Claude Desktop / the SPA
- Public internet exposure (Kong + shared-credentials; tailnet when that is
  how the fleet is reached)
- A custom FastMCP that speaks Kubernetes
- The `config` toolset, the Helm toolset, or any kubeconfig mount
- Starting step 2 before step 1’s live checks pass, or step 3 before the POC
  records a go in **Deviations**

## Step 1 — Fleet bootstrap

This step ends when a fleet with **Enable AI** on is running the upstream
server behind shared Kong, and a fleet with it off is not. No org-MCP changes
in this step.

### Chart

`charts/streamtime-fleet-mcp/`, the same shape as
`charts/streamtime-kafka-admin/`: Deployment, Service, ServiceAccount,
ClusterRole and ClusterRoleBinding, HTTPRoute, NetworkPolicy, PodMonitor. It
creates no Gateway. It also creates no KongPlugin and no KongConsumer — see
**Credentials and endpoint** for why.

The Helm release namespace stays the fleet id (`__fleet_id__`), but every
namespaced resource is rendered into the shared-services namespace
(`monitoring`), set from a chart `namespace` value. The Gateway API
`ExtensionRef` that attaches the auth plugin is namespace-local, so the route
must sit beside the fleet’s existing `monitoring-basic-auth` KongPlugin; the
backendRef stays in the same namespace. Cluster-scoped names stay suffixed with
the fleet id so two fleets on one cluster do not collide.

The process is configured with a ConfigMap TOML file (`--config`), not flags.
Upstream ignores runtime flags other than `--config` / `--config-dir`. Pin the
image from the catalogue. No `latest`.

```toml
port = "8080"
bind_address = "0.0.0.0"
metrics_port = "9090"
stateless = true
log_file = "stderr"
read_only = true
cluster_provider_strategy = "in-cluster"
toolsets = ["core"]

[[denied_resources]]
group = ""
version = "v1"
kind = "Secret"
```

- `port` set is what turns on Streamable HTTP at `/mcp`. Empty `port` is
  stdio, which does nothing useful in a pod.
- `read_only` is templated from the component’s resolved `config.readOnly`,
  which follows `Fleet.streamtime_ai_access`. Read-only (`true`) is the
  default; the ClusterRole verbs follow the same value.
- `cluster_provider_strategy = "in-cluster"` pins the pod identity. An empty
  `kubeconfig` already auto-detects in-cluster, but a stray `KUBECONFIG` or
  `~/.kube/config` in the image would select the kubeconfig provider. Do not
  set `kubeconfig`. Do not enable `disable_localhost_protection`: Kong calls
  the Service address, not loopback, so the Host check does not apply.
- `stateless = true` because the Deployment has more than one replica and Kong
  does not pin a session to a pod. Tool-change notifications are useless here.
- `metrics_port` keeps scrape traffic off `/mcp`. NetworkPolicy admits
  Prometheus in `monitoring` to 9090 only.
- Route path `/fleet-mcp` on the shared Kong Gateway, hostname
  `shared-{fleet}.{domain}`, authorized by the existing `monitoring-basic-auth`
  KongPlugin. The chart fails to render if no plugin is named, rather than
  leaving the route unauthenticated.
- NetworkPolicy ingress on 8080: Kong in the fleet namespace only. Egress:
  DNS, and the API server on 443 and 6443 (managed control planes are not a
  pod selector). Same pattern as kafka-admin.
- Helm unittest: no second Gateway, route `/fleet-mcp` references
  `monitoring-basic-auth`, the route renders into `monitoring`, ClusterRole has
  no Secret rules and no RBAC-object writes, read-only grants no write verbs or
  pods/exec while read-write does, Deployment has no kubeconfig volume and no
  `KUBECONFIG`, rendered TOML has `read_only = true` by default and
  `cluster_provider_strategy = "in-cluster"` and `toolsets = ["core"]` and does
  not set `kubeconfig`.

### Catalogue and resolver

Component key `streamtime_fleet_mcp` in
`fleet-manager-backend/core/services/bootstrap_resolver.py`
(`_COMPONENT_REGISTRY_MAP`), mirroring `streamtime_kafka_admin`:

| Field | Value |
|---|---|
| Release | `streamtime-fleet-mcp` |
| Namespace | `__fleet_id__` |
| install_order | 102 (after kafka-admin at 101, so LIFO teardown removes it before the Gateway) |
| conditional | true |
| Chart package | `streamtime-ai/streamtime-fleet-mcp-helm` on `ghcr.io`, and the local mirror |
| image_package | separate repository `streamtime-fleet-mcp`, paths `image.repository` and `image.tag` |

Not an entry in `WORKLOAD_GATED_COMPONENTS`. After
`gate_components_by_workloads` in `resolve_bootstrap_values`, a feature gate
sets `install` from `Fleet.enable_ai`. Skip reasons, plain language: “AI is
not enabled for this fleet.” A missing catalogue package uses the same
conditional skip as kafka-admin, so bootstrap does not fail.

Preload: `package_rules.yaml`, `package_inventory.yaml`, and the helm-repo
list, chart and image as distinct packages (the kafka-admin preload tests are
the pattern).

### `enable_ai` and `streamtime_ai_access`

`Fleet.enable_ai`, boolean, default false, migration. `FleetSerializer` uses
`fields = "__all__"`, so the field is on the API. Switch on Basic
Configuration in `KubernetesFleetCreate.js`, and on the screen that edits an
existing fleet’s basic fields. Label **Enable AI**. Helper text: lets the
assistant inspect this fleet’s workloads. No “MCP”, “kubeconfig”, chart name,
or workflow id.

`Fleet.streamtime_ai_access`, choices `read_only` / `read_write`, default
`read_only`, migration. Shown on Basic Configuration only when Enable AI is on:
a switch labelled **Allow AI to make changes**, checked means `read_write`, with
a tooltip that write access is experimental and lets Streamtime AI make
automatic remediations. The resolver hands the component
`config.readOnly = (streamtime_ai_access == "read_only")`, and the chart’s
ClusterRole verbs and TOML `read_only` follow it.

Do not bump `generation` for either field. A fleet reconcile of kind `update`
is rejected (`update_not_supported` in `fleet_reconcile_dispatch.py`). Dispatch
the way workloads do (`dispatch_workload_reconcile`, the workloads
scoped-update path) when a provisioned fleet (`Healthy` or `Error`) flips
Enable AI, or changes its access mode while AI is on. `FleetSerializer.aupdate`
reverts the field if the dispatch cannot start, so the DB never claims a change
that was not applied. The resolver’s feature gate marks the component
`workload_gated=True`, so a scoped UPDATE installs it (AI on) or uninstalls it
(AI off).

Turning AI **off** cannot be a normal scoped UPDATE.
`scope_bootstrap_components` rejects a conditional component with
`install=False`, and `bootstrap_cluster` skips it, so the release would stay.
Uninstall the way `uninstall_workload_components` does. BYOK already keeps
`all_bootstrap_components` before it filters a scoped UPDATE; this component
must still be visible there when the gate turns it off. Cloud providers that
call `bootstrap_cluster` with the full map uninstall from that map.
`build_fleet_teardown_releases` adds `streamtime-fleet-mcp` in the fleet
namespace, beside kafka-admin. `BOOTSTRAP_RELEASES` in the teardown test must
match.

### Credentials and endpoint

Authorization reuses the fleet’s existing shared monitoring basic-auth
consumer — the `basic-auth-creds` Secret, the `basic-auth` KongConsumer and the
`monitoring-basic-auth` KongPlugin in the `monitoring` namespace, the same
credential that fronts `/metrics`, `/logs`, `/otel` and `/alerts`. No
`fleet_mcp` key is added to `build_shared_credentials_payload`, and the chart
creates no KongPlugin or KongConsumer of its own. A caller authenticates as the
fleet’s `metrics` credential. This is why the namespaced resources render into
`monitoring`: the Gateway API `ExtensionRef` cannot cross namespaces, and the
chart must not create a second consumer. The chart fails to render if no plugin
is named.

Endpoint `https://{shared_hostname}/fleet-mcp`, type `fleet_mcp`, written next
to the kafka-admin endpoint in `bootstrap_cluster`, only when the component is
installed. Runtime values (hostname, auth plugin, resource namespace, gateway
namespace, network-policy namespace) are injected in `_apply_runtime_values`.

`monitoring-basic-auth` only exists when monitoring credentials are present and
the fleet is not on the OAuth path (`oauth_jwks_uri` with custom auth plugins),
which renders `monitoring-jwt-auth` instead. Step 1 assumes basic-auth; the
OAuth case is out of scope and noted in **Deviations**.

### No kubeconfig, including a hand-joined fleet

BYOK stores a kubeconfig at
`/organizations/{org}/fleet/{fleet}/kubeconfig` so the agent can be installed.
Chart install after that is the in-cluster agent. `bootstrap_cluster` does not
pass that kubeconfig into chart values. The MCP pod is installed the same way
and uses its ServiceAccount token. That still works when the join kubeconfig
is later expired or deleted.

It does not work when shared Kong was never installed
(`fleet_manager_infra_shared`): the route has nowhere to attach. That is the
same prerequisite as Kafka administration.

### Step 1 is done when

- `compute-components` installs the component only when `enable_ai` is true
  and the package exists, and skips with a plain reason otherwise.
- Unit tests cover the resolver, the feature gate and access mode, runtime
  values, the chart, the serializer dispatch, and the teardown list.
- Live, on one cloud fleet and one BYOK fleet: Enable AI, pod Ready, no
  kubeconfig volume, `kubectl exec` (or the pod spec) shows
  `cluster_provider_strategy = in-cluster`. From the backend network, HTTP
  `initialize` + `tools/list` against `https://{shared}/fleet-mcp/mcp` with
  the fleet’s monitoring (`metrics`) credential returns the `core` tools. One
  read (`pods_list` or the pinned release’s equivalent) returns cluster data.
  Disable AI and the release is gone. A fleet that never had AI on does not
  have the release.

## Step 2 — POC the fold

Start only after step 1’s live checks. This is a short experiment, not the
product. It answers whether Streamable HTTP survives Kong, and whether one
provider can feed both the harness and an external client.

### What to build

A Django client, `core/services/fleet_mcp.py`, enough to `initialize`,
`tools/list`, and `tools/call` against one fleet endpoint with the fleet’s
monitoring (`metrics`) credential. Errors must not contain the hostname, the
URL, or the password. Missing endpoint is “not provisioned”.

A single module, `mcp_server/fleet_leaf.py`, used two ways:

- **HTTP.** Wrap `get_mcp_http_app` so `tools/list` and `tools/call` for the
  authenticated org include that fleet’s tools under `fleet_<identifier>_`.
  Do not call `flm_mcp.mount` or `ProxyProvider` on the global server.
- **Harness.** `_mcp_tools_for_agent()` appends the same specs for the org
  already in `set_mcp_context`. The harness does not HTTP-call itself.

One org, one AI fleet, no cache, no investigation changes, no per-tool
permission matrix beyond “the caller is a member of this org”. Writes are
allowed in the POC so a mutate call can be shown once; do not leave that as
the production rule.

### What the POC must show

1. `tools/list` on `/organizations/{org}/mcp/` contains `fleet_<id>_*` and
   does not contain another org’s fleets.
2. The chat harness’s tool list for that org has the same leaf names.
3. One read and one write from the harness (or from the HTTP endpoint) reach
   the fleet and the ServiceAccount, not a kubeconfig.
4. Count the leaf tools. Record the number in **Deviations**.

### Stop

Stop and write the finding in **Deviations** if any of these are true:

- Kong or the Host check breaks Streamable HTTP (`initialize` / session /
  SSE). Fix the chart TOML or the route before any leaf work continues.
- The leaf count for one fleet, plus the existing bookkeeping tools, is too
  large for a model context. The full effort then uses one meta-tool
  (`list` + `call` with a fleet argument) instead of a prefixed tool per
  upstream tool. Do not build both.
- The only way to make the call succeed is to mount a kubeconfig. That is a
  failed POC. Do not add the mount.

### Go

A go is a **Deviations** bullet naming the date, the tool count, and which
shape won (prefixed tools, or the meta-tool). Step 3 implements that shape.

## Step 3 — Full effort

Only the shape the POC accepted.

- Org permission before forward: fleet read for read-only tools, fleet mutate
  for writes, service role cannot write (`_require_org_permission`).
- Classify `read_only` from the tool name. Do not trust upstream hints.
- Cache `tools/list` for about 60s. Omit a fleet that does not answer. Recheck
  `enable_ai` on call.
- Investigations: read-only leaf tools for the alert’s fleet only
  (`investigate_alert.py`). Playbook steps with an explicit tool list do not
  gain leaf tools unless that list includes them.
- Same names on the harness and on the HTTP app. One test asserts that.
- Docs in the MCP module: bookkeeping tools versus `fleet_<id>_*` tools.
- Live: enable → tools appear for the harness and for Claude Desktop on the
  org URL → read and write under the caller’s role → disable → tools
  disappear with the release.

## Tests

Step 1:

- Resolver: `enable_ai` false skips; true and package present installs;
  package missing does not fail bootstrap. Read-only is the default; read-write
  forwards `config.readOnly = false`; the access mode is not written when AI is
  off.
- Shared credentials: the payload gains no `fleet_mcp` key — the assistant
  reuses the monitoring consumer’s credential.
- Serializer: changing the access mode on an AI-enabled fleet dispatches a
  reconcile; a failed dispatch reverts the field; changing it with AI off does
  not dispatch.
- Orchestrator runtime values: hostname, auth plugin, resource namespace,
  gateway namespace, network-policy namespace. No kubeconfig in the values.
- Helm unittest and teardown list, as in step 1.

Step 2 (kept if the POC is promoted, deleted if the POC is thrown away):

- Client: `tools/list` and `tools/call` against a fake upstream; error text
  has no URL or password.
- Leaf: org A does not see org B; names use the prefix; harness and HTTP
  lists match for one org.

Step 3:

- Write without permission is refused. Service role cannot write. AI off
  omits the fleet. `tools/list` succeeds with zero AI fleets. A down fleet
  is omitted. Investigation sees only the alert fleet’s read-only leaf tools.

## Deviations

- **2026-10-09 — request-scoped provider, not a global mount.** The first
  sketch mounted `ProxyProvider` on `flm_mcp`. That server is one process for
  every org, and the harness does not read its tool list. The leaf is still
  namespaced tools on the single org MCP; both the harness and external
  clients use one provider. Step 2 proves that wrapper.
- **2026-10-09 — Helm and `config` toolsets off.** The sketch allowed Helm.
  Helm release storage is Secrets, which this ClusterRole denies. Upstream’s
  default `config` toolset edits kubeconfig, which this server must not do.
- **2026-10-09 — uninstall is a feature gate, not a component UPDATE.** A
  scoped UPDATE of a conditional component with `install=False` is rejected
  or skipped, so turning AI off follows the workload-uninstall path.
- **2026-10-09 — bootstrap, then a POC, then the full leaf.** The previous
  delivery list built the proxy, permissions, and harness in the same effort
  as the chart. Step 3 does not start until step 2 records a go here.
- **2026-10-10 — reuses the shared monitoring basic-auth consumer.** The first
  sketch minted a per-fleet `fleet_mcp` shared-credential and the chart’s own
  KongConsumer and KongPlugin, like `kafka_admin`. The requirement is that the
  assistant be reachable under the credential the fleet’s other shared-gateway
  resources already use, not a new secret or consumer. The chart now creates
  neither and `build_shared_credentials_payload` gains no key; the route
  authorizes with the fleet’s existing `monitoring-basic-auth` KongPlugin and
  the caller uses the `metrics` credential.
- **2026-10-10 — namespaced resources render into the shared-services
  namespace.** The Gateway API `ExtensionRef` that attaches `monitoring-basic-auth`
  is namespace-local, and the fleet namespace has no such plugin; the repo has
  no cross-namespace HTTPRoute backendRef precedent. So the chart renders its
  Deployment, Service, ServiceAccount, NetworkPolicy, PodMonitor and HTTPRoute
  into `monitoring` (a chart `namespace` value) while the Helm release namespace
  stays the fleet id, matching the fixed-name shared-services precedent in
  `fleet-manager-infra-shared`. The NetworkPolicy still admits only Kong in the
  fleet namespace.
- **2026-10-10 — read-only is the default, as a fleet field.** The sketch
  hardcoded `read_only = false`. It is now `Fleet.streamtime_ai_access`
  (`read_only` / `read_write`, default `read_only`), surfaced on Basic
  Configuration only when Enable AI is on, with an experimental-writes tooltip.
  The resolver sets `config.readOnly`; the chart’s ClusterRole verbs and TOML
  follow it. Read-write is opt-in per fleet.
- **2026-10-10 — the OAuth monitoring path is out of scope for step 1.**
  `monitoring-basic-auth` is only rendered when monitoring credentials exist
  and the fleet is not on the OAuth path (`oauth_jwks_uri` with custom auth
  plugins), which renders `monitoring-jwt-auth` instead. Step 1 assumes the
  basic-auth fleet; an OAuth fleet would need the plugin reference and caller
  credential resolved separately.
- **2026-10-10 — server-managed components appear in the bootstrap editor.**
  The plan mirrored `streamtime_kafka_admin` and left both it and
  `streamtime_fleet_mcp` out of the editor's component list, on the reasoning
  that they install automatically. The requirement is that both be visible and
  pinnable there. Added first-class fields to `BootstrapConfigSchema`
  (`streamtime_kafka_admin`, `streamtime_fleet_mcp`) and entries in the
  frontend `BOOTSTRAP_COMPONENTS` map (the `rustfs` pattern), so an operator can
  pin a chart version and set Helm values. Install is still decided by the
  gates, not by presence in the config: the streaming-workload gate for Kafka
  administration and the `enable_ai` feature gate for the assistant.
- **2026-10-10 — the assistant image rule tracks the fleet SemVer line.**
  The image rule shipped as `>=0.0.67` / `default_version: v0.0.67`, the
  upstream `kubernetes-mcp-server` release tag. The image is actually built and
  pushed alongside its chart by the same run and tagged with that run's chart
  version (`0.1.<epoch>`), exactly like the Kafka Admin image and the paired
  kroxylicious image. An upstream-shaped default could never resolve, so the
  component always skipped even with Enable AI on. Changed to `>=0.1.0` /
  `default_version: 0.1.0`, mirroring the Kafka Admin image rule. The image
  still has to be pushed with a version on that line before install resolves;
  the fleet's catalogue sync then picks the newest one.
- **2026-10-10 — the image is built by CI and by the chart script.** Nothing
  produced an artifact on the fleet's image line: `charts/` discovery covers
  charts only, and neither nightly nor release built `streamtime-fleet-mcp`.
  Added `docker/streamtime-fleet-mcp/Dockerfile` (a wrapper over the chart's
  upstream `kubernetes-mcp-server`, pinning the release from the chart's
  `appVersion` and adding our OCI metadata), `scripts/build-and-push-fleet-mcp-image.sh`
  (invoked by `build-and-push-chart.sh` when the `streamtime-fleet-mcp` chart is
  built, tagged with that run's `CHART_VERSION`, like the Kroxylicious paired
  image), and `.github/workflows/build-streamtime-fleet-mcp.yaml`, wired into
  `publish-nightly.yaml` and `release.yaml` exactly like `streamtime-kafka-admin`.
  Nightly tags (`0.0.0-nightly.*`) stay opt-in for package rules, as for every
  other component.
- **2026-10-10 — the step-2 client is hand-rolled, not the `mcp` SDK.** The
  backend pins `httpx` 0.28.1, but the installed `mcp` SDK depends on a second,
  separate `httpx2` package that is not in `requirements.txt`, and `fastmcp` is
  unpinned. Rather than add a dependency that would desync two HTTP stacks, the
  client speaks MCP Streamable HTTP directly over `httpx`: JSON-RPC POST, both
  `application/json` and `text/event-stream` replies, capture/echo of
  `Mcp-Session-Id`, and a `notifications/initialized` follow-up that is expected
  to answer 202 with no body. The protocol revision is fixed at `2025-06-18`.
- **2026-10-10 — the leaf is a raw-ASGI middleware, not a `ProxyProvider`.**
  `mcp_server/fleet_leaf.py` folds each AI fleet into the org MCP from one tool
  table used two ways. Operationally it is a raw ASGI middleware placed *after*
  `MCPApiKeyAuthMiddleware` so the org context is set before it runs: it buffers
  the POST body, appends `fleet_<id>_*` definitions to the inner `tools/list`
  reply on both SSE and JSON, and short-circuits `tools/call` for names in that
  namespace (resolving the fleet by prefix) with an SSE JSON-RPC result. The
  harness path calls `_mcp_tools_for_agent()`, now `async`, which appends the
  same `ToolSpec`s via `get_org_id()`. The middleware must replay the request
  body and then hand `receive` back to the client rather than emit
  `http.disconnect`, or the Streamable HTTP transport stops streaming before it
  writes a response. No `flm_mcp.mount` and no `ProxyProvider`.
- **2026-10-10 — step 2 POC (in-process): fold proven; gate stays closed.** The
  POC is proven end-to-end without a live fleet: `core/tests/test_fleet_mcp.py`
  drives the org MCP ASGI app through its real auth middleware and folds a fake
  fleet (an `httpx.MockTransport` speaking Streamable HTTP) — `tools/list` on
  `/organizations/{org}/mcp/` contains `fleet_<id>_*` and none of another org's
  fleets; a read and a write `tools/call` reach the upstream and carry the
  ServiceAccount result; errors carry no host, URL, or password. Name shape won:
  **prefixed tools** (`fleet_<identifier>_<upstream-tool>`), not a meta-tool.
  Tool count is not recorded: it needs a live AI fleet, and step 1's live checks
  are blocked on the `streamtime-fleet-mcp` image being pushed. No **go** is
  recorded here, so **step 3 must not start**; the live checks (count, Kong
  Streamable HTTP survival, a real read/write under the caller's role) settle the
  gate.
- **2026-10-11 — shape changed to a meta-tool with progressive disclosure
  (user-directed, ahead of the POC go).** The Step 2 POC concluded the prefixed
  shape. On review the concern was context bloat: one fleet's Kubernetes MCP can
  be many tools, and listing every AI fleet's tools on every chat turn is
  unbounded. The user directed the shape the plan reserved for Step 3: one meta
  tool, `list_fleet_ai_tools(fleet)`, which returns `false` when a fleet offers
  nothing (not AI-enabled, unreachable, or empty) and otherwise returns that
  fleet's tool definitions. The chat harness advertises only the shared tools plus
  the meta tool; when the model calls it, that fleet's leaf tools are added to the
  next model request through a pydantic-ai `Toolset` capability, so they become
  callable. Investigations do the same, read-only, deriving the revealed fleets
  from the persisted `list_fleet_ai_tools` calls, so each Temporal round stays
  stateless. The HTTP org MCP keeps listing `fleet_<id>_*` eagerly for external
  clients (the MCP transport has no per-session tool reveal), alongside the meta
  tool. `_mcp_tools_for_agent()` no longer appends leaf specs; the same tool
  table is still reused by name.
- **2026-10-11 — step 3's investigation item landed early, on user direction.**
  The Step 3 plan ("read-only leaf tools for the alert's fleet only") was
  implemented before the Step 2 go, at the user's explicit direction, via the
  same meta tool. Read-only is classified from the tool name (`_is_read_only`),
  never from upstream hints; a fleet that is unknown, AI-off, or unreachable
  contributes nothing, so the investigation still runs. This does not record a
  **go**: Step 1's live checks and the Step 2 live proof remain outstanding.
- **2026-10-11 — the image is the upstream image, referenced directly
  (user-directed; supersedes the two image bullets above).** Streamtime adding a
  wrapper Dockerfile, a paired image build, its own image catalogue entry, and a
  dedicated CI workflow was unnecessary. The upstream `kubernetes-mcp-server`
  image is third-party, and the repository already consumes several third-party
  charts and images directly, so this chart does too. `charts/streamtime-fleet-mcp`
  now defaults `image.repository` to `ghcr.io/containers/kubernetes-mcp-server`
  and `image.tag` to the release its `appVersion` targets; the resolver declares
  no `image_package`, exactly like the other third-party components, so it no
  longer injects `image.repository`/`image.tag`. Removed:
  `docker/streamtime-fleet-mcp/Dockerfile`, `scripts/build-and-push-fleet-mcp-image.sh`,
  `.github/workflows/build-streamtime-fleet-mcp.yaml`, the paired-image branch in
  `build-and-push-chart.sh`, both `streamtime-fleet-mcp` image entries in
  `package_inventory.yaml`, the "Streamtime Fleet MCP Image" rule in
  `package_rules.yaml`, and the `fleet-mcp` jobs/env/needs in `publish-nightly.yaml`
  and `release.yaml`. The component stays conditional on its **chart** being in
  the catalogue (and on Enable AI). This also removes the blocker the Step 2 POC
  note records: the live checks no longer wait on a Streamtime image being pushed,
  because the fleet pulls the upstream multi-arch image directly. No **go** is
  recorded here; Step 1's live checks and the Step 2 live proof still settle the
  gate.
- **2026-10-11 — Step 2 live proof: the gate is a go.** With
  `streamtime-fleet-mcp` installed on `k3-chitradurga` (`architectural-chickadee`,
  rendered into the shared-services namespace `monitoring`) and the fleet's
  `fleet_mcp` endpoint recorded (`https://shared-architectural-chickadee.az1.streamti.me/fleet-mcp`,
  the orchestrator's own address shape), the path was exercised through Kong:
  unauthenticated `POST /fleet-mcp/mcp` returns `401` (the shared
  `monitoring-basic-auth` KongPlugin), authenticated `initialize` returns `200`
  with protocol `2025-06-18`, and the `notifications/initialized` follow-up
  answers `202` while replies stream over `text/event-stream` — Kong preserves
  Streamable HTTP. `list_fleet_ai_tools('architectural-chickadee')` returns **19**
  leaf tools (`fleet_<id>_*`), and a real read (`namespaces_list`) and a real
  write (`resources_create_or_update` then `resources_delete` of a throwaway
  ConfigMap) both reached the cluster through the pod's ServiceAccount — no
  kubeconfig was mounted. Shape won: the **meta tool with progressive disclosure**
  (`list_fleet_ai_tools(fleet)`), per the 2026-10-11 shape deviation above. The
  endpoint row was written for this live check; the orchestrator writes the same
  row during a fleet reconcile. **Step 2 is a go; Step 3 may proceed.**
- **2026-10-11 — review corrections: private-registry pull secret and DNS
  ownership.** AI review (Codex P1/P2) found two defects after the live go. P1:
  the `streamtime_fleet_mcp` runtime branch never attached
  `registry-mirror-pull-secret` to `image.pullSecrets`, so on an authenticated
  private registry or mirror the Deployment could not pull the image and the Helm
  install would time out. Fixed in `fleet_provider_base._apply_runtime_values`
  (the chart's `image.pullSecrets` is a plain list, and the pod renders into
  `monitoring`, where bootstrap creates the mirror secret), with orchestrator
  tests. P2: the route carried `external-dns.alpha.kubernetes.io/hostname` for the
  shared hostname, which the first `fleet-manager-infra-shared` route already
  owns; a second resource claiming the same hostname makes external-dns rewrite
  the record's TXT owner on every sync (the infra-shared template comments this
  exactly). Removed the annotation from
  `charts/streamtime-fleet-mcp/templates/httproute.yaml` — the shared record is
  owned by the prometheus route — with a chart test. This is a deliberate
  departure from `streamtime-kafka-admin`, which still annotates the same shared
  hostname; that chart is out of scope here.
- **2026-10-11 — the maintainers' chart replaces `charts/streamtime-fleet-mcp`
  (user-directed; supersedes "Chart", the shared-services-namespace bullet and
  the pull-secret half of the review-corrections bullet).** Upstream publishes
  `oci://ghcr.io/containers/charts/kubernetes-mcp-server` (0.1.0, appVersion
  0.0.67), so a Streamtime wrapper chart was one more artifact to own, version
  and publish, and its catalogue entries followed the first-party pattern (a
  `registry:5000` mirror, a `>=0.1.0` rule whose default never existed on GHCR,
  no nightly rule). Now:
  - **Catalogue.** One tracked repository on `ghcr.io`
    (`containers/charts/kubernetes-mcp-server`, `workflow_chart_name` set), no
    `registry:5000` entry, rule "Kubernetes MCP Server" pinned to
    `>=0.1.0,<=0.1.0`. The image tag (`v0.0.67`, `ghcr.io/containers/kubernetes-mcp-server`)
    is pinned in that repository's `template_values`, because the chart defaults
    to `latest`, and is listed in `registry_images.yaml` so mirrored fleets can
    pull it. Both preload files and the chart are deleted.
  - **Namespace.** Release and every object live in the fleet namespace, beside
    the Gateway. `fullnameOverride: fleet-mcp-<fleet>` keeps the ClusterRole
    and binding unique per fleet, so several fleets can share a cluster.
  - **Auth and NetworkPolicy move to `fleet-manager-infra-shared`.** The upstream
    chart has neither. infra-shared renders `fleet-mcp-auth` (basic-auth, or JWT
    on the OAuth path - the same choice as the monitoring plugin, so the
    hardcoded `monitoring-basic-auth` reference is gone) and a NetworkPolicy for
    the release's pods, in the fleet namespace. Both are rendered whether or not
    AI is on: infra-shared installs (100) before the assistant (102), and is
    re-applied before the release is uninstalled when AI is turned off, so the
    route never exists without its plugin. The monitoring consumer is global to
    Kong, so the caller still uses the `metrics` credential.
  - **Access.** The upstream chart creates no RBAC and renders `config.toml` from
    values. The backend (`fleet_mcp_access_values`) sets the read-only/read-write
    ClusterRole rules and the server's `read_only`, `in-cluster` provider,
    `core` toolset and Secret denial from `Fleet.streamtime_ai_access`, over any
    preset.
  - **Values allowlist.** The upstream chart has no values schema and accepts
    `extraContainers`, `initContainers`, `extraVolumes` and service-account
    overrides. The orchestrator (`_fleet_mcp_values`) passes only resources,
    replicas, placement, pod labels/annotations, image and pull secrets from
    presets, plus the backend's access values; it always sets the route, turns
    the chart's default-on Ingress off and creates its own ServiceAccount.
    Values stay editable in the bootstrap editor.
  - **Dropped:** the separate metrics port and PodMonitor. With the upstream
    chart, `/healthz` and `/metrics` share the MCP port, and admitting a scraper
    there would admit it to the assistant too.

  Not yet proven live: the Step 2 live proof ran against the wrapper chart.
  Re-run it (401 without credentials, `initialize` 200, a read through the
  ServiceAccount) on a fleet before relying on this.
