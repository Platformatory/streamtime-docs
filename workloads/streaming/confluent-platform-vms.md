---
title: "Confluent Platform (VMs)"
parent: Streaming
ancestor: Workloads
nav_order: 6
---

# Confluent Platform on VMs

Confluent Platform on VMs installs a stable Confluent Platform release on
virtual machines you own, instead of on Kubernetes. Streamtime runs Kafka in
KRaft mode and adds Schema Registry, Kafka Connect, REST Proxy and Control
Center according to the machines in your VM fleet.

---

## When to use Confluent Platform on VMs

- **No Kubernetes**: your organization runs Kafka on virtual machines or bare metal.
- **Existing Confluent Platform estate**: you want Streamtime to install, upgrade and monitor Confluent Platform the way you already run it.
- **Dedicated hardware**: each cluster gets a fleet of its own.

## Prerequisites

- **A VM fleet** in **Healthy** state, with **Dedicated** tenancy and no other
  cluster on it. Each VM fleet hosts one Confluent Platform cluster. The
  fleet's machines decide which components run where. See
  [Fleet management]({{ site.baseurl }}/fleet-management/).
- **A Confluent Platform license**, unless you are running a trial.

## Cluster settings

**Basic Configuration**

- **Identifier**: unique in your organization, lowercase letters, digits and dashes.
- **Tags**: optional key/value labels.

Cloud provider, tenancy and capacity are fixed for this cluster type: it
always runs on a VM fleet with Dedicated tenancy, and its size comes from the
fleet's machines, not from Kafka Units.

**Fleet Selection** (administrators only)

Only VM fleets that are Healthy, Dedicated and empty are listed.

**Advanced Configuration** (administrators only)

- **Confluent Package Version**: the Confluent Platform release to install.
  The list shows the stable releases you can choose.
- **SASL protocol**: `scram` (SASL/SCRAM-SHA-512, the default) or `plain`
  (SASL/PLAIN). Clients always connect over TLS.
- **License**: your Confluent Platform license. Leave it blank for a trial.
- **Custom broker properties** and **custom controller properties**: extra
  Kafka settings as key/value pairs, applied to every broker or controller.

---

{% capture cpvm_create %}
## Create a cluster

{% capture ui %}
1. In the sidebar, select **Clusters**, then **Create cluster**.
2. **Cluster Type**: choose **Confluent Platform (VM)**, then select **Next**.

   {% include screenshot.html dir="confluent-platform-vms" file="cluster-type.png" alt="Cluster Type step with Confluent Platform (VM) selected" %}
3. **Basic Configuration**: enter an **Identifier** and optional **Tags**.

   {% include screenshot.html dir="confluent-platform-vms" file="cluster-basic-config.png" alt="Basic Configuration step with the identifier and tags" %}
4. **Fleet Selection**: choose the VM fleet.

   {% include screenshot.html dir="confluent-platform-vms" file="cluster-fleet-selection.png" alt="Fleet Selection step listing the VM fleets" %}
5. **Advanced Configuration**: choose the **Confluent Package Version** and
   the SASL protocol, and add your license.

   {% include screenshot.html dir="confluent-platform-vms" file="cluster-advanced-config.png" alt="Advanced Configuration step with the Confluent Platform version" %}
6. Select **Deploy**.

The cluster appears in the list as **Pending**, then **Provisioning**, then
**Healthy**.
{% endcapture %}

{% capture curl %}
Find the versions you can install in the `confluent_package_version` field
of the provider's settings:

```bash
curl -s "$API/kafka/configuration-profiles/cpansible/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
```

Then save the cluster and start provisioning it:

```bash
# 1. Save the cluster. The response includes its "generation".
curl -X POST "$API/kafka/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "ledger",
    "workload": "cpansible",
    "cloud_provider": "byovm",
    "tenancy_mode": "Dedicated",
    "kafka_units": 1,
    "fleet": "<vm-fleet>",
    "advanced_config": {
      "confluent_package_version": "<version>",
      "sasl_protocol": "scram",
      "license": "<license>"
    }
  }'

# 2. Start provisioning that generation.
curl -X POST "$API/kafka/ledger/reconcile/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"generation": 1}'
```

