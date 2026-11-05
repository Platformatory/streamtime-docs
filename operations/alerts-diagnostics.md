---
title: Alerts & Diagnostics
nav_order: 2
parent: Operations
has_children: true
permalink: /operations/alerts-diagnostics/
---

# Alerts & Diagnostics

Streamtime collects metrics and logs for every fleet and every workload on
it, shows them in the console, and raises alerts from
[alert rules]({{ site.baseurl }}/operations/alerts-diagnostics/alert-rules/).

## Fleets

- **Cluster health:** the overall state of the fleet's Kubernetes cluster.
- **Nodes:** CPU, memory and storage per node.
- **Metrics dashboards** to find bottlenecks, and **logs** from every pod.

![Node Overview]({{ site.baseurl }}/assets/images/monitoring/node-overview.png)

## Kafka

- **Cluster health:** status and availability of each cluster.
- **Operations metrics:** produce and consume rates, partition
  distribution and replication.
- **Dashboards:** throughput, latency and errors per topic.
- Per platform: topic and Schema Registry metrics and Confluent Platform
  logs (Confluent); controller (KRaft) metrics (Apache Kafka).

![cluster health]({{ site.baseurl }}/assets/images/monitoring/cluster-health.png)

## Flink

- The deployment's **Monitoring** tab: metrics for the deployment and its
  jobs.
- **Logs** from the JobManager and the TaskManagers.
- The **Flink Web UI** (or the **Confluent Manager for Flink UI**) from the
  deployment's page, for job graphs, checkpoints and back pressure.
- Built-in alert rules for restarting jobs, failing or slow checkpoints,
  no free task slots and memory pressure (set through the API for now).

## ClickHouse

- The cluster's **Monitoring** tab: **Metrics**, and **Alert Rules**.
- Built-in alert rules for instances down, disk space and replication
  lag.

## Alerts

- [Alert rules]({{ site.baseurl }}/operations/alerts-diagnostics/alert-rules/):
  the built-in rules for each fleet and workload, and your own.
- Alerts show in the console and go to the fleet's
  [alert channels]({{ site.baseurl }}/bring-your-own/alert-channels/)
  (Slack, PagerDuty or a webhook).
- [Triage alerts and review history]({{ site.baseurl }}/operations/alerts-diagnostics/triage-alerts/),
  with Streamtime AI investigating an alert for you.

## Your own monitoring product

If your team already uses Datadog, Grafana Cloud or New Relic, Streamtime
can send a copy of each fleet's metrics and logs there too. See
[Bring Your Own Observability]({{ site.baseurl }}/operations/alerts-diagnostics/byo-observability/).
