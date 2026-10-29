---
title: Kafka Connect
parent: Streaming
grand_parent: Workloads
nav_order: 9
---

# Kafka Connect

A Kafka Connect cluster moves data between a Kafka cluster and other
systems (databases, object storage, search) with connectors. Streamtime
runs the Connect cluster next to its Kafka cluster, installs the connector
plugins you choose, and manages the connectors on it.

## Key Features

- **Strimzi or Confluent Connect**: choose the **Provider** to match the
  Kafka cluster.
- **Your connector plugins**: add plugins from HTTPS ZIP archives; the
  cluster is built with them.
- **Connector lifecycle**: browse plugins and their settings, validate a
  configuration, then create, pause, resume, restart and delete
  connectors.
- **Monitoring**: a dashboard, metrics and logs for the cluster and its
  connectors.

## Settings

**Basic Configuration**: **Identifier** and **Provider** (Strimzi or
Confluent).

**Kafka Cluster Selection**: the **Kafka Cluster** it connects to.

**Advanced Configuration**: the connector plugins to install, each a name,
an HTTPS URL to a ZIP archive and, optionally, its SHA-512 checksum; and
the chart **Version**, to upgrade.

---

{% capture create_section %}
## Create a Connect cluster

{% capture ui %}
1. In the sidebar, select **Kafka Connect**, then **Add Kafka Connect**.
2. **Basic Configuration**: enter the **Identifier** and choose the
   **Provider**.
3. **Kafka Cluster Selection**: choose the **Kafka Cluster**.
4. **Advanced Configuration**: add the connector plugins you need.
5. Create it. It shows **Pending**, then **Provisioning**, then
   **Healthy**.
{% endcapture %}

{% capture curl %}
```bash
# 1. Save it. The response includes "generation".
curl -X POST "$API/kafka-connect/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "cdc",
    "kafka_id": "<kafka-cluster>",
    "provider": "skc",
    "advanced_config": {
      "connector_plugin_zips": [{"name": "<plugin>", "url": "https://example.com/<plugin>.zip"}]
    }
  }'

# 2. Provision it
curl -X POST "$API/kafka-connect/cdc/reconcile/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"generation": 1}'
```

`provider` is `skc` (Strimzi) or `cfk` (Confluent). Send
`"advanced_config": {}` to install the default plugins.
{% endcapture %}
{% capture python %}
```python
import uuid

from streamtime_sdk.api.kafka_connect import organizations_kafka_connect_reconcile_create
from streamtime_sdk.models import ReconcileRequest

resp = client.get_httpx_client().post(
    f"/organizations/{ORG}/kafka-connect/",
    json={
        "identifier": "cdc",
        "kafka_id": "<kafka-cluster>",
        "provider": "skc",
        "advanced_config": {
            "connector_plugin_zips": [{"name": "<plugin>", "url": "https://example.com/<plugin>.zip"}],
        },
    },
)
resp.raise_for_status()

organizations_kafka_connect_reconcile_create.sync(
    ORG,
    "cdc",
    client=client,
    body=ReconcileRequest(generation=resp.json()["generation"]),
    idempotency_key=str(uuid.uuid4()),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsKafkaConnectReconcileCreate } from "./client";

const { data: saved } = await client.post({
  url: "/organizations/{org_identifier}/kafka-connect/",
  path: { org_identifier: org },
  body: {
    identifier: "cdc",
    kafka_id: "<kafka-cluster>",
    provider: "skc",
    advanced_config: {
      connector_plugin_zips: [{ name: "<plugin>", url: "https://example.com/<plugin>.zip" }],
    },
  },
});

await organizationsKafkaConnectReconcileCreate({
  path: { org_identifier: org, identifier: "cdc" },
  headers: { "Idempotency-Key": crypto.randomUUID() },
  body: { generation: (saved as { generation: number }).generation },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/kafka-connect/", map[string]any{
    "identifier": "cdc",
    "kafka_id":   "<kafka-cluster>",
    "provider":   "skc",
    "advanced_config": map[string]any{
        "connector_plugin_zips": []any{
            map[string]any{"name": "<plugin>", "url": "https://example.com/<plugin>.zip"},
        },
    },
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
resp, err = call("POST", "/kafka-connect/cdc/reconcile/",
    map[string]any{"generation": saved.Generation}, newKey())
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="connect-create-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime kafka-connect create --config '{
  "identifier": "cdc",
  "kafka_id": "<kafka-cluster>",
  "provider": "skc",
  "advanced_config": {}
}'
```

