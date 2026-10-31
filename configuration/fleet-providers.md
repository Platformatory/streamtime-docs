---
title: "Cloud Accounts"
nav_order: 4
parent: Configuration

---

# Cloud Accounts

A cloud account holds the credentials Streamtime uses to create and manage Kubernetes fleets in a cloud platform. Register one for each cloud account you want Streamtime to provision into; every fleet on that account uses it.

## Supported clouds

| Cloud | Description | Fleet guide |
| --- | --- | --- |
| AWS | Amazon Web Services, a widely used cloud platform. | [Fleets on AWS]({{ site.baseurl }}/fleet-management/aws/) |
| GCP | Google Cloud Platform, known for its data analytics and machine learning capabilities. | [Fleets on GCP]({{ site.baseurl }}/fleet-management/gcp/) |
| OCI | Oracle Cloud Infrastructure, focused on enterprise applications and databases. | [Fleets on Oracle Cloud]({{ site.baseurl }}/fleet-management/oracle/) |
| Azure | Microsoft Azure, a comprehensive cloud platform with strong enterprise integration. Experimental. | [Fleets on Azure]({{ site.baseurl }}/fleet-management/azure/) |
| DigitalOcean | DigitalOcean's managed Kubernetes. | [Fleets on DigitalOcean]({{ site.baseurl }}/fleet-management/digitalocean/) |
| Civo | Civo's managed Kubernetes. | [Fleets on Civo]({{ site.baseurl }}/fleet-management/civo/) |

Each cloud lets you create and operate Kubernetes fleets, which are the foundation for running Kafka clusters and other workloads. A fleet on your own Kubernetes cluster ([BYOK]({{ site.baseurl }}/fleet-management/byok/)) needs no cloud account.

## When to use a cloud account

- **Multi-cloud deployments**: when you want to use several clouds for redundancy or specific features.
- **Regional compliance**: when your workloads must run in specific regions for compliance or latency.
- **Cost optimization**: choose a cloud based on cost efficiency for your workloads.

## Before you start

- In your cloud, create a service account, IAM user or application registration that can provision and manage Kubernetes clusters and their related resources. Each fleet guide lists the exact permissions.
- Generate its credentials. The cloud account takes these:

  | Cloud | Credentials |
  | --- | --- |
  | AWS | Access key ID and secret access key (plus a session token for temporary credentials) |
  | GCP | The service account key, as the key file's JSON |
  | Azure | Subscription ID, tenant ID, client ID and client secret |
  | OCI | Tenancy OCID, user OCID, API key fingerprint and private key |
  | DigitalOcean | An API token |
  | Civo | An API token |

- For the API: an access token in `STREAMTIME_TOKEN` and your organization identifier in place of `<org>`. Replace `api.example.com` with your Streamtime API address.
- Only administrators and infrastructure administrators can manage cloud accounts.

{% include api-setup.md id="accounts" %}

---

## Add a cloud account

The examples register an AWS account. For another cloud, change the cloud and its credentials from the table above.

{% capture ui %}
1. Go to **Settings**, then **Bootstrap Providers**, and select **+ Add Bootstrap Provider**.
2. **Basic Information**: enter an **Identifier** for the account (lowercase letters, digits and dashes, up to 24 characters).

   ![Add cloud account form]({{ site.baseurl }}/assets/images/fleet-provider.png)
3. **Bootstrap Provider Details**: choose the cloud and fill in its credentials, then save.

The account appears in the list. Some clouds, such as AWS, are checked as you save: Streamtime refuses credentials the cloud rejects and says why. Streamtime checks the permissions again when you create a fleet.
{% endcapture %}

{% capture curl %}
```bash
curl -X POST "$API/bootstrap-providers/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "aws-prod",
    "provider": "aws",
    "configuration": {
      "aws_access_key": "<access-key-id>",
      "aws_access_secret": "<secret-access-key>"
    }
  }'
```

Returns `201` with the account. For some clouds, such as AWS, Streamtime checks the credentials with the cloud first and returns `400` with the cloud's reason when they are rejected.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.bootstrap_providers import organizations_bootstrap_providers_create
from streamtime_sdk.models import OrganizationsBootstrapProvidersCreateBody

account = organizations_bootstrap_providers_create.sync(
    ORG,
    client=client,
    body=OrganizationsBootstrapProvidersCreateBody.from_dict({
        "identifier": "aws-prod",
        "provider": "aws",
        "configuration": {
            "aws_access_key": "<access-key-id>",
            "aws_access_secret": "<secret-access-key>",
        },
    }),
)
print(account.identifier)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsBootstrapProvidersCreate } from "./client";

const { data } = await organizationsBootstrapProvidersCreate({
  path: { org_identifier: org },
  body: {
    identifier: "aws-prod",
    provider: "aws",
    configuration: {
      aws_access_key: "<access-key-id>",
      aws_access_secret: "<secret-access-key>",
    },
  },
});
console.log(data?.identifier);
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/bootstrap-providers/", json.RawMessage(`{
    "identifier": "aws-prod",
    "provider": "aws",
    "configuration": {
        "aws_access_key": "<access-key-id>",
        "aws_access_secret": "<secret-access-key>"
    }
}`))
// resp.StatusCode is 201 on success.
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="accounts-add-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime provider create \
  --identifier aws-prod \
  --type aws \
  --config '{"aws_access_key": "<access-key-id>", "aws_access_secret": "<secret-access-key>"}'
```

