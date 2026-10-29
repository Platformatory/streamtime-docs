{%- comment -%}
  The lifecycle tasks every Kafka cluster page shares, each in UI / API / CLI /
  MCP tabs with HTTP / Python / TypeScript / Go API sub-tabs.

    {% include kafka-cluster-tasks.md workload="strimzi" name="Apache Kafka" id="strimzi" cluster="orders" %}

  Params:
    workload  Kafka provider key sent as `workload` (strimzi, cfk, redpanda, warpstream, automq)
    name      product name as shown on the Cluster Type step
    id        unique, kebab-case prefix for this page's tab ids
    cluster   example cluster identifier used in every snippet
    create_section, status_section, scale_section, upgrade_section
              optional captured markdown (heading and tabs) that replaces
              that task's default section, for providers that differ
    shots     optional folder under assets/images/ holding the UI screenshots.
              Each one shows once its file exists: cluster-type.png,
              cluster-basic-config.png, cluster-fleet-selection.png,
              cluster-advanced-config.png, cluster-list.png,
              cluster-endpoints.png, cluster-detail.png,
              cluster-credentials.png, cluster-upgrade.png,
              cluster-topics.png, cluster-monitoring.png, cluster-delete.png
{%- endcomment -%}
{%- assign w = include.workload -%}
{%- assign n = include.name -%}
{%- assign p = include.id -%}
{%- assign c = include.cluster -%}
{%- assign s = include.shots -%}

## Before you start

- A fleet in **Healthy** state with room for the cluster (see
  [Fleet management]({{ site.baseurl }}/fleet-management/)).
- For the API: an access token in `STREAMTIME_TOKEN` and your organization
  identifier in place of `<org>`. Replace `api.example.com` with your
  Streamtime API address.

{% include api-setup.md id=p %}

---

{% if include.create_section %}{{ include.create_section }}{% else %}
## Create a cluster

{% capture ui %}
1. In the sidebar, select **Clusters**, then **Create cluster**.
2. **Cluster Type**: choose **{{ n }}**, then select **Next**.

   {% include screenshot.html dir=s file="cluster-type.png" alt="Cluster Type step with the Kafka providers to choose from" %}
3. **Basic Configuration**: enter an **Identifier** (lowercase letters,
   digits and dashes, up to 24 characters) and optional **Tags**. Choose the
   **Cloud Provider** and **Region** where the fleet runs, the **Tenancy**
   (Shared, Isolated or Dedicated), **Kafka Units** (cluster capacity) and
   **Retention** (a number of days, or infinite). For Dedicated and Isolated
   clusters, also choose the **Optimization Goal** (Cost, Balanced or
   Performance).

   {% include screenshot.html dir=s file="cluster-basic-config.png" alt="Basic Configuration step with identifier, tenancy and Kafka Units" %}
4. **Fleet Selection**: choose the fleet to run the cluster on.

   {% include screenshot.html dir=s file="cluster-fleet-selection.png" alt="Fleet Selection step listing the fleets that can host the cluster" %}
