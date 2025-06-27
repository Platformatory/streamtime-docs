---
title: "Fleet Providers"
nav_order: 4
parent: Get Started
---

# Fleet Providers

Fleet providers define which cloud infrastructure Streamtime can provision Kubernetes clusters on.

## Types of Providers

- Bring Your Own Kubernetes (BYOK)
- Managed Services: AWS EKS, GCP GKE, Oracle OKE, Azure AKS

## Required Permissions

| Provider | Required IAM/Role Permissions |
|----------|-------------------------------|
| AWS EKS | eks:*, ec2:*, iam:* |
| GCP GKE | container.*, compute.*, iam.* |
| OCI OKE | container-engine.*, vcn.*, identity.* |
| Azure AKS | Microsoft.ContainerService/* |

Each provider must also allow node pool auto-scaling and private networking.
