---
title: Package Management
nav_order: 6
parent: Getting Started
permalink: /getting-started/package-management/
---

Streamtime deploys workloads from a **package catalog**: the charts and
container images it is allowed to install, with their versions. Nothing
runs in a fleet that is not in the catalog, which is what makes
air-gapped and compliance-sensitive installations possible.

## What the catalog holds

| Kind | What it is |
|---|---|
| **Charts** | The Helm charts behind each workload and platform component (Kafka operators, gateways, monitoring) |
| **Images** | The container images those charts run |

Each tracked chart and image carries a **default version** — what new
workloads get — and a list of versions an existing workload can be
moved to.

## Version policy

- Versions are SemVer. Upgrades roll forward: a workload moves from its
  current version to a newer one through a scheduled operation (see
  [Scheduled Operations](/operations/scheduled-operations/)).
- Auto-upgrade can be enabled per workload so patch versions apply
  themselves; disable it to stay on a version you have tested.
- Version support follows the product's support policy: the current line
  plus the previous one. Older versions stop receiving security fixes.

## Air-gapped installations

For a cluster with no internet access, the catalog is mirrored into
your own registry: Streamtime's required charts and images are
pre-staged, and the catalog points at the mirror. The console lists
every package it expects so you can diff the mirror against what it
needs.

## How this shows up in the UI

When you create or upgrade a workload, the **Version** selectors are
populated from the catalog — you pick from what Streamtime can actually
install, never a free-text version.

### Choosing component versions when you create something

The last step of each create form has a collapsed section — **Bootstrap
Components** when you create a fleet, **Components** when you create a
workload. Closed, it reads **Using recommended versions**, and you can
deploy without opening it: every component gets its catalog default.

Open it to change a component. Each component has its own card:

| Field | What it does |
|---|---|
| **Version** | The versions in the selected registry, newest first. The default is marked *(recommended)*. |
| **Registry** | Shown only when the chart is mirrored in more than one registry. Changing it clears the version and selects the recommended (or newest) version that registry has, so a version is never paired with a registry that does not hold it. |
| **Custom settings** | Shown for components whose settings you can override. Opens the component's default settings as YAML for you to edit. |

Once you change anything, the closed section reads **N version
overrides** instead. If a registry has no versions of a component, the
row says so: pick another registry, or sync packages in **Settings**.

## Track your own Helm chart

Add a Helm repository, then track a chart from it, so the chart and its
versions appear in the catalog. Catalog changes need the catalog
permission, normally in the root organization; the catalog is shared by
the whole installation.

{% include api-setup.md id="catalog" %}

{% capture ui %}
Adding a repository isn't available in the console yet. The **Packages**
page lists the catalog and its version rules, and **Settings** syncs
packages. Use the API or Terraform to add a repository.
{% endcapture %}

{% capture curl %}
```bash
# 1. The Helm repository.
curl -X POST "$API/helm-repositories/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"name": "team-charts", "base_url": "https://charts.example.com"}'

# 2. Track a chart from it (helm_repository_id from step 1's response).
curl -X POST "$API/tracked-repositories/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"repo_type": "helm", "repository": "kafka", "helm_repository_id": "<id>"}'
```

For a chart or image in an OCI registry, send `"repo_type": "oci"` with
`registry_url` and `repository` instead. Version rules are at
`$API/package-rules/`, catalog records at `$API/packages/`. Tracking a
repository doesn't sync its versions: sync packages afterwards.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.repositories import (
    organizations_helm_repositories_create,
    organizations_tracked_repositories_create,
)
from streamtime_sdk.models import HelmRepository, TrackedRepository

repo = organizations_helm_repositories_create.sync(
    ORG, client=client,
    body=HelmRepository.from_dict({"name": "team-charts", "base_url": "https://charts.example.com"}),
)
organizations_tracked_repositories_create.sync(
    ORG, client=client,
    body=TrackedRepository.from_dict(
        {"repo_type": "helm", "repository": "kafka", "helm_repository_id": str(repo.id)}
    ),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import {
  organizationsHelmRepositoriesCreate,
  organizationsTrackedRepositoriesCreate,
} from "./client";

const path = { org_identifier: org };
const { data: repo } = await organizationsHelmRepositoriesCreate({
  path,
  body: { name: "team-charts", base_url: "https://charts.example.com" },
});
await organizationsTrackedRepositoriesCreate({
  path,
  body: { repo_type: "helm", repository: "kafka", helm_repository_id: repo!.id },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/helm-repositories/", map[string]any{
    "name":     "team-charts",
    "base_url": "https://charts.example.com",
})
if err != nil {
    return err
}
defer resp.Body.Close()
// Then POST /tracked-repositories/ with repo_type, repository and helm_repository_id.
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="catalog-track-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet. Use the API or Terraform.
{% endcapture %}

{% capture mcp %}
Not available in MCP.
{% endcapture %}

{% capture terraform %}
```hcl
resource "streamtime_helm_repository" "charts" {
  name     = "team-charts"
  base_url = "https://charts.example.com"
}

resource "streamtime_tracked_repository" "kafka" {
  repository      = "kafka"
  repo_type       = "helm"
  helm_repository = streamtime_helm_repository.charts.name
}

resource "streamtime_package_rule" "kafka" {
  name               = "kafka-3x"
  repository         = streamtime_tracked_repository.kafka.repository
  version_constraint = ">=3.6.0 <4.0.0"
  target_status      = "supported"
  default_version    = "3.8.0"
}

resource "streamtime_package" "kafka" {
  registry_url   = streamtime_helm_repository.charts.base_url
  repository     = streamtime_tracked_repository.kafka.repository
  tag            = "3.8.0"
  artifact_type  = "helm_chart"
  support_status = "supported"
}
```

Tracking a repository and declaring a rule do not sync its versions. Run
package sync separately. A package resource manages one catalog record;
destroying it does not delete the chart or image from its registry.

```bash
terraform import streamtime_helm_repository.charts team-charts
terraform import streamtime_tracked_repository.kafka kafka
terraform import streamtime_package_rule.kafka kafka-3x
terraform import streamtime_package.kafka '<package-identifier>'
```

Tracked repositories are addressed by repository name. If the same name
exists in different registries, the provider refuses to read, change or
delete an object that does not match the registry recorded in its state.
{% endcapture %}

{% include tabs.html id="catalog-track" ui=ui api=api cli=cli mcp=mcp terraform=terraform %}
