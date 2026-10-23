# Elective fleet bootstrap by workload

## Objective

A fleet is set up for the workloads it will actually run. In the fleet's basic
configuration the user enables workload **categories** and, under each, one or
more **providers**. Capacity is sized per category, in that category's units:
chosen per category on cloud fleets, derived and split fairly on BYOK fleets.
Bootstrap installs only the operators the enabled providers need, decided by
compute-components.

This narrows the 28 Sep "Fleet bootstrap overhaul and sizing units" plan (commit
`84c1afd06`, never pushed); see Deviations.

## Decisions (2026-10-03)

| Topic | Decision |
|---|---|
| Hierarchy | Two levels: category → providers. Several providers per category allowed. |
| Categories | **Streaming** (Kafka; includes Kafka Connect and virtual clusters), **Stream Processing** (Flink), **Analytics** (ClickHouse). |
| Streaming providers | Confluent (`cfk`), Apache Kafka (`strimzi`), Redpanda, WarpStream, AutoMQ, LeafCuttr, Tansu. Confluent Platform on VMs (`cpansible`) only on VM fleets. UI labels never name the operator (Strimzi). |
| Stream Processing providers | Apache Flink (`open-source`), Confluent Flink (`cmf`). |
| Analytics providers | ClickHouse. |
| Sizing | Cloud fleets (every tenancy mode): a size per enabled category in its units (KU, FU, CU); nodes are sized to fit their sum. BYOK: derived from the cluster and split fairly across enabled categories. |
| Fair split (BYOK) | Allocatable CPU and memory (minus a system reserve) divided among enabled categories by weight, **equal by default**, converted into each category's units (whole units, limited by the scarcer resource). The fleet's settings can rebalance the weights later. A category never drops below what is already booked on it. |
| Units | Streaming: Kafka unit (existing model). Stream Processing: Flink unit = 1 TaskManager slot at the Balanced profile (1 vCPU, 2 GiB). Analytics: ClickHouse unit = one ClickHouse host at its documented size, 1 vCPU, 2 GiB (was 4 vCPU, 16 GiB; see Deviations 2026-10-08). Footprints in `GlobalConfiguration`; a missing key raises. |
| Existing fleets | Backfilled with every category and provider enabled (nothing is uninstalled) and `capacity_mode: legacy`: Streaming capacity stays `max_kafka_units` / `byok_capacity_kafka_units`; other categories are not capacity-checked, as today. |
| Bootstrap | compute-components decides; workflows install exactly what it returns. |
| Turning off a category or provider in use | Refused (409) with the remedy. |

## Bootstrap gating

| Enabled | Components |
|---|---|
| Streaming → Confluent, or Stream Processing → Confluent Flink | `cfk` |
| Streaming → Apache Kafka | `strimzi` |
| Streaming (any provider) | `envoy_gateway`, `streamtime_kafka_admin`; `kroxylicious` with Virtual clusters |
| Analytics (any provider) | `envoy_gateway` (a Gateway per ClickHouse cluster) |
| Stream Processing → Apache Flink | `flink_operator` |
| Stream Processing → Confluent Flink | `cmf`, `cp_flink_operator` |
| Analytics → ClickHouse | `clickhouse_operator`, `clickhouse_operator_monitoring` |
| always | `kong`, observability (`prometheus`, `grafana_operator`, `loki`, `alloy`, `rustfs` rules, `otel_operator`, `fleet_manager_otel`, exporters, `fm_alert_rules`, dashboards), `cert_manager`, `opencost`, `fleet_manager_infra_shared`, existing DNS / autoscaler rules |

Redpanda, WarpStream, AutoMQ, LeafCuttr and Tansu install everything per
cluster and need no fleet operator.

## In scope

- `Fleet.workloads` and capacity per category; migration and backfill; API,
  serializer validation; CLI, MCP and SDK consumers (`/regression-check`).
