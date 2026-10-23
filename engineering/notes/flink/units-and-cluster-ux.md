# Flink Units & Flink Cluster UX — Design Discussion

**Status:** Draft, for product owner review
**Owner:** Ashwin Venkatesan
**Last updated:** 2026-09-02

This document captures an in-progress design discussion on (1) defining a "Flink Unit" as a
sizing/capacity abstraction analogous to Kafka's existing "Kafka Units" concept, and (2) improving
the Flink cluster creation UX. It will be updated as the discussion continues — treat sections
below as the current state of thinking, not final decisions.

---

## 1. Background: how "Kafka Units" works today

Kafka Units (`kafka_units`) is a provider-neutral capacity dial on the `Kafka` model, roughly
"1 unit ≈ 20 MB/s of throughput." It's interpreted differently depending on tenancy:

- **Shared tenancy** — bin-packing against a pre-sized pool. A Shared Fleet has a fixed
  `max_kafka_units`; each Kafka cluster placed on it draws down that pool
  (`available = max_kafka_units - Σ(kafka_units of clusters on this fleet)`). No new
  infrastructure is provisioned per cluster.
- **Isolated / Dedicated tenancy** — the fleet grows to fit the cluster. A brand-new,
  cluster-specific cloud node group is provisioned at cluster-creation time, sized directly from
  `kafka_units` via a per-cloud instance-size lookup table. There's no pre-existing capacity to
  run out of.
- **BYOK fleets** — `max_kafka_units` is derived from the agent's discovery probe of real node
  CPU/RAM (minus ~30% overhead), converted at fixed GB-per-unit / vCPU-per-unit ratios. So for
  BYOK, the unit is ultimately backed by real discovered hardware.
- **Overflow behavior** — no auto-provisioning, no queuing. If no fleet has enough headroom,
  cluster creation fails with a 400. A human must create a new fleet.

Per-flavour sizing (CFK, Strimzi, Warpstream) each implement their own
`size_kafka_workload()` override translating `kafka_units` + `optimization_goal` into concrete
broker/instance specs (roughly: 1 unit ≈ 1 broker node, with per-node vCPU/RAM scaling by
optimization goal).

---

## 2. Proposed definition: "Flink Unit" (FU)

Flink has two resource roles with very different scaling behavior:

- **JobManager** — control plane (scheduling, checkpoint coordination, RPC). Resource need is
  roughly *fixed* per cluster/job, not driven by throughput/parallelism/state. Analogous to
  Kafka's KRaft controllers, which are fixed at 3 regardless of `kafka_units`.
- **TaskManager** — the actual compute. This is what parallelism, throughput, state size, and
  network pressure bear on.

**Proposal:** 1 Flink Unit ≈ 1 task slot's worth of baseline TaskManager compute (e.g. 1 vCPU +
a baseline GB of memory), sized independently of JobManager, which gets a fixed baseline
allocation outside the unit pool.

| Factor | How it factors into FU |
|---|---|
| **Parallelism** | Drives FU count directly: `flink_units ≈ parallelism` (or `parallelism / slots_per_taskmanager`). TaskManager replica count is derived from FU, the way Kafka derives `node_count` from `kafka_units`. |
| **State size** | Doesn't change slot count — changes RAM (and possibly local disk, for RocksDB) *per* slot. Proposed as a separate **State Tier** modifier (Stateless / Light / Heavy-RocksDB), analogous to `ram_per_ku = 8 if Performance else 4` in CFK's sizing. |
| **Throughput** | Secondary validation, not a primary sizing axis — parallelism is the real lever. Used the way `INGRESS_MBPS_PER_KU` validates Kafka's post-hoc disk/network sizing, not the primary node-count formula. |
| **Network** | Affects network-buffer memory fraction per TaskManager. Possible future refinement, not core to the FU number. |

### Fleet dependency — two-level allocation (new vs. Kafka)

Kafka only has Fleet → Cluster. Flink has Fleet → session cluster → nested Job, requiring an
extra layer:

- **Fleet-level** — same model as Kafka: Shared tenancy fleets get a `max_flink_units` pool that
  clusters draw down; Isolated/Dedicated carves a dedicated node group sized from the cluster's
  FU count.
