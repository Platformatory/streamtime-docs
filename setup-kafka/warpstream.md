---
title: "WarpStream"
parent: Setup Kafka
nav_order: 4
---

# WarpStream

WarpStream is a Kafka API-compatible streaming platform that writes directly to object storage instead of local disks. Streamtime deploys WarpStream as a Bring Your Own Cloud (BYOC) cluster: the Kafka-protocol agents run inside your own Kubernetes fleet, while WarpStream's own control plane handles coordination and metadata in the region you choose.

---

## When to Use WarpStream

- **Object-storage economics**: When you want Kafka's durability guarantees backed by S3 rather than provisioned block storage, and don't want to size or manage local disks.
- **Bursty or unpredictable traffic**: Agents are stateless, so scaling out doesn't involve rebalancing data across disks.
- **Cost-sensitive workloads**: Storage and throughput are billed on usage rather than pre-provisioned capacity.

---

## How WarpStream Is Different

A few architectural choices carry through into how you configure and operate a WarpStream cluster:

- **Object storage is the only storage tier.** WarpStream agents don't hold partition data on local disk — every write goes to your object storage bucket. There's no "hot tier" of local disk to size or a tiered-storage toggle to turn on, unlike some other Kafka platforms Streamtime supports. How long that data is *kept* before deletion is a separate, ordinary setting — **Retention** — covered under Cluster Basics below.
- **Agents, not brokers.** WarpStream's compute units are called Agents. They're Kafka-protocol-compatible, but because they don't hold local state, scaling agent count in and out is cheap and doesn't move data around.
- **Two independent sizing knobs.** Kafka Units control the data plane — how many agents run and how much compute they get. Cluster Tier (see Advanced Configuration) is a separate setting that determines the pricing and SLA of the WarpStream control plane your cluster registers against. Sizing one does not size the other.
- **TLS is always on.** WarpStream's listener uses a single TLS configuration shared by internal and external traffic — there's no option to run a cluster without TLS, regardless of which access mode you choose.

For more on WarpStream's architecture, see the [WarpStream documentation](https://docs.warpstream.com/warpstream/overview/architecture).

---

## Prerequisites

- **A Kubernetes fleet.** WarpStream deploys onto a fleet you've already bootstrapped. See [Bootstrapping a Fleet]({{ site.baseurl }}/bootstrapping-fleet/).
- **A WarpStream account and API key.** Your cluster is registered against WarpStream's own control plane, so you'll need a WarpStream account and an API key from it before you start. Streamtime uses this key only to provision the cluster on your behalf.
- **An S3 bucket, or permission to create one.** WarpStream's object storage backend is Amazon S3. You can point it at an existing bucket, or let Streamtime create one for you during cluster creation.
- **Credentials for that bucket.** An AWS access key and secret key with permission to read, write, list, and delete objects in the bucket. If you're letting Streamtime create the bucket, the credentials also need permission to create it.

| Credential | Needs permission to… |
|---|---|
| Access key / secret key | Read, write, list and delete objects in the bucket |
| (if auto-creating the bucket) | Create the bucket |

{: .note }
Streamtime only deletes the bucket when it created it for you. A bucket you pointed the cluster at yourself is never deleted when the cluster is removed.