- Capacity service: totals per category (fair split, per-category sizes,
  BYOK derivation, legacy), booked units, free units.
- Placement: Kafka fleet selection filters on Streaming + provider and uses
  Streaming capacity; Flink, ClickHouse and Kafka Connect creation is refused
  on a fleet without that category/provider or capacity.
- compute-components gating with a skip reason per component; bootstrap and
  update workflows install exactly that set; updates uninstall what was turned
  off (reverse order, keep CRDs, idempotent).
- UI: basic configuration (category checkboxes, provider checkboxes, sizing by
  tenancy mode), capacity per category on fleet detail, component preview.

## Out of scope

- One node pool per workload on cloud fleets.
- Streamtime AI (Kubernetes MCP server).
- Observed-usage saturation / burn forecasting.

## Validation (400 with a remedy unless noted)

- At least one category; at least one provider per enabled category.
- Provider suits the fleet: `cpansible` only on VM fleets, the others only on
  Kubernetes fleets.
- Sizing:
  - Cloud: at least 1 unit per enabled category (Streaming at least 3 on
    Shared fleets, the existing minimum).
  - BYOK: derived capacity that leaves a category with no units marks the
    fleet "too small" (status reason); it is never shrunk below what's booked.
- 409: turning off a category or provider that workloads on the fleet still
  use — names what to remove.
- Placing a workload on a fleet without its category/provider enabled, or
  beyond the category's free capacity: 400 with the reason; fleet pickers
  explain excluded fleets.

## Approach

1. **Contract.** `core/schemas/fleet_workloads_schema.py` (new):
   categories, providers, `FleetWorkloadsSchema` with `capacity_mode`
   (`legacy` | `split` for BYOK | `per_category` for cloud) and a BYOK
   `weight` per category. `Fleet.workloads` (`SchemaField`), backfilled through
   its default. Cloud fleets: `max_kafka_units` becomes the node-sizing total
   that fits every category's units (Kafka-unit blocks of CPU / memory);
   legacy fleets keep today's meaning. Serializer validation. CLI (`--streaming`, `--stream-processing`,
   `--analytics` provider lists), MCP fleet tools.
2. **Capacity.** `core/services/fleet_capacity.py` (new): unit footprints from
   `GlobalConfiguration` (seed migration), `fleet_capacity(fleet)` → per
   category total / booked / free; the weighted fair split for BYOK
   (BYOK derivation generalizes `_derive_ku_capacity_from_probe`). Kafka
   selection and the Flink / ClickHouse / Connect creation paths use it.
3. **Gating.** `bootstrap_resolver.py`: `_gate_components_by_workloads()`
   sets `install` from the table above with a `skip_reason`. Orchestrator
   bootstrap installs `install: true` only; the fleet update workflow
   uninstalls components that became `install: false` in reverse
   `install_order`.
4. **UI.** `KubernetesFleetCreate.js` basic configuration and the fleet
   update form; fleet detail capacity panel; compute-components preview.
5. **Verify.** Resolver tests for every category/provider combination;
   validation tests for each rule; live: a Streaming-only (Apache Kafka) fleet
   on k3-badami installs no Flink, ClickHouse, Confluent or CMF operators, then
   enabling Analytics installs ClickHouse, and turning it off uninstalls it.

## Risks

| Risk | Mitigation |
|---|---|
| Backfill uninstalls operators on existing fleets | Backfill all categories and providers |
| Existing Kafka capacity shrinks under the split | `capacity_mode: legacy` for existing fleets |
| Uninstalling an operator removes its CRDs and custom resources | 409 while in use; keep CRDs on uninstall |
| Kroxylicious ordering | Gated with Streaming, installed after Strimzi (existing order) |
| Public contract change (CLI binary users) | Additive fields; `max_kafka_units` unchanged |

## As built

