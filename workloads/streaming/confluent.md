---
title: "Confluent (CFK)"
parent: Streaming
ancestor: Workloads
nav_order: 2
---

# Confluent for Kubernetes (CFK)

Confluent for Kubernetes (CFK) runs Confluent Platform on your Kubernetes
fleets. Streamtime deploys, scales, upgrades and monitors it for you.

## Key Features

- **Managed Kafka**: automated deployment, scaling and management.
- **Confluent Platform components**: Schema Registry and Control Center alongside the brokers.
- **Kubernetes native**: runs on any fleet Streamtime manages, on any supported cloud or your own cluster.
- **Monitoring**: metrics, logs and alerts for every cluster.
- **Security**: TLS encryption, SASL/OAUTH or SASL/PLAIN authentication, and role-based authorization.
- **Tiered storage**: optionally offloads older data to object storage to lower storage cost.

---

## What Streamtime creates for you

- **Confluent Platform components**: Kafka brokers in KRaft mode, Schema Registry (if enabled) and Control Center.
- **Kubernetes objects**: namespaces, StatefulSets, Services and persistent volumes.
- **Networking**: load balancers according to your **Cluster Access** and **Private Access** choices.
- **Storage**: persistent volumes sized to the cluster, and a tiered storage bucket if you enable one.

## Prerequisites

- **A Kubernetes fleet.** See [Fleet management]({{ site.baseurl }}/fleet-management/).
- **An OAuth provider**, for SASL/OAUTH authentication (the default): its
  client ID and secret, issuer, and JWKS, authorization and token endpoints.
  With SASL/PLAIN you don't need one.
- **For tiered storage:** the fleet's cloud account needs permission to
  create object storage buckets (or to use an existing one) and the
  credentials that access it. For example, on AWS:

  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      { "Effect": "Allow", "Action": "s3:*", "Resource": "arn:aws:s3:::<bucket-name>" },
      { "Effect": "Allow", "Action": "s3:*", "Resource": "arn:aws:s3:::<bucket-name>/*" }
    ]
  }
  ```

  On OCI, allow the account's group to manage buckets and objects in the
  bucket's compartment:

  ```text
  Allow group <group-name> to manage buckets in compartment id <compartment-id>
  Allow group <group-name> to manage objects in compartment id <compartment-id>
  ```

---

## Cluster settings

What each setting on the **Create cluster** screens means. The steps
themselves are under [Create a cluster](#create-a-cluster).

**Basic Configuration**

- **Identifier**: unique in your organization. The UI suggests one; replace it with a meaningful name, for example `clickstream-pipe`.
- **Tags**: key/value labels such as `environment=non-prod`, for owner, environment or cost center.
- **Cloud Provider / Region**: where the fleet runs.
- **Tenancy**: Shared, Dedicated or Isolated. See [Tenancy]({{ site.baseurl }}/about/tenancy/#tenancy).
- **Kafka Units (KU)**: baseline throughput capacity, about 20 MB/s each.
  1 KU suits development or light production. With replication factor 3
  and bursty writes, choose more so the brokers' disks don't saturate.
- **Optimization Goal** (Dedicated and Isolated): **Cost**, **Balanced** or **Performance**.

{: .note }
Alerts for this cluster go to the alert channels of the fleet that hosts it.
See [Alert Channels]({{ site.baseurl }}/fleet-management/#alert-channels).

**Fleet Selection** (administrators only)

The fleet that hosts the cluster.

**Advanced Configuration** (administrators only)

- **Cluster Access**: **Internal** (clients in the same Kubernetes cluster),
  **External** (clients outside it), or **Internal & External** (the default).
- **Private Access**: makes the external load balancer private to your cloud
  network instead of public, on clouds that support it.
- **Authentication Mechanism**: **SASL/OAUTH** (the default, recommended)
  authenticates clients through your identity provider; **SASL/PLAIN** uses
  usernames and passwords.
- **OAuth Provider**: client ID, client secret, issuer, and the JWKS,
  authorization and token endpoints. Required for SASL/OAUTH. With SASL/PLAIN
  it is optional and only adds single sign-on to Control Center; fill in
  every field or leave it empty.
- **Enable Automatic Upgrades**: off by default.
- **License**: your Confluent license. Leave it blank for a trial.
- **Enable Schema Registry**: on by default.
- **Additional System Admin** and **Additional System Admin Type**: a group
  (the default, `Administrators`) or user in your identity provider that
  gets full access to the cluster.
- **Tiered Storage Provider**: off by default. When enabled, Streamtime takes
  the cloud and bucket credentials from the fleet's cloud account. Set:
  - **Tiered Storage Bucket Name**: globally unique within the cloud provider;
    add numbers to your organization's naming convention to keep it unique.
  - **Tiered Storage Create Bucket**: on to let Streamtime create the bucket,
    off to use an existing one.
  - **Storage Tier Configuration**: how soon data moves to the bucket.
    **Aggressive** moves it quickly and keeps local disks small;
    **Balanced** is the default; **Conservative** keeps data local longer,
    which is faster to read but needs larger disks.
    See [Confluent tiered storage](https://docs.confluent.io/platform/current/clusters/tiered-storage.html).

---

## Manage a CFK cluster

From the API, CLI or MCP, a CFK cluster also needs its authentication in
`advanced_config` (see [Cluster settings](#cluster-settings)). With
SASL/OAUTH, the default, add your OAuth provider to the create request:

```json
"advanced_config": {
  "oauth": {
    "clientId": "<client-id>",
    "clientSecret": "<client-secret>",
    "issuer": "https://idp.example.com",
    "jwksEndpoint": "https://idp.example.com/jwks",
    "authorizeEndpoint": "https://idp.example.com/authorize",
    "tokenEndpoint": "https://idp.example.com/token"
  }
}
```

Or use usernames and passwords instead:

```json
"advanced_config": { "authentication_mechanism": "SASL/PLAIN" }
```

To enable tiered storage, add:

```json
"tiered_storage_provider": {
  "tiered_storage_bucket_name": "<bucket>",
  "storage_tier_configuration": "Balanced"
}
```

{% include kafka-cluster-tasks.md workload="cfk" name="Confluent Platform" id="cfk" cluster="clickstream-pipe" shots="cfk" %}
