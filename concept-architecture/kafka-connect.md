---
title: Kafka Connect
nav_order: 7
parent: Concepts & Architecture
## Video Tutorial: Creating a Kafka Connect Cluster and Connector

<video class="video-js vjs-theme-city" controls preload="auto" width="640" height="264" data-setup='{}'>
    <source src="{{ '/assets/videos/kafka-connect.webm' | relative_url }}" type="video/webm">
  Your browser does not support the video tag.
</video>

<style>
    video {
        width: 100%;
        height: auto;
    }
</style>

<link
  href="https://unpkg.com/video.js@7/dist/video-js.min.css"
  rel="stylesheet"
/>
<link
  href="https://unpkg.com/@videojs/themes@1/dist/city/index.css"
  rel="stylesheet"
/>

---

# Kafka Connect

**Kafka Connect** lets you move data in and out of your Kafka cluster without writing custom producer/consumer code. You deploy a Kafka Connect cluster alongside one of your Kafka clusters, then create individual **Connectors** on it — each Connector either streams data from an external system into Kafka (a **source** connector, e.g. capturing changes from a database) or streams data from Kafka out to an external system (a **sink** connector, e.g. writing to a data warehouse or object storage).

Streamtime manages the Kafka Connect cluster's lifecycle for you and gives every Connector a guided, schema-driven configuration form — so you only ever see the settings that are actually relevant to the connector type you picked.

## Why Use Kafka Connect

- **No custom integration code** — stand up a battle-tested integration in minutes using a pre-built connector, instead of writing and operating your own producer or consumer application.
- **Guided configuration** — the configuration form for each connector type is generated from that connector's own definition, so required fields, defaults, and descriptions are always accurate and specific to what you picked.
- **Centrally managed** — restart, pause, resume, reconfigure, or delete a connector at any time from the Streamtime UI, with live status.
- **Bring your own connector** — in addition to the connector types available by default (including Debezium change-data-capture connectors and the JDBC connector), you can add any other Kafka Connect–compatible connector plugin.

---

## Before You Start: Container Registry

Kafka Connect clusters are built with your chosen connector plugins baked in, so Streamtime needs somewhere to store the images it builds for you. Before creating your first Kafka Connect cluster, configure a **Container Registry** under **Settings → Container Registry**:

- Registry URL (host and optional port)
- Username and password/token (optional — leave blank for an unauthenticated registry)
- Destination namespace (optional — needed for registries that require pushing under an owned namespace)

![Container Registry Settings]({{ site.baseurl }}/assets/images/kafka-connect/container-registry.png)

You only need to do this once per organization; every Kafka Connect cluster you create afterward reuses it.

---

## Creating a Kafka Connect Cluster

Creating a Kafka Connect cluster is a guided 3-step process.

### 1. Basic Configuration

- **Identifier** — a unique name for this Kafka Connect cluster.
- **Provider** — the Kafka Connect distribution to deploy. Today there is a single supported option, pre-selected for you.

![Basic Configuration]({{ site.baseurl }}/assets/images/kafka-connect/create-step-1.png)

### 2. Kafka Cluster Selection

- **Kafka Cluster** — the Kafka cluster this Kafka Connect cluster will read from and write to. Streamtime automatically sets up secure, certificate-based authentication between them — no manual credential configuration needed.

![Kafka Cluster Selection]({{ site.baseurl }}/assets/images/kafka-connect/create-step-2.png)

### 3. Advanced Configuration

- **Software Version** — optionally pin the version of the Kafka Connect software deployed. Most users can leave this on the recommended default.
- **Connector Plugins** — Debezium and JDBC connector types are available by default. To add a different or additional connector type, expand **"Show advanced connector plugin options"** and provide:
  - **Name** — a short name for the plugin.
  - **URL** — a direct HTTPS link to the connector plugin's `.zip` archive.
  - **Checksum** (optional) — a SHA-512 checksum to verify the downloaded plugin.
- **API Authentication** — choose **Basic Auth** or **OAuth2** to protect this Kafka Connect cluster's management endpoint. If you choose OAuth2, select the identity provider to use.

![Advanced Configuration]({{ site.baseurl }}/assets/images/kafka-connect/create-step-3.png)

Once you click **Create**, Streamtime builds and deploys the Kafka Connect cluster in the background. Its status moves from `Pending` → `Provisioning` → `Healthy`.

---

## The Kafka Connect Cluster Page

Once created, a Kafka Connect cluster has three tabs:

- **Overview** — identifier, provider, status, and creation date; a link back to the Kafka cluster it's attached to; and its **Endpoints** (the management endpoint's URL and DNS record, with a one-click copy button).
- **Monitoring** — a link to open this Kafka Connect cluster's dashboards, if configured.
- **Connectors** — the list of Connectors running on this cluster (see below).

![Kafka Connect Cluster Overview]({{ site.baseurl }}/assets/images/kafka-connect/cluster-overview.png)

---

## Creating a Connector

From the **Connectors** tab, click **+ Create Connector**.

1. **Identifier** — a unique name for this connector (lowercase letters, numbers, `-` and `_`, up to 24 characters).
2. **Connector type** — choose from the list of available connector types, grouped by **Source** and **Sink**. This list is kept up to date automatically in the background.
3. **Configuration** — once you pick a connector type, Streamtime automatically fetches and displays the exact configuration fields for that connector — required fields, optional fields, defaults, and helpful descriptions all come directly from the connector itself, so this section always matches what you selected.

