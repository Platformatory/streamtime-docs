---
title: "Domains & Certificates"
nav_order: 2
parent: Get Started
---

# Domains & Certificates

Streamtime requires domain configuration for accessing workloads and endpoints.

## DNS Records

You need to set up the following records with your DNS provider:

- `*.stream.example.com` → External Load Balancer IP
- `api.stream.example.com` → Control plane API

## Certificates

You can use:

- **Let’s Encrypt (default)**
- **Bring your own certificate** (PEM format)

For production workloads, bring your own certs and rotate them using the control plane.
