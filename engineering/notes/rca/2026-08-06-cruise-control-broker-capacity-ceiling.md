# RCA: Cruise Control never rebalances — undersized hardcoded `brokerCapacity`

**Date:** 2026-08-06  
**Severity:** Critical — Cruise Control silently never rebalances a skewed production cluster, with no error and no log activity  
**Component:** `charts/fleet-manager-strimzi` — Cruise Control `brokerCapacity` configuration  
**Status:** Fixed

---

## Summary

A production Strimzi Kafka cluster (BYOK/OKI) had all 3 partition leaders of a topic deliberately pinned to broker 0, creating a fully skewed leadership distribution. With ~11.3 MB/sec of active producer/consumer load and a ~2 minute observation window, Cruise Control produced no rebalance proposal, no `KafkaRebalance` activity, and no log output at all.

Root cause: `charts/fleet-manager-strimzi/values.yaml` hardcoded Cruise Control's per-broker `brokerCapacity.inboundNetwork`/`outboundNetwork` to `1000KB/s` (~8 Mbps) — a placeholder copy-pasted from the Cruise Control **pod's own** container resource limits when Cruise Control support was first added, never derived from real broker hardware, and never covered by a test. `NetworkInboundCapacityGoal`/`NetworkOutboundCapacityGoal` are **hard goals** in the same chart's `hard.goals`/`anomaly.detection.goals` config — goals Cruise Control's analyzer cannot violate when computing a proposal. Once real per-broker traffic exceeded the ~1 MB/s ceiling (11.3 MB/s observed, ~11× over), every possible partition assignment already violated a hard capacity goal, so the self-healing anomaly detector could never find a feasible rebalance and did nothing — by design, not as a malfunction.

---

## Root Cause Chain

### 1. `brokerCapacity` was a copy-paste placeholder, never real broker sizing

`charts/fleet-manager-strimzi/values.yaml` (introduced in commit `ce4740dee`, `feat: CruiseControl for Strimzi (#661)`, and unmodified since):

```yaml
cruiseControl:
  resources:
    limits:
      cpu: "1"
      memory: "2Gi"
  brokerCapacity:
    cpu: "1"            # ← identical to the block above: the CC POD's own limit
    inboundNetwork: "1000KB/s"
    outboundNetwork: "1000KB/s"
    memory: "2Gi"        # ← identical to the block above: the CC POD's own limit
```

`brokerCapacity.cpu`/`memory` are byte-for-byte identical to `cruiseControl.resources.limits` immediately above — the Cruise Control **pod's own** container resource limits, which have nothing to do with what a Kafka **broker** pod can actually handle. `inboundNetwork`/`outboundNetwork` have no matching value or derivation anywhere else in the codebase — a pure placeholder. Zero tests exercised any of these four fields since the block was introduced.

### 2. Hard capacity goals cannot be violated when computing a proposal

The same file's `default.goals`, `hard.goals`, and `anomaly.detection.goals` all include `NetworkInboundCapacityGoal` / `NetworkOutboundCapacityGoal` / `CpuCapacityGoal`. Cruise Control's analyzer treats hard goals as non-negotiable: if satisfying them is impossible for the current cluster state, the optimization fails outright rather than returning a best-effort proposal that violates one.

### 3. Real load exceeded the ceiling by ~11×

With all 3 leaders pinned to broker 0, that broker's observed throughput was ~11.3 MB/sec (~90 Mbps) against a configured ceiling of ~1 MB/sec (~8 Mbps) per broker. Every possible partition assignment Cruise Control could propose already had at least one broker exceeding the hard network capacity ceiling — including the skewed state itself and any rebalanced alternative, since the *cluster-wide* traffic figure did not fit within `brokerCapacity × broker_count` either. The self-healing anomaly detector's periodic check therefore never produced a feasible proposal.

### 4. Why this presented as total silence

Cruise Control's anomaly detector runs its self-healing check on a fixed interval regardless of whether traffic is skewed. When every candidate proposal violates a hard goal, the detector's behavior is to skip proposing anything rather than surface a best-effort alternative — this is expected Cruise Control behavior for an infeasible-under-hard-goals cluster state, not a bug in Cruise Control itself. Diagnosing this requires checking the **Cruise Control pod's own logs** specifically (`kubectl logs <cruise-control-pod>`) — broker logs alone will show nothing, since the failure is entirely internal to Cruise Control's own optimization loop.