The CLI saves the Connect cluster but can't start provisioning it yet.
Start it from the UI, or with the API's reconcile request.
{% comment %}Gap: #1818{% endcomment %}
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Create the Connect cluster from the UI, API or
CLI.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% include tabs.html id="connect-create" ui=ui api=api cli=cli mcp=mcp %}
{% endcapture %}

{% capture extra_section %}
## Manage connectors

Once the Connect cluster is **Healthy**, list the plugins it has, look up
a plugin's settings, validate a configuration, then create the connector.
A connector's `config` is Kafka Connect's own string key/value map.

{% capture ui %}
1. Open the Connect cluster from **Kafka Connect** and select
   **Connectors**.
2. Select **Create Connector**. Enter the **Identifier**, choose the
   **Connector type** (Source or Sink) and the plugin, and fill in the
   form generated from the plugin's settings. Select **Test Connection** to
   validate the configuration before you save it.
3. Open a connector to **Pause Connector**, **Resume Connector**,
   **Restart Connector**, **Update Connector** or delete it. Its **Status
   Snapshot** shows the state of the connector and its tasks.
{% endcapture %}

{% capture curl %}
```bash
C="$API/kafka-connect/cdc"

# Plugins on the cluster, and one plugin's settings
curl -s "$C/connector-plugins/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
curl -s "$C/connector-plugins/<connector-class>/config-schema/" -H "Authorization: Bearer $STREAMTIME_TOKEN"

# Validate, then create
curl -X POST "$C/connectors/validate/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"connector_class": "<connector-class>", "config": {"tasks.max": "1", "topics": "orders"}}'
curl -X POST "$C/connectors/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{
    "identifier": "orders-sink",
    "connector_class": "<connector-class>",
    "plugin_type": "sink",
    "config": {"tasks.max": "1", "topics": "orders"}
  }'

# Status, pause, resume, restart, delete
curl -X POST "$C/connectors/orders-sink/status/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
curl -X POST "$C/connectors/orders-sink/pause/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
curl -X POST "$C/connectors/orders-sink/resume/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
curl -X POST "$C/connectors/orders-sink/restart/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
curl -X DELETE "$C/connectors/orders-sink/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
```

`plugin_type` is `source` or `sink`. Change a connector's `config` with
`PATCH $C/connectors/orders-sink/`.
{% endcapture %}
{% capture python %}
The typed connector model marks server-set fields as required, so create
the connector with the SDK's HTTP client; the other calls are typed:

