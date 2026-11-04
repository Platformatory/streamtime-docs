---
title: Triage alerts and review history
parent: Alerts & Diagnostics
nav_order: 2
permalink: /operations/alerts-diagnostics/triage-alerts/
---

# Triage alerts and review history

When an alert fires, Streamtime's assistant investigates it and writes a report. The **Alerts** page sorts alerts by where they are in that process, so you can see first what still needs a person.

## Triage states

| State | Meaning |
|---|---|
| **AI-investigated** | The investigation finished and its report is ready (complete or partial). |
| **Investigating** | The investigation is waiting for a slot or running. |
| **Awaiting triage** | No investigation yet, the investigation failed, or it was closed before it started while the alert is still firing. |
| **Closed** | The investigation was closed, for example because the alert resolved. |

**Severity** shows the investigation's assessment once a report exists, and the alert's own severity before that.

An alert **needs attention** when it is neither closed nor being investigated, and it is still firing or assessed critical or major.

## In the UI

1. Open **Diagnostics → Alerts**.
2. The tiles at the top count **Firing**, **Critical firing**, **Needs attention**, **Awaiting triage**, **Investigating**, **AI-investigated** and **Closed (24h)** alerts. Next to them is the time it takes to close an investigation (median and 90th percentile).
3. Click a tile to list those alerts. Click it again to show every alert.
4. Narrow the list with **Status**, **Triage**, **Severity**, **Resource** and **Needs attention only**, and order it with **Sort by** (for example **Most severe first**).
5. Each alert shows its severity, status, triage state, fleet or Kafka cluster as labels. Click the fleet or cluster label to open it.

The filters are part of the page address, so a filtered list can be bookmarked or shared, and stays filtered when you reload the page.

Closing or resolving an alert whose investigation is still running stops the investigation; it shows as interrupted, with the steps it finished.

### Investigate an alert now

Investigations wait in a queue, and only a few run at once. To have one alert investigated straight away, click **Investigate now** on its row, or on its investigation page. It appears when the alert's investigation is still waiting, and on a firing alert that has no investigation yet or whose investigation was closed before it started. To investigate a resolved alert after the fact, use the API call below.

- If a slot is free, the investigation starts at once.
- If every slot is busy, it starts in a slot kept for this, without stopping the others.
- If another alert is already using that slot, it is next in the queue, and the button shows **Next in the queue**.

An investigation that is running or has finished can't be started again this way.

## Through the API

`GET /organizations/{org}/alerts/` takes these filters, alongside `limit`, `sort` and `investigation_status`:

| Parameter | Values |
|---|---|
| `triage_state` | Comma list of `investigated`, `investigating`, `awaiting_triage`, `closed` |
| `severity` | Comma list of `critical`, `major`, `warning`, `info`, `unknown` (the effective severity above) |
| `needs_attention` | `true` or `false` |
| `status` | The alert's status, e.g. `firing` or `resolved` |
| `resource_type`, `resource_identifier` | The resource the alert is about |
| `sort` | `severity` puts critical first, then the most recently updated |

An unknown value returns `400` with the allowed values. Each alert in the response has `triage_state`, `effective_severity` and `can_investigate_now`. `GET /organizations/{org}/alerts/stats/` includes `needs_attention`, `critical_firing`, `by_triage_state` (a count per triage state, using the same rules as the `triage_state` filter) and `p90_time_to_close_seconds`.

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://<your-streamtime-host>/organizations/<org>/alerts/?needs_attention=true&sort=severity"
```

To investigate an alert now, firing or resolved, `POST /organizations/{org}/alerts/{alert_id}/investigation/prioritize/` (no body). It returns the investigation, or `409` when the investigation is already running or has finished.

```bash
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  "https://<your-streamtime-host>/organizations/<org>/alerts/<alert-id>/investigation/prioritize/"
```

## With the assistant (MCP)

Ask, for example:

- *"Which critical alerts still need attention?"* (`list_alerts`)
- *"Which alerts keep coming back on kafka-prod this month, and how long do they take to resolve?"* (`summarize_incident_history`)
- *"Compare the last two benchmarks of kafka-prod"* (`list_benchmarks`, `compare_benchmarks`)
- *"Run a simple benchmark on kafka-dev"* (`run_benchmark`; it returns at once, and automated investigations can't start one)

The **Review operational history** prompt (`review_operational_history`) answers broader questions by combining incident history, current alerts, incident reports, recent changes, baselines and benchmarks.

## From the CLI

Alert triage isn't available in the CLI yet.
