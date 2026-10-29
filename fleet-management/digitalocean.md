---
title: "Bootstrap: DigitalOcean"
parent: Fleet Management
nav_order: 8
---

# Fleets on DigitalOcean

Streamtime creates and runs a Kubernetes cluster (DigitalOcean Kubernetes)
in your DigitalOcean account, then installs what the fleet's workloads
need. You register the account once, then create fleets on it.

## Key Features

- **Managed Kubernetes**: Streamtime creates, monitors and deletes the cluster for you.
- **Your network or a new one**: use an existing VPC, or let Streamtime create one.
- **Optional high-availability control plane** for production fleets.
- **Tenancy**: Shared, Isolated or Dedicated. See [Tenancy]({{ site.baseurl }}/about/tenancy/#tenancy).
- **Sized from your workloads**: node sizes and counts follow the capacity you choose for each workload.
- **Monitoring**: metrics, logs and alerts for the fleet and everything on it. Logs are kept in a Spaces bucket.

## Prerequisites

- **A DigitalOcean personal access token** with no expiration and write
  access to Kubernetes, VPCs and Spaces. Streamtime and the Agent on the
  fleet both use it, so a token that expires stops the fleet from being
  managed.
- **A Base Domain** for the fleet's endpoints, added under **Settings**.

## Fleet settings

**Placement Configuration**

- **Account**: the cloud account you registered.
- **Region**: `nyc3`, `sfo3`, `ams3`, `sgp1`, `fra1` or `syd1` (the
  regions with both Kubernetes and Spaces).

**Advanced Configuration**

- **VPC ID**: an existing VPC, or leave it empty to create a new one.
- **VPC CIDR**: the address range of a new VPC (`10.0.0.0/16`,
  `10.3.0.0/16`, the default, or `172.16.0.0/16`).
- **High-Availability Control Plane**: off by default.
- **Public Cluster**: whether the Kubernetes API is reachable from the
  internet (on by default).
- **Logs Storage Bucket Name**: optional; Streamtime generates a unique
  name when it's empty.
- **Spaces Region**: optional; set it only when the cluster's region has
  no Spaces endpoint.

---

{% capture credentials %}{"digitalocean_token": "<api-token>"}{% endcapture %}
{% capture placement %}{"account": "<cloud-account>", "region": "nyc3"}{% endcapture %}
{% capture advanced %}{"do_vpc_cidr": "10.3.0.0/16"}{% endcapture %}
{% include fleet-tasks.md provider="digitalocean" name="DigitalOcean" id="do" fleet="events-nyc" credentials=credentials placement=placement advanced=advanced shots="digitalocean" sdk_account_gap="1815" %}
