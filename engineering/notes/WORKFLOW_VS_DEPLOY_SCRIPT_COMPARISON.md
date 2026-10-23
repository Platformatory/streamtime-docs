# Workflow vs Deploy Script Comparison

This document compares the `UpdateAgentWorkflow` (Go workflow) with the `deploy-streamtime-agent.sh` script to identify differences and ensure parity.

## Overview

- **Deploy Script**: `scripts/deploy-streamtime-agent.sh` - Bash script that directly deploys the agent using Helm CLI
- **Workflow**: `streamtime-agent/internal/workflows/update_agent.go` - Temporal workflow that orchestrates agent updates

## Key Differences

### 1. Registry URL Handling

**Deploy Script** (lines 98-109):
- Detects if `REGISTRY_URL` contains `localhost`
- For localhost registries, converts to `registry:5000` (internal kind network)
- Uses `FULL_IMAGE_REPOSITORY="${KIND_REGISTRY_URL}/${IMAGE_REPOSITORY}"`

**Workflow** (lines 48-52, 145-172):
- Defaults to `registry:5000` if not provided
- Can detect registry URL from existing Helm values
- Uses `input.RegistryURL` directly without localhost conversion
- **MISSING**: Does not convert `localhost:5001` → `registry:5000` for kind clusters

**Recommendation**: Workflow should handle localhost → registry conversion like the script does.

### 2. Image Tag Resolution

**Deploy Script** (lines 22-58):
- If `IMAGE_TAG` not provided, queries registry API: `GET /v2/{image_name}/tags/list`
- Filters tags using SemVer pattern: `^[0-9]+\.[0-9]+\.[0-9]+$`
- Sorts using `sort -V -r` (SemVer-aware sorting)
- Falls back to alphabetical sort if no SemVer tags found

**Workflow** (lines 250-266):
- Uses `GetLatestImageTag` activity
- Activity queries registry API: `GET /v2/{image_name}/tags/list`
- Uses `github.com/Masterminds/semver/v3` for SemVer parsing and sorting
- Falls back to alphabetical sort if no SemVer tags found
- **PARITY**: ✅ Both use SemVer-aware sorting

### 3. Chart Version Resolution

**Deploy Script** (lines 60-68, 119-164):
- If `CHART_VERSION` not provided:
  - For HTTP registries (localhost): Queries registry API for chart tags
  - Filters using SemVer pattern: `^[0-9]+\.[0-9]+\.[0-9]+$`
  - Sorts using `sort -V -r`
  - Falls back to alphabetical sort
- For HTTPS registries: Uses `helm show chart` command
- If chart not found in registry, falls back to local chart path

**Workflow** (lines 268-284):
- Uses `GetLatestChartVersion` activity
- Activity queries OCI registry for chart versions
- Uses SemVer parsing for sorting
- **PARITY**: ✅ Both query registry for latest chart version

### 4. Chart Source Selection

**Deploy Script** (lines 111-224):
- Checks if chart exists in OCI registry
- For HTTP registries: Downloads chart manually via registry API (Helm OCI HTTP workaround)
- Falls back to local chart path if not found in registry
- Uses `CHART_SOURCE` variable (either OCI ref or local path)

**Workflow** (lines 86-92):
- Always uses OCI chart reference: `oci://{registry_url}/streamtime/streamtime-helm`
- Does not fall back to local chart
- **DIFFERENCE**: Workflow assumes chart is always in registry, script has fallback

### 5. Helm Values Construction

**Deploy Script** (lines 230-249):
- Uses `helm upgrade --install` with `--set` flags for each value:
  - `image.tag="${IMAGE_TAG}"`
  - `image.repository="${FULL_IMAGE_REPOSITORY}"`
  - `image.pullPolicy=Always`
  - `streamtime.orchestrator.*` (address, namespace, serverName, taskQueue, apiKey, tls.*)
  - `streamtime.uri`, `streamtime.fleetURI`
  - `agent.identity`, `agent.runtime` (optional)
  - `controller.enabled`
  - `--set-file streamtime.orchestrator.tls.caBundle="${CA_FILE}"`

**Workflow** (lines 286-349):
- Starts with current Helm values (from `GetHelmReleaseInfo`)
- Deep merges provided `input.Values`
- Applies `image_tag` convenience field
- Sets `image.repository` if not provided
- **DIFFERENCE**: Script sets all values explicitly, workflow merges with current values
- **MISSING**: Workflow does not explicitly set all the same defaults as the script

