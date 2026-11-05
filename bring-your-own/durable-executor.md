---
title: Durable Executor
parent: Bring your own
nav_order: 13
permalink: /bring-your-own/durable-executor/
---

# Durable Executor

The **Streamtime Durable Executor** runs every operation (creating,
updating and deleting fleets and workloads) to completion, retrying
through failures and restarts, and hands in-cluster work to each fleet's
agent. You choose where it runs once, in first-time setup:

| Choice | Where it runs | What fleets need |
|---|---|---|
| **Built-in Orchestrator** (recommended) | Inside your Streamtime installation | A route to Streamtime: the [private connection]({{ site.baseurl }}/bring-your-own/connectivity/) |
| **Streamtime Managed** (needs a license) | Streamtime provisions a dedicated namespace and credentials for you | No route to your installation: fleets connect to the managed endpoint directly |
| **Custom Orchestrator** (advanced) | A Temporal service you run, self-hosted or Temporal Cloud | A route to your service. Suited to air-gapped or regulated environments, or where you already operate Temporal |

{: .note }
The console still labels the Durable Executor **Orchestrator**: the setup
step, its options and its fields. The steps below quote those labels as
shown.

{: .warning }
A custom Durable Executor must be reachable from Streamtime and from every
fleet at all times. When it isn't, no fleet operation can run.

## Before you start: custom

- The **Orchestrator Endpoint** of your Temporal service, as
  `host:port` (for example `temporal.example.com:7233`).
- An **API Key**, if the endpoint requires one (for example Temporal
  Cloud).

## Choose where it runs

{% capture ui %}
1. In first-time setup, at the **Orchestrator** step, choose
   **Built-in Orchestrator**, **Streamtime Managed** or **Custom Orchestrator**.
2. **Built-in:** check **Gateway Address** (the host and port fleets'
   agents use to reach Streamtime's gateway) and **Advertised Hostname**.
   Leave **Orchestrator Server** and **Orchestrator Namespace** at
   their defaults unless your installation differs.
   **Streamtime Managed:** Streamtime provisions the namespace; this can
   take up to a minute, and the step shows the namespace and endpoint when
   it is done.
   **Custom:** enter **Orchestrator Endpoint** and, if needed,
   **API Key (optional)**, and check the connection.
3. Continue.
{% endcapture %}
{% capture api %}
Chosen during first-time setup only; there is no published API for it
yet.
{% endcapture %}
{% capture cli %}
Not available in the CLI.
{% endcapture %}
{% capture mcp %}
Not available in MCP.
{% endcapture %}
{% include tabs.html id="durable-executor-set" ui=ui api=api cli=cli mcp=mcp %}
