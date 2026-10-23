# Fleet Manager Secrets Management System

## Overview

The Fleet Manager Secrets Management System provides a unified interface for managing secrets across different backend providers. It supports multiple secret management systems through a pluggable provider architecture, allowing seamless switching between different vault providers without changing the API interface.

## Architecture

### Core Components

1. **Secret Model** (`core/models.py`)
   - Django model for storing secret metadata
   - Fields: `id`, `organization`, `author`, `provider`, `path`, `content`, `created_at`, `updated_at`, `provider_data`

2. **VaultProvider Interface** (`fleet_secrets_manager/providers.py`)
   - Abstract base class defining the provider interface
   - All providers must implement CRUD operations

3. **VaultProviderFactory** (`fleet_secrets_manager/providers.py`)
   - Factory pattern for provider instantiation
   - Handles provider discovery and configuration loading

4. **SecretsManager** (`fleet_secrets_manager/manager.py`)
   - High-level integration between Django models and vault providers
   - Orchestrates operations between the database and external vaults

5. **API Layer** (`core/views.py`, `core/serializers.py`)
   - REST API endpoints for secret management
   - Handles authentication, validation, and serialization

## Supported Providers

### Builtin Provider
- **Type**: Database storage
- **Description**: Stores secrets directly in the PostgreSQL database
- **Use Case**: Development, testing, or when external vaults are not available
- **Configuration**: No additional configuration required

