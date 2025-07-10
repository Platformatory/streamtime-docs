---
title: Monitoring
nav_order: 2
parent: Operations
---

## Video Walkthrough: Monitoring a Kubernetes Cluster

<video class="video-js vjs-theme-city" controls preload="auto" width="640" height="264" data-setup='{}'>
    <source src="{{ '/assets/videos/kubernetes-monitoring.webm' | relative_url }}" type="video/webm">
  Your browser does not support the video tag.
</video>
---


# Monitoring

Streamtime provides comprehensive monitoring for both Kubernetes infrastructure and Kafka clusters. All metrics are visualized through integrated dashboards for real-time observability and troubleshooting.

---

## Kubernetes Monitoring

- **Cluster Health**: Overall status of the Kubernetes fleet.
- **Node Metrics**: CPU, memory, and storage utilization for each node.
- **Metrics Dashboards**: Visualize resource usage and identify bottlenecks.

![Node Overview]({{site.baseurl}}/assets/images/monitoring/node-overview.png)



## Kafka Monitoring

## Video Tutorial: Monitoring a Kafka Cluster

<video class="video-js vjs-theme-city" controls preload="auto" width="640" height="264" data-setup='{}'>
    <source src="{{ '/assets/videos/kafka-monitoring.webm' | relative_url }}" type="video/webm">
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

- **Cluster Health**: Status and availability of Kafka clusters.
- **Kafka Operations Metrics**: Production and consumption rates, partition distribution, and replication status.
- **Metrics Dashboards**: Topic-level throughput, latency, and error rates.

### Platform-Specific Metrics

- **CFK (Confluent for Kubernetes)**
  - Topic-wise metrics
  - Schema Registry metrics
  - Confluent platform logs

- **Apache kafka**
  - KRaft (Kafka Raft) metrics

![cluster health]({{site.baseurl}}/assets/images/monitoring/cluster-health.png)

---


Use the Streamtime UI dashboards to monitor all aspects of your clusters and quickly respond to any issues.