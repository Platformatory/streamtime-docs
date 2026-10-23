# Building and Deploying Streamtime Agent and Helm Chart

This document describes how to build and push the Streamtime Agent Docker image and Helm chart to the local OCI registry.

For a **customer-like** install of the **fleet-manager control-plane chart** on the local kind cluster (API / UI / Temporal worker images, in-cluster Postgres/Redis/MinIO/Temporal/Kong, local OCI charts), see **[KIND_FLEET_MANAGER_HELM.md](KIND_FLEET_MANAGER_HELM.md)**. That path is separate from the agent/operator push flow below.

## Naming Conventions

- **Agent Image**: `streamtime/streamtime-agent` (contains both worker and controller binaries)
- **Worker Helm Chart**: `streamtime/streamtime-helm` (OCI path: `oci://registry/streamtime/streamtime-helm`)
- **Operator Helm Chart**: `streamtime/streamtime-operator` (OCI path: `oci://registry/streamtime/streamtime-operator`)

## Prerequisites

- Docker and Docker Buildx
- Helm 3.x with OCI support enabled
- Access to the local registry (default: `localhost:5001`)

## Building the Agent Image

### Standard Build (with cache)

```bash
cd streamtime-agent
./scripts/build-image.sh
```

This will:
1. Build the Docker image for `linux/amd64` platform
2. Tag it as `streamtime/streamtime-agent:latest`
3. Push it to the registry at `localhost:5001`

### Build with Custom Tag

```bash
cd streamtime-agent
IMAGE_TAG="v1.0.0" ./scripts/build-image.sh
```

### Build Without Cache (for clean builds)

```bash
cd streamtime-agent
NO_CACHE=true ./scripts/build-image.sh
```

### Build for Different Platform

```bash
cd streamtime-agent
PLATFORM="linux/arm64" ./scripts/build-image.sh
```

### Build with Custom Registry

```bash
cd streamtime-agent
REGISTRY_URL="my-registry:5000" IMAGE_TAG="v1.0.0" ./scripts/build-image.sh
```

## Building and Pushing the Helm Charts

The Helm charts are automatically packaged and pushed when using the deploy script. To manually build and push:

### Package the Charts

```bash
# Package worker chart
cd charts/streamtime-agent
helm package .

# Package operator chart
cd ../streamtime-operator
helm package .
```

This creates `.tgz` files in the respective directories.

### Push to OCI Registry

```bash
# Enable OCI support (if not already enabled)
export HELM_EXPERIMENTAL_OCI=1

# Push worker chart to local registry
helm push streamtime-helm-0.1.0.tgz oci://localhost:5001/streamtime/streamtime-helm

# Push operator chart to local registry
helm push streamtime-operator-0.1.0.tgz oci://localhost:5001/streamtime/streamtime-operator
```

## Complete Build and Deploy

The `deploy-streamtime-agent.sh` script builds both the image and chart, then deploys them:

### Standard Deploy

```bash
./scripts/deploy-streamtime-agent.sh
```

This will:
1. Build the agent image (with timestamp-based tag, contains both worker and controller binaries)
2. Package and push both Helm charts to OCI registry:
   - `streamtime-agent` chart (worker)
   - `streamtime-operator` chart (controller)
3. Deploy/upgrade both Helm releases in the `streamtime-agent` namespace:
   - `streamtime-agent` release (worker deployment)
   - `streamtime-operator` release (controller deployment)

### Deploy with No Cache

```bash
NO_CACHE=true ./scripts/deploy-streamtime-agent.sh
```

### Deploy with Custom Image Tag

```bash
IMAGE_TAG="v1.0.0" ./scripts/deploy-streamtime-agent.sh
```

### Deploy with Custom Registry

```bash
REGISTRY_URL="my-registry:5000" ./scripts/deploy-streamtime-agent.sh
```

## Environment Variables

### Build Script (`streamtime-agent/scripts/build-image.sh`)

- `IMAGE_NAME`: Image name (default: `streamtime/streamtime-agent`)
- `IMAGE_TAG`: Image tag (default: `latest`)
- `REGISTRY_URL`: Registry URL (default: `localhost:5001`)
- `PLATFORM`: Build platform (default: `linux/amd64`)
- `NO_CACHE`: Build without cache (default: `false`)

### Deploy Script (`scripts/deploy-streamtime-agent.sh`)

- `IMAGE_REPOSITORY`: Image repository (default: `streamtime/streamtime-agent`)
- `IMAGE_TAG`: Image tag (default: timestamp)
- `REGISTRY_URL`: Registry URL (default: `localhost:5001`)
- `RELEASE_NAME`: Helm release name (default: `streamtime-agent`)
- `NAMESPACE`: Always `streamtime-agent` (cannot be overridden)
- `NO_CACHE`: Build without cache (default: `false`)
- `TARGETOS`: Target OS (default: `linux`)
- `TARGETARCH`: Target architecture (default: `amd64`)

## Registry Configuration

### Local Development (Kind Cluster)

For local development with a Kind cluster:
- Host registry: `localhost:5001`
- Internal registry (from within cluster): `registry:5000`

The deploy script automatically handles the mapping between host and internal registry URLs.

### Production Registry

For production, set `REGISTRY_URL` to your production registry:

```bash
REGISTRY_URL="registry.example.com" ./scripts/deploy-streamtime-agent.sh
```

## Verifying Builds

### Check Image in Registry

```bash
# List images in registry
curl http://localhost:5001/v2/_catalog

# List tags for streamtime/streamtime-agent
curl http://localhost:5001/v2/streamtime/streamtime-agent/tags/list
```

### Check Helm Charts in Registry

```bash
# List worker chart versions
helm show chart oci://localhost:5001/streamtime/streamtime-helm

# List operator chart versions
helm show chart oci://localhost:5001/streamtime/streamtime-operator

# Show all charts in registry
curl http://localhost:5001/v2/_catalog | jq
```

## Troubleshooting

### OCI Support Not Enabled

If you see errors about OCI support:

```bash
export HELM_EXPERIMENTAL_OCI=1
```

### Registry Connection Issues

For local insecure registries, ensure Docker is configured to allow insecure registries:

```json
{
  "insecure-registries": ["localhost:5001"]
}
```

### Image Pull Errors in Kubernetes

If Kubernetes cannot pull images:
1. Verify the registry is accessible from the cluster
2. Check image pull secrets if using authenticated registry
3. For Kind clusters, ensure the registry is connected to the Kind network

## Examples

### Full Clean Build and Deploy

```bash
# Build image without cache
cd streamtime-agent
NO_CACHE=true IMAGE_TAG="v1.0.0" ./scripts/build-image.sh

# Deploy with the new image
cd ..
IMAGE_TAG="v1.0.0" ./scripts/deploy-streamtime-agent.sh
```

### Build Multiple Tags

```bash
cd streamtime-agent
for tag in v1.0.0 latest; do
  IMAGE_TAG="$tag" ./scripts/build-image.sh
done
```

### Build for Multiple Platforms

```bash
cd streamtime-agent
for arch in amd64 arm64; do
  PLATFORM="linux/$arch" IMAGE_TAG="v1.0.0" ./scripts/build-image.sh
done
```

