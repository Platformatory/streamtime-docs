---
title: Connectivity
parent: Bring your own
nav_order: 3
permalink: /bring-your-own/connectivity/
---

# Connectivity

Fleets and Streamtime need a private connection between them. Over it,
each fleet's agent fetches its work and reports results, and Streamtime
reads the fleet's metrics, logs and Kafka UI. Kafka traffic from your
applications never uses it: it goes through each workload's own gateway
(see [Architecture]({{ site.baseurl }}/about/architecture/#connectivity)).

You choose the connection in **Settings → Connectivity**, also a step of
first-time setup:

| | Tailscale (recommended) | Other tunnel |
|---|---|---|
| What it is | Streamtime and each fleet join your tailnet | Any other tunnel (ngrok, Cloudflare Tunnel, bore …), or your own network: public DNS and a load balancer, a VPN or peering |
| What you save | Your tailnet's name, an OAuth client, and this Streamtime host's tailnet address | The addresses fleets use to reach Streamtime |
| Addresses | Worked out from the tailnet; nothing else to save | **Orchestrator Tunnel URL** and **Registry Tunnel URL** |

{: .note }
A change reaches fleets that already exist through **Update Agent** on
the fleet's **Agent Management** tab. You never reinstall a fleet to
change its connection.

## Before you start: Tailscale

1. **Two tags in your tailnet policy.** In the Tailscale admin console,
   open **Access controls**, switch to the **JSON editor** and add:

   ```json
   "tagOwners": {
     "tag:k8s-operator": [],
     "tag:k8s": ["tag:k8s-operator"]
   }
   ```

   `tag:k8s-operator` is the Tailscale operator Streamtime puts in each
   fleet; `tag:k8s` are the devices it creates (each fleet's connection to
   Streamtime and its shared services). If your policy restricts traffic,
   also allow `tag:k8s` to reach the Streamtime host on port 8443, and the
   Streamtime host to reach `tag:k8s` on port 443.
2. **An OAuth client.** Under **Settings → OAuth clients** in Tailscale,
   generate a client with **All** scopes and **write** access, allowed to
   use `tag:k8s-operator`. Copy the client ID and secret; the secret is
   shown once.
3. **The Streamtime host on the tailnet.** Install Tailscale on the
   machine running Streamtime, run `tailscale up` with MagicDNS on, and
   read the two values the form asks for:

   ```bash
   tailscale status --json | jq -r '.Self.DNSName | rtrimstr(".")'   # Streamtime tailnet address
   tailscale status --json | jq -r '.MagicDNSSuffix'                 # Tailnet name
   ```

## Before you start: another tunnel or your own network

Fleets must reach two Streamtime addresses:

- **Orchestrator Tunnel URL**: where fleets' agents reach the
  Durable Executor, as `host:port`.
- **Registry Tunnel URL**: where fleets pull images from Streamtime's
  registry.

Leave both empty when fleets reach Streamtime directly, for example a kind
cluster on the same Docker network.

{% include api-setup.md id="connectivity" %}

## Set up the connection

{% capture ui %}
1. Go to **Settings → Connectivity**.
2. Choose **Tailscale (recommended)** or **Other tunnel**.
3. **Tailscale:** enter **Streamtime tailnet address**, **Tailnet name**,
   **OAuth client ID** and **OAuth client secret**. Optionally turn on
   **Serve the local registry over Tailscale** so fleets pull images over
   the tailnet, or change the **Operator tag** and **Fleet device tag**.
   **Other tunnel:** enter **Registry Tunnel URL** and **Orchestrator Tunnel URL**, then select **Test connectivity**. Streamtime checks each
   address from the server and shows the result.
4. Select **Save**.
5. For each existing fleet, run **Update Agent** on its **Agent
   Management** tab.
{% endcapture %}

{% capture curl %}
```bash
# Another tunnel: check the addresses first.
curl -X POST "$API/tunnel-config/probe/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"orchestrator_tunnel_url": "tunnel.example.com:7233",
       "registry_tunnel_url": "https://registry-tunnel.example.com"}'

# Save. Both addresses are required on every PUT: send the saved value to
# keep one, or an empty value to clear it.
curl -X PUT "$API/tunnel-config/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"tunnel_provider": "other",
       "orchestrator_tunnel_url": "tunnel.example.com:7233",
       "registry_tunnel_url": "https://registry-tunnel.example.com"}'
```

For Tailscale, send `"tunnel_provider": "tailscale"` and a `tailscale`
object with `tailnet_domain`, `client_id`, `client_secret` and
`streamtime_hostname` (optional: `operator_tags`, `proxy_tags`,
`registry_over_tailnet`). Check it first with
`POST $API/tunnel-config/tailscale/validate/`. Read the saved settings
with `GET $API/tunnel-config/`; the secret is never returned.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.tunnel_configuration import organizations_tunnel_config_update
from streamtime_sdk.models import TunnelConfigWrite

organizations_tunnel_config_update.sync(
    ORG,
    client=client,
    body=TunnelConfigWrite.from_dict({
        "tunnel_provider": "other",
        "orchestrator_tunnel_url": "tunnel.example.com:7233",
        "registry_tunnel_url": "https://registry-tunnel.example.com",
    }),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsTunnelConfigUpdate } from "./client";

await organizationsTunnelConfigUpdate({
  path: { org_identifier: org },
  body: {
    tunnel_provider: "other",
    orchestrator_tunnel_url: "tunnel.example.com:7233",
    registry_tunnel_url: "https://registry-tunnel.example.com",
  },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("PUT", "/tunnel-config/", map[string]any{
    "tunnel_provider":         "other",
    "orchestrator_tunnel_url": "tunnel.example.com:7233",
    "registry_tunnel_url":     "https://registry-tunnel.example.com",
})
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="connectivity-set-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet. Use the console or the API.
{% endcapture %}

{% capture mcp %}
Not available in MCP yet.
{% endcapture %}

{% include tabs.html id="connectivity-set" ui=ui api=api cli=cli mcp=mcp %}

## Exposing Kafka

Kafka endpoints are exposed per cluster, **internal** (inside the fleet's
network) or **external**, in the cluster's advanced configuration, through
the workload's own gateway. That gateway needs a load-balancer provider on
the cluster: cloud clusters have one; on bare metal or k3s, install one
(for example MetalLB) before your first cluster.
