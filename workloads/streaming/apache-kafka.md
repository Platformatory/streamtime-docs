---
title: Apache Kafka
parent: Streaming
ancestor: Workloads
nav_order: 1
---

# Apache Kafka

Apache Kafka is a popular open-source distributed event streaming platform. Streamtime enables you to deploy and manage Apache Kafka clusters on your Kubernetes fleets with full automation and observability.

---

## When to Use Apache Kafka

- **Open Source Requirements**: When you need a fully open-source Kafka distribution without vendor lock-in.
- **Custom Integrations**: If you require advanced customization or integration with existing open-source tools.
- **Benchmarking & Testing**: For proof-of-concept, benchmarking, or development environments.
- **Cost Control**: When you want to avoid commercial licensing costs and manage your own scaling and upgrades.

---

## Manage an Apache Kafka cluster

From the API, CLI or MCP, set how clients authenticate in `advanced_config`.
With SASL/OAUTH, the default, add your OAuth provider to the create request:

```json
"advanced_config": {
  "oauth": {
    "clientId": "<client-id>",
    "clientSecret": "<client-secret>",
    "issuer": "https://idp.example.com",
    "jwksEndpoint": "https://idp.example.com/jwks",
    "authorizationUri": "https://idp.example.com/authorize",
    "tokenUri": "https://idp.example.com/token"
  }
}
```

Or use usernames and passwords instead:

```json
"advanced_config": { "authentication_mechanism": "SASL/SCRAM" }
```

{% include kafka-cluster-tasks.md workload="strimzi" name="Apache Kafka" id="strimzi" cluster="orders" shots="apache-kafka" %}