List your accounts with `streamtime provider list -O json`.
{% comment %}Gap: #1883 (the table output of list fails){% endcomment %}
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Register the account from the UI, API or CLI.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% capture terraform %}
```hcl
resource "streamtime_cloud_account" "aws" {
  identifier     = "aws-prod"
  cloud_provider = "aws"

  configuration = jsonencode({
    aws_access_key    = var.aws_access_key
    aws_access_secret = var.aws_access_secret
  })
}

variable "aws_access_key" {
  type = string
}

variable "aws_access_secret" {
  type      = string
  sensitive = true
}
```

`cloud_provider` is one of `aws`, `azure`, `gcp`, `oci`, `digitalocean` or `civo`, and `configuration` takes that cloud's credentials from the table above. Keep the values in sensitive variables or your secrets store, not in the file. To manage an account that already exists, import it by identifier: `terraform import streamtime_cloud_account.aws aws-prod`. See [streamtime_cloud_account]({{ site.baseurl }}/terraform/cloud-account/).
{% endcapture %}

{% include tabs.html id="accounts-add" ui=ui api=api cli=cli mcp=mcp terraform=terraform %}

---

## Update a cloud account's credentials

Rotate the credentials when the key expires or is replaced. Fleets already on the account keep running; later operations use the new credentials.

{% capture ui %}
1. Go to **Settings**, then **Bootstrap Providers**.
2. Select **Edit Credentials** on the account, enter the new credentials, and save.
{% endcapture %}

{% capture curl %}
```bash
curl -X PATCH "$API/bootstrap-providers/aws-prod/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "configuration": {
      "aws_access_key": "<new-access-key-id>",
      "aws_access_secret": "<new-secret-access-key>"
    }
  }'
```

Returns `200`.
{% endcapture %}
{% capture python %}
```python
resp = client.get_httpx_client().patch(
    f"/organizations/{ORG}/bootstrap-providers/aws-prod/",
    json={
        "configuration": {
            "aws_access_key": "<new-access-key-id>",
            "aws_access_secret": "<new-secret-access-key>",
        }
    },
)
resp.raise_for_status()  # 200
```
{% endcapture %}
{% capture typescript %}
```typescript
const { response } = await client.patch({
  url: "/organizations/{org_identifier}/bootstrap-providers/{identifier}/",
  path: { org_identifier: org, identifier: "aws-prod" },
  body: {
    configuration: {
      aws_access_key: "<new-access-key-id>",
      aws_access_secret: "<new-secret-access-key>",
    },
  },
});
console.log(response.status); // 200
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("PATCH", "/bootstrap-providers/aws-prod/", map[string]any{
    "configuration": map[string]any{
        "aws_access_key":    "<new-access-key-id>",
        "aws_access_secret": "<new-secret-access-key>",
    },
})
// resp.StatusCode is 200.
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="accounts-update-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet. Change the credentials from the UI or the API.
{% comment %}Gap: #1882{% endcomment %}
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Change the credentials from the UI or the API.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% capture terraform %}
Change the values `configuration` is built from and run `terraform apply`. Terraform keeps the value you set and doesn't read credentials back, so a change made outside Terraform isn't detected.
{% endcapture %}

{% include tabs.html id="accounts-update" ui=ui api=api cli=cli mcp=mcp terraform=terraform %}

---

## Remove a cloud account

{: .warning }
Delete every fleet on the account first, and wait until they are gone. Streamtime doesn't stop you from removing an account that fleets still use, and without it those fleets can't be torn down.

{% capture ui %}
1. Go to **Settings**, then **Bootstrap Providers**.
2. Select **Delete** on the account and confirm.
{% endcapture %}

{% capture curl %}
```bash
curl -X DELETE "$API/bootstrap-providers/aws-prod/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN"
```

Returns `204`.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.bootstrap_providers import organizations_bootstrap_providers_destroy

resp = organizations_bootstrap_providers_destroy.sync_detailed(
    ORG, "aws-prod", client=client
)
print(resp.status_code)  # 204
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsBootstrapProvidersDestroy } from "./client";

await organizationsBootstrapProvidersDestroy({
  path: { org_identifier: org, identifier: "aws-prod" },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("DELETE", "/bootstrap-providers/aws-prod/", nil)
// resp.StatusCode is 204.
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="accounts-remove-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime provider delete aws-prod --yes
```
{% endcapture %}

{% capture mcp %}
Not available in MCP yet. Remove the account from the UI, API or CLI.
{% comment %}Gap: #1811{% endcomment %}
{% endcapture %}

{% capture terraform %}
```bash
# Preview what will be removed, then remove it.
terraform plan -destroy -target=streamtime_cloud_account.aws
terraform destroy -target=streamtime_cloud_account.aws
```

Terraform deletes the fleets that depend on the account first when they are in the same configuration, so check that the plan lists them. It only follows dependencies it can see: fleets managed in another configuration or outside Terraform aren't checked, so delete them first.
{% endcapture %}

{% include tabs.html id="accounts-remove" ui=ui api=api cli=cli mcp=mcp terraform=terraform %}

## Next steps

Create a fleet on the account with the guide for your cloud, listed under [Supported clouds](#supported-clouds).