- **Model:** `Fleet.workloads` (`core/schemas/fleet_workloads_schema.py`), migration `0176` (backfill through the field default) and `0177` (unit footprints seed).
- **Capacity service:** `core/services/fleet_capacity.py`.
  - BYOK usable resources are stored in `metadata.byok_resources` by `apply_byok_probe`.
  - `FleetSizingService._usable_resources_from_probe` is split out of the KU derivation.
- **API:** `FleetSerializer` validates workloads (400s, and a 409 in-use guard).
  - New endpoints: `GET fleet-workloads/options/` and `GET fleet/{id}/capacity/`.
  - Kafka, Flink and ClickHouse placement checks go through `_require_fleet_workload`.
  - Kafka fleet selection filters on the Streaming provider and uses Streaming capacity.
- **Gating:** `WORKLOAD_GATED_COMPONENTS` and `gate_components_by_workloads`, which set `install`, `conditional`, `workload_gated` and `skip_reason`.
- **Workload change on a provisioned fleet:** a PATCH dispatches `UPDATE` with `component_key: "workloads"` (`core/services/fleet_workloads.py`).
  - The orchestrator installs the needed gated components and uninstalls the rest through the new agent workflow `UninstallReleasesWorkflow`. That workflow never deletes namespaces and has bounded retries.
  - Installed-component records are removed through `removed` on the fleet installed-components POST.
- **UI:**
  - `FleetWorkloadsField` and `fleetWorkloads.js` in Basic Configuration;
  - `FleetWorkloadsCard` (capacity and "Change workloads") on the fleet's Metadata tab.
- **Capacity derivation on the fleet page:** `GET fleet/{id}/capacity/` (`fleet_capacity_report`) adds `derivation` (where the resources came from: `discovered` / `kafka_units` / `fleet_size` / `pending` / `sizes` / `legacy`, the resources divided, what was found and the reserve) and, per category, `footprint`, `weight`, `share`, `limited_by`, `kept_for_bookings` and `skus` (each provider: offered, workloads running, units booked). `FleetWorkloadsCard` explains them in plain language (`fleetCapacityDerivation.js`).
- **CLI:** `fleet create --streaming/--stream-processing/--analytics[-units]`.
- **MCP:** the fleet summary includes `workloads`.

## BYOK capacity scenarios

Tests: `core/tests/services/test_byok_capacity_scenarios.py`. Units at the seeded footprints:
KU 1 vCPU / 4 GB (Dedicated) or 2 / 4 (Shared); FU 1 / 2; CU 1 / 2. 30% of what the probe
finds is kept for the system. Clusters: small 8 vCPU / 16 GB (usable 5.6 / 11.2), medium
12 / 48 (8.4 / 33.6), large 24 / 96 (16.8 / 67.2).

**Kafka unit derivation is unchanged.** `byok_capacity_kafka_units` is the whole cluster in
KUs whatever categories are on (small 2, medium 8, large 16 Dedicated; 2 / 4 / 8 Shared), and
a Streaming-only fleet gets exactly that many.

One fleet (Dedicated unless noted):

| Cluster | Workloads | KU | FU | CU | Note |
|---|---|---|---|---|---|
| small | Streaming + Analytics | 1 | – | 2 | 2.8 vCPU / 5.6 GB each; KU memory-bound |
| small | all three | 0 | 1 | 1 | 3.7 GB each is less than a KU's 4 GB |
| medium | all three | 2 | 2 | 2 | |
| medium | Analytics only | – | – | 8 | |
| medium | Stream Processing + Analytics | – | 4 | 4 | |
| large | all three, Streaming weight 2 | 8 | 4 | 4 | |
| large, Shared | Streaming + Analytics | 4 | – | 8 | KU is 2 vCPU on Shared |
| medium | Streaming + Analytics, 6 KU booked | 6 | – | 2 | Streaming kept at its bookings; the rest goes to Analytics |
| not discovered | any | 0 | 0 | 0 | ClickHouse is refused with "0 free ClickHouse units" |