Example bucket-scoped IAM policy, minimally covering these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "WarpStreamObjectAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::<bucket-name>/*"
    },
    {
      "Sid": "WarpStreamListBucket",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::<bucket-name>"
    },
    {
      "Sid": "WarpStreamBucketLifecycle",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket"
      ],
      "Resource": "arn:aws:s3:::<bucket-name>"
    }
  ]
}
```

{: .note }
Drop the `WarpStreamBucketLifecycle` statement if you're pointing the cluster at a bucket that already exists — it's only needed when Streamtime creates (and later deletes) the bucket for you.

---

## Creating a WarpStream Cluster

**Step 1: Select Cluster Type**

Navigate to **Clusters → Create Cluster →** select **WarpStream → Begin Configuration**.

**Step 2: Cluster Basics**

* **Identifier** — a unique, lowercase name for the cluster. Used throughout the UI and API to refer to it.
* **Tags** — key/value labels for organizing clusters by environment, owner, or cost center.
* **Cloud Provider / Region** — where the underlying Kubernetes fleet runs.
* **Tenancy** — Shared, Dedicated, or Isolated. See [Tenancy]({{ site.baseurl }}/concept-architecture/tenancy.html#tenancy).
* **Kafka Units (KU)** — sizes the data plane. WarpStream always runs at least 3 agents for availability; each additional Kafka Unit above that adds one more agent. This is a different relationship than the "1 KU ≈ 20 MB/s" rule of thumb used for disk-based providers — WarpStream throughput scales with agent count rather than a fixed per-unit bandwidth figure.
* **Retention** — how long data is kept before deletion. Choose **Finite** and a number of days, or **Infinite** to keep data indefinitely. This applies to any Kafka cluster type, WarpStream included, and is unrelated to object storage tiering — WarpStream has no separate hot/cold tiers to configure.

**Step 3: Fleet Placement** (Administrator users only)

Select the Kubernetes fleet that will host the WarpStream agents.

**Step 4: Advanced Configuration** (Administrator users only)

* **Number of Zones** — `1` or `2`. Controls how many availability zones the deployment spans.
* **Cluster Access** — `Internal` or `External`. WarpStream exposes a single Kafka listener, so this is a straight either/or rather than a combined internal-and-external option: **Internal** keeps the cluster reachable only from inside the Kubernetes fleet; **External** exposes it outside the cluster and requires DNS pointed at the cluster's endpoints (see Connecting to Your Cluster below).
* **Private Access** — when enabled, the load balancer backing external access is provisioned as private (internal to your cloud network) rather than public. Available on cloud providers that support private load balancers.
* **Cluster Tier** — `dev`, `pro`, or `fundamentals`. Sets the pricing and SLA of the WarpStream control plane this cluster registers against. It does not affect throughput or agent count — that's controlled by Kafka Units.
* **WarpStream Account** — the API key for your WarpStream account (see Prerequisites), and the WarpStream control-plane region to register this cluster in. These are separate from the cloud provider/region you chose in Cluster Basics, which is where your Kubernetes fleet runs.
* **Object Storage** — bucket name, region, access key, and secret key for the S3 bucket backing this cluster, plus whether Streamtime should create the bucket if it doesn't already exist.
* **Enable Schema Registry** — provisions a Schema Registry alongside the Kafka cluster. See below.
* **Alert Channels** — notification channels (Slack/email, configured in Settings) that receive alerts for this cluster.

**Once all steps are complete** — review the configuration and click **Create Cluster**.

---

## Schema Registry (Optional)

Enabling **Schema Registry** during Advanced Configuration provisions a Schema Registry alongside your Kafka cluster.

**Authentication.** Schema Registry has HTTP Basic Auth enabled — every request must include a username and password. To get credentials:

1. Log in to the WarpStream console and select the Schema Registry cluster.
2. Open its **Credentials** tab and create a new credential. Copy the username and password — the password is shown only once.

Use these credentials with any Schema Registry client, e.g. `basic.auth.credentials.source=USER_INFO` and `basic.auth.user.info=<username>:<password>` for Confluent serializers. For more details, see the [WarpStream Schema Registry documentation](https://docs.warpstream.com/warpstream/schema-registry/warpstream-byoc-schema-registry).

---

## Connecting to Your Cluster

**Endpoints.** An Internal cluster is reachable at a standard in-cluster address (`ws.<namespace>.svc.cluster.local:9092`). An External cluster is reachable at a bootstrap hostname of the form `<cluster>-bootstrap.<your-domain>` on port 443, with per-agent hostnames following the same pattern.

**TLS and authentication.** All connections use TLS. Client authentication is SASL over TLS — obtain a username and password for the cluster from the WarpStream console.

{: .note }
If your fleet's domain uses automatic certificate issuance (the default — see Prerequisites), the cluster's certificate is issued by a real, publicly-trusted CA and no extra client configuration is needed. If instead you supplied your own certificate (BYO PEM, used when your DNS provider isn't supported for automatic issuance — see Troubleshooting below) and that certificate is self-signed rather than chained to a publicly-trusted root, clients must trust it explicitly via a local truststore, or TLS validation will fail.

To build a truststore from a self-signed cert with `keytool`:

```bash
keytool -import -trustcacerts -alias warpstream-ca -file ca-cert.pem \
  -keystore truststore.jks -storepass <truststore-password>
