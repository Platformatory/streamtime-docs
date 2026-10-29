---
title: "Bootstrap: Bring your own Kubernetes"
parent: Fleet Management
nav_order: 1
---

# Fleets on your own Kubernetes (BYOK)

BYOK ("Bring Your Own Kubernetes") runs Streamtime workloads on a Kubernetes
cluster you already operate, instead of a cluster Streamtime creates in a
cloud account. Streamtime installs its Agent and the services the fleet's
workloads need on your cluster; you keep control of the infrastructure.

## When to use BYOK

- You already run Kubernetes (on-premises, bare metal, or any cloud) and want to reuse it.
- You don't want to give Streamtime a cloud account.
- Your workloads must stay in an environment with network or compliance constraints.
- You want the fastest path to a first fleet for evaluation.

## Key Features

- Reuse your existing clusters and capacity.
- The same Kafka and other workloads, monitoring and lifecycle as cloud fleets.
- Shared, Isolated or Dedicated tenancy on your cluster.
- Only what the fleet's workloads need is installed, and removed again when you delete the fleet.

## Prerequisites

- **A Kubernetes cluster** with a LoadBalancer provider and a default
  storage class, sized for the workloads you plan to run. For EKS and OKE,
  see [BYOK with AWS](byok-aws.html) and [BYOK with OCI](byok-oci.html).
- **Access to install the Agent**: either a kubeconfig Streamtime can use
  to install it for you (**automatic**), or `kubectl` and `helm` access to
  run the install commands yourself (**manual**).
- **A Base Domain** for the fleet's endpoints, added under **Settings**.

## Fleet settings

**Placement Configuration** (both optional, for your records)

- **Bootstrap Provider**: the cloud your cluster runs on.
- **Region**: where it runs.

**Advanced Configuration**

- **Namespace Whitelist**: the namespaces Streamtime may use.
- **Workload Identity**: lets Streamtime's components use your cloud's
  workload identity, for example for the logs bucket.
- **Resource Limits & Quotas**: limits for what Streamtime runs.
- **Custom Labels** and **Custom Annotations**: added to what Streamtime creates.
- **Tolerations**, **Affinity** and **Topology Spread Constraints**: where
  Streamtime's components and Kafka workloads are scheduled. A component's
  own settings override these.
- **Logs Storage Bucket Name**: optional; needs workload identity. Without
  a name, Streamtime generates one.

---

{% capture account_section %}
## No cloud account needed

A BYOK fleet uses your cluster's credentials, not a cloud account, so there
is nothing to register. Create the fleet, then connect the cluster.
{% endcapture %}

{% capture create_section %}
## Create a fleet

{% capture ui %}
1. In the sidebar, select **Fleet**, then **+ Add Fleet**.
2. **Bootstrap Provider**: choose **BYOK**, then select **Next**.

   {% include screenshot.html dir="byok" file="step-1.png" alt="Bootstrap Provider step with BYOK selected" %}
3. **Basic Configuration**: enter an **Identifier**, choose the **Tenancy**
   (Shared, Isolated or Dedicated), the **Base Domain** and **Max Tenants**.
   Under **Workloads**, choose what the fleet runs and the share of the
   cluster each workload gets.

   {% include screenshot.html dir="byok" file="step-2.png" alt="Basic Configuration step with identifier, tenancy and workloads" %}
4. **Placement Configuration**: optionally note the cloud and region your
   cluster runs on.

   {% include screenshot.html dir="byok" file="step-3.png" alt="Placement Configuration step with optional provider and region" %}
5. **Advanced Configuration**: review the settings, then select **Deploy**.

   {% include screenshot.html dir="byok" file="step-4.png" alt="Advanced Configuration step for a BYOK fleet" %}

