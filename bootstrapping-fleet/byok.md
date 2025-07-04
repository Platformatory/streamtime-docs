---
title: "Advanced Usage (BYOK)"
parent: Bootstrapping Your Fleet
nav_order: 5
---

# Bootstrapping a Kubernetes Fleet with BYOK    
Bring Your Own Kubernetes (BYOK) allows you to use your existing Kubernetes clusters with Streamtime. This guide covers the steps to bootstrap a Kubernetes fleet using BYOK.

## When to use BYOK
BYOK is ideal when you have existing Kubernetes clusters that you want to integrate with Streamtime for Kafka management. It allows you to leverage your current infrastructure while benefiting from Streamtime's Kafka management capabilities.


## How to Bootstrap a Kubernetes Fleet with BYOK
Follow these steps to bootstrap a Kubernetes fleet using BYOK in Streamtime:
1. **Select BYOK as Bootstrap Provider**
    - In the Streamtime UI, click "Create Kubernetes Fleet".    
    - Choose **BYOK** as your bootstrap provider.
    ![Bootstrap Provider Selection]({{ site.baseurl }}/assets/images/byok/step-1.png)

2. **Configure Tenancy & Sizing**
    - Select the tenancy model: `shared`, `isolated`, or `dedicated`.
    - Define your base domain, set the maximum tenancy (number of Kafka clusters per fleet), and specify the maximum Kafka units (throughput capacity).
    - Choose the appropriate node size based on your workload (e.g., 1 Kafka unit = 20 MBps, recommended node: 4 vCPU / 16 GB RAM).
    ![Tenancy & Sizing Configuration]({{ site.baseurl }}/assets/images/byok/step-2.png)
3. **Placement Configuration**
    - Optionally, specify provider and region details for placement metadata to optimize for latency, compliance, or cost.
    - This step is optional but recommended for better performance and compliance.  
    ![Placement Configuration]({{ site.baseurl }}/assets/images/byok/step-3.png)
4. **Upload Your Kubernetes Configuration**
    - Upload your Kubernetes `kubeconfig` file. This file contains the necessary credentials and configuration to connect to your existing Kubernetes clusters.
    ![Upload Kubeconfig]({{ site.baseurl }}/assets/images/byok/step-4.png)
5. **Deploy and Validate**
    - Click **Deploy**. Streamtime will validate your kubeconfig and configure the Kubernetes fleet.
    - Once deployed, the fleet status will show as "Healthy" and is ready for Kafka
    ![byok detail view]({{ site.baseurl }}/assets/images/byok/detail-view.png)