---
title: Scaling
nav_order: 5
parent: Concepts & Architecture
---


# Scaling Kafka Clusters in Streamtime

Streamtime enables flexible scaling of Kafka clusters within Kubernetes fleets, based on your workload requirements and tenancy configuration.

## Kafka Cluster Scaling in Kubernetes

Each Kubernetes cluster can host multiple Kafka clusters, depending on the **max_tenancy** setting.  
- **max_tenancy** defines the maximum number of Kafka clusters that can be deployed on a single Kubernetes cluster.
- For example, if `max_tenancy` is set to 3, you can deploy up to 3 Kafka clusters on that Kubernetes cluster.

## Kafka Units

- Kafka clusters are sized by **Kafka Units**.
- **1 Kafka Unit = 20 MBps** throughput.
- When creating a Kafka cluster, specify the number of units required for your workload.
- You can scale up or down by adjusting the number of Kafka Units.

## Example

If your Kubernetes cluster has `max_tenancy` set to 3 and you need to run three separate Kafka clusters (for different teams or environments), you can deploy all three on the same Kubernetes cluster.  
Each Kafka cluster can be individually sized and scaled according to its throughput needs.

---