# Package Catalog Management

## Overview

The Fleet Manager Package Catalog provides a simplified system for tracking and managing OCI/container registry packages. Administrators can:

- **Track Packages**: Monitor container images, Helm charts, and OCI artifacts across registries
- **Query Versions**: Find all versions of a package with SemVer filtering
- **Manage Templates**: Define environment-specific configuration templates (default, dev, prod)
- **Auto-Sync**: Automatically discover and catalog packages from registries
- **Annotate Versions**: Mark versions as supported, deprecated, latest, or preview

## Architecture

### OCI-Compatible Design

The Package model follows the **OCI Distribution Specification** for maximum compatibility with container registries:

- Uses OCI terminology: `repository`, `tag`, `digest`, `manifest`
- Stores complete OCI manifest and config data
- Compatible with Docker Hub, GHCR, Quay.io, Harbor, and any OCI-compliant registry

### Environment Variable Authentication

Authentication credentials are stored in **environment variables** (not database):

```bash
GHCR_TOKEN=ghp_xxxxxxxxxxxx              # GitHub Container Registry
DOCKER_HUB_USERNAME=your-username         # Docker Hub
DOCKER_HUB_PASSWORD=your-password
QUAY_IO_TOKEN=your-token                  # Quay.io
HARBOR_USERNAME=admin                     # Harbor
HARBOR_PASSWORD=Harbor12345
```

Benefits:
- ✅ Credentials never stored in database
- ✅ Easy rotation (just restart service)
- ✅ Standard 12-factor app pattern
- ✅ Works with orchestration secrets (K8s, Docker Compose)

## Features

### TrackedRepository Model

TrackedRepository represents a repository being tracked for package synchronization. It can be either:
- **OCI**: Container images from OCI registries (ghcr.io, Docker Hub, Quay.io, etc.)
- **Helm**: Helm charts from Helm repositories

**Key Features**:
- Templates are stored at the TrackedRepository level (shared across all package versions)
- Sync operations are performed per TrackedRepository
- Each TrackedRepository can track one repository/chart

**Example**:
```python
# OCI TrackedRepository
TrackedRepository(
  repo_type="oci",
  registry_url="ghcr.io",
  repository="streamtime/streamtime-agent",
  template_values={"prod": {"replicas": 3}}
)

# Helm TrackedRepository
TrackedRepository(
  repo_type="helm",
  helm_repository=HelmRepository(name="confluentinc", base_url="https://packages.confluent.io/helm"),
  repository="confluent-for-kubernetes",
  template_values={"prod": {"replicas": 3}}
)
```

### Package Model

Each package entry represents a specific version (tag) of a container image/artifact:

```python
Package:
  # OCI Identity
  registry_url: "ghcr.io"
  repository: "streamtime/streamtime-agent"
  tag: "v1.0.0"
  digest: "sha256:abc123..."
  
  # OCI Manifest Data
  manifest: {...}  # Full OCI manifest
  config: {...}    # Architecture, OS, labels
  artifact_type: "container_image"
  size: 52428800  # Bytes
  
  # Admin Annotations
  support_status: "supported"
  support_notes: "Production-ready version"
  
  # Link to TrackedRepository
  tracked_repository: FK (nullable)  # Links to TrackedRepository
  
  # Organization Scope
  organization: null  # null = global (packages are global)
```

### Supported Registries

- **GitHub Container Registry** (`ghcr.io`)
- **Docker Hub** (`registry-1.docker.io`)
- **Quay.io** (`quay.io`)
- **Kind Local Registry** (`registry:5000`)
- **Harbor** (any Harbor instance)
- **Generic OCI Registries**

### Support Status Values

- **supported**: Production-ready, actively maintained
- **latest**: Latest version recommended for new deployments
- **deprecated**: Still works but migration recommended
- **preview**: Beta/preview version, not for production
- **active**: Default status for newly synced packages

### TrackedRepository Model

TrackedRepository represents a repository being tracked (either OCI or Helm):

```python
TrackedRepository:
  id: UUID (PK)
  repo_type: str                    # "oci" or "helm"
  registry_url: str (nullable)       # For OCI: e.g., "ghcr.io"
  repository: str                   # Repository path or chart name
  helm_repository: FK (nullable)    # For Helm: link to HelmRepository
  template_values: JSONField        # {"default": {...}, "prod": {...}}
  created_at: DateTime
  updated_at: DateTime
  last_synced_at: DateTime (nullable)
```

### Template Values

Template values are stored on **TrackedRepository** (not individual packages) as environment-keyed JSON. This allows templates to be shared across all versions of a tracked repository:

