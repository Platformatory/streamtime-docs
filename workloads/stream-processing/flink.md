---
title: Apache Flink
parent: Stream Processing
grand_parent: Workloads
nav_order: 1
---

# Apache Flink

Streamtime runs Flink on a Kubernetes fleet and keeps it monitored and up
to date. A Flink deployment runs in one of two modes:

- **Application** (a single-job cluster): the cluster runs one job, from
  an application JAR or a registered Flink project version, and is sized
  in **Flink Units**.
- **Session**: a shared cluster, sized up to **Max Flink Units**, that
  you submit jobs to. Each job claims Flink Units from it.

## Key Features

- **Open-source Apache Flink or Confluent Flink**, chosen as the
  **Provider**.
- **Sized in Flink Units**, with an **Optimization Goal** (Cost, Balanced
  or Performance) and a **State Backend Tier** (Stateless, Light, Heavy or
  Heavy-RocksDB).
- **Savepoints and upgrade modes** (stateless, savepoint or last-state)
  for safe job upgrades.
- **Flink Web UI**, optionally, and metrics, logs and alerts for every
  deployment.
- **Flink projects**: CI registers each build from your own artifact store
  as a version, and deployments run it by version. See
  [Flink projects](index.html#flink-projects).

## Settings

**Basic Configuration**: **Identifier**, **Description**, **Provider**,
the mode, and **Flink Units** (application) or **Max Flink Units**
(session).

**Fleet Selection**: the fleet to run on, or let Streamtime choose one.

**Advanced Configuration**

- For application mode: the **application JAR** location (or a project
  version), entry class or Python entry file, and arguments.
- For session mode: the **Job Language**, Java (the default) or Python. Python
  installs the image that runs PyFlink jobs and needs no project to exist
  first. A Python release is refused on a Java workspace, and the language
  cannot change once the workspace has jobs.
- **Parallelism** and **upgrade mode**; savepoint strategy.
- **Optimization Goal** and **State Backend Tier**.
- **Web UI Enabled**, Flink configuration (`flink_conf`), and JobManager
  and TaskManager resources.
- The chart **Version**, to upgrade.

---

{% capture create_section %}
## Create a Flink deployment

{% capture ui %}
1. In the sidebar, select **Flink**, then **Create Flink**.
2. **Basic Configuration**: enter the **Identifier**, choose the
   **Provider** and the mode, and set **Flink Units** (application) or
   **Max Flink Units** (session).
3. **Fleet Selection**: choose the fleet.
4. **Advanced Configuration**: for session mode, choose the **Job Language**
   (Java or Python); for application mode, the JAR or project
   version to run; then parallelism, upgrade mode, **Optimization Goal**,
   **State Backend Tier** and **Web UI Enabled**.
5. Create it. It shows **Pending**, then **Provisioning**, then
   **Healthy**.

{% include screenshot.html dir="flink" file="create.png" alt="Flink Basic Configuration step with provider, mode and Flink Units" %}
{% endcapture %}

{% capture curl %}
```bash
# 1. Save a session cluster. The response includes "generation".
curl -X POST "$API/flink/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "analytics",
    "mode": "session",
    "provider": "open-source",
    "max_flink_units": 8,
    "advanced_configuration": {"optimization_goal": "Balanced", "state_tier": "Light"}
  }'

# 2. Provision it
curl -X POST "$API/flink/analytics/reconcile/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"generation": 1}'
```

`identifier` and `mode` are required. For application mode, send
`flink_units` and either `advanced_configuration.application_jar` or
`project_version` (`{"project": "<project>", "version": "<version>"}`).
Add `"fleet": "<fleet>"` to choose the fleet.
{% endcapture %}
{% capture python %}
```python
import uuid

from streamtime_sdk.api.flink import organizations_flink_reconcile_create
from streamtime_sdk.models import ReconcileRequest

resp = client.get_httpx_client().post(
    f"/organizations/{ORG}/flink/",
    json={
        "identifier": "analytics",
        "mode": "session",
        "provider": "open-source",
        "max_flink_units": 8,
        "advanced_configuration": {"optimization_goal": "Balanced", "state_tier": "Light"},
    },
)
resp.raise_for_status()

organizations_flink_reconcile_create.sync(
    ORG,
    "analytics",
    client=client,
    body=ReconcileRequest(generation=resp.json()["generation"]),
    idempotency_key=str(uuid.uuid4()),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsFlinkReconcileCreate } from "./client";

const { data: saved } = await client.post({
  url: "/organizations/{org_identifier}/flink/",
  path: { org_identifier: org },
  body: {
    identifier: "analytics",
    mode: "session",
    provider: "open-source",
    max_flink_units: 8,
    advanced_configuration: { optimization_goal: "Balanced", state_tier: "Light" },
  },
});

await organizationsFlinkReconcileCreate({
  path: { org_identifier: org, identifier: "analytics" },
  headers: { "Idempotency-Key": crypto.randomUUID() },
  body: { generation: (saved as { generation: number }).generation },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/flink/", map[string]any{
    "identifier":      "analytics",
    "mode":            "session",
    "provider":        "open-source",
    "max_flink_units": 8,
    "advanced_configuration": map[string]any{
        "optimization_goal": "Balanced", "state_tier": "Light",
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
resp, err = call("POST", "/flink/analytics/reconcile/",
    map[string]any{"generation": saved.Generation}, newKey())
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="flink-create-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime flink create \
  --identifier analytics \
  --mode session \
  --runtime python \
  --fleet <fleet>
```

`--runtime` is `java` (the default) or `python`, and applies to session mode
only. The API field is `advanced_configuration.runtime`.

The CLI saves the deployment but can't start provisioning it yet. Start it
from the UI, or with the API's reconcile request.
{% comment %}Gap: #1818{% endcomment %}
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Create the deployment from the UI, API or CLI.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% include tabs.html id="flink-create" ui=ui api=api cli=cli mcp=mcp %}
{% endcapture %}

