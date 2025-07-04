---
title: Setup Kafka
nav_order: 4
layout: home
---

# Creating Kafka Clusters

Kafka clusters can be provisioned on any eligible fleet in Streamtime. Follow these steps to create a Kafka cluster:


## Before You Begin

Make sure you understand the following:

- **[Tenancy](/concept-architecture/tenancy.html)**: Choose the appropriate tenancy mode (shared, isolated, or dedicated) to control resource isolation.
- **[Kafka Units](/concept-architecture/scaling.html)**: Decide the required throughput and storage (1 Kafka unit = 20 MBps).
- **Fleet Affinity**: Select a fleet in the desired region and network for your workload.

![Cluster Basic configuration]({{ site.baseurl }}/assets/images/cfk/cluster-basic-config.png)  

---

## Steps to Create a Kafka Cluster

1. **Select Cluster Platform**  
   - Choose the Kafka platform that fits your use case: Apache Kafka, CFK, Warpstream, Redpanda, or AutoMQ.

2. **Configure Cluster Basics**  
   - Set the cluster name, tenancy mode, and number of Kafka units.

3. **Select Fleet Placement**  
   - Select the fleet where the cluster will be deployed.
   - Ensure the fleet matches the tenancy mode and has sufficient Kafka units available.

4. **Advanced Configuration**  
   - Configure authentication (identity provider), storage options, Kafka version, and enable/disable auto-upgrade as needed.

5. **Review and Deploy**  
   - Review your configuration.
   - Click "Deploy" to provision the Kafka cluster.

---

## Kafka Platforms

| Platform     | Use Case                     | Notes                  |
|--------------|------------------------------|------------------------|
| Apache Kafka | OSS / Benchmarking           | Full DIY control       |
| CFK          | Enterprise + full Confluent  | Requires license key   |
| Warpstream   | Cost-optimized + remote logs | S3-based architecture  |
| Redpanda     | Low-latency, JVM-free        | Preview feature        |
| AutoMQ       | Cloud-native Kafka engine    | Experimental support   |

![Cluster Type]({{ site.baseurl }}/assets/images/cfk/cluster-type.png)