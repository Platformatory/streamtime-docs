---
title: ClickHouse
parent: Real-time Analytics
grand_parent: Workloads
nav_order: 1
---

# ClickHouse

Streamtime runs ClickHouse, the columnar analytics database, on a
Kubernetes fleet (the Altinity distribution) and keeps it monitored and
up to date. You choose how much data it ingests and how long it keeps it;
Streamtime sizes the storage from that.

## Key Features

- **Sized from your data**: storage follows the expected ingestion rate,
  the retention period and the number of shards.
- **Shards and replicas**: scale out with more shards, and add replicas
  per shard for availability.
- **Tenancy**: Shared, Isolated or Dedicated fleets.
- **Monitoring and alerts**: metrics, logs and alert rules for every
  cluster.

## Settings

**Basic Configuration**

- **Identifier**: lowercase letters, digits, `-` and `_`, up to 24
  characters.
- **ClickHouse Provider**: Altinity.
- **Retention Days**: how long ingested data is kept before it ages out.
- **Expected Ingestion Rate**: sustained writes in MB/s (default 10), used
  to size storage.

**Fleet Selection**: the **Target Kubernetes Fleet**. The cloud, tenancy
and region you choose only narrow the list.

**Advanced Configuration**

- **Shards** (default 1) and **Replicas per shard** (default 1).
- **Resources**: CPU and memory requests and limits per ClickHouse host.
- Users, profiles and server settings, passed to ClickHouse as they are.
- The chart **Version**, to upgrade (see below).

---

{% capture create_section %}
## Create a ClickHouse cluster

{% capture ui %}
1. In the sidebar, select **ClickHouse**, then **Create ClickHouse**.
2. **Basic Configuration**: enter the **Identifier**, choose the
   **ClickHouse Provider**, and set the **Retention Days** and **Expected
   Ingestion Rate**.
3. **Fleet Selection**: choose the **Target Kubernetes Fleet**.
4. **Advanced Configuration**: set the **Shards** and **Replicas per
   shard**, and the resources if you need to. The **Estimated Additional
   Monthly Cost** updates as you go.
5. Create it. It shows **Pending**, then **Provisioning**, then
   **Healthy**.

{% include screenshot.html dir="clickhouse" file="create.png" alt="ClickHouse Advanced Configuration step with shards and replicas" %}
{% endcapture %}

{% capture curl %}
```bash
# 1. Save it. The response includes "generation" and "configuration_state".
curl -X POST "$API/clickhouses/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "events",
    "provider": "altinity",
    "fleet": "<fleet>",
    "retention_days": 30,
    "advanced_configuration": {"shards": 1, "replicas": 2, "ingestion_rate_mb_per_sec": 10}
  }'

# 2. Provision it
curl -X POST "$API/clickhouses/events/reconcile/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"generation": 1}'
```

Only `identifier` is required to save a draft; it can be provisioned once
`configuration_state` is `valid` (a fleet is set).
{% endcapture %}
{% capture python %}
```python
import uuid

from streamtime_sdk.api.click_house import organizations_clickhouses_reconcile_create
from streamtime_sdk.models import ReconcileRequest

resp = client.get_httpx_client().post(
    f"/organizations/{ORG}/clickhouses/",
    json={
        "identifier": "events",
        "provider": "altinity",
        "fleet": "<fleet>",
        "retention_days": 30,
        "advanced_configuration": {"shards": 1, "replicas": 2, "ingestion_rate_mb_per_sec": 10},
    },
)
resp.raise_for_status()

organizations_clickhouses_reconcile_create.sync(
    ORG,
    "events",
    client=client,
    body=ReconcileRequest(generation=resp.json()["generation"]),
    idempotency_key=str(uuid.uuid4()),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsClickhousesCreate, organizationsClickhousesReconcileCreate } from "./client";

const { data: saved } = await organizationsClickhousesCreate({
  path: { org_identifier: org },
  body: {
    identifier: "events",
    provider: "altinity",
    fleet: "<fleet>",
    retention_days: 30,
    advanced_configuration: { shards: 1, replicas: 2, ingestion_rate_mb_per_sec: 10 },
  },
});

await organizationsClickhousesReconcileCreate({
  path: { org_identifier: org, identifier: "events" },
  headers: { "Idempotency-Key": crypto.randomUUID() },
  body: { generation: saved!.generation },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/clickhouses/", map[string]any{
    "identifier":     "events",
    "provider":       "altinity",
    "fleet":          "<fleet>",
    "retention_days": 30,
    "advanced_configuration": map[string]any{
        "shards": 1, "replicas": 2, "ingestion_rate_mb_per_sec": 10,
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
resp, err = call("POST", "/clickhouses/events/reconcile/",
    map[string]any{"generation": saved.Generation}, newKey())
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="ch-create-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime clickhouse create \
  --identifier events \
  --fleet <fleet> \
  --shards 1 --replicas 2 \
  --retention-days 30
```

The command also starts provisioning once the settings are complete;
otherwise run `streamtime clickhouse reconcile events` when they are.
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Create the cluster from the UI, API or CLI.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% capture terraform %}
```hcl
resource "streamtime_clickhouse" "events" {
  identifier     = "events"
  fleet          = "<fleet>"
  retention_days = 30

  advanced_configuration = jsonencode({
    shards   = 1
    replicas = 2
  })
}
```

`terraform apply` saves the cluster, starts provisioning it and waits until it
is ready, the same two steps as the API. To manage an existing cluster, import
it by identifier: `terraform import streamtime_clickhouse.events events`. See
[streamtime_clickhouse]({{ site.baseurl }}/terraform/clickhouse/).
{% endcapture %}

{% include tabs.html id="ch-create" ui=ui api=api cli=cli mcp=mcp terraform=terraform %}
{% endcapture %}

{% capture update_note %}
Add shards or replicas, change the resources or the retention, or upgrade
to a new **Version** (`advanced_configuration.chart_config.main.version`).
Send the whole `advanced_configuration`, not just the keys you change.
{% endcapture %}
{% capture update_body %}{"advanced_configuration": {"shards": 2, "replicas": 2, "ingestion_rate_mb_per_sec": 10}}{% endcapture %}
{% capture mcp_status %}
Ask your assistant, for example: *"List my ClickHouse clusters"* or *"Is
the events ClickHouse cluster healthy?"*

It uses `list_clickhouses` and `get_clickhouse`.
{% endcapture %}

{% capture tf_update %}
Change the attributes in the `streamtime_clickhouse` block, for example
`retention_days` or the shards and replicas in `advanced_configuration`, and
run `terraform apply`. The plan shows an in-place update; Terraform saves the
change, applies it and waits until the cluster runs it. Changing `identifier`
or `fleet` replaces the cluster, and its data.
{% endcapture %}
{% capture tf_delete %}
Remove the `streamtime_clickhouse` block and run `terraform apply`, or run
`terraform destroy -target=streamtime_clickhouse.events`. Terraform waits until
Streamtime has removed the cluster.
{% endcapture %}

{% include workload-tasks.md name="ClickHouse" id="ch" res="events" path="clickhouses" py_mod="click_house" py_fn="organizations_clickhouses" ts_fn="organizationsClickhouses" menu="ClickHouse" cli="clickhouse" cli_reconcile="yes" has_status="yes" update_body=update_body update_note=update_note mcp_status=mcp_status create_section=create_section shots="clickhouse" tf_update=tf_update tf_delete=tf_delete %}
