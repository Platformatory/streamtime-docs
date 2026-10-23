# Native Kafka UI — Build Phases

Companion to `native-kafka-ui.md`. Each phase is one Claude Code session and one
PR. A phase is finished when its own tests are green in CI, not when the code
looks right.

Two deliberate deviations from the `Delivery sequence` in the plan:

1. **Providers fan out last, not first.** The plan's step 1 adds registration to
   every deployable Kafka workflow before anything consumes the CR. That commits
   four workflows and four ACL principals to an unvalidated contract. Do Strimzi
   only, prove it through a running Go service, freeze the contract, then fan out.
2. **The fleet-local REST contract is a checked-in artifact before any handler is
   written.** The Go handlers and the Django Pydantic schemas are written from the
   same file, in different phases, weeks apart. Without a frozen spec they drift.

---

## Stage A — Contract

### Phase 0 — Spec freeze and repo scaffolding
Not code. Sets up every later session.

- Check `native-kafka-ui.md` into the repo (e.g. `docs/plans/native-kafka-ui.md`).
- Write `streamtime-kafka-admin/api/openapi.yaml`: the eleven fleet-local routes,
  request/response schemas, and the closed error-code enum (`cluster_unavailable`,
  `topic_not_found`, `invalid_topic_update`, `topic_deletion_disabled`,
  `cursor_expired`, `request_timeout`). Mark every object `additionalProperties: false`.
- Add a `CLAUDE.md` section pointing at both files, plus the standing constraints:
  no provider branching in Go, no Temporal for topic ops, no message payloads in
  logs, no credentials in responses.

**Done when:** the spec lints and the error enum is exhaustive.

### Phase 1 — CRD extension
Files: `streamtime-agent/api/v1alpha1/streamtimekafkacluster_types.go`,
`zz_generated.deepcopy.go`, `config/crd/streamtimekafkacluster.yaml`,
`charts/streamtime-operator/templates/crd.yaml` + CRD tests.

- `spec.connection`: `bootstrapServers []string` (minItems 1), `securityProtocol`
  as a kubebuilder enum of `PLAINTEXT|SSL|SASL_PLAINTEXT|SASL_SSL`, `sasl`
  (mechanism enum + `secretName` with `usernameKey`/`passwordKey`), `tls`
  (`secretName`, `caKey`, `certificateKey`, `privateKeyKey`), optional
  `serverName`, optional `isolationLevel`.
- `spec.schemaRegistry`: optional `url`, `tls`, `authentication` (`type: basic|bearer`
  + secret key selectors).
- `spec.provider` becomes optional and documented as diagnostic-only.
- Every credential is a namespaced secret key selector. No `stringData`-shaped
  field exists anywhere in the type — enforce this with a schema test that greps
  for password/token-typed strings.

**Done when:** `make generate manifests` is clean, CRD applies to a kind cluster,
and an invalid `securityProtocol` is rejected by the API server in a test.

### Phase 2 — Strimzi registration + contract test suite
- New shared helper (e.g. `streamtime-agent/internal/kafkaregistration/`) that
  upserts and deletes the CR. Workflows call the helper; they do not hand-build CRs.
- Strimzi CREATE upserts the CR **after** the internal listener is ready and the
  dedicated `KafkaUser` exists. UPDATE re-upserts. DELETE removes the CR before
  the namespace/credentials.
- The admin `KafkaUser` ACLs: `Describe`/`DescribeConfigs` on cluster and topics,
  `Create`, `Delete`, `Alter` (partition increase), `AlterConfigs` on topics, and
  `Read` on topics. No `Group` operations at all — that is what keeps the message
  reader from committing offsets even by accident.
- Write the contract test as an exported, table-driven suite that later providers
  import unchanged. It asserts: internal listener address present, secret refs
  resolvable, no plaintext material, optional Schema Registry block, and DELETE
  ordering.

**Done when:** Strimzi passes the shared suite and the suite is importable.

---

## Stage B — Go service

New module `streamtime-kafka-admin/`. `franz-go`, distroless, non-root, static binary.

### Phase 3 — Skeleton, config, discovery, `GET /clusters`
- `cmd/server/main.go`, `internal/config`, `internal/discovery`, `internal/httpapi`.
- Informer over `StreamtimeKafkaCluster` with a label selector on
  `streamtime.ai/managed=true`. In-cluster config only.
