---
title: Stream Processing
nav_order: 2
parent: Workloads
permalink: /workloads/stream-processing/
has_toc: false
has_children: true
---

# Stream Processing

Compute that reads from your streaming platforms, transforms the data,
and writes it back — continuously, at the speed the data arrives.

| Platform | Status | In short |
|---|---|---|
| **Apache Flink** | Supported | Stateful stream processing: projects hold your code, deployments run it against your Kafka clusters |
| **Kafka Streams** | BYO runtime | A Java library, not a Streamtime-managed platform: your applications run it, Streamtime's clusters provide the streams |

## Apache Flink

Flink runs through **projects**: a project holds your application code
and builds, and from it you roll out **deployments** that consume and
produce on the Kafka clusters in your organization.

{% capture ui %}
1. In the sidebar, go to **Flink projects** and select **Create
   project**.
2. Name the project and select the organization's source for
   builds.
3. Upload or trigger a build, then create a **Deployment** from the
   build and start it. The deployment consumes and produces on your
   Kafka clusters; its status appears in the project view.
{% endcapture %}

{% capture cli %}
```bash
streamtime flink-project create --identifier orders-enrich
streamtime flink-project upload  orders-enrich <artifact>
streamtime flink create --project orders-enrich --identifier nightly-rollup
streamtime flink list
```
{% endcapture %}

{% capture mcp %}
MCP reads deployment and cluster state; it does not create or start
Flink deployments.
{% endcapture %}

{% include tabs.html id="flink-project" ui=ui api=none cli=cli mcp=mcp %}

## Kafka Streams

Kafka Streams is a client library inside your own Java applications —
Streamtime does not deploy it. What Streamtime provides is the
platform it runs against: the Kafka clusters, their authentication,
and the monitoring of the topics Streams applications read and write.
