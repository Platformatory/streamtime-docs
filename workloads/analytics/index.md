---
title: Real-time Analytics
nav_order: 3
parent: Workloads
permalink: /workloads/analytics/
has_toc: false
has_children: true
---

# Real-time Analytics

Analytics databases fed by your streaming layer, queried as the data
arrives.

| Platform | Status | In short |
|---|---|---|
| [**ClickHouse**](clickhouse.html) | Supported | Columnar analytics database deployed by Streamtime on your fleets, kept in step with your Kafka data |

## ClickHouse

A ClickHouse cluster is a Streamtime-managed workload like any other:
created from the UI, API or CLI, then monitored, scaled, upgraded and
deleted the same way. See [ClickHouse](clickhouse.html) for every task.

Data typically arrives from Kafka through a connector or a stream
processor; see [Workloads](/workloads/) for the platforms that feed it.
