---
title: Alert rules
parent: Alerts & Diagnostics
nav_order: 1
permalink: /operations/alerts-diagnostics/alert-rules/
---

# Alert rules

Alerts come from **alert rules**: a query over the metrics Streamtime
collects, and how long it must hold before the alert fires. Every fleet
and every workload gets a set of built-in rules, and you can change them
or add your own.

| Rules for | Built-in rules cover | Where in the console |
|---|---|---|
| A **fleet** | Kubernetes and the fleet's shared services: nodes, pods, storage, monitoring | The fleet's **Monitoring** cards → **Alert Rules** |
| A **Kafka cluster** (Apache Kafka, Confluent, WarpStream) | Brokers and partitions: free disk space, under-replicated and offline partitions, controller state, and more | The cluster's **Monitoring** cards → **Alert Rules** |
| A **ClickHouse** cluster | Instances down, disk space, replication lag, and more | The cluster's **Monitoring** cards → **Alert Rules** |
| A **Flink** deployment (Apache Flink) | Jobs restarting, failing or slow checkpoints, no free task slots, memory pressure | The API only, for now |

An alert that fires shows in the console and goes to the fleet's
[alert channels]({{ site.baseurl }}/bring-your-own/alert-channels/). With
[email]({{ site.baseurl }}/bring-your-own/email/) set up, the person who
created the resource is emailed too.

## A rule

| Field | What it is |
|---|---|
| **Alert name** | Starts with a letter; letters, digits and underscores only. Unique within the resource's rules |
| **Rule group** | Rules are grouped; a new rule goes in the resource's default group |
| **PromQL expression** | The condition. The alert fires for every series the query returns |
| **For duration** | How long the condition must hold first, for example `5m` |
| **Severity** | `critical` or `warning` by convention; your alert channels can route on it |
| **Enabled** | Turn a rule off without deleting it |

Rules marked **Default** are built in; rules you add are **Custom**. You
can edit or turn off a built-in rule. **Reset defaults** puts the
built-in rules back as Streamtime ships them, and leaves your custom rules
alone.

## Sync

Rules are saved in Streamtime and synced to the cluster that evaluates
them. Changes sync automatically. The panel shows **Syncing to cluster**
while that runs, **Sync required** when the cluster's rules differ from
what is saved, and **Apply failed** with the reason when the cluster
refused them. **Sync to cluster** syncs again.

{% include api-setup.md id="alert-rules" %}

## Add a rule

Paths below are for a fleet. For a Kafka cluster use
`/kafka/<cluster>/alert-rules/`, for ClickHouse
`/clickhouses/<cluster>/alert-rules/`, and for Flink
`/flink/<deployment>/alert-rules/`.

{% capture ui %}
1. Open the fleet or cluster, go to its **Monitoring** cards and choose
   **Alert Rules**.
2. Select **Add rule**.
3. Enter **Alert name**, **PromQL expression**, **For duration** and
   **Severity**; keep or change the **Rule group**; leave **Enabled** on.
4. Save. The rule appears as **Custom** and syncs to the cluster.
{% endcapture %}

{% capture curl %}
```bash
# Check it first: the expression must parse.
curl -X POST "$API/fleet/<fleet>/alert-rules/validate/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"alertname": "NodeDiskAlmostFull", "rule_group": "custom.rules",
       "expr": "node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.1",
       "for_duration": "10m", "labels": {"severity": "warning"},
       "annotations": {"summary": "A node disk is almost full"}}'

# Add it.
curl -X POST "$API/fleet/<fleet>/alert-rules/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"alertname": "NodeDiskAlmostFull", "rule_group": "custom.rules",
       "expr": "node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.1",
       "for_duration": "10m", "labels": {"severity": "warning"},
       "annotations": {"summary": "A node disk is almost full"}}'
```

Other requests on the same path:

| Request | Does |
|---|---|
| `GET …/alert-rules/` | The rules and the sync state (`apply_status`, `last_apply_error`) |
| `PATCH …/alert-rules/<alertname>/` | Change a rule, for example `{"enabled": false}` |
| `DELETE …/alert-rules/<alertname>/` | Remove a custom rule |
| `POST …/alert-rules/reset-defaults/` | Put the built-in rules back |
| `POST …/alert-rules/apply/` | Sync to the cluster now |
| `GET …/alert-rules/status/` | Whether a sync is pending, and its message |
{% endcapture %}
{% capture python %}
The generated SDK doesn't describe these request bodies yet, so send them
with the SDK's HTTP client:

```python
rule = {
    "alertname": "NodeDiskAlmostFull",
    "rule_group": "custom.rules",
    "expr": "node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.1",
    "for_duration": "10m",
    "labels": {"severity": "warning"},
}
http = client.get_httpx_client()
http.post(f"/organizations/{ORG}/fleet/<fleet>/alert-rules/validate/", json=rule).raise_for_status()
http.post(f"/organizations/{ORG}/fleet/<fleet>/alert-rules/", json=rule).raise_for_status()
```
{% endcapture %}
{% capture typescript %}
The generated client doesn't describe these request bodies yet, so send
them with `fetch`:

```typescript
const rule = {
  alertname: "NodeDiskAlmostFull",
  rule_group: "custom.rules",
  expr: "node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.1",
  for_duration: "10m",
  labels: { severity: "warning" },
};
await fetch(`https://api.example.com/organizations/${org}/fleet/<fleet>/alert-rules/`, {
  method: "POST",
  headers: {
    Authorization: `Bearer ${process.env.STREAMTIME_TOKEN}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify(rule),
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/fleet/<fleet>/alert-rules/", map[string]any{
    "alertname":    "NodeDiskAlmostFull",
    "rule_group":   "custom.rules",
    "expr":         "node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.1",
    "for_duration": "10m",
    "labels":       map[string]string{"severity": "warning"},
})
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="alert-rule-add-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet. Use the console or the API.
{% endcapture %}

{% capture mcp %}
Changing rules isn't available in MCP. MCP reads what they produce:
*"Which alerts are firing on the orders cluster, and since when?"*
{% endcapture %}

{% include tabs.html id="alert-rule-add" ui=ui api=api cli=cli mcp=mcp %}

## Turn a built-in rule off

{% capture ui %}
On **Alert Rules**, switch off **Enabled** for the rule. It stays in the
list, marked **Default**, and **Reset defaults** turns it back on.
{% endcapture %}
{% capture curl %}
```bash
curl -X PATCH "$API/kafka/<cluster>/alert-rules/UnderReplicatedPartitions/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"enabled": false}'
```
{% endcapture %}
{% capture python %}
```python
client.get_httpx_client().patch(
    f"/organizations/{ORG}/kafka/<cluster>/alert-rules/UnderReplicatedPartitions/",
    json={"enabled": False},
).raise_for_status()
```
{% endcapture %}
{% capture typescript %}
```typescript
await fetch(
  `https://api.example.com/organizations/${org}/kafka/<cluster>/alert-rules/UnderReplicatedPartitions/`,
  {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${process.env.STREAMTIME_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ enabled: false }),
  },
);
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("PATCH", "/kafka/<cluster>/alert-rules/UnderReplicatedPartitions/",
    map[string]any{"enabled": false})
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="alert-rule-off-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}
{% capture cli %}
Not available in the CLI yet.
{% endcapture %}
{% capture mcp %}
Not available in MCP.
{% endcapture %}
{% include tabs.html id="alert-rule-off" ui=ui api=api cli=cli mcp=mcp %}
