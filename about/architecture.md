---
title: Architecture
nav_order: 2
permalink: /about/architecture/
parent: About Streamtime
---

# Architecture

Streamtime is a management plane for streaming workloads. One **control
plane** records what you want running and drives it into existence;
one **agent per fleet** carries out the work inside your clusters.
This page describes the parts you interact with, how they connect, and
what you can bring of your own.

## The big picture

![Your console and API clients reach the control plane through one gateway; the Durable Executor sends work to the agent in your fleet over a private connection, and the agent runs your workloads.]({{ '/assets/images/architecture/overview.svg' | relative_url }})

The gateway is the only way in: the console, the REST API, the SDKs,
the CLI and the MCP server all arrive through the same door, and the
organization in the URL path scopes everything behind it. The agent
inside a fleet **never calls the Streamtime API**: it receives work from
the control plane over a private connection and reports results back
the same way, which is what lets fleets sit behind firewalls.

## The control plane

How the pieces divide the work:

- **Gateway** — verifies sign-in tokens against your organization's
  identity provider, applies rate limits, and routes
  `/organizations/<org>/…` to the right service. It is the single point
  of entry for every interface.
- **API service** — the system of record. Every fleet, workload,
  version and command is recorded here first, with a full audit trail.
  A request that starts an operation returns `202` immediately with an
  **Operation ID**, and the client polls status.
- **Streamtime Durable Executor** — runs each Create, Update and Delete operation
  to completion, retrying safely through failures and restarts. It
  provisions cloud infrastructure, records every resource ID as it goes,
  and hands in-cluster work to the fleet's agent.
- **Agent (one per fleet)** — runs inside the fleet. Installs and
  upgrades workloads, keeps Kubernetes state as recorded, and reports
  drift and results back. It never calls the Streamtime API.
- **MCP server** — part of the API service, so MCP tools see exactly
  what the REST API sees; it is a different door, not a different
  system.

Each consumer — console, SDKs, CLI, MCP — is written against the same
published OpenAPI contract, so what you can do in one interface maps
directly to the others.

## Connectivity

