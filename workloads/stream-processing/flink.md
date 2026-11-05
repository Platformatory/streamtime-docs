---
title: Apache Flink
parent: Stream Processing
grand_parent: Workloads
nav_order: 1
---

# Apache Flink

Streamtime runs Flink on a Kubernetes fleet and keeps it monitored and up
to date. **Apache Flink** runs in a **Job Workspace** (session mode): a shared
cluster, sized up to **Max Flink Units**, that you submit jobs to. Each job
claims Flink Units from it. Apache Flink does not offer a single-job cluster.

**Confluent Manager for Flink** keeps its single-job cluster (application
mode): the cluster runs one job, from an application JAR or a registered Flink
project version, and is sized in **Flink Units**.

## Key Features

- **Open-source Apache Flink or Confluent Flink**, chosen as the
  **Provider**.
- **Sized in Flink Units**, with an **Optimization Goal** (Cost, Balanced
  or Performance). Streamtime derives the rest from the Flink Units: each
  TaskManager gets min(Flink Units, 4) slots and the cluster gets enough
  TaskManagers to cover them. A job runs as wide as the Flink Units it was
  given. These numbers are provisional. What a Flink Unit is, and what it
  takes from the fleet: [Capacity units]({{ site.baseurl }}/about/scaling/#flink-units).
- **RocksDB state** in every Job Workspace.
- **Checkpoints and savepoints on by default.** On a kind or BYOK fleet they go
  to the fleet's RustFS, in the `flink` bucket under
  `<organization>/<cluster>`, and the last 3 checkpoints are kept. A job that
  stops or restarts resumes from them. Deleting the cluster removes its
  folder. The fleet's RustFS holds one shared credential for all clusters, so
  any cluster on the fleet can read another's state. Cloud fleets have no
  durable store yet and keep state on the pods' temporary disk, so **Keep
  running state** and **Resume from the latest checkpoint** are refused there.
- **State handling** per job: **Start fresh** (stateless), **Keep running
  state** (savepoint) or **Resume from the latest checkpoint** (last-state).
- **Flink Web UI** on every deployment, with metrics, logs and alerts.
- **Flink projects**: CI registers each build from your own artifact store
  as a version, and deployments run it by version. See
  [Flink projects]({{ site.baseurl }}/workloads/stream-processing/flink-projects/).

## Settings

**Provider**: Apache Flink or Confluent Manager for Flink.

**Basic Configuration**: **Identifier**, **Description**, and **Max Flink
Units** (Job Workspace) or **Flink Units** (Confluent single-job cluster) with
the **Optimization Goal**. For Apache Flink, **Jobs run in**: Java (the
default) or Python. Python installs the image that runs PyFlink jobs and needs
no project to exist first. A Python release is refused on a Java workspace, and
the language cannot change once the workspace has jobs. Confluent Manager for
Flink also asks for the **State Backend Tier**.

**Fleet Selection**: the fleet to run on, or let Streamtime choose one.

**Advanced Configuration**: the **Version**, to upgrade or for local
testing. Confluent Manager for Flink also asks for the application JAR (or a
project version), entry class and arguments, and its license. Task slots,
TaskManager count, security, Web UI, savepoint and checkpoint settings are not
asked for; the API still accepts them as overrides.

---

{% capture create_section %}
## Create a Flink deployment

{% capture ui %}
1. In the sidebar, select **Flink**, then **Create Flink**.
2. **Provider**: choose Apache Flink or Confluent Manager for Flink.
3. **Basic Configuration**: enter the **Identifier**, choose **Jobs run in**
   (Apache Flink), and set **Max Flink Units** and the **Optimization Goal**.
4. **Fleet Selection**: choose the fleet.
5. **Advanced Configuration**: change the **Version** only if you need to.
6. Create it. It shows **Pending**, then **Provisioning**, then
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

`identifier` and `mode` are required. Apache Flink takes `"mode": "session"` and
`max_flink_units`; `"mode": "application"` is refused for it. For Confluent
Manager for Flink (`"provider": "cmf"`), send `"mode": "application"`,
`flink_units` and either `advanced_configuration.application_jar` or
`project_version` (`{"project": "<project>", "version": "<version>"}`).
Sizing, state backend and checkpoint locations are Streamtime's defaults; the
rest of `advanced_configuration` is optional.
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

{% capture terraform %}
```hcl
resource "streamtime_flink" "analytics" {
  identifier      = "analytics"
  mode            = "session"
  fleet           = "<fleet>"
  max_flink_units = 8

  advanced_configuration = jsonencode({})
}
```

`terraform apply` saves the deployment, starts provisioning it and waits until
it is ready, the same two steps as the API. Leave out `fleet` to let Streamtime
choose one. Apache Flink takes `mode = "session"` and `max_flink_units`. For
Confluent Manager for Flink, set `flink_provider = "cmf"`, `mode = "application"`
and `flink_units`, and either the JAR in `advanced_configuration` or a project
version:

```hcl
resource "streamtime_flink" "shared" {
  identifier       = "shared"
  flink_provider   = "open-source"
  mode             = "session"
  fleet            = "<fleet>"
  max_flink_units  = 8
}

# A project runs in a Job Workspace and reserves Flink Units on it.
# The build tool follows the runtime (Java: Maven, Scala: sbt, Python: pip).
resource "streamtime_flink_project" "etl" {
  identifier        = "etl"
  name              = "ETL jobs"
  runtime           = "java"
  cluster           = streamtime_flink.shared.identifier
  flink_unit_budget = 2
}

resource "streamtime_flink" "etl" {
  identifier      = "etl"
  flink_provider  = "cmf"
  mode            = "application"
  fleet           = "<fleet>"
  flink_units = 2

  project_version = {
    project = streamtime_flink_project.etl.identifier
    version = "<version>"
  }
}
```

Terraform does not manage the project's CI upload key: create it when you set up
CI, on the project page or with `streamtime flink-project rotate-key`. To manage an existing deployment or
project, import it by identifier: `terraform import streamtime_flink.analytics analytics`.
See [streamtime_flink]({{ site.baseurl }}/terraform/flink/) and
[streamtime_flink_project]({{ site.baseurl }}/terraform/flink-project/).
{% endcapture %}

{% include tabs.html id="flink-create" ui=ui api=api cli=cli mcp=mcp terraform=terraform %}
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
Change the Flink Units, or upgrade to a new **Version**
(`advanced_configuration.chart_config.main.version`). With the
`savepoint` upgrade mode, Streamtime takes a savepoint first and resumes
the job from it.
{% endcapture %}
{% capture update_body %}{"max_flink_units": 12}{% endcapture %}

{% capture tf_update %}
Change the attributes in the `streamtime_flink` block, for example
`max_flink_units`, `project_version` or the settings in
`advanced_configuration`, and run `terraform apply`. The plan shows an
in-place update; Terraform saves the change, applies it and waits until the
deployment runs it. Changing `identifier`, `mode`, `flink_provider` or `fleet`
replaces the deployment.
{% endcapture %}
{% capture tf_delete %}
Remove the `streamtime_flink` block and run `terraform apply`, or run
`terraform destroy -target=streamtime_flink.analytics`. Terraform waits until
Streamtime has removed the deployment.
{% endcapture %}

{% include workload-tasks.md name="Flink" id="flink" res="analytics" path="flink" py_mod="flink" py_fn="organizations_flink" ts_fn="organizationsFlink" menu="Flink" cli="flink" cli_gap="1818" has_status="yes" update_body=update_body update_note=update_note create_section=create_section extra_section=extra_section shots="flink" tf_update=tf_update tf_delete=tf_delete %}