- `readyz` returns 200 once `HasSynced()` is true — not when brokers are reachable.
  `healthz` is liveness only.
- Startup with zero CRs must succeed and `GET /clusters` must return `[]`.
- Malformed CRs are quarantined per-cluster and surfaced in the list response;
  they never fail the informer loop.
- Prometheus metrics registered with no topic/payload labels.

**Decision to make here:** secret invalidation needs a second informer. Watching
all Secrets fleet-wide is the wrong RBAC posture. Prefer a `SingleNamespace`-free
informer with a field/label selector, or per-referenced-secret watches driven off
the CR cache. Pick one now and write it down; Phase 4 depends on it.

**Done when:** fake-informer tests cover add/update/delete and quarantine.

### Phase 4 — Client factory and cache
- `internal/client`: build a `kgo.Client` from `spec.connection`. Full matrix of
  the four security protocols plus each SASL mechanism.
- Cache key includes the CR `resourceVersion` **and** the `resourceVersion` of every
  referenced Secret. A rotation changes the key, the old client is closed on
  eviction, and no pod restart is needed.
- Bounded entries plus idle TTL. Connection timeout, request timeout, and max
  in-flight are mandatory config, not defaults buried in the library.

**Done when:** testcontainers Kafka covers SSL and SASL_SSL, and a secret rotation
test asserts reconnect without restart.

### Phase 5 — Topics
- `internal/topics`: list (server-paginated), create, get, patch, delete.
- PATCH: partition increase only — reject decreases with `invalid_topic_update`
  before hitting the broker. `configs.set` and `configs.delete` map to
  `IncrementalAlterConfigs` with `SET` and `DELETE` ops.
- DELETE: require `confirm=true` plus exact name in the body, use `DeleteTopics`,
  wait on the broker ack only, treat `UNKNOWN_TOPIC_OR_PARTITION` as success,
  and map `TOPIC_DELETION_DISABLED` to `409 topic_deletion_disabled`.
- Error normalization table from Phase 0. Broker addresses never appear in errors.

**Done when:** integration tests include a broker started with
`delete.topic.enable=false` and a principal deliberately missing `Delete`.

### Phase 6 — Message browsing
The hardest phase. Keep it alone.

- Cursor codec: versioned struct with direction, topic identity, partition set,
  and per-partition offsets; opaque to clients; validated against the route and
  the *current* partition set on every request.
- `position=beginning` seeks each partition's earliest offset and pages forward;
  `position=latest` reads back from high watermark and pages backward. Both return
  exactly ten merged records per page.
- Direct partition assignment, no consumer group, no commits. Assert in a test
  that `ListConsumerGroupOffsets` is empty after a full browse.
- `read_committed` default. Merge by timestamp, then partition, then offset.
- Bounded `MaxBytes`; a single oversized record is truncated and flagged rather
  than dropped or allowed to blow the response.
- Offsets below the earliest available return `409 cursor_expired`.
- Key/value as UTF-8 when valid, Base64 otherwise, with explicit encoding fields.

### Phase 7 — Schema Registry
- `internal/schemaregistry`: Confluent REST client, basic/bearer auth, TLS, same
  timeouts and size bounds as Kafka.
- Wire format: magic byte `0x00` + 4-byte big-endian schema ID. Resolve **by ID
  first**; do not assume `TopicNameStrategy`. Expose matching subjects as metadata.
- Avro and JSON Schema decode straightforwardly. Protobuf needs the Confluent
  message-index varint prefix and a dynamic descriptor built from the registered
  `.proto` source — budget for `protocompile`/`protoparse` and a resolver for
  references with explicit depth and cycle limits.
- Schema-by-ID and subject metadata caches with bounded TTL and entry count.
- Registry down or absent ⇒ `capabilities.schema_registry` reports the error state,
  and every message falls back to raw UTF-8/Base64. Topic administration is unaffected.

**Done when:** decode tests cover all three types, references, malformed payloads,
and a registry that is simply unreachable.

---

## Stage C — Delivery

### Phase 8 — Helm chart
`charts/streamtime-kafka-admin/` with Deployment, Service, ServiceAccount,
least-privilege RBAC (list/watch on the CRD, get on referenced Secrets only),
NetworkPolicy (ingress from the Kong data plane only; egress to Kafka + DNS),
PodMonitor, PDB, probes wired to `/healthz` and `/readyz`, `values.schema.json`,
HTTPRoute with `parentRef` to `kong-gateway`, hostname `shared-{fleet}.{domain}`,
path match `/kafka-admin`, `URLRewrite` stripping the prefix, plus KongPlugin
basic-auth, KongConsumer, and credential Secret.

