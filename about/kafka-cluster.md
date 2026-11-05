---
title: Workload types
nav_order: 6
parent: About Streamtime
---

# Workload types

A **workload** is something Streamtime runs on a fleet for you. There are
three kinds, and one fleet can run any mix of them:

| Kind | What it runs | Sized in | Platforms |
|---|---|---|---|
| **Streaming** | Kafka-compatible clusters your applications produce to and consume from, plus Kafka Connect, Kafka Replicator and virtual Kafka clusters | [Kafka Units]({{ site.baseurl }}/about/scaling/#kafka-units) | Apache Kafka, Confluent (CFK), WarpStream, Redpanda (preview), AutoMQ (experimental), Confluent Platform on VMs; LeafCuttr and Tansu (experimental, not provisioned yet) |
| **Stream Processing** | Apache Flink: Job Workspaces you submit jobs to, single-job clusters, and Flink projects that hold your code | [Flink Units]({{ site.baseurl }}/about/scaling/#flink-units) | Apache Flink, Confluent Flink |
| **Analytics** | ClickHouse, the columnar database fed from your streams | [ClickHouse units]({{ site.baseurl }}/about/scaling/#clickhouse-units) | ClickHouse |

Every workload has the same lifecycle in every interface (console, API,
CLI, MCP and, where a resource exists, Terraform): create it on a fleet,
check its status, change or scale it, upgrade its **Version**, monitor it
and delete it. Each workload's page walks through these tasks.

A fleet only runs the kinds of workload it was set up for, with the
capacity it was given for each; see
[Capacity units]({{ site.baseurl }}/about/scaling/#fleet-capacity).

See [Workloads]({{ site.baseurl }}/workloads/) for every platform's page.
