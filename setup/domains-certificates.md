---
title: "Domains & Certificates"
nav_order: 1
parent: Shared Cloud Accounts & Services

---


# Domains & Certificates

Streamtime uses your configured domain and TLS certificates to expose all Kubernetes and Kafka cluster workloads securely. Every service deployed—such as Kafka clusters, monitoring dashboards, logging endpoints, and schema registries—is made accessible through subdomains of your chosen domain, all protected by TLS encryption.

All endpoints for your Kafka clusters (bootstrap), Prometheus, Grafana, Loki logs, and (if enabled) Schema Registry are automatically provisioned under your domain. This ensures unified, secure access to every workload and management interface deployed by Streamtime.

## Why Domains & Certificates?
- **Unified Access**: All services are accessible under a single domain, simplifying management and access.
- **Security**: TLS certificates ensure encrypted communication for all endpoints, protecting sensitive data in transit.
- **Customizability**: You can upload your own TLS certificates or let Streamtime manage them for you, providing flexibility based on your security policies.
- **Automatic Provisioning**: Streamtime automatically provisions and manages the necessary DNS records and TLS certificates for all services, reducing operational overhead.

## How to Configure

1. **DNS Setup**: Point your DNS records to the Streamtime-managed ingress endpoints.
2. **TLS Certificates**: Upload your own certificates or let Streamtime generate and manage them for you.
3. **Validation**: Ensure all service URLs are reachable and secured with valid certificates.

![Domain & Certificates Configuration]({{ site.baseurl }}/assets/images/dns-certs.png)

See the platform UI or CLI for step-by-step instructions on configuring your domain and certificates.

---

# API Reference

## Create a Domain & Certificate with Route53

```bash
curl -X POST https://<streamtime-api-endpoint>/organizations/<your-org-id>/base-domains/ \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "organization": "<your-org-id>",
    "aws": "plf-route53",
    "domain": "fleet-manager.platformatory.io",
    "tls_cert": "your-certificate-content",
    "tls_key": "your-key-content",
    "dns_provider": "Route53",
    "dns_base_domain": "fleet-manager.platformatory.io"
  }'
```

**Response:**
```json
    {
        "id": "0efd7b28-a8b2-42d4-bce4-cedcefef5c53",
        "organization": "<your-org-id>",
        "aws": "plf-route53",
        "domain": "p6.fleet-manager.platformatory.io",
        "tls_cert": "your-certificate-content",
        "tls_key": "your-key-content",
        "dns_provider": "Route53",
        "dns_base_domain": "fleet-manager.platformatory.io",
        "created_at": "2025-07-15T07:01:16.637382Z",
        "updated_at": "2025-07-15T07:01:16.637396Z"
    }
```

## Create a Domain & Certificate 

```bash
curl -X POST https://<streamtime-api-endpoint>/organizations/<your-org-id>/base-domains/ \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "organization": "<your-org-id>",
    "domain": "fleet-manager.platformatory.io",
    "tls_cert": "your-certificate-content",
    "tls_key": "your-key-content",
    "dns_provider": "None"
  }
```

**Response:**
```json
    {
        "id": "0efd7b28-a8b2-42d4-bce4-cedcefef5c53",
        "organization": "<your-org-id>",
        "domain": "fleet-manager.platformatory.io",
        "tls_cert": "your-certificate-content",
        "tls_key": "your-key-content",
        "dns_provider": "None",
        "dns_base_domain": "fleet-manager.platformatory.io",
        "created_at": "2025-07-15T07:01:16.637382Z",
        "updated_at": "2025-07-15T07:01:16.637396Z"
    }
```