`fleet` and `confluent_package_version` are required. `kafka_units` is
always `1` for this cluster type. The second request returns `202` with the
operation it started; a `409` means the generation is out of date. Poll
`GET $API/kafka/ledger/` until `status` is `Healthy` (or `Error`).
{% endcapture %}
{% capture python %}
```python
import uuid

from streamtime_sdk.api.kafka import organizations_kafka_reconcile_create
from streamtime_sdk.models import ReconcileRequest

resp = client.get_httpx_client().post(
    f"/organizations/{ORG}/kafka/",
    json={
        "identifier": "ledger",
        "workload": "cpansible",
        "cloud_provider": "byovm",
        "tenancy_mode": "Dedicated",
        "kafka_units": 1,
        "fleet": "<vm-fleet>",
        "advanced_config": {"confluent_package_version": "<version>"},
    },
)
resp.raise_for_status()

organizations_kafka_reconcile_create.sync(
    ORG,
    "ledger",
    client=client,
    body=ReconcileRequest(generation=resp.json()["generation"]),
    idempotency_key=str(uuid.uuid4()),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsKafkaReconcileCreate } from "./client";

const { data: created } = await client.post({
  url: "/organizations/{org_identifier}/kafka/",
  path: { org_identifier: org },
  body: {
    identifier: "ledger",
    workload: "cpansible",
    cloud_provider: "byovm",
    tenancy_mode: "Dedicated",
    kafka_units: 1,
    fleet: "<vm-fleet>",
    advanced_config: { confluent_package_version: "<version>" },
  },
});

await organizationsKafkaReconcileCreate({
  path: { org_identifier: org, identifier: "ledger" },
  headers: { "Idempotency-Key": crypto.randomUUID() },
  body: { generation: (created as { generation: number }).generation },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/kafka/", map[string]any{
    "identifier":      "ledger",
    "workload":        "cpansible",
    "cloud_provider":  "byovm",
    "tenancy_mode":    "Dedicated",
    "kafka_units":     1,
    "fleet":           "<vm-fleet>",
    "advanced_config": map[string]any{"confluent_package_version": "<version>"},
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
resp, err = call("POST", "/kafka/ledger/reconcile/",
    map[string]any{"generation": created.Generation}, newKey())
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="cpvm-create-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime kafka create \
  --identifier ledger \
  --workload cpansible \
  --fleet <vm-fleet> \
  --advanced-config '{"confluent_package_version": "<version>"}'
```

`--fleet` is required for this cluster type. The CLI sets the VM provider,
Dedicated tenancy and one Kafka Unit for you.

{: .note }
The CLI saves the cluster but can't start provisioning yet. Start it from
the API (step 2 in the API tab) or from the cluster's page in the UI.
{% endcapture %}

{% capture mcp %}
Ask your assistant, for example: *"Create a Confluent Platform on VMs
cluster called ledger on the &lt;vm-fleet&gt; fleet, version &lt;version&gt;."*

It uses `create_kafka_cluster` with `workload` `cpansible`, `cloud_provider`
`byovm`, `tenancy_mode` `Dedicated` and `kafka_units` `1`.

{: .note }
The assistant saves the cluster but can't start provisioning yet. Start it
from the API (step 2 in the API tab) or from the cluster's page in the UI.
{% endcapture %}

{% include tabs.html id="cpvm-create" ui=ui api=api cli=cli mcp=mcp %}
{% endcapture %}

{% capture cpvm_status %}
## Check status and connection details

{% capture ui %}
1. In **Clusters**, find the cluster. The list shows its **Status**.
2. Open the cluster. **Overview** shows the status and the fleet.

   {% include screenshot.html dir="confluent-platform-vms" file="cluster-detail.png" alt="Cluster overview with status and fleet" %}
3. To create a user for client applications, select **Manage Credentials**.
   The same page gives the connection settings for your clients.

   {% include screenshot.html dir="confluent-platform-vms" file="cluster-credentials.png" alt="Manage Credentials page with connection settings" %}
{% endcapture %}

{% capture curl %}
```bash
# Status
curl -s "$API/kafka/ledger/status/" -H "Authorization: Bearer $STREAMTIME_TOKEN"

# Client connection settings
curl -s "$API/kafka/ledger/connection-configuration/" -H "Authorization: Bearer $STREAMTIME_TOKEN"

# Client credentials: list, then create one
curl -s "$API/kafka/ledger/credentials/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
curl -X POST "$API/kafka/ledger/credentials/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"credential_type": "KAFKA", "username": "ledger-app"}'
```

This cluster type supports only `KAFKA` credentials.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.kafka_monitoring import organizations_kafka_status_retrieve

status = organizations_kafka_status_retrieve.sync_detailed(ORG, "ledger", client=client)
print(status.content)

conn = client.get_httpx_client().get(
    f"/organizations/{ORG}/kafka/ledger/connection-configuration/"
)
print(conn.json())
```
{% endcapture %}
{% capture typescript %}
```typescript
import {
  organizationsKafkaConnectionConfigurationRetrieve,
  organizationsKafkaStatusRetrieve,
} from "./client";

const path = { org_identifier: org, kafka_id: "ledger" };
const { data: status } = await organizationsKafkaStatusRetrieve({ path });
const { data: conn } = await organizationsKafkaConnectionConfigurationRetrieve({ path });
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("GET", "/kafka/ledger/status/", nil)
resp, err = call("GET", "/kafka/ledger/connection-configuration/", nil)
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="cpvm-status-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime kafka get ledger
streamtime kafka status ledger
streamtime kafka credentials ledger
```

Creating credentials and reading connection settings aren't available in
the CLI yet. Use the UI or API.
{% endcapture %}

{% capture mcp %}
Ask, for example: *"What is the status of the ledger cluster?"* The
assistant uses `get_cluster_status`. MCP doesn't create credentials.
{% endcapture %}

{% include tabs.html id="cpvm-status" ui=ui api=api cli=cli mcp=mcp %}
{% endcapture %}

{% capture cpvm_scale %}
## Change the configuration

A Confluent Platform on VMs cluster takes its size from the VM fleet, so
there are no Kafka Units to change. To grow it, add machines to the fleet.
You can change the SASL protocol, license and custom broker or controller
properties.

{% capture ui %}
Changing these settings isn't available in the UI yet. Use the API.
{% endcapture %}

{% capture curl %}
```bash
# 1. Save the change. The response has the new "generation".
curl -X PATCH "$API/kafka/ledger/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"advanced_config": {
        "confluent_package_version": "<current-version>",
        "custom_broker_properties": {"log.retention.hours": "72"}
      }}'

