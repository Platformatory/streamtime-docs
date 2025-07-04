---
title: Introduction 
nav_order: 1
layout: home

---

# Streamtime BYOK (Bring Your Own Kubernetes) for Apache Kafka

This guide explains how Streamtime's BYOK (Bring Your Own Kubernetes) approach works for deploying and managing Apache Kafka clusters using Strimzi.

---

## What is BYOK?
BYOK (Bring Your Own Kubernetes) allows you to leverage your existing Kubernetes infrastructure to run Apache Kafka clusters managed by Streamtime. Instead of relying on Streamtime's managed cloud services, you can deploy Kafka directly on your own Kubernetes clusters, whether they are on-premises or in the cloud.
This approach provides you with full control over your environment while still benefiting from Streamtime's automation and management capabilities.

## Key Features
- **Self-Hosted Kafka**: Deploy and manage Kafka clusters on your own Kubernetes infrastructure.
- **Full Control**: You retain ownership of your Kafka environment, networking, and security policies.
- **Flexible Deployment**: Use your existing Kubernetes clusters, whether on-premises, in the cloud, or in a hybrid setup.
- **Enterprise-Grade Automation**: Streamtime automates Kafka operations, including scaling, monitoring, and maintenance, while you control the underlying infrastructure. 
- **Seamless Integration**: Easily integrate Kafka into your existing IT and security landscape without relying on external cloud providers.
- **Multi-Tenancy Support**: Deploy multiple Kafka clusters within a single Kubernetes cluster, allowing for efficient resource utilization and isolation between different teams or environments.

## streamtime responsibilities
- **Cluster Management**: Streamtime handles the deployment, scaling, and management of Kafka clusters on your Kubernetes infrastructure.
- **Monitoring & Alerts**: Streamtime provides monitoring and alerting capabilities for your Kafka clusters, ensuring you are notified of any issues or performance bottlenecks.
- **Updates & Upgrades**: Streamtime manages updates and upgrades to the Kafka software, ensuring you are always running a supported and secure version.
- **Support**: Streamtime offers support for troubleshooting and resolving issues related to your Kafka clusters, leveraging its expertise in Kafka and Kubernetes.  

{: .note }
> Streamtime does not manage the underlying Kubernetes infrastructure, networking, or security policies. You are responsible for maintaining and securing your Kubernetes clusters, including configuring access controls, network policies, and storage options.

---
## How to Get Started with BYOK

### Creating a BYOK Kubernetes Fleet

Creating a BYOK fleet in Streamtime is a guided 4-step process:

1. **Choose Bootstrap Provider**  
   - Click "Create Kubernetes Fleet" in the Streamtime UI.
   - Select your bootstrap provider. For BYOK, click the "BYOK" option (other options: AWS, GCP, OCI, Azure).
    ![BYOK Step 1](/assets/images/byok/step-1.png)

2. **Configure Tenancy & Sizing**  
   - Select tenancy mode (shared, isolated, or dedicated).
   - Set your base domain, max tenancy (maximum number of Kafka clusters allowed), and max Kafka units (total throughput capacity).
   - Specify the number of Kafka units you want to allocate for this fleet.
    ![BYOK Step 2](/assets/images/byok/step-2.png)

3. **Placement Configuration (Optional)**  
   - Optionally, specify provider and region details for placement metadata.
   ![BYOK Step 3](/assets/images/byok/step-3.png)

4. **Advanced Configuration**  
   - Upload your Kubernetes `kubeconfig` file.
   - Click deploy. Once the fleet is created, you will see the status as "Healthy".
   ![BYOK Step 4](/assets/images/byok/step-4.png)

---

### Creating an Apache Kafka Cluster on BYOK

Kafka cluster creation is also a 4-step guided process:

1. **Choose Cluster Type**  
   - Select the cluster type (CFK, Apache Kafka, WarpStream, Redpanda).
   - For BYOK, select "Apache Kafka".
   ![Cluster Step 1](/assets/images/byok/cluster-step-1.png)

2. **Provider & Tenancy**  
   - Choose provider as BYOK.
   - Select tenancy mode (must match the BYOK fleet's tenancy).
   - Specify the number of Kafka units required.
   ![Cluster Step 2](/assets/images/byok/cluster-step-2.png)

3. **Fleet Selection**  
   - Select the BYOK Kubernetes fleet you created in the previous steps.
   ![Cluster Step 3](/assets/images/byok/cluster-step-3.png)

4. **Advanced Configuration**  
   - Choose authentication identity provider, storage options, Apache Kafka version, and enable/disable auto-upgrade as needed.
   ![Cluster Step 4](/assets/images/byok/cluster-step-4.png)

---


With BYOK, Streamtime empowers you to run Kafka anywhere, with full control and enterprise-grade automation.

