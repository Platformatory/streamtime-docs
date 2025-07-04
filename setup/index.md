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
- Configure your DNS to point to the Streamtime-managed endpoints.
- Upload or generate TLS certificates for encrypted communication.

![Domain & Certificates Configuration]({{ site.baseurl }}/assets/images/dns-certs.png)
See [Domains & Certificates](domains-certificates.html) for detailed steps.

---

## 2. Identity Provider (OIDC)

Integrate your organization's identity provider using OIDC (OpenID Connect) for secure authentication and single sign-on (SSO).  
- Supports integration with providers like Auth0, Keycloak, Okta, and others.
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

Configure your fleet provider credentials and permissions to enable automated cluster management.

![Fleet Provider Configuration]({{ site.baseurl }}/assets/images/aws/fleet-provider.png)

See [Fleet Providers](fleet-providers.html) for more information.
