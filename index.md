---
title: Get Started 
nav_order: 1
layout: home

---

## Quick start

To get started with StreamTime, docker compose is the recommended way for single user and trial deployments. For production workloads, we recommend deploying StreamTime on Kubernetes using the helm chart.

To get started, run

```bash
STREAMTIME_SUPER_USER_EMAILS=<your-email> docker compose -f oci://ghcr.io/platformatory/streamtime up -d
```

> Replace <your-email> with you email.

Once the containers are up, visit http://localhost:3000 and enter `root` as the organization. The `root` organization is a special organization that can be used to create other organizations and the super user has complete administrator privileges for all organizations.

## Video Tutorial: BYOK with Apache Kafka Cluster

<video class="video-js vjs-theme-city" controls preload="auto" width="640" height="264" data-setup='{}'>
    <source src="{{ '/assets/videos/byok_apache-kafka.webm' | relative_url }}" type="video/webm">
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

<script src="https://vjs.zencdn.net/8.22.0/video.min.js"></script>

---

# Get Started

The fastest way to deploying a streamtime private cloud is by bringing your own Kubernetes cluster, also known as BYOK. This guide covers the steps to bootstrap a Kubernetes fleet using BYOK.

### Pre-requisitres

1. Any CNCF Kubernetes. We recommend the latest: 1.3.x
2. You must provide a kubeconfig with a static, long-lived token
3. Network connectivity between streamtime network and the k8s API endpoint. If private networking is required, you must ensure routability. We recommend atleast 128 available IP addresses (based on the number of clusters you intend to host)
4. CSI with default storage class set
5. A load balancer controller. 
6. Node sizing based on our guidelines, based on # of max tenants



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



# API Reference

Streamtime provides a comprehensive REST API for programmatically managing fleets and Kafka clusters. Below are examples for the most common CREATE operations.


### Authentication

All API requests require authentication using a Bearer token:

```bash
curl -H "Authorization: Bearer YOUR_API_TOKEN" \
     -H "Content-Type: application/json" \
     https://<streamtime-api-endpoint>/organizations/<your-org-id>/...
```


#### BYOK Fleet

```bash
curl -X POST https://<streamtime-api-endpoint>/organizations/<your-org-id>/infrastructure/ \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "additional-alpaca",
    "infra_type": "byok",
    "domain": "<your-domain>.com",
    "max_tenants": 4,
    "max_kafka_units": 17,
    "tenancy_mode": "Shared",
    "advanced_config": {
        "kubeconfig": "<your-kubeconfig-string>"
    },
    "placement_config": {},
    "organization": "acme"
}'
```

**Response:**
```json
   {
    "id": "bfca99b0-35a5-4490-9cc4-40296910f76d",
    "organization": "acme",
    "domain": "<your-domain>.com",
    "identifier": "additional-alpaca",
    "provisioner_name": null,
    "destroyer_name": null,
    "infra_type": "byok",
    "tenancy_mode": "Shared",
    "max_tenants": 4,
    "max_kafka_units": 17,
    "kubeconfig": null,
    "kubeconfig_str": null,
    "metadata": {},
    "prometheus_endpoint": null,
    "opencost_endpoint": null,
    "loki_endpoint": null,
    "loadbalancer_dns": null,
    "placement_config": {},
    "advanced_config": {
        "kubeconfig": "<your-kubeconfig-string>"
    },
    "advanced_properties": {},
    "status": "Pending",
    "created_at": "2025-07-17T04:37:33.316063Z",
    "updated_at": "2025-07-17T04:37:33.316090Z",
    "network": null
}
```   


### 2. Create Kafka Cluster

#### Apache Kafka Cluster

```bash
curl -X POST https://<streamtime-api-endpoint>/v1/clusters \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "dutch-mammal",
    "cluster_type": "strimzi",
    "kafka_units": 3,
    "provisioner_name": "",
    "tenancy_mode": "Shared",
    "advanced_config": {
        "number_of_zones": "1",
        "cluster_access": "Internal & External",
        "private_access": false,
        "version": "3.8.0",
        "oauth": "okta-dev-47119201",
        "tiered_storage_bucket_name": "apache-kafka-32421",
        "tiered_storage_provider": {
            "aws_account": "platformatory",
            "aws_region": "us-east-1"
        },
        "tiered_storage_create_bucket": true
    },
    "tags": [
        {
            "key": "environment",
            "value": "non-prod"
        }
    ],
    "organization": "<your-org-id>",
    "cloud_provider": "byok",
    "region": "us-east-1",
    "infrastructure": "additional-alpaca"
}'
```

**Response:**
```json
{
    "id": "1a0b72d5-96b9-4123-9cec-71446b6bf45c",
    "organization": "<your-org-id>",
    "infrastructure": "additional-alpaca",
    "identifier": "dutch-mammal",
    "provisioner_name": "",
    "destroyer_name": null,
    "version_updater_name": null,
    "cluster_type": "strimzi",
    "tenancy_mode": "Shared",
    "kafka_units": 3,
    "cloud_provider": "byok",
    "region": "us-east-1",
    "tags": [
        {
            "key": "environment",
            "value": "non-prod"
        }
    ],
    "advanced_config": {
        "number_of_zones": "1",
        "cluster_access": "Internal & External",
        "private_access": false,
        "version": "3.8.0",
        "oauth": "okta-dev-47119201",
        "tiered_storage_bucket_name": "apache-kafka-32421",
        "tiered_storage_provider": {
            "aws_account": "platformatory",
            "aws_region": "us-east-1"
        },
        "tiered_storage_create_bucket": true
    },
    "console_url": null,
    "client_properties": null,
    "new_version": null,
    "s3_manifests_file_path": null,
    "status": "Pending",
    "created_at": "2025-07-17T09:49:48.972570Z",
    "updated_at": "2025-07-17T09:49:48.972586Z"
}
```


