# Tailscale tunnel onboarding and gateway TLS certificate

## Objective

Make Tailscale the recommended way for fleets to reach a Streamtime instance, and
give the gateway (Kong) a certificate that matches the address fleets actually
use. Two onboarding changes:

1. **Tunnel step** — offer Tailscale as the recommended provider. Choosing it shows
   instructions for creating a Tailscale OAuth client and tailnet policy, collects
   the OAuth trust details, and validates them against the Tailscale API before
   saving. All details are saved to `GlobalConfiguration`.
2. **New certificate step** (after the tunnel step) — the operator either brings
   their own certificate (validated) or generates a self-signed certificate whose
   SANs cover the Streamtime instance's Tailscale names. Kong serves it.

The saved Tailscale details are the inputs `charts/streamtime-tailscale` needs
(OAuth client, tailnet domain, operator tags, egress targets). Wiring that chart
into fleet bootstrap is a follow-up (see Out of scope).

## In scope

- Tunnel provider choice in `TunnelStep` and in Organization Settings →
  Tunnel configuration: **Tailscale (recommended)** or **Other tunnel** (today's
  free-form registry/orchestrator URLs, unchanged).
- Tailscale path: step-by-step instructions, form fields, a **Validate** action,
  and save to `GlobalConfiguration`.
- New onboarding step **Gateway certificate**: bring-your-own (paste PEM) or
  generate self-signed with Tailscale SANs; validation; save to
  `GlobalConfiguration`; apply to Kong.
- Kong certificate applied through the existing DB-less admin `/config` push,
  plus a re-apply path so the certificate (and the existing tunnel host overlay)
  survives a Kong restart.
- Same settings editable after onboarding (root org administrators only).
- Docker Compose and single-node (`Dockerfile.bundled`) modes.

## Out of scope

- Installing `charts/streamtime-tailscale` during fleet bootstrap, per-fleet
  Tailscale enablement, and egress target wiring (next spec).
- Distributing the gateway certificate to agents as a CA bundle. Builtin agents
  use `tls_skip_verify: "true"` today (`orchestrator_connection.py`); switching to
  verified TLS is a follow-up once the certificate exists.
- Helm/production mode. TLS there terminates at the ingress (cert-manager,
  `letsencrypt-prod`). The certificate step is hidden in that distribution mode.
- ACME / Tailscale HTTPS (`tailscale cert`) issuance.
- Rotating or re-validating Tailscale credentials on a schedule.

## Decisions

- **Plaintext secrets in GlobalConfiguration (user decision, 2026-10-01).** The
  Tailscale OAuth client secret and the gateway TLS private key are stored as
  plaintext `GlobalConfiguration` values. This is a deliberate exception to the
  CLAUDE.md rule "Secrets via `fleet_secrets_manager` — never plaintext fields".
  Mitigations that still apply:
  - Secret values are write-only over the API. `GET` returns `*_set: true/false`,
    never the value. This matters because `TunnelConfigView` is `AllowAny` with no
    authentication (the orchestrator reads it from `activities/token.py`).
  - Secret values are never logged, never included in error bodies, and never
    returned by the validate endpoints.
  - Writes require the elevated check already used for `external_url`
    (`_can_update_post_setup_global_config`: open during setup, root org
    administrators afterwards).
- **Validation is server-side.** The browser never calls Tailscale. The backend
  performs every check and returns a per-check result list.
- **Self-signed, not org-CA-signed.** The generated certificate is self-signed as
  requested. `CertificateAuthorityService` is not used for this.

## GlobalConfiguration keys

| Key | Value | Secret |
|---|---|---|
| `tunnel_provider` | `tailscale` \| `other` (empty = `other`) | |
| `tailscale_tailnet_domain` | e.g. `tail1234.ts.net` | |
| `tailscale_oauth_client_id` | OAuth client ID | |
| `tailscale_oauth_client_secret` | OAuth client secret | yes (plaintext) |
| `tailscale_operator_tags` | default `tag:k8s-operator` | |
| `tailscale_proxy_tags` | default `tag:k8s` | |
| `tailscale_streamtime_hostname` | instance MagicDNS name, e.g. `streamtime.tail1234.ts.net` | |
| `tailscale_validated_at` | ISO-8601 time of last successful validation | |
| `gateway_tls_mode` | `default` \| `byo` \| `self_signed` | |
| `gateway_tls_cert_pem` | leaf certificate followed by any chain | |
| `gateway_tls_key_pem` | unencrypted private key | yes (plaintext) |
| `gateway_tls_sans` | JSON list of SANs on the certificate | |
| `gateway_tls_expires_at` | ISO-8601 | |

