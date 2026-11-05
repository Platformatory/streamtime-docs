---
title: Gateway certificate
parent: Bring your own
nav_order: 4
permalink: /bring-your-own/gateway-certificate/
---

# Gateway certificate

The gateway certificate protects the console and the API, and every
connection a fleet makes to Streamtime. Fleets verify it on every
connection.

| Choice | What happens |
|---|---|
| **Generate a new certificate from the Streamtime CA (recommended)** | Streamtime signs a certificate with your installation's own CA, covering every name it needs. Fleets trust that CA, so a new certificate never needs a fleet change |
| **Use my own certificate** | You upload a certificate, its intermediates and its private key. It must cover every name Streamtime needs; Streamtime refuses one that doesn't and names what is missing |

With the highly available Helm install, the certificate comes from
cert-manager (Let's Encrypt) instead, and fleets trust Let's Encrypt's
public roots.

## Before you start

- **Your own certificate:** the certificate in PEM format, the
  intermediate certificates from your CA (fleets need the full chain), and
  the private key without a password.
- **Trusting the Streamtime CA on your machines:** the settings page shows
  the commands for macOS, Windows and Linux.

{% include api-setup.md id="gateway-cert" %}

## Replace the gateway certificate

{% capture ui %}
1. Go to **Settings → Connectivity**. The **Gateway Certificate** card
   shows the current certificate.
2. Choose **Generate a new certificate from the Streamtime CA
   (recommended)** and, optionally, add **Extra hostnames or IP
   addresses** that people use to reach Streamtime. Or choose **Use my own
   certificate** and paste **Certificate**, **Intermediate certificates**
   and **Private key**, then select **Validate**.
3. Turn on **Tell browsers to always use HTTPS for these addresses
   (HSTS)** only when every user's browser trusts the certificate: a
   browser that has seen it won't let anyone click past a certificate
   warning.
4. Select **Replace certificate**. The gateway uses it after it restarts.
{% endcapture %}

{% capture curl %}
```bash
# Generate a new certificate with an extra name.
curl -X PUT "$API/settings/builtin-certificate/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"source": "generated", "extra_names": ["streamtime.example.com"]}'

# Or upload your own.
jq -n --rawfile cert cert.pem --rawfile chain chain.pem --rawfile key key.pem \
  '{source: "uploaded", cert_pem: $cert, chain_pem: $chain, key_pem: $key}' |
curl -X PUT "$API/settings/builtin-certificate/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d @-
```

`GET $API/settings/builtin-certificate/` shows the current certificate;
the private key is never returned. A `400` names the missing names or the
problem with an uploaded certificate.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.settings import settings_builtin_certificate_update
from streamtime_sdk.models import BuiltinCertificateSettingWrite

settings_builtin_certificate_update.sync(
    ORG,
    client=client,
    body=BuiltinCertificateSettingWrite.from_dict(
        {"source": "generated", "extra_names": ["streamtime.example.com"]}
    ),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { settingsBuiltinCertificateUpdate } from "./client";

await settingsBuiltinCertificateUpdate({
  path: { org_identifier: org },
  body: { source: "generated", extra_names: ["streamtime.example.com"] },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("PUT", "/settings/builtin-certificate/", map[string]any{
    "source":      "generated",
    "extra_names": []string{"streamtime.example.com"},
})
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="gateway-cert-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet. Use the console or the API.
{% endcapture %}

{% capture mcp %}
Not available in MCP yet.
{% endcapture %}

{% include tabs.html id="gateway-cert" ui=ui api=api cli=cli mcp=mcp %}

## Fleet certificates are separate

The certificate on your Kafka endpoints is the fleet certificate, one
wildcard per fleet. See [DNS & certificates]({{ site.baseurl }}/configuration/domains-certificates/).
