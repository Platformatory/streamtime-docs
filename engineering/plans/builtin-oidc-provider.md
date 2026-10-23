# django-oidc-provider Integration Plan

## Summary

Integrate `django-oidc-provider` as a **built-in OIDC provider** embedded inside Fleet Manager's Django backend. The goal: users can complete the onboarding wizard and reach a fully working system without touching Keycloak, Okta, or any external IdP. The built-in provider is also the token issuer for Kafka SASL/OAUTHBEARER service accounts.

A prominent warning appears wherever this mode is selected: **not suitable for production**; recommend Keycloak, Okta, Auth0, etc.

---

## Architecture

```
Browser → Kong → /oidc/authorize/ → Django login page → auth code
         → Kong → /oidc/token/    → access token (RS256 JWT)
         → Kong → /oidc/.well-known/jwks.json → public key for verification
         → Kong authz-proxy plugin validates JWT same as today
```

For Kafka service accounts:
```
Kafka client → POST /oidc/token/ grant_type=client_credentials → JWT → SASL/OAUTHBEARER
```

Kong's `kong-authz-proxy` plugin already fetches `jwks_endpoint_uri` from `/organizations/{org}/oidc-credentials/` and validates tokens against it. When the built-in provider is configured, `jwks_endpoint_uri` points to `/oidc/.well-known/jwks.json` — no plugin changes needed.

### Org scoping model