![Creating a Connector]({{ site.baseurl }}/assets/images/kafka-connect/connector-create.png)

Before creating, you can click **Test Connection** to validate your configuration without creating the connector yet. When you're ready, click **Create** — you'll see a confirmation and be returned to the Connectors list, where the new connector's status will move from `Provisioning` to `Running` automatically.

![Connectors List]({{ site.baseurl }}/assets/images/kafka-connect/connectors-list.png)

---

## Managing a Connector

Each connector's detail page shows:

- **Status Snapshot** — the connector's live state (including the state of each of its tasks), refreshed automatically.
- **Configuration** — the connector's current settings, with an **Edit** option to update them using the same guided form used at creation.

![Connector Detail]({{ site.baseurl }}/assets/images/kafka-connect/connector-detail.png)

Available actions:

| Action | What it does |
| --- | --- |
| Refresh status | Immediately re-checks the connector's live status. |
| Restart | Restarts the connector. |
| Pause / Resume | Temporarily stops or resumes data flow without deleting the connector. |
| Delete | Permanently removes the connector. |

### Connector Status

| Status | Meaning |
| --- | --- |
| Pending | The connector has been requested and is queued. |
| Provisioning | The connector is being created. |
| Running | The connector is active and processing data. |
| Paused | The connector is temporarily stopped. |
| Failed | The connector has encountered an error — check its Status Snapshot for details. |
| Deleting | The connector is being removed. |

---

## Troubleshooting

- **Kafka Connect cluster stuck in `Provisioning`** — connector plugins are baked into a container image and pushed to your configured Container Registry. If the registry isn't configured, or its credentials are wrong, the build can't complete. Check **Settings → Container Registry** and confirm the registry is reachable.
- **Connector stuck in `Failed`** — open the connector's detail page and check its **Status Snapshot**; it surfaces the underlying error reported by Kafka Connect itself (e.g. a missing required field, an unreachable external system, or a bad connector class).
- **"Test Connection" or create fails with a config validation error** — the error lists the specific fields Kafka Connect rejected. A common cause is submitting mutually exclusive fields for the same connector type (e.g. both an include list and an exclude list) — leave the ones you don't need blank rather than empty strings.
- **A connector type you expect isn't in the list** — the available connector/plugin list is cached and refreshed periodically. If you just added a custom plugin, use the refresh action on the connector type step, or wait for the next automatic refresh.

---

# API Reference

### Create a Kafka Connect Cluster

```bash
curl -X POST https://<streamtime-api-endpoint>/organizations/<your-org-id>/kafka-connects/ \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "my-kafka-connect",
    "provider": "skc",
    "kafka_id": "my-kafka",
    "advanced_config": {
        "authentication": "Basic Auth"
    }
  }'
```

### Create a Connector

```bash
curl -X POST https://<streamtime-api-endpoint>/organizations/<your-org-id>/kafka-connects/<connect-id>/connectors/ \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "pg-orders-source",
    "connector_class": "io.debezium.connector.postgresql.PostgresConnector",
    "config": {
        "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
        "database.hostname": "db.example.com",
        "database.user": "debezium",
        "database.password": "<password>",
        "database.dbname": "orders",
        "topic.prefix": "orders"
    }
  }'
```

**Response:**
```json
{
    "identifier": "pg-orders-source",
    "connector_class": "io.debezium.connector.postgresql.PostgresConnector",
    "plugin_type": "source",
    "status": "Provisioning",
    "config": {
        "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
        "database.hostname": "db.example.com",
        "database.dbname": "orders",
        "topic.prefix": "orders"
    },
    "connect_status": null,
    "created_at": "2026-09-10T04:12:03.000Z",
    "updated_at": "2026-09-10T04:12:03.000Z"
}
```

### Validate a Connector Configuration

Corresponds to the **Test Connection** action in the UI — validates a connector configuration against the Kafka Connect cluster without creating the connector.

```bash
curl -X POST https://<streamtime-api-endpoint>/organizations/<your-org-id>/kafka-connects/<connect-id>/connectors/validate/ \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "connector_class": "io.debezium.connector.postgresql.PostgresConnector",
    "config": {
        "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
        "database.hostname": "db.example.com",
        "database.user": "debezium",
        "database.password": "<password>",
        "database.dbname": "orders",
        "topic.prefix": "orders"
    }
  }'
```

**Response:**
```json
{
    "workflow_id": "kafka-connector-validate-pg-orders-source-..."
}
```

The validation runs asynchronously — poll the returned operation's status to see whether the configuration passed.

### List Connectors

```bash
curl -H "Authorization: Bearer YOUR_API_TOKEN" \
     https://<streamtime-api-endpoint>/organizations/<your-org-id>/kafka-connects/<connect-id>/connectors/
```

### Restart / Pause / Resume a Connector

```bash
curl -X POST -H "Authorization: Bearer YOUR_API_TOKEN" \
     https://<streamtime-api-endpoint>/organizations/<your-org-id>/kafka-connects/<connect-id>/connectors/<identifier>/restart/
```

Replace `restart` with `pause` or `resume` for the other actions.

### Delete a Connector

```bash
curl -X DELETE -H "Authorization: Bearer YOUR_API_TOKEN" \
     https://<streamtime-api-endpoint>/organizations/<your-org-id>/kafka-connects/<connect-id>/connectors/<identifier>/
```

---
