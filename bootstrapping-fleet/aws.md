---
title: "AWS"
parent: Bootstrapping Your Fleet
nav_order: 1
---

## Video Tutorial: Bootstrapping a Kubernetes Fleet on AWS

<video class="video-js vjs-theme-city" controls preload="auto" width="640" height="264" data-setup='{}'>
    <source src="{{ '/assets/videos/aws-create.webm' | relative_url }}" type="video/webm">
  Your browser does not support the video tag.
</video>

<style>
    video {
        width: 100%;
        height: auto;       
    }
</style>

<link
  href="https://unpkg.com/video.js@7/dist/video-js.min.css"
  rel="stylesheet"
/>
<link
  href="https://unpkg.com/@videojs/themes@1/dist/city/index.css"
  rel="stylesheet"
/>

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

---


# API Reference

## Create a Kubernetes Fleet on AWS

```bash
curl -X POST https://<streamtime-api-endpoint>/organizations/<your-org-id>/infrastructure/ \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "narrow-impala",
    "infra_type": "aws",
    "domain": "<your-domain>.com",
    "max_tenants": 3,
    "max_kafka_units": 12,
    "tenancy_mode": "Shared",
    "advanced_config": {
        "vpc_id": "vpc-05ab2abs23359a6e",
        "instance_type": "t3.large",
        "cluster_public": false
    },
    "placement_config": {
        "account": "plf-fleet-manager",
        "region": "us-east-1"
    },
    "organization": "<your-org-id>"
   }' 
```

**Response:**
```json
{
    "id": "78d2d356-3898-4c3c-ac26-e5c9b0b595bf",
    "organization": "acme",
    "domain": "<your-domain>.com",
    "identifier": "narrow-impala",
    "provisioner_name": null,
    "destroyer_name": null,
    "infra_type": "aws",
    "tenancy_mode": "Shared",
    "max_tenants": 3,
    "max_kafka_units": 12,
    "kubeconfig": null,
    "kubeconfig_str": null,
    "metadata": {},
    "prometheus_endpoint": null,
    "opencost_endpoint": null,
    "loki_endpoint": null,
    "loadbalancer_dns": null,
    "placement_config": {
        "account": "plf-fleet-manager",
        "region": "us-east-1"
    },
    "advanced_config": {
        "vpc_id": "vpc-05ab2abs23359a6e",
        "instance_type": "t3.large",
        "cluster_public": false
    },
    "advanced_properties": {},
    "status": "Pending",
    "created_at": "2025-07-17T04:31:32.844883Z",
    "updated_at": "2025-07-17T04:31:32.844911Z",
    "network": null
}
```