When the Tailscale path is saved, `orchestrator_tunnel_url` is set to
`<tailscale_streamtime_hostname>:8443`, so `resolve_orchestrator_connection`, the
Kong `temporal-grpc` host/SNI overlay, and agent install keep working unchanged.

## Tailscale validation

Endpoint: `POST /organizations/{org}/tunnel-config/tailscale/validate/`. Body is
the form values; the client secret may be omitted to reuse the saved one. Returns
`{"ok": bool, "checks": [{"id", "status": "ok"|"warning"|"error", "detail"}]}`.
Nothing is saved by this call.

| Check | How | On failure |
|---|---|---|
| `credentials` | `POST https://api.tailscale.com/api/v2/oauth/token`, client-credentials grant | error: "Tailscale did not accept this client ID and secret." |
| `scopes` | The token response's `scope` must include `all` (every scope, read and write) | error: partial scopes, `all:read`, or no reported scope |
| `operator_tag` | Create a non-reusable, ephemeral, unpreauthorized auth key tagged with the operator tags (`POST /api/v2/tailnet/-/keys`), then delete it | error: the OAuth client is not allowed to use the operator tag; show the `tagOwners` snippet |
| `tailnet_domain` | `GET /api/v2/tailnet/-/devices`; device names should end in `.<domain>` | warning if devices exist and none match |
| `streamtime_host` | Hostname must end in `.<domain>`, and a device with that name should exist | error if the suffix is wrong; warning if no device found |
| `reachability` | Existing TCP probe (`_probe_orchestrator_sync`) to `<hostname>:8443` | warning (the backend container may not be on the tailnet) |

Required tailnet policy, shown in the instructions:

```json
"tagOwners": {
  "tag:k8s-operator": [],
  "tag:k8s": ["tag:k8s-operator"]
}
```

`PUT /tunnel-config/` with `tunnel_provider: "tailscale"` re-runs the error-level
checks and refuses to save (400) if any fail. Exact scope strings in the token
response must be confirmed against the live API during implementation.

## Gateway certificate

Endpoints (all under `/organizations/{org}/gateway-tls/`):

- `GET` — mode, SANs, issuer, expiry, `key_set`. Never the key.
- `POST validate/` — BYO: certificate + key + optional chain. Runs
  `validate_certificate_key_pair` (parses, current, key matches). Also parses the
  chain, and checks the SANs cover the required hostnames (error if
  `tailscale_streamtime_hostname` is missing, warning for other configured
  hostnames). Returns `parse_cert_details` output plus checks.
- `POST generate/` — self-signed: RSA 2048 (or P-256), 825-day validity, SANs =
  `tailscale_streamtime_hostname`, `orchestrator_server_name` /
  `orchestrator.streamtime.local`, and the API host from
  `fleet_manager_external_url`, plus optional extra names supplied by the user.
  Returns the details; it is saved only on `PUT`.
- `PUT` — save (`byo` or `self_signed`) or reset to `default`, then apply to Kong.

Required hostnames come from GC, so the step must follow the tunnel step.

## Kong integration

- New `core/services/gateway_sync.py` with `apply_gateway_overlay()`. It reads GC
  and patches Kong's declarative config in one push:
  - `temporal-grpc` route hosts/SNIs and `oidc` route hosts (moved out of
    `TunnelConfigView.put`, same behaviour).
  - A `certificates` entry with `snis` set to the certificate's DNS SANs. Kong
    serves it for those SNIs. The `KONG_SSL_CERT` default
    (`certs/streamtime.local.crt`) still serves every other name.
- Called from the tunnel `PUT`, the gateway-tls `PUT`, and an internal
  `POST /internal/gateway-sync/`, which is not routed through Kong and is limited
  to the `RBAC_BYPASS_HOSTS` path.
