---
title: "DNS & certificates"
parent: Bring your own
nav_order: 5
permalink: /configuration/domains-certificates/
---

# DNS & certificates

Every fleet publishes its endpoints (Kafka bootstrap and brokers, REST,
Schema Registry, Connect, dashboards) under a **base domain**, protected
by one wildcard **fleet certificate** that every cluster in the fleet
reuses. You choose who owns the DNS zone and the certificate:

| Mode | DNS | Certificate | Credentials stored |
|---|---|---|---|
| **Streamtime Managed** | A `*.<subdomain>.streamti.me` domain; records created for you | Wildcard certificate issued for you | None. Needs a Streamtime license |
| **Bring Your Own Zone** | Your zone in **AWS Route53**, **Cloudflare** or **GoDaddy**; Streamtime creates the records for each new fleet and cluster | Issued for you automatically (**Auto Create Certificates**), or one you upload. GoDaddy always needs an uploaded certificate | Your DNS provider credentials |
| **Customer Managed** | You create the records Streamtime shows you | One you upload | None |

The certificate on the console and API is a different one: see
[Gateway certificate]({{ site.baseurl }}/bring-your-own/gateway-certificate/).

## Before you start

| DNS provider | What Streamtime needs |
|---|---|
| **AWS Route53** | An access key ID and secret access key allowed to change records in the hosted zone, and its AWS region. The hosted zone is found from the domain name |
| **Cloudflare** | An API token with **DNS:Edit** permission for the zone. The zone is found from the domain name |
| **GoDaddy** | An API key and secret (create them at developer.godaddy.com), and a certificate to upload |
| **Streamtime DNS** | A free subdomain name, and a Streamtime license |
| **None** | A wildcard certificate and its key to upload; you create the DNS records |

An uploaded certificate is a PEM wildcard certificate for the domain
(`*.example.com`) with its private key.

{% include api-setup.md id="dns" %}

## Add a base domain

{% capture ui %}
1. Go to **Settings → DNS & Certificates** and add a domain. (First-time
   setup offers the same choice at **Domain & TLS**, as **Streamtime
   Managed**, **Bring Your Own Zone** or **Customer Managed**.)
2. Enter the **Domain** and choose the DNS provider: **AWS Route53**,
   **Cloudflare**, **GoDaddy**, **Streamtime DNS** or **None**.
3. Enter the provider's credentials: for Route53 **AWS Access Key ID**,
   **AWS Secret Access Key** and **AWS Region**; for Cloudflare the **API
   Token**; for GoDaddy **API Key** and **API Secret**; for Streamtime DNS
   the **Subdomain** to claim.
4. Leave **Auto Create Certificates** on to have the fleet certificate
   issued for you, or turn it off and upload **TLS Certificate** and **TLS
   Key**.
5. Save. Fleets you create can now use the domain.
{% endcapture %}

{% capture curl %}
```bash
# Bring Your Own Zone: Cloudflare, certificates issued for you.
curl -X POST "$API/base-domains/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"domain": "example.com", "auto_create_certificates": true,
       "dns_provider_config": {"dns_provider": {
         "provider_type": "cloudflare", "zone_id": "<zone-id>", "api_token": "<api-token>"}}}'

# Customer Managed: no DNS provider, your own certificate.
jq -n --rawfile cert wildcard.pem --rawfile key wildcard.key \
  '{domain: "example.com", auto_create_certificates: false,
    dns_provider_config: {dns_provider: {provider_type: "none"}},
    tls_cert: $cert, tls_key: $key}' |
curl -X POST "$API/base-domains/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d @-
```

`provider_type` is `route53` (`aws_access_key`, `aws_access_secret`,
`aws_region`), `cloudflare` (`zone_id`, `api_token`), `godaddy`
(`api_key`, `api_secret`), `stdns` or `none`. The fields of each:
`GET $API/base-domains/configuration-profiles/`.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.base_domains import organizations_base_domains_create
from streamtime_sdk.models import BaseDomain

organizations_base_domains_create.sync(
    ORG,
    client=client,
    body=BaseDomain.from_dict({
        "domain": "example.com",
        "auto_create_certificates": True,
        "dns_provider_config": {"dns_provider": {
            "provider_type": "cloudflare",
            "zone_id": "<zone-id>",
            "api_token": "<api-token>",
        }},
    }),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsBaseDomainsCreate } from "./client";

await organizationsBaseDomainsCreate({
  path: { org_identifier: org },
  body: {
    domain: "example.com",
    auto_create_certificates: true,
    dns_provider_config: {
      dns_provider: { provider_type: "cloudflare", zone_id: "<zone-id>", api_token: "<api-token>" },
    },
  },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/base-domains/", map[string]any{
    "domain":                   "example.com",
    "auto_create_certificates": true,
    "dns_provider_config": map[string]any{"dns_provider": map[string]any{
        "provider_type": "cloudflare",
        "zone_id":       "<zone-id>",
        "api_token":     "<api-token>",
    }},
})
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="dns-add-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime domain create --domain example.com --auto-certs \
  --dns-config '{"dns_provider": {"provider_type": "cloudflare",
                                  "zone_id": "<zone-id>", "api_token": "<api-token>"}}'
streamtime domain dns-schema   # the fields each DNS provider takes
```
{% endcapture %}

{% capture mcp %}
Not available in MCP.
{% endcapture %}

{% capture terraform %}
```hcl
variable "cloudflare_zone_id" {
  type = string
}

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

resource "streamtime_base_domain" "example" {
  domain                   = "example.com"
  auto_create_certificates = true
  dns_provider_config = {
    dns_provider = {
      provider_type = "cloudflare"
      zone_id       = var.cloudflare_zone_id
      api_token     = var.cloudflare_api_token
    }
  }
}
```

```bash
terraform import streamtime_base_domain.example example.com
```

See [streamtime_base_domain]({{ site.baseurl }}/terraform/base-domain/).
{% endcapture %}

{% include tabs.html id="dns-add" ui=ui api=api cli=cli mcp=mcp terraform=terraform %}

## Use it for a fleet

Choose the base domain when you create a fleet (**Base Domain** in the
console, `--domain` in the CLI, `domain` in the API). The fleet's
endpoints are published under it, and its Kafka clusters reuse the
fleet's wildcard certificate.