# 2. Apply that generation.
curl -X POST "$API/kafka/ledger/reconcile/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"generation": <generation>}'
```

`advanced_config` is replaced as a whole, so send every setting, including
the current `confluent_package_version`. To change the version, use
[Upgrade the version](#upgrade-the-version) instead.
{% endcapture %}
{% capture python %}
```python
import uuid

from streamtime_sdk.api.kafka import organizations_kafka_reconcile_create
from streamtime_sdk.models import ReconcileRequest

resp = client.get_httpx_client().patch(
    f"/organizations/{ORG}/kafka/ledger/",
    json={"advanced_config": {
        "confluent_package_version": "<current-version>",
        "custom_broker_properties": {"log.retention.hours": "72"},
    }},
)
resp.raise_for_status()

organizations_kafka_reconcile_create.sync(
    ORG,
    "ledger",
    client=client,
    body=ReconcileRequest(generation=resp.json()["generation"]),
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

const path = { org_identifier: org, identifier: "ledger" };
const { data: cluster } = await organizationsKafkaPartialUpdate({
  path,
  body: {
    advanced_config: {
      confluent_package_version: "<current-version>",
      custom_broker_properties: { "log.retention.hours": "72" },
    },
  },
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
resp, err := call("PATCH", "/kafka/ledger/", map[string]any{
    "advanced_config": map[string]any{
        "confluent_package_version": "<current-version>",
        "custom_broker_properties":  map[string]string{"log.retention.hours": "72"},
    },
})
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
resp, err = call("POST", "/kafka/ledger/reconcile/",
    map[string]any{"generation": updated.Generation}, newKey())
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="cpvm-scale-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime kafka update ledger --advanced-config '{"confluent_package_version": "<current-version>", "custom_broker_properties": {"log.retention.hours": "72"}}'
```

{: .note }
The CLI saves the change but can't apply it yet. Apply it from the API
(step 2 in the API tab).
{% endcapture %}

{% capture mcp %}
Not available in MCP yet.
{% endcapture %}

{% include tabs.html id="cpvm-scale" ui=ui api=api cli=cli mcp=mcp %}
{% endcapture %}

{% capture cpvm_upgrade %}
## Upgrade the version

Streamtime upgrades through every release between the current and the target
version, in order.

{% capture ui %}
1. Open the cluster and select the **Manage** tab.
2. Select **Upgrade version** and choose the new **Version**, then confirm.

   {% include screenshot.html dir="confluent-platform-vms" file="cluster-upgrade.png" alt="Upgrade version dialog with the available Confluent Platform releases" %}

The cluster shows **Upgrading**, then **Healthy**.
{% endcapture %}

{% capture curl %}
```bash
# Versions you can upgrade to
curl -s "$API/kafka/ledger/packages/update/" -H "Authorization: Bearer $STREAMTIME_TOKEN"

# Upgrade to one of them (or send {"strategy": "latest"} for the newest)
curl -X POST "$API/kafka/ledger/packages/update/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"target_version": "<version>"}'
```

The first request returns `current_version` and the `versions` you can
choose. Send either `target_version` or `strategy`, not both.
{% endcapture %}
{% capture python %}
```python
http = client.get_httpx_client()
path = f"/organizations/{ORG}/kafka/ledger/packages/update/"

print(http.get(path).json()["versions"])
http.post(path, json={"target_version": "<version>"}).raise_for_status()
```
{% endcapture %}
{% capture typescript %}
```typescript
const url = "/organizations/{org_identifier}/kafka/{identifier}/packages/update/";
const path = { org_identifier: org, identifier: "ledger" };

const { data: targets } = await client.get({ url, path });
await client.post({ url, path, body: { target_version: "<version>" } });
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("GET", "/kafka/ledger/packages/update/", nil)
resp, err = call("POST", "/kafka/ledger/packages/update/",
    map[string]any{"target_version": "<version>"})
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="cpvm-upgrade-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet. Use the UI or API.
{% endcapture %}

{% capture mcp %}
Not available in MCP yet.
{% endcapture %}

{% include tabs.html id="cpvm-upgrade" ui=ui api=api cli=cli mcp=mcp %}
{% endcapture %}

{% include kafka-cluster-tasks.md workload="cpansible" name="Confluent Platform (VM)" id="cpvm" cluster="ledger" shots="confluent-platform-vms" create_section=cpvm_create status_section=cpvm_status scale_section=cpvm_scale upgrade_section=cpvm_upgrade %}
