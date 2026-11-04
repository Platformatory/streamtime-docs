---
title: "Architecture"
permalink: "/1.1/about/architecture/"
nav_exclude: true
search_exclude: true
version_snapshot: "1.1"
---

# Architecture

Streamtime is a management plane for streaming workloads. One **control
plane** records what you want running and drives it into existence;
one **agent per fleet** carries out the work inside your clusters.
This page describes the parts you interact with, how they connect, and
what you can bring of your own.

## The big picture

![Your console and API clients reach the control plane through one gateway; the operations engine sends work to the agent in your fleet over a private connection, and the agent runs your workloads.]({{ '/assets/images/architecture/overview.svg' | relative_url }})

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
- **Operations engine** — runs each Create, Update and Delete operation
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

Every dependency has a default, so a trial needs none of these. Each
can be swapped for what your organization already runs. Most are set
during first-time setup and can be changed later in **Settings**.

| | Default | Bring your own |
|---|---|---|
| [Infrastructure](#infrastructure) | A Kubernetes cluster Streamtime provisions in your cloud account | Your own Kubernetes cluster, or your own virtual machines |
| [Sign-in](#sign-in) | **Streamtime identity**, built in | Any OIDC identity provider |
| [Private connection](#private-connection) | — | Tailscale, another tunnel, or your own network |
| [Gateway certificate](#gateway-certificate) | Generated from the Streamtime CA | Your own certificate |
| [DNS and fleet certificates](#dns-and-fleet-certificates) | **Streamtime Managed** | Your DNS zone, or records you manage |
| [Secrets](#secrets) | Built-in vault | HashiCorp Vault |
| [Container images](#container-images) | Public registries, cached inside each fleet | A private mirror registry |
| [Observability](#observability) | Streamtime's own dashboards, metrics and logs | A copy to Datadog, Grafana Cloud or New Relic |
| [Alert destinations](#alert-destinations) | Alerts in the console | Slack, PagerDuty or a webhook |
| [Email](#email) | — | Your SMTP server |
| [Operations engine](#operations-engine) | Built in | **Streamtime Managed**, or an endpoint you run |

### Infrastructure

Where your workloads run. Each fleet picks one:

- **A cloud account.** Streamtime creates and later deletes the
  Kubernetes cluster in your AWS, Azure, GCP, Oracle, Civo or
  DigitalOcean account, and records every resource it creates. Register
  the account under **Settings → Bootstrap Providers** (first-time setup:
  **Cloud Accounts**).
- **Your own Kubernetes cluster (BYOK).** On-premises, bare metal or any
  cloud. The cluster needs a load-balancer provider and a default storage
  class. Streamtime installs its agent with a kubeconfig you give it, or
  you run the install commands yourself; no cloud account is needed.
  Streamtime installs only what the fleet's workloads need and removes it
  again when you delete the fleet; your cluster's own networking, storage
  and load balancer are left alone.
- **Your own virtual machines (BYOVM).** Linux machines in any cloud or
  data center, reached over SSH with one key, for Confluent Platform on
  VMs.

See [Fleet Management]({{ site.baseurl }}/fleet-management/),
[Bring your own Kubernetes]({{ site.baseurl }}/fleet-management/byok/)
and [Bring your own VMs]({{ site.baseurl }}/fleet-management/byovm/).

### Sign-in

Out of the box, people sign in with **Streamtime identity**. Connect your
own identity provider (Okta, Microsoft Entra ID, Google, Auth0, Keycloak
or any other OIDC provider) under **Settings → Identity providers**
(first-time setup: **Sign-in**), one per organization. The gateway then
verifies every request against your provider's keys, so access is
granted and revoked where you already manage people.

Automation signs in with API keys or, with Streamtime identity, OAuth
clients (**Settings → OAuth Clients**).

See [Identity Providers]({{ site.baseurl }}/configuration/identity-providers/).

### Private connection

How fleets and Streamtime reach each other: Tailscale, another tunnel,
or your own network (public DNS and a load balancer, a VPN or peering).
Set in **Settings → Connectivity**; see [Connectivity](#connectivity)
above. Only Streamtime's own traffic uses it; Kafka traffic never does.

### Gateway certificate

The certificate on the console and API. Generated from your
installation's Streamtime CA by default, or your own, set in
**Settings → Connectivity**. See
[Certificates and trust](#certificates-and-trust) above.

### DNS and fleet certificates

The names and certificate your Kafka endpoints use. **Streamtime
Managed** by default; bring your own DNS zone (**Bring Your Own Zone**,
Route 53 or Cloudflare) or manage the records and certificate yourself
(**Customer Managed**) in **Settings → DNS & Certificates**. See
[Certificates and trust](#certificates-and-trust) above and
[Domains & Certificates]({{ site.baseurl }}/configuration/domains-certificates/).

### Secrets

Credentials Streamtime holds for you (cloud account keys, kubeconfigs,
SSH keys, DNS and observability credentials, Kafka passwords) are kept
in a secret store, never in plain configuration.

- **Built-in vault (default).** Nothing to set up.
- **HashiCorp Vault (AppRole sign-in).** Keep the secrets in your own
  Vault. In first-time setup (**Secrets Vault**) enter the **Vault URL**,
  the **Namespace** for Vault Enterprise, and the AppRole **Role ID** and
  **Secret ID** from your Vault administrator. **Auth Mount Path** and
  **Secrets Mount Path** (a KV version 2 engine) default to Vault's
  usual paths. The Streamtime server must be able to reach your Vault.

**Settings → Secrets Management** lists the secrets Streamtime holds, and
lets you add your own and choose which store each one goes to.

### Container images

Every fleet pulls the images of the services Streamtime installs and of
your workloads. By default they come from public registries, and each
fleet keeps a local cache so a node pulls an image from the internet
once.

- **A private mirror registry.** For air-gapped or controlled
  environments, Streamtime copies the images it needs into your registry
  and fleets pull from there. Set it in **Settings → Container
  Registry** (first-time setup: **Image Registries**): **Registry URL**,
  a username and token if the registry needs one, and a **Destination
  namespace** for registries such as GHCR that only accept pushes under
  an owned path. **Test Connection** checks it, and **Sync Now** copies the
  images.
- **Registry credentials.** Streamtime tracks new versions of the
  packages it installs, and needs read credentials for GitHub Container
  Registry and Quay.io to do so (Docker Hub is optional). The same
  credentials pull artefacts in private and air-gapped installations.

### Observability

Streamtime always collects metrics and logs for its own dashboards,
alerts and diagnostics. You can also send a copy of a fleet's metrics
and logs to **Datadog**, **Grafana Cloud** or **New Relic**: add the
provider and its ingest credential under **Settings → Observability
Providers**, then attach it to the fleet. Nothing moves; your provider
gets a copy, tagged with the fleet and organization.

See [Bring Your Own Observability]({{ site.baseurl }}/operations/alerts-diagnostics/byo-observability/).

### Alert destinations

Alerts show in the console. To reach people where they work, add a
destination under **Settings → Alert Channels**: **Slack** (a channel and
its incoming webhook URL), **PagerDuty**, or any **Webhook** that
accepts a JSON post.

### Email

With your own mail server, Streamtime sends notification emails to the
people who created a resource: when it becomes healthy or needs
attention, when an alert starts or clears, and a weekly performance
report per cluster. Set it under **Settings → SMTP Email** (first-time
setup: **SMTP Email**): **SMTP server**, **Connection security**
(STARTTLS, SSL/TLS or none) and **Port**, a username and password if
your server needs them, and the **From address**. Choose which emails go
out, and use **Send test email** before you save.

### Operations engine

The service that runs every operation to completion. Chosen once, in
first-time setup (the **Orchestrator** step):

- **Built-in** (recommended). Runs inside your Streamtime installation.
  Fleets reach it over the private connection.
- **Streamtime Managed** (needs a license). Streamtime runs it for you,
  and fleets connect to the managed endpoint directly, so they need no
  route to your installation.
- **Custom Orchestrator** (advanced). An endpoint you operate, for
  air-gapped or regulated environments, or where you already run this
  kind of service: enter its **Orchestrator Endpoint** and, if it needs
  one, an **API Key**.

## Where to read on

- [Kubernetes Fleet]({{ site.baseurl }}/about/kubernetes-fleet/),
  [Kafka Cluster]({{ site.baseurl }}/about/kafka-cluster/),
  [Tenancy]({{ site.baseurl }}/about/tenancy/) and
  [Scaling]({{ site.baseurl }}/about/scaling/) —
  fleets, workloads, tenancy and scaling as a user faces them.
- [Configuration]({{ site.baseurl }}/getting-started/configuration/) — the accounts, domains and
  identity providers the control plane plugs into.
- [Operations]({{ site.baseurl }}/operations/) — upgrades, monitoring
  and troubleshooting of a running installation.
