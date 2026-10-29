---
title: "Bootstrap: Azure"
parent: Fleet Management
nav_order: 4
---

# Fleets on Azure (Experimental)

Streamtime creates and runs a Kubernetes cluster (Azure Kubernetes Service,
AKS) in your Azure subscription, then installs what the fleet's workloads
need. You register the account once, then create fleets on it.

{: .warning }
Azure fleets are experimental.

## Key Features

- **Managed Kubernetes**: Streamtime creates, monitors and deletes the AKS cluster for you.
- **Your network or a new one**: use an existing VNet, or let Streamtime create one.
- **Your encryption key**: optionally encrypt node disks with your own disk encryption set.
- **Tenancy**: Shared, Isolated or Dedicated. See [Tenancy]({{ site.baseurl }}/about/tenancy/#tenancy).
- **Monitoring**: metrics, logs and alerts for the fleet and everything on it.

## Prerequisites

- **A service principal** (an app registration with a client secret) that
  can create AKS clusters, virtual networks, storage accounts and managed
  identities in the subscription and resource group the fleet uses.
- **A resource group** for the fleet.
- **A Base Domain** for the fleet's endpoints, added under **Settings**.

**Cloud account credentials**

- **Subscription ID** and **Tenant ID**: where the fleet is created.
- **Client ID** and **Client Secret**: the service principal's.
- **Defined Tags** (optional): tags, as namespace, key and value, that
  Streamtime adds to the resources it creates.

## Fleet settings

**Placement Configuration**

- **Account**: the cloud account you registered.
- **Region**: `centralindia`, `southindia`, `centralus` or `eastus`.
- **Resource Group Name**: the resource group for the fleet.

**Advanced Configuration**

- **VNet ID**: an existing VNet, or leave it empty to create a new one.
- **Node Size**: `Standard_D4as_v6`, `Standard_D8as_v6` or
  `Standard_D16as_v6`. The UI shows each size's price.
- **Availability Zones**: 1 to 3 (default 1, a single zone).
- **Public Cluster**: whether the Kubernetes API is reachable from the
  internet (on by default).
- **Disk Encryption Set ID**: optional; encrypts node disks with your key.
- **Logs Storage Bucket Name**: the storage account for logs, unique across
  Azure; optional, Streamtime generates one when it's empty.

---

{% capture credentials %}{"subscription_id": "<subscription-id>", "tenant_id": "<tenant-id>", "client_id": "<client-id>", "client_secret": "<client-secret>"}{% endcapture %}
{% capture placement %}{"account": "<cloud-account>", "region": "eastus", "resource_group": "<resource-group>"}{% endcapture %}
{% capture advanced %}{"azure_node_size": "Standard_D4as_v6", "azure_az_count": 1}{% endcapture %}
{% include fleet-tasks.md provider="azure" name="Azure" id="azure" fleet="orders-east" credentials=credentials placement=placement advanced=advanced shots="azure" %}
