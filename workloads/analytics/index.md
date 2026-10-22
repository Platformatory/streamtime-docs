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
| **ClickHouse** | Supported | Columnar analytics database deployed by Streamtime on your fleets, kept in step with your Kafka data |

## ClickHouse

A ClickHouse cluster is a Streamtime-managed workload like any other:
created from the console, API or CLI, monitored, upgraded and deleted
the same way.

{% capture ui %}
1. In the sidebar, go to **ClickHouse clusters** and select **Create
   cluster**.
2. Set the **Identifier**, pick the fleet, and choose the
   capacity.
3. Select **Create**. The cluster appears with the status
   **Provisioning**, then **Running**, with its console URL.
{% endcapture %}

{% capture cli %}
```bash
streamtime clickhouse create --identifier events --fleet <fleet>
streamtime clickhouse list
streamtime clickhouse get events
```
{% endcapture %}

{% capture mcp %}
MCP reads ClickHouse state (`list_clickhouses`, `get_clickhouse`); it
does not create clusters.
{% endcapture %}

{% include tabs.html id="clickhouse-create" ui=ui api=none cli=cli mcp=mcp %}

Data typically arrives from Kafka through a connector or a stream
processor; see [Workloads](/workloads/) for the platforms that feed it.
