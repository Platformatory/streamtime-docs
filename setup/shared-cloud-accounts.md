---
title: "Setting up Shared Cloud Accounts"
nav_order: 1
parent: Get Started
---

# Setting up Shared Cloud Accounts

To bootstrap and manage fleets and clusters, you need to provide access to your cloud infrastructure.

## Why Shared Accounts?

Shared accounts let you reuse cloud credentials for multiple fleets and clusters. This is essential for consistent provisioning, tagging, and auditing.

## Supported Cloud Providers

- AWS (via IAM access key or STS AssumeRole)
- GCP (via Service Account key)
- Oracle Cloud (via tenancy OCID & API key)
- Azure (via Client Secret or Workload Identity)

## Recommended Practice

- Use **least privilege** policies scoped to specific tags or resource groups.
- Create one provider config per cloud region if network peering is required.
