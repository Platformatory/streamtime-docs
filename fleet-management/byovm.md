---
title: "Bootstrap: Bring your own VMs"
parent: Fleet Management
nav_order: 10
---

# Fleets on your own virtual machines (BYOVM)

A VM fleet runs on Linux virtual machines you already have, in any cloud
or data center. Streamtime connects to them over SSH, sets up the shared
services every fleet needs (gateway, metrics, dashboards, logs and
alerts), and then runs one Confluent Platform cluster on the remaining
machines. See [Confluent Platform on VMs]({{ site.baseurl }}/workloads/streaming/confluent-platform-vms.html)
for the cluster itself.

## When to use BYOVM

- You run Kafka on virtual machines, not Kubernetes.
- The machines are yours: their size, network and operating system are
  your choice.

For a Kubernetes cluster you already run, use
[Bring your own Kubernetes](byok.html) instead.

## Key Features

- **No cloud account needed**: Streamtime uses an SSH key you upload.
- **Development or production topologies**, from 4 to 15 machines.
- **Dedicated tenancy**: each VM fleet hosts one Confluent Platform cluster.
- **Health at a glance**: each machine's address, roles, operating system
  and running services under **Host Management**.
- **Monitoring**: metrics, logs and alerts for the fleet and its cluster.

## Prerequisites

- **Linux machines**, as many as the topology needs (see below), running
  Debian or Ubuntu, or RHEL, CentOS, Rocky Linux, AlmaLinux or Oracle
  Linux.
- **SSH access** from Streamtime to every machine, with one key for all of
  them. The SSH user needs passwordless `sudo`.
- **An unencrypted SSH private key** (RSA, Ed25519 or ECDSA) for that user.
  Streamtime stores it as a secret and never returns it.
- **A Base Domain** for the fleet's endpoints, added under **Settings**.

Streamtime checks SSH to every machine when you save the fleet, and names
any machine it can't reach.

## Fleet settings

**Placement Configuration**

- **Environment**: Development or Production.
- **Topology**: Minimum, or Full - High Availability. The pair sets how
  many machines the fleet needs:

  | Environment | Topology | Confluent Platform nodes | Shared Services VMs | Total |
  |---|---|---|---|---|
  | Development | Minimum | 3 | 1 | 4 |
  | Development | Full | 6 | 1 | 7 |
  | Production | Minimum | 7 | 1 | 8 |
  | Production | Full | 13 | 2 | 15 |

  Minimum runs Kafka with its controllers (and, in production, Control
  Center). Full adds Kafka Connect, Schema Registry and REST Proxy, with
  two of each in production.

**Advanced Configuration**

- **SSH private key**: the key file for the SSH user.
- **Confluent Platform Nodes** and **Shared Services VMs**: for each
  machine, a name (letters, digits and dashes, unique in the fleet), its
  host name or IP address, the SSH user and the SSH port (default 22). The
  order decides each machine's role: the first nodes become the Kafka
  brokers and controllers.

---

{% capture account_section %}
## No cloud account needed

A VM fleet uses your SSH key, not a cloud account, so there is nothing to
register. Create the fleet with its machines.
{% endcapture %}

{% capture create_section %}
## Create a fleet

{% capture ui %}
1. In the sidebar, select **Fleet**, then **+ Add Fleet**.
2. **Bootstrap Provider**: choose **Bring Your Own Virtual Machine**, then
   select **Next**.
3. **Basic Configuration**: enter an **Identifier**, keep the **Tenancy**
   at **Dedicated**, choose the **Base Domain**, and under **Workloads**
   turn on Streaming with **Confluent Platform (VMs)**.
4. **Placement Configuration**: choose the **Environment** and the
   **Topology**. The form says how many machines the topology needs.
5. **Advanced Configuration**: upload the **SSH private key**, then fill
   in each of the **Confluent Platform Nodes** and **Shared Services
   VMs**.
6. Select **Deploy**.

Streamtime checks SSH to every machine first; if one can't be reached, the
form says which. The fleet then appears in the list as **Pending**, then
**Provisioning**, then **Healthy** once the shared services are running.

{% include screenshot.html dir="byovm" file="fleet-advanced.png" alt="Advanced Configuration step with the SSH key and the machines" %}
{% endcapture %}

{% capture curl %}
Creating a fleet takes two requests. The first saves the fleet and checks
SSH to every machine; the second starts setting it up. Send the key as a
base64 data URL, so it fits in JSON:

