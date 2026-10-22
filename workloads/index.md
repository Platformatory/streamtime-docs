---
title: Workloads
nav_order: 5
layout: home
permalink: /workloads/
has_children: true
---

# Workloads

Streamtime runs three classes of workload on your fleets, and one fleet
can host any mix of them:

| Category | What it runs | Pages |
|---|---|---|
| **Streaming** | The message brokers themselves — Kafka-compatible clusters that applications produce to and consume from | [Streaming](/workloads/streaming/) |
| **Stream Processing** | Compute that reads from and writes to streaming platforms: Apache Flink deployments and jobs, Kafka Streams applications | [Stream Processing](/workloads/stream-processing/) |
| **Real-time Analytics** | Analytics databases fed by the streaming layer | [Real-time Analytics](/workloads/analytics/) |

When you create a fleet you choose which classes it serves and how much
capacity each gets, and the workloads you deploy then land on the fleets
that serve their class.