```json
{
  "default": {
    "replicas": 1,
    "resources": {
      "limits": {"cpu": "500m", "memory": "512Mi"}
    }
  },
  "prod": {
    "replicas": 3,
    "resources": {
      "limits": {"cpu": "2000m", "memory": "4Gi"}
    }
  },
  "dev": {
    "replicas": 1,
    "resources": {
      "limits": {"cpu": "200m", "memory": "256Mi"}
    }
  }
}
```

## API Endpoints

### Package CRUD

```
GET    /organizations/{org_id}/packages/                 # List/query packages
POST   /organizations/{org_id}/packages/                 # Create package
GET    /organizations/{org_id}/packages/{id}/            # Get package details
PATCH  /organizations/{org_id}/packages/{id}/            # Update package (admin annotations)
DELETE /organizations/{org_id}/packages/{id}/            # Delete package
```

### Package Queries

```
GET    /organizations/{org_id}/packages/{package_id}/versions/       # Get all versions of a package's repository
GET    /organizations/{org_id}/packages/?latest=true                  # Get latest version (with repository param)
```

### Tracked Repository Management

```
GET    /organizations/{org_id}/tracked-repositories/                  # List tracked repositories
POST   /organizations/{org_id}/tracked-repositories/                  # Track a new repository
GET    /organizations/{org_id}/tracked-repositories/{id}/             # Get tracked repository details
DELETE /organizations/{org_id}/tracked-repositories/{id}/             # Stop tracking a repository
POST   /organizations/{org_id}/tracked-repositories/{id}/sync/        # Sync packages for this tracked repository
GET    /organizations/{org_id}/tracked-repositories/{id}/template/    # Get template values for environment
POST   /organizations/{org_id}/tracked-repositories/{id}/set-template/ # Set template values for environment
```

## Query Parameters

### List Packages (`GET /organizations/{org_id}/packages/`)

- `repository`: Filter by repository path (partial match, required when `latest=true`)
- `registry_url`: Filter by registry URL
- `tag`: Filter by exact tag
- `support_status`: Filter by support status
- `artifact_type`: Filter by artifact type
- `latest`: If true and repository is provided, return only the latest version (default: false)
- `semver_only`: When `latest=true`, only consider semantic versions (default: true)

### Query Versions (`GET /organizations/{org_id}/packages/{package_id}/versions/`)

Get all versions of a package's repository. The package ID is used to identify the repository.

- `registry_url`: Filter by specific registry (optional)
- `support_status`: Filter by support status (optional)
- `semver_constraint`: SemVer constraint (optional) - e.g., `>=1.0.0`, `^2.0.0`, `~1.2.0`
- `exclude_prerelease`: Exclude pre-release versions (default: false)
- `limit`: Max results (default: 50)


## Usage Examples

### 1. List All Packages

```bash
curl "http://localhost:7999/organizations/root/packages/" | jq
```

### 2. Query Versions of a Package

```bash
# First, get a package ID
PACKAGE_ID=$(curl -s "http://localhost:7999/organizations/root/packages/?repository=streamtime/streamtime-agent" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.[0].id')

# Get all versions of that package's repository
curl "http://localhost:7999/organizations/root/packages/$PACKAGE_ID/versions/" \
  -H "Authorization: Bearer $TOKEN" | jq

# Only versions >= 1.0.0
curl "http://localhost:7999/organizations/root/packages/$PACKAGE_ID/versions/?semver_constraint=>=1.0.0" \
  -H "Authorization: Bearer $TOKEN" | jq

# Exclude pre-releases
curl "http://localhost:7999/organizations/root/packages/$PACKAGE_ID/versions/?exclude_prerelease=true" \
  -H "Authorization: Bearer $TOKEN" | jq
```

### 3. Get Latest Version

```bash
# Get latest version using query params
curl "http://localhost:7999/organizations/root/packages/?repository=streamtime/streamtime-agent&latest=true" | jq

# Get latest semantic version only
curl "http://localhost:7999/organizations/root/packages/?repository=streamtime/streamtime-agent&latest=true&semver_only=true" | jq

# Get latest version from specific registry
curl "http://localhost:7999/organizations/root/packages/?repository=streamtime/streamtime-agent&registry_url=ghcr.io&latest=true" | jq
```

### 4. Track a Repository and Sync

```bash
# First, track a repository (OCI)
curl -X POST "http://localhost:7999/organizations/root/tracked-repositories/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "repo_type": "oci",
    "registry_url": "ghcr.io",
    "repository": "streamtime/streamtime-agent"
  }' | jq

# Get the tracked repository ID
TRACKED_REPO_ID=$(curl -s "http://localhost:7999/organizations/root/tracked-repositories/" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.[0].id')

# Sync packages for this tracked repository
curl -X POST "http://localhost:7999/organizations/root/tracked-repositories/$TRACKED_REPO_ID/sync/" \
  -H "Authorization: Bearer $TOKEN" | jq
```

