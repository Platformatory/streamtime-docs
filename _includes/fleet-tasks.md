{%- comment -%}
  The lifecycle tasks every fleet provider page shares, each in UI / API /
  CLI / MCP tabs with HTTP / Python / TypeScript / Go API sub-tabs.

    {% include fleet-tasks.md provider="aws" name="AWS" id="aws" fleet="payments-east"
         credentials=credentials placement=placement advanced=advanced shots="aws" %}

  Params:
    provider     provider key sent as `provider` (aws, azure, gcp, oci, byok)
    name         provider name as shown on the Bootstrap Provider step
    id           unique, kebab-case prefix for this page's tab ids
    fleet        example fleet identifier used in every snippet
    credentials  JSON object: the cloud account's `configuration`
    placement    JSON object: the fleet's `placement_config`
    advanced     JSON object: the fleet's `advanced_config`
    account_section, create_section, status_section, update_section,
    remove_account_section
                 optional captured markdown (heading and tabs) that replaces
                 that task's default section, for providers that differ
    sdk_account_gap
                 optional gap issue number. When set, the Python and
                 TypeScript tabs of "Register the cloud account" say the
                 client can't do it yet (the generated clients don't know
                 the provider) and point to HTTP or Go instead
    network_body optional JSON object: the body of "Create a network" (identifier,
                 provider, name, region, cidr, and compartment_id on OCI).
                 When set, the page gets a "Networks" section after the cloud
                 account. Only AWS and OCI can create a network.
    network_terraform
                 captured markdown for the network's Terraform tab (required
                 with network_body; OCI differs, see oracle.md)
    shots        optional folder under assets/images/ holding the UI
                 screenshots. Each one shows once its file exists:
                 account-basic-info.png, account-credentials.png,
                 fleet-bootstrap-provider.png, fleet-basic-config.png,
                 fleet-placement-config.png, fleet-advanced.png,
                 fleet-list.png, fleet-detail.png, fleet-agent.png,
                 agent-update.png, fleet-delete.png
  JSON params go into Python and TypeScript as literals, so they hold only
  strings, numbers, objects and arrays (no true, false or null).
{%- endcomment -%}
{%- assign k = include.provider -%}
{%- assign n = include.name -%}
{%- assign p = include.id -%}
{%- assign f = include.fleet -%}
{%- assign s = include.shots -%}
{%- assign rn = f | replace: "-", "_" -%}
{%- assign kn = k | replace: "-", "_" -%}

## Before you start

- A **Base Domain** for the fleet's endpoints, added under **Settings**.
- For the API: an access token in `STREAMTIME_TOKEN` and your organization
  identifier in place of `<org>`. Replace `api.example.com` with your
  Streamtime API address.
- Only administrators and infrastructure administrators can manage fleets
  and cloud accounts.

{% include api-setup.md id=p %}

---

{% if include.account_section %}{{ include.account_section }}{% else %}
## Register the cloud account

A cloud account holds the credentials Streamtime uses to create resources
in your {{ n }} account. Register it once; every fleet on that account uses it.

{% capture ui %}
1. Go to **Settings**, then **Bootstrap Providers**, and select
   **+ Add Bootstrap Provider**.
2. **Basic Information**: enter an **Identifier** for the account (lowercase
   letters, digits and dashes, up to 24 characters).

   {% include screenshot.html dir=s file="account-basic-info.png" alt="Basic Information step with the account identifier" %}
