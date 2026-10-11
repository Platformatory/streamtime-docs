---
title: "Bring Your Own Virtual Machines (BYOVM)"
parent: Bootstrapping Your Fleet
nav_order: 8
---

# Bootstrapping a BYOVM Fleet

Bring Your Own Virtual Machines (BYOVM) lets Streamtime install and operate Confluent Platform directly on Linux virtual machines that you own. Streamtime uses SSH and `cp-ansible` to configure the hosts; the VMs do not become a Kubernetes cluster.

Use BYOVM when you need VM-based Confluent Platform, must keep the infrastructure in your own network, or cannot run the workload on Kubernetes.

{: .note }
> BYOVM fleets use **Dedicated** tenancy and can host the **Confluent Platform (VM)** Kafka workload. Kubernetes workloads cannot be placed on a BYOVM fleet.

## Prerequisites

Before creating the fleet, prepare the following:

- A base domain configured in Streamtime. Streamtime derives Kafka and component endpoints from this domain.
- The exact number of VMs required by the selected topology. Each VM needs a unique name and a reachable IP address or FQDN.
- SSH access from Streamtime to every VM, using the same unencrypted RSA, Ed25519, or ECDSA private key. Passphrase-protected keys are not supported.
- An SSH user that can run privileged installation tasks with `sudo`.
- Network connectivity between the VMs for the Confluent Platform components in the selected topology.
- A supported 64-bit Linux release:
  - Debian 12
  - Ubuntu 20.04, 22.04, or 24.04
  - RHEL-compatible 8, 9, or 10, including Rocky Linux, AlmaLinux, Oracle Linux, and CentOS
  - Amazon Linux 2023
- Capacity for Confluent Platform data, logs, and shared monitoring services. Size the VMs and disks for your expected retention and throughput.

{: .warning }
> Streamtime records each host's SSH fingerprint during the first connection. Do not rebuild or replace a VM behind the same address without reviewing the stored fingerprint and the replacement procedure for your environment.

## Choose a topology

The **Environment** and **Topology** selections determine both the number of VMs and the component placement. The selected environment is independent of the organization's catalog environment, so a development organization can create a production-shaped fleet for pre-production testing.

| Environment | Topology | VMs | Component placement |
| --- | --- | ---: | --- |
| Development | Minimum | 4 | 3 combined Kafka broker/controller VMs; 1 shared-services VM |
| Development | Full | 7 | Minimum topology plus 1 Kafka Connect, 1 Schema Registry, and 1 REST Proxy VM |
| Production | Minimum | 8 | 3 Kafka broker VMs; 3 controller VMs; 1 Control Center VM; 1 shared-services VM |
| Production | Full - High Availability | 15 | 3 brokers; 3 controllers; 2 Kafka Connect; 2 Schema Registry; 2 REST Proxy; 1 Control Center; 2 shared-services VMs |

The shared-services placement provides the ingress and observability services used by the fleet, including Kong, Prometheus, Grafana, Loki, and Alertmanager. In the production full topology, ingress/metrics and log services are placed on separate VMs.

## Create the fleet

1. In the Streamtime UI, open **Fleets** and click **Create Kubernetes Fleet**.
2. Select **Bring Your Own Virtual Machine** as the bootstrap provider.
3. In **Basic Configuration**:
   - Enter a unique fleet identifier.
   - Keep **Dedicated** tenancy selected.
   - Select the base domain that will be used for Kafka and component endpoints.
   - Optionally select an observability account.
4. In **Placement Configuration**:
   - Select **Development** or **Production**.
   - Select **Minimum** or **Full - High Availability**. The form displays the required VM count.
5. In **Advanced Configuration**:
   - Upload the SSH private key.
   - For every Confluent Platform node, enter a unique host name, IP address or FQDN, SSH user, and SSH port.
   - Enter the same information for each shared-services VM in the separate section.
6. Review the host-to-role mapping and click **Deploy**.

Streamtime validates the SSH key, connects to every host, verifies the operating system, and records SSH fingerprints before it saves and reconciles the fleet. If validation fails, correct every reported host and retry.

## Validate the fleet

When the fleet is ready, its status changes to **Healthy**. Open the fleet detail page to:

- Review the topology and host-to-role mapping.
- Use **Host Management** to inspect the latest status, services, and endpoints for every VM.
- Refresh host health after networking or operating-system changes.
- Open the fleet's Grafana dashboards from the **Monitoring** tab when the shared-services endpoint is available.

After the fleet is healthy, continue with [Confluent Platform on BYOVM]({{ site.baseurl }}/setup-kafka/confluent-platform-vm.html).

## DNS and network planning

Streamtime publishes the DNS names required by a Confluent Platform cluster after deployment. The cluster's **Endpoints** page shows each endpoint and the VM address to which its DNS record must resolve. Depending on the topology, this includes:

- Kafka bootstrap and per-broker names on port `9092`
- Schema Registry on port `8081`
- REST Proxy on port `8082`
- Kafka Connect on port `8083`
- Control Center on port `9021`

Create the displayed DNS records in your DNS provider and allow client traffic only from the networks that should reach each service. Keep SSH and inter-component ports restricted to Streamtime and the BYOVM network.

## Troubleshooting host validation

| Message | What to check |
| --- | --- |
| Authentication failed | Confirm the SSH user and that the uploaded public key is in the user's `authorized_keys`. |
| Connection timed out | Verify routing, firewall rules, the host address, and the SSH port. |
| Unsupported operating system | Recreate or upgrade the VM to a supported distribution and version. |
| Passphrase-protected key | Upload an unencrypted RSA, Ed25519, or ECDSA private key. |
| Host name must be unique | Give every Confluent Platform and shared-services VM a different name. |
