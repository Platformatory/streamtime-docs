---
title: "Azure (Experimental)"
parent: Bootstrapping Your Fleet
nav_order: 4
---

# Bootstrapping on Azure (Experimental)

Azure is supported as a bootstrap provider for creating Kubernetes fleets in Streamtime, enabling you to deploy and manage Kafka clusters on Azure Kubernetes Service (AKS) with integrated automation.

---

## When to Use Azure

- **Microsoft Cloud Preference**: When your workloads or data reside primarily in Azure.
- **AKS Features**: If you want to leverage Azure’s managed Kubernetes capabilities.
- **Enterprise Integration**: For organizations using Azure Active Directory and other Microsoft services.
- **Regional Compliance**: When you need to deploy clusters in specific Azure regions for compliance or latency.

---

## Key Features

- **Managed Kubernetes (AKS)**: Automated provisioning and management of AKS clusters.
- **Flexible Tenancy**: Support for shared, isolated, or dedicated tenancy models.
- **Integrated Security**: Leverage Azure AD and security features.
- **Scalable Throughput**: Define Kafka units and scale clusters as needed.
- **Placement Options**: Deploy in any supported Azure region.

---

## How to Deploy on Azure
Follow these steps to bootstrap a Kubernetes fleet on Azure using Streamtime:

1. **Start Fleet Creation in Streamtime**
   - In the Streamtime UI, click "Create Kubernetes Fleet".
   - Select **Azure** as your bootstrap provider.

2. **Configure Tenancy & Sizing**
   - Choose tenancy mode (shared, isolated, or dedicated).
   - Set base domain, max tenancy, and max Kafka units.

3. **Placement Configuration**
   - Select the Azure region for your fleet.

4. **Advanced Configuration**
   - Enter resource group, vnet name, subnet name, Kubernetes version, network plugin, agent VM size, and node count.


---