```

Then point your client at it in `client.properties`:

```properties
ssl.truststore.location=/path/to/truststore.jks
ssl.truststore.password=<truststore-password>
```

Non-Java clients (e.g. librdkafka-based) typically don't need a JKS truststore at all — point `ssl.ca.location` directly at the PEM file instead.

**Client configuration.** The cluster detail page's **Test Kafka Connection** dialog gives you a ready-to-use `client.properties` file and equivalent CLI commands for the cluster — copy these directly into your Kafka client rather than assembling connection settings by hand.

**Listing schemas.** If Schema Registry is enabled, the same dialog includes a command to list registered subjects against its REST endpoint:

```bash
curl -u <username>:<password> https://<schema-registry-endpoint>/subjects
```

WarpStream's Schema Registry implements the standard Confluent Schema Registry REST API, so any client or tool built against that API (subjects, schema versions, compatibility checks) works against it unmodified. All requests require HTTP Basic Auth — see [Schema Registry](#schema-registry-optional) above for how to get credentials.

---

## Monitoring and Alerts

WarpStream clusters get a dedicated dashboard covering:

- **Availability** — agent count, topic and partition counts against your plan's limits.
- **Traffic** — produce/fetch throughput, compression ratio, requests by Kafka API type.
- **Latency and lag** — consumer group lag, request latency, control-plane round-trip time.
- **Storage** — object storage latency and error rate.

Default alerts are pre-configured for every WarpStream cluster and route to the alert channels you selected in Advanced Configuration:

- **Agent Down** — fires when all agents are unavailable for several minutes.
- **Consumer Group Lag Too High** — fires when a consumer group falls significantly behind.
- **Object Storage Errors** — fires when writes to your bucket start failing.
- **Elevated Request Latency** — fires when Kafka requests are consistently slow to respond.

See [Alert Channels]({{ site.baseurl }}/operations/monitoring.html) to configure where these go.

---

## Scaling and Cost

Kafka Units control agent count: WarpStream runs a minimum of 3 agents, and each Kafka Unit above that adds one more. For Dedicated or Isolated tenancy, the Optimization Goal (Cost / Balanced / Performance) also determines the instance size each agent runs on. This is a straightforward count-and-size relationship rather than a validated throughput curve — treat Kafka Units as a starting point and adjust based on the throughput and latency you observe for your own workload, using the dashboard described above.

Cost is usage-based: you're billed for storage consumed, data transferred, and cluster uptime, rather than for a fixed reserved capacity. See [Scaling]({{ site.baseurl }}/concept-architecture/scaling.html) for how this compares to other Kafka platforms Streamtime supports.

---

## API Reference

### Create a WarpStream Cluster

```bash
curl -X POST https://<streamtime-api-endpoint>/organizations/<your-org-id>/clusters/ \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "clever-otter",
    "cluster_type": "warpstream",
    "kafka_units": 3,
    "tenancy_mode": "Shared",
    "retention_mode": "Finite",
    "retention_days": 7,
    "advanced_config": {
        "number_of_zones": "1",
        "cluster_access": "External",
        "private_access": false,
        "cluster_tier": "pro",
        "warpstream_api_key": "********",
        "warpstream_region": "us-east-1",
        "s3_bucket_name": "clever-otter-warpstream",
        "s3_region": "us-east-1",
        "s3_access_key": "AKIA...",
        "s3_secret_access_key": "********",
        "storage_create_bucket": true,
        "schema_registry_enabled": true
    },
    "tags": [
        {
            "key": "environment",
            "value": "non-prod"
        }
    ],
    "organization": "<your-org-id>",
    "cloud_provider": "aws",
    "region": "us-east-1",
    "infrastructure": "sympathetic-emu"
}'
```

**Response:**

```json
{
    "id": "7b6a1e2d-4c3f-4a5b-9e8d-1f2a3b4c5d6e",
    "organization": "<your-org-id>",
    "infrastructure": "sympathetic-emu",
    "identifier": "clever-otter",
    "cluster_type": "warpstream",
    "tenancy_mode": "Shared",
    "kafka_units": 3,
    "retention_days": 7,
    "cloud_provider": "aws",
    "region": "us-east-1",
    "tags": [
        {
            "key": "environment",
            "value": "non-prod"
        }
    ],
    "advanced_config": {
        "number_of_zones": "1",
        "cluster_access": "External",
        "private_access": false,
        "cluster_tier": "pro",
        "warpstream_region": "us-east-1",
        "s3_bucket_name": "clever-otter-warpstream",
        "s3_region": "us-east-1",
        "storage_create_bucket": true,
        "schema_registry_enabled": true
    },
    "console_url": null,
    "client_properties": null,
    "status": "Pending",
    "created_at": "2025-07-17T09:54:37.723465Z",
    "updated_at": "2025-07-17T09:54:37.723481Z"
}
```

---

## Troubleshooting

**Cluster stuck in Pending.** The most common cause is object storage credentials — double-check the access key and secret key have permission to read, write, list, and delete objects in the bucket (and create it, if you left bucket auto-creation on).

**External cluster unreachable after creation.** Allow a few minutes for DNS to propagate after enabling External access. If it's still unreachable, confirm you're using a DNS provider Streamtime can automate certificates for. Automated TLS certificate issuance is only available on certain DNS providers; on others (for example, GoDaddy), you'll need to supply your own TLS certificate instead of relying on automatic issuance.