```python
from streamtime_sdk.api.kafka_connect import (
    kafka_connector_kafka_connector_pause,
    kafka_connector_status,
    organizations_kafka_connect_connector_plugins_retrieve,
    organizations_kafka_connect_connectors_destroy,
)

plugins = organizations_kafka_connect_connector_plugins_retrieve.sync_detailed(ORG, "cdc", client=client)
print(plugins.content.decode())

http = client.get_httpx_client()
http.post(
    f"/organizations/{ORG}/kafka-connect/cdc/connectors/validate/",
    json={"connector_class": "<connector-class>", "config": {"tasks.max": "1", "topics": "orders"}},
).raise_for_status()
http.post(
    f"/organizations/{ORG}/kafka-connect/cdc/connectors/",
    json={
        "identifier": "orders-sink",
        "connector_class": "<connector-class>",
        "plugin_type": "sink",
        "config": {"tasks.max": "1", "topics": "orders"},
    },
).raise_for_status()

kafka_connector_status.sync_detailed(ORG, "cdc", "orders-sink", client=client)
kafka_connector_kafka_connector_pause.sync_detailed(ORG, "cdc", "orders-sink", client=client)
organizations_kafka_connect_connectors_destroy.sync_detailed(ORG, "cdc", "orders-sink", client=client)
```
{% endcapture %}
{% capture typescript %}
```typescript
import {
  kafkaConnectorKafkaConnectorPause,
  kafkaConnectorStatus,
  organizationsKafkaConnectConnectorPluginsRetrieve,
  organizationsKafkaConnectConnectorsDestroy,
} from "./client";

const connector = { org_identifier: org, connect_identifier: "cdc", identifier: "orders-sink" };

const { data: plugins } = await organizationsKafkaConnectConnectorPluginsRetrieve({
  path: { org_identifier: org, connect_identifier: "cdc" },
});
console.log(plugins);

await client.post({
  url: "/organizations/{org_identifier}/kafka-connect/{connect_identifier}/connectors/",
  path: { org_identifier: org, connect_identifier: "cdc" },
  body: {
    identifier: "orders-sink",
    connector_class: "<connector-class>",
    plugin_type: "sink",
    config: { "tasks.max": "1", topics: "orders" },
  },
});

await kafkaConnectorStatus({ path: connector });
await kafkaConnectorKafkaConnectorPause({ path: connector });
await organizationsKafkaConnectConnectorsDestroy({ path: connector });
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("GET", "/kafka-connect/cdc/connector-plugins/", nil)

resp, err = call("POST", "/kafka-connect/cdc/connectors/", map[string]any{
    "identifier":      "orders-sink",
    "connector_class": "<connector-class>",
    "plugin_type":     "sink",
    "config":          map[string]string{"tasks.max": "1", "topics": "orders"},
})

resp, err = call("POST", "/kafka-connect/cdc/connectors/orders-sink/pause/", nil)
resp, err = call("DELETE", "/kafka-connect/cdc/connectors/orders-sink/", nil)
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="connectors-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime kafka-connect connectors plugins list cdc
streamtime kafka-connect connectors schema get cdc <connector-class>

streamtime kafka-connect connectors validate cdc \
  --class <connector-class> \
  --config '{"tasks.max": "1", "topics": "orders"}' --wait

streamtime kafka-connect connectors create cdc --wait --config '{
  "identifier": "orders-sink",
  "connector_class": "<connector-class>",
  "plugin_type": "sink",
  "config": {"tasks.max": "1", "topics": "orders"}
}'

streamtime kafka-connect connectors status cdc orders-sink
streamtime kafka-connect connectors pause cdc orders-sink
streamtime kafka-connect connectors resume cdc orders-sink
streamtime kafka-connect connectors restart cdc orders-sink
streamtime kafka-connect connectors delete cdc orders-sink --yes
```
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Manage connectors from the UI, API or CLI.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% include tabs.html id="connectors" ui=ui api=api cli=cli mcp=mcp %}
{% endcapture %}

{% capture update_note %}
Change the connector plugins, or upgrade to a new **Version**
(`advanced_config.chart_config.main.version`). The cluster is rebuilt
with the new plugins.
{% endcapture %}
{% capture update_body %}{"advanced_config": {"connector_plugin_zips": [{"name": "<plugin>", "url": "https://example.com/<plugin>-2.zip"}]}}{% endcapture %}

{% include workload-tasks.md name="Kafka Connect" id="connect" res="cdc" path="kafka-connect" py_mod="kafka_connect" py_fn="organizations_kafka_connect" ts_fn="organizationsKafkaConnect" menu="Kafka Connect" cli="kafka-connect" cli_gap="1818" update_body=update_body update_note=update_note create_section=create_section extra_section=extra_section shots="kafka-connect" %}
