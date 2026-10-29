---
title: Virtual Kafka Clusters
parent: Streaming
grand_parent: Workloads
nav_order: 11
---

# Virtual Kafka Clusters

A virtual Kafka cluster gives a team its own Kafka endpoint on top of a
shared Kafka cluster. It claims part of the backing cluster's capacity, in
Kafka Units, and enforces produce and fetch limits for it. Clients use it
like any Kafka cluster.

## Key Features

- **Many teams, one Kafka cluster**: each virtual cluster has its own
  endpoint and its own share of the capacity.
- **Capacity in Kafka Units**: the virtual clusters on a Kafka cluster
  together can't claim more than its **Cluster Capacity (Kafka Units)**.
- **Produce and fetch limits** follow the capacity it claims.
- **OAuth sign-in** for clients, with your identity provider's issuer,
  audience and keys.

## Settings

- **Basic Configuration**: **Identifier** and **Provider**.
- **Kafka Cluster Selection**: the backing **Kafka Cluster**, and the
  **Capacity Allocation (Kafka Units)** to claim from it.
- **Advanced Configuration**: client authentication (the OAuth
  **Issuer**, **Audience**, **JWKS Endpoint**, **Authorization URI**,
  **Token URI** and **Scope**).

A virtual cluster belongs to the fleet of its Kafka cluster, so the API
addresses it under that fleet: `$API/fleet/<fleet>/kafka/kvc/`.

---

{% capture create_section %}
## Create a virtual cluster

{% capture ui %}
1. In the sidebar, select **Virtual Kafka**, then **Add Virtual Kafka
   Cluster**.
2. **Basic Configuration**: enter the **Identifier** and choose the
   **Provider**.
3. **Kafka Cluster Selection**: choose the **Kafka Cluster** and set the
   **Capacity Allocation (Kafka Units)**.
4. **Advanced Configuration**: set up client authentication, then create
   it. It shows **Pending**, then **Provisioning**, then **Healthy**.
{% endcapture %}

{% capture curl %}
```bash
# 1. Save it. The response includes "generation".
curl -X POST "$API/fleet/<fleet>/kafka/kvc/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"identifier": "team-a", "kafka_id": "<kafka-cluster>", "kafka_units": 2}'

# 2. Provision it
curl -X POST "$API/fleet/<fleet>/kafka/kvc/team-a/reconcile/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"generation": 1}'
```

`identifier`, `kafka_id` and `kafka_units` are required; `provider`
defaults to `kroxy`. The request is refused when the Kafka cluster has
too little capacity left for the Kafka Units you ask for.
{% endcapture %}
{% capture python %}
```python
import uuid

from streamtime_sdk.api.virtual_kafka_clusters import organizations_fleet_kafka_kvc_reconcile_create
from streamtime_sdk.models import ReconcileRequest

resp = client.get_httpx_client().post(
    f"/organizations/{ORG}/fleet/<fleet>/kafka/kvc/",
    json={"identifier": "team-a", "kafka_id": "<kafka-cluster>", "kafka_units": 2},
)
resp.raise_for_status()

organizations_fleet_kafka_kvc_reconcile_create.sync(
    ORG,
    "<fleet>",
    "team-a",
    client=client,
    body=ReconcileRequest(generation=resp.json()["generation"]),
    idempotency_key=str(uuid.uuid4()),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsFleetKafkaKvcReconcileCreate } from "./client";

const { data: saved } = await client.post({
  url: "/organizations/{org_identifier}/fleet/{fleet_id}/kafka/kvc/",
  path: { org_identifier: org, fleet_id: "<fleet>" },
  body: { identifier: "team-a", kafka_id: "<kafka-cluster>", kafka_units: 2 },
});

await organizationsFleetKafkaKvcReconcileCreate({
  path: { org_identifier: org, fleet_id: "<fleet>", identifier: "team-a" },
  headers: { "Idempotency-Key": crypto.randomUUID() },
  body: { generation: (saved as { generation: number }).generation },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/fleet/<fleet>/kafka/kvc/", map[string]any{
    "identifier":  "team-a",
    "kafka_id":    "<kafka-cluster>",
    "kafka_units": 2,
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
resp, err = call("POST", "/fleet/<fleet>/kafka/kvc/team-a/reconcile/",
    map[string]any{"generation": saved.Generation}, newKey())
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="vkc-create-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime virtual-kafka-cluster create --config '{
  "identifier": "team-a",
  "kafka_id": "<kafka-cluster>",
  "kafka_units": 2
}'
```

The CLI saves the virtual cluster but can't start provisioning it yet.
Start it from the UI, or with the API's reconcile request.
{% comment %}Gap: #1818{% endcomment %}
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Create the virtual cluster from the UI, API or
CLI.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% include tabs.html id="vkc-create" ui=ui api=api cli=cli mcp=mcp %}
{% endcapture %}

{% capture extra_section %}
## Connect clients

Once it's **Healthy**, the virtual cluster has its own bootstrap address,
a ready-made client configuration and sample commands. Clients sign in
with OAuth tokens from the identity provider set in its advanced
configuration.

{% capture ui %}
1. Open the virtual cluster from **Virtual Kafka**.
2. **Endpoints** lists its addresses. Select **Test** for the client
   properties and sample commands to copy.
3. **Authorization** shows the **Issuer**, **Audience**, **JWKS Endpoint**,
   **Authorization URI**, **Token URI** and **Scope** clients use to get
   a token.
{% endcapture %}

{% capture curl %}
```bash
# Endpoints, client properties and sample commands are under "resources";
# the OAuth settings under "advanced_config.oauth".
curl -s "$API/fleet/<fleet>/kafka/kvc/team-a/" -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  | jq '{endpoints: .resources.endpoints, client_properties: .resources.client_properties, oauth: .advanced_config.oauth}'
```
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.virtual_kafka_clusters import organizations_fleet_kafka_kvc_retrieve

vkc = organizations_fleet_kafka_kvc_retrieve.sync(ORG, "<fleet>", "team-a", client=client)
print(vkc.resources)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsFleetKafkaKvcRetrieve } from "./client";

const { data: vkc } = await organizationsFleetKafkaKvcRetrieve({
  path: { org_identifier: org, fleet_id: "<fleet>", identifier: "team-a" },
});
console.log(vkc?.resources);
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("GET", "/fleet/<fleet>/kafka/kvc/team-a/", nil)
// Decode "resources" (endpoints, client_properties, commands) from resp.Body.
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="vkc-connect-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime virtual-kafka-cluster get team-a --output json
```

The `resources` field holds the endpoints and client properties.
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Get the connection details from the UI, API or
CLI.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% include tabs.html id="vkc-connect" ui=ui api=api cli=cli mcp=mcp %}
{% endcapture %}

{% capture update_note %}
Change the capacity it claims (`kafka_units`) or its client
authentication. Produce and fetch limits follow the new capacity.
{% endcapture %}
{% capture update_body %}{"kafka_units": 3}{% endcapture %}
{% capture tspath %}{ org_identifier: org, fleet_id: "<fleet>", identifier: "team-a" }{% endcapture %}

{% include workload-tasks.md name="Virtual Kafka Cluster" id="vkc" res="team-a" path="fleet/<fleet>/kafka/kvc" py_mod="virtual_kafka_clusters" py_fn="organizations_fleet_kafka_kvc" py_args='ORG, "<fleet>", "team-a"' ts_fn="organizationsFleetKafkaKvc" ts_path=tspath menu="Virtual Kafka" cli="virtual-kafka-cluster" cli_gap="1818" update_body=update_body update_note=update_note create_section=create_section extra_section=extra_section shots="virtual-kafka" %}
