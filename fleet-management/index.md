---
title: Fleet Management
nav_order: 4
has_children: true
layout: home
permalink: /fleet-management/
---

# Fleet Management

Creating a Kubernetes fleet in Streamtime is the foundational step for deploying and managing Kafka clusters. A **Kubernetes fleet** is a managed group of Kubernetes clusters provisioned on your chosen cloud provider (AWS, GCP, OCI, Azure) or using BYOK (Bring Your Own Kubernetes).
![Kubernetes Fleet Creation]({{ site.baseurl }}/assets/images/aws/fleet-bootstrap-provider.png)

## Overview

1. **Select Bootstrap Provider**  
   - Start by clicking "Create Kubernetes Fleet" in the Streamtime UI.
   - Choose your bootstrap provider: AWS, GCP, OCI, Azure, DigitalOcean, Civo, BYOK (your own Kubernetes cluster) or BYOVM (your own virtual machines).

2. **Configure Tenancy & Sizing**  
   - Select the tenancy model: `shared`, `isolated`, or `dedicated`.
   - Define your base domain, set the maximum tenancy (number of Kafka clusters per fleet), and specify the maximum Kafka units (throughput capacity).
   - Choose the appropriate node size based on your workload (e.g., 1 Kafka unit = 20 MBps, recommended node: 4 vCPU / 16 GB RAM).
   - Optionally, choose the fleet's alert channels. See [Alert Channels](#alert-channels).

3. **Placement Configuration**
   - Cloud Provider: Select the cloud provider for your Kubernetes clusters (e.g., AWS, GCP).
   - Region: Choose the region where you want to deploy your Kubernetes fleet.
 
   {: .note }
   > For BYOK fleets, you can optionally specify provider and region details for placement metadata to optimize for latency, compliance, or cost.

4. **Advanced Configuration**
   - **AWS**: use an existing VPC or create one, and choose its address range and availability zones. See [AWS](aws.html#fleet-settings).
   - **GCP**: use an existing VPC network or create one, and optionally a Cloud KMS key. See [GCP](gcp.html#fleet-settings).
   - **OCI**: use an existing VCN or create one, choose the node shape and logs bucket, and optionally a KMS key. See [Oracle](oracle.html#fleet-settings).
   - **Azure**: use an existing VNet or create one, and choose the node size and availability zones. See [Azure](azure.html#fleet-settings).
   - **DigitalOcean**: use an existing VPC or create one, and optionally a high-availability control plane. See [DigitalOcean](digitalocean.html#fleet-settings).
   - **Civo**: use an existing network or create one, and optionally pin the Kubernetes version. See [Civo](civo.html#fleet-settings).
   - **BYOK**: set namespaces, labels and scheduling rules, then install the Agent on your cluster. See [Connect the cluster](byok.html#connect-the-cluster).
   - **BYOVM**: upload the SSH key and list the machines for the topology you chose. See [Bring your own VMs](byovm.html#fleet-settings).

5. **Deploy and Validate**  
   - Click deploy. Streamtime will provision and configure the Kubernetes fleet.
   - Once deployed, the fleet status will show as "Healthy" and is ready for Kafka cluster deployments.

   ![Kubernetes Fleet List]({{ site.baseurl }}/assets/images/aws/fleet-list.png)

## Alert Channels

Alert channels decide where Streamtime sends alerts. They are set on the fleet, and cover the fleet itself and every Kafka cluster and other workload it hosts. Kafka clusters and other workloads have no alert channels of their own.

- **Create channels first.** Add Slack, PagerDuty or webhook channels under **Settings → Alert Channels**.
- **Choose them for the fleet.** When you create the fleet, select one or more channels in the **Alert Channels** field. The field is optional.
- **What gets sent.** The fleet's own alerts, and the default alerts of each workload on the fleet (for example, WarpStream's Agent Down or Consumer Group Lag Too High).