5. **Advanced Configuration**: review the {{ n }} settings, such as how the
   cluster is reached (internal or external access). Streamtime installs the
   default version; change it later under
   [Upgrade the version](#upgrade-the-version).

   {% include screenshot.html dir=s file="cluster-advanced-config.png" alt="Advanced Configuration step with the provider's settings" %}
6. Review the summary on the right and select **Deploy**.

The cluster appears in the list as **Pending**, then **Provisioning**, then
**Healthy**.

{: .note }
Cluster administrators see only the first two steps; Streamtime picks the
fleet and uses the default advanced configuration.
{% endcapture %}

{% capture curl %}
Creating a cluster takes two requests. The first saves the cluster; the
second starts provisioning it.

```bash
# 1. Save the cluster. The response includes its "generation" (1 for a new cluster).
curl -X POST "$API/kafka/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "{{ c }}",
    "workload": "{{ w }}",
    "kafka_units": 3,
    "tenancy_mode": "Shared",
    "fleet": "<fleet>"
  }'

# 2. Start provisioning that generation.
curl -X POST "$API/kafka/{{ c }}/reconcile/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"generation": 1}'
```

`identifier`, `workload` and `kafka_units` are required, and `fleet` must
be set before provisioning can start. `advanced_config` takes the {{ n }}
settings; list them with `GET $API/kafka/configuration-profiles/{{ w }}/`.

The second request returns `202` with the operation it started. Retrying
with the same `Idempotency-Key` returns that operation again instead of
starting another. A `409` means the generation is out of date (send the
`generation` from `GET $API/kafka/{{ c }}/`) or the cluster has no fleet yet.

The cluster is built in the background. Poll until `status` is `Healthy`
(or `Error`):

```bash
curl -s "$API/kafka/{{ c }}/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
```
{% endcapture %}
{% capture python %}
The typed `KafkaCreate` model can't be used for this request yet, so save
the cluster with the SDK's HTTP client, then start provisioning:

```python
import uuid

from streamtime_sdk.api.kafka import (
    organizations_kafka_reconcile_create,
    organizations_kafka_retrieve,
)
from streamtime_sdk.models import ReconcileRequest

resp = client.get_httpx_client().post(
    f"/organizations/{ORG}/kafka/",
    json={
        "identifier": "{{ c }}",
        "workload": "{{ w }}",
        "kafka_units": 3,
        "tenancy_mode": "Shared",
        "fleet": "<fleet>",
    },
)
resp.raise_for_status()

organizations_kafka_reconcile_create.sync(
    ORG,
    "{{ c }}",
    client=client,
    body=ReconcileRequest(generation=resp.json()["generation"]),
    idempotency_key=str(uuid.uuid4()),
)

cluster = organizations_kafka_retrieve.sync(ORG, "{{ c }}", client=client)
print(cluster.status)  # Pending → Provisioning → Healthy
```
{% endcapture %}
{% capture typescript %}
The generated `KafkaCreate` type marks server-set fields as required, so
send the body through the client directly, then start provisioning:

```typescript
import {
  organizationsKafkaReconcileCreate,
  organizationsKafkaRetrieve,
} from "./client";

const { data: created } = await client.post({
  url: "/organizations/{org_identifier}/kafka/",
  path: { org_identifier: org },
  body: {
    identifier: "{{ c }}",
    workload: "{{ w }}",
    kafka_units: 3,
    tenancy_mode: "Shared",
    fleet: "<fleet>",
  },
});

await organizationsKafkaReconcileCreate({
  path: { org_identifier: org, identifier: "{{ c }}" },
  headers: { "Idempotency-Key": crypto.randomUUID() },
  body: { generation: (created as { generation: number }).generation },
});

const { data } = await organizationsKafkaRetrieve({
  path: { org_identifier: org, identifier: "{{ c }}" },
});
console.log(data?.status);
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/kafka/", map[string]any{
    "identifier":   "{{ c }}",
    "workload":     "{{ w }}",
    "kafka_units":  3,
    "tenancy_mode": "Shared",
    "fleet":        "<fleet>",
})
if err != nil {
    return err
}
defer resp.Body.Close()

var created struct {
    Generation int `json:"generation"`
}
if err := json.NewDecoder(resp.Body).Decode(&created); err != nil {
    return err
}

// Start provisioning that generation.
resp, err = call("POST", "/kafka/{{ c }}/reconcile/",
    map[string]any{"generation": created.Generation}, newKey())
// Then poll: call("GET", "/kafka/{{ c }}/", nil) until "status" is "Healthy".
```
{% endcapture %}
{%- capture tid -%}{{ p }}-create-api{%- endcapture -%}
{% capture api %}{% include code-tabs.html id=tid curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime kafka create \
  --identifier {{ c }} \
  --workload {{ w }} \
  --fleet <fleet> \
  --kafka-units 3 \
  --tenancy-mode Shared
```

Pass {{ n }} settings as JSON with `--advanced-config '{...}'`.

{: .note }
The CLI saves the cluster but can't start provisioning yet. Start it from
the API (step 2 in the API tab) or from the cluster's page in the UI.
{% endcapture %}

{% capture mcp %}
Ask your assistant, for example: *"Create a {{ n }} cluster called {{ c }}
with 3 Kafka units on the &lt;fleet&gt; fleet."*

It uses the `create_kafka_cluster` tool (`workload` is `{{ w }}`), which
picks a fleet when you don't name one. Use `list_kafka_providers` to see
the providers your organization can use.

{: .note }
The assistant saves the cluster but can't start provisioning yet. Start it
from the API (step 2 in the API tab) or from the cluster's page in the UI.
{% endcapture %}

{%- capture tid -%}{{ p }}-create{%- endcapture -%}
{% include tabs.html id=tid ui=ui api=api cli=cli mcp=mcp %}
{% endif %}

---

{% if include.status_section %}{{ include.status_section }}{% else %}
## Check status and connection details

{% capture ui %}
1. In **Clusters**, find the cluster. The list shows its **Status**.

   {% include screenshot.html dir=s file="cluster-list.png" alt="Clusters list showing each cluster's status" %}
2. Select **Show Endpoints** to see the addresses clients connect to.

   {% include screenshot.html dir=s file="cluster-endpoints.png" alt="Endpoints dialog with the cluster's connection addresses" %}
3. Open the cluster. **Overview** shows the status, Kafka Units and fleet.

   {% include screenshot.html dir=s file="cluster-detail.png" alt="Cluster overview with status, Kafka Units and fleet" %}
4. To create a user for client applications, select **Manage Credentials**.

   {% include screenshot.html dir=s file="cluster-credentials.png" alt="Manage Credentials dialog" %}
{% endcapture %}

{% capture curl %}
```bash
# Status, plus the bootstrap servers and listeners under "spec"
curl -s "$API/kafka/{{ c }}/" -H "Authorization: Bearer $STREAMTIME_TOKEN"

# Last reported cluster status
curl -s "$API/kafka/{{ c }}/status/" -H "Authorization: Bearer $STREAMTIME_TOKEN"

# Client credentials: list, then create one
curl -s "$API/kafka/{{ c }}/credentials/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
curl -X POST "$API/kafka/{{ c }}/credentials/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"credential_type": "KAFKA", "username": "orders-app"}'
```

`credential_type` is `KAFKA` for client applications.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.kafka import organizations_kafka_retrieve
from streamtime_sdk.api.kafka_monitoring import organizations_kafka_status_retrieve

cluster = organizations_kafka_retrieve.sync(ORG, "{{ c }}", client=client)
print(cluster.status, cluster.spec)

status = organizations_kafka_status_retrieve.sync_detailed(ORG, "{{ c }}", client=client)
print(status.content)
```
{% endcapture %}
{% capture typescript %}
```typescript
import {
  organizationsKafkaRetrieve,
  organizationsKafkaStatusRetrieve,
} from "./client";

const { data: cluster } = await organizationsKafkaRetrieve({
  path: { org_identifier: org, identifier: "{{ c }}" },
});
const { data: status } = await organizationsKafkaStatusRetrieve({
  path: { org_identifier: org, kafka_id: "{{ c }}" },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("GET", "/kafka/{{ c }}/", nil)        // status and spec
resp, err = call("GET", "/kafka/{{ c }}/status/", nil)  // last reported status
```
{% endcapture %}
{%- capture tid -%}{{ p }}-status-api{%- endcapture -%}
{% capture api %}{% include code-tabs.html id=tid curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime kafka get {{ c }}
streamtime kafka status {{ c }}
streamtime kafka credentials {{ c }}
```

Creating credentials from the CLI isn't available yet. Use the UI or API.
{% endcapture %}

{% capture mcp %}
Ask, for example: *"What is the status of the {{ c }} cluster?"* The
assistant uses `get_cluster_status`. MCP doesn't create credentials.
{% endcapture %}

{%- capture tid -%}{{ p }}-status{%- endcapture -%}
{% include tabs.html id=tid ui=ui api=api cli=cli mcp=mcp %}
{% endif %}

---

{% if include.scale_section %}{{ include.scale_section }}{% else %}
## Scale or change the configuration

Changing **Kafka Units** or advanced settings updates the running cluster in
place. The status shows **Provisioning** until the change is applied.

{% capture ui %}
Changing Kafka Units isn't available in the UI yet. Use the API or CLI.
{% endcapture %}

{% capture curl %}
As with create, saving the change and applying it are two requests:

```bash
# 1. Save the change. The response has the new "generation".
curl -X PATCH "$API/kafka/{{ c }}/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"kafka_units": 6}'

# 2. Apply that generation.
curl -X POST "$API/kafka/{{ c }}/reconcile/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"generation": <generation>}'
```

Send only the fields you change. Poll the cluster until it is `Healthy` again.
{% endcapture %}
{% capture python %}
```python
import uuid

from streamtime_sdk.api.kafka import (
    organizations_kafka_partial_update,
    organizations_kafka_reconcile_create,
)
from streamtime_sdk.models import PatchedKafka, ReconcileRequest

cluster = organizations_kafka_partial_update.sync(
    ORG, "{{ c }}", client=client, body=PatchedKafka(kafka_units=6)
)
organizations_kafka_reconcile_create.sync(
    ORG,
    "{{ c }}",
    client=client,
    body=ReconcileRequest(generation=cluster.generation),
    idempotency_key=str(uuid.uuid4()),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import {
  organizationsKafkaPartialUpdate,
  organizationsKafkaReconcileCreate,
} from "./client";

const path = { org_identifier: org, identifier: "{{ c }}" };
const { data: cluster } = await organizationsKafkaPartialUpdate({
  path,
  body: { kafka_units: 6 },
});
await organizationsKafkaReconcileCreate({
  path,
  headers: { "Idempotency-Key": crypto.randomUUID() },
  body: { generation: cluster!.generation },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("PATCH", "/kafka/{{ c }}/", map[string]any{"kafka_units": 6})
if err != nil {
    return err
}
defer resp.Body.Close()

var updated struct {
    Generation int `json:"generation"`
}
if err := json.NewDecoder(resp.Body).Decode(&updated); err != nil {
    return err
}

// Apply that generation.
resp, err = call("POST", "/kafka/{{ c }}/reconcile/",
    map[string]any{"generation": updated.Generation}, newKey())
```
{% endcapture %}
{%- capture tid -%}{{ p }}-scale-api{%- endcapture -%}
{% capture api %}{% include code-tabs.html id=tid curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime kafka update {{ c }} --kafka-units 6
```

Change advanced settings with `--advanced-config '{...}'`.

{: .note }
The CLI saves the change but can't apply it yet. Apply it from the API
(step 2 in the API tab).
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. MCP can check the result: *"Is the {{ c }}
cluster healthy?"*
{% endcapture %}

{%- capture tid -%}{{ p }}-scale{%- endcapture -%}
{% include tabs.html id=tid ui=ui api=api cli=cli mcp=mcp %}
{% endif %}

---

{% if include.upgrade_section %}{{ include.upgrade_section }}{% else %}
## Upgrade the version

{% capture ui %}
1. Open the cluster and select the **Manage** tab.
2. Find the {{ n }} release and select **Upgrade version**.
3. Choose the new **Version** and confirm.

   {% include screenshot.html dir=s file="cluster-upgrade.png" alt="Upgrade version dialog with the available versions" %}

The cluster shows **Upgrading**, then **Healthy**.
{% endcapture %}

{% capture curl %}
```bash
curl -X POST "$API/kafka/{{ c }}/packages/update/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"component_key": "main", "chart_version": "<version>"}'
```

`chart_version` is the new version. Poll the cluster until it is `Healthy`.
{% endcapture %}
{% capture python %}
```python
resp = client.get_httpx_client().post(
    f"/organizations/{ORG}/kafka/{{ c }}/packages/update/",
    json={"component_key": "main", "chart_version": "<version>"},
)
resp.raise_for_status()
```
{% endcapture %}
{% capture typescript %}
```typescript
await client.post({
  url: "/organizations/{org_identifier}/kafka/{identifier}/packages/update/",
  path: { org_identifier: org, identifier: "{{ c }}" },
  body: { component_key: "main", chart_version: "<version>" },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/kafka/{{ c }}/packages/update/", map[string]any{
    "component_key": "main",
    "chart_version": "<version>",
})
```
{% endcapture %}
{%- capture tid -%}{{ p }}-upgrade-api{%- endcapture -%}
{% capture api %}{% include code-tabs.html id=tid curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet. Use the UI or API.
{% endcapture %}

{% capture mcp %}
Not available in MCP yet.
{% endcapture %}

{%- capture tid -%}{{ p }}-upgrade{%- endcapture -%}
{% include tabs.html id=tid ui=ui api=api cli=cli mcp=mcp %}
{% endif %}

---

## Manage topics

{% capture ui %}
1. Open the cluster and select **Manage Topics**.
2. To add a topic, select **Create topic**, enter the name, partitions and
   replication factor, and confirm.
3. To remove one, select **Delete topic** and type the topic name to
   confirm. This deletes the topic's data.

{% include screenshot.html dir=s file="cluster-topics.png" alt="Manage Topics page listing the cluster's topics" %}
{% endcapture %}

{% capture curl %}
```bash
# List (supports ?search=, ?page=, ?page_size=)
curl -s "$API/kafka/{{ c }}/topics/" -H "Authorization: Bearer $STREAMTIME_TOKEN"

# Create
curl -X POST "$API/kafka/{{ c }}/topics/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"name": "payments", "partitions": 6, "replication_factor": 3,
       "configs": {"retention.ms": "604800000"}}'

# Add partitions or change settings (partitions can only increase)
curl -X PATCH "$API/kafka/{{ c }}/topics/payments/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"partitions": 12, "configs": {"set": {"retention.ms": "86400000"}}}'

# Delete: repeat the topic name to confirm
curl -X DELETE "$API/kafka/{{ c }}/topics/payments/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"name": "payments"}'
```
{% endcapture %}
{% capture python %}
```python
http = client.get_httpx_client()
base = f"/organizations/{ORG}/kafka/{{ c }}/topics/"

http.post(base, json={"name": "payments", "partitions": 6, "replication_factor": 3})
print(http.get(base).json())
http.request("DELETE", base + "payments/", json={"name": "payments"})
```
{% endcapture %}
{% capture typescript %}
```typescript
import { createKafkaTopic, listKafkaTopics } from "./client";

const path = { org_identifier: org, kafka_id: "{{ c }}" };
await createKafkaTopic({
  path,
  body: { name: "payments", partitions: 6, replication_factor: 3 },
});
const { data } = await listKafkaTopics({ path });
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/kafka/{{ c }}/topics/", map[string]any{
    "name": "payments", "partitions": 6, "replication_factor": 3,
})
resp, err = call("DELETE", "/kafka/{{ c }}/topics/payments/",
    map[string]any{"name": "payments"})
```
{% endcapture %}
{%- capture tid -%}{{ p }}-topics-api{%- endcapture -%}
{% capture api %}{% include code-tabs.html id=tid curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet. Use the UI or API.
{% endcapture %}

{% capture mcp %}
MCP reads topic settings; it doesn't change them. Ask, for example:
*"What is the retention of the payments topic on {{ c }}?"* (uses
`get_topic_configuration`).
{% endcapture %}

{%- capture tid -%}{{ p }}-topics{%- endcapture -%}
{% include tabs.html id=tid ui=ui api=api cli=cli mcp=mcp %}

---

## View metrics, logs and alerts

{% capture ui %}
Open the cluster and select the **Monitoring** tab for throughput, broker
health, logs and alerts.

{% include screenshot.html dir=s file="cluster-monitoring.png" alt="Monitoring tab with throughput and broker health charts" %}
{% endcapture %}

{% capture curl %}
```bash
curl -s "$API/kafka/{{ c }}/metrics/overview/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
curl -s "$API/kafka/{{ c }}/logs/"             -H "Authorization: Bearer $STREAMTIME_TOKEN"
curl -s "$API/kafka/{{ c }}/firing-alerts/"    -H "Authorization: Bearer $STREAMTIME_TOKEN"
```
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.kafka_monitoring import (
    organizations_kafka_firing_alerts_retrieve,
    organizations_kafka_logs_retrieve,
    organizations_kafka_metrics_overview_retrieve,
)

for op in (
    organizations_kafka_metrics_overview_retrieve,
    organizations_kafka_logs_retrieve,
    organizations_kafka_firing_alerts_retrieve,
):
    print(op.sync_detailed(ORG, "{{ c }}", client=client).content)
```
{% endcapture %}
{% capture typescript %}
```typescript
import {
  organizationsKafkaFiringAlertsRetrieve,
  organizationsKafkaLogsRetrieve,
  organizationsKafkaMetricsOverviewRetrieve,
} from "./client";

const path = { org_identifier: org, kafka_id: "{{ c }}" };
const metrics = await organizationsKafkaMetricsOverviewRetrieve({ path });
const logs = await organizationsKafkaLogsRetrieve({ path });
const alerts = await organizationsKafkaFiringAlertsRetrieve({ path });
```
{% endcapture %}
{% capture go %}
```go
for _, p := range []string{"metrics/overview/", "logs/", "firing-alerts/"} {
    resp, err := call("GET", "/kafka/{{ c }}/"+p, nil)
    // ...
}
```
{% endcapture %}
{%- capture tid -%}{{ p }}-monitor-api{%- endcapture -%}
{% capture api %}{% include code-tabs.html id=tid curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime kafka metrics {{ c }}
streamtime kafka logs {{ c }}
```

Alerts aren't available in the CLI yet.
{% endcapture %}

{% capture mcp %}
Ask, for example: *"Show me errors in the {{ c }} logs from the last hour"*
or *"Are any alerts firing on {{ c }}?"* The assistant uses
`get_cluster_metric`, `get_cluster_logs` and `get_cluster_alerts`
(`list_cluster_metrics` lists what can be queried).
{% endcapture %}

{%- capture tid -%}{{ p }}-monitor{%- endcapture -%}
{% include tabs.html id=tid ui=ui api=api cli=cli mcp=mcp %}

---

## Delete the cluster

{: .warning }
Deleting a cluster removes its brokers and all topic data. It can't be undone.

{% capture ui %}
1. In **Clusters**, find the cluster and select **Delete**.
2. Confirm.

   {% include screenshot.html dir=s file="cluster-delete.png" alt="Delete confirmation dialog" %}

The cluster shows **Deleting** and then leaves the list.
{% endcapture %}

{% capture curl %}
```bash
curl -X DELETE "$API/kafka/{{ c }}/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
```

Returns `202` with the delete operation; the cluster shows `Deleting`
while its resources are removed, then `GET $API/kafka/{{ c }}/` returns
`404`. A cluster that was never provisioned is removed at once.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.kafka import organizations_kafka_destroy

organizations_kafka_destroy.sync_detailed(ORG, "{{ c }}", client=client)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsKafkaDestroy } from "./client";

await organizationsKafkaDestroy({
  path: { org_identifier: org, identifier: "{{ c }}" },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("DELETE", "/kafka/{{ c }}/", nil)
```
{% endcapture %}
{%- capture tid -%}{{ p }}-delete-api{%- endcapture -%}
{% capture api %}{% include code-tabs.html id=tid curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime kafka delete {{ c }}
```

Add `--yes` to skip the confirmation prompt.
{% endcapture %}

{% capture mcp %}
Not available in MCP.
{% endcapture %}

{%- capture tid -%}{{ p }}-delete{%- endcapture -%}
{% include tabs.html id=tid ui=ui api=api cli=cli mcp=mcp %}
