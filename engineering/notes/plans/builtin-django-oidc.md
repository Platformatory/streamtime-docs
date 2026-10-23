---
name: Built-in Django OIDC
overview: Selectable built-in OIDC issuer in Django for local/trial. Replaces Streamtime Public IDP at onboarding. Org-scoped OAuth Clients mint JWTs (auth code, password, client credentials). Kafka cluster is an OAuth scope, not a client FK.
---

# Built-in Django OIDC

Dev / bundled / trial identity. Keycloak (“Streamtime Private IDP”) and BYOIDP stay for real deployments. UI warns this is not a production IdP.

## Locked decisions

- **One issuer per org.** Builtin or external covers both UI login and Kafka. No Kafka-only sidecar.
- **Custom RS256 issuer** (`core/services/builtin_oidc.py` + PyJWT). `django-oidc-provider` and DOT issue opaque access tokens; Kong and Kafka JWKS-validate the **access** token.
- **Naming:** OAuth Clients, not service accounts.
- **Scoping:** clients are **org-scoped**. Kafka cluster is scope `kafka:{identifier}` on the client. A Kafka FK would not constrain JWTs that share the org JWKS. Optional list filter `?kafka=`.
- **Grants:** password grant is always available on the built-in issuer (no setting or toggle). UI client is `authorization_code` (password works on that client). Machine clients are `client_credentials`.
- **Onboarding:** builtin replaces Public IDP (Auth0/DCR). Default sign-in is the root contact email / streamtime (operator may set a custom password, min 5 chars). Recovery secret + hint for password reset on `/oidc/login/?reset=1`.
- **Members:** invite requires password in builtin mode; set-password for rotation.
- **Tunnel:** dedicated Kong route `/oidc` (skips JWT). Stable `iss` from `fleet_manager_external_url`; reachable token/JWKS from orchestrator tunnel when set.

## How it plugs in

No Kong JWT-verification rewrite. Setup writes `OAuthProvider` `builtin-oidc` whose endpoints are the Django issuer. Kong still fetches `GET /organizations/{org}/oidc-credentials/` (now includes `oidc_mode`) and runs auth-code + PKCE. JWTs carry `email` so existing middleware keeps working. Client-credentials tokens use `{client_id}@oauth-clients.local`.

```
GET  /oidc/.well-known/openid-configuration
GET  /oidc/.well-known/jwks.json
GET  /oidc/authorize/          PKCE
POST /oidc/token/              authorization_code | password | client_credentials
GET  /oidc/userinfo/
POST /setup/oidc/builtin/      admin password
CRUD /organizations/{org}/oauth-clients/
POST /organizations/{org}/oauth-clients/{id}/rotate/
POST /organizations/{org}/members/{id}/set-password/
```

## OAuth Clients

| | |
|---|---|
| URL | `/organizations/{org}/oauth-clients/` |
| Storage | `OAuthClient` unique on `(organization, identifier)` |
| Scopes | `OAuthClientScopesSchema.kafka_clusters` → `kafka:{id}` at token time |
| Secrets | returned once on create/rotate |
| Gate | 403 unless `oidc_mode=builtin` |

Empty cluster list means no Kafka scopes. Brokers that cannot yet check `scope` still get a valid JWT; Helm expected-scope is a follow-up.

## Still out of this PR / follow-up

- Optional broker expected-scope enforcement for `kafka:{id}` beyond Helm `oauth.scope`.
- Apply migration `0145_builtin_oidc_oauth_clients` in running environments.
