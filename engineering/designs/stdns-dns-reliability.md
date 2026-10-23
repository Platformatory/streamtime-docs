# Streamtime DNS (STDNS): ownership records and cleanup

Retrospective spec (written after implementation, PR #1393) for review.
Follows `dns-record-deletion.md` (external-dns `policy: sync`, STDNS webhook reads).

## Objective

Records external-dns publishes in STDNS are owned (TXT ownership record) so external-dns
can update and delete them, and a deleted Kafka cluster's records leave the shared
`streamti.me` zone even when ownership is missing.

## Findings (2026-10-05, k3-halebeedu)

- The webhook spent ~7 sequential STDNS calls per record (pre-upsert delete, purge,
  lookup, create). external-dns cancelled the batch after ~15 s, after the A records and
  before their TXT ownership records (it lists A first). Unowned records are never
  retried or deleted (female-turtle).
- A non-JSON STDNS error was reported as `decode: invalid character` (status and text
  lost) — a-cc-wet-gerbil.
- Several infra-shared routes annotated the same `shared-<fleet>` hostname; the TXT
  owner's resource label flipped every sync (~14 s of writes per minute).
- Deleted clusters' records filled the zone until Cloudflare rejected new ones
  (`81045 Record quota exceeded`); STDNS kept them as "synced" in its inventory, so
  external-dns did not retry.

## Design

1. Webhook (`internal/stdnswebhook/server.go`): deletes, then TXT ownership records,
   then the rest; one call per record (`stdnsclient.PutRecord`: POST with
   `forceOverwrite`, purge-and-retry only on 409); up to `WEBHOOK_CONCURRENCY` (default 4)
   writes at once; every record attempted before a 500 lists the failures.
2. Client (`pkg/stdnsclient`): status checked before decoding; non-JSON error text kept.
   The cert-manager DNS-01 solver keeps `UpsertRecordWithOutcomeScoped` (purge-first, for
   stale ACME challenges).
3. external-dns: `webhook-provider-read-timeout=1m`, `webhook-provider-write-timeout=2m`.
4. infra-shared `kong-http-routes.yaml`: a hostname is annotated on the first rendered
   route only (prometheus, alertmanager, loki, opencost, otel order).
5. Explicit cleanup on Kafka delete: `DELETE /organizations/{org}/base-domains/{domain}/dns-records/{name}/`
   (STDNS base domains only, names under the domain only, 204 when already gone) →
   orchestrator activity `delete_stdns_dns_record` → CFK, Strimzi, Warpstream and Redpanda
   delete workflows delete the hostnames they already compute for Route53
   (`workflows/dns_cleanup.py`, `workflow.patched("kafka-delete-stdns-dns-records")`).

## Out of scope

- STDNS accepting a record Cloudflare rejected without surfacing it (STDNS service).
- Existing unowned records: removed as their clusters are deleted (item 5); one-off
  cleanup done by hand on 2026-10-05 (31 records).
- Kafka Connect / Flink / fleet records cleanup through the new endpoint.

## API contract impact

Added `DELETE .../base-domains/{domain}/dns-records/{name}/` (used by the orchestrator).

## Tests

- Go: `stdnsclient` (PutRecord, conflict fallback, non-JSON errors, existing solver
  paths); webhook (ownership first, failures still attempt the rest, concurrency cap)
  under `-race`.
- Backend: `test_stdns_dns_record`, `test_external_dns_bootstrap` (timeouts), OpenAPI path
  manifest.
- Chart: infra-shared shared-hostname annotation.
- Orchestrator: CFK and Strimzi delete STDNS records in order; pre-patch replays delete none.
- Live: endpoint 204 / 400 / 404 cases.

## Rollout

`stdns-webhook:latest` is pulled by every fleet: behaviour changes when its pod restarts
after the image is pushed. Timeouts and the hostname change apply on bootstrap /
infra-shared upgrade.
