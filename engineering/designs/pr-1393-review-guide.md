# PR #1393 review guide

Map of everything in the PR to its spec, so each part can be reviewed against the plan
that describes it. Specs marked *retrospective* were written after implementation;
every spec's Deviations section records where implementation drifted.

| Area | Spec | Main code |
|---|---|---|
| Tailscale onboarding, tailnet gateway certificate | `tailscale-tunnel-and-gateway-tls.md` | `core/services/tailscale.py`, `tunnel_config.py`, onboarding UI |
| Fleet connectivity over the tailnet (operator, egress, private ingress, DNS) | `tailscale-fleet-connectivity.md` | `charts/streamtime-tailscale`, `core/services/tailscale_fleet.py`, infra-shared `kong-gateway-tailnet.yaml` |
| Tailscale bundled with the agent chart | `tailscale-agent-dependency.md` | `charts/streamtime-agent`, `workflows/install_streamtime_agent.py` |
| Local registry over the tailnet | `tailscale-registry-over-tailnet.md` | `registry_rewrite.py`, registry mirror DaemonSet |
| Elective bootstrap by workload, virtual clusters as a streaming service, sizing | `fleet-bootstrap-overhaul.md` | `fleet_workloads*.py`, `bootstrap_resolver.py`, `fleet_provider_base.py`, `uninstall_releases.go`, FleetWorkloads UI, migrations 0176–0177 |
| Kafka endpoints: data plane on Envoy (JWT), monitoring UIs on Kong; no Kong load-balancer wait | `kafka-endpoint-routing.md` *(retrospective)* | `charts/fleet-manager-strimzi`, `envoy-security-policy.yaml`, `egress-backends.yaml`, `workflows/strimzi.py`, `cfk.py` |
| Gateway certificates in GlobalConfiguration, Kong certificate phase, trust bundle, agent TLS verification, console via Kong | `gateway-certificates-and-trust.md` *(retrospective)* | `gateway_tls.py`, `views/settings/`, `kong-authz-proxy/tls.lua`, `orchestrator_connection.py`, kong.yml / compose / single-node env |
| Kong pulls tunnel route hosts (no config push) | `gateway-route-hosts.md` *(retrospective)* | `kong-authz-proxy/route_hosts.lua`, `gateway_sync.py`, kong.yml routes |
| STDNS ownership records, external-dns timeouts, explicit DNS cleanup on Kafka delete | `stdns-dns-reliability.md` *(retrospective)*, after `dns-record-deletion.md` | `internal/stdnswebhook`, `pkg/stdnsclient`, `external_dns_bootstrap.py`, `stdns_domain_service.py`, `workflows/dns_cleanup.py` |
| Kafka clusters reuse the fleet certificate | `kafka-fleet-certificate-reuse.md` *(retrospective)* | `secretcopy_controller.go`, Kafka charts' `external-certificate.yaml`, `_reuse_fleet_certificate` |
| One gateway certificate from a Streamtime CA, orchestrator address in one place, no tunnel wildcards, upgrades re-apply network values | `gateway-single-certificate-and-tailscale-main-path.md` | `gateway_tls.py`, `orchestrator_connection.py`, `gateway_sync.py`, `kong-authz-proxy` (`backend-tunnel`, `/oidc` rewrite), `update_streamtime_agent.py`, `BuiltinCertificatePanel` |
| Gateway API v1.5 (TLSRoute v1), GatewayClass acceptance during install | `gateway-api-v1-5-compat.md` *(retrospective)* | CFK / Warpstream `kafka-tls-routes.yaml`, infra-shared `kong-gatewayclass-reconcile.yaml`, preflight |

Cross-cutting rules added to CLAUDE.md: principle 13 (data plane on Envoy, monitoring on
shared Kong); `/workload` skill §4a.

## Pushes required after merge (user-run)

- Images: agent (worker, operator, controller), `stdns-webhook`, gateway (single-node).
- Charts: `fleet-manager-strimzi`, `-cfk`, `-warpstream`, `fleet-manager-infra-shared`,
  `streamtime-tailscale`, `streamtime-agent-helm`, `streamtime-operator-helm`.

## Known follow-ups (not in this PR)

- Kafka Connect and Redpanda endpoints on Envoy; Strimzi REST basic auth on Envoy.
- STDNS surfacing Cloudflare rejections.
- Package rules pin `ghcr.io` 1.1.15 Kafka charts: local builds must be pinned per cluster.