A ClickHouse cluster at the chart default (500m / 1Gi per host) books ceil(hosts × 0.5) CUs:
1 host → 1, 3 replicas → 2. 3 replicas fit a small Streaming + Analytics fleet (2 CU) and fill it.

Several fleets in one organization (medium clusters): Streaming-only (8 KU), Analytics-only
(8 CU), all three (2 / 2 / 2) and a legacy fleet (8 KU; Flink and ClickHouse unchecked).
ClickHouse is refused on the Streaming-only fleet ("does not run Analytics"), fits 8 CU on
the Analytics-only fleet, 2 but not 3 on the mixed fleet, and any size on the legacy fleet.
Kafka is refused on the Analytics-only fleet. Bookings on one fleet never change another's.

## Follow-ups

- The `available_kafka_units` fleet list filter (`core/filters.py`) still compares against `max_kafka_units`. For new fleets that is the node-sizing total, so the filter over-includes.
- Per-workload node pools on cloud fleets (BO-4); Streamtime AI (BO-6).

## Deviations

- **2026-10-08 — ClickHouse unit is 1 vCPU / 2 GB, not 4 / 16** (user decision, after a
  report that CUs were not derived on BYOK). At 4 / 16, a BYOK cluster under about 17 vCPU /
  69 GB split three ways gave Analytics 0 CUs, and a ClickHouse host at the chart default
  (500m / 1Gi) booked a whole 4 / 16 unit. A CU is now one ClickHouse host at its documented
  size (1 / 2Gi), the same grain as a Flink unit (one TaskManager slot). Migration `0185`
  changes the seeded value only; an operator's own value is kept. Hosts without requests count
  at the chart default (500m / 1Gi), not 1 / 2Gi. Kafka units and their BYOK derivation are
  unchanged. Cloud fleets size nodes from the same footprints, so Analytics needs less node
  capacity there too. Not counted: ClickHouse Keeper (250m / 512Mi per replica) and the Flink
  JobManager (one per Flink cluster); rounding up per cluster absorbs a single Keeper.

- **2026-10-05 — virtual clusters are an optional Streaming service; no default choices**
  (user decision). Categories carry `services` (Streaming: `virtual_clusters`); Kroxylicious
  is gated on it (`SERVICE_GATED_COMPONENTS`), not on any Streaming provider. Legacy fleets
  count every service as on. Turning it off while virtual clusters exist is a 409; creating
  a virtual cluster on a fleet without it is a 400; VM fleets cannot have it. The fleet form
  pre-selects nothing (no category, provider or service); the user picks. CLI:
  `--virtual-clusters`. The virtual cluster form's Kafka cluster picker leaves out clusters
  on fleets without the service (`fleetRunsService`). Also fixed: the BYOK `prepare_byok_bootstrap_config` activity dropped
  `workload_gated` / `workload_dependent` / `skip_reason`, so a workload update on BYOK
  installed and removed nothing (seen live on elderly-marlin).

- **2026-10-04 — Kafka fleet pickers list only fleets running the provider.**
  The fleet-selection and validate endpoints built their list from every fleet
  of the cloud and tenancy; the provider-aware selection only chose the
  default (seen live: an Apache Kafka-only fleet offered for Confluent). Both
  now build it with `_streaming_fleet_clusters` (provider from the URL,
  Streaming capacity). The fleet detail GET also rendered `workloads` as
  key/value pairs; `FleetGetSerializer` now declares the field.

