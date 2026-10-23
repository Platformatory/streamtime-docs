# Kong pulls tunnel route hosts (no config push)

Retrospective spec (written after implementation, PR #1393) for review.
User decision: "backend should not push … Kong should pull this lazily and cache it".

## Objective

Kong routes tunnel and tailnet traffic correctly from the moment it starts, with no
runtime configuration pushed into it.

Before: the backend rewrote Kong's DB-less config (`POST /config`) to add tunnel and
tailnet hosts to the `temporal-grpc`, `oidc` and `registry` routes. Kong reloads
kong.yml on every start, and the start hook re-pushed once, before the backend was
serving (Kong up at +3 s, backend at +29 s). Fleets then got 404 pulling the agent image
over the tailnet (global-rabbit).

## Design

- kong.yml routes match on path/protocol, not host: `temporal-grpc` (grpc/grpcs, `/`),
  `registry` (http/https, `/v2`), and a new `oidc-tunnel` (`/oidc`). `oidc` keeps only the
  hosts it shares with the `backend` route so `/oidc` on the API host still wins over `/`.
  Routes that list a host (api., dashboard., identity., fleet-manager-gateway) still win
  on their own hosts.
- `kong-authz-proxy` `route_hosts.lua`, access phase: for routes listed in
  `config.route_hosts.routes`, the request Host (`:authority` for gRPC) must match that
  route's list (`*.domain` matches any name under it). Lists come from
  `GET /organizations/{org}/gateway-routes/` (internal key), fetched on first use and
  cached (`cache_ttl` 60 s, last list kept `stale_ttl` 1 day); no list at all → 503; an
  unlisted host → 404. The temporal-grpc service's plugin instance gates its route.
- Backend `gateway_sync`: `route_hosts()` (static tunnel hosts + saved tunnel addresses +
  the tailnet registry address) and `drop_gateway_caches()` (DELETE both cache keys on
  a tunnel/Tailscale/certificate change; best effort, TTL otherwise).
- Removed: `apply_overlay`, `sync_kong_gateway`, `POST .../gateway-syncs/`,
  `sync-overlays.sh` and its `build.sh` / `gateway.service` / `Dockerfile.bundled` hooks.
- kong.singlenode.yaml / kong.trial.yaml were already host-less and stay ungated.

## API contract impact

Added `GET /organizations/{org}/gateway-routes/`; removed `POST .../gateway-syncs/`. Both
internal (Kong only); no SDK, CLI, MCP or frontend consumer.

## Tests

- Backend: `test_gateway_sync` (route hosts, cache drop sends no config),
  `test_network_views` (internal key), tunnel config views, OpenAPI path manifest.
- Gateway: `05-route_hosts_spec.lua` (matching, gating, schema).
- Live after a gateway restart with nothing pushed: registry and `/oidc` over the
  tailnet 200; unlisted hosts 404; API, `/oidc` on the API host 200; agent reconnected.
