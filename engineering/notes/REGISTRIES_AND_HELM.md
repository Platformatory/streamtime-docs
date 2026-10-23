## Registries and Helm Repositories

### Supported OCI Registries (registry = OCI only)
- `ghcr.io`
- `registry-1.docker.io` (Docker Hub)
- `quay.io`
- `registry:5000` (local dev)
- Auth behavior: uses existing env-based auth helpers (GHCR, Docker Hub, Quay). Local registry is anonymous by default.

### Helm Repositories (no auth)
- Defined via `HelmRepository` (name, base_url, optional org).
- Synced by fetching `index.yaml` from `base_url` (HTTPS assumed).

### TrackedRepository
- `repo_type`: `oci` or `helm`
- OCI: `registry_url` (host), `repository` (path)
- Helm: `helm_repository` (FK), `repository` (chart name)
- `organization`: optional for org scoping
- Timestamps and last_synced_at

### Sync Behavior
- OCI: uses registry auth if available; only supported registries allowed.
- Helm: fetches index.yaml; no auth; syncs all chart versions.

### Frontend Track Flow
- OCI: pick supported registry + repo path.
- Helm: create/select Helm repo (name + base URL) + chart name.

### Preload
- Helm preload uses `helm_repos.json` to seed HelmRepository + tracked entries; no auth.
