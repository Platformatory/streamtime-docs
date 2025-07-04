---
title: "Warpstream"
parent: Setup Kafka
nav_order: 4
---

# Warpstream

Warpstream is a cost-optimized Kafka-compatible platform that leverages S3 object storage for durability and scalability. Streamtime enables you to deploy and manage Warpstream clusters on your Kubernetes fleets.

---

## When to Use Warpstream

- **Cost Optimization**: Ideal for workloads where storage cost is a primary concern.
- **Large-Scale Data**: Suitable for use cases requiring scalable, durable storage for Kafka topics.
- **Cloud-Native Environments**: When you want to leverage cloud object storage (like S3) for Kafka data.
- **Remote Log Storage**: If you need to decouple compute and storage for Kafka clusters.

---

## Key Features

- **S3 Object Storage Integration**: Uses S3-compatible storage for Kafka log data.
- **Performance Tiers**: Select different performance tiers based on workload needs.
- **Cost Efficiency**: Reduces storage costs by offloading data to object storage.
- **Kafka API-Compatible**: Works with existing Kafka clients and tools.
- **Scalable & Durable**: Designed for high durability and easy scaling.

---

## How to Deploy Warpstream on Streamtime

1. **Select Cluster Platform**
   - In the Streamtime UI, create a new Kafka cluster.
   - Choose **Warpstream** as the cluster platform.

2. **Configure Cluster Basics**
   - Set the cluster name, tenancy mode, and number of Kafka units.
   - Select the Kubernetes fleet for deployment.

3. **Configure Object Storage**
   - Enter your object storage account name and bucket name.
   - Choose the desired performance tier.

4. **Advanced Configuration**
   - Configure authentication, storage options, and other advanced settings as needed.

5. **Review and Deploy**
   - Review your configuration and click **Deploy** to provision the Warpstream cluster.

---

Once deployed, you can monitor and manage your Warpstream cluster directly from the Streamtime dashboard.