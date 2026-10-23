# Kafka clusters reuse the fleet's certificate

Retrospective spec (written after implementation, PR #1393) for review.
User decision after a risk review (2026-10-06).

## Objective

A Kafka cluster on a fleet with automatic certificates uses the fleet's existing
wildcard certificate instead of having cert-manager issue an identical one.

Before: the fleet (infra-shared) and every Strimzi/CFK/Warpstream cluster each issued
`*.<domain>` + `<domain>` from the same ClusterIssuer. Let's Encrypt allows 5 per week for
an identical set of names; wet-gerbil's broker certificate was refused (429) and its
brokers could not start.

## Design

- Charts (`fleet-manager-cfk`, `-strimzi`, `-warpstream`): value
  `certManager.fleetCertificateNamespace` (declared in values and schemas). In ACME mode,
  when set, `external-certificate.yaml` renders ConfigMap `tls-kafka-external-copy`
  (label `streamtime.ai/secret-copy: "true"`; data `sourceNamespace`, `sourceName`,
  `targetName`) instead of a Certificate. Unset: unchanged.
- Backend `_reuse_fleet_certificate`: sets it to the fleet's namespace for the main
  charts only when the cluster's domain equals the fleet's (case / trailing dot
  normalised); an explicit value wins.
- infra-shared: the fleet Certificate's `secretTemplate` labels its Secret
  `streamtime.ai/shareable: "true"` (applied without reissue).
- Operator `SecretCopyReconciler` (`internal/controller/secretcopy_controller.go`):
  watches labelled ConfigMaps (manager ConfigMap cache limited to them); reads Secrets
  uncached; copies only shareable sources; the copy is controlled by the request
  (garbage-collected with the chart), adopts a pre-existing Secret (cert-manager's on
  upgrade), drops the shareable label, records `streamtime.ai/copied-from`; status on the
  request (`streamtime.ai/secret-copy-status`: Ready / Waiting / Refused / Invalid);
  re-reads every 10 min (renewal), 30 s while the source is missing.
- Orchestrator: no per-cluster Certificate status wait when reusing; the Kafka readiness
  waits cover it (brokers need the Secret).

## Risks (reviewed before implementation)

| Risk | Mitigation / verdict |
|---|---|
| One wildcard key across the fleet's Kafka namespaces | Each per-cluster key was already valid for the whole domain; a compromise now means fleet-wide rotation. Accepted. |
| Copy-any-Secret escalation via ConfigMaps | Only `streamtime.ai/shareable` sources are copied. |
| Overwriting or deleting a namespace's Secrets via ConfigMaps (PR #1393 review) | An existing target is replaced only when it is the request's own copy, or a cert-manager Secret whose Certificate no longer exists (the upgrade case). Anything else — unmanaged, owned by something else, or still issued by a Certificate — is left alone and the request reports `Refused`. |
| Stale copies after renewal | 10-minute resync; Let's Encrypt renews 30 days early. |
| Upgrade of existing clusters | cert-manager owner refs are off: removing the Certificate keeps the Secret (annotated `cert-manager.io/certificate-name`); the controller adopts it once that Certificate is gone. |
| Custom Kafka domain / manual certificates | Not reused (domain must equal the fleet's; ACME only). |
| Fleet certificate not issued yet | The copy waits; previously the cluster's own issuance would hit the same limit. |
| Memory | No Secret cache; ConfigMap cache limited to requests. |

## Out of scope

- Redpanda and KVC charts (no per-cluster ACME certificate / different path).
- Rotating the shared key on compromise (manual).

## Tests

- Go: copy, renewal follow, adopt existing Secret, refuse non-shareable, wait for source.
- Charts: copy request vs Certificate vs nothing, per chart; infra-shared shareable label.
- Backend: `test_reuse_fleet_certificate`.
- Orchestrator: no certificate wait when reusing; kept otherwise.

## Rollout

Agent image (operator) and the four charts must be pushed; existing clusters switch on
their next upgrade.
