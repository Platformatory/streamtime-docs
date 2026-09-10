---
title: Virtual Kafka Cluster
nav_order: 6
parent: Concepts & Architecture
---

# Virtual Kafka Cluster

A **Virtual Kafka Cluster** lets you carve out a logically independent Kafka cluster from the spare capacity of an existing Kafka cluster. Each Virtual Kafka Cluster gets its own connection endpoint, its own authentication, and a guaranteed slice of throughput — while multiple Virtual Kafka Clusters share the same underlying physical Kafka cluster.

To a client application, a Virtual Kafka Cluster looks and behaves exactly like a dedicated Kafka cluster. Behind the scenes, Streamtime is sharing one physical cluster's resources across many tenants safely and predictably.

## Why Use a Virtual Kafka Cluster

- **Faster tenant onboarding** — hand a new team or customer their own Kafka endpoint in minutes, without provisioning and paying for an entirely new physical cluster.
- **Guaranteed throughput per tenant** — each Virtual Kafka Cluster is allocated a fixed share of the backing cluster's capacity, so one noisy tenant can't starve another.
- **Independent authentication** — every Virtual Kafka Cluster authenticates clients against its own identity provider, so tenants never share credentials or see each other's traffic.
- **Lower cost per tenant** — many lightweight tenants can share the infrastructure cost of one well-sized physical Kafka cluster.

{: .note }
> A Virtual Kafka Cluster always runs on top of an existing physical Kafka cluster in your fleet. If you don't have a Kafka cluster yet, create one first — see [Kafka Cluster]({{ site.baseurl }}/concept-architecture/kafka-cluster).

## How Capacity Works

Every physical Kafka cluster has a total capacity measured in **Kafka Units** (the same throughput unit used when sizing a Kafka cluster). When you create a Virtual Kafka Cluster, you claim a portion of that capacity for it.

- The Kafka Units you allocate become that Virtual Kafka Cluster's guaranteed produce and fetch throughput.
- The sum of the Kafka Units claimed by *all* Virtual Kafka Clusters on a physical cluster can never exceed that cluster's total Kafka Units.
- If you try to allocate more than what's left, Streamtime rejects the request and tells you exactly how much capacity remains.

This means capacity planning is explicit and predictable — you always know exactly how much of your Kafka cluster is claimed, and by whom.

---

## Creating a Virtual Kafka Cluster

Creating a Virtual Kafka Cluster is a guided 3-step process in the Streamtime UI.

### 1. Basic Configuration

- **Identifier** — a unique name for this Virtual Kafka Cluster (a default is suggested for you, and you can change it).
- **Provider** — the virtual cluster technology to use. Today there is a single supported option, pre-selected for you.

### 2. Kafka Cluster Selection

- **Kafka Cluster** — choose which physical Kafka cluster this Virtual Kafka Cluster will run on. Only clusters with enough spare capacity are shown.
- **Capacity Allocation (Kafka Units)** — how much of that cluster's throughput to reserve for this Virtual Kafka Cluster. This becomes its guaranteed produce and fetch limit.

### 3. Advanced Configuration

