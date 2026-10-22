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

## Deploy Streamtime

Three ways to run the Streamtime control plane, by environment:

| Deployment | For | How |
|---|---|---|
| **Docker Compose** | Single-user trials and evaluations | The command below |
| **Kubernetes (Helm chart)** | Production private clouds | The Helm chart `charts/fleet-manager` (see your deployment guide) |
| **Single image** | Embedded single-node pilots | `oci://ghcr.io/platformatory/streamtime` |

To deploy with Docker Compose, run

```bash
STREAMTIME_SUPER_USER_EMAILS=<your-email> docker compose -f oci://ghcr.io/platformatory/streamtime up -d
```

> Replace `<your-email>` with your email.

## First steps

1. Open **http://localhost:3000** (or your deployment's address) and
   sign in.
2. Enter `root` as the organization. `root` is the special
   organization: its super user can create other organizations and has
   complete administrator privileges.
3. **Create a fleet** — a fleet is the Kubernetes cluster (or cloud
   account) Streamtime runs workloads on. The fastest first fleet is
   BYOK, using a cluster you already have:
   [Bootstrapping Your Fleet](/bootstrapping-fleet/).
4. **Deploy your first workload** — typically a Kafka cluster — on that
   fleet: [Setup Kafka](/setup-kafka/).
5. Once it is running, watch it: [Monitoring](/operations/monitoring.html)
   and, when something looks wrong, [Troubleshooting](/operations/troubleshooting.html).

### See it end to end

A guided walkthrough of a complete BYOK fleet with an Apache Kafka
cluster on it:

<video class="video-js vjs-theme-city" controls preload="auto" width="640" height="264" data-setup='{}'>
    <source src="{{ '/assets/videos/byok_apache-kafka.webm' | relative_url }}" type="video/webm">
  Your browser does not support the video tag.
</video>

<style>
    video {
        width: 100%;
        height: auto;
    }
</style>

<link
  href="https://unpkg.com/video.js@7/dist/video-js.min.css"
  rel="stylesheet"
/>
<link
  href="https://unpkg.com/@videojs/themes@1/dist/city/index.css"
  rel="stylesheet"
/>

<script src="https://vjs.zencdn.net/8.22.0/video.min.js"></script>

## Where to go next

| You want to… | Go to |
|---|---|
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
