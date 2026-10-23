# Package Catalog Quick Start

## What Was Built

### Backend (Django)
✅ **Package Model** - OCI-compatible with embedded template values
✅ **PackageService** - SemVer filtering, env-based auth, version queries
✅ **REST API** - Full CRUD + versions query + latest + sync endpoints
✅ **Serializers** - PackageSerializer and PackageListSerializer
✅ **Auto-Import** - Loads package_inventory.yaml on first startup

### Temporal
✅ **PackageSyncWorkflow** - Discovers and catalogs packages from registries
✅ **Registry Activities** - OCI registry operations (test, list tags, get manifest)
✅ **Backend Activities** - create_or_update_package added
✅ **SDK Methods** - Package CRUD methods added

### Frontend
✅ **PackageCatalogPage** - Table view with filters, details dialog, sync button
✅ **Route Added** - /packages in navigation

### Configuration
✅ **Environment Variables** - Added to docker-compose.yaml (backend & orchestrator)
✅ **Inventory File** - data/package_inventory.yaml with default packages
✅ **Documentation** - Complete PACKAGE_CATALOG.md guide

## Test It Now

### Step 1: Restart Backend (pick up new models)
```bash
# Backend will auto-import package_inventory.yaml on first startup
docker compose restart fleet-manager-backend
# Or if running locally: restart your backend process
```

### Step 2: Verify Packages Were Imported
```bash
export TOKEN="your-token-here"
curl -s "http://localhost:7999/organizations/root/packages/" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

### Step 3: Query Versions
```bash
# First get a package ID
PACKAGE_ID=$(curl -s "http://localhost:7999/organizations/root/packages/?repository=streamtime/streamtime-agent" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.[0].id')

# Get all versions
curl -s "http://localhost:7999/organizations/root/packages/$PACKAGE_ID/versions/" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

### Step 4: Track Repository and Sync (if GHCR_TOKEN is set)
```bash
export GHCR_TOKEN="ghp_xxxxxxxxxxxx"

# Track a repository
curl -s -X POST "http://localhost:7999/organizations/root/tracked-repositories/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "repo_type": "oci",
    "registry_url": "ghcr.io",
    "repository": "streamtime/streamtime-agent"
  }' | python3 -m json.tool

# Get tracked repo ID and sync
TRACKED_REPO_ID=$(curl -s "http://localhost:7999/organizations/root/tracked-repositories/" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.[0].id')

curl -s -X POST "http://localhost:7999/organizations/root/tracked-repositories/$TRACKED_REPO_ID/sync/" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

### Step 5: Access Frontend
1. Login to Fleet Manager console
2. Navigate to **Package Catalog** (admin menu)
3. View packages, apply filters
4. Click info icon for details
5. Click **Sync Packages** button

## API Endpoints Quick Reference

### Packages
```
GET    /organizations/{org_id}/packages/                                    # List all
GET    /organizations/{org_id}/packages/?repository=X&latest=true          # Latest version
GET    /organizations/{org_id}/packages/{package_id}/versions/            # All versions of a package's repository
GET    /organizations/{org_id}/packages/{id}/                              # Details
PATCH  /organizations/{org_id}/packages/{id}/                              # Update
```

### Tracked Repositories
```
GET    /organizations/{org_id}/tracked-repositories/                       # List tracked repos
POST   /organizations/{org_id}/tracked-repositories/                       # Track a new repository
GET    /organizations/{org_id}/tracked-repositories/{id}/                  # Get tracked repo details
DELETE /organizations/{org_id}/tracked-repositories/{id}/                  # Stop tracking
POST   /organizations/{org_id}/tracked-repositories/{id}/sync/             # Sync packages
GET    /organizations/{org_id}/tracked-repositories/{id}/template/         # Get template values
POST   /organizations/{org_id}/tracked-repositories/{id}/set-template/     # Set template values
```

## What's Different from Before

**Simplified**:
- ❌ No separate Registry model (registry info inline in each package)
- ❌ No SoftwareTemplateValues model (templates on TrackedRepository)
- ❌ No RegistrySync model (tracked by Temporal workflows)
- ✅ Single Package model with OCI structure
- ✅ TrackedRepository model for managing tracked repos (OCI and Helm)
- ✅ Environment variable authentication (no secrets in DB)
- ✅ Template values stored on TrackedRepository (shared across versions)

**Better**:
- ✅ OCI Distribution Spec compliant
- ✅ SemVer support with constraints
- ✅ Query all versions across registries
- ✅ Admin annotations per version
- ✅ Simpler data model

