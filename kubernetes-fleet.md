---
title: Kubernetes Fleet
nav_order: 2
layout: home
---


# Kubernetes Fleet

The fleet overview page displays a list of all Kubernetes Fleets.

-  Top-right: **Create Fleet** button
-  Search input
-  Delete action per row

![Fleet List](assets/images/fleet-list.png)

---

##  Creating a Kubernetes Fleet

Fleet creation is a 4-step form:

### Step 1: Bootstrap Provider

Choose from:

- Bring Your Own Kubernetes
- AWS EKS
- GCP GKE
- OCI OKE
- Azure AKS

![Bootstrap Provider](assets/images/fleet-bootstrap-provider.png)

---

### Step 2: Basic Configuration

- Tenancy Mode: `shard`, `dedicated`, `isolated`
- DNS Selection
- Max Tenants
- Max Kafka Units (1 unit = 20MBps throughput)
- Identifier (slug)

![Basic Configuration](assets/images/fleet-basic-config.png)

---

### Step 3: Placement Configuration

- Select Cloud Account (depends on provider)
- Choose Region

![Placement Config](assets/images/fleet-placement-config.png)

---

### Step 4: Advanced Configurations

- VPC ID
- Instance Type

![Advanced Config](assets/images/fleet-advanced.png)

---

##  Fleet Detail View

- General Info:
  - Identifier, Provider, Tenancy, Status
- Performance Charts:
  - CPU, Memory, Storage
- Cluster List (linked to fleet)
- Actions:
  - Execution Logs
  - Kubeconfig
- Dashboards:
  - Cluster Health
  - Node Metrics
  - Kafka Operator Metrics

![Fleet Details](assets/images/fleet-detail.png)