```bash
KEY="data:application/octet-stream;base64,$(base64 -w0 ./id_ed25519)"

# 1. Save the fleet. The response includes "generation".
curl -X POST "$API/fleet/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "cp-dev",
    "provider": "byovm",
    "domain": "<base-domain>",
    "tenancy_mode": "Dedicated",
    "workloads": {"streaming": {"enabled": true, "providers": ["cpansible"]}},
    "placement_config": {"environment": "development", "topology": "minimum"},
    "advanced_config": {
      "ssh_private_key": "'"$KEY"'",
      "hosts": [
        {"name": "cp-1", "ansible_host": "10.0.1.11", "ssh_user": "ubuntu"},
        {"name": "cp-2", "ansible_host": "10.0.1.12", "ssh_user": "ubuntu"},
        {"name": "cp-3", "ansible_host": "10.0.1.13", "ssh_user": "ubuntu"}
      ],
      "shared_service_hosts": [
        {"name": "shared-1", "ansible_host": "10.0.1.20", "ssh_user": "ubuntu"}
      ]
    }
  }'

# 2. Start setting up that generation.
curl -X POST "$API/fleet/cp-dev/reconcile/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"generation": 1}'
```

A `400` names the machine Streamtime couldn't reach over SSH, or says how
many machines the topology needs. `ssh_port` defaults to 22. Poll
`GET $API/fleet/cp-dev/` until `status` is `Healthy` (or `Error`).
{% endcapture %}
{% capture python %}
```python
import uuid
from pathlib import Path

from streamtime_sdk.api.fleet import organizations_fleet_reconcile_create
from streamtime_sdk.models import ReconcileRequest

def host(name, address):
    return {"name": name, "ansible_host": address, "ssh_user": "ubuntu"}

resp = client.get_httpx_client().post(
    f"/organizations/{ORG}/fleet/",
    json={
        "identifier": "cp-dev",
        "provider": "byovm",
        "domain": "<base-domain>",
        "tenancy_mode": "Dedicated",
        "workloads": {"streaming": {"enabled": True, "providers": ["cpansible"]}},
        "placement_config": {"environment": "development", "topology": "minimum"},
        "advanced_config": {
            "ssh_private_key": Path("id_ed25519").read_text(),
            "hosts": [host("cp-1", "10.0.1.11"), host("cp-2", "10.0.1.12"), host("cp-3", "10.0.1.13")],
            "shared_service_hosts": [host("shared-1", "10.0.1.20")],
        },
    },
)
resp.raise_for_status()  # 400: a machine failed the SSH check

organizations_fleet_reconcile_create.sync(
    ORG,
    "cp-dev",
    client=client,
    body=ReconcileRequest(generation=resp.json()["generation"]),
    idempotency_key=str(uuid.uuid4()),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { readFileSync } from "node:fs";
import { organizationsFleetReconcileCreate } from "./client";

const host = (name: string, address: string) =>
  ({ name, ansible_host: address, ssh_user: "ubuntu" });

const { data: saved } = await client.post({
  url: "/organizations/{org_identifier}/fleet/",
  path: { org_identifier: org },
  body: {
    identifier: "cp-dev",
    provider: "byovm",
    domain: "<base-domain>",
    tenancy_mode: "Dedicated",
    workloads: { streaming: { enabled: true, providers: ["cpansible"] } },
    placement_config: { environment: "development", topology: "minimum" },
    advanced_config: {
      ssh_private_key: readFileSync("id_ed25519", "utf8"),
      hosts: [host("cp-1", "10.0.1.11"), host("cp-2", "10.0.1.12"), host("cp-3", "10.0.1.13")],
      shared_service_hosts: [host("shared-1", "10.0.1.20")],
    },
  },
});

await organizationsFleetReconcileCreate({
  path: { org_identifier: org, identifier: "cp-dev" },
  headers: { "Idempotency-Key": crypto.randomUUID() },
  body: { generation: (saved as { generation: number }).generation },
});
```
{% endcapture %}
{% capture go %}
```go
key, err := os.ReadFile("id_ed25519")
if err != nil {
    return err
}
host := func(name, address string) map[string]any {
    return map[string]any{"name": name, "ansible_host": address, "ssh_user": "ubuntu"}
}
resp, err := call("POST", "/fleet/", map[string]any{
    "identifier":   "cp-dev",
    "provider":     "byovm",
    "domain":       "<base-domain>",
    "tenancy_mode": "Dedicated",
    "workloads": map[string]any{
        "streaming": map[string]any{"enabled": true, "providers": []string{"cpansible"}},
    },
    "placement_config": map[string]any{"environment": "development", "topology": "minimum"},
    "advanced_config": map[string]any{
        "ssh_private_key":      string(key),
        "hosts":                []any{host("cp-1", "10.0.1.11"), host("cp-2", "10.0.1.12"), host("cp-3", "10.0.1.13")},
        "shared_service_hosts": []any{host("shared-1", "10.0.1.20")},
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
resp, err = call("POST", "/fleet/cp-dev/reconcile/",
    map[string]any{"generation": saved.Generation}, newKey())
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="byovm-create-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
KEY="data:application/octet-stream;base64,$(base64 -w0 ./id_ed25519)"

streamtime fleet create \
  --identifier cp-dev \
  --provider byovm \
  --domain <base-domain> \
  --tenancy-mode Dedicated \
  --streaming cpansible \
  --placement-config '{"environment": "development", "topology": "minimum"}' \
  --advanced-config '{
    "ssh_private_key": "'"$KEY"'",
    "hosts": [
      {"name": "cp-1", "ansible_host": "10.0.1.11", "ssh_user": "ubuntu"},
      {"name": "cp-2", "ansible_host": "10.0.1.12", "ssh_user": "ubuntu"},
      {"name": "cp-3", "ansible_host": "10.0.1.13", "ssh_user": "ubuntu"}
    ],
    "shared_service_hosts": [
      {"name": "shared-1", "ansible_host": "10.0.1.20", "ssh_user": "ubuntu"}
    ]
  }'
```

