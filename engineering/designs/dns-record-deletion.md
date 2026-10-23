# DNS record deletion (#1346)

## Objective

DNS records that external-dns creates for a fleet are deleted when the
resource that published them is deleted — a Kafka / Connect / Flink route, or
the whole fleet. Before: `policy: upsert-only` never deleted, and fleet
teardown uninstalled external-dns first, so every record leaked.

## In scope

- external-dns `policy: sync` for Route53, Cloudflare, GoDaddy and STDNS
- Per-fleet TXT owner (`streamtime-fleet-<fleet>`) for Route53, which used the
  shared hosted zone ID
- Fleet teardown ordering: external-dns removed last, after a reconcile
- STDNS webhook (Go agent): read STDNS zone records so `sync` can see and
  delete them
- Regression tests for workload deletion, teardown ordering, Route53 owner ID
  and the STDNS record shape

## Out of scope

- External cleanup for fleets whose cluster is dead or unreachable (no
  in-cluster external-dns left to delete anything) — follow-up
- Records that leaked before this change (zone-ID-owned, no longer served) —
  manual cleanup
- Adopting zone-ID-owned Route53 records of existing fleets — migrated by hand
  (fewer than 5 clusters; see Deviations 2026-09-29)
- Chart changes — none needed

## Approach

1. Backend (`ExternalDnsBootstrapService`): `policy: sync`, `interval: 1m`,
   `triggerLoopOnEvent: true`. Deletes stay scoped to records tagged with the
   fleet's `txtOwnerId`.
2. Route53 owner becomes `streamtime-fleet-<fleet>`. Under `sync`, the shared
   zone-ID owner would let one fleet delete every other fleet's records.
3. Teardown: `build_fleet_teardown_releases` keeps its order (external-dns
   last). `tear_down_cluster` pulls external-dns out and removes it in a
   second `TeardownFleetClusterWorkflow` pass after the reconcile wait, so
   routes and namespaces from the first pass are gone before it stops.
4. The teardown change is behind `workflow.patched("external-dns-teardown-last")`.
5. STDNS webhook (`streamtime-agent/internal/stdnswebhook`, `pkg/stdnsclient`):
   parse `tenantIdentifier`/`cfRecordType`/`cfTarget`, list the whole license
   inventory page by page and filter by domain, delete by record type.

## Behavior change: existing Route53 fleets

Route53 fleets bootstrapped before this change own their records with the
hosted zone ID. On their next bootstrap/update their owner becomes
`streamtime-fleet-<fleet>` and zone-ID-owned records are **not** adopted, so
external-dns will neither update (e.g. a new load balancer target) nor delete
them, and treats them as foreign when it would create the same name.

Before updating such a fleet (fewer than 5 today), migrate its records by
hand, per hostname it serves (`shared-<fleet>`, Kafka/Connect/Flink routes,
`cmf`):

- no downtime: edit each ownership TXT record (`a-`/`aaaa-`/`cname-<name>`)
  and replace `external-dns/owner=<hosted-zone-id>` with
  `external-dns/owner=streamtime-fleet-<fleet>`; or
- simpler, ~1 min gap: delete the record and its TXT records; external-dns
  recreates them with the new owner on its next reconcile after the update.

Records of fleets that no longer exist are deleted by hand.

## Deviations

- **2026-09-25 — stateless migration.** Planned a per-fleet marker in
  `Fleet.metadata` to run phase 1 once. Dropped: metadata is also written by
  the discovery probe and BYOK paths, so a read-modify-write PATCH risks
  clobbering them. Phase 1 now runs on every Route53 bootstrap (~2 min extra);
  remove once all legacy fleets have been updated.
- **2026-09-25 — installed-components bookkeeping.** Records the phase-2
  (final) values, not the phase-1 overlay that was installed first.
- **2026-09-28 — pre-patch histories (PR review).** The teardown list keeps
  its original order (external-dns appended last); the second pass alone
  removes it last. Workflows started before rollout (`patched()` false) still
  install the non-deleting migration values, so they never reach `sync`
  without adopting zone-ID records; only the wait and switch to the final
  values are patch-gated.
- **2026-09-29 — STDNS webhook could not see records (live, sole-haddock).**
  `sync` never deleted on STDNS fleets: the webhook read `name`/`type`/`content`,
  but STDNS returns `tenantIdentifier`/`cfRecordType`/`cfTarget`, and its `name=`
  filter is exact-match (listing the apex returned only the apex). `GET /records`
  was always empty, so external-dns saw no owned records, re-created every
  endpoint each minute and planned `delete=0`. Fix in `pkg/stdnsclient` +
  `internal/stdnswebhook`: parse the STDNS fields, list the whole license
  inventory page by page (100/page) and filter by domain suffix, delete by
  record type. Out-of-scope note "Go agent … none needed" no longer holds.
- **2026-09-29 — Route53 TXT-owner migration removed (PR review).** The
  two-phase `--migrate-from-txt-owner` takeover (and `migration_values` in
  compute-components, the `external-dns-route53-owner-migration` patch and the
  second bootstrap install) added a code path and ~2 min to every Route53
  bootstrap for fewer than 5 legacy clusters. Dropped: new fleets get the
  per-fleet owner; records of existing fleets still tagged with the hosted
  zone ID are migrated by hand (rewrite the owner in their TXT records, or
  delete and let external-dns recreate them). Never merged or deployed beyond
  dev, so no in-flight history carries the removed patch marker.