- **Cluster-level (new)** — a session `Flink` cluster gets its own FU budget
  (`Flink.max_flink_units`), and each nested `FlinkJob` consumes FU against *that* budget, not
  the Fleet's directly, since jobs land in the TaskManager pool the session cluster already owns.
  Application-mode `Flink` clusters (no nesting, single job = the cluster) consume Fleet-level FU
  directly, matching Kafka's model today.

### Decision so far

**FU is settable at the job level within a session cluster** — each `FlinkJob` gets its own FU
value, drawn from the parent session cluster's capacity pool, rather than being fixed once at
cluster creation with no per-job dial.

---

## 3. Flink Cluster creation UX — proposed redesign

### Current state (as of this writing)

Kafka Cluster Creation (`ClusterCreate.js`) has 4 steps (non-admin): **Cluster Type** (SKU
card grid) → **Basic Configuration** (Identifier, Tags, Cloud Provider, Region, Tenancy,
**Kafka Units**, **Optimization Goal**, **Retention Mode/Days**) → **Fleet Selection** →
**Advanced Configuration**.

Flink Cluster Creation (`FlinkCreate.js`) has 3 steps and no equivalent capacity/cost-shaping
block: **Basic Configuration** (Identifier, Provider dropdown, Deployment Mode, Tags, Cloud
Provider, Region, Tenancy) → **Fleet Selection** → **Advanced Configuration**. Provider selection
is a plain dropdown rather than a card grid (there's unused dead code for a card-grid version).
`FlinkJob` creation is a separate, differently-styled, non-wizard single page with a raw numeric
`Parallelism` field.

### Proposed redesign

**Step 0 — "Cluster Type"** *(new — mirrors Kafka's SKU card grid)*

Two cards, replacing the current "Deployment Mode" dropdown/radio and reusing the existing
unused `AvailableSkUCard` component:

> **Single-Job Cluster**
> Dedicated capacity for one long-running Flink job. The cluster is created and torn down with
> the job — ideal for isolated, resource-guaranteed workloads.

> **Job Workspace**
> A shared, long-lived cluster that runs multiple jobs at once. Submit and stop jobs
> independently without restarting the workspace — ideal for teams running many smaller,
> frequent jobs.

Naming rationale: internal Flink terms "Application Mode" / "Session Mode" violate the project's
no-internal-names-in-UI rule. "Headless / Interactive" was considered and rejected — both modes
run a JobManager Web UI, so "headless" would mislead. The real distinction is **job multiplicity
and lifecycle coupling** (one job per cluster vs. many independently-managed jobs on a shared
pool), not UI presence. "Dedicated / Shared" was also considered and rejected — those words are
already used by the **Tenancy** field for a different axis (infra isolation across
orgs/tenants); reusing them here would conflate two distinct concepts.

**Step 1 — "Basic Configuration"**

1. `Identifier *` — text (unchanged)
2. `Tags` — ArrayField (unchanged)
3. `Choose a Cloud Provider` — radio-card grid (unchanged)
4. `Region` — dropdown, conditional on non-BYOK (unchanged)
5. `Tenancy` — dropdown + helper text (unchanged)
6. **`Optimization Goal`** *(new)* — dropdown Cost/Balanced/Performance, ported directly from
   Kafka's pattern; drives TaskManager instance family selection the way it drives CFK/Strimzi
   broker instance family today.
7. **`State Tier`** *(new)* — dropdown (Stateless / Light State / Heavy State-RocksDB), Flink's
   analog to Kafka's Retention Mode/Days; shapes per-slot RAM and local disk sizing.
8. **`Flink Units`** *(new, conditional on Step 0 choice)*:
   - **Single-Job Cluster**: field labeled `Flink Units`, slider. Helper text: *"1 unit ≈ 1
     parallel task slot for this job. Higher values increase throughput and reduce processing
     latency."* Tooltip: *"Flink Units set how much parallel processing capacity this cluster
     gets. Matches your job's parallelism to the resources provisioned."*
   - **Job Workspace**: field relabeled `Workspace Capacity (Flink Units)`, slider. Helper text:
     *"Total task-slot capacity available to jobs submitted to this workspace. Individual jobs
     will draw from this pool when submitted."* Tooltip: *"This sets the size of the shared
     pool. Each job you add later requests its own share of these units — the workspace can host
     multiple jobs as long as capacity is available."*

**Steps 2–3** — Fleet Selection, Advanced Configuration — unchanged (already schema-driven).

**Important:** the cluster creation wizard never asks about jobs, in either mode. For Job
Workspace, it only sets the pool (`Workspace Capacity`, field 8 above) — job submission is a
separate flow, described next.

### Job submission — moved out of cluster creation, into Job Workspace management

Today, `FlinkJobCreate.js` is a disconnected, differently-styled top-level page — not part of
cluster creation, but also not visually or navigationally anchored to the workspace it belongs
to. Proposed fix: job submission belongs entirely inside the **Job Workspace management page**
(the detail/management view for a Session-mode `Flink` cluster), not in a separate top-level
route and not in the creation wizard:

- Add an **"Add Job"** action on the Job Workspace detail page (next to the existing jobs list),
  which opens the job form scoped to that specific workspace.
- Replace the raw numeric `Parallelism` field with a **`Flink Units`** slider, same
  `SliderInput` component and helper-text pattern as elsewhere. `parallelism` becomes a value
  derived from FU, the way `kafka_units` derives `node_count` today.
  - Helper text: *"1 unit ≈ 1 parallel task slot for this job. Limited by the remaining capacity
    in this workspace (X of Y units available)."*
  - Slider max is bounded by the parent Job Workspace's remaining `Workspace Capacity` headroom
    — gives the job form a real, validated ceiling the way Kafka Units is validated against Fleet
    headroom.
- Keep Application JAR / Entry Class / Application Arguments / Upgrade Mode as-is — job-specific
  fields with no Kafka analogue.
- Re-style the form to match the wizard visual language instead of remaining a disconnected
  single-page form.
- Single-Job Cluster mode has no "Add Job" action at all — the job is implicitly defined by the
  cluster's own Flink Units field at creation time (see field 8, Single-Job Cluster state), and
  there is nowhere else to submit a job to that cluster.

---

## 3a. Advanced Configuration — field mapping by mode

**Single-Job Cluster** (all fields on the cluster wizard, since the cluster *is* the job):

| Field | Notes |
|---|---|
| `application_jar` *(required)* | The job's JAR |
| `entry_class` | **Gap**: doesn't exist on `FlinkAdvancedConfigSchema` today — only on `FlinkJobAdvancedConfigSchema`. Needs to be added to the cluster schema for Single-Job mode to have parity with what a session job can specify. |
| `application_args` | |
| `parallelism` | Superseded in the UI by the Flink Units slider (Basic Configuration), but still the underlying field |
| `upgrade_mode` | |
| `savepoint_strategy` | enabled / retention policy / location |
| `flink_conf` | Runtime config (state backend, checkpoint/savepoint dirs, task slots) |
| `web_ui` | enabled / submit enabled |
| `security` | provider + auth (basic/oauth) |
| `jobmanager_resources`, `taskmanager_resources` | Accepted by the Pydantic schema but never surfaced in the RJSF form today — needs to be added if users should override sizing beyond what Optimization Goal/State Tier imply |
| `image`, `kafka` | Advanced/power-user knobs; probably belongs behind an "Advanced" disclosure rather than the top-level list |
| `chart_config` | Handled by `FlinkChartPicker`, not RJSF |
| `extraVolumes`/`extraVolumeMounts` | Expert-tier only |

**Job Workspace** (session mode) — cluster wizard shows only pool-shape fields, nothing job-specific:

| Field | Notes |
|---|---|
| `taskmanager_replicas`, `taskmanager_resources` | Defines the shared TaskManager pool other jobs draw from |
| `jobmanager_resources` | |
| `web_ui` | |
| `security` | Cluster-wide auth, applies to all jobs submitted to it |
| `image`, `kafka` | |
| `chart_config` | |
| `extraVolumes`/`extraVolumeMounts` | |

Explicitly **excluded** from the Job Workspace cluster wizard: `application_jar`, `application_args`,
`entry_class`, `upgrade_mode`, `savepoint_strategy` — these are per-job and belong on the Add Job
form instead.

**Add Job form** (session mode only, on the workspace management page):

| Field | Notes |
|---|---|
| `application_jar` *(required)* | |
| `entry_class` | Already present |
| `application_args` | Already present |
| `parallelism` | Superseded by Flink Units slider per earlier design |
| `upgrade_mode` | Already present |
| `savepoint_strategy` | **Gap**: schema supports it, but `FlinkJobCreate.js` has no field for it today |
| `flink_conf` | **Gap**: schema supports job-level overrides layered on the cluster's `flink_conf`, but nothing in the current UI exposes it |
| `chart_config` | Already present via `FlinkJobChartPicker` |

### Underlying implementation gaps this surfaced (not pure UX — needs eng scoping)

1. **Mode-based field visibility is currently client-side only and duplicated.** `FlinkCreate.js`
   never actually sends `mode` to the backend's advanced-config schema endpoint
   (`core/views/flink/config.py::FlinkAdvancedConfigView` defaults to `"application"`
   server-side), so today's mode-toggle behavior is two independent client-side copies of the
   same `if mode !== "session"` logic (main fetch path + fallback schema) — a drift risk. Fixing
   this means the frontend sends `mode` and the backend returns the authoritative schema for it,
   removing the duplicated client logic.
2. **The RJSF-facing schema is narrower than the real Pydantic contract.** `security`,
   `jobmanager_resources`, `taskmanager_resources`, `image`, `kafka`, `extraVolumes*` are all
   accepted by validation but never offered in the form at all, regardless of mode — not a
   mode-conditional gap, just missing entirely.
3. **`FlinkJobCreate.js` isn't schema-driven** (plain MUI state, no RJSF), unlike the cluster
   form — so it can't easily grow to add `flink_conf`/`savepoint_strategy` the way the cluster
   form can. Building a `FlinkJobAdvancedConfigView` (mirroring `FlinkAdvancedConfigView`) would
   let the job form become schema-driven too, consistent with the cluster form.

---

## 4. Broader product/UX ideas raised (not yet scoped)

- **Presets over raw knobs** — once Optimization Goal + State Tier + Flink Units + Tenancy are
  all on the form, that's a lot of jargon-adjacent decisions for a self-serve user. Consider
  named workload profiles (e.g. "Lightweight streaming", "Balanced", "Heavy stateful
  processing") that bundle Optimization Goal + State Tier into one guided pick, with an
  "Advanced" toggle to override individual fields.
- **Live sizing/cost preview** — Kafka has a backend sizing-preview endpoint
  (`KafkaSizingPreviewView`) but no equivalent exists for Flink yet. Adding a live preview panel
  (estimated JobManager+TaskManager footprint, estimated cost) as the user moves the Flink Units
  slider would be a genuine UX upgrade, not just parity with Kafka.
- **Shared vocabulary across workload types** — if more stream-processing engines are added
  later, consider whether "Flink Units" and "Kafka Units" should become two instances of a
  generic "Compute Units" concept. Flagged as premature abstraction unless more engines are
  actually planned — revisit if/when that becomes concrete.

---

## 5. Change management, BYO JAR, and PyFlink (applies to both modes)

### 5a. Change management / VCS-backed redeploy

The repo already has a mechanism for this shape of problem, just not git-scoped today:
**`TrackedRepository`** (`core/models.py:2758`) tracks an OCI or Helm registry, periodically
syncs discovered tags into versioned `Package` rows, and resolves a layered values chain
(`package.default_values → tracked_repository.template_values → package.template_values → user
overrides`, `core/services/preset_resolver.py:284-359` — matches the merge order documented in
CLAUDE.md). `PackageRule` (`core/services/package_rules.py`) classifies synced versions as
supported/deprecated/latest by semver/age.

**Proposal**: don't build a separate git-integration feature. Route Flink job artifacts through
this same catalog — CI builds and pushes the JAR to an OCI/artifact registry, that registry is
registered as a `TrackedRepository`, and users pick a `Package` (a specific build/tag) from the
catalog instead of pasting a raw JAR URL. This gives versioning and rollback (redeploy an earlier
`Package`) for free, and a natural provenance trail for change management.

**Known gap**: catalog sync today is pull-based / manually triggered
(`POST .../tracked-repositories/{repo}/sync/` → `PackageSyncWorkflow`) — there is no webhook or
CI-callback anywhere in the system. True "push a new build → auto-redeploy" requires a new
sync-trigger webhook feeding into the existing `FlinkJobUpdateWorkflow` (already idempotent per
design principle #4). CFK's `auto_upgrade_version` field (`fm_types/cfk.py`) is a nearby
precedent — an existing "opt-in auto-redeploy on new version" toggle worth mirroring for Flink
jobs rather than inventing new semantics.

### 5b. Bring Your Own Job JAR — validation / sandboxing

This is a real, currently-unaddressed gap — not a design nicety. Repo-wide, there is **no
checksum/signature verification, no malware scanning, and no admission control** for any
user-supplied artifact anywhere in the codebase (Kafka Connect connectors included). Specifically
for Flink: `application_jar` has **zero scheme restriction** today — contrast with
`savepoint_strategy.location`, which already goes through `validate_storage_uri`'s scheme
allowlist (`flink_schema.py:66-77`). Porting that same allowlist onto `application_jar` is a
cheap, immediate fix regardless of anything else below.

Two complementary tracks beyond that:
- **Catalog-first, not raw-URL-first** — if BYO JARs route through the `TrackedRepository`/
  `Package` flow from 5a, integrity verification comes via `Package.digest`
  (`models.py:2867-2874`), and "raw arbitrary URL" mode can be gated behind an org-level admin
  toggle, since letting any user paste any URL for code that runs inside the cluster is a
  meaningfully larger risk surface than picking from a registry the org already trusts.
- **Runtime sandboxing, not artifact inspection** — static scanning of arbitrary JARs is weak
  defense-in-depth. Real containment is Kubernetes-level: PodSecurity admission, non-root /
  read-only-root-filesystem TaskManager pods, NetworkPolicy restricting egress from job pods,
  resource limits. Needs confirmation from whoever owns cluster security posture on whether this
  exists generically today or needs to be added per-workload.

Full engineering scoping for all three items in this section now lives in
[`dev-to-deployment-lifecycle-technical-design.md`](./dev-to-deployment-lifecycle-technical-design.md),
which also covers VCS-driven build execution and SQL as a third job runtime.

### 5c. PyFlink support

**No precedent exists anywhere in the repo** — confirmed zero references in schemas, charts, or
orchestrator workflows. Current Flink support is exclusively JVM/JAR-based. The Flink Kubernetes
Operator's `FlinkDeployment` CRD does support `job.pythonFile` as an alternative to `job.jarURI`,
but `charts/streamtime-flink/templates/flinkdeployment.yaml:129-142` only renders the JAR path
today. Adding this requires schema fields (`python_file`, likely `python_requirements`/
`python_archives`), a chart template branch, and orchestrator-side handling — not a small
addition.

**Product framing**: treat as a **Job Runtime** selector, orthogonal to Single-Job vs. Job
Workspace mode. On the Add Job form (and the Single-Job cluster's Advanced Config), a "Runtime"
choice (`JAR (Java/Scala)` vs `Python (PyFlink)`) would toggle between `application_jar`/
`entry_class` and `python_file`/dependency fields — the same visibility-toggle pattern `mode`
already applies to `application_jar` today (see §3a gap #1, which should be fixed *before*
adding a second axis of conditional fields on top of it). Recommend scoping as a separate
roadmap item, additive to the schema, not bundled into the units/mode redesign.

---

## 6. Open questions / decisions still needed

1. Should the State Tier field directly gate RAM allocation only, or also switch the Flink state
   backend (hashmap vs. RocksDB) in `flink_conf`? (Affects whether this is purely a sizing hint
   or also a functional config choice.)
2. For Job Workspace mode, what happens when a job's requested Flink Units would exceed the
   workspace's remaining capacity — hard block (like Kafka's fleet-placement failure), or offer
   to resize the workspace's `Workspace Capacity` inline?
3. Should `size_flink_workload()` be implemented as a single canonical function (avoiding the
   two-derivation split — preview vs. actual chart values — that exists today for Kafka), or is
   parity with the existing Kafka pattern preferred for consistency even with its known
   drawback?
4. Naming: confirm "Single-Job Cluster" / "Job Workspace" against product's preferred voice, or
   supply alternatives.
5. Should BYO JAR support default to catalog-only (`TrackedRepository`/`Package`), with raw-URL
   input as an opt-in admin-gated fallback — or is raw-URL the primary path or launch, with the
   catalog integration deferred?
6. Is a CI/webhook-triggered auto-redeploy (5a) in scope for the initial release, or should
   change management launch with manual redeploy-from-catalog only?
7. Is PyFlink support (5c) on the near-term roadmap, or purely aspirational for now? Affects
   whether the Job Runtime selector should be stubbed into the schema now (unused) or added
   later as a clean follow-up.
