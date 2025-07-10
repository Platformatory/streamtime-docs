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



## Conclusion
Confluent for Kubernetes (CFK) provides a powerful and flexible solution for deploying and managing Kafka clusters in Kubernetes environments. With its comprehensive feature set, including integration with the Confluent ecosystem, advanced monitoring capabilities, and Kubernetes-native design, CFK simplifies Kafka operations and enhances productivity for developers and operators alike. Whether you're running a small development cluster or a large-scale production environment, CFK offers the tools and features needed to succeed with Kafka on Kubernetes.
