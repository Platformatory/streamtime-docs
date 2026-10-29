---
title: "Tansu (Experimental)"
parent: Streaming
ancestor: Workloads
nav_order: 8
---

# Tansu (Experimental)

Tansu is an Apache Kafka-compatible broker with a pluggable storage layer
that can keep data in PostgreSQL, SQLite or object storage. Clients
authenticate with SASL/SCRAM-SHA-512 or SASL/OAUTHBEARER, and access is
controlled with ACLs.

{: .warning }
Tansu is experimental. You can select it when you create a cluster, but
Streamtime can't provision Tansu clusters yet, so a new cluster never becomes
**Healthy**. Use another Kafka provider for now, such as
[Apache Kafka]({{ site.baseurl }}/workloads/streaming/apache-kafka/).

## When it becomes available

Tansu clusters will be managed like other
[streaming workloads]({{ site.baseurl }}/workloads/streaming/): created on a
Kubernetes fleet with Shared or Isolated tenancy, from the UI, API, CLI or an
AI assistant. Tansu has no advanced settings. This page will then describe
each task.