### 5. Update Admin Status

```bash
curl -X PATCH "http://localhost:7999/organizations/root/packages/{id}/" \
  -H "Content-Type: application/json" \
  -d '{
    "admin_status": "latest",
    "admin_notes": "Recommended for production deployments"
  }' | jq
```

### 6. Set Template Values (on TrackedRepository)

```bash
# Get tracked repository ID
TRACKED_REPO_ID=$(curl -s "http://localhost:7999/organizations/root/tracked-repositories/" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.[0].id')

# Set template values for a tracked repository
curl -X POST "http://localhost:7999/organizations/root/tracked-repositories/$TRACKED_REPO_ID/set-template/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "environment": "prod",
    "values": {
      "replicas": 3,
      "resources": {
        "limits": {"cpu": "2000m", "memory": "4Gi"}
      }
    }
  }' | jq
```

### 7. Get Template Values (from TrackedRepository)

```bash
# Get tracked repository ID
TRACKED_REPO_ID=$(curl -s "http://localhost:7999/organizations/root/tracked-repositories/" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.[0].id')

# Get template values for a specific environment
curl "http://localhost:7999/organizations/root/tracked-repositories/$TRACKED_REPO_ID/template/?environment=prod" \
  -H "Authorization: Bearer $TOKEN" | jq
```

## Package Inventory File

Define packages to track in `/fleet-manager-backend/data/package_inventory.yaml`:

```yaml
packages:
  - repository: "streamtime/streamtime-agent"
    registry_url: "ghcr.io"
    tags_to_track: ["latest", "v*"]  # Track latest and all semver tags
    artifact_type: "container_image"
    admin_status: "supported"
    template_values:
      default:
        replicas: 1
        resources:
          limits:
            cpu: "500m"
            memory: "512Mi"
      prod:
        replicas: 3
        resources:
          limits:
            cpu: "2000m"
            memory: "4Gi"
  
  - repository: "streamtime/streamtime-operator"
    registry_url: "ghcr.io"
    tags_to_track: ["latest", "v*"]
    artifact_type: "container_image"
    admin_status: "supported"
```

### Auto-Import on Startup

The inventory file is **automatically imported** on first backend startup if the package catalog is empty.

### Manual Import

```bash
# Import from default location
python manage.py import_packages

# Import from custom file
python manage.py import_packages --file=/path/to/inventory.yaml

# Import and trigger sync
python manage.py import_packages --sync

# Force reimport
python manage.py import_packages --force
```

## Temporal Workflows

### PackageSyncWorkflow

Synchronizes packages from OCI registries.

**Input**:
```json
{
  "registry_url": "ghcr.io",
  "repositories": ["streamtime/streamtime-agent", "streamtime/streamtime-operator"],
  "organization": "root",
  "protocol": "https",
  "auth_config": {"auth_type": "bearer", "token": "..."}
}
```

**Workflow ID Pattern**:
- For TrackedRepository sync: `/organizations/{org}/tracked-repositories/{id}/sync/command/PackageSyncWorkflow`
- For legacy sync: `/organizations/{org}/packages/sync-{registry}/command/PackageSyncWorkflow`

**Output**:
```json
{
  "success": true,
  "repositories_synced": ["streamtime/streamtime-agent", "streamtime/streamtime-operator"],
  "packages_discovered": 50,
  "packages_added": 10,
  "packages_updated": 5,
  "errors": []
}
```

**Process**:
1. Get auth credentials from environment variables
2. Test registry connection
3. List tags for each repository
4. Fetch OCI manifest for each tag
5. Create/update package entries
6. Return statistics

### Registry Activities

- `test_registry_connection`: Verify registry is accessible
- `discover_repositories`: List repositories in registry (not used with explicit repository list)
- `list_repository_tags`: List tags for a repository
- `get_manifest`: Fetch OCI manifest for a tag

## Frontend UI

### Package Catalog Page

Navigate to **Package Catalog** in the main menu.

**Features**:
- **Table View**: List all packages with filters
- **Filters**: Repository, registry, status, type
- **Details Dialog**: View manifest, config, digest
- **Track Package**: Add new OCI or Helm repositories to track
- **Manage Helm Repos**: CRUD operations for Helm repositories
- **Sync Button**: Sync packages for tracked repositories

**Accessing**:
1. Login to Fleet Manager console
2. Navigate to **Package Catalog** (in admin menu)
3. Use filters to find packages
4. Click info icon to view details
5. Click **Sync Packages** to trigger discovery

## Configuration

### Environment Variables

Set in `.env` file or shell:

```bash
# GitHub Container Registry
export GHCR_TOKEN="ghp_xxxxxxxxxxxx"

# Docker Hub
export DOCKER_HUB_USERNAME="your-username"
export DOCKER_HUB_PASSWORD="your-password"

# Quay.io
export QUAY_IO_TOKEN="your-token"
```

### Docker Compose

Environment variables are automatically passed to backend and orchestrator services in `docker-compose.yaml`.

### Package Inventory

Edit `fleet-manager-backend/data/package_inventory.yaml` to add packages to track.

## Database Schema

```python
Package:
  id: UUID (PK)
  registry_url: str                    # e.g., "ghcr.io"
  repository: str (indexed)            # e.g., "streamtime/streamtime-agent"
  tag: str (indexed)                   # e.g., "v1.0.0", "latest"
  digest: str (indexed)                # e.g., "sha256:abc123..."
  manifest: JSONField                  # Full OCI manifest
  config: JSONField                    # OCI config (arch, OS, labels)
  artifact_type: str (indexed)         # container_image, helm_chart, oci_artifact
  size: BigIntegerField                # Total size in bytes
  published_at: DateTime               # When published to registry
  support_status: str (indexed)        # supported, deprecated, latest, preview, active
  support_notes: TextField             # Admin comments
  tracked_repository: FK (nullable)    # Link to TrackedRepository
  created_at: DateTime
  updated_at: DateTime
  
  unique_together: (registry_url, repository, tag)
  indexes: 
    - (registry_url, repository)
    - (published_at DESC)
    - (support_status)
```

```python
TrackedRepository:
  id: UUID (PK)
  repo_type: str                       # "oci" or "helm"
  registry_url: str (nullable)          # For OCI registries
  repository: str                      # Repository path or chart name
  helm_repository: FK (nullable)       # For Helm repositories
  template_values: JSONField           # {"default": {...}, "prod": {...}}
  created_at: DateTime
  updated_at: DateTime
  last_synced_at: DateTime (nullable)
  
  indexes:
    - (repo_type, registry_url, repository)
    - (repo_type, helm_repository, repository)
```

## SemVer Support

The system uses Python's `packaging` library for semantic version comparison:

- **Constraints**: `>=1.0.0`, `^2.0.0`, `~1.2.0`, `<3.0.0`
- **Sorting**: Versions are sorted using SemVer rules
- **Filtering**: Pre-release versions can be excluded
- **Latest Detection**: Automatically finds latest semantic version

## Integration with Bootstrap

Bootstrap workflows can query the package catalog to determine which versions to deploy:

```python
# Get latest supported version
latest_agent = await workflow.execute_activity(
    BackendActivities.get_latest_package,
    {
        "repository": "streamtime/streamtime-agent",
        "admin_status": "supported",
        "organization": org_id
    },
    ...
)

# Get template values for environment
template_values = latest_agent['template_values'].get('production', {})

# Use in chart installation
charts.append(ChartInstallConfig(
    release="streamtime-agent",
    chart_name=f"{latest_agent['registry_url']}/{latest_agent['repository']}",
    chart_version=latest_agent['tag'],
    values=template_values
))
```

## Troubleshooting

### No Packages Showing

1. Check if inventory file exists: `ls -la fleet-manager-backend/data/package_inventory.yaml`
2. Check backend logs for auto-import errors
3. Manually import: `python manage.py import_packages`
4. Trigger sync: `python manage.py import_packages --sync`

### Sync Failures

1. Check environment variables are set: `echo $GHCR_TOKEN`
2. Verify credentials are valid
3. Check Temporal workflow logs: `http://localhost:8080`
4. Check backend logs: `docker compose logs fleet-manager-backend`

### Connection Errors

1. Verify registry URL is correct
2. Check network connectivity
3. For private registries, ensure credentials are set
4. For local Kind registry, ensure it's running: `docker ps | grep registry`

## Migration from Old Models

The new Package model replaces:
- **Registry** model (registry info now inline in each package)
- **SoftwareCatalog** model (renamed to Package with OCI structure)
- **SoftwareTemplateValues** model (embedded in Package.template_values)
- **RegistrySync** model (sync tracked via Temporal workflows)

No data migration needed - you'll start with a clean slate.

## Next Steps

1. **Set Environment Variables**: Configure `GHCR_TOKEN` and other registry credentials
2. **Start Backend**: Backend will auto-import packages from inventory file
3. **Trigger Sync**: Use UI or API to sync packages
4. **Browse Catalog**: View packages in the Package Catalog page
5. **Set Templates**: Define environment-specific configurations
6. **Annotate Versions**: Mark supported/deprecated versions

## Support

For issues:
- Backend logs: `docker compose logs fleet-manager-backend`
- Temporal UI: `http://localhost:8080`
- API docs: `http://localhost:7999/swagger/`

