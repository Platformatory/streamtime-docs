---
title: Alerts & Diagnostics
nav_order: 2
parent: Operations
has_children: true
permalink: /operations/alerts-diagnostics/
---

---
# Alerts & Diagnostics
Streamtime provides comprehensive monitoring for both Kubernetes infrastructure and Kafka clusters. All metrics are visualized through integrated dashboards for real-time observability and troubleshooting.
---
## Kubernetes Monitoring
- **Cluster Health**: Overall status of the Kubernetes fleet.
- **Node Metrics**: CPU, memory, and storage utilization for each node.
- **Metrics Dashboards**: Visualize resource usage and identify bottlenecks.
![Node Overview]({{site.baseurl}}/assets/images/monitoring/node-overview.png)
## Kafka Monitoring
  
---
- **Cluster Health**: Status and availability of Kafka clusters.
- **Kafka Operations Metrics**: Production and consumption rates, partition distribution, and replication status.
- **Metrics Dashboards**: Topic-level throughput, latency, and error rates.
### Platform-Specific Metrics
- **CFK (Confluent for Kubernetes)**
  - Topic-wise metrics
  - Schema Registry metrics
  - Confluent platform logs
- **Apache kafka**
  - KRaft (Kafka Raft) metrics
![cluster health]({{site.baseurl}}/assets/images/monitoring/cluster-health.png)
---
Use the Streamtime UI dashboards to monitor all aspects of your clusters and quickly respond to any issues.
---
## Sending telemetry to your own monitoring product
If your team already uses Datadog, Grafana Cloud, or New Relic, Streamtime can forward a copy of your fleet and Kafka metrics and logs there, so you can alert on Streamtime infrastructure alongside everything else you monitor.
See [Bring Your Own Observability](/operations/alerts-diagnostics/byo-observability/).

## Manage alert destinations with Terraform

{% capture alerts_ui %}
Manage alert destinations in the organization's alert channel settings.
{% endcapture %}
{% capture alerts_api %}
Create with `POST /organizations/<org>/alert-channels/`; read, update or
delete at `/organizations/<org>/alert-channels/<identifier>/`.
{% endcapture %}
{% capture alerts_terraform %}
```hcl
variable "slack_webhook_url" {
  type      = string
  sensitive = true
}

resource "streamtime_alert_channel" "operations" {
  identifier = "operations"
  type       = "slack"
  receiver_config = jsonencode({
    channel = "#operations"
    api_url = var.slack_webhook_url
  })
}
```

The provider fills `receiver_type` from `type` when it is omitted. Webhook
channels need `url`; PagerDuty channels need `routing_key`. Configuration
is sensitive and stored in Terraform state. Import with
`terraform import streamtime_alert_channel.operations operations`.
Changing the destination updates the channel in place; changing its
identifier replaces it. Destroy removes the channel from Streamtime.
{% endcapture %}
{% capture alerts_cli %}
Use `streamtime alert-channel --help` for alert channel commands.
{% endcapture %}
{% capture alerts_mcp %}
Consult the connected MCP server for alert reads; manage destinations
through the API, CLI or Terraform.
{% endcapture %}
{% include tabs.html id="manage-alert-destinations" ui=alerts_ui api=alerts_api cli=alerts_cli mcp=alerts_mcp terraform=alerts_terraform %}