### 5. A separate, unrelated timing factor in the same report

Cruise Control's load monitor config (`metric.sampling.interval.ms`/`partition.metrics.window.ms`/`broker.metrics.window.ms` = 300000ms × 5 windows each) means the load monitor needs up to **~25 minutes** of active-traffic uptime before it has enough valid windows to build a cluster model at all. The reported ~2 minute observation window would not have been enough time for Cruise Control to act even absent the capacity bug. This is expected/by-design (the windowing exists for statistical smoothing and to avoid false-positive rebalances on short-lived spikes) and must not be "fixed" by shrinking the windows — it is documented inline in `values.yaml` so it isn't mistaken for a second bug in a future investigation.

### 6. A second, compounding gap found during live verification: `self.healing.enabled` doesn't cascade to per-anomaly-type flags

While reproducing the bug end-to-end on a live kind cluster (BYOK, Strimzi operator `1.1.0`) after applying the `brokerCapacity` fix, a 3-partition/RF3 topic was created and all leaders forced onto broker 0 via `kafka-reassign-partitions.sh` + `kafka-leader-election.sh --election-type preferred`, under sustained producer load. Once Cruise Control's load monitor accumulated enough valid windows, its `/state` output confirmed the core fix works:

```
AnalyzerState: {isProposalReady: true, readyGoals: [..., NetworkInboundCapacityGoal, NetworkOutboundCapacityGoal, ...]}
```

`NetworkInboundCapacityGoal`/`NetworkOutboundCapacityGoal` — the exact hard goals infeasible under the old `1000KB/s` ceiling — are satisfiable. Cruise Control's anomaly detector also correctly detected the injected skew:

```
recentGoalViolations:[{detectionDate=..., fixableViolatedGoals=[NetworkOutboundUsageDistributionGoal, LeaderBytesInDistributionGoal], status=IGNORED}, ...]
AnomalyDetectorState: {selfHealingEnabled:[], selfHealingDisabled:[DISK_FAILURE, BROKER_FAILURE, GOAL_VIOLATION, METRIC_ANOMALY, TOPIC_ANOMALY, MAINTENANCE_EVENT], ...}
```

The violation was logged as fixable but left `status=IGNORED` — never auto-executed — because `GOAL_VIOLATION` self-healing shows disabled at runtime. The chart's blanket `self.healing.enabled: "true"` (hardcoded in `templates/kafka.yaml`) does not cascade to the per-anomaly-type `self.healing.goal.violation.enabled` flag in this Cruise Control version. This is a second, independent gap: even with a satisfiable proposal, nothing would auto-execute it without this flag set explicitly.

### 7. A third, independent gap: setting the per-anomaly-type flag still isn't enough — Strimzi blocks `self.healing.*` config entirely

