---
title: "AutoMQ (Experimental)"
parent: Setup Kafka
nav_order: 6
---

# AutoMQ (Experimental)

AutoMQ is a Kafka-compatible, cloud-native messaging platform designed for high scalability and operational simplicity. Streamtime enables you to deploy and manage AutoMQ clusters on your Kubernetes fleets.

---

## When to Use AutoMQ

- **Cloud-Native Messaging**: Ideal for teams seeking a modern, cloud-native Kafka alternative.
- **Auto-Scaling Needs**: When you require seamless, automatic scaling of your messaging workloads.
- **Built-in Observability**: If you want integrated monitoring and operational insights.
- **Internal Tenants**: Currently best suited for internal or experimental environments.

---

## Key Features

- **Kafka API-Compatible**: Works with existing Kafka clients and tools.
- **Auto-Scaling**: Automatically adjusts resources based on workload.
- **Cloud-Native Architecture**: Designed for Kubernetes and containerized deployments.
- **Built-in Observability**: Integrated hooks for monitoring and metrics.
- **Operational Simplicity**: Minimal manual intervention required.

---

## How to Deploy AutoMQ on Streamtime

1. **Select Cluster Platform**
   - In the Streamtime UI, create a new Kafka cluster.
   - Choose **AutoMQ** as the cluster platform.

2. **Configure Cluster Basics**
   - Set the cluster name, tenancy mode, and number of Kafka units.
   - Select the Kubernetes fleet for deployment.

3. **Advanced Configuration**
   - Configure authentication, storage, and other advanced settings as needed.

4. **Review and Deploy**
   - Review your configuration and click **Deploy** to provision the AutoMQ cluster.

---

Once deployed, you can monitor and manage your AutoMQ cluster directly from the Streamtime dashboard.