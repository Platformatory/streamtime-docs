---
title: Flink projects
parent: Stream Processing
grand_parent: Workloads
nav_order: 2
permalink: /workloads/stream-processing/flink-projects/
---

# Flink projects

A **Flink project** is the home of one Flink application. Your CI system
builds the application and adds each build to the project as a
**version**; Streamtime runs a version as a job in a **Job Workspace**,
and moves it forward or back when you choose.

- **Runtime:** Java, Scala or Python. It decides what a version is: a
  JAR, or a `.zip` for Python.
- **Budget:** the project books **Flink Units** on its Job Workspace, and
  its jobs run within them. See [Capacity units]({{ site.baseurl }}/about/scaling/#flink-units).
- **Versions** come one of two ways: uploaded to Streamtime, or kept in
  your own artifact store (an OCI registry such as GHCR, or a JFrog
  repository) and registered by digest.
- **HEAD** is the version the project runs. Moving HEAD deploys that
  version, newer or older than the current one.
- A **CI key** lets your pipeline add versions. It is shown once.

{% include api-setup.md id="flink-projects" %}

## Create a project

{% capture ui %}
1. In the sidebar, open **Flink projects** and create a project.
2. Enter **Identifier**, **Name**, **Runtime** and, optionally,
   **Description**.
3. Choose the **Job Workspace** the project runs in and its **Flink
   Units**.
4. Save. On the project's **CI/CD** tab, create the CI key: the dialog
   **Save your CI upload key** shows it once. Copy it, tick **I have stored
   this key somewhere safe**, and close.
{% endcapture %}

{% capture curl %}
```bash
curl -X POST "$API/flink-projects/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"identifier": "etl", "name": "ETL jobs", "runtime": "java",
       "cluster": "<job-workspace>", "flink_unit_budget": 2}'

# The CI key, shown once (rotating replaces it).
curl -X POST "$API/flink-projects/etl/rotate-key/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
```
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.flink_projects import flink_projects_create, flink_projects_rotate_key
from streamtime_sdk.models import FlinkProject

flink_projects_create.sync(
    ORG,
    client=client,
    body=FlinkProject.from_dict({
        "identifier": "etl", "name": "ETL jobs", "runtime": "java",
        "cluster": "<job-workspace>", "flink_unit_budget": 2,
    }),
)
key = flink_projects_rotate_key.sync(ORG, "etl", client=client)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { flinkProjectsCreate, flinkProjectsRotateKey } from "./client";

await flinkProjectsCreate({
  path: { org_identifier: org },
  body: { identifier: "etl", name: "ETL jobs", runtime: "java",
          cluster: "<job-workspace>", flink_unit_budget: 2 },
});
const { data: key } = await flinkProjectsRotateKey({
  path: { org_identifier: org, identifier: "etl" },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/flink-projects/", map[string]any{
    "identifier": "etl", "name": "ETL jobs", "runtime": "java",
    "cluster": "<job-workspace>", "flink_unit_budget": 2,
})
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="flink-project-create-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime flink-project create --identifier etl --name "ETL jobs" --runtime java \
  --cluster <job-workspace> --flink-units 2
streamtime flink-project rotate-key etl     # the CI key, shown once
```
{% endcapture %}

{% capture mcp %}
Not available in MCP.
{% endcapture %}

{% capture terraform %}
```hcl
resource "streamtime_flink_project" "etl" {
  identifier        = "etl"
  name              = "ETL jobs"
  runtime           = "java"
  cluster           = streamtime_flink.shared.identifier # a Job Workspace
  flink_unit_budget = 2
}
```

Terraform doesn't manage the CI key: create it on the project page or
with `streamtime flink-project rotate-key etl`. See
[streamtime_flink_project]({{ site.baseurl }}/terraform/flink-project/).
{% endcapture %}

{% include tabs.html id="flink-project-create" ui=ui api=api cli=cli mcp=mcp terraform=terraform %}

## Connect your own artifact store

Optional. Keep builds in your own registry instead of uploading them, and
give Streamtime a **read-only** credential limited to this project's
artifacts.

{% capture ui %}
On the project, open the store settings and choose the **Store type**
(OCI registry or JFrog), its address, and the **Sign-in**: none,
**Username** and **Password**, or an **Access token**. Add a **CA
certificate** if the store doesn't use a public certificate.
{% endcapture %}
{% capture curl %}
```bash
curl -X PUT "$API/flink-projects/etl/store/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"store_type": "oras", "url": "https://ghcr.io",
       "authentication": "token", "token": "<read-only-token>"}'