Setting `self.healing.goal.violation.enabled: "true"` (finding #6's fix) was verified live against the running Strimzi operator (`1.1.0`) and confirmed **silently stripped**, via the operator's own logs:

```
WARN AbstractConfiguration:106 - Configuration option "self.healing.enabled" is forbidden and will be ignored
WARN AbstractConfiguration:106 - Configuration option "self.healing.goal.violation.enabled" is forbidden and will be ignored
```

Both flags — the pre-existing blanket one and the new per-anomaly-type one — are on Strimzi's list of forbidden Cruise Control configuration options and never reach Cruise Control at all. **Native Cruise Control self-healing is not achievable on this Strimzi version, full stop** — no config combination fixes it. The only other path to execute a rebalance is Strimzi's own `KafkaRebalance` custom resource, which requires a human (or automation) to annotate it `strimzi.io/rebalance: approve`. Strimzi's CRD has no auto-approval field. This is an architectural gap in Strimzi itself, not a misconfiguration — closing it requires automation outside Cruise Control's/Strimzi's own control loop.

---

## Fixes Applied

### Fix: derive `brokerCapacity` from the existing `kafka_units` sizing model

`fleet-manager-backend/core/services/kafka_workload_charts.py` — new `compute_strimzi_broker_capacity(kafka_units, broker_count)`, wired into `_apply_kafka_model_overrides_to_preset` for `workload_type == "strimzi"` (same preset-layer precedence as the existing `compute_strimzi_disk_sizing`, so an explicit operator override in `chart_values` still wins):

- Reuses `KafkaSizingService.INGRESS_MBPS_PER_KU`/`EGRESS_MBPS_PER_KU` (already used for cost-estimation network line items) as the per-unit throughput basis, spread across the cluster's broker count.
- Since those constants model *average* provisioned throughput for cost estimation, not a *peak* capacity ceiling, the result is inflated by a `_BROKER_CAPACITY_HEADROOM_FACTOR = 4` and floored at `_MIN_BROKER_NETWORK_KBPS = 25_000` (~200 Mbps/broker) — the floor alone clears the reported incident's ~11.3 MB/s observed load with ~2× margin.
- `cpu`/`memory` are corrected to static, decoupled-from-the-CC-pod-limits constants (`"2"`/`"4Gi"`) — not implicated by this incident (the reported number was a network figure), so per-tier derivation for those two dimensions is left as a deliberate future follow-up rather than expanding this fix's scope.

`charts/fleet-manager-strimzi/values.yaml` — the static block is corrected (`25000KB/s`, `cpu: "2"`, `memory: "4Gi"`) and documented as a **standalone/manual-deploy fallback only** — used when this chart is `helm install`/`helm template`'d outside fleet-manager-backend, where the kafka_units-derived override never runs.

`charts/fleet-manager-strimzi/values.schema.json` — added a `cruiseControl` schema block (previously absent entirely) covering `enabled`/`config`/`resources`/`brokerCapacity`.

Test coverage added: `charts/fleet-manager-strimzi/tests/cruisecontrol_test.yaml` (rendering fidelity + regression assertion that `1000KB/s` never renders again) and `fleet-manager-backend/core/tests/services/test_kafka_workload_charts_service.py` (`compute_strimzi_broker_capacity` unit tests — regression, floor, scaling, invalid-input, and cpu/memory cases — plus full-pipeline and operator-override-precedence integration tests).

### Fix: `self.healing.goal.violation.enabled: "true"` (finding #6 above) — kept for documentation value, not functional

`charts/fleet-manager-strimzi/templates/kafka.yaml` — added explicitly alongside the existing hardcoded `self.healing.enabled: "true"`. Finding #7 (above) confirmed live that Strimzi silently strips *both* flags before they ever reach Cruise Control, so neither actually does anything on this Strimzi version. The line is kept in the chart, with an inline comment pointing at this RCA, purely so a future reader doesn't re-add it believing it's the fix — the real fix for this class of gap is the event-driven approval controller below.

### Fix: event-driven Cruise Control proposal approval (`streamtime-operator`)

Since native self-healing is unreachable (finding #7) and `KafkaRebalance` has no auto-approval field, closing the gap requires external automation that creates/refreshes a `KafkaRebalance` CR per Cruise-Control-enabled cluster and approves it once a worthwhile proposal exists.

**`KafkaRebalanceReconciler`** (`streamtime-agent/internal/controller/kafka_rebalance_controller.go`) — a `sigs.k8s.io/controller-runtime` reconciler running inside `streamtime-operator`, watching `Kafka` and `KafkaRebalance` custom resources directly (unstructured, no vendored Strimzi Go types — the manager's scheme needs an explicit `AddKnownTypeWithName` entry per GVK for this to work, confirmed live: without it the watch silently delivers zero events). On any status change:

- `New`/`PendingProposal`/absent → no-op, wait for the next status change.
- `ProposalReady` → evaluate `isRebalanceWorthApproving(optimizationResult, minDataToMoveMB)`; if worthwhile, patch `strimzi.io/rebalance: approve`. The threshold check special-cases leader/replica-order-only proposals (`dataToMoveMB == 0` but `numLeaderMovements`/`numReplicaMovements > 0`) as always worth approving regardless of the MB threshold — confirmed live this is exactly the original bug's signature (all leaders pinned to one broker, zero bytes of actual data to move).
- `Ready`/`NotReady` (terminal from a prior cycle) → patch `strimzi.io/rebalance: refresh` so a fresh proposal is ready for next time.
- `Rebalancing` → no-op, don't double-trigger.

This is a genuine Kubernetes **watch**, not a poll: `KafkaRebalanceReconciler` reacts within about a second of Strimzi writing a new status, compared to the previously-shipped version of this fix (a Temporal cron workflow polling every 30 minutes, since replaced — see "Superseded design" below). Gated by its own `GlobalConfiguration`-style kill-switch (`controller.rebalanceApproval.enabled`, off by default) via `streamtime-operator`'s Helm values.

**Superseded design.** An earlier version of this fix used a Python Temporal workflow (`CruiseControlRebalanceWorkflow`, cron `*/30 * * * *`) dispatching a per-cluster Go child workflow. It was fully implemented, tested, and live-verified, then replaced after review — event-driven reaction to Strimzi's own status updates is strictly better than a fixed poll interval for this specific problem, and removing the Temporal round-trip (backend dispatch → orchestrator → agent task queue) in favor of a direct in-cluster K8s watch is simpler to operate. No trace of the cron design remains in the current implementation.

### Fix: bounded stale-proposal recheck (gap found during live verification of the fix above)

Pure event-driven reconciliation turned out to be insufficient on its own. `KafkaRebalanceReconciler` only ever fires when the `KafkaRebalance` CR's own `status` object changes — but Strimzi/Cruise Control never rewrites a `ProposalReady` CR's status spontaneously; it only recomputes on CR creation or an explicit `strimzi.io/rebalance=refresh` annotation. So once a below-threshold proposal was evaluated and skipped, the CR sat unchanged forever: no further watch event ever fired for it, even after real new skew appeared on the cluster. Confirmed live: a second demo run against the same standing `cc-scheduled-rebalance` CR (left at `ProposalReady`/skip by an earlier, unrelated cleanup pass) never got approved despite a genuinely skewed fresh topic, because there was no event for the reconciler to react to.

This isn't fixable by watching a different Kubernetes resource instead. This platform's real topic-creation path never touches Kubernetes: `fleet-manager-backend`'s Kafka topic code is read-only, customers create topics by connecting directly to the Kafka broker protocol, and the cluster's KRaft-mode Strimzi Topic Operator (unidirectional only) doesn't discover topics created that way and reflect them back as `KafkaTopic` CRs. There is no missing watch to add — Cruise Control's own recomputation is driven by its internal metrics pipeline, which has no Kubernetes-native event at all.

The fix bounds a `RequeueAfter`-based recheck, tracked via annotations on the `KafkaRebalance` CR itself rather than Strimzi's own status timestamps (survives controller restarts, is unambiguous, and is directly visible via `kubectl describe`):

- `streamtime.io/rebalance-skipped-at` — when the current stale-tracking window started.
- `streamtime.io/rebalance-recheck-count` — consecutive forced refreshes not yet confirmed to have reached Cruise Control.

On a `ProposalReady` proposal below threshold: the first sighting stamps `rebalance-skipped-at` and requeues after `RebalanceRecheckInterval` (default 300s, `0` disables rechecking and reverts to the original purely-event-driven behavior). If still below threshold once that window elapses, the reconciler patches `strimzi.io/rebalance=refresh` to force Cruise Control to recompute, increments `rebalance-recheck-count`, and resets the window — the refresh itself causes a real Strimzi status transition (`ProposalReady → PendingProposal → ProposalReady`), which re-triggers `Reconcile` via the existing watch, so genuine new skew gets caught and approved on that pass.

`rebalance-recheck-count` specifically bounds **consecutive refreshes that don't appear to be reaching Cruise Control** — a real failure mode already observed live this session (a Strimzi-side bug, `"Executor State null does not contain required 'finishedDataMovement' field"`, left a CR stuck in `Rebalancing` across several ignored annotations before eventually clearing) — not "how many times the cluster is allowed to be chronically imbalanced." Both annotations are cleared on approval and on reaching a terminal `Ready`/`NotReady` state. Once `RebalanceMaxRechecks` (default 12) is hit without confirmed progress, the reconciler stops sending `refresh` but keeps a slow hourly health-check requeue going rather than going permanently silent, and emits a `Warning RebalanceMaxRechecksExceeded` Kubernetes Event. (The original version of this design cleared the counter on an *observed* `PendingProposal` transition — see the next fix for why that turned out not to be reliable enough on its own.)

The reconciler also emits `Normal` events (`RebalanceRecheckScheduled`, `RebalanceRefreshTriggered`, `RebalanceApproved`) visible via `kubectl describe kafkarebalance`, since log lines alone aren't a durable audit trail for an automation that's expected to run unattended.

Cruise Control remains the only balancing authority throughout this fix — the reconciler never manipulates Kafka directly; it only ever asks Cruise Control, via the already-sanctioned `refresh` annotation, to look again.

### Fix: recheck-count false-positive from an unobserved `PendingProposal` flicker (third gap found during live verification)

The bounded recheck fix above shipped with one more bug, found by simply running the demo script again after a period of idle operation: `recheck-count` was designed to clear the moment the reconciler *observed* the CR in `PendingProposal` phase — proof a refresh had reached Cruise Control. In practice, on an already-balanced cluster, Cruise Control can recompute fast enough (well under a second, confirmed live) that the CR round-trips `ProposalReady → PendingProposal → ProposalReady` faster than this reconciler's next `Get()` ever lands on the intermediate state. controller-runtime reconciliation is level-triggered, not edge-triggered — a `Reconcile` call only ever sees the *current* state, so a transient phase that resolves between the watch firing and the `Get()` executing is invisible to it every single time.

The practical effect: with the operator running for under an hour at a fast `recheckIntervalSeconds=60` (used for rapid live-testing, not the `300`s production default, though the same failure mode is reachable there too given enough idle time), the recheck-count climbed by one every cycle regardless of whether the refresh actually worked, hit `RebalanceMaxRechecks` after 12 minutes, and the reconciler backed off refreshing for a full hour — exactly the window a subsequent demo run landed in. Confirmed via the CR's own annotations at the time of failure: `rebalance-recheck-count: "12"`, `rebalance-skipped-at` twelve refresh-cycles old, and a completely empty operator log for the entire wait window (nothing to log — the reconciler had already silently given up before the run even started).

Fix: stop relying on directly observing the transient phase. Add a fourth annotation, `streamtime.io/rebalance-last-known-transition`, that records Strimzi's own `status.conditions[].lastTransitionTime` on the `ProposalReady` condition (used purely as an opaque change-detection token, not for measuring elapsed time — that stays annotation-based via `rebalance-skipped-at`, for the same restart-survival reasons as before). Before doing anything else, the reconciler compares the CR's *current* `lastTransitionTime` against the stored one: a mismatch is direct proof Cruise Control recomputed since the last check — regardless of whether the intermediate `PendingProposal` state was ever independently observed — so `rebalance-recheck-count` resets and a fresh cycle begins. Only when the timestamps match (the condition genuinely hasn't moved since last checked) does the reconciler proceed to the recheck-count/staleness logic. A CR upgrading from the previous version of this code (present `rebalance-skipped-at`/`rebalance-recheck-count`, absent `rebalance-last-known-transition`) is treated the same as a first sighting rather than as confirmed-stale, so no pre-existing CR gets stuck mid-upgrade.

### Explicitly out of scope: per-topic leader distribution

Cruise Control's own goals (`LeaderReplicaDistributionGoal`, `TopicReplicaDistributionGoal` — both already enabled in this chart's `default.goals`) balance leader/replica **counts cluster-wide**, not per topic. Live testing during this work confirmed a cluster can look balanced in aggregate while one specific topic stays fully pinned to a single broker, because other topics' distributions compensate in the aggregate count.

Fixing that gap would require either a custom Cruise Control goal (a heavy lift — building and deploying a custom analyzer JAR) or bypassing Cruise Control entirely via direct Kafka Admin API calls (`AlterPartitionReassignments`/`ElectLeaders`). A `TopicLeaderBalanceReconciler` doing the latter was built and live-verified working during this investigation, then deliberately removed after review, because:

- Cruise Control already owns cluster-wide balancing; a second component directly manipulating partition leadership/replica assignment creates a second, independent balancing authority that can fight the first.
- Raw Kafka partition leadership has no Kubernetes-native watch event, so this piece could only ever be a periodic poll (not truly event-driven like the approval flow above) — a materially different operational model bolted onto an otherwise fully event-driven design.
- It required a new Go dependency (`github.com/IBM/sarama`), a dedicated `KafkaUser`/ACL with `Alter` on the cluster resource (a bigger permission grant than anything else this operator does), and its own failure modes (in-flight-reassignment checks, ISR-completeness checks, replica-set-widening guards) — real operational complexity not required to fix the original bug.
- The original incident is fully addressed by the capacity fix + event-driven approval above; per-topic distribution was never part of the reported problem.

If per-topic leader distribution becomes a real requirement later, treat it as a separate initiative with its own design review — not an extension of this fix.

### Fix: `brokerCapacity.memory` removed (finding from live verification)

`brokerCapacity.memory` is not a field the Strimzi Kafka CRD (`kafka.strimzi.io/v1`) recognizes — only `cpu`/`inboundNetwork`/`outboundNetwork`/`overrides` exist. A `memory` key is silently dropped by the Kubernetes API server with an "unknown field" admission warning. This was true of the *original* buggy static block too (`memory: "2Gi"`, equally a no-op) — not a regression from this fix, but confirmed live during verification and removed from `compute_strimzi_broker_capacity`, `values.yaml`'s fallback, and `values.schema.json` while already touching these files.

---

## Impact on other services

**No retroactive effect on already-provisioned clusters.** Chart values are snapshotted into the Temporal workflow input at explicit Create/Update dispatch time (per the codebase's "snapshot at start" design principle) — no periodic reconcile or Temporal `Schedule` recomputes an existing cluster's Helm values. This fix only takes effect the next time a Create or Update is explicitly dispatched for a given Kafka resource. The specific production cluster from the original report will keep its undersized `brokerCapacity` until an Update is explicitly triggered for it — tracked as a separate operational follow-up, not part of this code fix.

**Mechanical risk is low.** `spec.cruiseControl.brokerCapacity` is a Cruise-Control-config-side field only; changing it does not trigger Kafka broker pod restarts.

**Behavioral risk is real and intentional.** Any cluster that has silently accumulated leadership/replica skew under the old ceiling may see its first-ever real Cruise Control rebalance execute automatically shortly after its next Update — that is the fix working as intended, but it is a genuine behavior change (a burst of inter-broker replica-fetch traffic), not a no-op config bump. Roll out to a non-critical cluster first where possible and monitor `KafkaRebalance` CR status and the Cruise Control pod's own logs afterward.

---

## Prevention

| Guard | Location | What it prevents |
|---|---|---|
| `compute_strimzi_broker_capacity` derives from `kafka_units` | `kafka_workload_charts.py` | A future chart edit reintroducing a static, unrealistic placeholder |
| Headroom factor + floor constants, named and commented | `kafka_workload_charts.py` | The derived ceiling silently collapsing toward zero for small tiers (the original failure mode) |
| Chart-test regression assertion (`1000KB/s` must never render) | `cruisecontrol_test.yaml` | A future refactor silently reverting to the old placeholder |
| `values.schema.json` `cruiseControl` block | `values.schema.json` | Cruise Control values passing through completely unvalidated, as they did before this fix |
| Inline `values.yaml` comment on the ~25 min load-monitor warm-up | `values.yaml` | Re-litigating the warm-up period as a second bug in a future investigation |
| `self.healing.goal.violation.enabled: "true"` explicit flag (documentation value only — see finding #7) | `templates/kafka.yaml` | A future reader re-discovering finding #6 without realizing the flag itself is a dead end |
| `KafkaRebalanceReconciler` (event-driven, `streamtime-operator`) | `streamtime-agent/internal/controller/kafka_rebalance_controller.go` | The actual gap this incident traces to: a satisfiable proposal existing but nothing ever approving it |
| Bounded stale-proposal recheck (`rebalance-skipped-at`/`rebalance-recheck-count` annotations, `RebalanceRecheckInterval`/`RebalanceMaxRechecks`) | `streamtime-agent/internal/controller/kafka_rebalance_controller.go` | A skipped, below-threshold proposal going permanently unreviewed — pure event-driven reaction alone missed any skew introduced after the first proposal was evaluated |
| `rebalance-last-known-transition` annotation (compares Strimzi's own condition timestamp instead of requiring a directly-observed `PendingProposal` reconcile) | `streamtime-agent/internal/controller/kafka_rebalance_controller.go` | `rebalance-recheck-count` climbing on every cycle regardless of whether a refresh actually worked, whenever Cruise Control recomputes faster than the reconciler's next `Get()` — leading to a false `RebalanceMaxRechecksExceeded` lockout on a perfectly healthy pipeline |

---

## Lessons Learned

1. **A hard capacity goal that's undersized doesn't fail loudly — it fails by never proposing anything.** Cruise Control's hard-goal semantics mean an infeasible ceiling produces total silence from the self-healing loop, not an error. The diagnostic fingerprint is: no `KafkaRebalance` activity, no proposal, and — critically — check the **Cruise Control pod's own logs**, not broker logs, since the failure is entirely internal to its optimization loop.

2. **Values copy-pasted from an adjacent, differently-scoped block are a silent trap.** `brokerCapacity.cpu`/`memory` matching `cruiseControl.resources.limits` exactly (the CC pod's own limits, not broker capacity) was itself the tell that these were never actually derived from broker sizing — worth grepping for suspicious exact-value matches between semantically unrelated config blocks during review.

3. **A config field with zero test coverage since introduction is a config field nobody has verified in years.** `brokerCapacity` sat untouched and untested from `ce4740dee` to this fix — any hardcoded value in a Helm chart that gates real infrastructure behavior needs at least a rendering assertion, even if the "real" value requires backend derivation to get right.

4. **Chart value snapshotting means fixes to derived Helm values aren't retroactive.** Because this codebase snapshots chart values into the workflow input at dispatch time rather than reconciling periodically, shipping this fix does not automatically repair already-provisioned clusters — that requires a deliberate follow-up per affected cluster.

5. **A blanket legacy flag ("enable self-healing") is not proof that the specific behavior you need is on.** `self.healing.enabled: "true"` reads as "self-healing is on," but Cruise Control's runtime `AnomalyDetectorState` showed `GOAL_VIOLATION` in `selfHealingDisabled` regardless. Live verification (creating the actual skew and watching `/state`) caught this; static config review alone would not have — `isProposalReady: true` looks like success right up until you notice the violation's `status` field says `IGNORED`.

6. **Live-testing a fix on a real cluster surfaces class of bugs that unit tests structurally cannot.** The CRD `memory` field mismatch, the self-healing cascade gap, and Strimzi's blanket rejection of `self.healing.*` config were all invisible to `helm-unittest` (which only proves template rendering) and to backend unit tests (which only prove Python computation) — all three require an actual Strimzi operator interpreting the rendered CR against its live CRD schema and Cruise Control actually running the anomaly detector loop. The same held for the replacement controller itself: a controller-name collision, a missing scheme registration causing watches to silently deliver zero events, a check against a Strimzi field that structurally doesn't exist, and a wrong Kafka ACL operation name were each found only by deploying to the live kind cluster and watching real reconcile logs — none surfaced in unit tests, `go vet`, or chart-template tests, because each was specifically about the seam between this code and Strimzi/Kafka's actual live behavior.

7. **When you can't own the mechanism (Strimzi/Cruise Control's internals), don't build a second one that competes with it.** The instinct to "just fix it ourselves" (direct Kafka Admin API calls for per-topic leader correction) was tempting and was even built and proven working — but it would have created a second, independent balancing authority alongside Cruise Control, with its own periodic-poll operational model and permission surface, for a problem outside the original incident's scope. Removed after review in favor of staying inside Cruise Control's own decision-making and only automating the one genuinely missing piece: approval.

8. **"Event-driven" is only as complete as the set of events that actually occur.** `KafkaRebalanceReconciler` correctly reacts to every `KafkaRebalance` status change — but a below-threshold proposal that gets skipped never produces another status change on its own, so the reconciler went permanently silent for that CR, missing all subsequent real skew. This wasn't caught by unit tests (which only exercise the reconciler's reaction to a given state, not the absence of future events) — it took two live demo runs in a row against the same standing CR to surface, because the first run always looks correct. A bounded, annotation-tracked recheck closes the gap without reintroducing a fixed-interval poll for the common case. General lesson: when designing a watch-based reconciler, explicitly enumerate which states are guaranteed to eventually change on their own (the system being watched will write to them again) versus which are terminal from the reconciler's own inaction — the latter need an explicit bounded fallback, not an assumption that "something will trigger it eventually."

9. **Level-triggered reconciliation can silently miss a transient state, and a safety cap built on top of that assumption fails in the direction of "stop working," not "crash loudly."** The bounded-recheck fix's own safety valve (`RebalanceMaxRechecks`) assumed catching a `PendingProposal` reconcile was reliable evidence of progress; it wasn't, whenever the underlying system round-trips faster than the next `Get()`. The bug was invisible in isolated unit tests (which construct the intermediate state directly, side-stepping the very race that causes it in production) and only surfaced by leaving the operator running for real and re-running the same demo later — the exact "come back later and try again" step that's easy to skip when a live-verification session feels done after the first successful run. Any safety cap that resets on "observed evidence of progress X" needs to ask specifically: can the system transition through X and back out again before I'm guaranteed to see it? If yes, X isn't sufficient evidence on its own — compare a durable, monotonically-changing token (a timestamp, a generation, a resourceVersion) instead of relying on catching a transient phase.
