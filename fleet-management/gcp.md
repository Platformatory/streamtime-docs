---
title: "Bootstrap: GCP"
parent: Fleet Management
nav_order: 4
---

# Fleets on Google Cloud (Preview)

Streamtime creates and runs a Kubernetes cluster (Google Kubernetes Engine,
GKE) in your Google Cloud project, then installs what the fleet's workloads
need. You register the account once, then create fleets on it.

{: .note }
Google Cloud fleets are in preview.

## Key Features

- **Managed Kubernetes**: Streamtime creates, monitors and deletes the GKE cluster for you.
- **Your network or a new one**: use an existing VPC network, or let Streamtime create one.
- **Your encryption key**: optionally encrypt node storage with a Cloud KMS key.
- **Tenancy**: Shared, Isolated or Dedicated. See [Tenancy]({{ site.baseurl }}/about/tenancy/#tenancy).
- **Monitoring**: metrics, logs and alerts for the fleet and everything on it.

## Prerequisites

- **A service account** with a JSON key, that can create GKE clusters, VPC
  networks, Cloud Storage buckets and service accounts in the project.
- **A Base Domain** for the fleet's endpoints, added under **Settings**.

**Cloud account credentials**

- **Service account key**: paste the whole JSON key file.

## Fleet settings

**Placement Configuration**

- **Project**: the cloud account you registered.
- **Zone**: `us-central1-a` or `us-west1-b`.

**Advanced Configuration**

- **VPC network**: an existing network's name, or leave it empty to create
  a new one.
- **Availability Zones**: 1 to 4 (default 1, a single zone).
- **Encryption key** (optional): a Cloud KMS key
  (`projects/<project>/locations/<location>/keyRings/<ring>/cryptoKeys/<key>`)
  to encrypt node storage; without it, Google-managed encryption is used.
- **Logs Storage Bucket Name**: a Cloud Storage bucket name, unique across
  Google Cloud; optional, Streamtime generates one when it's empty.

---

{% capture credentials %}{"service_account_key": "<service-account-key-json-as-a-string>"}{% endcapture %}
{% capture placement %}{"account": "<cloud-account>", "region": "us-central1-a"}{% endcapture %}
{% capture advanced %}{"gcp_az_count": 1}{% endcapture %}
{% include fleet-tasks.md provider="gcp" name="GCP" id="gcp" fleet="clicks-central" credentials=credentials placement=placement advanced=advanced shots="gcp" %}
