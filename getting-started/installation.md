---
title: Installation
nav_order: 1
parent: Getting Started
permalink: /getting-started/installation/
---

Three ways to run the Streamtime control plane, by environment:

| Deployment | For | You need |
|---|---|---|
| **Single image (Docker)** | Try it out on one machine; embedded single-node pilots | Docker |
| **Kubernetes (Helm chart)** | Production private clouds | a Kubernetes cluster, Helm 3 |
| **Docker Compose (from source)** | Contributing and development | a checkout of `streamtime-ai/fleet-manager` |

## Single image (Docker)

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
Add `-v streamtime-data:/data` to keep data across container restarts.

Where it listens:

| Port | What |
|---|---|
| **8443** | The console **and** the API (HTTPS) — browse https://localhost:8443 |
| 3000 | Console UI directly (plain HTTP; use 8443 instead) |
| 7999 | Backend API without the gateway (diagnostics) |

## Kubernetes (Helm)

```bash
helm upgrade --install streamtime oci://ghcr.io/streamtime-ai/fleet-manager \
  --namespace streamtime --create-namespace \
  --set fleetmanager.adminEmail=you@example.com
```

The console and API are exposed through the cluster's LoadBalancer
service; point a DNS record for your base domain at it and open the
console. Add `--set fleetmanager.superUserEmails=you@example.com` for a
super user that spans organizations.

For a highly available install (HA Postgres via CloudNativePG,
cert-manager issuer) use the `streamtime-ha` chart: one
`helm upgrade --install` creates everything, with the domain, admin
email, license and registry credentials in a values file.

## From source (Docker Compose)

```bash
git clone https://github.com/streamtime-ai/fleet-manager.git
cd fleet-manager
docker compose up -d
```

## Sign in

Open **https://localhost:8443** (or your deployment's address) and sign
in. Enter `root` as the organization: `root` is the special
organization whose super user can create other organizations and has
complete administrator privileges. Super users are the email addresses
listed in `SUPER_USER_EMAILS` (single image and Compose) or
`fleetmanager.superUserEmails` (Helm). See
[User Management](/getting-started/user-management/).

To sign in from the terminal instead:

```bash
pip install streamtime-cli
streamtime login --org root --streamtime-url https://localhost:8443
streamtime fleet list
```

`login` opens the browser for the org's identity provider; add
`--grant password` for headless use.
