---
title: Shared Cloud Accounts & Services
nav_order: 3
layout: home
# parent: Get Started
---

# Shared Cloud Accounts & Services

The foundational setup required for Streamtime, including shared cloud accounts, domain and certificate management, fleet provider configuration, and identity provider integration.

---


## 1. Domain & Certificates

Domains and TLS certificates are required for secure access to your Kafka clusters and management interfaces.  
### Why Domains & Certificates?
- Configure a base domain for your Streamtime-managed services.
- All Kafka clusters, monitoring dashboards, logging endpoints, and schema registries will be accessible under this domain.
- TLS certificates ensure encrypted communication for all endpoints.
- Streamtime can manage certificates automatically or you can upload your own.

## DNS Configuration
- Configure your DNS to point to the Streamtime-managed endpoints.
- Upload or generate TLS certificates for encrypted communication.

![Domain & Certificates Configuration]({{ site.baseurl }}/assets/images/dns-certs.png)
See [Domains & Certificates](domains-certificates.html) for detailed steps.

---

## 2. Identity Provider (OIDC)

Integrate your organization's identity provider using OIDC (OpenID Connect) for secure authentication and single sign-on (SSO).  

### Why Use an Identity Provider?
- Streamline user management and authentication across your Kafka clusters.
- Enable single sign-on (SSO) for users across multiple applications.
- Centralize user access control and permissions.
- Support for OIDC-compliant identity providers like Auth0, Keycloak, Okta, and others.

### Key Features
- Simplifies user authentication and authorization.
- Provides SSO capabilities for users across Kafka clusters and management interfaces.
- Enables centralized user and access management.

![OIDC Integration Example]({{ site.baseurl }}/assets/images/identity-provider.png)

See [Identity Providers](identity-providers.html) for setup instructions.

---


## 3. Fleet Provider

A Fleet Provider is the cloud platform where your Kubernetes fleets are provisioned.  
Supported providers include:
- AWS
- GCP
- OCI
- Azure

### Why Configure a Fleet Provider?
- Streamtime automates the provisioning and management of Kubernetes clusters on your chosen cloud provider.
- Each provider has unique features, regions, and compliance options.
- Choose the provider that best fits your requirements for region, compliance, and cost.

Configure your fleet provider credentials and permissions to enable automated cluster management.

![Fleet Provider Configuration]({{ site.baseurl }}/assets/images/fleet-provider.png)

See [Fleet Providers](fleet-providers.html) for more information.
