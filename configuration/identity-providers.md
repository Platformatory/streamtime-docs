---
title: Identity providers
parent: Bring your own
nav_order: 2
permalink: /configuration/identity-providers/
---

# Identity providers

Every organization signs its people in through one **primary identity
provider**. The same provider issues the tokens Kafka clients use with
OAuth on that organization's clusters.

| Choice | When to use it |
|---|---|
| **Streamtime identity** | Built in, for trials and non-production environments only |
| **Streamtime private identity service** | The identity service deployed alongside your Streamtime installation; its addresses are filled in for you |
| **Your own identity provider** | Okta, Microsoft Entra ID, Ping Identity, Google, Auth0, Keycloak, or any other OIDC provider. Access is then granted and revoked where you already manage people |

The installation's sign-in is chosen in first-time setup, at the
**Sign-in** step. After that, each organization adds identity providers
under **Settings → Identity providers** and picks its **Primary OIDC
provider** under **Settings → Organization**.

## Before you start

1. Register Streamtime as an application (an OIDC client) in your
   identity provider, and note its **Client ID** and **Client Secret**.
2. Note the provider's **Issuer** URL. Streamtime reads the other
   addresses (token, signing keys, sign-in) from the issuer's discovery
   document.
3. Check which token claims carry the user's ID, email and groups
   (usually `sub`, `email` and `groups`).

{% include api-setup.md id="idp" %}

## Add an identity provider

{% capture ui %}
1. Go to **Settings → Identity providers** and create an identity
   provider.
2. Enter an **Identifier** and the **Issuer**, then select **Auto-fill**
   to fill **Token Endpoint**, **JWKS Endpoint** and **Authorize
   Endpoint** from discovery.
3. Enter **Client ID** and **Client Secret**. If your provider supports
   Dynamic Client Registration, fill in **Dynamic Client Registration
   (optional)** instead and Streamtime registers itself.
4. Under **Advanced Settings**, check **Sub Claim Name**, **Email Claim
   Name** and **Groups Claim Name**; set **Audience**, **Scope**, **Groups
   Claim Scope**, **Refresh Token** or a **TLS Trusted Certificate
   (optional)** if your provider needs them.
5. Save. To make it the organization's sign-in, go to **Settings →
   Organization** and choose it as **Primary OIDC provider**.
{% endcapture %}

{% capture curl %}
```bash
curl -X POST "$API/oauth-providers/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"identifier": "sso",
       "issuer": "https://accounts.example.com",
       "jwks_endpoint_uri": "https://accounts.example.com/keys",
       "token_endpoint_uri": "https://accounts.example.com/token",
       "authorize_endpoint_uri": "https://accounts.example.com/authorize",
       "client_id": "streamtime", "client_secret": "<client-secret>",
       "sub_claim_name": "sub", "email_claim_name": "email",
       "groups_claim_name": "groups"}'
```

Change it with `PATCH $API/oauth-providers/<identifier>/`.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.o_auth_providers import organizations_oauth_providers_create
from streamtime_sdk.models import OAuthProvider

organizations_oauth_providers_create.sync(
    ORG,
    client=client,
    body=OAuthProvider.from_dict({
        "identifier": "sso",
        "issuer": "https://accounts.example.com",
        "jwks_endpoint_uri": "https://accounts.example.com/keys",
        "token_endpoint_uri": "https://accounts.example.com/token",
        "authorize_endpoint_uri": "https://accounts.example.com/authorize",
        "client_id": "streamtime",
        "client_secret": "<client-secret>",
    }),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsOauthProvidersCreate } from "./client";

await organizationsOauthProvidersCreate({
  path: { org_identifier: org },
  body: {
    identifier: "sso",
    issuer: "https://accounts.example.com",
    jwks_endpoint_uri: "https://accounts.example.com/keys",
    token_endpoint_uri: "https://accounts.example.com/token",
    authorize_endpoint_uri: "https://accounts.example.com/authorize",
    client_id: "streamtime",
    client_secret: "<client-secret>",
  },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/oauth-providers/", map[string]any{
    "identifier":             "sso",
    "issuer":                 "https://accounts.example.com",
    "jwks_endpoint_uri":      "https://accounts.example.com/keys",
    "token_endpoint_uri":     "https://accounts.example.com/token",
    "authorize_endpoint_uri": "https://accounts.example.com/authorize",
    "client_id":              "streamtime",
    "client_secret":          "<client-secret>",
})
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="idp-add-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime oauth-provider create --identifier sso \
  --issuer https://accounts.example.com \
  --jwks-uri https://accounts.example.com/keys \
  --token-uri https://accounts.example.com/token \
  --authorize-uri https://accounts.example.com/authorize \
  --client-id streamtime --client-secret "$CLIENT_SECRET"
streamtime oauth-provider list
```

Changing a provider in place isn't available in the CLI; use the API or
Terraform.
{% endcapture %}

{% capture mcp %}
Not available in MCP.
{% endcapture %}

{% capture terraform %}
```hcl
variable "oidc_client_secret" {
  type      = string
  sensitive = true
}

resource "streamtime_oauth_provider" "sso" {
  identifier             = "sso"
  issuer                 = "https://accounts.example.com"
  client_id              = "streamtime"
  client_secret          = var.oidc_client_secret
  jwks_endpoint_uri      = "https://accounts.example.com/keys"
  token_endpoint_uri     = "https://accounts.example.com/token"
  authorize_endpoint_uri = "https://accounts.example.com/authorize"
}
```

Changing credentials updates the provider in place; changing its
identifier replaces it. The client secret stays in sensitive Terraform
state because it can't be read back. Deleting the resource removes the
registration in Streamtime, not your identity provider.

```bash
terraform import streamtime_oauth_provider.sso sso
```

After an import, set the client secret in the configuration before you
apply. See [streamtime_oauth_provider]({{ site.baseurl }}/terraform/oauth-provider/).
{% endcapture %}

{% include tabs.html id="idp-add" ui=ui api=api cli=cli mcp=mcp terraform=terraform %}

## Automation

Scripts, CI and Terraform sign in with an **API key** or, with
Streamtime identity, an **OAuth client** (**Settings → OAuth Clients**),
not with a person's account.
