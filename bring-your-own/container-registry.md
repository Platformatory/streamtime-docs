---
title: Container registry
parent: Bring your own
nav_order: 7
permalink: /bring-your-own/container-registry/
---

# Container registry

Every fleet pulls the images of the services Streamtime installs and of
your workloads. By default they come from public registries, and each
fleet keeps a local cache so a node pulls an image from the internet
once.

Two things you can bring:

| | What it does | Where |
|---|---|---|
| **A private mirror registry** | Streamtime copies the images it needs into your registry, and fleets pull from there. For air-gapped or controlled environments | **Settings → Container Registry** (root organization), or first-time setup at **Image Registries** |
| **Registry credentials** | Streamtime tracks new versions of the packages it installs, and needs read access to GitHub Container Registry and Quay.io for it (Docker Hub is optional). The same credentials pull artefacts in private and air-gapped installations | First-time setup, **Image Registries** |

## Before you start

- **Mirror:** the registry's address (host and optional port), and a
  username and token if it needs them. For registries such as GHCR that
  only accept pushes under a path you own, the **Destination namespace**
  (for example `your-org`). Not needed for ECR.
- **GitHub Container Registry:** a classic personal access token with the
  `read:packages` scope.
- **Quay.io:** a robot account with read access; its username is
  `orgname+robotname`.

{% include api-setup.md id="registry" %}

## Set up a mirror registry

{% capture ui %}
1. Go to **Settings → Container Registry**.
2. Enter **Registry URL**, and **Username (optional)** and **Password /
   Token (optional)** if the registry needs them. Add a **Destination
   namespace (optional)** for registries that need one.
3. Select **Test Connection**. It shows **Connected successfully.** when
   Streamtime can sign in.
4. Save, then select **Sync Now** to copy the images into your mirror.
   The copy runs in the background; this page doesn't show its progress
   yet.
{% endcapture %}

{% capture curl %}
```bash
# Validates the credentials, then saves them.
curl -X POST "$API/container-registry/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"container_registry_url": "mirror.example.com",
       "container_registry_username": "<user>",
       "container_registry_password": "<token>",
       "container_registry_namespace": "your-org"}'

# Copy the images into the mirror.
curl -X POST "$API/container-registry/sync/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN"
```

`GET $API/container-registry/` shows the saved settings (not the
password); `DELETE` removes them.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.container_registry import (
    organizations_container_registry_create,
    organizations_container_registry_sync_create,
)
from streamtime_sdk.models import OrganizationsContainerRegistryCreateBody

organizations_container_registry_create.sync(
    ORG,
    client=client,
    body=OrganizationsContainerRegistryCreateBody.from_dict({
        "container_registry_url": "mirror.example.com",
        "container_registry_username": "<user>",
        "container_registry_password": "<token>",
    }),
)
organizations_container_registry_sync_create.sync(ORG, client=client)
```
{% endcapture %}
{% capture typescript %}
```typescript
import {
  organizationsContainerRegistryCreate,
  organizationsContainerRegistrySyncCreate,
} from "./client";

const path = { org_identifier: org };
await organizationsContainerRegistryCreate({
  path,
  body: {
    container_registry_url: "mirror.example.com",
    container_registry_username: "<user>",
    container_registry_password: "<token>",
  },
});
await organizationsContainerRegistrySyncCreate({ path });
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/container-registry/", map[string]any{
    "container_registry_url":      "mirror.example.com",
    "container_registry_username": "<user>",
    "container_registry_password": "<token>",
})
if err != nil {
    return err
}
resp.Body.Close()

resp, err = call("POST", "/container-registry/sync/", nil)
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="registry-mirror-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet. Use the console or the API.
{% endcapture %}

{% capture mcp %}
Not available in MCP.
{% endcapture %}

{% include tabs.html id="registry-mirror" ui=ui api=api cli=cli mcp=mcp %}

## Registry credentials

{% capture ui %}
1. In first-time setup, at the **Image Registries** step, enter the
   **Username** and **Token / Password** for **GitHub Container Registry
   (GHCR)** and **Quay.io**, and optionally **Docker Hub**. Each section
   explains how to create the credential.
2. Optionally fill in **Container Image Mirror Registry (optional)**, the
   same mirror as above.
3. Check and continue.
{% endcapture %}
{% capture api %}
Set during first-time setup only; there is no published API for it yet.
{% endcapture %}
{% capture cli %}
Not available in the CLI.
{% endcapture %}
{% capture mcp %}
Not available in MCP.
{% endcapture %}
{% include tabs.html id="registry-credentials" ui=ui api=api cli=cli mcp=mcp %}
