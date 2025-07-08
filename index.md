---
title: Get Started 
nav_order: 1
layout: home

---

# Get Started
Bring Your Own Kubernetes (BYOK) allows you to use your existing Kubernetes clusters with Streamtime. This guide covers the steps to bootstrap a Kubernetes fleet using BYOK.


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
   ![Cluster Step 1](/assets/images/apache-kafka/cluster-step-1.png)

2. **Provider & Tenancy**  
   - Choose provider as BYOK.
   - Select tenancy mode (must match the BYOK fleet's tenancy).
   - Specify the number of Kafka units required.
   ![Cluster Step 2](/assets/images/apache-kafka/cluster-step-2.png)

3. **Fleet Selection**  
   - Select the BYOK Kubernetes fleet you created in the previous steps.
   ![Cluster Step 3](/assets/images/apache-kafka/cluster-step-3.png)

4. **Advanced Configuration**  
   - Choose authentication identity provider, storage options, Apache Kafka version, and enable/disable auto-upgrade as needed.
   ![Cluster Step 4](/assets/images/apache-kafka/cluster-step-4.png)

---


With BYOK, Streamtime empowers you to run Kafka anywhere, with full control and enterprise-grade automation.

