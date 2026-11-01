---
title: Kafka Replicator
parent: Streaming
grand_parent: Workloads
nav_order: 10
---

# Kafka Replicator

A replicator copies topics, and optionally consumer group offsets, from
one Kafka cluster to another: between two Streamtime clusters, or between
a Streamtime cluster and an external one. Use it for disaster recovery,
migrations, or to bring data closer to its readers.

## Key Features

- **MirrorMaker 2 or Cluster Link**, chosen as the **Provider**.
- **Active-passive or active-active** replication.
- **Choose what to copy**: topic and consumer group allow and deny lists
  (comma-separated names or patterns).
- **Offset translation and checkpoints**, so consumers can fail over.
- **Lag alerts**: an alert fires when replication falls behind by a
  threshold you set, in messages, bytes or seconds.

## Settings

- **Basic Configuration**: **Identifier**, **Provider** (MirrorMaker2 or
  Cluster Link).
- **Source Cluster** and **Destination Cluster**: a Streamtime **Kafka
  Cluster**, or an **External Cluster** with its bootstrap servers,
  security protocol, authentication and the secret holding its
  credentials.
- **Replication Settings**: **Replication Mode**, **Topic Whitelist** /
  **Topic Blacklist**, **Groups Whitelist** / **Groups Blacklist**, and the
  **Lag Alert Threshold** with its unit.
- **Advanced Configuration**: MirrorMaker 2 or Cluster Link tuning, such
  as checkpoints, heartbeats, offset sync topics and producer and consumer
  settings.

---

{% capture create_section %}
## Create a replicator

{% capture ui %}
1. In the sidebar, select **Replicators**, then **Add Replicator**.
2. **Basic Configuration**: enter the **Identifier** and choose the
   **Provider**.
3. **Source Cluster** and **Destination Cluster**: choose a Streamtime
   **Kafka Cluster** for each, or enter an **External Cluster**'s
   connection details.
4. **Replication Settings**: choose the **Replication Mode**, the topics
   and groups to copy, and the **Lag Alert Threshold**.
5. **Advanced Configuration**: tune the replication if you need to, then
   create it. It shows **Pending**, then **Provisioning**, then
   **Healthy**.
{% endcapture %}

{% capture curl %}
```bash
# 1. Save it. The response includes "generation".
curl -X POST "$API/kafka-replicator/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "orders-dr",
    "provider": "MirrorMaker2",
    "source_kafka_id": "<source-cluster>",
    "destination_kafka_id": "<destination-cluster>",
    "replication_mode": "active-passive",
    "topic_whitelist": "orders.*",
    "lag_alert_threshold": 10000,
    "lag_alert_threshold_unit": "messages"
  }'

# 2. Provision it
curl -X POST "$API/kafka-replicator/orders-dr/reconcile/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"generation": 1}'
```

