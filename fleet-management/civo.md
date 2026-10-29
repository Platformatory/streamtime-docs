---
title: "Bootstrap: Civo"
parent: Fleet Management
nav_order: 9
---

# Fleets on Civo

Streamtime creates and runs a Kubernetes cluster in your Civo account,
then installs what the fleet's workloads need. You register the account
once, then create fleets on it.

## Key Features

- **Managed Kubernetes**: Streamtime creates, monitors and deletes the cluster for you.
- **Your network or a new one**: use an existing Civo network, or let Streamtime create one.
- **Kubernetes version**: Civo's current default, or a version you choose.
- **Tenancy**: Shared, Isolated or Dedicated. See [Tenancy]({{ site.baseurl }}/about/tenancy/#tenancy).
- **Sized from your workloads**: node sizes and counts follow the capacity you choose for each workload.
- **Monitoring**: metrics, logs and alerts for the fleet and everything on it. Logs are kept in a Civo Object Store bucket.

## Prerequisites

- **A Civo API token** with no expiration and write access to Kubernetes,
  Networks and Object Store. Streamtime and the Agent on the fleet both use
  it, so a token that expires stops the fleet from being managed.
- **A Base Domain** for the fleet's endpoints, added under **Settings**.

## Fleet settings

**Placement Configuration**

- **Account**: the cloud account you registered.
- **Region**: `NYC1`. More regions will follow.

**Advanced Configuration**

- **Network ID**: an existing Civo network, or leave it empty to create a
  new one.
- **Kubernetes Version**: optional; Civo's current default is used when
  it's empty.
- **Logs Storage Bucket Name**: optional; Streamtime generates a unique
  name when it's empty.

---

{% capture credentials %}{"civo_api_token": "<api-token>"}{% endcapture %}
{% capture placement %}{"account": "<cloud-account>", "region": "NYC1"}{% endcapture %}
{% capture advanced %}{}{% endcapture %}
{% include fleet-tasks.md provider="civo" name="Civo" id="civo" fleet="metrics-nyc" credentials=credentials placement=placement advanced=advanced shots="civo" sdk_account_gap="1815" %}
