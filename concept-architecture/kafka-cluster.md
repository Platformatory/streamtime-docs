---
title: Kafka Cluster
nav_order: 3
parent: Concepts & Architecture
---

# Kafka Cluster

A **Kafka Cluster** in Streamtime refers to the type of Kafka cluster you can deploy within your Kubernetes fleet.

## Supported Apache Kafka 

| Cluster | Description | Status/Notes |
| --- | ----------- | --- |
| CFK (Confluent for Kubernetes) | Confluent's distribution of Kafka, optimized for Kubernetes. | - |
| Strimzi | An open-source project that provides a way to run Kafka on Kubernetes. | - |
| WarpStream | A high-performance streaming platform built on Kafka. | - |
| Redpanda (preview) | A modern Kafka alternative designed for high throughput and low latency. | Preview |
| AutoMQ (experimental) | An experimental messaging queue built on Kafka. | experimental  |

Each Cluster represents a different Kafka distribution or implementation, allowing you to choose the best fit for your use case, performance, and licensing needs.

---
