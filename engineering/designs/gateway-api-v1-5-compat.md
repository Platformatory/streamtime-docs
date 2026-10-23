# Gateway API v1.5 compatibility and GatewayClass acceptance

Retrospective spec (written after implementation, PR #1393) for review.

## Objective

Kafka workloads and the fleet's shared Kong install on clusters with Gateway API v1.5
(the CRDs Envoy Gateway v1.8 installs), and a fresh infra-shared install never waits
forever on an unaccepted GatewayClass.

## Findings

- Gateway API v1.5.1 serves `TLSRoute` only as `v1`. The CFK and Warpstream charts
  hard-coded `v1alpha2`: `helm install` failed with "no matches for kind TLSRoute in
  version v1alpha2" on k3-halebeedu (female-turtle). Older clusters (k3-badami) still
  served `v1alpha2`, hiding it. Strimzi was unaffected (its operator creates `v1`).
- infra-shared applies `GatewayClass` before `GatewayConfiguration` (alphabetical, both
  unknown kinds to Helm). The Gateway Operator checks the configuration once and leaves
  the class `Accepted=False`; the nudge was a `post-install` hook, which runs only after
  `helm install --wait`, which never finished (working-tyrannosaurus, global-rabbit).

## Design

- `fleet-manager-cfk` / `-warpstream`: helper `tlsRouteApiVersion` → `v1` when
  `.Capabilities` has `gateway.networking.k8s.io/v1/TLSRoute`, else `v1alpha2`.
- Orchestrator preflight (`ENVOY_GATEWAY_REQUIRED_API_RESOURCES`): `tlsroutes` at `v1`
  (`tcproutes` stays `v1alpha2`, the only version served).
- infra-shared: the nudge is a regular release Job `kong-gatewayclass-accept-<revision>`:
  waits for the GatewayConfiguration, re-annotates the class every 15 s until Accepted
  (~10 min cap). New namespaced Role to read that GatewayConfiguration.

## Tests

- Charts: TLSRoute version with and without the capability (CFK, Warpstream);
  GatewayClass Job is not a hook, RBAC.
- Live: dry run of the old build reproduced the error, the fixed chart passed; installed
  in place, the `v1` TLSRoute was accepted and the broker served TLS through Envoy;
  supporting-swordfish bootstrapped with the new infra-shared without the hang.
