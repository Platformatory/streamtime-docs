---
title: "Apache Kafka"
parent: Setup Kafka
nav_order: 2
---

## Video Tutorial: Creating an Apache Kafka Cluster on BYOK

<video class="video-js vjs-theme-city" controls preload="auto" width="640" height="264" data-setup='{}'>
    <source src="{{ '/assets/videos/apache-kafka.webm' | relative_url }}" type="video/webm">
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

# Apache Kafka

Apache Kafka is a popular open-source distributed event streaming platform. Streamtime enables you to deploy and manage Apache Kafka clusters on your Kubernetes fleets with full automation and observability.

---

## When to Use Apache Kafka

- **Open Source Requirements**: When you need a fully open-source Kafka distribution without vendor lock-in.
- **Custom Integrations**: If you require advanced customization or integration with existing open-source tools.
- **Benchmarking & Testing**: For proof-of-concept, benchmarking, or development environments.
- **Cost Control**: When you want to avoid commercial licensing costs and manage your own scaling and upgrades.

---

## Steps to Create an Apache Kafka Cluster

1. **Select Cluster Platform**
   - In the Streamtime UI, start by creating a new Kafka cluster.
   - Choose **Apache Kafka** as the cluster platform.
    ![Cluster Type]({{ site.baseurl }}/assets/images/apache-kafka/cluster-step-1.png)

2. **Configure Cluster Basics**
   - Set the cluster name.
   - Select the tenancy mode (shared, isolated, or dedicated).
   - Specify the number of Kafka units required (1 Kafka unit = 20 MBps throughput).
   ![Cluster Basics]({{ site.baseurl }}/assets/images/apache-kafka/cluster-step-2.png)

3. **Select Fleet Placement**
   - Choose the Kubernetes fleet (BYOK or managed cloud) where the cluster will be deployed.
   - Ensure the selected fleet matches your tenancy and sizing requirements.
   ![Fleet Selection]({{ site.baseurl }}/assets/images/apache-kafka/cluster-step-3.png)

4. **Advanced Configuration**
    - Configure authentication (identity provider), storage options, and Apache Kafka version.
    - Enable or disable auto-upgrade based on your operational preferences.
    ![Advanced Configuration]({{ site.baseurl }}/assets/images/apache-kafka/cluster-step-4.png)

---

# API Reference

## Create an Apache Kafka Cluster

```bash
curl -X POST https://<streamtime-api-endpoint>/organizations/<your-org-id>/clusters/ \
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
    "cloud_provider": "aws",
    "region": "us-east-1",
    "infrastructure": "sympathetic-emu"
}'
```

**Response:**
```json
{
    "id": "1a0b72d5-96b9-4123-9cec-71446b6bf45c",
    "organization": "<your-org-id>",
    "infrastructure": "sympathetic-emu",
    "identifier": "dutch-mammal",
    "provisioner_name": "",
    "destroyer_name": null,
    "version_updater_name": null,
    "cluster_type": "strimzi",
    "tenancy_mode": "Shared",
    "kafka_units": 3,
    "cloud_provider": "aws",
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