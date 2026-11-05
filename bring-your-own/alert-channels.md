---
title: Alert channels
parent: Bring your own
nav_order: 10
permalink: /bring-your-own/alert-channels/
---

# Alert channels

Alerts always show in the console. An **alert channel** also sends them
where your team works:

| Type | What you need |
|---|---|
| **Slack** | The channel name or ID, and an incoming webhook URL for it |
| **PagerDuty** | The integration (routing) key of a PagerDuty service. Optionally the PagerDuty API URL, and a client name and link shown in incidents |
| **Webhook** | Any URL that accepts a JSON `POST`. Optionally a proxy, basic auth, or a token sent in the `Authorization` header |

A fleet sends its alerts, and those of the workloads on it, to the
channels in its configuration. Which alerts fire is set by the
[alert rules]({{ site.baseurl }}/operations/alerts-diagnostics/).

{% include api-setup.md id="alert-channels" %}

## Add an alert channel

{% capture ui %}
1. Go to **Settings → Alert Channels** and select **Create Alert
   Channel**.
2. Enter an **Identifier** and choose the **Receiver Type**.
3. **Slack:** **Channel** and **Webhook URL**. **PagerDuty:** **Routing
   Key**, and optionally **URL**, **Client** and **Client URL**.
   **Webhook:** **URL**, and optionally **Proxy URL**, basic auth or
   **Auth Token**.
4. Save.
{% endcapture %}

{% capture curl %}
```bash
curl -X POST "$API/alert-channels/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"identifier": "ops", "type": "slack",
       "receiver_config": {"receiver_type": "slack", "channel": "#operations",
                           "api_url": "https://hooks.slack.com/services/<path>"}}'
```

Then list it in a fleet's configuration:

```bash
curl -X PATCH "$API/fleet/<fleet>/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"config": {"alert_channels": ["ops"]}}'
```

The fields each type takes: `GET $API/alert-channels/configuration-profiles/`.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.alert_channels import organizations_alert_channels_create
from streamtime_sdk.models import AlertChannel

organizations_alert_channels_create.sync(
    ORG,
    client=client,
    body=AlertChannel.from_dict({
        "identifier": "ops",
        "type": "slack",
        "receiver_config": {
            "receiver_type": "slack",
            "channel": "#operations",
            "api_url": "https://hooks.slack.com/services/<path>",
        },
    }),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsAlertChannelsCreate } from "./client";

await organizationsAlertChannelsCreate({
  path: { org_identifier: org },
  body: {
    identifier: "ops",
    type: "slack",
    receiver_config: {
      receiver_type: "slack",
      channel: "#operations",
      api_url: "https://hooks.slack.com/services/<path>",
    },
  },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/alert-channels/", map[string]any{
    "identifier": "ops",
    "type":       "slack",
    "receiver_config": map[string]any{
        "receiver_type": "slack",
        "channel":       "#operations",
        "api_url":       "https://hooks.slack.com/services/<path>",
    },
})
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="alert-channel-add-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime alert-channel create --config '{"identifier": "ops", "type": "slack",
  "receiver_config": {"receiver_type": "slack", "channel": "#operations",
                      "api_url": "https://hooks.slack.com/services/<path>"}}'
streamtime alert-channel config-schema   # the fields each type takes
```
{% endcapture %}

{% capture mcp %}
Not available in MCP. MCP reads the alerts themselves: *"Which alerts
are firing on the payments fleet?"*
{% endcapture %}

{% capture terraform %}
```hcl
variable "slack_webhook_url" {
  type      = string
  sensitive = true
}

resource "streamtime_alert_channel" "ops" {
  identifier = "ops"
  type       = "slack"
  receiver_config = jsonencode({
    api_url = var.slack_webhook_url
    channel = "#operations"
  })
}
```

```bash
terraform import streamtime_alert_channel.ops ops
```

The provider fills `receiver_type` from `type` when you leave it out.
Webhook channels need `url`; PagerDuty channels need `routing_key`. The
configuration is sensitive and kept in Terraform state. Changing the
destination updates the channel in place; changing its identifier
replaces it. `terraform destroy` removes the channel from Streamtime.

See [streamtime_alert_channel]({{ site.baseurl }}/terraform/alert-channel/).
{% endcapture %}

{% include tabs.html id="alert-channel-add" ui=ui api=api cli=cli mcp=mcp terraform=terraform %}