- `fleet-manager-gateway/build.sh` (and the bundled start script) start a
  background loop. Once the Kong admin API answers, it calls the internal sync
  once. This also fixes an existing gap: tunnel hosts pushed to Kong are lost when
  the gateway container restarts.
- A Kong push failure is reported in the `PUT` response (`gateway_applied: false`
  with a plain-language reason). Today it is only logged.

## UI

`TunnelStep`:

- A provider choice: **Tailscale (recommended)** / **Other tunnel**.
- The Tailscale panel shows numbered instructions:
  1. Add the `tagOwners` policy (copyable block).
  2. Create an OAuth client with **All** scopes (read and write).
  3. Install Tailscale on this host and note its MagicDNS name.
- Fields, each with `helperText`: Tailnet name, OAuth client ID, OAuth client
  secret (password field; "Saved — leave blank to keep" when set), Streamtime
  tailnet address, Operator tag, Device tag.
- **Validate** shows the per-check results. **Save** is enabled only after a
  passing validation of the current values.
- Other tunnel: today's form, unchanged.

New `GatewayCertificateStep` after `TunnelStep` (wizard indexes shift by one):

- Choice: **Generate a self-signed certificate (recommended for Tailscale)** /
  **Use my own certificate** / **Keep the built-in certificate** (skip).
- Generate: shows the SANs it will use, plus optional extra names, then
  **Generate**, preview details, **Save**.
- Bring your own: certificate, chain, and private key text areas, then
  **Validate**, details and checks, **Save**.
- Hidden in Helm distribution mode.
- A new `SystemSetup.gateway_tls_complete` flag (migration), set on save or skip.

The same panels appear in Organization Settings for root org administrators.

Wording follows the CLAUDE.md terminology table. Use "Gateway certificate", not
"Kong", and "Operation ID", not workflow IDs.

## API contract impact (`/regression-check`)

- `tunnel-config` GET/PUT gain fields. The change is additive, and existing fields
  are unchanged. Consumers: frontend `setupService.js`, orchestrator
  `activities/token.py` (reads GET; unaffected because the new fields are
  additive and contain no secrets).
- New endpoints: `tunnel-config/tailscale/validate/`, `gateway-tls/`,
  `gateway-tls/validate/`, `gateway-tls/generate/`, `internal/gateway-sync/`.
- CLI / MCP: no existing commands for tunnel config, so no change required.
  Optional read-only MCP exposure is out of scope.

## Phases

1. **Backend: Tailscale.** GC keys, validate endpoint (Tailscale API mocked in
   unit tests; this is an external system), tunnel-config PUT/GET changes with
   write-only secrets, elevated-permission check.
2. **Backend: gateway TLS + Kong sync.** `gateway_sync.py`, gateway-tls endpoints,
   self-signed generation, BYO validation, `SystemSetup` migration, `build.sh`
   re-sync loop.
3. **Frontend.** `TunnelStep` provider choice and Tailscale panel,
   `GatewayCertificateStep`, settings panels, tests.
4. **Exercise.** Live API pass (`/api-call`), then the onboarding UI against a
   real tailnet and OAuth client, checking that Kong serves the new certificate
   (`openssl s_client -servername <hostname>`).

## Tests

- Validate: bad credentials; missing scope; tag not permitted; domain mismatch
  warning; hostname outside the tailnet; secret omitted reuses the saved one;
  secret never present in any response or log record.
- Tunnel PUT: refuses an invalid Tailscale config; elevated check after setup;
  `GET` returns `client_secret_set` only.
- Gateway TLS: expired, not-yet-valid, mismatched key, encrypted key, missing
  required SAN (error), garbage outside PEM blocks; generate covers the expected
  SANs; `PUT` pushes a `certificates` entity (Kong admin mocked); `GET` never
  returns the key.
- Kong sync: re-applies tunnel hosts and the certificate together; idempotent.
- Frontend: provider switch, validate-before-save gating, secret placeholder,
  step skip, Helm mode hides the step.

## Deviations

