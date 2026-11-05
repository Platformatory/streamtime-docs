---
title: Capacity units
nav_order: 8
parent: About Streamtime
permalink: /about/scaling/
---

# Capacity units

Each kind of workload is sized in its own unit, so you ask for capacity in
terms of the workload instead of in CPUs and memory:

| Workload | Unit | What one unit is | You set it as |
|---|---|---|---|
| Streaming (Kafka) | **Kafka Unit** | 5 MB/s of produce traffic in and 15 MB/s of consume traffic out | **Kafka Units** on the cluster |
| Stream Processing (Flink) | **Flink Unit** | One parallel task slot. A job needs as many Flink Units as its parallelism | **Max Flink Units** on a Job Workspace, or **Flink Units** on a single-job cluster or a job |
| Analytics (ClickHouse) | **ClickHouse unit** | A block of server capacity a cluster's servers take from the fleet | Worked out from the cluster's shards, replicas and server size |

A fleet tracks its capacity for each kind of workload in the same units.
A cluster can only be created where the fleet has enough free units for
it, and the fleet's **Workloads** card shows what is used and free.

{: .note }
The sizes below are the defaults. Your Streamtime administrator can change
them for your installation, and the fleet's **Workloads** card always
shows the size in use ("… vCPU, … GB each").

## Kafka Units

A Kafka Unit is throughput: **5 MB/s in and 15 MB/s out** (1 MB =
1,048,576 bytes). A cluster of 6 Kafka Units is sized for 30 MB/s of
produce and 90 MB/s of consume traffic. A virtual Kafka cluster claims
Kafka Units from the Kafka cluster behind it, and the claim is enforced on
its traffic.

Behind each Kafka Unit is a share of the fleet: 2 vCPU and 4 GB on a
Shared fleet, 1 vCPU and 4 GB on an Isolated or Dedicated fleet.

## Flink Units

A Flink Unit is one task slot: one parallel instance of a job. A job with
parallelism 4 needs 4 Flink Units.

- A **Job Workspace** (session cluster) has a pool of **Max Flink Units**,
  and each job you submit claims **Flink Units Required** from that pool.
- A **single-job cluster** gets its own **Flink Units**.

Streamtime puts up to 4 slots on each worker and adds workers to cover the
units. The cluster's coordinator is sized on its own and doesn't count
against the pool.

How much compute stands behind a Flink Unit depends on the cluster's
**Optimization Goal**, and its memory also on the **State Backend Tier**
(Confluent Flink):

| Optimization Goal | Per Flink Unit | Coordinator |
|---|---|---|
| Cost | 0.5 vCPU, 1 GB | 0.5 vCPU, 1 GB |
| Balanced | 1 vCPU, 2 GB | 1 vCPU, 2 GB |
| Performance | 2 vCPU, 4 GB | 2 vCPU, 4 GB |

| State Backend Tier | Memory per Flink Unit |
|---|---|
| Stateless (In-Memory) | × 1 |
| Light (Heap State) | × 1.5 |
| Heavy (RocksDB) | × 2 |

On the fleet, a cluster books its Flink Units at their real size plus its
coordinator, rounded up to whole fleet units of 1 vCPU and 2 GB. Eight
Flink Units on **Performance** therefore take more of the fleet than eight
on **Cost**.

## ClickHouse units

You size a ClickHouse cluster by its **shards**, **replicas** and the
resources of each server. A cluster runs shards × replicas servers.

The fleet counts that in ClickHouse units of **4 vCPU and 16 GB**. Each
server takes the larger of its CPU and memory share of a unit, and the
cluster's total is rounded up once. For example, 2 shards × 2 replicas at
1 vCPU and 2 GB each come to 4 × 0.25 = **1 ClickHouse unit**.

## Fleet capacity

A fleet can run Streaming, Stream Processing and Analytics workloads side
by side. Its capacity for each is worked out one of two ways:

- **Cloud fleets:** you give each kind of workload its own number of units
  when you create the fleet, and Streamtime sizes the nodes to fit them
  all.
- **Your own Kubernetes cluster:** Streamtime finds the cluster's CPU and
  memory, keeps a share for the system and the agent, and divides the rest
  between the workloads you enabled: equally by default, or by the weights
  you set. Each share is converted into that workload's units, limited by
  whichever of CPU or memory runs out first. A workload never gets less
  than it already uses.

The fleet's **Workloads** card explains the result in words, for example
*"Share 1 of 2: 14 vCPU, 56 GB → 7 Kafka units at 2 vCPU, 4 GB each
(limited by CPU)."*

{% include api-setup.md id="capacity" %}

## Check a fleet's capacity

{% capture ui %}
1. Open **Infrastructure** and select the fleet.
2. The **Workloads** card lists each kind of workload the fleet runs, its
   total, used and free units, and how the total was worked out.
{% endcapture %}

{% capture curl %}
```bash
curl "$API/fleet/<fleet>/capacity/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN"
```

For each kind of workload the response has `unit`, `total`, `booked`,
`free` and `footprint` (the CPU and memory of one unit), plus a
`derivation` saying how the totals were reached.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.fleet_workloads import get_fleet_capacity

capacity = get_fleet_capacity.sync(ORG, "<fleet>", client=client)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { getFleetCapacity } from "./client";

const { data: capacity } = await getFleetCapacity({
  path: { org_identifier: org, fleet_id: "<fleet>" },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("GET", "/fleet/<fleet>/capacity/", nil)
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="capacity-check-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet. Set a cloud fleet's capacity when you
create it:

```bash
streamtime fleet create --identifier <fleet> --provider aws --domain <domain> \
  --streaming strimzi --streaming-units 12 \
  --stream-processing open-source --stream-processing-units 8 \
  --analytics clickhouse --analytics-units 2
```
{% endcapture %}

{% capture mcp %}
Not available in MCP yet.
{% endcapture %}

{% include tabs.html id="capacity-check" ui=ui api=api cli=cli mcp=mcp %}

## Where to read on

- [Tenancy]({{ site.baseurl }}/about/tenancy/): Shared, Isolated and
  Dedicated fleets.
- [Apache Kafka]({{ site.baseurl }}/workloads/streaming/apache-kafka/),
  [Flink]({{ site.baseurl }}/workloads/stream-processing/flink/) and
  [ClickHouse]({{ site.baseurl }}/workloads/analytics/clickhouse/): sizing
  each cluster.
