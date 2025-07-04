---
title: "AWS"
parent: Bootstrapping Your Fleet
nav_order: 1
---

# Bootstrapping a Kubernetes Fleet on AWS

Follow these four steps to create and configure a Kubernetes fleet on AWS using Streamtime.

---

## Key Features

- **Automated Cluster Management**: Streamtime provisions and manages Kubernetes clusters on AWS.
- **Flexible Tenancy Models**: Choose between shared, isolated, or dedicated tenancy for your Kafka clusters.
- **Scalable Throughput**: Define your Kafka units based on workload requirements (1 Kafka unit = 20 MBps).
- **Region and Placement Options**: Deploy in your preferred AWS region with optional placement metadata for compliance or latency optimization.
- **Advanced Configuration**: Customize VPC, instance types, and other AWS-specific settings to fit your infrastructure needs.


## 1. Select AWS as Bootstrap Provider

- In the Streamtime UI, click "Create Kubernetes Fleet".
- Choose **AWS** as your bootstrap provider.

![AWS Bootstrap Provider]({{ site.baseurl }}/assets/images/aws/fleet-bootstrap-provider.png)

---

## 2. Configure Tenancy & Sizing

- Select the tenancy model: `shared`, `isolated`, or `dedicated`.
- Set your base domain, maximum tenancy (number of Kafka clusters per fleet), and maximum Kafka units (throughput capacity).
- Choose the appropriate node size for your workload (e.g., 1 Kafka unit = 20 MBps, recommended node: 4 vCPU / 16 GB RAM).

![AWS Tenancy & Sizing]({{ site.baseurl }}/assets/images/aws/fleet-basic-config.png)

---

## 3. Placement Configuration

- Select the AWS region where you want to deploy your Kubernetes fleet.
- Optionally, specify placement metadata for compliance or latency optimization.

![AWS Placement]({{ site.baseurl }}/assets/images/aws/fleet-placement-config.png)

---

## 4. Advanced Configuration

- Select an existing VPC ID or create a new VPC.
- Choose the instance type for your nodes.
- Configure any additional AWS-specific settings as needed.

![AWS Advanced Config]({{ site.baseurl }}/assets/images/aws/fleet-advanced.png)

---

## Deploy and Validate

- Click **Deploy**. Streamtime will provision and configure the Kubernetes fleet on AWS.
- Once deployed, the fleet status will show as "Healthy" and is ready for Kafka cluster deployments.

![Kubernetes Fleet List]({{ site.baseurl }}/assets/images/aws/fleet-list.png)