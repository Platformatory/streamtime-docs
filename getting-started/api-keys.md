---
title: API keys and OAuth clients
nav_order: 5
parent: Getting Started
permalink: /getting-started/api-keys/
---

# API keys and OAuth clients

Automation shouldn't sign in as a person. Streamtime has two kinds of
machine credential:

| | API key | OAuth client |
|---|---|---|
| For | Scripts, CI, Terraform, MCP clients and the CLI | Applications that sign in with OAuth client credentials, for example a Kafka producer |
| Scope | One organization, one role | One organization, optionally limited to some Kafka clusters |
| Available | Always | With **Streamtime identity** as the sign-in |
| Sent as | `X-Streamtime-Key` header | A token from the OAuth token endpoint |

The key or secret is shown **once**, when it is created or rotated. Store
it in your secret manager straight away.

## API key roles

Give each key the least it needs. A key has one of these roles:
**Agent** (the least privileged), **MCP Agent** (required to connect an
MCP client), **Cluster Administrator**, **Infrastructure Administrator**,
**Billing Administrator** or **Administrator** (everything in the
organization). The roles are the same ones people have; see
[User Management]({{ site.baseurl }}/getting-started/user-management/).

{% include api-setup.md id="api-keys" %}

## Create an API key

{% capture ui %}
1. Open the **API Keys** page from the account menu (organization
   administrators).
2. Select **Create API Key**, enter a **Name** and choose the **Role**.
3. Copy the key now; it isn't shown again.
{% endcapture %}

{% capture curl %}
```bash
curl -X POST "$API/api-keys/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"name": "ci", "role": "Cluster Administrator"}'
```

The response's `key` is the only time the key is returned. List keys with
`GET $API/api-keys/`; revoke one with `DELETE $API/api-keys/<id>/`.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.api_keys import organizations_api_keys_create
from streamtime_sdk.models import APIKEY

created = organizations_api_keys_create.sync(
    ORG, client=client, body=APIKEY.from_dict({"name": "ci", "role": "Cluster Administrator"})
)
print(created.key)  # shown once
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsApiKeysCreate } from "./client";

const { data } = await organizationsApiKeysCreate({
  path: { org_identifier: org },
  body: { name: "ci", role: "Cluster Administrator" },
});
console.log(data?.key); // shown once
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/api-keys/", map[string]any{
    "name": "ci",
    "role": "Cluster Administrator",
})
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="api-key-create-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime api-key create --name ci --role "Cluster Administrator"
streamtime api-key list
streamtime api-key rotate <key-id>
streamtime api-key delete <key-id>
```

Always pass `--role`; the CLI's default role isn't one of the roles above.
{% endcapture %}

{% capture mcp %}
Not available in MCP.
{% endcapture %}

{% capture terraform %}
```hcl
resource "streamtime_api_key" "ci" {
  name = "ci"
  role = "Cluster Administrator"
}
```

The key value is sensitive and kept in Terraform state after creation; an
import can't recover it, so protect the state storage. Destroying the
resource revokes the key.

```bash
terraform import streamtime_api_key.ci '<key-id>'
```

See [streamtime_api_key]({{ site.baseurl }}/terraform/api-key/).
{% endcapture %}

{% include tabs.html id="api-key-create" ui=ui api=api cli=cli mcp=mcp terraform=terraform %}

## Create an OAuth client

{% capture ui %}
1. Go to **Settings → OAuth Clients** (shown when the organization signs
   in with Streamtime identity) and select **Create OAuth Client**.
2. Enter an **Identifier** and a **Name**, and optionally limit it to some
   **Kafka clusters**.
3. Select **Create** and copy the client secret; it isn't shown again.
   **Rotate secret** issues a new one.
{% endcapture %}

{% capture curl %}
```bash
curl -X POST "$API/oauth-clients/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"identifier": "producer", "name": "Order producer", "kafka_clusters": ["orders"]}'

# New secret
curl -X POST "$API/oauth-clients/producer/rotate/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
```
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.o_auth_clients import organizations_oauth_clients_create
from streamtime_sdk.models import OAuthClientWrite

organizations_oauth_clients_create.sync(
    ORG,
    client=client,
    body=OAuthClientWrite.from_dict(
        {"identifier": "producer", "name": "Order producer", "kafka_clusters": ["orders"]}
    ),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsOauthClientsCreate } from "./client";

await organizationsOauthClientsCreate({
  path: { org_identifier: org },
  body: { identifier: "producer", name: "Order producer", kafka_clusters: ["orders"] },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/oauth-clients/", map[string]any{
    "identifier":     "producer",
    "name":           "Order producer",
    "kafka_clusters": []string{"orders"},
})
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="oauth-client-create-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet. Use the console, the API or Terraform.
{% endcapture %}

{% capture mcp %}
Not available in MCP.
{% endcapture %}

{% capture terraform %}
```hcl
resource "streamtime_oauth_client" "producer" {
  identifier     = "producer"
  name           = "Order producer"
  kafka_clusters = ["orders"]
}
```

Its access settings can't be changed in place, so a change replaces the
client. The secret is sensitive and kept in Terraform state; destroying
the resource revokes the client.

```bash
terraform import streamtime_oauth_client.producer producer
```

See [streamtime_oauth_client]({{ site.baseurl }}/terraform/oauth-client/).
{% endcapture %}

{% include tabs.html id="oauth-client-create" ui=ui api=api cli=cli mcp=mcp terraform=terraform %}
