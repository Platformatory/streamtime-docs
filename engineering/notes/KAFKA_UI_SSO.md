# Kafka UI Single Sign-On (SSO) Guide

Kafka UI uses Spring Security's OAuth2/OIDC implementation to provide a seamless Single Sign-On (SSO) experience. It is designed to work with any OIDC-compliant provider (Okta, Keycloak, Azure AD, etc.) by sharing a common configuration.

---

##  Quick Start

> Note: Kafka UI authentication is separate from Strimzi Kafka listener authentication. You can deploy a Strimzi cluster with `SASL/SCRAM` for Kafka client connections while still using OAuth SSO for Kafka UI login.

### 1. Update `values.yaml`
Ensure global OIDC is configured and enable SSO for Kafka UI:

```yaml
# Global OIDC Configuration
oauth:
  clientId: "your-client-id"
  clientSecret: "your-client-secret"
  issuer: "https://your-idp.com"
  jwksEndpoint: "https://your-idp.com/.well-known/jwks.json"
  clientName: "Identity Service" # Optional: Display name on login button

# Kafka UI Configuration
kafkaUi:
  auth:
    type: "OAUTH2"
```

### 2. Deploy
Apply the changes using Helm:

```bash
helm upgrade --install fleet-manager-strimzi ./charts/fleet-manager-strimzi \
  -f values.yaml \
  -n kafka-system
```

### 3. Access
Navigate to `https://<kafka-ui-domain>`. You will be redirected to your Identity Provider (IdP) for authentication.

---

##  Configuration Reference

### Identity Provider (IdP) Setup
Register your Kafka UI application in your IdP with the following **Redirect URI**:

```
https://<kafka-ui-domain>/login/oauth2/code/oidc
```

### OIDC Parameters
| Parameter | Description |
|-----------|-------------|
| `clientId` | Unique identifier for the application in the IdP. |
| `clientSecret` | Secret key used for authenticating the application. |
| `issuer` | The base URL of the OIDC provider. |
| `jwksEndpoint` | URL to fetch the JSON Web Key Set for token validation. |
| `groupsClaim` | (Optional) Token claim name used for role mapping (default: `groups`). |
| `clientName` | (Optional) Name displayed on the login button (default: `Identity Service`). |

---

##  Deployment & Troubleshooting

### Verification
Check the pod status and logs to ensure the application started correctly:

```bash
# Check pod status
kubectl get pods -n kafka-system -l app=kafka-ui

# View logs for authentication events
kubectl logs -n kafka-system -l app=kafka-ui
```

### Common Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| **"Invalid client"** | Incorrect `clientId` or `clientSecret`. | Verify credentials in the IdP portal. |
| **"Redirect URI mismatch"** | IdP redirect URI does not match Kafka UI. | Ensure IdP redirect URI ends with `/login/oauth2/code/oidc`. |
| **"Invalid issuer"** | Issuer URL is incorrect or unreachable. | Verify the URL and check pod network/DNS. |
| **Groups not showing** | `groupsClaim` mismatch in token. | Match `groupsClaim` to the claim name in your token. |

---

##  Security Best Practices
1. **Enable TLS**: Always access Kafka UI via HTTPS.
2. **Rotate Secrets**: Regularly update your OAuth client secrets.
3. **Least Privilege**: Map user groups to appropriate roles in Kafka UI if using RBAC.
