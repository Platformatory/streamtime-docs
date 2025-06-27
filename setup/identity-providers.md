---
title: "Identity Providers"
nav_order: 3
parent: Get Started
---

# Identity Providers

To secure access to your Streamtime platform, configure an external identity provider (IdP).

## Supported Providers

- Google Workspace (OIDC)
- Azure Active Directory (OIDC)
- Custom OIDC providers

## What You Need

- Client ID and Client Secret
- Discovery URL (e.g. `https://accounts.google.com/.well-known/openid-configuration`)
- Redirect URI: `<your-control-plane-url>/auth/callback`

## Best Practices

- Use a separate client per environment (dev/staging/prod)
- Set login restrictions (domain or group-based)