- **2026-10-04 — infra-shared follows the gating.** fleet-manager-infra-shared
  renders the CMF HTTPRoute into `confluent` and PodMonitors into `strimzi` and
  `envoy-gateway-system`. A fleet without those operators failed the whole
  release on a missing namespace (seen live on awake-bat: `namespaces
  "confluent" not found`). `scope_infra_shared_to_installed` (backend, after
  gating) drops the CMF hostname and turns off the PodMonitors
  (`strimzi.podMonitor.enabled`, `envoyGateway.podMonitor.enabled`) for
  components that are off; values are unchanged when everything is on.
  infra-shared is marked `workload_dependent`, so a workload update re-applies
  it after the operators. Separately, the `kong-tailnet` pre-delete hook exits 0
  when it lacks permission (an install that failed before its Role existed never
  created the tailnet Service); before, it wedged the release in `uninstalling`.

- **2026-10-04 — the first bootstrap also removes operators the workloads don't
  need.** A cluster reused from a previous fleet still had that fleet's Flink
  and ClickHouse operators (seen live on k3-badami). `bootstrap_cluster` now
  ends with a best-effort uninstall of gated-out components (patch
  `bootstrap-uninstall-gated-components`). It is a no-op on a fresh cluster.

- **2026-10-04 — no new fleet-size field.** `max_kafka_units` stays what nodes
  are sized from. For cloud fleets with workloads it is computed from the
  category sizes. Streaming capacity comes from the capacity service, not
  `max_kafka_units`.
- **2026-10-04 — BYOK split is rebalanceable** by a per-category `weight`
  (decision: "adjustable later").
- **2026-10-04 — uninstall through a new agent workflow**, not
  `TeardownFleetClusterWorkflow`. Teardown deletes each release's namespace,
  which would remove shared operators (the Confluent namespace hosts both cfk
  and cmf).
- **2026-10-03 — narrowed and restructured.** Workloads are a two-level
  category → provider hierarchy with several providers per category. Kafka
  Connect is part of Streaming, not its own SKU. Sizing is per category
  (cloud: a size per category in its units; BYOK: derived and split fairly,
  rebalanceable by weight). No new fleet-size field: `max_kafka_units` stays
  the node-sizing total, computed from the category sizes. Node pools per workload (BO-4) and Streamtime AI
  (BO-6) are deferred. The `streamtime_tailscale` gating row is gone: Tailscale
  ships with the agent chart. Implemented in PR #1393.
- Review fixes (2026-10-06, PR #1393 review):
  - A services-only change (Virtual clusters on / off, or leaving legacy without a
    service) now reconciles operators: `workloads_changed` compares enabled services
    the way bootstrap gates them, not only categories and providers.
  - Split (BYOK) capacity conserves the fleet's resources: categories whose share is
    below their bookings keep their bookings, and only the leftover CPU / memory is
    split among the others by weight (previously the booked floor was added on top).
  - Kafka placement checks Streaming capacity on the effective fleet and size in
    `KafkaSerializer.validate`, so an explicitly chosen fleet and a size-only PATCH
    are checked too (previously only the fleet's workloads, with 0 units).
  - Envoy is also installed for Analytics (ClickHouse runs a Gateway per
    cluster); it was gated on Streaming only, so Analytics-only fleets had no
    gateway controller and turning Streaming off uninstalled it under ClickHouse.
  - Shared cloud fleets size one workload pool (tainted `purpose=kafka_workload`)
    for every category; Flink and ClickHouse now get the same toleration and node
    affinity as Kafka (`workload_pool_scheduling`; BYOK: the fleet's own
    scheduling settings). The ClickHouse chart gained `tolerations` / `affinity`;
    the Flink chart renders `flink.jobmanager.affinity` on its shared pod template.
  - Until per-workload node pools (BO-4), Dedicated / Isolated category sizes
    drive pricing and capacity checks only: provisioning creates the
    shared-services pool, Kafka adds nodes per cluster, Flink and ClickHouse run
    on whatever the cluster has.
  - Fleet teardown (BYOK) now also removes the OTel operator and collector and the
    workload-gated operators (Flink, Confluent Flink, ClickHouse, Kroxylicious); a
    test compares the list with bootstrap's. Deriving teardown from installed
    components is #1412.
