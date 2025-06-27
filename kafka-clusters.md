---
title: Clusters
nav_order: 3
layout: home
---

# Kafka Clusters

The cluster list shows:

- Table view of clusters
-  **Create Cluster** button (top right)
-  Search input

![Cluster List](assets/images/cluster-list.png)

---

##  Creating a Kafka Cluster

Cluster creation follows 4 steps:

### Step 1: Cluster Type

Choose type:

- Confluent for Kubernetes Standard
- Apache Kafka
- Warpstream Standard
- Redpanda Standard
- Automq

![Cluster Type](assets/images/cluster-type.png)  

---

### Step 2: Basic Configuration

- Identifier Name
- Tags
- Cloud Provider (AWS, OCI, GCP, Azure, BYOK)
- Regions
- Tenancy Mode
- Kafka Units

![Cluster Basic configuration](assets/images/cluster-basic-config.png)  

---

### Step 3: Fleet Selection

- Select Kubernetes Fleet (filtered by Basic Config)

![Cluster Fleet Selection](assets/images/cluster-fleet-selection.png)  

---

### Step 4: Advanced Configurations

- Number of Zones
- Cluster Access: `internal`, `external`
- Kafka Version
- Enable Auto-Upgrades
- Auth Provider & Group
- Tiered Storage:
  - Bucket Name
  - Object Storage Account

![Cluster Advanced Configurations](assets/images/cluster-advanced-config.png)  

---

##  Cluster Detail View

Includes:

- **Cluster Info**: Identifier, SKU, Version, Status
- **Fleet Info**: Identifier, Fleet Provider, Status
- **Performance Charts**:
  - Production
  - Consumption
  - Partitions
- **Dashboards**:
  - Cluster Health
  - Kafka Metrics
  - Topic-wise Metrics
- **Actions**:
  - Health Agents
  - Benchstress
  - Execution Logs
  - Health & Benchmark Reports
- **Billing**: Cost charts
- **Endpoints**:
  - Prometheus URL
  - Bootstrap Servers
  - Loki URL

![Cluster Details](assets/images/cluster-detail.png)  
