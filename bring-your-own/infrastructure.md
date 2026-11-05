---
title: Infrastructure
parent: Bring your own
nav_order: 1
permalink: /bring-your-own/infrastructure/
---

# Infrastructure

Every fleet runs somewhere you choose. Pick per fleet; one organization
can mix all three.

| | A cloud account | Your own Kubernetes (BYOK) | Your own virtual machines (BYOVM) |
|---|---|---|---|
| What Streamtime does | Creates the Kubernetes cluster, its network and nodes, and deletes them again with the fleet | Installs its agent and only the services the fleet's workloads need on your cluster | Connects over SSH and sets up the shared services and one Confluent Platform cluster |
| What you bring | An account in AWS, Azure, GCP, Oracle Cloud, Civo or DigitalOcean, registered as a **Cloud Account** | A cluster with a load-balancer provider and a default storage class | Linux machines (4 to 15), one SSH key with passwordless `sudo` |
| Workloads | Kafka, Flink, ClickHouse | Kafka, Flink, ClickHouse | Confluent Platform |
| Capacity | You set units per kind of workload | Divided from what the cluster has | Set by the machines |
| You also need | A **Base Domain** | A **Base Domain** | A **Base Domain** |

What stays yours on your own cluster: its networking, storage, load
balancer and anything Streamtime didn't install. Deleting a fleet removes
only what Streamtime installed for it.

## Pages

- [Cloud Accounts]({{ site.baseurl }}/configuration/fleet-providers/):
  register an account in a supported cloud.
- [Fleet Management]({{ site.baseurl }}/fleet-management/): create a fleet
  in each cloud.
- [Bring your own Kubernetes]({{ site.baseurl }}/fleet-management/byok/),
  with [AWS (EKS)]({{ site.baseurl }}/fleet-management/byok-aws/) and
  [OCI (OKE)]({{ site.baseurl }}/fleet-management/byok-oci/) specifics.
- [Bring your own VMs]({{ site.baseurl }}/fleet-management/byovm/).
- [Capacity units]({{ site.baseurl }}/about/scaling/): how a fleet's
  capacity is worked out.