The fleet is saved. Next, [connect the cluster](#connect-the-cluster).
{% endcapture %}

{% capture curl %}
```bash
# 1. Save the fleet.
curl -X POST "$API/fleet/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "edge-lab",
    "provider": "byok",
    "domain": "<base-domain>",
    "tenancy_mode": "Shared"
  }'

# 2. Record it as ready for its cluster (send the "generation" from step 1).
curl -X POST "$API/fleet/edge-lab/reconcile/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"generation": 1}'
```

`identifier`, `provider` and `domain` are required. Add `placement_config`
and `advanced_config` for the settings above, and `workloads` to choose
what the fleet runs (without it, every workload is enabled). Nothing is
installed until you connect the cluster.
{% endcapture %}
{% capture python %}
```python
import uuid

from streamtime_sdk.api.fleet import organizations_fleet_reconcile_create
from streamtime_sdk.models import ReconcileRequest

resp = client.get_httpx_client().post(
    f"/organizations/{ORG}/fleet/",
    json={
        "identifier": "edge-lab",
        "provider": "byok",
        "domain": "<base-domain>",
        "tenancy_mode": "Shared",
    },
)
resp.raise_for_status()

organizations_fleet_reconcile_create.sync(
    ORG,
    "edge-lab",
    client=client,
    body=ReconcileRequest(generation=resp.json()["generation"]),
    idempotency_key=str(uuid.uuid4()),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsFleetReconcileCreate } from "./client";

const { data: saved } = await client.post({
  url: "/organizations/{org_identifier}/fleet/",
  path: { org_identifier: org },
  body: {
    identifier: "edge-lab",
    provider: "byok",
    domain: "<base-domain>",
    tenancy_mode: "Shared",
  },
});

await organizationsFleetReconcileCreate({
  path: { org_identifier: org, identifier: "edge-lab" },
  headers: { "Idempotency-Key": crypto.randomUUID() },
  body: { generation: (saved as { generation: number }).generation },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/fleet/", map[string]any{
    "identifier":   "edge-lab",
    "provider":     "byok",
    "domain":       "<base-domain>",
    "tenancy_mode": "Shared",
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
resp, err = call("POST", "/fleet/edge-lab/reconcile/",
    map[string]any{"generation": saved.Generation}, newKey())
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="byok-create-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime fleet create \
  --identifier edge-lab \
  --provider byok \
  --domain <base-domain> \
  --tenancy-mode Shared
```
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Create the fleet from the UI, API or CLI.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% include tabs.html id="byok-create" ui=ui api=api cli=cli mcp=mcp %}

---

## Connect the cluster

Install the Agent on your cluster. Streamtime then sets up the fleet
("bootstraps" it) with the services its workloads need.

{% capture ui %}
1. Open the fleet and select **Agent Management**.
2. Choose how to install the Agent:
   - **Install (Automatic)**: select **Create kubeconfig secret**, upload
     your kubeconfig, then select **Start installation**. Streamtime
     installs the Agent and bootstraps the cluster.
   - **Install (Manual)**: run the commands shown on the page against your
     cluster, tick **I have completed the installation steps above and the
     agent is running in my cluster**, and continue. Streamtime verifies the
     Agent's connection, then bootstraps the cluster.

The steps (**Install Agent**, **Bootstrap Cluster**, and **Verify
Connection** for a manual install) complete in turn; the page shows
**Cluster Bootstrapped** when the fleet is ready.

{: .note }
Streamtime is strict about the kubeconfig format. See
[BYOK with AWS](byok-aws.html) or [BYOK with OCI](byok-oci.html) for how to
build one.
{% endcapture %}

{% capture curl %}
**Automatic install.** Store the kubeconfig, then start the install:

```bash
# 1. Store the kubeconfig (base64-encoded) for the fleet.
curl -X POST "$API/secrets/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"provider\": \"builtin\",
    \"path\": \"/organizations/<org>/fleet/edge-lab/kubeconfig\",
    \"content\": \"$(base64 -w0 < ./kubeconfig)\"
  }"

# 2. Install the Agent and bootstrap the cluster.
curl -X POST "$API/fleet/edge-lab/agent/InstallStreamtimeAgentWorkflow/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "registry_url": "<registry>",
    "repository": "<repository>",
    "mode": "fleet_bootstrap"
  }'
```

**Manual install.** Get the install values, install the Agent yourself,
then have Streamtime verify it and bootstrap the cluster:

