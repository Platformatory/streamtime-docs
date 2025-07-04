---
title: "GCP (Preview)"
parent: Bootstrapping Your Fleet
nav_order: 3
---

# Bootstrapping on GCP (Preview)

Google Cloud Platform (GCP) is supported as a bootstrap provider for creating Kubernetes fleets in Streamtime. This enables you to deploy and manage Kafka clusters on Google Kubernetes Engine (GKE) with integrated automation.

---

## When to Use GCP

- **Google Cloud Preference**: When your workloads or data reside primarily in GCP.
- **GKE Features**: If you want to leverage GKE’s managed Kubernetes capabilities.
- **Multi-Cloud Strategy**: For organizations adopting a multi-cloud or hybrid cloud approach.
- **Regional Compliance**: When you need to deploy clusters in specific GCP regions for compliance or latency.

---

## Key Features

- **Managed Kubernetes (GKE)**: Automated provisioning and management of GKE clusters.
- **Flexible Tenancy**: Support for shared, isolated, or dedicated tenancy models.
- **Integrated Security**: Leverage GCP IAM and security features.
- **Scalable Throughput**: Define Kafka units and scale clusters as needed.
- **Placement Options**: Deploy in any supported GCP region.

---

## How to Deploy on GCP
Follow these steps to bootstrap a Kubernetes fleet on GCP using Streamtime:

1. **Start Fleet Creation in Streamtime**
   - In the Streamtime UI, click "Create Kubernetes Fleet".
   - Select **GCP** as your bootstrap provider.

2. **Configure Tenancy & Sizing**
   - Choose tenancy mode (`shared`, `isolated`, or `dedicated`).
   - Set base domain, max tenancy, and max Kafka units.

3. **Placement Configuration**
   - Select the GCP region for your fleet.

4. **Advanced Configuration**
   - Upload your service account JSON key.
   - Specify network and node machine type.

5. **Deploy and Validate**
   - Click **Deploy**. Streamtime will provision and configure the GKE fleet.
   - Once deployed, the fleet status will show as "Healthy" and is ready for Kafka cluster deployments.

---

