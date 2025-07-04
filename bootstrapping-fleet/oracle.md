---
title: "Oracle"
parent: Bootstrapping Your Fleet
nav_order: 2
---

# Bootstrapping on Oracle (OKE)

Oracle Cloud Infrastructure (OCI) is supported as a bootstrap provider for creating Kubernetes fleets in Streamtime, enabling you to deploy and manage Kafka clusters on Oracle Kubernetes Engine (OKE) with integrated automation.

---

## When to Use Oracle (OKE)

- **Oracle Cloud Preference**: When your workloads or data reside primarily in OCI.
- **OKE Features**: If you want to leverage Oracle’s managed Kubernetes capabilities.
- **Enterprise Integration**: For organizations using Oracle Cloud services and databases.
- **Regional Compliance**: When you need to deploy clusters in specific OCI regions for compliance or latency.

---

## Key Features

- **Managed Kubernetes (OKE)**: Automated provisioning and management of OKE clusters.
- **Flexible Tenancy**: Support for shared, isolated, or dedicated tenancy models.
- **Integrated Security**: Leverage OCI IAM and security features.
- **Scalable Throughput**: Define Kafka units and scale clusters as needed.
- **Placement Options**: Deploy in any supported OCI region.

---

## How to Deploy on Oracle (OKE)


1. **Start Fleet Creation in Streamtime**
   - In the Streamtime UI, click "Create Kubernetes Fleet".
   - Select **Oracle** as your bootstrap provider.

2. **Configure Tenancy & Sizing**
   - Choose tenancy mode (shared, isolated, or dedicated).
   - Set base domain, max tenancy, and max Kafka units.

3. **Placement Configuration**
   - Select the OCI region for your fleet.

4. **Advanced Configuration**
   - Provide VCN ID or create a new one.
   - Set the node shape, optionally specify a KMS Key ID, and set `cluster_public` (default: false).


---