### 6. Helm Command Execution

**Deploy Script** (lines 230-250):
- Uses `helm upgrade --install` with:
  - `--namespace "${NAMESPACE}"`
  - `--create-namespace`
  - Multiple `--set` flags
  - `--set-file` for CA bundle
- Does not specify `--wait` or `--atomic` (uses Helm defaults)

**Workflow** (lines 373-452):
- Uses `HelmInstall` or `HelmUpgrade` activities
- For install: No `Wait` or `Atomic` specified (uses defaults)
- For upgrade: `Wait=true`, `Atomic=false`
- **DIFFERENCE**: Script doesn't wait, workflow waits for upgrade

### 7. Rollout Verification

**Deploy Script** (lines 252-259):
- After Helm command, runs `kubectl rollout status deployment/{DEPLOYMENT_NAME}`
- Timeout: 300 seconds (5 minutes)
- Warns if rollout check fails or times out (doesn't fail script)

**Workflow** (lines 470-530):
- After Helm upgrade, verifies deployment spec was updated
- If deployment spec doesn't match expected image tag, patches it directly
- Spawns `VerifyUpgrade` activity (non-blocking) after delay
- **DIFFERENCE**: Script uses `kubectl rollout status`, workflow verifies and patches if needed

### 8. Namespace Handling

**Deploy Script** (line 10):
- Hardcodes namespace: `NAMESPACE="streamtime-agent"`
- Uses `--create-namespace` flag

**Workflow** (line 23):
- Uses `input.Namespace` (typically `"streamtime-agent"`)
- **PARITY**: ✅ Both use streamtime-agent namespace

### 9. Deployment Name

**Deploy Script** (line 255):
- Constructs deployment name: `DEPLOYMENT_NAME="${RELEASE_NAME}-streamtime-helm"`
- Assumes chart name is `streamtime-helm`

**Workflow** (line 24):
- Uses `input.DeploymentName` (typically `"streamtime-agent-streamtime-helm"`)
- **PARITY**: ✅ Both use same naming pattern

### 10. Error Handling

**Deploy Script**:
- Uses `set -euo pipefail` (fails on any error)
- Checks for required tools (helm, kubectl)
- Validates CA file exists
- Exits on errors

**Workflow**:
- Uses Temporal retry policies
- Handles errors gracefully with fallbacks
- Logs warnings for non-fatal errors
- Returns structured error responses

### 11. Additional Features in Workflow

**Workflow Only**:
- **Scaling**: Optional `scale_up_replicas` to scale before upgrade (for single-worker safety)
- **Force Options**: `force="rollout"` to restart deployment, `force="rollback"` (not yet implemented)
- **Idempotency**: Helm upgrade activity is idempotent (handles pod termination gracefully)
- **Verification**: Spawns `VerifyUpgrade` activity to verify upgrade succeeded
- **Resumption**: Handles workflow resumption after pod termination

**Script Only**:
- **Setup Check**: Runs `setup-dev-fleet.sh` to ensure cluster is ready
- **Local Chart Fallback**: Falls back to local chart if not in registry
- **HTTP Registry Workaround**: Manual chart download for HTTP registries

## Missing in Workflow

1. **Registry URL Conversion**: Does not convert `localhost:5001` → `registry:5000` for kind clusters
2. **Local Chart Fallback**: Does not fall back to local chart if not in registry
3. **HTTP Registry Workaround**: Does not handle HTTP registry chart download manually
4. **Explicit Default Values**: Does not set all the same default values as the script
5. **Setup Check**: Does not verify cluster is ready before deployment

## Recommendations

1. **Add Registry URL Conversion**: Workflow should detect localhost and convert to `registry:5000` for kind clusters
2. **Add Local Chart Fallback**: Workflow should fall back to local chart if not found in registry (or fail gracefully)
3. **Add Explicit Default Values**: Workflow should set the same default values as the script (or ensure they're in the chart defaults)
4. **Consider Setup Check**: Add a pre-flight check activity to verify cluster is ready

## Summary

The workflow is more feature-rich (scaling, force options, idempotency, verification) but is missing some of the deployment script's robustness features (registry URL conversion, local chart fallback, HTTP registry workaround). The workflow should be updated to match the script's behavior for these edge cases.

