---
title: "Bootstrapping Your Fleet"
nav_order: 3
layout: home
---

# Bootstrapping Your Fleet

Before provisioning a Kubernetes fleet, plan the following:

![Bootstrap Provider]({{site.base_url}}/assets/images/fleet-bootstrap-provider.png)

##  Sizing Considerations

Choose your tenancy model:

- `shard`: Shared control and data plane
- `dedicated`: Isolated data plane
- `isolated`: Full tenant isolation including control plane

Recommended instance sizing:

| Kafka Units | Throughput | Node Size |
|-------------|------------|-----------|
| 1 unit      | 20 MBps    | 4 vCPU / 16 GB RAM |

![Basic Configuration]({{site.base_url}}/assets/images/fleet-basic-config.png)

##  Provider Choice

Choose a provider that matches:

- Your cloud region affinity
- VPC peering capabilities
- Instance flexibility

See provider-specific pages for details.


![Placement Config]({{site.base_url}}/assets/images/fleet-placement-config.png)

![Advanced Config]({{site.base_url}}/assets/images/fleet-advanced.png)