---
title: "Confluent (CFK)"
parent: Setup Kafka
nav_order: 3
---

## Video Tutorial: Creating a Confluent for Kubernetes (CFK) Cluster

<video class="video-js vjs-theme-city" controls preload="auto" width="640" height="264" data-setup='{}'>
    <source src="{{ '/assets/videos/cfk-create.webm' | relative_url }}" type="video/webm">
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

# Confluent for Kubernetes (CFK)    
Confluent for Kubernetes (CFK) is a fully managed Kafka distribution optimized for Kubernetes environments. It provides a comprehensive set of features for deploying, managing, and scaling Kafka clusters with ease.
## Key Features
- **Managed Kafka**: Simplifies Kafka operations with automated deployment, scaling, and management.
- **Integration with Confluent Platform**: Seamlessly integrates with Confluent's ecosystem, including Schema Registry, KSQL, and Connect.
- **Kubernetes Native**: Designed specifically for Kubernetes, leveraging its capabilities for resource management and scaling.
- **Monitoring and Management**: Provides built-in monitoring and management tools for Kafka clusters, including metrics and logs.
- **Security**:
  - Supports TLS encryption, authentication, and authorization.
  - Integrates with Kubernetes RBAC for fine-grained access control.            
- **Multi-Cloud Support**: Can be deployed across multiple cloud providers, ensuring high availability and disaster recovery.

## How to Deploy CFK
Deploying Confluent for Kubernetes (CFK) using Streamtime is straightforward and can be done through the Streamtime UI. Here’s a step-by-step guide:

1. **Create a Kafka Cluster**:
   - Use the Streamtime UI to create a new Kafka cluster.
   - Select "Confluent for Kubernetes" as the distribution type.
   ![Create Kafka Cluster]({{ site.baseurl }}/assets/images/cfk/cluster-type.png)

2. **Configure Cluster Settings**:
   - Choose a cloud provider (AWS, GCP, OCI, Azure) or use BYOK (Bring Your Own Kubernetes).
   - Specify the region.
   - Specify the number of Kafka units (1 unit = 20 MBps throughput).
   - Set the tenancy model (`shared`, `isolated`, or `dedicated`).
   ![Cluster Basic Configuration]({{ site.baseurl }}/assets/images/cfk/cluster-basic-config.png)

3. **Fleet Selection**:
   - Choose the Kubernetes fleet where the Kafka cluster will be deployed.
   - Ensure the fleet is healthy and ready for deployment.
   ![Cluster Fleet Selection]({{ site.baseurl }}/assets/images/cfk/cluster-fleet-selection.png)

4. **Advanced Configuration**:
   - Optionally configure advanced settings such as replication factor, partition count, and resource limits.
   
   ![Cluster Advanced Configuration]({{ site.baseurl }}/assets/images/cfk/cluster-advanced-config.png)

## Monitoring and Management
- **Metrics Dashboards**: Visualize key metrics such as throughput, latency, and error rates.
- **Logs**: Access Kafka logs for troubleshooting and auditing.
- **Alerts**: Set up alerts for critical events and performance issues.
- **Scaling**: Easily scale the Kafka cluster by adjusting the number of Kafka units or adding more nodes to the underlying Kubernetes fleet.
![Cluster Detail]({{ site.baseurl }}/assets/images/cfk/cluster-detail.png)

---

# API Reference

## Create a Confluent for Kubernetes (CFK) Cluster

```bash
curl -X POST https://<streamtime-api-endpoint>/organizations/<your-org-id>/clusters/ \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "working-wallaby",
    "cluster_type": "cfk",
    "kafka_units": 3,
    "provisioner_name": "",
    "tenancy_mode": "Shared",
    "advanced_config": {
        "cluster_access": "Internal & External",
        "authentication_mechanism": "SASL/OAUTH",
        "private_access": false,
        "version": "7.7.0",
        "auto_upgrade_version": false,
        "node_count": 3,
        "oauth": "okta-dev-47119201",
        "additional_system_admin": "Administrators",
        "additional_system_admin_type": "group",
        "storage_tier_configuration": "Balanced",
        "tiered_storage_bucket_name": "cluster-cfk-404",
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
    "id": "cdc0647e-51cc-458f-9fdc-6ea31143b95b",
    "organization": "<your-org-id>",
    "infrastructure": "sympathetic-emu",
    "identifier": "working-wallaby",
    "provisioner_name": "",
    "destroyer_name": null,
    "version_updater_name": null,
    "cluster_type": "cfk",
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
        "cluster_access": "Internal & External",
        "authentication_mechanism": "SASL/OAUTH",
        "private_access": false,
        "version": "7.7.0",
        "auto_upgrade_version": false,
        "node_count": 3,
        "oauth": "okta-dev-47119201",
        "additional_system_admin": "Administrators",
        "additional_system_admin_type": "group",
        "storage_tier_configuration": "Balanced",
        "tiered_storage_bucket_name": "cluster-cfk-404",
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
    "created_at": "2025-07-17T09:54:37.723465Z",
    "updated_at": "2025-07-17T09:54:37.723481Z"
}
```

---


