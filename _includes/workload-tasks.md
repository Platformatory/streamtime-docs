{%- comment -%}
  The lifecycle tasks the non-Kafka workload pages share (status, update,
  monitoring, delete), each in UI / API / CLI / MCP tabs with HTTP / Python /
  TypeScript / Go API sub-tabs. The page supplies its own create task, and
  any extra tasks (jobs, connectors), as captured sections.

    {% include workload-tasks.md name="ClickHouse" id="ch" res="events" path="clickhouses"
         py_mod="click_house" py_fn="organizations_clickhouses" ts_fn="organizationsClickhouses"
         menu="ClickHouse" cli="clickhouse" create_section=create_section %}

  Params:
    name         product name as the UI shows it
    id           unique, kebab-case prefix for this page's tab ids
    res          example identifier used in every snippet
    path         API path of the resource under $API (e.g. clickhouses, or
                 fleet/<fleet>/kafka/kvc for fleet-nested resources)
    py_mod       Python SDK module under streamtime_sdk.api
    py_fn        Python SDK function prefix (…_retrieve, …_reconcile_create,
                 …_destroy are appended)
    py_mod_reconcile
                 optional module holding …_reconcile_create, when it differs
                 from py_mod
    py_args      optional Python path arguments (default: ORG, "<res>")
    ts_fn        TypeScript function prefix (…Retrieve, …ReconcileCreate,
                 …Destroy are appended)
    ts_path      optional TypeScript path object
                 (default: { org_identifier: org, identifier: "<res>" })
    menu         the sidebar entry that lists this resource
    cli          CLI command group (streamtime <cli> list / get / delete)
    cli_reconcile  "yes" when the CLI group has `reconcile`
    cli_gap      optional issue number: the CLI can save but not provision
    has_status   "yes" when the resource has a /status/ endpoint
    update_body  JSON object: an example PATCH body
    update_note  captured markdown: what an update can change
    mcp_status   optional captured markdown for the status task's MCP tab
    create_section, extra_section
                 captured markdown (heading and tabs); create_section is
                 required, extra_section goes after the status task
    shots        optional folder under assets/images/ with UI screenshots:
                 list.png, detail.png, monitoring.png, delete.png
    tf_update, tf_delete
                 optional captured markdown for the update and delete tasks'
                 Terraform tab; pass them only when a provider resource covers
                 the resource
{%- endcomment -%}
{%- assign n = include.name -%}
{%- assign p = include.id -%}
{%- assign r = include.res -%}
{%- assign u = include.path -%}
{%- assign s = include.shots -%}
{%- capture pyargs_default -%}ORG, "{{ r }}"{%- endcapture -%}
{%- assign pa = include.py_args | default: pyargs_default -%}
{%- capture tspath_default -%}{ org_identifier: org, identifier: "{{ r }}" }{%- endcapture -%}
{%- assign tp = include.ts_path | default: tspath_default -%}
{%- assign prm = include.py_mod_reconcile | default: include.py_mod -%}

## Before you start

- A fleet in **Healthy** state with room for the {{ n }} workload (see
  [Fleet management]({{ site.baseurl }}/fleet-management/)).
- For the API: an access token in `STREAMTIME_TOKEN` and your organization
  identifier in place of `<org>`. Replace `api.example.com` with your
  Streamtime API address.

{% include api-setup.md id=p %}

Saving a {{ n }} resource and provisioning it are separate steps in the
API: create or change it, then **reconcile** its new `generation`. The
reconcile returns `202` with the operation it started; the same
`Idempotency-Key` returns that operation again, and a `409` means the
generation is out of date.

---

{{ include.create_section }}

---

## Check status

`status` is one of Pending, Provisioning, Updating, Healthy, Error or
Deleting.

{% capture ui %}
1. In the sidebar, select **{{ include.menu }}**. Each entry shows its
   status.

   {% include screenshot.html dir=s file="list.png" alt="List with each entry's status" %}
2. Open it. **Overview** shows its status, settings and endpoints.

   {% include screenshot.html dir=s file="detail.png" alt="Overview with status and settings" %}
{% endcapture %}