For an external cluster, send `source_connection_details` (or
`destination_connection_details`) and the matching `…_secret_path`
instead of the `…_kafka_id`. `replication_mode` is `active-passive` or
`active-active`; `lag_alert_threshold_unit` is `messages`, `bytes` or
`seconds`.
{% endcapture %}
{% capture python %}
```python
import uuid

from streamtime_sdk.api.kafka_replicator import organizations_kafka_replicator_reconcile_create
from streamtime_sdk.models import ReconcileRequest

resp = client.get_httpx_client().post(
    f"/organizations/{ORG}/kafka-replicator/",
    json={
        "identifier": "orders-dr",
        "provider": "MirrorMaker2",
        "source_kafka_id": "<source-cluster>",
        "destination_kafka_id": "<destination-cluster>",
        "replication_mode": "active-passive",
        "topic_whitelist": "orders.*",
        "lag_alert_threshold": 10000,
        "lag_alert_threshold_unit": "messages",
    },
)
resp.raise_for_status()

organizations_kafka_replicator_reconcile_create.sync(
    ORG,
    "orders-dr",
    client=client,
    body=ReconcileRequest(generation=resp.json()["generation"]),
    idempotency_key=str(uuid.uuid4()),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsKafkaReplicatorReconcileCreate } from "./client";

const { data: saved } = await client.post({
  url: "/organizations/{org_identifier}/kafka-replicator/",
  path: { org_identifier: org },
  body: {
    identifier: "orders-dr",
    provider: "MirrorMaker2",
    source_kafka_id: "<source-cluster>",
    destination_kafka_id: "<destination-cluster>",
    replication_mode: "active-passive",
    topic_whitelist: "orders.*",
    lag_alert_threshold: 10000,
    lag_alert_threshold_unit: "messages",
  },
});

await organizationsKafkaReplicatorReconcileCreate({
  path: { org_identifier: org, identifier: "orders-dr" },
  headers: { "Idempotency-Key": crypto.randomUUID() },
  body: { generation: (saved as { generation: number }).generation },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/kafka-replicator/", map[string]any{
    "identifier":               "orders-dr",
    "provider":                 "MirrorMaker2",
    "source_kafka_id":          "<source-cluster>",
    "destination_kafka_id":     "<destination-cluster>",
    "replication_mode":         "active-passive",
    "topic_whitelist":          "orders.*",
    "lag_alert_threshold":      10000,
    "lag_alert_threshold_unit": "messages",
})
if err != nil {
    return err
}
defer resp.Body.Close()

var saved struct {
    Generation int `json:"generation"`
}
if err := json.NewDecoder(resp.Body).Decode(&saved); err != nil {
    return err
}
resp, err = call("POST", "/kafka-replicator/orders-dr/reconcile/",
    map[string]any{"generation": saved.Generation}, newKey())
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="replicator-create-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime kafka-replicator create --config '{
  "identifier": "orders-dr",
  "provider": "MirrorMaker2",
  "source_kafka_id": "<source-cluster>",
  "destination_kafka_id": "<destination-cluster>",
  "replication_mode": "active-passive",
  "topic_whitelist": "orders.*",
  "lag_alert_threshold": 10000,
  "lag_alert_threshold_unit": "messages"
}'
```

The CLI saves the replicator but can't start provisioning it yet. Start
it from the UI, or with the API's reconcile request.
{% comment %}Gap: #1818{% endcomment %}
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Create the replicator from the UI, API or CLI.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% capture terraform %}
```hcl
resource "streamtime_kafka_replicator" "mirror" {
  identifier               = "east-to-west"
  replicator_provider      = "MirrorMaker2"
  source_kafka_id          = "<source-kafka-cluster>"
  destination_kafka_id     = "<destination-kafka-cluster>"
  source_secret_path       = "builtin:///replicators/east-to-west/source-secret"
  destination_secret_path  = "builtin:///replicators/east-to-west/destination-secret"
  replication_mode         = "active-passive"
  lag_alert_threshold      = 1000
  lag_alert_threshold_unit = "messages"
}
```

`terraform apply` saves the replicator, starts it and waits until it is ready.
Both secret paths are required, and the secrets must already exist.
For a cluster outside Streamtime, leave out its `*_kafka_id` and set
`source_connection_details` or `destination_connection_details`. A later change
is saved with a warning: the running replicator keeps its current settings until
you recreate it (`terraform apply -replace=...`). Import by identifier:
`terraform import streamtime_kafka_replicator.mirror east-to-west`. See
[streamtime_kafka_replicator]({{ site.baseurl }}/terraform/kafka_replicator/).
{% endcapture %}

{% include tabs.html id="replicator-create" ui=ui api=api cli=cli mcp=mcp terraform=terraform %}
{% endcapture %}

{% capture update_note %}
Change the replicated topics or groups, the lag threshold, or the
advanced replication settings. Replication lag shows on the replicator's **Monitoring**
tab, and the lag alert fires when it passes the threshold.
{% endcapture %}
{% capture update_body %}{"topic_whitelist": "orders.*,payments.*", "lag_alert_threshold": 5000}{% endcapture %}

{% include workload-tasks.md name="Kafka Replicator" id="replicator" res="orders-dr" path="kafka-replicator" py_mod="kafka_replicators" py_mod_reconcile="kafka_replicator" py_fn="organizations_kafka_replicator" ts_fn="organizationsKafkaReplicator" menu="Replicators" cli="kafka-replicator" cli_gap="1818" update_body=update_body update_note=update_note create_section=create_section shots="kafka-replicator" %}
