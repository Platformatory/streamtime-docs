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
- **Fair-use limits** follow the capacity it claims: produce and fetch
  bytes, requests, and new connections per second.
- **Audited admin operations**: topic, partition, config, record and group
  changes, and every refused request, are recorded with the organization,
  virtual cluster and signed-in client.
- **OAuth sign-in** for clients, with your identity provider's issuer,
  audience and keys.
- **Isolated namespaces**: the virtual clusters on one Kafka cluster can't
  see or change each other's topics, consumer groups or transactions. See
  [Isolation between virtual clusters](#isolation-between-virtual-clusters).

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

The command also starts provisioning, on the Kafka cluster's fleet, once
the settings are complete; otherwise run
`streamtime virtual-kafka-cluster reconcile team-a` when they are.
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Create the virtual cluster from the UI, API or
CLI.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% capture terraform %}
```hcl
resource "streamtime_virtual_kafka" "team_a" {
  identifier  = "team-a"
  kafka_id    = "<kafka-cluster>"
  kafka_units = 1
  advanced_config = jsonencode({
    oauth = {
      client_id         = "team-a"
      client_secret     = var.oauth_client_secret
      issuer            = "<issuer>"
      jwks_endpoint     = "<jwks-endpoint>"
      authorization_uri = "<authorization-endpoint>"
      token_uri         = "<token-endpoint>"
      audience          = "team-a"
    }
  })
}
```

`terraform apply` saves the virtual cluster, deploys it and waits until it is
ready. The endpoints are in `resources`, which is sensitive: read them with
`jsondecode(streamtime_virtual_kafka.team_a.resources).endpoints`. Unlike a
Kafka cluster, a change to `kafka_units` or the settings is deployed in place.
Import by identifier: `terraform import streamtime_virtual_kafka.team_a team-a`.
See [streamtime_virtual_kafka]({{ site.baseurl }}/terraform/virtual-kafka/).
{% endcapture %}

{% include tabs.html id="vkc-create" ui=ui api=api cli=cli mcp=mcp terraform=terraform %}
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

## Isolation between virtual clusters

Each virtual cluster is its own namespace on the shared Kafka cluster.
Clients use plain names (`orders`, `billing-app`); on the Kafka cluster
they are stored as `<virtual cluster identifier>.<name>`, for example
`team-a.orders`. That applies to topics, consumer groups and
transactional IDs. So:

- Two virtual clusters can both have a topic `orders`; they are separate
  topics.
- Listing topics, groups or transactions shows only the virtual cluster's
  own.
- A client can't reach another virtual cluster's data by naming it: the
  name `team-b.orders`, sent through `team-a`, means `team-a.team-b.orders`.

To keep that boundary, a virtual cluster accepts only the Kafka requests
that stay inside it. Producing, consuming with the classic consumer group
protocol, transactions, Kafka Streams, and topic administration (create,
delete, partitions, topic configs, delete records) all work. These are
refused:

| Refused | Error the client gets | Use instead |
|---|---|---|
| The new consumer group protocol (`group.protocol=consumer`), share groups, streams groups | `UNSUPPORTED_VERSION` | the classic protocol (`group.protocol=classic`, the default) |
| ACLs, quotas, SCRAM credentials, delegation tokens, log directories, partition reassignment, leader election | `UNSUPPORTED_VERSION` | ask the Kafka cluster's administrator |
| Broker or broker logger configs | `CLUSTER_AUTHORIZATION_FAILED` | topic configs work |
| Addressing topics by topic ID instead of name | `UNSUPPORTED_VERSION` (or `INVALID_REQUEST` for metadata) | names; current Kafka clients fall back to them automatically |

Kafka clients ask a virtual cluster which requests and versions it
supports and use only those, so these limits show up only when a client
uses one of the refused features.

### Fair-use limits

Each Kafka Unit a virtual cluster claims gives it, shared by all its
clients:

| Limit | Per Kafka Unit |
|---|---|
| Produce | 5 MB/s |
| Fetch | 15 MB/s |
| Requests | 1,500 per second |
| New connections | 25 per second |

A client over a limit is slowed down the way a Kafka broker slows a client
over its quota: responses carry a throttle time, and Kafka clients back
off by themselves. A client that keeps sending anyway is held until the
throttle time is over. A connection opened past the new-connection limit is
accepted, then closed without an answer when its first request arrives;
Kafka clients reconnect after their usual backoff.
The number of connections a virtual cluster keeps open is not limited.

The request and connection limits are starting values and may be tuned.

### Audit of admin operations

Each admin operation through a virtual cluster (creating or deleting
topics, adding partitions, changing topic configs, deleting records or
groups, resetting offsets) and each refused request is written to the
virtual cluster's proxy log as one line, with the organization, the
virtual cluster, the signed-in client, the operation, the topics or groups
it named, and the result. Message contents, config values and credentials
are never written.

### Upgrade order for existing fleets

Isolation, fair-use limits and the audit run in the fleet's virtual
cluster component, which is installed when the fleet is set up. A fleet set
up before this release still runs the old component. Upgrade that fleet's
virtual cluster component to this release **before** you create or update
a virtual cluster on it. A virtual cluster created or updated on a fleet
that still has the old component does not start, and its clients can't
connect until the component is upgraded. Virtual clusters you don't touch
keep running as before until their next update.

### Upgrading a virtual cluster created before isolation

Topics, consumer groups and transactional IDs that a virtual cluster
created before this release are stored without the prefix. After the
upgrade its clients no longer see them: a topic `orders` now means
`team-a.orders`, which starts empty. The old data is not deleted and stays
on the Kafka cluster under its old name.

Plan the upgrade as a new namespace: drain or replay the data your
applications need into the virtual cluster after the upgrade (for example
with MirrorMaker 2 or your own copy job against the Kafka cluster), and
expect consumer groups to start again from their `auto.offset.reset`
position. Delete the old, unprefixed topics from the Kafka cluster once
you no longer need them.
{% endcapture %}

{% capture update_note %}
Change the capacity it claims (`kafka_units`) or its client
authentication. Produce and fetch limits follow the new capacity.
{% endcapture %}
{% capture update_body %}{"kafka_units": 3}{% endcapture %}
{% capture tspath %}{ org_identifier: org, fleet_id: "<fleet>", identifier: "team-a" }{% endcapture %}

{% include workload-tasks.md name="Virtual Kafka Cluster" id="vkc" res="team-a" path="fleet/<fleet>/kafka/kvc" py_mod="virtual_kafka_clusters" py_fn="organizations_fleet_kafka_kvc" py_args='ORG, "<fleet>", "team-a"' ts_fn="organizationsFleetKafkaKvc" ts_path=tspath menu="Virtual Kafka" cli="virtual-kafka-cluster" cli_reconcile="yes" update_body=update_body update_note=update_note create_section=create_section extra_section=extra_section shots="virtual-kafka" %}