{% capture curl %}
```bash
curl -s "$API/{{ u }}/{{ r }}/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
{%- if include.has_status == "yes" %}

# Collect a fresh status report (waits for the answer)
curl -s -X POST "$API/{{ u }}/{{ r }}/status/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
{%- endif %}
```
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.{{ include.py_mod }} import {{ include.py_fn }}_retrieve

res = {{ include.py_fn }}_retrieve.sync({{ pa }}, client=client)
print(res.status)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { {{ include.ts_fn }}Retrieve } from "./client";

const { data } = await {{ include.ts_fn }}Retrieve({ path: {{ tp }} });
console.log(data?.status);
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("GET", "/{{ u }}/{{ r }}/", nil)
// Decode "status" from resp.Body.
```
{% endcapture %}
{%- capture tid -%}{{ p }}-status-api{%- endcapture -%}
{% capture api %}{% include code-tabs.html id=tid curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime {{ include.cli }} list
streamtime {{ include.cli }} get {{ r }}
```
{% endcapture %}

{% capture mcp %}
{% if include.mcp_status %}{{ include.mcp_status }}{% else %}
Not available in MCP yet. Check the status from the UI, API or CLI.
{% comment %}Gap: #1811{% endcomment %}
{% endif %}
{% endcapture %}

{%- capture tid -%}{{ p }}-status{%- endcapture -%}
{% include tabs.html id=tid ui=ui api=api cli=cli mcp=mcp %}

{% if include.extra_section %}
---

{{ include.extra_section }}
{% endif %}

---

## Change the configuration or upgrade

{{ include.update_note }}

{% capture ui %}
1. Open it from **{{ include.menu }}** and select **Configuration** (or
   **Edit**).
2. Change the settings, then save. Streamtime applies the change, and the
   status shows **Updating**, then **Healthy**.
{% endcapture %}

{% capture curl %}
```bash
# 1. Save the change. The response includes the new "generation".
GEN=$(curl -s -X PATCH "$API/{{ u }}/{{ r }}/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{{ include.update_body }}' | jq .generation)

# 2. Apply it
curl -X POST "$API/{{ u }}/{{ r }}/reconcile/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d "{\"generation\": $GEN}"
```
{% endcapture %}
{% capture python %}
The SDK has no typed call for this update yet, so save it with the SDK's
HTTP client, then apply it:

```python
import uuid

from streamtime_sdk.api.{{ prm }} import {{ include.py_fn }}_reconcile_create
from streamtime_sdk.models import ReconcileRequest

resp = client.get_httpx_client().patch(
    f"/organizations/{ORG}/{{ u }}/{{ r }}/",
    json={{ include.update_body }},
)
resp.raise_for_status()

{{ include.py_fn }}_reconcile_create.sync(
    {{ pa }},
    client=client,
    body=ReconcileRequest(generation=resp.json()["generation"]),
    idempotency_key=str(uuid.uuid4()),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { {{ include.ts_fn }}ReconcileCreate } from "./client";

const { data: saved } = await client.patch({
  url: "/organizations/{org_identifier}/{{ u }}/{{ r }}/",
  path: { org_identifier: org },
  body: {{ include.update_body }},
});

await {{ include.ts_fn }}ReconcileCreate({
  path: {{ tp }},
  headers: { "Idempotency-Key": crypto.randomUUID() },
  body: { generation: (saved as { generation: number }).generation },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("PATCH", "/{{ u }}/{{ r }}/", json.RawMessage(`{{ include.update_body }}`))
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
resp, err = call("POST", "/{{ u }}/{{ r }}/reconcile/",
    map[string]any{"generation": saved.Generation}, newKey())
```
{% endcapture %}
{%- capture tid -%}{{ p }}-update-api{%- endcapture -%}
{% capture api %}{% include code-tabs.html id=tid curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
{% if include.cli_reconcile == "yes" %}
Changing the settings isn't available in the CLI yet; save them from the UI
or API. Then apply the change:

```bash
streamtime {{ include.cli }} reconcile {{ r }}
```
{% comment %}Gap: #1812{% endcomment %}
{% else %}
Not available in the CLI yet. Change the configuration from the UI or API.
{% if include.cli_gap %}{% comment %}Gap: #{{ include.cli_gap }}{% endcomment %}{% endif %}
{% endif %}
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Change the configuration from the UI or API.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{%- capture tid -%}{{ p }}-update{%- endcapture -%}
{% include tabs.html id=tid ui=ui api=api cli=cli mcp=mcp terraform=include.tf_update %}

---

## View metrics, logs and alerts

{% capture ui %}
Open it from **{{ include.menu }}** and select **Monitoring** for its
metrics and logs, and **Alert Rules** (where shown) for the alerts that
watch it. Alerts that fire also appear on the fleet's **Monitoring** tab.

{% include screenshot.html dir=s file="monitoring.png" alt="Monitoring tab with metrics and logs" %}
{% endcapture %}

{% capture curl %}
Metrics and logs are read through the fleet that runs it:

```bash
curl -s "$API/fleet/<fleet>/metrics/overview/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
curl -s "$API/fleet/<fleet>/alerts/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
```
{% endcapture %}
{% capture python %}
```python
resp = client.get_httpx_client().get(f"/organizations/{ORG}/fleet/<fleet>/alerts/")
print(resp.json())
```
{% endcapture %}
{% capture typescript %}
```typescript
const { data: alerts } = await client.get({
  url: "/organizations/{org_identifier}/fleet/{fleet_id}/alerts/",
  path: { org_identifier: org, fleet_id: "<fleet>" },
});
console.log(alerts);
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("GET", "/fleet/<fleet>/alerts/", nil)
```
{% endcapture %}
{%- capture tid -%}{{ p }}-monitor-api{%- endcapture -%}
{% capture api %}{% include code-tabs.html id=tid curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
# The fleet's logs from the last hour
streamtime logs fleet <fleet> --since 60
```

Reading metrics or alerts isn't available in the CLI yet.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% capture mcp %}
Ask your assistant, for example: *"Any alerts on the {{ r }} {{ n }}
workload today?"* or *"Show its error logs from the last hour."*

It uses `get_fleet_alerts`, `get_fleet_logs`, `list_fleet_metrics` and
`get_fleet_metric` on the fleet that runs it.
{% endcapture %}

{%- capture tid -%}{{ p }}-monitor{%- endcapture -%}
{% include tabs.html id=tid ui=ui api=api cli=cli mcp=mcp %}

---

## Delete

Deleting removes what Streamtime installed for it on the fleet.

{% capture ui %}
1. In the sidebar, select **{{ include.menu }}**.
2. Open its menu in the list, select **Delete**, and confirm.

   {% include screenshot.html dir=s file="delete.png" alt="Delete confirmation" %}

The status shows **Deleting**, then it disappears from the list.
{% endcapture %}

{% capture curl %}
```bash
curl -X DELETE "$API/{{ u }}/{{ r }}/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
```

A draft that was never provisioned is removed at once; otherwise the
teardown starts. Poll `GET $API/{{ u }}/{{ r }}/` until it returns `404`.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.{{ include.py_mod }} import {{ include.py_fn }}_destroy

{{ include.py_fn }}_destroy.sync_detailed({{ pa }}, client=client)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { {{ include.ts_fn }}Destroy } from "./client";

await {{ include.ts_fn }}Destroy({ path: {{ tp }} });
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("DELETE", "/{{ u }}/{{ r }}/", nil)
```
{% endcapture %}
{%- capture tid -%}{{ p }}-delete-api{%- endcapture -%}
{% capture api %}{% include code-tabs.html id=tid curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime {{ include.cli }} delete {{ r }} --yes
```
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Delete it from the UI, API or CLI.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{%- capture tid -%}{{ p }}-delete{%- endcapture -%}
{% include tabs.html id=tid ui=ui api=api cli=cli mcp=mcp terraform=include.tf_delete %}
