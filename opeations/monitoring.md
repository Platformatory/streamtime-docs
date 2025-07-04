---
title: Monitoring
nav_order: 2
parent: Operations
---

# Monitoring

Streamtime provides comprehensive monitoring for both Kubernetes infrastructure and Kafka clusters. All metrics are visualized through integrated dashboards for real-time observability and troubleshooting.

---

## Kubernetes Monitoring

- **Cluster Health**: Overall status of the Kubernetes fleet.
- **Node Metrics**: CPU, memory, and storage utilization for each node.
- **Metrics Dashboards**: Visualize resource usage and identify bottlenecks.

![Node Overview]({{site.baseurl}}/assets/images/monitoring/node-overview.png)
---

## Kafka Monitoring

- **Cluster Health**: Status and availability of Kafka clusters.
- **Kafka Operations Metrics**: Production and consumption rates, partition distribution, and replication status.
- **Metrics Dashboards**: Topic-level throughput, latency, and error rates.

### Platform-Specific Metrics

- **CFK (Confluent for Kubernetes)**
  - Topic-wise metrics
  - Schema Registry metrics
  - Confluent platform logs

- **Strimzi**
  - KRaft (Kafka Raft) metrics

![cluster health]({{site.baseurl}}/assets/images/monitoring/cluster-health.png)

---

Use the Streamtime UI dashboards to monitor all aspects of your clusters and quickly respond to any issues.