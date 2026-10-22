---
title: About Streamtime
nav_order: 1
has_children: true
permalink: /
has_toc: false
---

Streamtime is a private cloud for streaming workloads: you bring
infrastructure (a Kubernetes cluster or a cloud account), Streamtime
deploys and operates Kafka and other streaming platforms on it, and you
drive everything from the console, the REST API, the SDKs, the CLI or
MCP.

Under the hood, a single control plane (gateway, backend, orchestrator)
records what you want running and drives it into existence; one agent
per fleet carries out the work inside your clusters, over an inbound
connection — fleets never dial out.

- [Architecture](/about/architecture/) — how the pieces fit, in diagrams.
- [Deployment Topologies](/about/deployment-topologies/) — single image,
  Docker Compose, Helm, and what each is for.

## Where to go next

| You want to… | Go to |
|---|---|
| Install Streamtime and log in for the first time | [Getting Started](/getting-started/) |
| Set up domains, certificates, identity providers and cloud accounts | [Configuration](/getting-started/configuration/) |
| Bootstrap a fleet (your own Kubernetes, AWS, Azure, GCP, Oracle) | [Fleet Management](/fleet-management/) |
| Deploy and operate workloads (Apache Kafka, Confluent, WarpStream, …) | [Workloads](/workloads/) |
| Schedule operations, set up alerts, diagnose problems | [Operations](/operations/) |

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
