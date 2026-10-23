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