### HashiCorp Vault Provider
- **Type**: External vault service
- **Description**: Integrates with HashiCorp Vault (local or cloud) via AppRole auth
- **Authentication**: AppRole (role_id + secret_id)
- **Configuration**: exclusively via `GlobalConfiguration` — there is no environment-variable
  runtime channel for these keys. Set them through the onboarding Vault step, or by seeding
  `STREAMTIME_GLOBAL_VAULT_*` env vars (which `core/apps.py` writes into `GlobalConfiguration`
  on startup):
  - `vault_mode`: `builtin` (default) or `hashicorp`
  - `vault_url`: Vault server URL
  - `vault_role_id` / `vault_secret_id`: AppRole credentials
  - `vault_namespace`: Vault namespace (optional)
  - `vault_mount_path`: AppRole auth mount (default `approle`)
  - `vault_kv_mount_path`: KV v2 secrets engine mount (default `secret`)

  Vault only becomes the active provider once `vault_mode=hashicorp` **and** `vault_url` +
  both AppRole credentials are present — an incomplete config keeps the active provider as
  `builtin` rather than half-enabling Vault. See `VaultProviderFactory.get_active_provider()` /
  `is_vault_configured()` in `fleet_secrets_manager/providers.py`.

  To try this locally with a disposable Vault, see
  [`fleet-manager-vault/README.md`](https://github.com/streamtime-ai/fleet-manager/blob/main/fleet-manager-vault/README.md) and run
  `docker compose --profile vault up -d`.

### AWS Secrets Manager Provider
- **Type**: Cloud service
- **Description**: Integrates with AWS Secrets Manager
- **Authentication**: AWS credentials (access key, secret key, region)
- **Configuration**:
  - `STREAMTIME_AWS_REGION`: AWS region
  - `STREAMTIME_AWS_ACCESS_KEY_ID`: AWS access key
  - `STREAMTIME_AWS_SECRET_ACCESS_KEY`: AWS secret key

### GCP Secret Manager Provider
- **Type**: Cloud service
- **Description**: Integrates with Google Cloud Secret Manager
- **Authentication**: Service account credentials
- **Configuration**:
  - `STREAMTIME_GCP_PROJECT_ID`: GCP project ID
  - `STREAMTIME_GCP_CREDENTIALS`: Service account JSON credentials

### Azure Key Vault Provider
- **Type**: Cloud service
- **Description**: Integrates with Azure Key Vault
- **Authentication**: Azure service principal
- **Configuration**:
  - `STREAMTIME_AZURE_VAULT_URL`: Key Vault URL
  - `STREAMTIME_AZURE_CLIENT_ID`: Service principal client ID
  - `STREAMTIME_AZURE_CLIENT_SECRET`: Service principal secret
  - `STREAMTIME_AZURE_TENANT_ID`: Azure tenant ID

## Configuration

### GlobalConfiguration (Vault provider)

The active Secrets API provider is **not** selected via environment variable. It's derived
entirely from `GlobalConfiguration` (see the HashiCorp Vault Provider section above for the
full key list). This is set either through the onboarding wizard's Vault step, or by seeding
`STREAMTIME_GLOBAL_VAULT_*` env vars for headless installs — both write to the same
`GlobalConfiguration` table, so there is a single source of truth regardless of install mode.

Existing rows are unaffected by a provider switch (mixed mode): reads/updates/deletes follow
each secret's own stored `provider`, and only new secrets created without an explicit
`provider` land on whichever provider is currently active.

### Docker Compose Configuration (local Vault for testing)

```bash
# Bring up a disposable, pre-initialized dev Vault (see fleet-manager-vault/README.md)
docker compose --profile vault up -d

# Point the backend at it (add to .env, then restart fleet-manager-backend)
STREAMTIME_GLOBAL_VAULT_MODE=hashicorp
STREAMTIME_GLOBAL_VAULT_URL=http://vault:8200
STREAMTIME_GLOBAL_VAULT_ROLE_ID=streamtime-approle-role-id
STREAMTIME_GLOBAL_VAULT_SECRET_ID=streamtime-approle-secret-id
```

Env-var-only providers (AWS/GCP/Azure — currently stub implementations, see below) still read
their config from `GlobalConfiguration` by the same mechanism, keyed by field name
(`aws_region`, `gcp_project_id`, etc.) rather than a `STREAMTIME_*` prefix.

## API Reference

### Base URL
```
https://api.streamtime.local:8443/organizations/{org_identifier}/secrets/
```

### Authentication
All API requests require a valid JWT token in the Authorization header:
```
Authorization: Bearer <jwt_token>
```

### Endpoints

#### Create Secret
```http
POST /organizations/{org_identifier}/secrets/
Content-Type: application/json

{
  "provider": "vault",
  "path": "database/password",
  "content": "{\"username\": \"admin\", \"password\": \"secret123\"}"
}
```

#### Get Secret by ID
```http
GET /organizations/{org_identifier}/secrets/{secret_id}/
```

#### Get Secret by Path
```http
GET /organizations/{org_identifier}/secrets/by-path/?uri=vault://database/password
```

#### Update Secret
```http
PUT /organizations/{org_identifier}/secrets/{secret_id}/
Content-Type: application/json

{
  "provider": "vault",
  "path": "database/password",
  "organization": "root",
  "content": "{\"username\": \"admin\", \"password\": \"newpassword123\"}"
}
```

#### Delete Secret
```http
DELETE /organizations/{org_identifier}/secrets/{secret_id}/
```

#### List Secrets
```http
GET /organizations/{org_identifier}/secrets/
```

### Response Format

#### Success Response
```json
{
  "id": "c3c63d62-2d9d-413b-822d-a699d7b02d02",
  "provider": "vault",
  "path": "test/vault-cloud-demo",
  "content": {
    "message": "Hello from Vault Cloud!",
    "timestamp": "2025-01-10T15:00:00Z",
    "provider": "hvac",
    "test": true
  },
  "uri": "vault://test/vault-cloud-demo",
  "organization": "root",
  "created_at": "2025-10-10T18:55:54.463978Z",
  "updated_at": "2025-10-10T18:55:54.464022Z"
}
```

#### Error Response
```json
{
  "non_field_errors": [
    "Failed to create secret: ['Failed to create secret in vault provider: Failed to create secret in HashiCorp Vault: 1 error occurred:\\n\\t* permission denied\\n\\n, on post https://streamtime-test-public-vault-bfb549b6.3e77e988.z1.hashicorp.cloud:8200/v1/secret/data/test/vault-cloud-demo']"
  ],
  "status_code": 400,
  "detail": "{'non_field_errors': [ErrorDetail(string=\"Failed to create secret: ['Failed to create secret in vault provider: Failed to create secret in HashiCorp Vault: 1 error occurred:\\\\n\\\\t* permission denied\\\\n\\\\n, on post https://streamtime-test-public-vault-bfb549b6.3e77e988.z1.hashicorp.cloud:8200/v1/secret/data/test/vault-cloud-demo']\", code='invalid')], 'status_code': 400}"
}
```

## Adding New Providers

### Step 1: Create Provider Class

Create a new class that inherits from `VaultProvider` and implement all abstract methods:

```python
class NewProvider(VaultProvider):
    def validate_config(self) -> None:
        """Validate provider-specific configuration."""
        required_fields = ['field1', 'field2']
        for field in required_fields:
            if field not in self.config or not self.config[field]:
                raise VaultProviderConfigError(f"Provider requires '{field}' configuration")
    
    def create_secret(self, path: str, content: str, metadata: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Create a secret in the external system."""
        # Implementation here
        pass
    
    def get_secret(self, path: str) -> Dict[str, Any]:
        """Retrieve a secret from the external system."""
        # Implementation here
        pass
    
    def update_secret(self, path: str, content: str, metadata: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Update a secret in the external system."""
        # Implementation here
        pass
    
    def delete_secret(self, path: str) -> bool:
        """Delete a secret from the external system."""
        # Implementation here
        pass
    
    def list_secrets(self, prefix: str = "") -> List[str]:
        """List secrets from the external system."""
        # Implementation here
        pass
    
    def test_connection(self) -> Dict[str, Any]:
        """Test connection to the external system."""
        # Implementation here
        pass
```

### Step 2: Register Provider

Add the new provider to the factory's provider registry:

```python
# In VaultProviderFactory class
PROVIDER_CLASSES = {
    'builtin': BuiltinVaultProvider,
    'vault': HashiCorpVaultProvider,
    'aws': AWSSecretsManagerProvider,
    'gcp': GCPSecretManagerProvider,
    'azure': AzureKeyVaultProvider,
    'newprovider': NewProvider,  # Add here
}
```

### Step 3: Add Configuration Support

Update the factory's configuration loading method to handle the new provider:

```python
def _get_provider_config(cls, provider_name: str) -> Dict[str, Any]:
    if provider_name == 'newprovider':
        # Config comes from GlobalConfiguration — no environment-variable fallback.
        return {
            'field1': cls._gc_value('field1'),
            'field2': cls._gc_value('field2'),
        }
    # ... existing providers
```

### Step 4: Update Exports

Add the new provider to the package exports:

```python
# In fleet_secrets_manager/__init__.py
from .providers import NewProvider

__all__ = [
    # ... existing exports
    'NewProvider',
]
```

### Step 5: Add Environment Variables

Document the required environment variables for the new provider:

```bash
# New Provider Configuration
STREAMTIME_NEWPROVIDER_FIELD1=value1
STREAMTIME_NEWPROVIDER_FIELD2=value2
```

## Usage Examples

### Using curl

#### Get Authentication Token
```bash
# Use the provided script
./scripts/get-auth-token.sh
export TOKEN="<jwt_token>"
```

#### Create a Secret
```bash
curl -X POST "https://api.streamtime.local:8443/organizations/root/secrets/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "provider": "vault",
    "path": "database/password",
    "content": "{\"username\": \"admin\", \"password\": \"secret123\"}"
  }' \
  -k
```

#### Retrieve a Secret
```bash
curl -X GET "https://api.streamtime.local:8443/organizations/root/secrets/by-path/?uri=vault://database/password" \
  -H "Authorization: Bearer $TOKEN" \
  -k
```

#### Update a Secret
```bash
curl -X PUT "https://api.streamtime.local:8443/organizations/root/secrets/{secret_id}/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "provider": "vault",
    "path": "database/password",
    "organization": "root",
    "content": "{\"username\": \"admin\", \"password\": \"newpassword123\"}"
  }' \
  -k
```

#### Delete a Secret
```bash
curl -X DELETE "https://api.streamtime.local:8443/organizations/root/secrets/{secret_id}/" \
  -H "Authorization: Bearer $TOKEN" \
  -k
```

### Using Python

```python
import requests

# Configuration
base_url = "https://api.streamtime.local:8443"
org_id = "root"
token = "your_jwt_token"
headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

# Create a secret
response = requests.post(
    f"{base_url}/organizations/{org_id}/secrets/",
    headers=headers,
    json={
        "provider": "vault",
        "path": "api/keys",
        "content": '{"api_key": "abc123", "secret": "xyz789"}'
    },
    verify=False
)

secret_data = response.json()
secret_id = secret_data["id"]

# Retrieve the secret
response = requests.get(
    f"{base_url}/organizations/{org_id}/secrets/by-path/?uri=vault://api/keys",
    headers=headers,
    verify=False
)

secret_content = response.json()["content"]
```

## Security Considerations

### Content Handling
- **Builtin Provider**: Content is stored in the database (encrypted if using EncryptedField)
- **External Providers**: Content is stored in the external vault system, opaquely (Vault never
  parses or reformats it — write and read round-trip the exact bytes you sent)
- **API Responses**: Content is included on detail/create/update responses only. **List**
  responses (`GET .../secrets/`) never include `content`, for either provider — see
  `SecretListSerializer` in `core/serializers.py`.

### Authentication
- All API endpoints require valid JWT authentication
- Provider-specific authentication is handled internally by each provider

### Provider Restrictions (mixed mode)
- `builtin` is always accepted as an explicit `provider` value.
- `vault` is accepted only when `GlobalConfiguration` has it fully configured
  (`VaultProviderFactory.is_vault_configured()`); otherwise it's rejected with a validation error.
- Existing secrets keep working under their original provider regardless of which one is
  currently active — only new secrets are gated by this check.

### Configuration Source
- All vault provider config lives in `GlobalConfiguration`, not environment variables —
  see the Configuration section above.
- No default values for Vault connection details are provided — explicit configuration
  (onboarding or `STREAMTIME_GLOBAL_VAULT_*`) is required before `vault_mode=hashicorp` takes effect.
- Missing configuration results in clear error messages, and headless bootstrap fails fast
  (`ImproperlyConfigured`) rather than starting half-configured.

## Troubleshooting

### Common Issues

#### Provider Not Found
```
Error: Provider 'unknown' not found in PROVIDER_CLASSES
```
**Solution**: Check that the provider is registered in `VaultProviderFactory.PROVIDER_CLASSES`

#### Configuration Missing
```
Error: HashiCorp Vault requires 'vault_url' configuration
```
**Solution**: Set the missing `GlobalConfiguration` key via the onboarding Vault step, or the
matching `STREAMTIME_GLOBAL_VAULT_*` env var (see Configuration above).

#### Permission Denied
```
Error: permission denied
```
**Solution**: Check that the authentication credentials have the necessary permissions in the external vault system

#### Connection Failed
```
Error: Failed to connect to external service
```
**Solution**: Verify network connectivity and service availability

### Debugging

#### Check Provider Configuration
```bash
# Dumps GlobalConfiguration vault_* keys (masked) and the resolved active provider
docker compose exec fleet-manager-backend python manage.py test_vault_config
```

#### Test Provider Connection / End-to-End Secret CRUD
```bash
# Exercises builtin, and vault if GlobalConfiguration has it configured
docker compose exec fleet-manager-backend python manage.py test_secrets
```

## Migration Guide

### Switching Providers

1. **Configure Vault** via the onboarding Vault step, or by setting `STREAMTIME_GLOBAL_VAULT_*`
   and restarting the backend (which reseeds `GlobalConfiguration`)
2. **Verify** with `python manage.py test_vault_config` and/or `GET .../secrets/providers/`
3. `SetupVaultView.post` calls `VaultProviderFactory.invalidate_cache()`, but `_provider_cache`
   is a plain in-process class dict — this only clears the cache in the single worker process
   that handled the config-change request. Under a single-worker, single-replica deployment
   (this chart's shipped default: `replicas: 1`, `UVICORN_WORKERS=1`) that happens to be the
   only process there is, so the switch does take effect immediately in practice. Under any
   multi-worker or multi-replica deployment, every *other* process keeps using its own cached
   provider (built from the config at the time it was first resolved) until that process
   restarts — there is no cross-process invalidation. **A full restart of all backend
   processes is the only way to guarantee an immediate, uniform switch across all of them.**

### Data Migration

When switching from builtin to external providers:
- Existing secrets in the database will remain
- New secrets will be stored in the external vault
- To migrate existing secrets, you'll need to:
  1. Export secrets from the database
  2. Create them using the new provider
  3. Update any references to use the new provider

## Performance Considerations

### Builtin Provider
- **Pros**: Fast access, no network latency
- **Cons**: Limited scalability, security concerns for sensitive data

### External Providers
- **Pros**: Better security, scalability, audit capabilities
- **Cons**: Network latency, external dependency

### Recommendations
- Use **builtin** for development and testing
- Use **external providers** for production environments
- Consider caching strategies for frequently accessed secrets

## Testing

### Test Structure

The secrets management system includes comprehensive unit tests organized by Django app:

```
fleet-manager-backend/
├── core/
│   ├── tests/
│   │   ├── __init__.py
│   │   ├── test_models.py          # Secret model tests
│   │   ├── test_serializers.py     # SecretSerializer tests
│   │   └── test_views.py           # SecretViewSet tests
│   ├── models.py
│   └── views.py
└── fleet_secrets_manager/
    ├── tests/
    │   ├── __init__.py
    │   ├── test_providers.py       # Vault provider tests
    │   ├── test_manager.py         # SecretsManager tests
    │   └── test_utils.py           # Test utilities
    ├── providers.py
    └── manager.py
```

### Running Tests

#### Using the Test Runner Script

The project includes a comprehensive test runner script that runs tests inside the Docker container:

```bash
# Run all tests
./scripts/run-tests.sh

# Run with verbose output
./scripts/run-tests.sh -v

# Run with coverage report
./scripts/run-tests.sh -c

# Run tests for specific app
./scripts/run-tests.sh -a core

# Run tests matching pattern
./scripts/run-tests.sh -t test_secrets

# Run only unit tests
./scripts/run-tests.sh -u

# Run only integration tests
./scripts/run-tests.sh -i

# Run with linting checks
./scripts/run-tests.sh -l

# Run migrations before tests
./scripts/run-tests.sh -m
```

#### Manual Docker Commands

You can also run tests manually using Docker commands:

```bash
# Run all tests
docker exec backend python manage.py test core.tests fleet_secrets_manager.tests

# Run tests for specific app
docker exec backend python manage.py test core.tests

# Run tests with verbose output
docker exec backend python manage.py test core.tests --verbosity=2

# Run tests with pattern matching
docker exec backend python manage.py test core.tests --pattern=test_secrets

# Run tests in parallel
docker exec backend python manage.py test core.tests --parallel
```

#### Coverage Reports

To generate coverage reports:

```bash
# Using the test runner script
./scripts/run-tests.sh -c

# Manually
docker exec backend coverage run --source='.' python manage.py test core.tests fleet_secrets_manager.tests
docker exec backend coverage report
docker exec backend coverage html

# Copy coverage report to host
docker cp backend:/app/htmlcov ./htmlcov
```

### Test Categories

#### Unit Tests
- **Model Tests** (`test_models.py`): Test Secret model validation, constraints, and methods
- **Serializer Tests** (`test_serializers.py`): Test SecretSerializer validation and serialization
- **Provider Tests** (`test_providers.py`): Test individual vault provider implementations
- **Manager Tests** (`test_manager.py`): Test SecretsManager integration logic

#### Integration Tests
- **View Tests** (`test_views.py`): Test API endpoints and request/response handling
- **End-to-End Tests**: Test complete workflows from API to vault storage

#### Test Utilities
- **Mock Providers**: Mock implementations for testing without external dependencies
- **Test Data**: Utilities for creating test organizations, users, and secrets
- **Base Test Classes**: Common setup and teardown logic

### Test Configuration

Tests use Django's test framework with the following configuration:

```python
# Test settings
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': ':memory:',
    }
}

CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
    }
}
```

### Mocking External Services

Tests use mocking to avoid dependencies on external services:

```python
from unittest.mock import patch, MagicMock

# Mock HashiCorp Vault
@patch('fleet_secrets_manager.providers.hvac.Client')
def test_vault_provider_create_secret(self, mock_hvac_client):
    mock_client = MagicMock()
    mock_client.secrets.kv.v2.create_or_update_secret.return_value = {
        'request_id': 'test-request-id'
    }
    mock_hvac_client.return_value = mock_client
    
    # Test implementation
```

### Test Data Management

Tests use Django's test database and fixtures:

```python
def setUp(self):
    """Set up test data."""
    self.user = User.objects.create_user(
        username='testuser',
        email='test@example.com',
        password='testpass123'
    )
    self.organization = Organization.objects.create(
        identifier="test-org",
        name="Test Organization",
        poc_email='test@test.com',
        poc_name='Test Admin'
    )
```

### Continuous Integration

For CI/CD pipelines, use the test runner script:

```yaml
# GitHub Actions example
- name: Run Tests
  run: |
    docker-compose up -d fleet-manager-backend
    ./scripts/run-tests.sh -c -v
```

### Debugging Tests

To debug failing tests:

```bash
# Run specific test with verbose output
docker exec backend python manage.py test core.tests.test_models.SecretModelTest.test_secret_creation_builtin --verbosity=2

# Run with debugger
docker exec -it backend bash
python manage.py test core.tests.test_models.SecretModelTest.test_secret_creation_builtin --verbosity=2 --debug-mode

# Check test database
docker exec backend python manage.py shell
>>> from core.models import Secret
>>> Secret.objects.all()
```

### Performance Testing

For performance testing of the secrets management system:

```bash
# Run tests with timing
docker exec backend python manage.py test core.tests --verbosity=2 --debug-mode

# Profile specific tests
docker exec backend python -m cProfile -o profile.stats manage.py test core.tests.test_views
```

## Future Enhancements

### Planned Features
- Secret versioning and history
- Secret rotation automation
- Audit logging improvements
- Bulk operations support
- Secret sharing between organizations

### Provider Roadmap
- Kubernetes Secrets provider
- Docker Secrets provider
- HashiCorp Vault Enterprise features
- Multi-cloud secret synchronization
