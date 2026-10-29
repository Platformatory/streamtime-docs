---
title: Terraform
nav_order: 5
parent: Getting Started
permalink: /getting-started/terraform/
---

Manage Streamtime as code with the Streamtime Terraform provider. This page
covers installing it, signing in, and a first resource. The
[reference]({{ '/terraform/' | relative_url }}) documents every resource.

## Install

Add the provider to your configuration and run `terraform init`.

```hcl
terraform {
  required_providers {
    streamtime = {
      source = "streamtime-ai/streamtime"
    }
  }
}
```

### Without internet access

On a network that cannot reach the Terraform Registry, download the provider
release for your platform from the provider's releases page on a connected
machine, then point Terraform at a local folder with a
[provider mirror](https://developer.hashicorp.com/terraform/cli/config/config-file#explicit-installation-method-configuration)
in your Terraform CLI configuration:

```hcl
provider_installation {
  filesystem_mirror {
    path    = "/opt/terraform/providers"
    include = ["streamtime-ai/streamtime"]
  }
}
```

## Connect to your installation

Set the address of your installation and your organization. There is no
default address.

```hcl
provider "streamtime" {
  api_url      = "https://api.example.com"
  organization = "acme"
}
```

Each setting is looked up in this order, and the first one found is used:

1. the `provider` block;
2. the environment: `STREAMTIME_API_URL`, `STREAMTIME_ORG`, `STREAMTIME_API_KEY`, `STREAMTIME_TOKEN`;
3. your Streamtime CLI login (the current context of the first config file found: `STREAMTIME_CONFIG`, then `./streamtime.yaml`, then `~/.streamtime/config.yaml`, the same order the CLI uses).

If you have already run `streamtime login`, the provider block can be empty.

### Sign in

| Use | When |
|---|---|
| **API key** (`api_key` or `STREAMTIME_API_KEY`) | CI, and any run that may last long. It does not expire with a login. |
| **Login token** (`token`, `STREAMTIME_TOKEN`, or your CLI login) | Working at your own machine. It expires. |

Set one or the other in the provider block, not both. If a run stops with
*Your login has expired*, run `streamtime login` again, or switch to an API
key.

Mark keys as sensitive and pass them in with a variable or the environment.
Never write them into a `.tf` file you commit.

### Private certificate authority

If your installation uses a certificate from your own authority, set
`ca_cert_file` to the PEM file of that authority. `insecure_skip_verify = true`
turns verification off. Use it only on throwaway environments.

## Match the provider to your installation

The provider reads your installation's version when it starts.

| Provider compared with your installation | Result |
|---|---|
| Same version | Runs. |
| Provider is older | Runs, with a warning. Newer features of your installation may not be available. |
| Provider is newer | **Stops with an error.** Install the provider release that matches your installation. |
| Your installation runs a nightly or development build | Runs, with a warning. No comparison is made. |

## Create your first resource

```hcl
resource "streamtime_secret" "db_password" {
  path    = "apps/db-password"
  content = var.db_password
}

variable "db_password" {
  type      = string
  sensitive = true
}
```

Run `terraform plan`, then `terraform apply`. The value of `content` is never
shown in plans or logs. Streamtime does not return it either, so
`terraform import` brings in the secret but not its value. Set `content` in
your configuration and apply to write it.

Task pages elsewhere in these docs show the Terraform way of doing a task in
a **Terraform** tab, next to the UI, API, CLI and MCP tabs, for the tasks the
provider supports.

## Resources

See the [reference]({{ '/terraform/' | relative_url }}) for each resource.
More resources are added over time; a resource is documented once the
provider supports it.