```bash
# 1. Values for the Agent's Helm install.
curl -s "$API/fleet/edge-lab/agent/bootstrap/" -H "Authorization: Bearer $STREAMTIME_TOKEN"

# 2. After installing the Agent, verify its connection.
curl -X POST "$API/fleet/edge-lab/agent/connection/verify/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN"

# 3. Bootstrap the cluster.
curl -X POST "$API/fleet/edge-lab/agent/ByokProvider/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action": "CREATE"}'
```

`registry_url` and `repository` are where your Streamtime installation
publishes the Agent; ask your Streamtime administrator. Each step returns
`201` with the operation it started (`409` if a verification is already
running). Follow progress with `GET $API/fleet/edge-lab/agent/`: its
`status` reaches `bootstrap_complete` when the fleet is ready.
{% endcapture %}
{% capture python %}
```python
import base64

from streamtime_sdk.api.agent import get_agent_connection
from streamtime_sdk.api.fleet_tasks import dispatch_agent_task
from streamtime_sdk.models import DispatchAgentTaskWorkflowType

with open("kubeconfig", "rb") as fh:
    content = base64.b64encode(fh.read()).decode()

client.get_httpx_client().post(
    f"/organizations/{ORG}/secrets/",
    json={
        "provider": "builtin",
        "path": f"/organizations/{ORG}/fleet/edge-lab/kubeconfig",
        "content": content,
    },
).raise_for_status()

dispatch_agent_task.sync_detailed(
    ORG,
    "edge-lab",
    DispatchAgentTaskWorkflowType.INSTALLSTREAMTIMEAGENTWORKFLOW,
    client=client,
    body={
        "registry_url": "<registry>",
        "repository": "<repository>",
        "mode": "fleet_bootstrap",
    },
)

agent = get_agent_connection.sync_detailed(ORG, "edge-lab", client=client)
print(agent.content.decode())  # "status" reaches "bootstrap_complete"
```
{% endcapture %}
{% capture typescript %}
```typescript
import { readFileSync } from "node:fs";
import { dispatchAgentTask, getAgentConnection } from "./client";

await client.post({
  url: "/organizations/{org_identifier}/secrets/",
  path: { org_identifier: org },
  body: {
    provider: "builtin",
    path: `/organizations/${org}/fleet/edge-lab/kubeconfig`,
    content: readFileSync("kubeconfig").toString("base64"),
  },
});

await dispatchAgentTask({
  path: {
    org_identifier: org,
    fleet_id: "edge-lab",
    workflow_type: "InstallStreamtimeAgentWorkflow",
  },
  body: {
    registry_url: "<registry>",
    repository: "<repository>",
    mode: "fleet_bootstrap",
  },
});

const { data } = await getAgentConnection({
  path: { org_identifier: org, fleet_id: "edge-lab" },
});
console.log(data);
```
{% endcapture %}
{% capture go %}
```go
kubeconfig, err := os.ReadFile("kubeconfig")
if err != nil {
    return err
}
// Also import "encoding/base64".
resp, err := call("POST", "/secrets/", map[string]any{
    "provider": "builtin",
    "path":     "/organizations/<org>/fleet/edge-lab/kubeconfig",
    "content":  base64.StdEncoding.EncodeToString(kubeconfig),
})

resp, err = call("POST", "/fleet/edge-lab/agent/InstallStreamtimeAgentWorkflow/", map[string]any{
    "registry_url": "<registry>",
    "repository":   "<repository>",
    "mode":         "fleet_bootstrap",
})
// Then poll call("GET", "/fleet/edge-lab/agent/", nil) until "status" is "bootstrap_complete".
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="byok-connect-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet. Connect the cluster from the UI or the API.
{% comment %}Gap: #1813{% endcomment %}
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Connect the cluster from the UI or the API.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% include tabs.html id="byok-connect" ui=ui api=api cli=cli mcp=mcp %}
{% endcapture %}

{% capture remove_account_section %}
Deleting a BYOK fleet removes what Streamtime installed on your cluster.
The cluster itself, and its baseline (networking, load balancer, storage),
stay as they are.
{% endcapture %}

{% include fleet-tasks.md provider="byok" name="BYOK" id="byok" fleet="edge-lab" account_section=account_section create_section=create_section remove_account_section=remove_account_section shots="byok" %}