3. **Bootstrap Provider Details**: choose **{{ n }}** and fill in its
   credentials (see [Prerequisites](#prerequisites)), then save.

   {% include screenshot.html dir=s file="account-credentials.png" alt="Bootstrap Provider Details step with the credential fields" %}

The account appears in the list. Some clouds, such as AWS, are checked as
you save: Streamtime refuses credentials the cloud rejects and says why.
Streamtime checks the permissions again when you create a fleet.
{% endcapture %}

{% capture curl %}
```bash
curl -X POST "$API/bootstrap-providers/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "<cloud-account>",
    "provider": "{{ k }}",
    "configuration": {{ include.credentials }}
  }'
```

Returns `201` with the account. For some clouds, such as AWS, Streamtime
checks the credentials with the cloud first and returns `400` with the
cloud's reason when they are rejected.
{% endcapture %}
{% if include.sdk_account_gap %}
{% capture python %}
Not available in the Python client yet. Register the account with the HTTP
or Go example.
{% comment %}Gap: #{{ include.sdk_account_gap }}{% endcomment %}
{% endcapture %}
{% capture typescript %}
Not available in the TypeScript client yet. Register the account with the
HTTP or Go example.
{% comment %}Gap: #{{ include.sdk_account_gap }}{% endcomment %}
{% endcapture %}
{% else %}
{% capture python %}
```python
from streamtime_sdk.api.bootstrap_providers import organizations_bootstrap_providers_create
from streamtime_sdk.models import OrganizationsBootstrapProvidersCreateBody

account = organizations_bootstrap_providers_create.sync(
    ORG,
    client=client,
    body=OrganizationsBootstrapProvidersCreateBody.from_dict({
        "identifier": "<cloud-account>",
        "provider": "{{ k }}",
        "configuration": {{ include.credentials }},
    }),
)
print(account.identifier)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsBootstrapProvidersCreate } from "./client";

const { data } = await organizationsBootstrapProvidersCreate({
  path: { org_identifier: org },
  body: {
    identifier: "<cloud-account>",
    provider: "{{ k }}",
    configuration: {{ include.credentials }},
  },
});
console.log(data?.identifier);
```
{% endcapture %}
{% endif %}
{% capture go %}
```go
resp, err := call("POST", "/bootstrap-providers/", json.RawMessage(`{
    "identifier": "<cloud-account>",
    "provider": "{{ k }}",
    "configuration": {{ include.credentials }}
}`))
// resp.StatusCode is 201 on success.
```
{% endcapture %}
{%- capture tid -%}{{ p }}-account-api{%- endcapture -%}
{% capture api %}{% include code-tabs.html id=tid curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime provider create \
  --identifier <cloud-account> \
  --type {{ k }} \
  --config '{{ include.credentials }}'
```

List your accounts with `streamtime provider list -O json`.
{% comment %}Gap: #1883 (the table output of list fails){% endcomment %}
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Register the account from the UI, API or CLI.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% capture terraform %}
```hcl
resource "streamtime_cloud_account" "{{ kn }}" {
  identifier     = "<cloud-account>"
  cloud_provider = "{{ k }}"

  configuration = jsonencode({{ include.credentials }})
}
```

Fill the credentials from sensitive variables or your secrets store, not
from values written in the file. Terraform doesn't read credentials back, so
a change made outside Terraform isn't detected. To manage an account that
already exists, import it by identifier:
`terraform import streamtime_cloud_account.{{ kn }} <cloud-account>`, then
set `configuration` and apply. See
[streamtime_cloud_account]({{ site.baseurl }}/terraform/cloud-account/).
{% endcapture %}

{%- capture tid -%}{{ p }}-account{%- endcapture -%}
{% include tabs.html id=tid ui=ui api=api cli=cli mcp=mcp terraform=terraform %}

To change the credentials later, select **Edit Credentials** on the
account in the UI, send `PATCH $API/bootstrap-providers/<cloud-account>/`
with a new `configuration`, or change `configuration` in Terraform and apply.
Changing them from the CLI isn't available yet.
{% comment %}Gap: #1882{% endcomment %}
{% endif %}

---

{% if include.network_body %}
## Networks

A network is the {% if k == "oci" %}VCN{% else %}VPC{% endif %} a fleet runs in. You don't need one to create a
fleet: without it, the fleet creates its own (see [Fleet settings](#fleet-settings)).
Create a network when you want to manage it separately from any fleet. Leave
out **Existing Network ID** and Streamtime creates the network in your cloud
account; give the ID of one you already have and Streamtime only records it.

### Create a network

{% capture ui %}
1. In the sidebar, select **Network**, then **Create network**.
2. In **Create Network**, choose the **Bootstrap Provider** (your cloud
   account), enter an **Identifier** (lowercase letters, digits and dashes,
   up to 24 characters), a **Name**, the **Region** and, optionally, the
   **CIDR**.{% if k == "oci" %} Enter the **Compartment ID (OCI)** to create the network in.{% endif %}
3. To use a network you already have, enter its ID in **Existing Network ID**
   instead of leaving it empty.
4. Select **Create**.

The network appears in the list. A new one is empty until Streamtime has
created it in the cloud; refresh the list to see its ID.
{% endcapture %}

{% capture curl %}
```bash
curl -X POST "$API/networks/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{{ include.network_body }}'
```

Returns `201` with the network. `identifier`, `provider` (the cloud account)
and `name` are required. Without `network_id`, Streamtime starts creating the
network in the cloud and fills `network_id` in when it's done: poll
`GET $API/networks/<network>/` until `network_id` has a value. With
`network_id`, nothing is created.
{% endcapture %}
{% capture python %}
The typed `Network` model marks server-set fields as required, so send the
body with the SDK's HTTP client:

```python
resp = client.get_httpx_client().post(
    f"/organizations/{ORG}/networks/",
    json={{ include.network_body }},
)
resp.raise_for_status()
print(resp.json()["identifier"])  # poll until "network_id" is set
```
{% endcapture %}
{% capture typescript %}
The generated `Network` type doesn't list every field the request takes, so
send the body through the client directly:

```typescript
const { data } = await client.post({
  url: "/organizations/{org_identifier}/networks/",
  path: { org_identifier: org },
  body: {{ include.network_body }},
});
console.log((data as { identifier: string }).identifier); // poll until network_id is set
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/networks/", json.RawMessage(`{{ include.network_body }}`))
// resp.StatusCode is 201; poll call("GET", "/networks/<network>/", nil)
// until "network_id" has a value.
```
{% endcapture %}
{%- capture tid -%}{{ p }}-network-create-api{%- endcapture -%}
{% capture api %}{% include code-tabs.html id=tid curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime network create --config '{{ include.network_body }}'
```

List networks with `streamtime network list -O json`, and show one with
`streamtime network get <network>`.
{% comment %}Gap: #1883 (the table output of list fails){% endcomment %}
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Create the network from the UI, API or CLI.
{% comment %}Gap: #1878{% endcomment %}
{% endcapture %}

{% capture terraform %}{{ include.network_terraform }}{% endcapture %}

{%- capture tid -%}{{ p }}-network-create{%- endcapture -%}
{% include tabs.html id=tid ui=ui api=api cli=cli mcp=mcp terraform=terraform %}

### Delete a network

{: .warning }
Deleting a network removes it from Streamtime only. The {% if k == "oci" %}VCN{% else %}VPC{% endif %} stays in your cloud
account, and so do the resources in it. Remove them in the cloud console
or CLI if you no longer need them.
{% comment %}Gap: #1860{% endcomment %}

{% capture ui %}
1. In the sidebar, select **Network**.
2. Select the delete icon on the network's row and confirm.
{% endcapture %}

{% capture curl %}
```bash
curl -X DELETE "$API/networks/<network>/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN"
```

Returns `204`.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.networks import organizations_networks_destroy

resp = organizations_networks_destroy.sync_detailed(ORG, "<network>", client=client)
print(resp.status_code)  # 204
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsNetworksDestroy } from "./client";

await organizationsNetworksDestroy({
  path: { org_identifier: org, identifier: "<network>" },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("DELETE", "/networks/<network>/", nil)
// resp.StatusCode is 204.
```
{% endcapture %}
{%- capture tid -%}{{ p }}-network-delete-api{%- endcapture -%}
{% capture api %}{% include code-tabs.html id=tid curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime network delete <network> --yes
```
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Delete the network from the UI, API or CLI.
{% comment %}Gap: #1878{% endcomment %}
{% endcapture %}

{% capture terraform %}
Remove the `streamtime_network` block and run `terraform apply`, or run
`terraform destroy -target=streamtime_network.<name>`. As above, this removes
the record from Streamtime and leaves the cloud network in place.
{% endcapture %}

{%- capture tid -%}{{ p }}-network-delete{%- endcapture -%}
{% include tabs.html id=tid ui=ui api=api cli=cli mcp=mcp terraform=terraform %}

---
{% endif %}

{% if include.create_section %}{{ include.create_section }}{% else %}
## Create a fleet

{% capture ui %}
1. In the sidebar, select **Fleet**, then **+ Add Fleet**.
2. **Bootstrap Provider**: choose **{{ n }}**, then select **Next**.

   {% include screenshot.html dir=s file="fleet-bootstrap-provider.png" alt="Bootstrap Provider step with the providers to choose from" %}
3. **Basic Configuration**: enter an **Identifier**, choose the **Tenancy**
   (Shared, Isolated or Dedicated), the **Base Domain** and **Max Tenants**
   (how many clusters the fleet can host). Under **Workloads**, choose what
   the fleet runs (Streaming, Stream Processing, Analytics) and how much
   capacity each gets; only the services those workloads need are installed.
   Optionally turn on **Enable autoscale for workload node pool** and
   **Enable AI**, and pick accounts under **How should this fleet be
   monitored?**

   {% include screenshot.html dir=s file="fleet-basic-config.png" alt="Basic Configuration step with identifier, tenancy, domain and workloads" %}
4. **Placement Configuration**: choose the cloud account and where the fleet
   runs (see [Fleet settings](#fleet-settings)).

   {% include screenshot.html dir=s file="fleet-placement-config.png" alt="Placement Configuration step with account and region" %}
5. **Advanced Configuration**: review the network and node settings.

   {% include screenshot.html dir=s file="fleet-advanced.png" alt="Advanced Configuration step with network and node settings" %}
6. Review the cost estimate on the right and select **Deploy**.

The fleet appears in the list as **Pending**, then **Provisioning**, then
**Healthy**. Creating the Kubernetes cluster can take 20 minutes or more.

{: .note }
If you leave the wizard early, the fleet is kept as a draft
(**Incomplete**). Open it from the list to pick up where you left off.
{% endcapture %}

{% capture curl %}
Creating a fleet takes two requests. The first saves the fleet; the second
starts provisioning it.

```bash
# 1. Save the fleet. The response includes "generation" and "configuration_state".
curl -X POST "$API/fleet/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "{{ f }}",
    "provider": "{{ k }}",
    "domain": "<base-domain>",
    "tenancy_mode": "Shared",
    "placement_config": {{ include.placement }},
    "advanced_config": {{ include.advanced }}
  }'

# 2. Start provisioning that generation.
curl -X POST "$API/fleet/{{ f }}/reconcile/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"generation": 1}'
```

`identifier`, `provider` and `domain` are required. Provisioning can start
only once `configuration_state` is `valid`: the placement and advanced
settings are complete. List the settings and their allowed values with
`GET $API/fleet/configuration-profiles/{{ k }}/placement-configuration/`
and `POST $API/fleet/configuration-profiles/{{ k }}/advanced-configuration/`.

Add `workloads` to choose what the fleet runs, for example
`{"streaming": {"enabled": true, "providers": ["strimzi"], "units": 6}}`.
Without it, every workload is enabled.

The second request returns `202` with the operation it started. Retrying
with the same `Idempotency-Key` returns that operation again. A `409` means
the generation is out of date (send the `generation` from
`GET $API/fleet/{{ f }}/`) or the configuration is incomplete.

Poll until `status` is `Healthy` (or `Error`):

```bash
curl -s "$API/fleet/{{ f }}/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
```
{% endcapture %}
{% capture python %}
The typed `FleetCreate` model can't be used for this request yet, so save
the fleet with the SDK's HTTP client, then start provisioning:

```python
import uuid

from streamtime_sdk.api.fleet import (
    organizations_fleet_reconcile_create,
    organizations_fleet_retrieve,
)
from streamtime_sdk.models import ReconcileRequest

resp = client.get_httpx_client().post(
    f"/organizations/{ORG}/fleet/",
    json={
        "identifier": "{{ f }}",
        "provider": "{{ k }}",
        "domain": "<base-domain>",
        "tenancy_mode": "Shared",
        "placement_config": {{ include.placement }},
        "advanced_config": {{ include.advanced }},
    },
)
resp.raise_for_status()
saved = resp.json()

if saved["configuration_state"] == "valid":
    organizations_fleet_reconcile_create.sync(
        ORG,
        "{{ f }}",
        client=client,
        body=ReconcileRequest(generation=saved["generation"]),
        idempotency_key=str(uuid.uuid4()),
    )

fleet = organizations_fleet_retrieve.sync(ORG, "{{ f }}", client=client)
print(fleet.status)  # Pending → Provisioning → Healthy
```
{% endcapture %}
{% capture typescript %}
The generated `FleetCreate` type marks server-set fields as required, so
send the body through the client directly, then start provisioning:

```typescript
import {
  organizationsFleetReconcileCreate,
  organizationsFleetRetrieve,
} from "./client";

const { data: saved } = await client.post({
  url: "/organizations/{org_identifier}/fleet/",
  path: { org_identifier: org },
  body: {
    identifier: "{{ f }}",
    provider: "{{ k }}",
    domain: "<base-domain>",
    tenancy_mode: "Shared",
    placement_config: {{ include.placement }},
    advanced_config: {{ include.advanced }},
  },
});

await organizationsFleetReconcileCreate({
  path: { org_identifier: org, identifier: "{{ f }}" },
  headers: { "Idempotency-Key": crypto.randomUUID() },
  body: { generation: (saved as { generation: number }).generation },
});

const { data } = await organizationsFleetRetrieve({
  path: { org_identifier: org, identifier: "{{ f }}" },
});
console.log(data?.status);
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/fleet/", json.RawMessage(`{
    "identifier": "{{ f }}",
    "provider": "{{ k }}",
    "domain": "<base-domain>",
    "tenancy_mode": "Shared",
    "placement_config": {{ include.placement }},
    "advanced_config": {{ include.advanced }}
}`))
if err != nil {
    return err
}
defer resp.Body.Close()

var saved struct {
    Generation         int    `json:"generation"`
    ConfigurationState string `json:"configuration_state"`
}
if err := json.NewDecoder(resp.Body).Decode(&saved); err != nil {
    return err
}

// Start provisioning that generation.
resp, err = call("POST", "/fleet/{{ f }}/reconcile/",
    map[string]any{"generation": saved.Generation}, newKey())
// Then poll: call("GET", "/fleet/{{ f }}/", nil) until "status" is "Healthy".
```
{% endcapture %}
{%- capture tid -%}{{ p }}-create-api{%- endcapture -%}
{% capture api %}{% include code-tabs.html id=tid curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime fleet create \
  --identifier {{ f }} \
  --provider {{ k }} \
  --domain <base-domain> \
  --tenancy-mode Shared \
  --streaming strimzi --streaming-units 6 \
  --placement-config '{{ include.placement }}' \
  --advanced-config '{{ include.advanced }}'
```

When the settings are complete, the command also starts provisioning. If
they aren't, it saves the fleet and says what's missing; finish the
settings, then run `streamtime fleet reconcile {{ f }}`.

Choose workloads with `--streaming`, `--stream-processing` and
`--analytics` (each takes a comma-separated list of providers) and their
`--…-units` options. Without them, every workload is enabled.
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Create the fleet from the UI, API or CLI.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% capture terraform %}
```hcl
resource "streamtime_fleet" "{{ rn }}" {
  identifier     = "{{ f }}"
  fleet_provider = "{{ k }}"
  domain         = "<base-domain>"
  tenancy_mode   = "Shared"

  placement_config = jsonencode({{ include.placement }})
  advanced_config  = jsonencode({{ include.advanced }})

  # The placement refers to the account by name, so tell Terraform to
  # create the account first.
  depends_on = [streamtime_cloud_account.{{ kn }}]

  timeouts = {
    create = "90m"
    delete = "60m"
  }
}
```

`terraform apply` saves the fleet, starts provisioning it, and waits until
it is ready, so allow for the {{ n }} cluster taking 20 minutes or more (the
`timeouts` block). Read the `placement_config` and `advanced_config` fields
{{ n }} accepts, and their allowed values, from the
`streamtime_fleet_configuration_profile` data source. They match the
API's [fleet settings](#fleet-settings).

Changes to `placement_config` or `advanced_config` on a running fleet are
saved but not applied yet (see [Update the fleet or the Agent](#update-the-fleet-or-the-agent)).
To manage a fleet that already exists, import it by identifier:
`terraform import streamtime_fleet.{{ rn }} {{ f }}`. See
[streamtime_fleet]({{ site.baseurl }}/terraform/fleet/).
{% endcapture %}

{%- capture tid -%}{{ p }}-create{%- endcapture -%}
{% include tabs.html id=tid ui=ui api=api cli=cli mcp=mcp terraform=terraform %}
{% endif %}

---

{% if include.status_section %}{{ include.status_section }}{% else %}
## Check fleet status

A fleet's **Status** is one of Incomplete, Pending, Provisioning, Updating,
Restarting, Deleting, Healthy or Error. The Agent's connection and the
installed components show whether Streamtime can reach the fleet and what
it runs.

{% capture ui %}
1. In the sidebar, select **Fleet**. Each fleet's status shows in the list.

   {% include screenshot.html dir=s file="fleet-list.png" alt="Fleet list showing each fleet's status" %}
2. Open the fleet. **Overview** shows its status, tenancy, Kafka Units and
   capacity. **Endpoints** lists its addresses, and **Monitoring** its
   metrics.

   {% include screenshot.html dir=s file="fleet-detail.png" alt="Fleet overview with status, tenancy and capacity" %}
3. **Agent Management** shows whether the Agent is installed and connected,
   with the history of its operations.

   {% include screenshot.html dir=s file="fleet-agent.png" alt="Agent Management tab with the Agent's connection status" %}
{% endcapture %}

{% capture curl %}
```bash
# Status and provisioning state
curl -s "$API/fleet/{{ f }}/" -H "Authorization: Bearer $STREAMTIME_TOKEN"

# Collect a fresh health report from the fleet (waits for the answer)
curl -s -X POST "$API/fleet/{{ f }}/status/" -H "Authorization: Bearer $STREAMTIME_TOKEN"

# The Agent's connection
curl -s "$API/fleet/{{ f }}/agent/" -H "Authorization: Bearer $STREAMTIME_TOKEN"

# Installed components
curl -s "$API/fleet/{{ f }}/installed-components/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
```

In the fleet, `status` is the fleet's state and `reconciliation_state` the
state of its last operation (`queued`, `running`, `succeeded` or
`failed`). `GET $API/fleet/{{ f }}/status/` returns the last health report
without collecting a new one. The Agent's `status` reads
`bootstrap_complete` once it is installed and the fleet is set up.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.agent import get_agent_connection
from streamtime_sdk.api.fleet import organizations_fleet_retrieve
from streamtime_sdk.api.fleet_metrics import organizations_fleet_status_create

fleet = organizations_fleet_retrieve.sync(ORG, "{{ f }}", client=client)
print(fleet.status, fleet.reconciliation_state)

report = organizations_fleet_status_create.sync_detailed(ORG, "{{ f }}", client=client)
print(report.content.decode())

agent = get_agent_connection.sync_detailed(ORG, "{{ f }}", client=client)
print(agent.content.decode())
```
{% endcapture %}
{% capture typescript %}
```typescript
import {
  getAgentConnection,
  organizationsFleetRetrieve,
  organizationsFleetStatusCreate,
} from "./client";

const { data: fleet } = await organizationsFleetRetrieve({
  path: { org_identifier: org, identifier: "{{ f }}" },
});
console.log(fleet?.status, fleet?.reconciliation_state);

const report = await organizationsFleetStatusCreate({
  path: { org_identifier: org, fleet_id: "{{ f }}" },
});
const agent = await getAgentConnection({
  path: { org_identifier: org, fleet_id: "{{ f }}" },
});
console.log(report.data, agent.data);
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("GET", "/fleet/{{ f }}/", nil)
// Decode "status" and "reconciliation_state" from resp.Body.

resp, err = call("POST", "/fleet/{{ f }}/status/", nil)  // fresh health report
resp, err = call("GET", "/fleet/{{ f }}/agent/", nil)    // Agent connection
```
{% endcapture %}
{%- capture tid -%}{{ p }}-status-api{%- endcapture -%}
{% capture api %}{% include code-tabs.html id=tid curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime fleet list
streamtime fleet get {{ f }}
streamtime fleet status {{ f }}
streamtime fleet kubeconfig {{ f }} --save ./{{ f }}.kubeconfig
```

`fleet status` shows the last health report. Showing the Agent's
connection or the installed components isn't available in the CLI yet.
{% endcapture %}

{% capture mcp %}
Ask your assistant, for example: *"Is the {{ f }} fleet healthy?"* or
*"What alerts fired on {{ f }} in the last hour?"*

It uses `get_fleet_status` (pass `refresh` to collect a fresh report),
`list_fleet_resources`, `get_fleet_alerts`, `get_fleet_logs` and
`get_fleet_metric`.
{% endcapture %}

{%- capture tid -%}{{ p }}-status{%- endcapture -%}
{% include tabs.html id=tid ui=ui api=api cli=cli mcp=mcp %}

{% endif %}
---

{% if include.update_section %}{{ include.update_section }}{% else %}
## Update the fleet or the Agent

You can turn the workload node pool's autoscaling on or off, and change the
accounts that receive the fleet's monitoring data. Streamtime can't apply
changes to a fleet's placement or advanced settings yet: they are saved,
but the update operation fails. To change them, create a new fleet.

The Agent is the Streamtime component that runs inside the fleet. Update it
to a new version from **Agent Management**.

{% capture ui %}
1. Open the fleet and select **Agent Management**.
2. Open the actions menu (**⋮**) and select **Update Agent**.
3. In **Update Streamtime Agent**, choose the **Target** (Worker or
   Operator) and the **Registry**, then set the **Image Tag** (leave it
   empty for the latest), or the **Chart Version** or **Helm Values** you
   want to change. Start the update.

   {% include screenshot.html dir=s file="agent-update.png" alt="Update Streamtime Agent dialog with target, registry and version" %}

The operation shows under **Command History** until it finishes.
{% endcapture %}

{% capture curl %}
```bash
# Turn autoscaling of the workload node pool off
curl -X PATCH "$API/fleet/{{ f }}/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"autoscale": false}'

# Update the Agent to a new version
curl -X POST "$API/fleet/{{ f }}/agent/UpdateStreamtimeAgentWorkflow/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "update_types": ["agent"],
    "registry_url": "<registry>",
    "repository": "<repository>",
    "agent": {"image_tag": "<version>"}
  }'
```

`registry_url` and `repository` are where your Streamtime installation
publishes the Agent image; ask your Streamtime administrator. The update
returns `201` with the operation it started. Follow it with
`GET $API/fleet/{{ f }}/agent/`.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.fleet import organizations_fleet_partial_update
from streamtime_sdk.api.fleet_tasks import dispatch_agent_task
from streamtime_sdk.models import DispatchAgentTaskWorkflowType, PatchedFleet

organizations_fleet_partial_update.sync(
    ORG, "{{ f }}", client=client, body=PatchedFleet(autoscale=False)
)

resp = dispatch_agent_task.sync_detailed(
    ORG,
    "{{ f }}",
    DispatchAgentTaskWorkflowType.UPDATESTREAMTIMEAGENTWORKFLOW,
    client=client,
    body={
        "update_types": ["agent"],
        "registry_url": "<registry>",
        "repository": "<repository>",
        "agent": {"image_tag": "<version>"},
    },
)
print(resp.status_code)  # 201
```
{% endcapture %}
{% capture typescript %}
```typescript
import { dispatchAgentTask, organizationsFleetPartialUpdate } from "./client";

await organizationsFleetPartialUpdate({
  path: { org_identifier: org, identifier: "{{ f }}" },
  body: { autoscale: false },
});

await dispatchAgentTask({
  path: {
    org_identifier: org,
    fleet_id: "{{ f }}",
    workflow_type: "UpdateStreamtimeAgentWorkflow",
  },
  body: {
    update_types: ["agent"],
    registry_url: "<registry>",
    repository: "<repository>",
    agent: { image_tag: "<version>" },
  },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("PATCH", "/fleet/{{ f }}/", map[string]any{"autoscale": false})

resp, err = call("POST", "/fleet/{{ f }}/agent/UpdateStreamtimeAgentWorkflow/", map[string]any{
    "update_types": []string{"agent"},
    "registry_url": "<registry>",
    "repository":   "<repository>",
    "agent":        map[string]any{"image_tag": "<version>"},
})
// resp.StatusCode is 201 once the update has started.
```
{% endcapture %}
{%- capture tid -%}{{ p }}-update-api{%- endcapture -%}
{% capture api %}{% include code-tabs.html id=tid curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet. Update the fleet or the Agent from the UI or
the API.
{% comment %}Gap: #1812{% endcomment %}
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Update the fleet or the Agent from the UI or the
API.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{%- capture tid -%}{{ p }}-update{%- endcapture -%}
{% include tabs.html id=tid ui=ui api=api cli=cli mcp=mcp %}

{% endif %}
---

## Delete the fleet

Delete every cluster and workload on the fleet first; Streamtime refuses to
delete a fleet that still hosts one. Deleting the fleet removes the
resources Streamtime created for it.

{% capture ui %}
1. In the sidebar, select **Fleet**.
2. Open the fleet's menu in the list, select **Delete**, and confirm.

   {% include screenshot.html dir=s file="fleet-delete.png" alt="Delete confirmation for the fleet" %}

The fleet shows **Deleting**, then disappears from the list.
{% endcapture %}

{% capture curl %}
```bash
curl -X DELETE "$API/fleet/{{ f }}/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
```

Returns `202` with the delete operation it started. `403` means the fleet
still hosts Kafka clusters; `409` means it still has Kafka Connect
clusters, replicators or virtual Kafka clusters. Delete those first. Poll
`GET $API/fleet/{{ f }}/`: it shows `Deleting`, then returns `404` once
the fleet is gone.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.fleet import organizations_fleet_destroy

resp = organizations_fleet_destroy.sync_detailed(ORG, "{{ f }}", client=client)
print(resp.status_code)  # 202; 403 or 409 while workloads remain
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsFleetDestroy } from "./client";

await organizationsFleetDestroy({
  path: { org_identifier: org, identifier: "{{ f }}" },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("DELETE", "/fleet/{{ f }}/", nil)
// resp.StatusCode is 202 (403 or 409 while workloads remain);
// poll GET /fleet/{{ f }}/ until it returns 404.
```
{% endcapture %}
{%- capture tid -%}{{ p }}-delete-api{%- endcapture -%}
{% capture api %}{% include code-tabs.html id=tid curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime fleet delete {{ f }} --yes
```
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Delete the fleet from the UI, API or CLI.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% capture terraform %}
```bash
terraform destroy -target=streamtime_fleet.{{ rn }}
```

Or remove the `streamtime_fleet` block and run `terraform apply`. Terraform
starts the delete and waits until the fleet is gone (the `delete` timeout).
Streamtime refuses the delete while the fleet still hosts workloads, so
remove those first.
{% endcapture %}

{%- capture tid -%}{{ p }}-delete{%- endcapture -%}
{% include tabs.html id=tid ui=ui api=api cli=cli mcp=mcp terraform=terraform %}

{% if include.remove_account_section %}{{ include.remove_account_section }}{% else %}
---

## Remove the cloud account

{: .warning }
Delete every fleet on the account first, and wait until they are gone.
Streamtime doesn't stop you from removing an account that fleets still use,
and without it those fleets can't be torn down.

{% capture ui %}
1. Go to **Settings**, then **Bootstrap Providers**.
2. Select **Delete** on the account and confirm.
{% endcapture %}

{% capture curl %}
```bash
curl -X DELETE "$API/bootstrap-providers/<cloud-account>/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN"
```

Returns `204`.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.bootstrap_providers import organizations_bootstrap_providers_destroy

resp = organizations_bootstrap_providers_destroy.sync_detailed(
    ORG, "<cloud-account>", client=client
)
print(resp.status_code)  # 204
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsBootstrapProvidersDestroy } from "./client";

await organizationsBootstrapProvidersDestroy({
  path: { org_identifier: org, identifier: "<cloud-account>" },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("DELETE", "/bootstrap-providers/<cloud-account>/", nil)
// resp.StatusCode is 204.
```
{% endcapture %}
{%- capture tid -%}{{ p }}-remove-account-api{%- endcapture -%}
{% capture api %}{% include code-tabs.html id=tid curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime provider delete <cloud-account> --yes
```
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Remove the account from the UI, API or CLI.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% capture terraform %}
```bash
# Preview what will be removed, then remove it.
terraform plan -destroy -target=streamtime_cloud_account.{{ kn }}
terraform destroy -target=streamtime_cloud_account.{{ kn }}
```

Terraform deletes the fleets that depend on the account first when they are
in the same configuration, so check that the plan lists them. It only follows
dependencies it can see: fleets managed in another configuration or outside
Terraform aren't checked, so delete them first, as above.
{% endcapture %}

{%- capture tid -%}{{ p }}-remove-account{%- endcapture -%}
{% include tabs.html id=tid ui=ui api=api cli=cli mcp=mcp terraform=terraform %}
{% endif %}
