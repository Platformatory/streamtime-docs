---
title: "Redpanda (Preview)"
parent: Streaming
ancestor: Workloads
nav_order: 4
---

# Redpanda (Preview)

Redpanda is a modern, high-performance streaming platform that is Kafka API-compatible but does not require the JVM. Streamtime enables you to deploy and manage Redpanda clusters on your Kubernetes fleets.

---

## When to Use Redpanda

- **Low-Latency Workloads**: Ideal for applications that require ultra-fast message processing.
- **JVM-Free Environments**: When you want to avoid Java dependencies and reduce resource overhead.
- **Kafka Compatibility**: If you need Kafka API compatibility but want a simpler operational model.
- **Cloud-Native Deployments**: Optimized for Kubernetes and containerized environments.

---

## Key Features

- **Kafka API-Compatible**: Works with existing Kafka clients and tools.
- **No JVM Required**: Written in C++, offering lower latency and reduced resource usage.
- **High Throughput**: Designed for performance-critical streaming workloads.
- **Simplified Operations**: Easier upgrades and scaling compared to traditional Kafka.
- **Cloud-Native**: Built for Kubernetes with native support for container orchestration.

---

## Manage a Redpanda cluster

From the API, CLI or MCP, a Redpanda cluster also needs its license and
tiered storage in `advanced_config`. `aws_account` is the identifier of the
AWS cloud account registered in your organization's settings:

```json
"advanced_config": {
  "license": "<redpanda-license>",
  "tiered_storage_bucket_name": "<bucket>",
  "tiered_storage_provider": {
    "aws_account": "<cloud-account>",
    "aws_region": "us-east-1"
  }
}
```

{% include kafka-cluster-tasks.md workload="redpanda" name="Redpanda" id="redpanda" cluster="telemetry" shots="redpanda" %}