When the settings are complete, the command also starts setting up the
fleet; otherwise run `streamtime fleet reconcile cp-dev` once they are.
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Create the fleet from the UI, API or CLI.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% include tabs.html id="byovm-create" ui=ui api=api cli=cli mcp=mcp %}
{% endcapture %}

{% capture status_section %}
## Check fleet status

A VM fleet's **Status** is one of Incomplete, Pending, Provisioning,
Updating, Deleting, Healthy or Error. Each machine's health comes from a
check Streamtime runs over SSH on request.

{% capture ui %}
1. In the sidebar, select **Fleet**, and open the fleet. **Overview**
   shows its status and machines.
2. Select **Host Management**, then **Refresh fleet status** to check every
   machine now. Each row shows the machine's **Slot**, **Address**,
   **Roles**, **Operating System** and **Running Services**, with the time
   of the last check.

   {% include screenshot.html dir="byovm" file="host-management.png" alt="Host Management with each machine's roles and running services" %}
{% endcapture %}

{% capture curl %}
```bash
# Status, and the machines as last checked (metadata.byovm_host_observations)
curl -s "$API/fleet/cp-dev/" -H "Authorization: Bearer $STREAMTIME_TOKEN"

# Check every machine now (waits for the answer)
curl -s -X POST "$API/fleet/cp-dev/status/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
```
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.fleet import organizations_fleet_retrieve
from streamtime_sdk.api.fleet_metrics import organizations_fleet_status_create

fleet = organizations_fleet_retrieve.sync(ORG, "cp-dev", client=client)
print(fleet.status)

report = organizations_fleet_status_create.sync_detailed(ORG, "cp-dev", client=client)
print(report.content.decode())  # one entry per machine
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsFleetRetrieve, organizationsFleetStatusCreate } from "./client";

const { data: fleet } = await organizationsFleetRetrieve({
  path: { org_identifier: org, identifier: "cp-dev" },
});
const report = await organizationsFleetStatusCreate({
  path: { org_identifier: org, fleet_id: "cp-dev" },
});
console.log(fleet?.status, report.data);
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("GET", "/fleet/cp-dev/", nil)
// Decode "status" from resp.Body.

resp, err = call("POST", "/fleet/cp-dev/status/", nil) // check every machine now
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="byovm-status-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime fleet list
streamtime fleet get cp-dev
streamtime fleet status cp-dev
```

`fleet status` shows the last health report.
{% endcapture %}

{% capture mcp %}
Ask your assistant, for example: *"Is the cp-dev fleet healthy?"*

It uses `get_fleet_status` (pass `refresh` to check the machines now),
`get_fleet_alerts` and `get_fleet_logs`.
{% endcapture %}

{% include tabs.html id="byovm-status" ui=ui api=api cli=cli mcp=mcp %}
{% endcapture %}

{% capture update_section %}
## Update the fleet

To replace a machine, change its address or rotate the SSH key, send the
fleet's advanced settings again, with the key and every machine, then
start an update. Streamtime checks SSH to every machine before it saves
the change. The environment and topology can't be changed; create a new
fleet for a different size. A VM fleet has no Agent to update.

{% capture ui %}
Not available in the UI yet. **Advanced Configuration** on the fleet shows
the machines but can't change them. Use the API.
{% comment %}Gap: #1816{% endcomment %}
{% endcapture %}

{% capture curl %}
```bash
KEY="data:application/octet-stream;base64,$(base64 -w0 ./id_ed25519)"

# 1. Save the new machines (here cp-3 moves to 10.0.1.14)
curl -X PATCH "$API/fleet/cp-dev/advanced-config/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "ssh_private_key": "'"$KEY"'",
    "hosts": [
      {"name": "cp-1", "ansible_host": "10.0.1.11", "ssh_user": "ubuntu"},
      {"name": "cp-2", "ansible_host": "10.0.1.12", "ssh_user": "ubuntu"},
      {"name": "cp-3", "ansible_host": "10.0.1.14", "ssh_user": "ubuntu"}
    ],
    "shared_service_hosts": [
      {"name": "shared-1", "ansible_host": "10.0.1.20", "ssh_user": "ubuntu"}
    ]
  }'

