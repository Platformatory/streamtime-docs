---
title: Secrets
parent: Bring your own
nav_order: 6
permalink: /bring-your-own/secrets/
---

# Secrets

Credentials Streamtime holds for you (cloud account keys, kubeconfigs,
SSH keys, DNS and monitoring credentials, Kafka passwords) live in a
secret store, never in plain configuration.

| Store | What it is |
|---|---|
| **Built-in vault (default)** | An encrypted store inside Streamtime. Nothing to set up |
| **HashiCorp Vault (AppRole sign-in)** | Your own Vault server keeps the secrets and Streamtime's encryption keys, with automatic key rotation |

The store is chosen in first-time setup, at the **Secrets Vault** step.
**Settings → Secrets Management** then lists the secrets Streamtime holds,
and lets you add your own and choose which store each one goes to.

## Before you start: HashiCorp Vault

From your Vault administrator:

- The **Vault URL**. The Streamtime server must be able to reach it.
- The **Namespace**, if you use Vault Enterprise namespaces.
- An AppRole **Role ID** and **Secret ID** for Streamtime. Treat both as
  credentials.
- Where AppRole sign-in is mounted (**Auth Mount Path**) and where the
  secrets go (**Secrets Mount Path**, a KV version 2 engine), if not at
  Vault's usual paths.

## Use HashiCorp Vault

{% capture ui %}
1. In first-time setup, at the **Secrets Vault** step, choose **HashiCorp
   Vault (AppRole sign-in)**.
2. Enter **Vault URL**, **Namespace (optional)**, **Role ID** and **Secret
   ID**. Change **Auth Mount Path** and **Secrets Mount Path** only if your
   administrator mounted them elsewhere.
3. Select **Test Connection**, then continue.
{% endcapture %}
{% capture api %}
The store is set during first-time setup only; there is no published API
for it yet.
{% endcapture %}
{% capture cli %}
Not available in the CLI.
{% endcapture %}
{% capture mcp %}
Not available in MCP.
{% endcapture %}
{% include tabs.html id="secrets-vault" ui=ui api=api cli=cli mcp=mcp %}

{% include api-setup.md id="secrets" %}

## Add a secret

Store a value under a path, for example for a workload setting that
refers to a secret.

{% capture ui %}
1. Go to **Settings → Secrets Management** and select **Create Secret**.
2. Choose the **Provider** (where to store it; it can't be changed later),
   enter a unique **Path** such as `apps/db-password`, and the
   **Content** as plain text or JSON.
3. Save. The value is never shown again.
{% endcapture %}

{% capture curl %}
```bash
curl -X POST "$API/secrets/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"path": "apps/db-password", "content": "<value>", "provider": "builtin"}'
```

`provider` is `builtin` or `vault`. List secrets with `GET $API/secrets/`
(values are not returned), and the stores available with
`GET $API/secrets/providers/`.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.secrets import organizations_secrets_create
from streamtime_sdk.models import Secret

organizations_secrets_create.sync(
    ORG,
    client=client,
    body=Secret.from_dict({"path": "apps/db-password", "content": "<value>"}),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsSecretsCreate } from "./client";

await organizationsSecretsCreate({
  path: { org_identifier: org },
  body: { path: "apps/db-password", content: "<value>" },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/secrets/", map[string]any{
    "path":    "apps/db-password",
    "content": "<value>",
})
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="secrets-add-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime secret create --path apps/db-password --from-file ./db-password.txt
streamtime secret list
```
{% endcapture %}

{% capture mcp %}
Not available in MCP.
{% endcapture %}

{% capture terraform %}
```hcl
variable "db_password" {
  type      = string
  sensitive = true
}

resource "streamtime_secret" "db_password" {
  path    = "apps/db-password"
  content = var.db_password
}
```

```bash
terraform import streamtime_secret.db_password <secret-id>
```

See [streamtime_secret]({{ site.baseurl }}/terraform/secret/).
{% endcapture %}

{% include tabs.html id="secrets-add" ui=ui api=api cli=cli mcp=mcp terraform=terraform %}
