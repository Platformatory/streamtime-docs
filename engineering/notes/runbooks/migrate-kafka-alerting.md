# Migrate Kafka clusters to fleet-only alert delivery (#1521)

Kafka clusters (Strimzi, CFK, WarpStream) created before #1521 run their own
`fleet-manager-<workload>-alerts` Helm release: an Alertmanager, an HTTPRoute, a Kong
consumer, a certificate and receivers, per cluster. From #1521 on:

- every alert rule Streamtime renders carries a `fleet=<fleet id>` label;
- the fleet's Alertmanager (`fleet-manager-infra-shared`) routes on that label and is the
  only delivery path, to the fleet's alert channels, verifying TLS against the gateway
  trust bundle;
- alert channels are set per fleet only. A Kafka cluster no longer has its own.

`manage.py migrate_kafka_alerting` moves existing clusters over. It is a one-off and
idempotent: run it again if a fleet fails. It migrates **every** fleet, including fleets
with no Strimzi, CFK or WarpStream cluster.

## When to run it

Straight after the control plane runs the #1521 release. Run it again once Kafka create
and update operations started before the upgrade have finished (one started earlier can
still install a `-alerts` release; the second run removes it).

Until a fleet is migrated:

- its existing Strimzi, CFK and WarpStream clusters keep delivering through their own
  release, so their alerts are not lost;
- **nothing delivers alerts** for its ClickHouse or Flink resources, or for any Kafka
  cluster created after the upgrade: there is no per-cluster release any more, and the
  fleet route still matches the old `cluster` label.

## What it does, per fleet

`MigrateKafkaAlertingWorkflow`, in this order, so no alert is dropped:

1. Re-applies `fm-alert-rules` for the fleet and each Kafka cluster (every rule gets `fleet`).
2. Runs the fleet's update of `fleet-manager-infra-shared` (the route matches on `fleet`).
3. Uninstalls each cluster's `fleet-manager-<workload>-alerts` release (already gone counts
   as removed) and deletes its installed-component record.

It never removes anything else. A fleet without such clusters gets steps 1 and 2 only.

Between steps 2 and 3 both Alertmanagers deliver a cluster's alerts, for the few
minutes the uninstall takes; a notification can arrive twice in that window, and the
alert can be listed twice under the Kafka cluster.

## Run it

```bash
# docker-compose
docker compose exec fleet-manager-backend python manage.py migrate_kafka_alerting --dry-run
docker compose exec fleet-manager-backend python manage.py migrate_kafka_alerting

# Helm
kubectl -n <streamtime namespace> exec deploy/fleet-manager -- \
  python manage.py migrate_kafka_alerting --dry-run

# single image (SQLite)
docker exec <container> python manage.py migrate_kafka_alerting --dry-run
```

Options: `--fleet <fleet id>` and `--organization <org id>` limit it to one fleet or org.
`--dry-run` lists each fleet, each cluster and the release it would remove, and changes
nothing. A fleet whose provider has no fleet workflow is skipped with a warning (an error
when named with `--fleet`).

Each fleet runs as an operation (`/organizations/<org>/fleet/<fleet>/command/MigrateKafkaAlertingWorkflow`).
The fleet update step fails cleanly while another operation runs on the fleet. Wait for
it to finish, then run the command again for that fleet.

## Verify

For each migrated fleet:

```bash
# No per-cluster alerts release is left (expect no output)
helm list -A | grep -E 'fleet-manager-(strimzi|cfk|warpstream)-alerts'

# The fleet route matches on fleet, and every rule carries it
kubectl -n <fleet id> get alertmanagerconfig <fleet id>-alerts -o jsonpath='{.spec.route.matchers}'
kubectl -n <kafka id> get prometheusrule -o yaml | grep 'fleet: <fleet id>'
```

Then trigger a Kafka alert and a fleet alert. Both should reach the fleet's alert channels
and show in Streamtime under the Kafka cluster and the fleet respectively.

## Manual fallback

If the operation cannot run (for example the agent is down), do the same by hand, in this
order:

1. Apply the rules: `POST /organizations/<org>/fleet/<fleet>/alert-rules/apply/`, then
   `POST /organizations/<org>/kafka/<kafka>/alert-rules/apply/` for each cluster.
2. Update the fleet's infra-shared component (Fleet → Components → Fleet Manager infra
   shared → Update).
3. On the cluster: `helm uninstall fleet-manager-<workload>-alerts -n <kafka id>` for each
   Kafka cluster.

ClickHouse clusters are not migrated (none were expected to exist). If one does, remove
its release the same way: `helm uninstall <clickhouse id>-clickhouse-alerts -n <clickhouse id>`.
