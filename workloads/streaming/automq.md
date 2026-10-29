---
title: "AutoMQ (Experimental)"
parent: Streaming
ancestor: Workloads
nav_order: 5
---

# AutoMQ (Experimental)

AutoMQ is a Kafka-compatible, cloud-native messaging platform designed for high scalability and operational simplicity. Streamtime enables you to deploy and manage AutoMQ clusters on your Kubernetes fleets.

---

## When to Use AutoMQ

- **Cloud-Native Messaging**: Ideal for teams seeking a modern, cloud-native Kafka alternative.
- **Auto-Scaling Needs**: When you require seamless, automatic scaling of your messaging workloads.
- **Built-in Observability**: If you want integrated monitoring and operational insights.
- **Internal Tenants**: Currently best suited for internal or experimental environments.

---

## Key Features

- **Kafka API-Compatible**: Works with existing Kafka clients and tools.
- **Auto-Scaling**: Automatically adjusts resources based on workload.
- **Cloud-Native Architecture**: Designed for Kubernetes and containerized deployments.
- **Built-in Observability**: Integrated hooks for monitoring and metrics.
- **Operational Simplicity**: Minimal manual intervention required.

---

## Manage an AutoMQ cluster

From the API, CLI or MCP, an AutoMQ cluster also needs these settings in
`advanced_config`. `oauth` is the identifier of an OAuth provider in your
organization's settings, and `aws_account` the identifier of an AWS cloud
account:

```json
"advanced_config": {
  "number_of_zones": "1",
  "cluster_access": "Internal",
  "oauth": "<oauth-provider>",
  "storage_bucket_name": "<bucket>",
  "storage_provider": {
    "aws_account": "<cloud-account>",
    "aws_region": "us-east-1"
  }
}
```

{% include kafka-cluster-tasks.md workload="automq" name="AutoMQ" id="automq" cluster="events" shots="automq" %}
