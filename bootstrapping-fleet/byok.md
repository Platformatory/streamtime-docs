---
title: "Advanced Usage (BYOK)"
parent: Bootstrapping Your Fleet
nav_order: 5
---

# Advanced Usage Scenarios: BYOK

Bring Your Own Kubernetes lets you register and manage an existing cluster.

## Requirements

- Kubernetes API server must be reachable
- Provide kubeconfig context
- RBAC access for our agent

Use this for:
- On-prem clusters
- Rancher / OpenShift setups

![BYOK Setup](../assets/screenshots/advanced-setup.png)