{% capture extra_section %}
## Submit and manage jobs (session mode)

A session cluster runs the jobs you submit to it. Each job claims Flink
Units from the cluster's **Max Flink Units**. Submitting a job starts it
straight away.

{% capture ui %}
1. Open the session deployment from **Flink** and select **Submit Job**
   (**Submit First Job** when it has none yet).
2. Enter the **Job Identifier** and its **Flink Units**, then the JAR or
   project version, parallelism and upgrade mode, and select **Submit
   Flink Job**.
3. Open a job to see its status, change it or delete it.
{% endcapture %}

{% capture curl %}
```bash
# Submit a job
curl -X POST "$API/flink/analytics/jobs/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "clickstream",
    "flink_units": 2,
    "advanced_configuration": {
      "application_jar": "<jar-url>",
      "parallelism": 2,
      "upgrade_mode": "savepoint"
    }
  }'

# List jobs, check one, delete one
curl -s "$API/flink/analytics/jobs/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
curl -s "$API/flink/analytics/jobs/clickstream/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
curl -X DELETE "$API/flink/analytics/jobs/clickstream/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
```

Change a running job with `PATCH $API/flink/analytics/jobs/clickstream/`
(for example a new `flink_units` or `advanced_configuration`).
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.flink import (
    organizations_flink_jobs_create,
    organizations_flink_jobs_destroy,
    organizations_flink_jobs_list,
)
from streamtime_sdk.models import FlinkJobCreateSchema

job = organizations_flink_jobs_create.sync(
    ORG,
    "analytics",
    client=client,
    body=FlinkJobCreateSchema.from_dict({
        "identifier": "clickstream",
        "flink_units": 2,
        "advanced_configuration": {
            "application_jar": "<jar-url>",
            "parallelism": 2,
            "upgrade_mode": "savepoint",
        },
    }),
)

jobs = organizations_flink_jobs_list.sync_detailed(ORG, "analytics", client=client)
print(jobs.content.decode())

organizations_flink_jobs_destroy.sync_detailed(ORG, "analytics", "clickstream", client=client)
```
{% endcapture %}
{% capture typescript %}
```typescript
import {
  organizationsFlinkJobsCreate,
  organizationsFlinkJobsDestroy,
  organizationsFlinkJobsList,
} from "./client";

await organizationsFlinkJobsCreate({
  path: { org_identifier: org, flink_identifier: "analytics" },
  body: {
    identifier: "clickstream",
    flink_units: 2,
    advanced_configuration: {
      application_jar: "<jar-url>",
      parallelism: 2,
      upgrade_mode: "savepoint",
    },
  },
});

const { data: jobs } = await organizationsFlinkJobsList({
  path: { org_identifier: org, flink_identifier: "analytics" },
});
console.log(jobs);

await organizationsFlinkJobsDestroy({
  path: { org_identifier: org, flink_identifier: "analytics", identifier: "clickstream" },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/flink/analytics/jobs/", map[string]any{
    "identifier":  "clickstream",
    "flink_units": 2,
    "advanced_configuration": map[string]any{
        "application_jar": "<jar-url>",
        "parallelism":     2,
        "upgrade_mode":    "savepoint",
    },
})

resp, err = call("GET", "/flink/analytics/jobs/", nil)
resp, err = call("DELETE", "/flink/analytics/jobs/clickstream/", nil)
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="flink-jobs-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime flink job create analytics \
  --identifier clickstream \
  --application-jar <jar-url> \
  --parallelism 2 \
  --upgrade-mode savepoint

streamtime flink job list analytics
streamtime flink job get analytics clickstream
streamtime flink job delete analytics clickstream --yes
```

Use `--project-version PROJECT@VERSION` instead of `--application-jar` to
run a registered project version. Setting a job's Flink Units, or changing
a job, isn't available in the CLI yet; jobs it creates get 1 Flink Unit.
{% comment %}Gap: #1819{% endcomment %}
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Submit and manage jobs from the UI or API.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% include tabs.html id="flink-jobs" ui=ui api=api cli=cli mcp=mcp %}
{% endcapture %}

{% capture update_note %}
Change the Flink Units, the advanced settings (parallelism, upgrade mode,
resources, Flink configuration), or upgrade to a new **Version**
(`advanced_configuration.chart_config.main.version`). With the
`savepoint` upgrade mode, Streamtime takes a savepoint first and resumes
the job from it.
{% endcapture %}
{% capture update_body %}{"max_flink_units": 12}{% endcapture %}

{% include workload-tasks.md name="Flink" id="flink" res="analytics" path="flink" py_mod="flink" py_fn="organizations_flink" ts_fn="organizationsFlink" menu="Flink" cli="flink" cli_gap="1818" has_status="yes" update_body=update_body update_note=update_note create_section=create_section extra_section=extra_section shots="flink" %}
