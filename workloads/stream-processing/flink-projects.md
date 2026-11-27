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

- **Runtime:** Java, Scala, Python or SQL. It decides what a version is: a
  JAR, a `.zip` for Python, or a SQL script for SQL. SQL projects run on SQL
  workspaces; see [SQL projects](#sql-projects).
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
The **CI/CD** tab shows the pipeline file to commit. To register by hand a
build you have already pushed to your artifact store:

1. Connect the project to your store (see above). Until then **Register
   release** is disabled.
2. On the project's **Versions** tab, select **Register release**.
   Administrators, Cluster Administrators and Project Owners see it.
3. Enter the **Version** (the next one is filled in), the **Location** of
   the file in your store, and its **Digest**: run `sha256sum <file>` on
   the file you pushed. This is the digest of the file, not the registry's
   manifest digest.
4. For a Python project, also choose the **Dependency layout** that
   matches how you [packaged the release](#package-a-python-release), and
   enter the **Entry file**. **Python version**, **Dependencies** and
   **Connectors** are optional.
5. Java, Scala and Python projects take optional build details:
   **Commit**, **Branch**, **CI run ID**, **CI run link** and **Built
   with**. A SQL project asks only for the version, location and digest of
   your script (at most 1 MB).
6. Select **Register**. The version appears in the list. Select **Set
   HEAD** to run it now, or **Close**.

Registering the same build again under the same version changes nothing,
and the dialog says it was already registered. A different build needs a
new version.

{% include screenshot.html dir="flink" file="register-release.png" alt="Register release dialog with the Version, Location and Digest fields" %}
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

## Package a Python release

A Python release is a `.zip`. Your job's pods download nothing from a
package index when they start, so the zip must carry every library your
code needs beyond Python and PyFlink. The **dependency layout** says how
you packed them. Choosing a layout does not repackage anything: it must
match what is in the zip.

| Dependency layout | In the zip | Before the job starts |
|---|---|---|
| **Wheel files packaged in the archive (wheelhouse)**, `wheelhouse` | `wheels/` with the `.whl` files, and `requirements.txt` | The packages in `requirements.txt` are installed from `wheels/` |
| **Packages installed into the archive (vendored)**, `vendored` | `deps/` with the installed packages | `deps/` is used as it is |
| **No extra packages**, `none` | Your code only | Nothing is installed, even if there is a `requirements.txt` |

Put your files at the top of the zip, not inside a folder. The **Entry
file** is the path of the `.py` file that starts the job, as it appears in
the zip, for example `main.py`. Leave PyFlink (`apache-flink`) out of
`requirements.txt` and the zip: the job already has it.

Libraries with compiled code must be built for the Python version and
processor type of your cluster. The commands below build for Python 3.10
on x86_64; use `manylinux2014_aarch64` for Arm nodes, and ask your
administrator if your installation runs another Python version.

Wheelhouse:

```bash
pip download -r requirements.txt -d wheels --only-binary=:all: \
  --implementation cp --python-version 3.10 --platform manylinux2014_x86_64
zip -r app.zip main.py requirements.txt wheels
```

`wheels/` needs a wheel for every package, including the ones your
packages depend on. `pip download` collects them all.

Vendored:

```bash
pip install -r requirements.txt --target deps --only-binary=:all: \
  --implementation cp --python-version 3.10 --platform manylinux2014_x86_64
zip -r app.zip main.py deps
```

No extra packages:

```bash
zip -r app.zip main.py
```

Add any other code your job imports to the same `zip` command.

**Connector JARs** such as the Kafka connector go in a `jars/` folder in
the zip, with any layout. If you name one under **Connectors**, the start
of its file name must match, and it must be in `jars/` unless the cluster
already provides it.

The pipeline file on the **CI/CD** tab builds a wheelhouse when your
project has a `requirements.txt`. That file must list at least one
package: if you need none, delete it.

The zip is checked when a job starts, not when you register it. A missing
entry file, a layout that does not match the zip, or a wheel built for
another Python version or processor type stops the job with the reason.
Vendored packages are not checked for Python version or processor type.

## Change a project's Job Workspace or budget

A project's **Job Workspace** and **Flink Units** can be changed after it is
created. A project created before Job Workspaces were required has none yet;
place it the same way. The change is refused when:

- the new budget is more than the workspace has free (a project's own
  booking doesn't count against it when it stays on its workspace);
- the budget is lower than the Flink Units the project's jobs already use;
- the project still has jobs on its current workspace, when you move it.
  Delete them or redeploy them to the new workspace first.

The reason is shown as written, and nothing changes.

{% capture ui %}
1. In the sidebar, open **Flink projects** and select the project.
2. Select **Edit placement** (**Place project** for a project with no Job
   Workspace). Only a Project Owner sees it.
3. Choose the **Job Workspace**. Each one shows its free room, for example
   `analytics: 6 of 10 Flink Units free`.
4. Set **Flink Units**. The dialog shows how many the project's jobs use
   now.
5. **Save**. A refusal appears in the dialog; fix the value and save again.

The project's page shows its workspace and **Jobs use N of M Flink Units**.

{% include screenshot.html dir="flink" file="edit-placement.png" alt="Edit placement dialog with the Job Workspace list showing free room and the Flink Units field" %}
{% endcapture %}
{% capture curl %}
```bash
curl -X PATCH "$API/flink-projects/etl/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"cluster": "<job-workspace>", "flink_unit_budget": 6}'
```

Send only what changes. A refused change returns `400` with the reason:

```json
{"detail": {"flink_unit_budget": ["Cluster 'analytics' has 3 free Flink units of 10; this project asks for 12. Choose a smaller budget or another cluster."]}}
```
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.flink_projects import flink_projects_partial_update
from streamtime_sdk.models import PatchedFlinkProject

flink_projects_partial_update.sync(
    ORG, "etl", client=client,
    body=PatchedFlinkProject(cluster="<job-workspace>", flink_unit_budget=6),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { flinkProjectsPartialUpdate } from "./client";

await flinkProjectsPartialUpdate({
  path: { org_identifier: org, identifier: "etl" },
  body: { cluster: "<job-workspace>", flink_unit_budget: 6 },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("PATCH", "/flink-projects/etl/", map[string]any{
    "cluster": "<job-workspace>", "flink_unit_budget": 6,
})
if err != nil {
    return err
}
defer resp.Body.Close()
// 200 on success; 400 carries the reason under "detail"
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="flink-project-placement-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}
{% capture cli %}
```bash
streamtime flink-project update etl --cluster <job-workspace> --flink-units 6
```
{% endcapture %}
{% capture mcp %}
Not available in MCP.
{% endcapture %}
{% capture terraform %}
Change `cluster` or `flink_unit_budget` on the `streamtime_flink_project`
resource and apply. See
[streamtime_flink_project]({{ site.baseurl }}/terraform/flink-project/).
{% endcapture %}
{% include tabs.html id="flink-project-placement" ui=ui api=api cli=cli mcp=mcp terraform=terraform %}

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

## SQL projects

A SQL project's versions are SQL scripts, kept in your own artifact store
and registered by digest like any other release; they can't be uploaded to
Streamtime. A version runs as a job on a **SQL workspace** (a Job Workspace on
Confluent Platform for Apache Flink).

When the job starts, a short-lived step inside your fleet fetches the script
with your store's credential, checks it against the registered digest, and
creates the job's statement from it. The script and the credential never leave
the fleet.

What a script can hold:

- **One statement**, or one statement set
  (`EXECUTE STATEMENT SET BEGIN INSERT …; INSERT …; END;`) to run several
  INSERTs as one job. A script with several separate statements fails with
  "only single statement supported".
- **INSERT and SELECT on existing tables.** Each topic of the workspace's
  Kafka cluster is a table. Creating tables (`CREATE TABLE`) isn't supported yet.
- **Not portable to Apache Flink as is.** A SQL workspace doesn't accept
  connector options such as `'connector' = 'kafka'`, `SET`, `CREATE CATALOG`
  or `CREATE FUNCTION`. Set Flink options on the job instead of with `SET`.

Deploying another version replaces the statement: the job restarts **without
its state** and reads its input again from the start. Rolling back works the
same way.

To run a version, create a job on the SQL workspace, choose **A version from a
Flink project** under **What the job runs**, and pick the SQL project and
version. Moving the project's HEAD then deploys newer or older versions.

Don't put credentials in a script: the statement's text is visible in the
fleet. SQL on SQL workspaces is a preview feature of Confluent Platform for
Apache Flink.

## Delete a project

Deleting removes the project, every version and its CI key. It is refused
while a Flink deployment or job still runs one of its versions.
`streamtime flink-project delete etl`, `DELETE $API/flink-projects/etl/`,
or remove the `streamtime_flink_project` resource.
