---
title: Setup Kafka
nav_order: 4
layout: home
---

# Creating Kafka Clusters

Kafka clusters can be provisioned on any eligible fleet.
![Cluster Type]({{ site.baseurl }}/assets/images/cluster-type.png)  
##  Before You Begin

Understand:

- **Tenancy**: Controls isolation and shared infra boundaries
- **Kafka Units**: Determines throughput and storage
- **Fleet Affinity**: Ensure compatible region and network

![Cluster Basic configuration]({{ site.baseurl }}/assets/images/cluster-basic-config.png)  


## Kafka Platforms

| Platform     | Use Case                     | Notes                  |
|--------------|------------------------------|------------------------|
| Apache Kafka | OSS / Benchmarking           | Full DIY control       |
| CFK          | Enterprise + full Confluent  | Requires license key   |
| Warpstream   | Cost-optimized + remote logs | S3-based architecture  |
| Redpanda     | Low-latency, JVM-free        | Preview feature        |
| AutoMQ       | Cloud-native Kafka engine    | Experimental support   |

![Cluster Type]({{ site.baseurl }}/assets/images/cluster-type.png) 