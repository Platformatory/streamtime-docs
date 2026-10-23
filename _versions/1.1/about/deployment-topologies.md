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

Everything in one container: console, API, gateway, orchestrator, an
embedded database and an embedded workflow engine. For single-user
trials, evaluations and embedded single-node pilots. No external
dependencies; data lives on one volume.

## Kubernetes (Helm chart)

The production shape. Each component runs as its own workload, the
database is PostgreSQL, and the workflow engine is a managed Temporal:

- **Gateway (Kong)** — the single ingress.
- **Backend + MCP** — the API and the MCP server (mounted in-process).
- **Frontend** — the console.
- **Orchestrator** — the Temporal worker that drives provisioning.
- Optional HA profile (the `streamtime-ha` chart): HA Postgres via
  CloudNativePG and a cert-manager issuer, created by the same install
  command.

## Docker Compose (from source)

The development topology: the same services as separate containers
against a real PostgreSQL and an external Temporal, plus the
developer's local registry and tunnels. For people working on
Streamtime itself.

## What does not change

| | Single image | Helm | Compose |
|---|---|---|---|
| Console, API, CLI, MCP, SDKs | identical | identical | identical |
| Database | embedded (SQLite) | PostgreSQL | PostgreSQL |
| Workflow engine | embedded | Temporal (managed) | Temporal (external) |
| Scale | one node | your cluster | one host |

Workloads (Kafka and the rest) always run in your **fleets** — separate
clusters from the control plane — whichever topology you installed.

Install instructions for each shape:
[Installation](/getting-started/installation/).
