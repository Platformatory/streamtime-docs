---
title: "Deployment Topologies"
permalink: "/1.1/about/deployment-topologies/"
nav_exclude: true
search_exclude: true
version_snapshot: "1.1"
---

The same Streamtime ships in three shapes. Pick by environment; the
product you use afterwards is identical.

## Single image (Docker)

Everything in one container: console, API, gateway, operations engine
and an embedded database. For single-user trials, evaluations and
embedded single-node pilots. No external dependencies; data lives on one
volume.

## Kubernetes (Helm chart)

The production shape. Each part of the control plane runs as its own
workload:

- **Gateway** — the single entry point.
- **API service** — the REST API and the MCP server.
- **Console** — the web UI.
- **Operations engine** — runs provisioning and lifecycle operations.
- Optional HA profile (the `streamtime-ha` chart): installs the control
  plane together with its backing services, a highly available
  PostgreSQL database and a cert-manager issuer, in one install command.

## Docker Compose (from source)

The development topology: the same parts as separate containers, plus
the developer's local registry and tunnels. For people working on
Streamtime itself.

## What does not change

| | Single image | Helm | Compose |
|---|---|---|---|
| Console, API, CLI, MCP, SDKs | identical | identical | identical |
| Database | embedded | PostgreSQL | PostgreSQL |
| Scale | one node | your cluster | one host |

Workloads (Kafka and the rest) always run in your **fleets** — separate
clusters from the control plane — whichever topology you installed.

Install instructions for each shape:
[Installation]({{ site.baseurl }}/getting-started/installation/).