# 2. Apply them: reconcile the fleet's new generation
GEN=$(curl -s "$API/fleet/cp-dev/" -H "Authorization: Bearer $STREAMTIME_TOKEN" | jq .generation)
curl -X POST "$API/fleet/cp-dev/reconcile/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d "{\"generation\": $GEN}"
```

The fleet shows **Updating**, then **Healthy** again.
{% endcapture %}
{% capture python %}
```python
import uuid
from pathlib import Path

from streamtime_sdk.api.fleet import (
    organizations_fleet_reconcile_create,
    organizations_fleet_retrieve,
)
from streamtime_sdk.models import ReconcileRequest

def host(name, address):
    return {"name": name, "ansible_host": address, "ssh_user": "ubuntu"}

resp = client.get_httpx_client().patch(
    f"/organizations/{ORG}/fleet/cp-dev/advanced-config/",
    json={
        "ssh_private_key": Path("id_ed25519").read_text(),
        "hosts": [host("cp-1", "10.0.1.11"), host("cp-2", "10.0.1.12"), host("cp-3", "10.0.1.14")],
        "shared_service_hosts": [host("shared-1", "10.0.1.20")],
    },
)
resp.raise_for_status()

fleet = organizations_fleet_retrieve.sync(ORG, "cp-dev", client=client)
organizations_fleet_reconcile_create.sync(
    ORG,
    "cp-dev",
    client=client,
    body=ReconcileRequest(generation=fleet.generation),
    idempotency_key=str(uuid.uuid4()),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { readFileSync } from "node:fs";
import { organizationsFleetReconcileCreate, organizationsFleetRetrieve } from "./client";

const host = (name: string, address: string) =>
  ({ name, ansible_host: address, ssh_user: "ubuntu" });

await client.patch({
  url: "/organizations/{org_identifier}/fleet/{identifier}/advanced-config/",
  path: { org_identifier: org, identifier: "cp-dev" },
  body: {
    ssh_private_key: readFileSync("id_ed25519", "utf8"),
    hosts: [host("cp-1", "10.0.1.11"), host("cp-2", "10.0.1.12"), host("cp-3", "10.0.1.14")],
    shared_service_hosts: [host("shared-1", "10.0.1.20")],
  },
});

const { data: fleet } = await organizationsFleetRetrieve({
  path: { org_identifier: org, identifier: "cp-dev" },
});
await organizationsFleetReconcileCreate({
  path: { org_identifier: org, identifier: "cp-dev" },
  headers: { "Idempotency-Key": crypto.randomUUID() },
  body: { generation: fleet!.generation },
});
```
{% endcapture %}
{% capture go %}
```go
key, err := os.ReadFile("id_ed25519")
if err != nil {
    return err
}
host := func(name, address string) map[string]any {
    return map[string]any{"name": name, "ansible_host": address, "ssh_user": "ubuntu"}
}
resp, err := call("PATCH", "/fleet/cp-dev/advanced-config/", map[string]any{
    "ssh_private_key":      string(key),
    "hosts":                []any{host("cp-1", "10.0.1.11"), host("cp-2", "10.0.1.12"), host("cp-3", "10.0.1.14")},
    "shared_service_hosts": []any{host("shared-1", "10.0.1.20")},
})
if err != nil {
    return err
}
resp.Body.Close()

resp, err = call("GET", "/fleet/cp-dev/", nil)
if err != nil {
    return err
}
defer resp.Body.Close()
var fleet struct {
    Generation int `json:"generation"`
}
if err := json.NewDecoder(resp.Body).Decode(&fleet); err != nil {
    return err
}
resp, err = call("POST", "/fleet/cp-dev/reconcile/",
    map[string]any{"generation": fleet.Generation}, newKey())
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="byovm-update-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet. Update the fleet from the API.
{% comment %}Gap: #1812{% endcomment %}
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Update the fleet from the API.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% include tabs.html id="byovm-update" ui=ui api=api cli=cli mcp=mcp %}
{% endcapture %}

{% capture remove_account_section %}
Deleting a VM fleet removes the shared services Streamtime installed and
the fleet's stored SSH key. The machines themselves stay as they are.
{% endcapture %}

{% include fleet-tasks.md provider="byovm" name="Bring Your Own Virtual Machine" id="byovm" fleet="cp-dev" account_section=account_section create_section=create_section status_section=status_section update_section=update_section remove_account_section=remove_account_section shots="byovm" %}
