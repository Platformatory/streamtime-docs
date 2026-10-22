---
title: Get Started
nav_order: 1
layout: home
---

Streamtime is a private cloud for streaming workloads: you bring
infrastructure (a Kubernetes cluster or a cloud account), Streamtime
deploys and operates Kafka and other streaming platforms on it, and you
drive everything from the console, the REST API, the SDKs, the CLI or
MCP.

## Install Streamtime

Three ways to run the Streamtime control plane, by environment:

| Deployment | For | You need |
|---|---|---|
| **Single image (Docker)** | Try it out on one machine; embedded single-node pilots | Docker |
| **Kubernetes (Helm chart)** | Production private clouds | a Kubernetes cluster, Helm 3 |
| **Docker Compose (from source)** | Contributing and development | a checkout of `streamtime-ai/fleet-manager` |

### Single image (Docker)

The single image contains everything — the API, console, gateway,
orchestrator and an embedded database and workflow engine. No external
dependencies.

Interactively (the default is fine for a trial):

```bash
docker run -d --name streamtime --privileged \
  -p 3000:3000 -p 8443:8443 -p 7999:7999 \
  ghcr.io/streamtime-ai/streamtime:latest
```

Headless / unattended (CI, a VM you only SSH into):

```bash
docker run -d --name streamtime --privileged \
  -p 3000:3000 -p 8443:8443 -p 7999:7999 \
  -e SUPER_USER_EMAILS=you@example.com \
  ghcr.io/streamtime-ai/streamtime:latest
```

Pin a version (`ghcr.io/streamtime-ai/streamtime:1.1`) instead of
`latest` for anything you keep running. The image is amd64 and arm64.
`--privileged` is required: the image runs a full service stack.

Where it listens:

| Port | What |
|---|---|
| **8443** | The console **and** the API (HTTPS) — browse https://localhost:8443 |
| 3000 | Console UI directly (plain HTTP; use 8443 instead) |
| 7999 | Backend API without the gateway (diagnostics) |

Data persists in the `streamtime-data` behaviour of the bundled compose
file; with a bare `docker run`, add `-v streamtime-data:/data` to keep it
across container restarts.

### Kubernetes (Helm)

```bash
helm upgrade --install streamtime oci://ghcr.io/streamtime-ai/fleet-manager \
  --namespace streamtime --create-namespace \
  --set fleetmanager.adminEmail=you@example.com
```

The console and API are exposed through the cluster's LoadBalancer
service; point a DNS record for your base domain at it and open the
console. Add `--set fleetmanager.superUserEmails=you@example.com` for a
super user that spans organizations.

For a highly available install (HA Postgres via CloudNativePG, cert-manager
issuer) use the `streamtime-ha` chart: one `helm upgrade --install`
creates everything, with the domain, admin email, license and registry
credentials in a values file.

### From source (Docker Compose)

```bash
git clone https://github.com/streamtime-ai/fleet-manager.git
cd fleet-manager
docker compose up -d
```

## First steps

1. Open **https://localhost:8443** (or your deployment's address) and
   sign in.
2. Enter `root` as the organization. `root` is the special organization:
   its super user can create other organizations and has complete
   administrator privileges. Super users are the email addresses listed
   in `SUPER_USER_EMAILS` (single image and Compose) or
   `fleetmanager.superUserEmails` (Helm).
3. **Create a fleet** — a fleet is the Kubernetes cluster (or cloud
   account) Streamtime runs workloads on. The fastest first fleet is
   BYOK, using a cluster you already have:
   [Bootstrapping Your Fleet](/bootstrapping-fleet/).
4. **Deploy your first workload** — typically a Kafka cluster — on that
   fleet: [Setup Kafka](/setup-kafka/).
5. Once it is running, watch it: [Monitoring](/operations/monitoring.html)
   and, when something looks wrong, [Troubleshooting](/operations/troubleshooting.html).

To drive Streamtime from the terminal instead of the console:

```bash
pip install streamtime-cli
streamtime login --org root --streamtime-url https://localhost:8443
streamtime fleet list
```

`login` opens the browser for the org's identity provider; add
`--grant password` for headless use.

## Where to go next

| You want to… | Go to |
|---|---|
| Understand how Streamtime is built (gateway, control plane, orchestrator, agents) | [Architecture](/architecture/) |
| Register cloud accounts and set up domains, certificates and identity providers | [Setup](/setup/) |
| Understand fleets, workloads, tenancy and scaling | [Concepts & Architecture](/concept-architecture/) |
| Bootstrap a fleet per cloud (AWS, Oracle, GCP, Azure, BYOK) | [Bootstrapping Your Fleet](/bootstrapping-fleet/) |
| Deploy and operate Kafka platforms (Apache Kafka, Confluent, WarpStream, Redpanda, AutoMQ) | [Setup Kafka](/setup-kafka/) |
| Upgrade, monitor and troubleshoot what you run | [Operations](/operations/) |
| Script or automate Streamtime (REST API, Python / TypeScript SDKs, CLI, MCP) | [API Reference](/api/) |

## The four ways to do anything

Every task in these pages is shown four ways, in tabs:

- **UI** — the console screens, step by step.
- **API** — the REST call, with **HTTP** (curl), **Python**,
  **TypeScript** and **Go** variants.
- **CLI** — the `streamtime` command.
- **MCP** — the MCP tool and an example prompt, for tasks the MCP
  server supports.

Where an interface can't do a task yet, the page says so instead of
hiding the tab.
