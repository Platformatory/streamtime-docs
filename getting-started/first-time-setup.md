---
title: First-time setup
nav_order: 1.5
parent: Getting Started
permalink: /getting-started/first-time-setup/
---

# First-time setup

The first time you open the console of a new installation, a setup
wizard walks through what Streamtime needs before anyone can use it. Each
step saves as you go, so you can leave and come back. Optional steps can
be skipped and set later in **Settings**.

| # | Step | Required | What you decide |
|---|---|---|---|
| 1 | **Organization** | Yes | The root organization: the top-level account that owns every resource, user and organization, and its contact details for operational alerts, license notices and support. Its identifier can't be changed later. Also the installation's administrators |
| 2 | **License** | Yes | Your Streamtime license |
| 3 | **Sign-in** | Yes | How people sign in: Streamtime identity (non-production only), the private identity service deployed with Streamtime, or your own identity provider. See [Identity providers]({{ site.baseurl }}/configuration/identity-providers/) |
| 4 | **Encryption Key** | Yes | The one secret that encrypts all sensitive data at rest. A key is generated for you: **copy it to your secret manager before you continue.** It can't be recovered, and without it every encrypted record is unreadable |
| 5 | **Image Registries** | Yes | Read credentials for GitHub Container Registry and Quay.io (Docker Hub optional), and optionally a mirror registry. See [Container registry]({{ site.baseurl }}/bring-your-own/container-registry/) |
| 6 | **Domain & TLS** | No | The base domain and fleet certificates: Streamtime Managed, Bring Your Own Zone or Customer Managed. See [DNS & certificates]({{ site.baseurl }}/configuration/domains-certificates/) |
| 7 | **Orchestrator** | Yes | Where operations run: built in, Streamtime Managed or your own. See [Durable Executor]({{ site.baseurl }}/bring-your-own/durable-executor/) |
| 8 | **Connectivity** | No | The **Public API URL** and how fleets reach Streamtime: Tailscale or another tunnel. See [Connectivity]({{ site.baseurl }}/bring-your-own/connectivity/) |
| 9 | **Gateway Certificate** | No | The certificate on the console and API. See [Gateway certificate]({{ site.baseurl }}/bring-your-own/gateway-certificate/). With the Helm install's own certificates there is nothing to set |
| 10 | **Secrets Vault** | No | The built-in vault, or your HashiCorp Vault. See [Secrets]({{ site.baseurl }}/bring-your-own/secrets/) |
| 11 | **SMTP Email** | No | A mail server for health, alert and weekly report emails. See [Email]({{ site.baseurl }}/bring-your-own/email/) |
| 12 | **Cloud Accounts** | No | Cloud accounts Streamtime may create fleets in. See [Cloud Accounts]({{ site.baseurl }}/configuration/fleet-providers/) |
| 13 | **Package Catalog** | Yes | Imports the package catalog and its rules, starts Streamtime's background tasks and finishes setup |

After the last step you sign in to the root organization. Next:
[Interfaces]({{ site.baseurl }}/getting-started/interfaces/) to connect
the CLI, SDKs, MCP or Terraform, and
[User Management]({{ site.baseurl }}/getting-started/user-management/) to
create organizations and invite people.

{: .note }
The single image and Docker Compose can also be set up headless, without
the wizard: see [Installation]({{ site.baseurl }}/getting-started/installation/).