```

`store_type` is `oras` (an OCI registry) or `jfrog`; `authentication` is
`none`, `basic` (with `username` and `password`) or `token`.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.flink_projects import flink_project_store_update
from streamtime_sdk.models import FlinkProjectStore

flink_project_store_update.sync(
    ORG, "etl", client=client,
    body=FlinkProjectStore.from_dict({
        "store_type": "oras", "url": "https://ghcr.io",
        "authentication": "token", "token": "<read-only-token>",
    }),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { flinkProjectStoreUpdate } from "./client";

await flinkProjectStoreUpdate({
  path: { org_identifier: org, identifier: "etl" },
  body: { store_type: "oras", url: "https://ghcr.io",
          authentication: "token", token: "<read-only-token>" },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("PUT", "/flink-projects/etl/store/", map[string]any{
    "store_type": "oras", "url": "https://ghcr.io",
    "authentication": "token", "token": "<read-only-token>",
})
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="flink-project-store-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}
{% capture cli %}
```bash
export STREAMTIME_STORE_TOKEN=<read-only-token>   # rather than --token on the command line
streamtime flink-project store set etl --store oras --url https://ghcr.io
streamtime flink-project store show etl
```

For password sign-in use `--username` with `STREAMTIME_STORE_PASSWORD`;
`--ca-file` adds a CA certificate.
{% endcapture %}
{% capture mcp %}
Not available in MCP.
{% endcapture %}
{% capture terraform %}
Set the `store` block on `streamtime_flink_project`: `store_type`, `url`,
`authentication` and the credential, from a sensitive variable.
{% endcapture %}
{% include tabs.html id="flink-project-store" ui=ui api=api cli=cli mcp=mcp terraform=terraform %}

## Add a version from CI

Your pipeline adds each build with the project's CI key. Streamtime
generates the pipeline for you: GitHub, GitLab, Bitbucket or a generic
script, on the project's **CI/CD** tab or with
`streamtime flink-project ci-template etl --provider github`.
`streamtime flink-project init etl` writes a local development setup.

{% capture ui %}
On the project's **Versions** tab, **Upload Version** adds a build by
hand. The **CI/CD** tab shows the pipeline file to commit.
{% endcapture %}
{% capture curl %}
```bash
# A version kept in your own store: register it by digest.
curl -X POST "$API/flink-projects/etl/releases/" \
  -H "X-Streamtime-Key: $CI_KEY" -H "Content-Type: application/json" \
  -d '{"version": "1.4.0", "store_type": "oras",
       "location": "ghcr.io/acme/etl:1.4.0",
       "digest": "sha256:<64-hex-characters>"}'
```

To upload the build to Streamtime instead, `POST` the file to
`$API/flink-projects/etl/versions/`. List versions with
`GET $API/flink-projects/etl/versions/`.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.flink_projects import flink_project_releases_register
from streamtime_sdk.models import FlinkReleaseRegister

flink_project_releases_register.sync(
    ORG, "etl", client=client,
    body=FlinkReleaseRegister.from_dict({
        "version": "1.4.0", "store_type": "oras",
        "location": "ghcr.io/acme/etl:1.4.0",
        "digest": "sha256:<64-hex-characters>",
    }),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { flinkProjectReleasesRegister } from "./client";

await flinkProjectReleasesRegister({
  path: { org_identifier: org, identifier: "etl" },
  body: { version: "1.4.0", store_type: "oras",
          location: "ghcr.io/acme/etl:1.4.0", digest: "sha256:<64-hex-characters>" },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/flink-projects/etl/releases/", map[string]any{
    "version": "1.4.0", "store_type": "oras",
    "location": "ghcr.io/acme/etl:1.4.0", "digest": "sha256:<64-hex-characters>",
})
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="flink-project-version-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}
{% capture cli %}
```bash
# Upload a build to Streamtime
streamtime flink-project upload etl ./target/etl.jar --version 1.4.0

# Or register one in your own store
streamtime flink-project release register etl --version 1.4.0 --store oras \
  --location ghcr.io/acme/etl:1.4.0 --digest sha256:<64-hex-characters>

streamtime flink-project versions etl
```
{% endcapture %}
{% capture mcp %}
Not available in MCP.
{% endcapture %}
{% include tabs.html id="flink-project-version" ui=ui api=api cli=cli mcp=mcp %}

## Run a version

Moving the project's HEAD to a version deploys it. The first time, name
the job and its Job Workspace.

{% capture ui %}
On the project's **Deployments** tab, choose the **Version**; the first
time also the **Job Workspace** and **Job** (and for Python the **Python
file to run**). Choose the **State handling**: from a savepoint, the last
state, or stateless. Moving to an older version often needs stateless,
because newer state may not load in older code.
{% endcapture %}
{% capture curl %}
```bash
curl -X PUT "$API/flink-projects/etl/head/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"version": "1.4.0", "target_type": "job", "target": "etl-main",
       "cluster": "<job-workspace>", "upgrade_mode": "savepoint"}'
```

Returns `202`: the job rolls out in the background. Later moves need only
`version` and `upgrade_mode`. See where it runs with
`GET $API/flink-projects/etl/deployments/`.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.flink_projects import flink_projects_head_update
from streamtime_sdk.models import FlinkProjectHeadRequest

flink_projects_head_update.sync(
    ORG, "etl", client=client,
    body=FlinkProjectHeadRequest.from_dict({
        "version": "1.4.0", "target_type": "job", "target": "etl-main",
        "cluster": "<job-workspace>", "upgrade_mode": "savepoint",
    }),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { flinkProjectsHeadUpdate } from "./client";

await flinkProjectsHeadUpdate({
  path: { org_identifier: org, identifier: "etl" },
  body: { version: "1.4.0", target_type: "job", target: "etl-main",
          cluster: "<job-workspace>", upgrade_mode: "savepoint" },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("PUT", "/flink-projects/etl/head/", map[string]any{
    "version": "1.4.0", "target_type": "job", "target": "etl-main",
    "cluster": "<job-workspace>", "upgrade_mode": "savepoint",
})
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="flink-project-run-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}
{% capture cli %}
```bash
streamtime flink-project head set etl --version 1.4.0 \
  --job etl-main --session-cluster <job-workspace> --wait
streamtime flink-project head show etl
streamtime flink-project deployments etl
```
{% endcapture %}
{% capture mcp %}
MCP reads the job's status, metrics and logs: *"Is the etl-main job
healthy?"* Deploying isn't available in MCP.
{% endcapture %}
{% include tabs.html id="flink-project-run" ui=ui api=api cli=cli mcp=mcp %}

## Delete a project

Deleting removes the project, every version and its CI key. It is refused
while a Flink deployment or job still runs one of its versions.
`streamtime flink-project delete etl`, `DELETE $API/flink-projects/etl/`,
or remove the `streamtime_flink_project` resource.
