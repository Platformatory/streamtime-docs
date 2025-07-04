---
title: "Domains & Certificates"
nav_order: 1
parent: Shared Cloud Accounts & Services

---


# Domains & Certificates

Streamtime uses your configured domain and TLS certificates to expose all Kubernetes and Kafka cluster workloads securely. Every service deployed—such as Kafka clusters, monitoring dashboards, logging endpoints, and schema registries—is made accessible through subdomains of your chosen domain, all protected by TLS encryption.

All endpoints for your Kafka clusters (bootstrap), Prometheus, Grafana, Loki logs, and (if enabled) Schema Registry are automatically provisioned under your domain. This ensures unified, secure access to every workload and management interface deployed by Streamtime.

## How to Configure

1. **DNS Setup**: Point your DNS records to the Streamtime-managed ingress endpoints.
2. **TLS Certificates**: Upload your own certificates or let Streamtime generate and manage them for you.
3. **Validation**: Ensure all service URLs are reachable and secured with valid certificates.

![Domain & Certificates Configuration]({{ site.baseurl }}/assets/images/dns-certs.png)

See the platform UI or CLI for step-by-step instructions on configuring your domain and certificates.

---

