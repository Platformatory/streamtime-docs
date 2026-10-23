# Fleet alert rules migration (existing fleets)

New fleets receive editable alert rules (`fm-alert-rules` Helm release) during bootstrap automatically. For fleets and Kafka clusters created before this feature:

## Prerequisites

1. Sync the `fleet-manager-prometheus-rules` package (`POST .../packages/sync/` or package sync workflow).
2. Ensure the fleet agent is connected and can run Helm upgrades.
3. Confirm kube-prometheus-stack uses `defaultRules.create: false` (Fleet Manager preload and orchestrator set this so rules are not duplicated).

## Platform default catalog (KPS rules-1.14)

Fleet-level defaults are generated from **kube-prometheus-stack** chart version **81.5.1** (`rules-1.14` templates), matching [`package_rules.yaml`](https://github.com/streamtime-ai/fleet-manager/blob/main/fleet-manager-backend/preload/package_rules.yaml).

- **Alerting rules** (~149): seeded into the DB on `ensure` / reset; editable in the UI.
- **Recording rules** (~90): applied from preload YAML on every fleet apply (not stored per-row in DB).

Regenerate after upgrading the pinned KPS chart version:

```bash
python fleet-manager-backend/scripts/generate_fleet_kps_defaults_from_kps.py --chart-version 81.5.1
```

Requires Helm 3.x and network access to pull `prometheus-community/kube-prometheus-stack` (or pass `--chart-path` to a local chart checkout).

## Per fleet

1. Seed the DB rule set (creates defaults from preload YAML):

```bash
TOKEN=$(./scripts/get-root-token.sh -q)
curl -sk -X POST -H "Authorization: Bearer $TOKEN" \
  https://api.streamtime.local:8443/organizations/{org}/fleet/{fleet_id}/alert-rules/ensure/
```

2. Apply rules to the cluster (deploys alerting rules from DB plus static recording groups from the catalog):

```bash
curl -sk -X POST -H "Authorization: Bearer $TOKEN" \
  https://api.streamtime.local:8443/organizations/{org}/fleet/{fleet_id}/alert-rules/apply/
```

3. **Pick up expanded KPS defaults** on existing fleets: run **Reset defaults** in the UI (or re-`ensure` after deleting the rule set), then **Apply** again. Recording rules update on apply even when DB rows are unchanged.

4. Disable kube-prometheus-stack bundled `defaultRules` if not already (avoids duplicate firing):

```bash
# Upgrade kafka-fleet-manager-prometheus with defaultRules.create=false
# Use your fleet advanced config or helm upgrade with values from preload after package sync.
```

5. Verify status:

```bash
curl -sk -H "Authorization: Bearer $TOKEN" \
  https://api.streamtime.local:8443/organizations/{org}/fleet/{fleet_id}/alert-rules/status/
```

Expect `apply_status` of `applied` and no drift flags on the status endpoint.

## Per Kafka cluster (Strimzi / CFK)

Repeat `ensure` + `apply` under `/organizations/{org}/kafka/{kafka_id}/alert-rules/`.

The per-cluster `fleet-manager-<workload>-alerts` charts are gone (#1521): alerts are
delivered by the fleet's Alertmanager. Remove the releases left on older clusters with
[`migrate_kafka_alerting`](migrate-kafka-alerting.md).

## Optional: import customized rules from cluster

See [scripts/import-alert-rules.sh](https://github.com/streamtime-ai/fleet-manager/blob/main/scripts/import-alert-rules.sh).

## Order of operations (important)

1. Apply `fm-alert-rules` from DB (ensure + apply).
2. Disable KPS `defaultRules` / upgrade prometheus stack.
3. Run [`migrate_kafka_alerting`](migrate-kafka-alerting.md) to move Kafka clusters onto the fleet's Alertmanager.

This avoids alert gaps and duplicate firing.

## Notes

- Windows and etcd rule groups are included in the catalog; they are harmless if those targets are not scraped.
- Job names in expressions match a typical FM install (`fullnameOverride: kafka-fleet-manager-prometheus`).
