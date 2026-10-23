---
title: Installation
nav_order: 1
parent: Getting Started
permalink: /getting-started/installation/
---

Three ways to run the Streamtime control plane, by environment:

| Deployment | For | You need |
|---|---|---|
| **Single image (Docker)** | Try it out on one machine; embedded single-node pilots | Docker |
| **Kubernetes (Helm chart)** | Production private clouds | a Kubernetes cluster, Helm 3 |
| **Docker Compose (from source)** | Contributing and development | a checkout of `streamtime-ai/fleet-manager` |

## Single image (Docker)

The single image contains everything — the API, console, gateway,
orchestrator and an embedded database and workflow engine. No external
dependencies.

Interactively (the default is fine for a trial):

```bash
docker run -d --name streamtime --privileged \
  -p 3000:3000 -p 8443:8443 -p 7999:7999 \
  ghcr.io/streamtime-ai/streamtime:latest
```

Headless / unattended (CI, a VM you only SSH into):

```bash
docker run -d --name streamtime --privileged \
  -p 3000:3000 -p 8443:8443 -p 7999:7999 \
  -e SUPER_USER_EMAILS=you@example.com \
  ghcr.io/streamtime-ai/streamtime:latest
```

Pin a version (`ghcr.io/streamtime-ai/streamtime:1.1`) instead of
`latest` for anything you keep running. The image is amd64 and arm64.
`--privileged` is required: the image runs a full service stack.
Add `-v streamtime-data:/data` to keep data across container restarts.

Where it listens:

| Port | What |
|---|---|
| **8443** | The console **and** the API (HTTPS) — browse https://localhost:8443 |
| 3000 | Console UI directly (plain HTTP; use 8443 instead) |
| 7999 | Backend API without the gateway (diagnostics) |

## Kubernetes (Helm)

```bash
helm upgrade --install streamtime oci://ghcr.io/streamtime-ai/fleet-manager \
  --namespace streamtime --create-namespace \
  --set fleetmanager.adminEmail=you@example.com
```

The console and API are exposed through the cluster's LoadBalancer
service; point a DNS record for your base domain at it and open the
console. Add `--set fleetmanager.superUserEmails=you@example.com` for a
super user that spans organizations.

For a highly available install (HA Postgres via CloudNativePG,
cert-manager issuer) use the `streamtime-ha` chart: one
`helm upgrade --install` creates everything, with the domain, admin
email, license and registry credentials in a values file.

### Changing credentials after install (HA chart)

The license, registry tokens, identity-provider client secret and admin
password you set in the values file are applied on every
`helm upgrade`: change the value and upgrade to rotate it. Leaving a value
empty keeps the one already stored. Passwords Streamtime generates itself
(database, cache, signing and encryption keys) are created once and kept
across upgrades, as long as the release name and namespace stay the same.

