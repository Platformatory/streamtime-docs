# Reconcile OpenAPI contract (#1369)

## Objective

Every `POST .../reconcile/` endpoint requires an `Idempotency-Key` header and
a `{"generation": <int>}` body, but the OpenAPI spec did not document either,
so SDK, CLI and UI consumers could not discover the contract. Document it in
one place, enforce exactly what is documented, and advertise it through
HATEOAS so clients can build the request from the resource itself.

## In scope

- `core/views/reconcile_common.py` is the single home of the contract:
  `ReconcileRequestSerializer`, the `Idempotency-Key` parameter, the
  `reconcile_schema()` decorator and `parse_reconcile_request()`. The minimum
  generation (`_MIN_GENERATION`) is shared by the schema and the runtime check
  so they cannot drift; negative and boolean generations return 400.
- All seven reconcile views (fleet, kafka, connect, benchmark, replicator,
  virtual cluster, flink) use `@reconcile_schema` + `parse_reconcile_request`.
- `_links.reconcile` / `_forms.reconcile` (with the `Idempotency-Key` header
  and `{"generation": ...}` body) on replicator, virtual cluster and Flink
  responses, declared on `KafkaReplicatorResponseSchema`,
  `VirtualKafkaClusterResponseSchema` and `FlinkResponseSchema`.
- Bundled reliability fixes found while verifying: Flink status-wait resource
  naming, perf-test replication factor capped by broker count, bounded Helm
  chart download dial timeout in the agent, extra headers in the test-harness
  client.
- `openapi_paths_manifest.json` updated to match the routes (the path-drift
  test requires it).

## Out of scope

- CLI subcommands and MCP tools for reconcile (none exist today).
- Changing reconcile semantics, generation handling or idempotency storage.
- Hand-editing `streamtime-sdk`; `test-pr` regenerates it.

## Approach

1. Define the contract once in `reconcile_common.py`; views only call it.
2. Add the HATEOAS envelope in `fleet_hateoas.build_reconcile_links_and_forms`.
3. Declare the envelope on the explicit response schemas (aliased
   `_links`/`_forms`, `populate_by_name`) so OpenAPI matches the payload.
4. Contract tests: `core/tests/test_reconcile_openapi_contract.py` plus
   per-resource reconcile view tests.

## Deviations

None. The earlier draft validated only "is an int" at runtime and omitted the
new envelope from the response schemas; both were corrected before merge.
