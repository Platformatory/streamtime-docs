# Package Catalog API Examples

This document provides interactive examples for common package catalog operations.

## Prerequisites

All examples require authentication. Get a token using:
```bash
TOKEN=$(./scripts/get-root-token.sh 2>/dev/null | sed -n 's/.*Bearer \([^"]*\).*/\1/p' | head -1)
```

Base URL: `https://api.streamtime.local:8443`

## Example 1: List All Versions with SemVer Filter

List all versions of a tracked repository package, filtered by semantic version constraint and excluding pre-releases.

**Request:**
```bash
REPO="streamtime/streamtime-agent"
ENCODED_REPO=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$REPO', safe=''))")

curl -k -s -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/tracked-repositories/$ENCODED_REPO/versions/?semver_constraint=%3E%3D0.1.0&exclude_prerelease=true"
```

**Endpoint:** `GET /organizations/{org}/tracked-repositories/{repository}/versions/`

**Query Parameters:**
- `semver_constraint`: SemVer constraint (e.g., `>=0.1.0`, `^2.0.0`) - URL encode special characters (`>=` becomes `%3E%3D`)
- `exclude_prerelease`: Exclude pre-release versions (default: `false`)
- `support_status`: Filter by support status (optional, default: ANY/all) - values: `active`, `supported`, `deprecated`, `unsupported`
- `limit`: Maximum results (default: `50`)

**Response:**
```json
[
  {
    "id": "ac1c5c05-0325-4e96-aacf-c73528e423a3",
    "repository": "streamtime/streamtime-agent",
    "tag": "0.1.1765206477",
    "registry_url": "registry:5000",
    "support_status": "active",
    "artifact_type": "oci",
    "published_at": null,
    "created_at": "2025-12-08T12:33:28.749805Z"
  },
  ...
]
```

**Example Output:**
```
Tag: 0.1.1765206477 | Support Status: active | Published: N/A
Tag: 0.1.1765191919 | Support Status: active | Published: N/A
Tag: 0.1.1765191892 | Support Status: active | Published: N/A
```

---

## Example 2: Get Latest Version by SemVer

Get the latest semantic version of a package (support_status=ANY, meaning all statuses are considered).

**Request:**
```bash
REPO="streamtime/streamtime-agent"

curl -k -s -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/packages/?repository=$REPO&latest=true&semver_only=true"
```

**Endpoint:** `GET /organizations/{org}/packages/`

**Query Parameters:**
- `repository`: Repository path (required when `latest=true`)
- `latest`: If `true`, return only the latest version (default: `false`)
- `semver_only`: When `latest=true`, only consider semantic versions (default: `true`)
- `support_status`: Filter by support status (optional, default: ANY/all)

**Response:**
```json
[
  {
    "id": "ac1c5c05-0325-4e96-aacf-c73528e423a3",
    "repository": "streamtime/streamtime-agent",
    "tag": "0.1.1765206477",
    "registry_url": "registry:5000",
    "support_status": "active",
    "artifact_type": "oci",
    "published_at": null,
    "created_at": "2025-12-08T12:33:28.749805Z"
  }
]
```

**Example Output:**
```
Tag: 0.1.1765206477
Support Status: active
Published: N/A
Registry: registry:5000
Repository: streamtime/streamtime-agent
```

---

## Example 3: Get Default Helm Values (Template)

Get template values (default Helm values) for a tracked repository. Template values are stored per environment and apply to all versions of the tracked repository.

**Request:**
```bash
REPO="streamtime/streamtime-agent"
ENCODED_REPO=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$REPO', safe=''))")

curl -k -s -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/tracked-repositories/$ENCODED_REPO/template/?environment=default"
```

**Endpoint:** `GET /organizations/{org}/tracked-repositories/{repository}/template/`

**Query Parameters:**
- `environment`: Environment identifier (default: `default`)

**Response:**
```json
{
  "tracked_repository_id": "6b839459-bca3-44fd-810b-667d2510f4a5",
  "repository": "streamtime/streamtime-agent",
  "environment": "default",
  "template_values": {}
}
```

**Note:** Template values are stored on `TrackedRepository`, not individual packages. This allows templates to be shared across all versions. To set template values, use:

```bash
curl -k -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "environment": "prod",
    "values": {
      "replicas": 3,
      "resources": {
        "limits": {"cpu": "2000m", "memory": "4Gi"}
      }
    }
  }' \
  "https://api.streamtime.local:8443/organizations/root/tracked-repositories/$ENCODED_REPO/set-template/"
```

---

## Bonus Example: List Versions with Support Status Filter

List versions filtered by support status.

**Request:**
```bash
REPO="streamtime/streamtime-agent"
ENCODED_REPO=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$REPO', safe=''))")

curl -k -s -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/tracked-repositories/$ENCODED_REPO/versions/?support_status=active&limit=5"
```

**Query Parameters:**
- `support_status`: Filter by support status - values: `active`, `supported`, `deprecated`, `unsupported`
- `limit`: Maximum results (default: `50`)

**Response:**
```json
[
  {
    "id": "ac1c5c05-0325-4e96-aacf-c73528e423a3",
    "repository": "streamtime/streamtime-agent",
    "tag": "0.1.1765206477",
    "support_status": "active",
    ...
  },
  ...
]
```

**Example Output:**
```
Tag: 0.1.1765206477 | Support Status: active
Tag: 0.1.1765191919 | Support Status: active
Tag: 0.1.1765191892 | Support Status: active
Tag: test-sync-123 | Support Status: active
Tag: v1.0.0-test | Support Status: active
```

---

## URL Encoding Notes

When using repository names with slashes in URLs, they must be URL-encoded:

- `streamtime/streamtime-agent` → `streamtime%2Fstreamtime-agent`
- `prometheus-community/charts/kube-prometheus-stack` → `prometheus-community%2Fcharts%2Fkube-prometheus-stack`

**Python encoding:**
```python
import urllib.parse
encoded = urllib.parse.quote("streamtime/streamtime-agent", safe='')
# Result: streamtime%2Fstreamtime-agent
```

**Bash encoding:**
```bash
ENCODED_REPO=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$REPO', safe=''))")
```

---

## Support Status Values

- `active`: Package is actively maintained and recommended for use
- `supported`: Package is supported but may not be actively developed
- `deprecated`: Package is deprecated and should not be used for new deployments
- `unsupported`: Package is no longer supported

When `support_status` is not specified in query parameters, all statuses are returned (ANY).

---

## SemVer Constraint Examples

- `>=1.0.0`: All versions >= 1.0.0
- `^2.0.0`: Compatible versions (>=2.0.0, <3.0.0)
- `~1.2.0`: Patch versions only (>=1.2.0, <1.3.0)
- `>=1.0.0 <2.0.0`: Range constraint

**URL Encoding:**
- `>=` → `%3E%3D`
- `<` → `%3C`
- `^` → `%5E`
- `~` → `%7E`

---

## Related Documentation

- [Package Catalog Documentation](./PACKAGE_CATALOG.md) - Full API reference
- [Package Catalog Quickstart](./PACKAGE_CATALOG_QUICKSTART.md) - Quick start guide