- **2026-10-05 — the console is served through Kong** (user decision), so it uses the
  certificates the backend stores, like the API. Compose: Kong route `console`
  (`console.streamtime.local`) → the Vite dev server over plain HTTP (`HTTPS=false`, no key
  mounted); the console URL is `https://console.streamtime.local:8443` (Kong
  `frontend_base_url`, `VITE_REDIRECT_URL`, Keycloak client URLs, CORS); hot reload over
  `wss` on 8443 (`VITE_HMR_CLIENT_PORT`); no traces for the route (route-level
  opentelemetry, `sampling_rate: 0`). Single-node: its public address is Kong's
  `https://localhost:8443` (`FLEETMANAGER_EXTERNAL_URL`, frontend env, Kong auth handler;
  8443 published), Kong already routing `/` to nginx. Kong's proxy buffers are 16 KB
  (`KONG_NGINX_PROXY_PROXY_BUFFER_SIZE`): the console's Content-Security-Policy is ~5.5 KB and
  the default 4 KB returned 502. A generated built-in certificate also covers the API host
  (`builtin_generated_sans`; `localhost` on single-node).

- **2026-10-05 — Kong pulls; the backend pushes nothing** (user decision). Pushing
  route hosts with `POST /config` was lost on every Kong restart, and the start hook that
  re-pushed them ran once, before the backend was serving (seen live: Kong up at +3 s,
  backend at +29 s; fleets on k3-badami then got 404 pulling the agent image over the
  tailnet). Now `temporal-grpc`, `registry` and a new `oidc-tunnel` route are host-less in
  kong.yml; `oidc` keeps only the hosts it shares with the `backend` route. In the access
  phase, kong-authz-proxy (`route_hosts.lua`, `config.route_hosts.routes`) checks the Host
  against that route's list from `GET /organizations/{org}/gateway-routes/` (internal key),
  fetched on first use and cached (60 s; the last list is kept for a day when the backend
  is unreachable; no list at all → 503). `POST …/gateway-syncs/`, `sync-overlays.sh`, its
  `build.sh` / `gateway.service` hooks and `apply_overlay` are gone. A tunnel, tailnet or
  certificate change only drops Kong's two cache entries (`DELETE /cache/{key}`, best
  effort; otherwise the TTL applies). kong.singlenode.yaml / kong.trial.yaml were already
  host-less and stay ungated. Certificates are unchanged: certificate phase, by SNI.

- **2026-10-05 — Kong pulls certificates from the backend with a TTL** (user decision; in
  kong-authz-proxy, not a new plugin). The global instance's `certificate` phase
  (`kong-authz-proxy/tls.lua`, `config.tls.enabled`) reads the set from `kong.cache`
  (`streamtime-tls:certificates`, `cache_ttl` 300 s); on a miss it fetches the internal
  `GET /organizations/{org}/gateway-certificates/` (internal service key; tailnet
  certificate first, built-in last and `default`), picks by SNI, and serves the last set
  for `stale_ttl` (3600 s) if a refresh fails, else Kong's own default. The gateway sync no
  longer pushes certificates: it removes any an earlier push left and `DELETE`s the cache
  entry so a saved certificate is served on the next handshake. `internal_service_key` is
  referenceable; the global instances use `{vault://env/internal-service-key}`
  (bundled/prod configs had no key before). docker-compose drops `KONG_SSL_CERT` and the
  gateway's `./certs` mount; `kong.yml` no longer embeds the certificate and key.
  Note: Kong's admin API (`GET /cache/{key}`) exposes the cached keys, as `/config` did.

- **2026-10-05 — certificates are typed settings; no verb endpoints** (user decision).
  `/organizations/{org}/gateway-tls/` and `…/validate/` became
  `GET|PUT /organizations/{org}/settings/gateway-certificate/`, validation is
  `PUT ?dry_run=true` (all modes), and the write body has a typed serializer (per-field
  errors). The built-in certificate is `…/settings/builtin-certificate/` the same way.
  Kong's start hook `POST …/gateway-tls/sync/` became `POST /organizations/{org}/gateway-syncs/`
  (one re-apply run per call); `sync-overlays.sh`, the JWT exemption and
  `regenerate-gateway-cert.sh` follow. Onboarding keeps `/setup/gateway-tls/` and
  `/setup/gateway-tls/validate/` (setup-window only) for now.

