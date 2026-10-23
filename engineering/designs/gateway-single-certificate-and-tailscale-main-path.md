# One gateway certificate, Tailscale as the main path

Status: implemented (PR #1393). Decisions by the user on 2026-10-06: land in
#1393 (the second certificate never reached `main`, so no migration for real
installs); sign generated certificates with a Streamtime CA; Tailscale is the
main path, other tunnels are the alternative.

## Objective

Remove the duplicated plumbing PR #1393 grew while Tailscale was added next to
the older tunnels:

1. Two gateway certificates (built-in `*.streamtime.local` and the tailnet /
   bring-your-own one) with two trust paths, two required-name lists and two
   Settings panels.
2. Two sources for the orchestrator address: `orchestrator_tunnel_url` is saved,
   then overridden by the tailnet address in `resolve_orchestrator_connection`.
3. Static tunnel host wildcards (`STATIC_OIDC_HOSTS`, `STATIC_TEMPORAL_HOSTS`,
   `STATIC_REGISTRY_HOSTS`, kong.yml's `*.pinggy-free.link`) that accept any
   ngrok / Cloudflare / pinggy name although Kong now pulls the saved hosts.
4. Agent upgrades keep the Tailscale and trust values from install time, so every
   Tailscale-side or certificate change meant reinstalling the fleet.

## Design

### 1. One certificate, signed by a Streamtime CA

- **Streamtime CA**: generated once (RSA 3072, 10 years, `ca=True`,
  `path_length=0`) and stored in GlobalConfiguration
  (`streamtime_ca_cert_pem`, `streamtime_ca_key_pem`; the key in plaintext, same
  product decision as the other keys). Never rotated automatically.
- **The gateway certificate** (the existing `gateway_builtin_*` keys) has one of
  three sources:
  - `generated`: a leaf signed by the CA (825 days), covering the required names
    plus any extra names.
  - `uploaded`: an administrator's certificate, chain and key, validated against
    the required names.
  - `bundled`: the mounted `certs/streamtime.local.*` pair, imported once on
    first start (kept until #1407 removes it).
- **Required names**, in one function: the Streamtime API host when it is a real
  hostname, the `*.streamtime.local` names, and the tailnet name when Tailscale
  is the tunnel provider (it also serves the registry over the tailnet).
- **Re-issue on name changes**: when the required names change (Tailscale saved,
  Streamtime address changed) a `generated` or `bundled` certificate that no
  longer covers them is re-issued from the CA at once. An `uploaded` one is not
  touched; the change is refused with "upload a certificate that also covers X,
  or switch to a generated certificate".
- **Trust bundle** (`gateway_trust_bundle`, what fleets and Kafka OAuth clients
  trust): the CA certificate, plus the uploaded chain when the source is
  `uploaded`, plus the bundled certificate when it is `bundled`. Generated
  leaves can be re-issued without any fleet change.
- **Removed**: the second certificate (`gateway_tls_*` keys,
  `settings/gateway-certificate/`, `read_active_certificate`,
  `GatewayCertificatePanel`, the onboarding Gateway certificate step's second
  panel, `GatewayCertificateSettings`). A data migration deletes the
  `gateway_tls_*` keys (dev installs of this branch only).
- **Kong** still gets a list from `gateway-certificates/`; it now has one entry.
- The Settings certificate panel offers "Download the Streamtime CA" so browsers
  and machines trust every generated certificate once.

### 2. The orchestrator address in one place

`orchestrator_address()` (in `orchestrator_connection.py`) is the only reader:

| Tunnel provider | Address |
|---|---|
| Tailscale | `<tailnet host>:8443` (derived, never stored) |
| Other tunnel | saved `orchestrator_tunnel_url` |
| None | the built-in default (Kong on the compose network) |

Saving Tailscale clears `orchestrator_tunnel_url`; `resolve_orchestrator_connection`,
`gateway_sync.route_hosts` and `builtin_oidc` call `orchestrator_address()`.

### 3. Route hosts: only what is configured

- `route_hosts` lists exactly the canonical names plus the configured addresses:
  the saved tunnel hosts (other-tunnel path), the tailnet host, and the external
  URL host. The `STATIC_*` wildcard lists are deleted; an unknown tunnel host gets
  Kong's 404.
- kong.yml drops `*.pinggy-free.link` from `backend` and `oidc`. The external URL
  (any provider) is served by a host-less `backend-tunnel` route that
  `kong-authz-proxy` gates by the backend's list and authenticates exactly like
  `backend` (`backend.routes` accepts both names).

### 4. Agent upgrades recompute network and trust values

- `UpdateStreamtimeAgentWorkflow` snapshots, at start, the values the backend
  computes for a fresh install of this fleet (`get_streamtime_agent_helm_values`:
  Tailscale values, `gatewayCA`, the orchestrator address and TLS settings) and
  merges them over the upgrade's values, so every upgrade applies the current
  network settings. The operator release gets the same `gatewayCA`.
- Settings → Tailscale and certificate saves say which fleets need the change
  and offer "Apply to fleets", which runs a values-only agent update per fleet.

### 5. Tailscale as the main path

- Onboarding and Settings lead with Tailscale; "Use another tunnel" is the
  alternative, not a peer choice.
- Tailscale validation refuses a Streamtime address fleets cannot use
  (`localhost`, loopback, single-label names), and the agent values never alias
  such names.
- Validation results say "Credentials verified"; fleet connectivity is proven by
  the first agent install. Proxy tags are checked against the tailnet policy's
  `tagOwners` (the operator tag must own each proxy tag).

## Out of scope

- In-fleet pull-through registry cache (zot) and removing registry rewrites:
  roadmap step 5, its own PR.
- Domain-derived names, Keycloak behind Kong, container trust from the backend:
  #1407.

## Risks

- Re-issuing a `bundled` certificate on compose changes what Kong serves for
  `*.streamtime.local`; containers that trust the bundled file (#1405) must also
  trust the CA. The compose mounts gain the CA file written by the backend, or the
  re-issue keeps the bundled certificate for those names until #1407.
- Fleets installed before the CA trust the old self-signed leaf; their next agent
  upgrade (item 4) moves them to the CA.

## Tests

- CA generated once; generated leaf verifies against it; re-issue keeps the CA.
- Required names: Tailscale adds the tailnet name; uploaded certificate missing
  it is refused with the remedy; generated one is re-issued.
- `orchestrator_address()` per provider; Tailscale save clears the stored URL.
- `route_hosts` contains no wildcard and exactly the configured hosts; Lua spec:
  `backend-tunnel` is authenticated like `backend`.
- Upgrade workflow merges the recomputed values (replay-safe patch).
- Frontend: one certificate panel; CA download; Tailscale-first tunnel step.

## Deviations

- **Onboarding keeps the current certificate** with `source: "keep"` on
  `/setup/gateway-tls/` (the same shapes as `settings/builtin-certificate/`);
  it is refused when a required name is missing. The "saved but not applied"
  message stays on screen until the user continues.
- **The plugin's own tunnel list went too**: `kong-authz-proxy` rewrote the
  `/oidc` Host for hosts matching `tunnel_host_patterns` (bore, ngrok, pinggy,
  Cloudflare) after fetching `tunnel-config/`. It now rewrites on the
  host-gated `oidc-tunnel` route, which accepts only the backend's list;
  `tunnel_host_patterns` and `tunnel_config_cache_ttl` are removed.
- **"Apply to fleets" is not a separate button**: every agent update (Update
  Agent, or the automatic upgrade) now applies the current network and trust
  values, so the existing action is the way to push a change.
- **Localhost Streamtime address**: rather than refusing Tailscale with a
  single-node `https://localhost:8443`, names fleets cannot use
  (`fleet_reachable`) are never egress aliases; fleets reach the API and OIDC
  on the tailnet name.
- **Proxy tag ownership** (`tagOwners`) is not checked yet; validation says what
  it proves ("Credentials verified…") and the first agent install proves the rest.
- `scripts/regenerate-gateway-cert.sh` re-issues from the CA through
  `settings/builtin-certificate/` and verifies Kong against the CA.
