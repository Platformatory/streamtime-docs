---
title: Fleet Provider
nav_order: 1
parent: Concepts & Architecture
---

# Fleet Providers

Streamtime supports deploying and managing Kubernetes fleets across multiple cloud providers. These are known as **Fleet Providers**.

## Supported Fleet Providers

| Provider | Description | Status/Notes |
| --- | --- | --- |
| AWS | Amazon Web Services, a widely used cloud platform. | - |
| GCP | Google Cloud Platform, known for its data analytics and machine learning capabilities. | Preview |
| OCI | Oracle Cloud Infrastructure, focused on enterprise applications and databases. | - |
| Azure | Microsoft Azure, a comprehensive cloud platform with strong enterprise integration. | Experimental |

Each fleet provider allows you to bootstrap and operate Kubernetes clusters, which serve as the foundation for running Kafka clusters and other workloads.

---

## Choosing a Fleet Provider

When creating a new fleet, select the cloud provider that best fits your requirements for region, compliance, and cost. Streamtime automates the provisioning and management of Kubernetes clusters on your chosen provider.

---