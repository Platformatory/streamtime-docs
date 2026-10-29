---
title: "LeafCuttr (Experimental)"
parent: Streaming
ancestor: Workloads
nav_order: 7
---

# LeafCuttr (Experimental)

LeafCuttr is an Apache Kafka-compatible broker with Kafka-backed native
interfaces for MQTT and HTTP, suited to edge and IoT use cases. Clients
authenticate with SASL/SCRAM-SHA-512 or SASL/OAUTHBEARER, and access is
controlled with ACLs.

{: .warning }
LeafCuttr is experimental. You can select it when you create a cluster, but
Streamtime can't provision LeafCuttr clusters yet, so a new cluster never becomes
**Healthy**. Use another Kafka provider for now, such as
[Apache Kafka]({{ site.baseurl }}/workloads/streaming/apache-kafka/).

## When it becomes available

LeafCuttr clusters will be managed like other
[streaming workloads]({{ site.baseurl }}/workloads/streaming/): created on a
Kubernetes fleet with Shared or Isolated tenancy, from the UI, API, CLI or an
AI assistant. LeafCuttr has no advanced settings. This page will then
describe each task.
