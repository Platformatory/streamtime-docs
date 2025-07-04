---
title: "Redpanda (Preview)"
parent: Setup Kafka
nav_order: 5
---

# Redpanda (Preview)

Redpanda is a modern, high-performance streaming platform that is Kafka API-compatible but does not require the JVM. Streamtime enables you to deploy and manage Redpanda clusters on your Kubernetes fleets.

---

## When to Use Redpanda

- **Low-Latency Workloads**: Ideal for applications that require ultra-fast message processing.
- **JVM-Free Environments**: When you want to avoid Java dependencies and reduce resource overhead.
- **Kafka Compatibility**: If you need Kafka API compatibility but want a simpler operational model.
- **Cloud-Native Deployments**: Optimized for Kubernetes and containerized environments.

---

## Key Features

- **Kafka API-Compatible**: Works with existing Kafka clients and tools.
- **No JVM Required**: Written in C++, offering lower latency and reduced resource usage.
- **High Throughput**: Designed for performance-critical streaming workloads.
- **Simplified Operations**: Easier upgrades and scaling compared to traditional Kafka.
- **Cloud-Native**: Built for Kubernetes with native support for container orchestration.

---

## How to Deploy Redpanda on Streamtime

1. **Select Cluster Platform**
   - In the Streamtime UI, create a new Kafka cluster.
   - Choose **Redpanda** as the cluster platform.

2. **Configure Cluster Basics**
   - Set the cluster name, tenancy mode, and number of Kafka units.
   - Select the Kubernetes fleet for deployment.

3. **Advanced Configuration**
   - Configure authentication, storage, Redpanda version, and other advanced settings as needed.

4. **Review and Deploy**
   - Review your configuration and click **Deploy** to provision the Redpanda cluster.

---

Once deployed, you can monitor and manage your Redpanda cluster directly from the Streamtime dashboard.