---
title: "Bootstrap: Oracle"
parent: Fleet Management
nav_order: 5
---

# Fleets on Oracle Cloud (OCI)

Streamtime creates and runs a Kubernetes cluster (Oracle Kubernetes Engine,
OKE) in your OCI tenancy, then installs what the fleet's workloads need.
You register the account once, then create fleets on it.

## Key Features

- **Managed Kubernetes**: Streamtime creates, monitors and deletes the OKE cluster for you.
- **Your network or a new one**: use an existing VCN, or let Streamtime create one.
- **Your encryption key**: optionally encrypt the cluster with a key from OCI Vault.
- **Tenancy**: Shared, Isolated or Dedicated. See [Tenancy]({{ site.baseurl }}/about/tenancy/#tenancy).
- **Monitoring**: metrics, logs and alerts for the fleet and everything on it.

## Prerequisites

1. **A user with the right permissions.** Create a group for Streamtime
   (for example `streamtime-admins`), add the user to it, and attach a
   policy that lets the group manage resources in the fleet's compartment:

   ```text
   Allow group <group-name> to manage all-resources in compartment id <compartment-id>
   ```

   Streamtime then creates and manages compute, networking, storage and
   OKE resources in that compartment.
2. **An API key for that user.** See
   [Managing API keys](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm#two).
   You need its fingerprint and the unencrypted private key.
3. **A compartment** for the fleet, and its OCID (OCI Console →
   Identity & Security → Compartments).
4. **A Base Domain** for the fleet's endpoints, added under **Settings**.
5. Optionally, an **SSH public key** to reach the worker nodes, and a
   **KMS key** in OCI Vault to encrypt the cluster. OKE must be allowed to
   use the key.

**Cloud account credentials**

- **Tenancy OCID**: the tenancy Streamtime creates resources in.
- **User OCID**: the user from step 1.
- **Key Fingerprint** and **Private Key**: the API key from step 2.
- **Defined Tags** (optional): tags, as namespace, key and value, that
  Streamtime adds to every resource it creates, for ownership, cost and
  auditing.
- **Domain OCID** (optional): the Identity Domain where Streamtime creates
  the user for the logs bucket. Without it, the tenancy's default domain is
  used; set it when the user can't use the default domain.

## Fleet settings

**Placement Configuration**

- **Account**: the cloud account you registered.
- **Region**: `ap-mumbai-1` or `ap-hyderabad-1`.
- **Compartment ID**: the compartment's OCID.

**Advanced Configuration**

- **VCN ID**: an existing VCN, or leave it empty to create a new one. Make
  sure an existing VCN has enough addresses for the nodes and services.
- **Node Shape**: the worker nodes' shape (default `VM.Standard.E4.Flex`;
  also `VM.Standard3.Flex`, `VM.Standard.A1.Flex`, `VM.Standard.E5.Flex`).
- **Logs Storage Bucket Name** (required): an Object Storage bucket name,
  unique across OCI.
- **KMS Key ID**: optional; without it, Oracle-managed keys are used.
- **Public Cluster**: whether the Kubernetes API is reachable from the
  internet (on by default).
- **API Server Allowed CIDRs**: the address ranges allowed to reach the
  Kubernetes API and SSH. The default `0.0.0.0/0` allows everyone; restrict
  it to your office or VPN ranges.
- **SSH Public Key**: optional; leave it empty if you don't need SSH access
  to the nodes.

---

{% capture credentials %}{"tenancy_ocid": "ocid1.tenancy.oc1..<id>", "user_ocid": "ocid1.user.oc1..<id>", "fingerprint": "<key-fingerprint>", "private_key": "<private-key-pem>"}{% endcapture %}
{% capture placement %}{"account": "<cloud-account>", "region": "ap-hyderabad-1", "compartment_id": "ocid1.compartment.oc1..<id>"}{% endcapture %}
{% capture advanced %}{"oci_node_shape": "VM.Standard.E4.Flex", "oci_logs_storage_bucket_name": "<logs-bucket>"}{% endcapture %}
{% capture network_body %}{"identifier": "ledger-vcn", "provider": "<cloud-account>", "name": "ledger-vcn", "region": "ap-hyderabad-1", "cidr": "10.3.0.0/22", "compartment_id": "ocid1.compartment.oc1..<id>"}{% endcapture %}
{% capture network_terraform %}
```hcl
# Record a VCN you already have: set network_id and nothing is created.
resource "streamtime_network" "existing" {
  identifier    = "ledger-vcn"
  name          = "ledger-vcn"
  cloud_account = streamtime_cloud_account.oci.identifier
  network_id    = "ocid1.vcn.oc1..<id>"
}
```

Terraform can't create a new VCN yet: creating one needs a compartment, and
`streamtime_network` has no setting for it. Create the VCN from the UI, API
or CLI, or in OCI, then record it here. To manage a network that already
exists in Streamtime, import it by identifier:
`terraform import streamtime_network.existing ledger-vcn`. See
[streamtime_network]({{ site.baseurl }}/terraform/network/).
{% endcapture %}
{% include fleet-tasks.md provider="oci" name="OCI" id="oci" fleet="ledger-south" credentials=credentials placement=placement advanced=advanced network_body=network_body network_terraform=network_terraform shots="oci" %}