- **2026-10-04 — the built-in certificate lives in GlobalConfiguration too** (user
  decision: "GC is the source"). Keys `gateway_builtin_cert_pem`, `_key_pem`, `_sans`,
  `_expires_at`, `_source` (`bundled` | `generated` | `uploaded`). Seeded once at backend
  start from the mounted `certs/streamtime.local.*` (docker-compose mounts them read-only
  at `/certs`), otherwise generated for `*.streamtime.local`. The gateway sync serves it
  under the id kong.yml declares (`534f0818…`), so it replaces the file copy, and adds it
  where the config has none (bundled). The tailnet certificate wins shared names.
  Administrators generate a new one or upload their own (must cover the API host) through
  a typed setting: `GET|PUT /organizations/{org}/settings/builtin-certificate/`, with
  `PUT ?dry_run=true` to validate without saving (user: no verb endpoints; typed
  `/settings` resources). UI: Settings → Gateway certificate → Streamtime Certificate. Kafka OAuth trust
  (`get_builtin_tls_trusted_cert`, `oidc-credentials`) is `gateway_trust_bundle()`: both
  certificates from GlobalConfiguration, no disk reads. Seen live: brokers fetching JWKS
  over the tailnet trusted only the disk certificate and crash-looped.
  Not moved: Kong's fallback certificate for unknown names (`KONG_SSL_CERT`), Keycloak's
  keystore, the frontend dev server and the containers' system CA (`update-certs.sh`)
  still read the files; replacing the built-in certificate means those must be updated.

- **2026-10-01 — Single PR.** The four phases ship together in one PR (user decision).
- **2026-10-01 — Onboarding uses /setup/ endpoints.** `main` (a16d97883) moved onboarding
  networking to the unauthenticated, setup-window-only `/setup/tunnel-config/`. The new
  endpoints follow it: `/setup/tunnel-config/tailscale/validate/`, `/setup/gateway-tls/`,
  `/setup/gateway-tls/validate/` for onboarding; `/organizations/{org}/tunnel-config/tailscale/validate/`,
  `/organizations/{org}/gateway-tls/`, `/organizations/{org}/gateway-tls/validate/` for Settings
  (root org administrators after setup).
- **2026-10-01 — No `generate/` endpoint.** `PUT gateway-tls/` with `mode: self_signed`
  generates and saves in one call. A separate generate step would have had to send the
  private key to the browser for it to come back on save.
- **2026-10-01 — Generated SANs.** The self-signed certificate covers only the Tailscale
  hostname plus user-supplied extra names. It must not claim `orchestrator.streamtime.local`:
  the local compose agent verifies that name against `certs/streamtime.local.crt` with
  verification on, and the managed certificate would take that SNI over in Kong.
- **2026-10-01 — Re-sync endpoint path.** `POST /organizations/{org}/gateway-tls/sync/`
  (internal key, JWT-exempt like `api-keys/validate/`) instead of `/internal/gateway-sync/`.
  Called by `fleet-manager-gateway/sync-overlays.sh` from `build.sh` (compose) and
  `gateway.service` `ExecStartPost` (bundled). Helm is unaffected (Kong ingress controller).
- **2026-10-01 — Helm detection.** `/setup/status/` gains `gateway_tls_supported`
  (false when `KUBERNETES_SERVICE_HOST` is set). The wizard always shows the step and
  explains when it does not apply, so step indexes stay fixed.
- **2026-10-01 — Migration.** `0175_systemsetup_gateway_tls_complete` adds the flag on top of
  `main`'s `0174_merge_20261001_0901` (which resolved the two 0173 leaves).
- **2026-10-01 — Reset.** `/setup/reset/` clears the new keys and re-syncs Kong so a
  deleted certificate stops being served immediately.
- **2026-10-01 — Privileged OAuth client required.** The OAuth client must have all scopes
  (Tailscale reports `scope: all`), not only the operator's minimum (Devices Core, Auth Keys,
  Services). Partial scopes, `all:read`, and an unreported scope are errors. Confirmed against
  the live API: a client created with All selected returns `scope: all`.
