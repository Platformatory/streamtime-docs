---
title: "Identity Providers"
nav_order: 3
parent: Shared Cloud Accounts & Services

---

# Identity Providers

Streamtime supports integration with external identity providers using OIDC (OpenID Connect) for OAuth Bearer authentication. This enables secure, centralized authentication for accessing Kafka clusters and management interfaces.

By configuring an identity provider, you can enforce single sign-on (SSO) and manage user access through platforms such as  Okta, Keycloak, Auth0, Azure AD, Google, or any OIDC-compliant provider.

## How Streamtime Uses Identity Providers

- **OAuth Bearer Authentication**: Kafka clusters use OAuth Bearer tokens for client authentication.
- **Centralized Access Control**: Manage user and group permissions from your identity provider.
- **Single Sign-On (SSO)**: Users authenticate once and gain access to all authorized Streamtime services.

## Required OIDC Endpoints

To integrate your identity provider, you must provide the following OIDC endpoints:

- **Authorization Endpoint**: Used for user login and consent.
- **Issuer URL**: The base URL of your identity provider, which includes the authorization and token endpoints.
- **Token Endpoint**: Used to exchange authorization codes for access tokens.
- **JWKS URL**: JSON Web Key Set endpoint for public keys used to verify token signatures.

![OIDC Integration Example]({{ site.baseurl }}/assets/images/identity-provider.png)

## Configuration Steps

1. Register Streamtime as an application in your identity provider.
2. Provide the OIDC issuer URL, client ID, client secret, authorization endpoint, token endpoint, and JWKS URL in the Streamtime platform.
3. Assign users or groups who should have access to Kafka clusters.

See the platform UI or CLI for detailed setup instructions.

---
