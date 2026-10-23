# Kafka endpoint routing: data plane on Envoy, monitoring on shared Kong

Retrospective spec (written after implementation, PR #1393) for review.
Rule recorded as CLAUDE.md principle 13 and `/workload` §4a.

## Objective

A Kafka cluster's endpoints are reachable according to the cluster's own
advanced config (internal / external access), never through the tailnet, and
installing one never depends on the fleet's shared Kong having a load balancer.

Before: on Tailscale fleets infra-shared made the fleet's Kong proxy ClusterIP and
pointed its external-dns target at the tailnet IP. Kafka UI / REST / schema
registry HTTPRoutes on that Kong became tailnet-only, and the Strimzi workflow
waited forever for a `kong-gateway-proxy` load balancer address
(deafening-planarian).

## Routing rule

| Endpoint | Gateway | Auth |
|---|---|---|
| Brokers | the cluster's Envoy gateway, TLS passthrough | Kafka's own (SASL / OAuth) |
| REST / HTTP bridge, Schema Registry, MDS, Kafka Connect | the cluster's Envoy gateway, one HTTPS listener per hostname | the service's own; otherwise an Envoy `SecurityPolicy` (JWT against the cluster's OAuth JWKS, scope `kafka:<id>`) |
| Monitoring / admin UIs (Kafka UI, Control Center) | the fleet's shared-services Kong (`kongGatewayApi`) | the UI's own sign-in |

The tailnet only carries Streamtime ↔ shared services.

## In scope

- `fleet-manager-strimzi`: per-endpoint HTTPS listeners on the Envoy Gateway
  (`gatewayApi.http.enabled`, default on) for REST and schema registry; routes
  attach via `httpParentRefs`; Kafka UI stays on Kong; REST with basic auth stays on
  Kong (its basic-auth plugin).
- `envoy-security-policy.yaml`: JWT `SecurityPolicy` per Envoy-served endpoint
  (issuer + JWKS from the cluster's OAuth config; `gatewayApi.jwks.requiredScopes`,
  `kafka:<cluster>` for built-in sign-in) and a `ReferenceGrant` when the JWKS
  backend Service lives in another namespace.
- JWKS over the tailnet: `streamtime-tailscale` egress targets gain `backend`
  (ClusterIP Service `streamtime-gateway-backend` selecting the egress pods, CA
  ConfigMap, `BackendTLSPolicy` with the gateway trust bundle). Envoy Gateway
  rejects ExternalName and headless Services as backends.
- Backend: `tailscale_fleet.jwks_backend_ref`, `kafka_workload_charts._envoy_jwks_values`.
- Workflows no longer wait for `kong-gateway-proxy`: Strimzi
  (`workflow.patched("strimzi-kafka-http-on-envoy")`) and CFK
  (`workflow.patched("cfk-shared-kong-from-fleet")`). Kong-served hostnames take the
  fleet's recorded shared-services address (`fleet_gateway_address`), data-plane
  hostnames the Envoy load balancer address.
- Kafka UI truststore imports every certificate of the trusted bundle (keytool reads
  only the first of a file).

## Out of scope (follow-ups)

- Kafka Connect (`streamtime-kafkaconnect`, `streamtime-cfk-kafkaconnect`) still on
  Kong and its workflow still waits for `kong-gateway-proxy`; needs a decision on its
  own Envoy gateway vs the Kafka cluster's.
- Strimzi REST with basic auth on Envoy (Envoy basic auth).
- Redpanda HTTP endpoints.
- Existing fleets do not get the egress backend from an agent upgrade (upgrades do
  not recompute Tailscale values).

## Tests

- Chart: `fleet-manager-strimzi` gateway/listener, routes, security policy;
  `streamtime-tailscale` egress backends.
- Backend: `test_kafka_envoy_auth`, `test_tailscale_fleet`.
- Orchestrator: Strimzi and CFK create no longer wait on Kong and record the right
  DNS targets (`test_create_serves_kafka_http_endpoints_from_envoy_not_kong`,
  `test_create_takes_control_center_address_from_the_fleet_not_kong`).
- Live (k3-halebeedu, popular-damselfly): brokers TLS passthrough, Kafka UI via Kong;
  REST 403 until the fleet runs the new agent chart (missing JWKS backend).

## Deviations

- Kafka UI was first moved to Envoy, then back to Kong (user decision: monitoring
  UIs are not data plane).
- The Strimzi workflow records, per HTTP endpoint, the gateway the chart routes it
  through (`strimzi_http_on_envoy`): REST with basic auth, and everything when
  `gatewayApi.http.enabled=false`, record the shared Kong address. It first recorded
  Envoy for every HTTP endpoint (PR #1393 review). Display only: DNS follows each
  route's parent gateway through external-dns.