- **Human users**: `OrgUser` table maps `email → org`. Lazy creation post-auth (middleware) still works once a user can actually log in. With built-in OIDC, users must exist with a usable password **before** their first login — the lazy get_or_create pattern is incompatible with being your own IdP.
- **OIDC clients** (`django-oidc-provider`'s `Client` model) have no org FK — they are global to the provider.
- **Kafka service accounts**: linked via naming convention `kafka-sa-{kafka_identifier}`. A bridge model (`KafkaOIDCClient`) records the association: Kafka cluster → `oidc_provider.Client`. This enables per-cluster credential display and secret rotation without relying on name parsing.
- **Built-in mode is one shared issuer** across all orgs. Per-org scoping is entirely through `OrgUser` records, same as today.

---

## Phase 1: Django Backend — Library Setup

### 1.1 Install

Add to `requirements.txt`:
```
django-oidc-provider>=0.9
```

### 1.2 `settings.py` changes

```python
INSTALLED_APPS = [
    ...
    'oidc_provider',      # must come after 'django.contrib.auth'
    'core',
    ...
]

OIDC_USERINFO = 'core.oidc_hooks.userinfo'
OIDC_EXTRA_SCOPE_CLAIMS = 'core.oidc_hooks.CustomScopeClaims'
OIDC_IDTOKEN_EXPIRE = 3600
OIDC_TOKEN_EXPIRE = 3600
OIDC_CODE_EXPIRE = 60
OIDC_AFTER_USERLOGIN_HOOK = 'core.oidc_hooks.after_userlogin'
OIDC_IDTOKEN_PROCESSING_HOOK = 'core.oidc_hooks.process_id_token'
LOGIN_URL = '/oidc/login/'
OIDC_GRANT_TYPE_PASSWORD_ENABLE = False
OIDC_GRANT_TYPE_CLIENT_CREDENTIALS_ENABLE = True
```

### 1.3 `urls.py` changes

```python
from django.contrib.auth import views as auth_views

urlpatterns = [
    path('oidc/', include('oidc_provider.urls', namespace='oidc_provider')),
    path('oidc/login/', auth_views.LoginView.as_view(template_name='oidc/login.html'), name='oidc-login'),
    path('oidc/logout/', auth_views.LogoutView.as_view(next_page='/'), name='oidc-logout'),
    ...
]
```

Well-known endpoints from `oidc_provider.urls`:
- `GET /oidc/.well-known/openid-configuration`
- `GET /oidc/.well-known/jwks.json`
- `GET/POST /oidc/authorize/`
- `POST /oidc/token/`
- `GET /oidc/userinfo/`
- `POST /oidc/end-session/`

Kong whitelist must include `/oidc/.*` — update `kong.yml`, `kong.singlenode.yaml`, `kong.trial.yaml`.

### 1.4 Login template

**New file:** `fleet-manager-backend/templates/oidc/login.html`
- Minimal Django form-based login with Fleet Manager branding
- Note: "Built-in authentication — not for production use"

```python
# settings.py
TEMPLATES[0]['DIRS'] = [BASE_DIR / 'templates']
```

---

## Phase 2: Custom Claims Hook

**New file:** `fleet-manager-backend/core/oidc_hooks.py`

```python
def userinfo(claims, user):
    claims['email'] = user.email
    claims['email_verified'] = True
    claims['name'] = user.get_full_name() or user.email
    return claims

def after_userlogin(request, user, client):
    pass  # hook point for audit logging

def process_id_token(id_token, token, request):
    # For client_credentials grants, add a synthetic service-account email
    # so OrgJWTUserCheckMiddleware doesn't crash on missing email claim
    if not id_token.get('email'):
        client_id = id_token.get('sub', '')
        id_token['email'] = f"{client_id}@service.{settings.FLEET_MANAGER_DOMAIN}"
    return id_token
```

---

## Phase 3: RSA Key Bootstrap

**New file:** `fleet-manager-backend/core/services/builtin_oidc.py`

```python
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend
from oidc_provider.models import RSAKey

def ensure_rsa_key():
    if not RSAKey.objects.exists():
        from cryptography.hazmat.primitives import serialization
        private_key = rsa.generate_private_key(
            public_exponent=65537, key_size=2048, backend=default_backend()
        )
        pem = private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.TraditionalOpenSSL,
            encryption_algorithm=serialization.NoEncryption(),
        ).decode()
        RSAKey.objects.create(key=pem)

def create_ui_client(redirect_uri):
    from oidc_provider.models import Client, ResponseType
    import secrets
    client, _ = Client.objects.get_or_create(
        name='fleet-manager-ui',
        defaults={
            'client_id': 'fleet-manager-ui',
            'client_secret': secrets.token_urlsafe(32),
            'client_type': 'confidential',
            'redirect_uris': [redirect_uri],
            'require_consent': False,
        }
    )
    resp_type, _ = ResponseType.objects.get_or_create(value='code')
    client.response_types.add(resp_type)
    return client

def create_kafka_client(kafka_identifier, name):
    """Create or return the client_credentials OIDC client for a Kafka cluster."""
    from oidc_provider.models import Client
    import secrets
    client, created = Client.objects.get_or_create(
        client_id=f'kafka-sa-{kafka_identifier}',
        defaults={
            'name': name,
            'client_secret': secrets.token_urlsafe(32),
            'client_type': 'confidential',
            'redirect_uris': [],
        }
    )
    return client, created

def rotate_kafka_client_secret(kafka_identifier):
    """Rotate the client_secret for a Kafka cluster's OIDC client."""
    import secrets
    from oidc_provider.models import Client
    client = Client.objects.get(client_id=f'kafka-sa-{kafka_identifier}')
    client.client_secret = secrets.token_urlsafe(32)
    client.save(update_fields=['client_secret'])
    return client
```

`ensure_rsa_key()` is called in `apps.py`'s `ready()` when setup is complete and built-in OIDC mode is active.

---

## Phase 4: Setup Backend

### 4.1 New SystemSetup field

**`core/models.py`** — add to `SystemSetup`:
```python
OIDC_MODE_CHOICES = [('builtin', 'Built-in'), ('external', 'External')]
oidc_mode = models.CharField(max_length=16, choices=OIDC_MODE_CHOICES, default='external')
```

**New migration:** `0120_systemsetup_oidc_mode.py`
Data migration: set `oidc_mode = 'external'` for any existing complete `SystemSetup` rows.

### 4.2 New KafkaOIDCClient bridge model

**`core/models.py`** — new model:
```python
class KafkaOIDCClient(models.Model):
    kafka = models.OneToOneField(Kafka, on_delete=models.CASCADE, related_name='oidc_client')
    oidc_client_id = models.CharField(max_length=255)  # matches oidc_provider.Client.client_id
    created_at = models.DateTimeField(auto_now_add=True)
```

This bridge enables lookups without name parsing and cascades deletes cleanly.

### 4.3 `SetupOIDCBuiltinView`

**`core/views/setup/oidc.py`** — add `SetupOIDCBuiltinView`:

```python
class SetupOIDCBuiltinView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        setup = SystemSetup.get_singleton()
        if setup.is_complete:
            raise PermissionDenied("Setup already complete.")

        from core.services.builtin_oidc import ensure_rsa_key, create_ui_client
        ensure_rsa_key()

        external_url = (getattr(settings, 'FLEETMANAGER_EXTERNAL_URL', '') or '').rstrip('/')
        if not external_url:
            return Response({"error": "FLEETMANAGER_EXTERNAL_URL must be set."}, status=400)

        redirect_uri = f"{external_url}/authHandler"
        ui_client = create_ui_client(redirect_uri)
        issuer = f"{external_url}/oidc"
        root_org = Organization.objects.get(identifier='root')

        provider, _ = OAuthProvider.objects.update_or_create(
            identifier='root-oauth',
            defaults={
                'issuer': issuer,
                'jwks_endpoint_uri': f"{issuer}/.well-known/jwks.json",
                'token_endpoint_uri': f"{issuer}/token/",
                'authorize_endpoint_uri': f"{issuer}/authorize/",
                'client_id': ui_client.client_id,
                'client_secret': ui_client.client_secret,
                'scope': 'openid profile email',
                'email_claim_name': 'email',
                'sub_claim_name': 'sub',
                'refresh_token': True,
                'organization': root_org,
            }
        )
        if not root_org.oauth_provider_id:
            root_org.oauth_provider = provider
            root_org.save(update_fields=['oauth_provider'])

        for org in Organization.objects.filter(oauth_provider__isnull=True):
            org.oauth_provider = provider
            org.save(update_fields=['oauth_provider'])

        # Bootstrap first superuser password
        User = get_user_model()
        super_user_email = (os.getenv('SUPER_USER_EMAILS') or '').split(',')[0].strip()
        initial_password = (request.data.get('initial_password') or '').strip()
        if not initial_password:
            initial_password = secrets.token_urlsafe(12)
        if super_user_email:
            user, _ = User.objects.get_or_create(
                email=super_user_email, username=super_user_email
            )
            user.set_password(initial_password)
            user.save(update_fields=['password'])

        setup.oidc_complete = True
        setup.oidc_mode = 'builtin'
        setup.save(update_fields=['oidc_complete', 'oidc_mode', 'updated_at'])

        return Response({
            'oidc_complete': True,
            'mode': 'builtin',
            'issuer': issuer,
            'client_id': ui_client.client_id,
            'client_secret': ui_client.client_secret,
            'redirect_uri': redirect_uri,
            'initial_password': initial_password,   # shown once in wizard; never stored
            'admin_email': super_user_email,
        })
```

### 4.4 `core/urls_setup.py`

```python
path("oidc/builtin/", SetupOIDCBuiltinView.as_view()),
```

### 4.5 `core/views/setup/status.py`

Expose `oidc_mode` in the status response.

---

## Phase 5: Middleware Compatibility

`OrgJWTUserCheckMiddleware` already does `jwt.decode(..., options={"verify_signature": False})` and extracts email — no changes needed for human user tokens.

For Kafka `client_credentials` tokens, `process_id_token` (Phase 2) injects a synthetic `email` claim so the middleware doesn't crash if a service-account token ever reaches the API. These tokens are normally consumed only by Kafka brokers and never sent to the Fleet Manager API.

---

## Phase 6: Admin Password Management

### 6.1 Backend — set-password endpoint

Add a `set_password` action to `OrganizationMemberViewSet`:

```python
@action(detail=True, methods=["post"], url_path="set-password")
def set_password(self, request, org_identifier=None, pk=None):
    setup = SystemSetup.get_singleton()
    if setup.oidc_mode != 'builtin':
        return Response({"error": "Only available in built-in OIDC mode."}, status=400)
    password = (request.data.get("password") or "").strip()
    if not password:
        return Response({"error": "password is required."}, status=400)
    org_user = self.get_object()
    if not org_user.user:
        # Ensure Django User row exists
        User = get_user_model()
        user, _ = User.objects.get_or_create(
            email=org_user.email, username=org_user.email
        )
        org_user.user = user
        org_user.save(update_fields=['user'])
    org_user.user.set_password(password)
    org_user.user.save(update_fields=['password'])
    return Response(status=204)
```

Requires `Administrator` role — existing `OrganizationPermission` enforces this.

### 6.2 Member creation ensures Django User exists

`OrganizationMemberViewSet.perform_create()` (or serializer) must call `User.objects.get_or_create(email=email, username=email)` before creating `OrgUser`, so `set-password` always has a `user` FK to target. Verify and fix if not already done.

### 6.3 Frontend — Members page "Set Password" button

In the org Members page, when `oidc_mode === 'builtin'`:
- Add a key/lock icon button per member row
- Opens a dialog: single password field + "Set Password" submit button
- Calls `PATCH /organizations/{org}/members/{id}/set-password/`
- Success: snackbar "Password updated", dialog closes
- Button is hidden entirely when `oidc_mode === 'external'`

---

## Phase 7: Frontend — OIDC Wizard Step

**Modify:** `src/features/onboarding/steps/OIDCProviderStep.jsx`

Add mode selector at top:
- `RadioGroup`: "External OIDC Provider (recommended)" | "Built-in OIDC (development only)"
- `Alert severity="warning"` shown when builtin selected

### Built-in branch flow

The step does **not** auto-advance after the API call. Instead it transitions through two sub-states:

**Sub-state 1 — Setup form:**
```
[Radio: Built-in OIDC ●]
⚠️  Built-in OIDC is not suitable for production...

[Set Up Built-in OIDC]  ← calls POST /setup/oidc/builtin/
```

**Sub-state 2 — Credential display (after API success):**
```
✅ Built-in OIDC configured

Admin login
  Email:    admin@example.com
  Password: [abc123xyz...]  [Copy] [Show/Hide]
  — or set your own —
  New password: [______________]

☐  I've saved these credentials

[Continue]  ← disabled until checkbox checked
```

- If admin types a custom password in "set your own" field, clicking Continue calls
  `POST /organizations/root/members/{admin_id}/set-password/` before `onComplete()`
- `initial_password` from the API response is never stored in state after `onComplete()`

### External branch

Existing form unchanged.

**Modify:** `src/services/setupService.js`
```js
postOIDCBuiltin: (data) => setupClient.post("/setup/oidc/builtin/", data),
getOIDC: () => setupClient.get("/setup/oidc/"),
```

---

## Phase 8: Kafka SASL/OAUTHBEARER — Per-cluster Service Account

### 8.1 Token flow

```
Kafka broker config:
  sasl.oauthbearer.token.endpoint.url = https://api.{domain}/oidc/token/

Kafka client config:
  sasl.oauthbearer.client.id     = kafka-sa-{kafka_identifier}
  sasl.oauthbearer.client.secret = <secret>
  sasl.oauthbearer.scope         = openid
```

The broker validates tokens using JWKS at `https://api.{domain}/oidc/.well-known/jwks.json`.

### 8.2 Auto-creation on Kafka cluster create

In the Kafka cluster creation path (view or signal), when `setup.oidc_mode == 'builtin'`:
```python
from core.services.builtin_oidc import create_kafka_client
client, _ = create_kafka_client(kafka.identifier, kafka.name)
KafkaOIDCClient.objects.get_or_create(
    kafka=kafka,
    defaults={'oidc_client_id': client.client_id}
)
```

### 8.3 Kafka OIDC client API

**New view:** `core/views/kafka/oidc_client.py`

```
GET  /organizations/{org}/kafka/{id}/oidc-client/
     → Returns client_id, masked client_secret (last 4 chars), token_endpoint, example config snippet
     → 404 if KafkaOIDCClient doesn't exist yet
     → 403 if setup.oidc_mode != 'builtin'

POST /organizations/{org}/kafka/{id}/oidc-client/
     → Idempotent create: calls create_kafka_client(), creates KafkaOIDCClient bridge row
     → Returns full client_secret (only on create; subsequent GETs mask it)

POST /organizations/{org}/kafka/{id}/oidc-client/rotate/
     → Calls rotate_kafka_client_secret()
     → Returns new full client_secret (only time it's visible after initial create)
```

Register in `fleet_manager/urls.py`.

### 8.4 Frontend — Kafka cluster "OIDC Client" tab

**Condition:** Tab is rendered only when the cluster's org has `oidc_mode === 'builtin'` (read from app-level setup status context).

**New component:** `src/components/Kafka/KafkaOIDCClientTab.jsx`

Tab content:
```
SASL/OAUTHBEARER Service Account

Client ID:     kafka-sa-abc123          [Copy]
Client Secret: ••••••••••••[abcd]       [Reveal] [Copy] [Rotate Secret]

Token Endpoint:
  https://api.example.com/oidc/token/  [Copy]

── Kafka Client Config ──────────────────────────────
  sasl.oauthbearer.token.endpoint.url = https://...
  sasl.oauthbearer.client.id          = kafka-sa-abc123
  sasl.oauthbearer.client.secret      = <your secret>
  sasl.oauthbearer.scope              = openid
[Copy config]
─────────────────────────────────────────────────────

[Generate Client]   ← shown instead of above if not yet created
```

- "Reveal" fetches the secret on demand (or stores in component state after rotate)
- "Rotate Secret" shows a confirmation dialog → calls rotate API → shows new secret once
- The tab is a no-op / hidden entirely when `oidc_mode !== 'builtin'`

---

## Phase 9: apps.py Changes

In `CoreConfig.ready()`, after encryption key loading:

```python
try:
    setup = SystemSetup.get_singleton()
    if setup.is_complete and setup.oidc_mode == 'builtin':
        from .services.builtin_oidc import ensure_rsa_key
        ensure_rsa_key()
except Exception:
    pass
```

In `bootstrap_async()`, when `setup.oidc_mode == 'builtin'`, skip creating `root-oauth` from env vars — the built-in provider record is already in the database from setup.

---

## Phase 10: Kong Whitelist

**Modify:** `fleet-manager-gateway/kong.yml`, `kong.singlenode.yaml`, `kong.trial.yaml`

Add to `kong-authz-proxy` plugin `config.whitelist_paths`:
```yaml
- /oidc/.*
```

---

## Phase 11: Helm Chart

**Modify:** `charts/fleet-manager/templates/fleet-manager-api-deployment.yaml`

```yaml
- name: OIDC_ISSUER_URL
  value: https://{{ include "fleetmanager.api.domain" . }}/oidc
```

Informational only — actual issuer computed from `FLEETMANAGER_EXTERNAL_URL`.

---

## New UI Inventory

| UI surface | Type | Condition | Description |
|---|---|---|---|
| `OIDCProviderStep.jsx` — builtin branch | Onboarding wizard step | Always (mode selector) | Mode radio, production warning, "Set Up" button |
| `OIDCProviderStep.jsx` — credential display | Wizard sub-state | After builtin setup API call | Admin email + initial password display, copy, optional override field, confirmation checkbox |
| `KafkaOIDCClientTab.jsx` | New tab on Kafka cluster detail page | `oidc_mode === 'builtin'` only | client_id, masked secret, reveal, rotate, token endpoint, copy-paste config snippet |
| Members page — "Set Password" button + dialog | Addition to existing Members page | `oidc_mode === 'builtin'` only | Per-member lock icon, password dialog, calls set-password API |
| Django login template `oidc/login.html` | Server-rendered Django template (not React) | Built-in OIDC active | Username + password form, Fleet Manager branding, "not for production" notice |

---

## Migration Plan

| # | Migration | Content |
|---|-----------|---------|
| 0120 | `systemsetup_oidc_mode` | Add `oidc_mode` to `SystemSetup`; data migration sets `'external'` for existing complete rows |
| 0121 | `kafkaoidcclient` | Add `KafkaOIDCClient` bridge model |
| auto | `oidc_provider` tables | Run automatically via `manage.py migrate` after adding to INSTALLED_APPS |

---

## Files Changed

### New backend files
- `core/services/builtin_oidc.py` — RSA key bootstrap, client creation, secret rotation
- `core/oidc_hooks.py` — userinfo claims, client_credentials synthetic email
- `core/views/kafka/oidc_client.py` — Kafka OIDC client API views
- `core/migrations/0120_systemsetup_oidc_mode.py`
- `core/migrations/0121_kafkaoidcclient.py`
- `templates/oidc/login.html`

### Modified backend files
- `fleet_manager/settings.py` — add `oidc_provider`, OIDC settings, LOGIN_URL, TEMPLATES DIRS
- `fleet_manager/urls.py` — mount `/oidc/`, register Kafka OIDC client routes
- `core/models.py` — add `oidc_mode` to `SystemSetup`, add `KafkaOIDCClient`
- `core/views/setup/oidc.py` — add `SetupOIDCBuiltinView`, add GET to `SetupOIDCView`
- `core/views/setup/status.py` — expose `oidc_mode`
- `core/views/organization/views.py` — add `set_password` action to `OrganizationMemberViewSet`; ensure `perform_create` creates Django `User` row
- `core/urls_setup.py` — register `oidc/builtin/`
- `core/apps.py` — call `ensure_rsa_key()` on startup; skip env-var OIDC creation when builtin

### New frontend files
- `src/components/Kafka/KafkaOIDCClientTab.jsx`

### Modified frontend files
- `src/features/onboarding/steps/OIDCProviderStep.jsx` — builtin mode branch + credential display sub-state
- `src/services/setupService.js` — add `postOIDCBuiltin`, `getOIDC`
- Kafka cluster detail page — add `KafkaOIDCClientTab` (conditional render)
- Org Members page — add "Set Password" button + dialog (conditional render)

### Modified gateway files
- `fleet-manager-gateway/kong.yml`
- `fleet-manager-gateway/kong.singlenode.yaml`
- `fleet-manager-gateway/kong.trial.yaml`
— add `/oidc/.*` to whitelist_paths

---

## Verification Checklist

1. Fresh install → choose Built-in OIDC → wizard shows admin email + initial password → checkbox required before Continue
2. Admin can override the generated password before continuing
3. Login at `https://api.{domain}/oidc/login/` with initial credentials works
4. Authorization code flow completes → token → Kong validates → `/organizations/root/me/organizations/` returns results
5. `GET /oidc/.well-known/jwks.json` returns RS256 public key
6. Members page shows "Set Password" button only when `oidc_mode === 'builtin'`; admin can set a member's password; member can then log in
7. Kafka cluster detail page shows "OIDC Client" tab only when `oidc_mode === 'builtin'`
8. Tab shows client_id, masked secret, token endpoint, config snippet
9. "Rotate Secret" generates a new secret, displays it once
10. `POST /oidc/token/` with `grant_type=client_credentials` + kafka-sa client returns valid JWT
11. Existing external OIDC installs: `oidc_mode = 'external'`, tab hidden, set-password endpoint returns 400, no disruption
12. Wizard back-navigation to OIDC step pre-selects saved mode
