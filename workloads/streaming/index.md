---
title: Streaming
nav_order: 1
parent: Workloads
permalink: /workloads/streaming/
has_children: true
---

# Streaming

Kafka-compatible message brokers that applications produce to and
consume from. One cluster per platform choice; they are interchangeable
from your applications' point of view (Kafka protocol), and differ in
where the data is stored and who operates the platform:

| Platform | Page | In short |
|---|---|---|
| **Apache Kafka** | [Apache Kafka](/workloads/streaming/apache-kafka/) | Fully open-source Kafka (Strimzi); your scaling and upgrades |
| **Confluent for Kafka** | [Confluent (CFK)](/workloads/streaming/confluent/) | Confluent Platform operated by its own Kubernetes operator |
| **WarpStream** | [WarpStream](/workloads/streaming/warpstream/) | Kafka protocol on cloud object storage — near-zero storage cost |
| **Redpanda** | [Redpanda (Preview)](/workloads/streaming/redpanda/) | Single-binary Kafka-compatible broker |
| **AutoMQ** | [AutoMQ (Experimental)](/workloads/streaming/automq/) | Kafka on block + object storage tiering |
| **Confluent Platform on VMs** | [Confluent Platform (VMs)](/workloads/streaming/confluent-platform-vms/) | Confluent Platform on virtual machines you own, no Kubernetes |
| **LeafCuttr** | [LeafCuttr (Experimental)](/workloads/streaming/leafcuttr/) | Kafka-compatible broker with MQTT and HTTP interfaces, for edge and IoT; not provisioned yet |
| **Tansu** | [Tansu (Experimental)](/workloads/streaming/tansu/) | Kafka-compatible broker storing data in PostgreSQL, SQLite or object storage; not provisioned yet |

Around your Kafka clusters:

| Service | Page | In short |
|---|---|---|
| **Kafka Connect** | [Kafka Connect](/workloads/streaming/kafka-connect/) | Connectors that move data between Kafka and other systems |
| **Kafka Replicator** | [Kafka Replicator](/workloads/streaming/kafka-replicator/) | Copies topics between Kafka clusters (MirrorMaker 2 or Cluster Link) |
| **Virtual Kafka Clusters** | [Virtual Kafka Clusters](/workloads/streaming/virtual-kafka-clusters/) | A team's own Kafka endpoint and capacity on a shared cluster |