{: .warning }
GitOps tools that render with `helm template` (Argo CD's default) cannot
keep generated passwords: every render makes new ones. Use a tool that runs
Helm itself, such as Flux.

### Join your tailnet (HA chart)

Fleets reach Streamtime over the organization's Tailscale tailnet. With the
`streamtime-ha` chart, the control plane can join the tailnet itself: the
gateway (port 8443) gets a tailnet address and fleets connect to it. It is
off by default.

1. In the Tailscale admin console:
   - Add to the tailnet policy:
     `"tagOwners": {"tag:k8s-operator": ["autogroup:admin"], "tag:k8s": ["tag:k8s-operator"]}`.
   - Create an OAuth client with every scope read and write, tagged
     `tag:k8s-operator`. Keep its client ID and secret.
   - Note the tailnet name (**DNS** page, for example `tail1a2b3.ts.net`).
2. Store the OAuth client in the cluster. The Secret's name is fixed:

   ```bash
   kubectl -n streamtime create secret generic operator-oauth \
     --from-literal=client_id='<client id>' \
     --from-file=client_secret=/dev/stdin    # paste the secret, then Ctrl-D
   ```

3. Turn it on in the values file and upgrade:

   ```yaml
   global:
     streamtime:
       tailscale:
         enabled: true
         tailnetDomain: tail1a2b3.ts.net
         hostname: streamtime          # the gateway joins as streamtime.tail1a2b3.ts.net
       # Only with tls.mode: letsencrypt
       gatewayCertificateIssuer: letsencrypt
   ```

The gateway keeps serving its own certificate on the tailnet. A public certificate
authority cannot issue the tailnet name, so with `tls.mode: letsencrypt`
fleets connect to the tailnet address and check the certificate for your
public name. `gatewayCertificateIssuer: letsencrypt` tells Streamtime to
give fleets the Let's Encrypt roots; the install stops with a message if it
is missing.

- The hostname and the client secret are applied on every start. The
  tailnet, client ID, tags and registry setting are applied on the first
  install only; change them under **Settings → Connectivity** afterwards.
- A hostname already in use on the tailnet silently becomes
  `<hostname>-1`. Remove stale devices before reinstalling.
- To rotate the client secret: update `operator-oauth`, restart the API and
  the Tailscale operator, run **Update Agent** on each fleet, then revoke
  the old secret.

{: .note }
The single image and Docker Compose join the tailnet from
**Settings → Connectivity** instead; nothing in this section applies to them.

#### Check the tailnet connection

{% capture ui %}
1. Go to **Settings → Connectivity**. **Tailscale (recommended)** is
   selected, and the tailnet name, Streamtime tailnet address and OAuth
   client ID are filled in.
2. Select **Validate**. It shows **Checking with Tailscale…**, then each
   check with its result. All checks pass when the tailnet, the OAuth client
   and the tags are set up correctly.
{% endcapture %}

{% capture curl %}
```bash
curl -s -X POST "https://api.example.com/organizations/<org>/tunnel-config/tailscale/validate/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"tailnet_domain": "tail1a2b3.ts.net",
       "streamtime_hostname": "streamtime.tail1a2b3.ts.net",
       "client_id": "<client id>"}'
```
Leaving out `client_secret` checks the saved one. The response has `ok`,
one entry per check under `checks`, and `field_errors`.
{% endcapture %}

{% capture python %}
```python
from streamtime_sdk import AuthenticatedClient
from streamtime_sdk.api.tunnel_configuration import (
    organizations_tunnel_config_tailscale_validate_create as validate,
)
from streamtime_sdk.models import TailscaleSettingsWrite

client = AuthenticatedClient(base_url="https://api.example.com", token="<token>")
result = validate.sync(
    "<org>",
    client=client,
    body=TailscaleSettingsWrite(
        tailnet_domain="tail1a2b3.ts.net",
        streamtime_hostname="streamtime.tail1a2b3.ts.net",
        client_id="<client id>",
    ),
)
print(result.ok, [check.to_dict() for check in result.checks])
```
{% endcapture %}

{% capture typescript %}
```typescript
import { client } from "./client.gen";
import { organizationsTunnelConfigTailscaleValidateCreate } from "./sdk.gen";

client.setConfig({
  baseUrl: "https://api.example.com",
  headers: { Authorization: `Bearer ${process.env.STREAMTIME_TOKEN}` },
});

const { data } = await organizationsTunnelConfigTailscaleValidateCreate({
  path: { org_identifier: "<org>" },
  body: {
    tailnet_domain: "tail1a2b3.ts.net",
    streamtime_hostname: "streamtime.tail1a2b3.ts.net",
    client_id: "<client id>",
  },
});
console.log(data?.ok, data?.checks);
```
{% endcapture %}

{% capture go %}
```go
body := strings.NewReader(`{"tailnet_domain":"tail1a2b3.ts.net",` +
    `"streamtime_hostname":"streamtime.tail1a2b3.ts.net","client_id":"<client id>"}`)
req, _ := http.NewRequest(http.MethodPost,
    "https://api.example.com/organizations/<org>/tunnel-config/tailscale/validate/", body)
req.Header.Set("Authorization", "Bearer "+os.Getenv("STREAMTIME_TOKEN"))
req.Header.Set("Content-Type", "application/json")
resp, err := http.DefaultClient.Do(req)
```
{% endcapture %}

{% capture api %}{% include code-tabs.html id="check-tailnet-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet.
{% endcapture %}

{% capture mcp %}
Not available through MCP yet.
{% endcapture %}

{% include tabs.html id="check-tailnet" ui=ui api=api cli=cli mcp=mcp %}

## From source (Docker Compose)

```bash
git clone https://github.com/streamtime-ai/fleet-manager.git
cd fleet-manager
docker compose up -d
```

## Sign in

Open **https://localhost:8443** (or your deployment's address) and sign
in. Enter `root` as the organization: `root` is the special
organization whose super user can create other organizations and has
complete administrator privileges. Super users are the email addresses
listed in `SUPER_USER_EMAILS` (single image and Compose) or
`fleetmanager.superUserEmails` (Helm). See
[User Management](/getting-started/user-management/).

To sign in from the terminal instead:

```bash
pip install streamtime-cli
streamtime login --org root --streamtime-url https://localhost:8443
streamtime fleet list
```

`login` opens the browser for the org's identity provider; add
`--grant password` for headless use.