- **Software Version** — optionally pin the version of the virtual cluster engine and its metrics dashboard. Most users can leave these on the recommended defaults.
- **Authentication** — configure the identity provider your clients will use to connect (see [Authentication](#authentication) below).

Once you click **Create**, Streamtime provisions the Virtual Kafka Cluster in the background. You'll see its status move from `Pending` → `Provisioning` → `Healthy` on the detail page.

---

## Authentication

Every Virtual Kafka Cluster authenticates client connections against an identity provider you configure — clients never connect anonymously, and tenants never share credentials.

You'll need the following details from your identity provider:

| Field | Description |
| --- | --- |
| Client ID | The OAuth client identifier registered with your identity provider. |
| Client Secret | The OAuth client secret. This is never displayed again after you save it. |
| Issuer | The identity provider's issuer URL. |
| JWKS Endpoint | The endpoint your identity provider publishes its signing keys at. |
| Authorization URI | The identity provider's authorization endpoint. |
| Token URI | The identity provider's token endpoint. |
| Audience | The expected audience value for tokens issued to this Virtual Kafka Cluster. |
| Scope | (Optional) The OAuth scope requested when authenticating. |
| TLS Trusted Certificate | (Optional) A custom CA certificate, if your identity provider uses one. |

{: .note }
> Client Secret is write-only. Once saved, Streamtime never displays it again — if you need to rotate it, enter a new one from your identity provider.

---

## Connecting to Your Virtual Kafka Cluster

Once your Virtual Kafka Cluster is `Healthy`, open its detail page to find everything a client needs to connect:

- **Endpoints** — the bootstrap address(es) and DNS record for this Virtual Kafka Cluster, with a one-click copy button.
- **Test Connection** — click **Test** next to an endpoint to get a ready-to-use `client.properties` snippet (bootstrap servers plus the authentication settings you configured), which you can paste directly into your Kafka client or application configuration.
- **Cluster Capacity, Produce Limit, and Fetch Limit** — the throughput guarantees enforced for this Virtual Kafka Cluster, shown in both Kafka Units and bytes/second.
- **Upstream Kafka Cluster** — a link back to the physical Kafka cluster this Virtual Kafka Cluster runs on, and its fleet.
- **Authorization** — the identity provider details you configured (Issuer, Audience, JWKS Endpoint, Authorization URI, Token URI, Scope). Client ID and Client Secret are not redisplayed for security.

## Cluster Status

| Status | Meaning |
| --- | --- |
| Pending | The Virtual Kafka Cluster has been requested and is queued for provisioning. |
| Provisioning | Streamtime is setting up the Virtual Kafka Cluster. |
| Healthy | The Virtual Kafka Cluster is running and ready to accept client connections. |
| Deleting | The Virtual Kafka Cluster is being torn down. |
| DeleteFailed | Deletion did not complete successfully — contact support if this persists. |
| Error | Something went wrong during provisioning — check the detail page for more information. |

---

# API Reference

Virtual Kafka Clusters can also be managed programmatically.

### Create a Virtual Kafka Cluster

```bash
curl -X POST https://<streamtime-api-endpoint>/organizations/<your-org-id>/fleet/<your-fleet-id>/kafka/kvc/ \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "my-virtual-kafka-cluster",
    "kafka_id": "my-kafka",
    "provider": "kroxy",
    "kafka_units": 2,
    "advanced_config": {
        "oauth": {
            "client_id": "<client-id>",
            "client_secret": "<client-secret>",
            "issuer": "https://idp.example.com",
            "jwks_endpoint": "https://idp.example.com/.well-known/jwks.json",
            "authorization_uri": "https://idp.example.com/authorize",
            "token_uri": "https://idp.example.com/token",
            "audience": "kafka",
            "scope": "openid"
        }
    }
  }'
```

**Response:**
```json
{
    "identifier": "my-virtual-kafka-cluster",
    "kafka": "my-kafka",
    "provider": "kroxy",
    "status": "Pending",
    "kafka_units": 2,
    "produce_bytes_per_second": 20000000,
    "fetch_bytes_per_second": 20000000,
    "resources": {
        "endpoints": [],
        "client_properties": null
    },
    "created_at": "2026-09-10T04:12:03.000Z",
    "updated_at": "2026-09-10T04:12:03.000Z"
}
```

### List Virtual Kafka Clusters

```bash
curl -H "Authorization: Bearer YOUR_API_TOKEN" \
     https://<streamtime-api-endpoint>/organizations/<your-org-id>/virtual-kafka-clusters/
```

### Get a Virtual Kafka Cluster

```bash
curl -H "Authorization: Bearer YOUR_API_TOKEN" \
     https://<streamtime-api-endpoint>/organizations/<your-org-id>/fleet/<your-fleet-id>/kafka/kvc/<identifier>/
```

### Delete a Virtual Kafka Cluster

```bash
curl -X DELETE -H "Authorization: Bearer YOUR_API_TOKEN" \
     https://<streamtime-api-endpoint>/organizations/<your-org-id>/fleet/<your-fleet-id>/kafka/kvc/<identifier>/
```

---