![People and tools reach the control plane's gateway over HTTPS. The fleet's agent and monitoring talk to the control plane over a private connection: Tailscale, another tunnel or your own network. Your applications reach Kafka through the workload's own gateway in the fleet, never through that connection.]({{ '/assets/images/architecture/connectivity.svg' | relative_url }})

Three kinds of traffic, each on its own path:

| Traffic | Path | Protected by |
|---|---|---|
| People and tools → Streamtime (console, API, CLI, MCP) | HTTPS to the control plane's gateway | The gateway certificate, and sign-in with your identity provider |
| Fleet ↔ Streamtime: the agent fetching work and reporting results, sign-in checks, image pulls from Streamtime, and Streamtime reading the fleet's metrics, logs and Kafka UI | The **private connection** | The gateway certificate: the fleet verifies every connection it makes |
| Your applications → Kafka (brokers, REST, Schema Registry, Connect) | The workload's own gateway inside the fleet, **never** the private connection | The fleet certificate, and the cluster's own client authentication |

Choose the private connection in **Settings → Connectivity** (also a step
of first-time setup):

- **Tailscale (recommended).** Streamtime and each fleet join your
  tailnet. Streamtime derives every address from the tailnet name, so
  there is nothing else to save. The settings page lists the two tags and
  the OAuth client to create in Tailscale.
- **Other tunnel.** Any other tunnel (ngrok, Cloudflare Tunnel and the
  like), or your own network with no tunnel at all: public DNS and a load
  balancer, a VPN or network peering. Save the addresses fleets use to
  reach Streamtime (**Orchestrator Tunnel URL**, **Registry Tunnel URL**)
  and select **Test connectivity**; Streamtime checks each one from the
  server.

Kafka traffic is exposed per cluster, **internal** (inside the fleet's
network) or **external**, in the cluster's advanced configuration. The
workload gateway needs a load-balancer provider on the cluster: cloud
clusters have one; on bare metal or k3s, install one (for example
MetalLB) before your first cluster.

{: .note }
Connectivity and certificate settings reach a fleet that already exists
through **Update Agent** on the fleet's **Agent Management** tab. You
never reinstall a fleet to change them.

## Certificates and trust

Streamtime uses two certificates, for two different audiences:

| | Gateway certificate | Fleet certificate |
|---|---|---|
| Protects | The console and API, and every connection a fleet makes to Streamtime | The Kafka endpoints in one fleet: brokers, REST, Schema Registry, Connect |
| Set in | **Settings → Connectivity** | **Settings → DNS & Certificates** |
| Choices | **Generate a new certificate from the Streamtime CA** (recommended), or **Use my own certificate** | **Streamtime Managed**, **Bring Your Own Zone** or **Customer Managed** (below) |
| Shared by | Everything that reaches the control plane | Every Kafka cluster in the fleet (one wildcard certificate per fleet) |

**Gateway certificate.**

- A generated certificate is signed by your installation's own
  Streamtime CA and covers every name Streamtime needs. Fleets trust that
  CA, so when Streamtime issues a new certificate (for example after you
  add a name) no fleet needs a change.
- Add the other names people use to reach Streamtime under **Extra
  hostnames or IP addresses**.
- To trust the CA on your own machines, follow the commands the settings
  page shows for macOS, Windows and Linux.
- With your own certificate, it must cover every name Streamtime needs.
  Streamtime refuses one that doesn't and names what is missing. If a
  public CA issued it, include the full chain, so fleets can verify it.
- **Tell browsers to always use HTTPS for these addresses (HSTS)** is
  off by default. Turn it on only when every user's browser trusts the
  certificate: a browser that has seen HSTS will not let anyone click
  past a certificate warning.
- With the highly available Helm install, the gateway certificate comes
  from cert-manager (Let's Encrypt), and fleets trust Let's Encrypt's
  public roots, so renewals need no fleet change either.

**Fleet certificate and DNS.**

- **Streamtime Managed:** a `*.<subdomain>.streamti.me` domain and a
  wildcard certificate, with DNS records created for you. Needs a license.
- **Bring Your Own Zone:** your DNS zone (Route 53 or Cloudflare) and
  your certificate. Streamtime stores the DNS credentials and creates the
  records for each new fleet and cluster.
- **Customer Managed:** you upload the certificate and create the DNS
  records Streamtime shows you. No DNS credentials are stored.

See [Domains & Certificates]({{ site.baseurl }}/configuration/domains-certificates/).

## What you can bring

Every dependency has a default, so a trial needs none of these. Each can
be swapped for what your organization already runs; each has its own page
under [Bring your own]({{ site.baseurl }}/bring-your-own/).

| | Default | Bring your own |
|---|---|---|
| [Infrastructure]({{ site.baseurl }}/bring-your-own/infrastructure/) | A Kubernetes cluster Streamtime creates in your cloud account | Your own Kubernetes cluster, or your own virtual machines |
| [Sign-in]({{ site.baseurl }}/configuration/identity-providers/) | **Streamtime identity** (non-production only) | Any OIDC identity provider |
| [Private connection]({{ site.baseurl }}/bring-your-own/connectivity/) | — | Tailscale, another tunnel, or your own network |
| [Gateway certificate]({{ site.baseurl }}/bring-your-own/gateway-certificate/) | Generated from the Streamtime CA | Your own certificate |
| [DNS and fleet certificates]({{ site.baseurl }}/configuration/domains-certificates/) | **Streamtime Managed** | Your DNS zone (AWS Route53, Cloudflare, GoDaddy), or records you manage |
| [Secrets]({{ site.baseurl }}/bring-your-own/secrets/) | Built-in secret store | HashiCorp Vault |
| [Container images]({{ site.baseurl }}/bring-your-own/container-registry/) | Public registries, cached inside each fleet | A private mirror registry |
| [Packages]({{ site.baseurl }}/bring-your-own/packages/) | Streamtime's package catalog | Your own Helm repositories and packages |
| [Observability]({{ site.baseurl }}/operations/alerts-diagnostics/byo-observability/) | Streamtime's own dashboards, metrics and logs | A copy to Datadog, Grafana Cloud or New Relic |
| [Alert destinations]({{ site.baseurl }}/bring-your-own/alert-channels/) | Alerts in the console | Slack, PagerDuty or a webhook |
| [Email]({{ site.baseurl }}/bring-your-own/email/) | — | Your SMTP server |
| [AI models]({{ site.baseurl }}/bring-your-own/ai-models/) | — | OpenAI, Anthropic, Google, Groq, or a model you host |
| [Durable Executor]({{ site.baseurl }}/bring-your-own/durable-executor/) | Built in | **Streamtime Managed**, or a Temporal service you run |

## Where to read on

- [Kubernetes Fleet]({{ site.baseurl }}/about/kubernetes-fleet/),
  [Workload types]({{ site.baseurl }}/about/kafka-cluster/),
  [Tenancy]({{ site.baseurl }}/about/tenancy/) and
  [Capacity units]({{ site.baseurl }}/about/scaling/) —
  fleets, workloads, tenancy and scaling as a user faces them.
- [Configuration]({{ site.baseurl }}/getting-started/configuration/) — the accounts, domains and
  identity providers the control plane plugs into.
- [Operations]({{ site.baseurl }}/operations/) — upgrades, monitoring
  and troubleshooting of a running installation.