helm-unittest must assert **no** additional Gateway or Service of type LoadBalancer.

### Phase 9 — Package lifecycle
Tracked repositories for the image and chart, enabled PackageRules with explicit
supported versions, preload/seed migration, package sync discovery, Package Preset
exposure limited to resources/replicas/log level/timeouts/node placement, CI
workflows (`test-` and `build-streamtime-kafka-admin.yaml`), build-and-push script
coverage, SBOM/provenance/signing/scanning. Resolution must work against both the
local mirror and the GHCR namespace form. Reject `latest` at runtime.

### Phase 10 — Bootstrap and orchestrator
Highest blast radius in the whole project — isolate it.

- `bootstrap_resolver.py`: `streamtime_kafka_admin` component ordered after
  `fleet_manager_infra_shared`, versions resolved through `PackageRuleService`.
- `fleet_provider_base.py`: computed values, endpoint persistence
  (`type="kafka_admin"`, `https://shared-{fleet}.{domain}/kafka-admin`),
  installed-component bookkeeping, teardown before shared Kong.
- **`shared_credentials.kafka_admin` soft-fill.** Existing fleet secrets have no
  such key. UPDATE must add only the missing key and preserve every existing
  metrics/cost/alerts/logs/otel/dashboard credential. Write the test against a
  fixture of a real existing secret shape before writing the code.

**Human checkpoint:** bootstrap a dev fleet, then run UPDATE twice and assert
idempotency and that no pre-existing credential changed.

---

## Stage D — BFF and UI

### Phase 11 — Django BFF
`core/schemas/kafka_admin_schema.py` generated from the Phase 0 spec,
`core/services/kafka_admin.py` (load with `select_related("fleet", "organization")`,
resolve endpoint, read credential via `SecretsManager`, `httpx.AsyncClient` with
TLS verify + strict timeout + response-size bound + Basic auth, validate with
Pydantic, map errors), thin async views, `KafkaPermission` on every route,
percent-encoded path segments with ambiguous decoded slashes rejected.

`topic-configuration/` stays, reimplemented as an adapter over the new service with
its response fields unchanged. Regenerate OpenAPI, the orchestrator client snapshot,
and `api-types.d.ts` in the same PR.

### Phase 12 — Frontend: topics
`src/features/kafka-admin/` service + TanStack hooks, `KafkaTopicsPage`,
`TopicCreateDialog`, `TopicConfigurationPanel`, `TopicDeleteDialog`, and the
`Topics` tab in `KafkaClusterDetail.js`. Mutation invalidation keys scoped by org
and Kafka id. Delete requires typing the exact topic name and is hidden for
read-only roles.

### Phase 13 — Frontend: messages and schemas
`MessageBrowser` (Beginning/Latest, ten rows, client-side cursor history for
Previous, cursor-expiry recovery, JSON pretty-print, encoding and schema badges,
never render HTML) and `SchemaRegistryPanel`, shown only when the capability is
reported. Add the test that asserts the browser never issues a request to a
`shared-{fleet}` hostname.

---

## Stage E — Fan-out and rollout

### Phase 14 — Remaining providers
CFK, Redpanda, WarpStream registration + dedicated principals against the frozen
Phase 2 suite. These are independent of each other and can run as parallel
sessions once the suite exists.

### Phase 15 — E2E and backfill
The nine-step end-to-end script from the plan, per provider. Backfill existing
clusters through normal workload updates. Confirm Kafbat resources, routes, and
endpoints are untouched.

---

## Working notes for Claude Code

- One phase per session. When a session starts, load only: the plan, this file,
  the OpenAPI spec, and the specific files that phase touches. The plan's file
  inventory is long enough that loading it all wastes the window.
- Ask for tests first on Phases 2, 6, 7, and 10. Those are the four where a
  plausible-looking implementation can be quietly wrong.
- Phases 3–7 are the same module and will accumulate context. Between them, have
  the session write a short `streamtime-kafka-admin/NOTES.md` recording decisions
  actually made (secret-watch strategy, cursor struct, cache keys) so the next
  session does not re-derive them differently.
- Phases 1, 8, 9, 11 are mostly mechanical and go fast. Phases 6, 7, 10 are where
  the schedule will actually go.
