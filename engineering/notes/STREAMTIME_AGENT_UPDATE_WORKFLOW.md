# Streamtime Agent Update Workflow Documentation

## Overview

The `UpdateStreamtimeAgentWorkflow` is a Temporal workflow that manages updates to the `streamtime-agent` deployment in Kubernetes using a **CRD-based, declarative approach**. The workflow creates or updates a `StreamtimeAgentConfig` CRD, which a Kubernetes controller reconciles to perform the actual Helm upgrade.

This architecture provides:
- **Declarative upgrades**: Desired state expressed in a CRD
- **Kubernetes-native**: Uses standard controller patterns
- **Self-upgrade capability**: Controller can upgrade worker without terminating itself
- **Observability**: CRD status provides visibility into upgrade progress
- **Idempotency**: Both workflow activity and controller reconciliation are idempotent

## Architecture

### Workflow Structure

```
UpdateStreamtimeAgentWorkflow (Python)
  └─> UpdateAgentWorkflow (Go - Child Workflow)
      ├─> GetLatestImageTag (Activity) - if image_tag not provided
      ├─> GetLatestChartVersion (Activity) - if chart_version not provided
      └─> CreateOrUpdateAgentConfig (Activity) - creates/updates CRD
            └─> Controller reconciles CRD
                  └─> Helm Upgrade/Install
```

### Key Components

1. **Python Workflow** (`fleet-manager-orchestrator/workflows/update_streamtime_agent.py`)
   - Entry point for the workflow
   - Validates inputs and dispatches Go child workflow
   - Handles Temporal workflow orchestration

2. **Go Child Workflow** (`streamtime-agent/internal/workflows/update_agent.go`)
   - Executes in the `streamtime-agent` pod
   - Queries registry for latest tags/versions if not provided
   - Creates or updates `StreamtimeAgentConfig` CRD
   - Returns immediately after CRD creation (controller handles upgrade)

3. **CRD Activity** (`streamtime-agent/internal/activities/agent_config.go`)
   - `CreateOrUpdateAgentConfig`: Creates or updates the CRD
   - Idempotent: If CRD exists with same spec, returns success without update

4. **Kubernetes Controller** (`streamtime-agent/internal/controller/streamtimeagentconfig_controller.go`)
   - Watches `StreamtimeAgentConfig` CRDs
   - Reconciles CRD by performing Helm upgrade/install
   - Updates CRD status with upgrade progress and result
   - Handles force actions (rollout, rollback)

5. **Registry Activities** (`streamtime-agent/internal/activities/registry.go`)
   - `GetLatestImageTag`: Queries Docker registry for latest SemVer image tag
   - `GetLatestChartVersion`: Queries OCI registry for latest SemVer chart version

## Workflow Input

### Python Workflow Input

The workflow supports both **new typed format** (recommended) and **legacy flat format** (for backward compatibility).

#### New Typed Format (Recommended)

```python
{
    "target": str,                       # Optional: "worker" or "operator" (default: "worker")
    "update_types": list[str],           # Required: ["agent"], ["chart"], ["values"], ["agent", "chart"], etc.
    "agent": {                           # Optional: Required if "agent" in update_types
        "image_tag": str                 # Optional: If not provided, pulls latest from registry
    },
    "chart": {                           # Optional: Required if "chart" in update_types
        "version": str                   # Optional: If not provided, pulls latest from registry
    },
    "values": {                          # Optional: Required if "values" in update_types
        "values": dict                   # Helm values to merge with current values
    },
    "registry_url": str,                 # Optional: Default "registry:5000"
    "release": str,                      # Optional: Default "streamtime-agent"
    "namespace": str,                    # Optional: Default "streamtime-agent" (hardcoded)
    "deployment_name": str,              # Optional: Default based on target
    "scale_up_replicas": int,            # Optional: Default 0 (skip scaling)
    "verify_delay_seconds": int,         # Optional: Default 180 (3 minutes)
    "force": str,                        # Optional: "rollout" or "rollback"
    "timeout_seconds": int,              # Optional: Default 1800 (30 minutes)
}
```

#### Legacy Flat Format (Backward Compatible)

```python
{
    "image_tag": str,                    # Optional: New image tag. If not provided, pulls latest from registry
    "chart_version": str,                # Optional: New chart version. If not provided, pulls latest from registry
    "values": dict,                      # Optional: Any Helm values to update (merged with current values)
    "registry_url": str,                 # Optional: Default "registry:5000"
    "release": str,                      # Optional: Default "streamtime-agent"
    "namespace": str,                    # Optional: Default "streamtime-agent" (hardcoded)
    "deployment_name": str,              # Optional: Default "streamtime-agent-streamtime-helm"
    "scale_up_replicas": int,            # Optional: Default 0 (skip scaling)
    "verify_delay_seconds": int,         # Optional: Default 180 (3 minutes)
    "force": str,                        # Optional: "rollout" or "rollback"
    "timeout_seconds": int,              # Optional: Default 1800 (30 minutes)
}
```

### Go Child Workflow Input

```go
type UpdateAgentInput struct {
    Target             string                 `json:"target"`                         // "worker" or "operator"
    RegistryURL        string                 `json:"registry_url"`                   // e.g., "registry:5000"
    Release            string                 `json:"release"`                        // Helm release name
    Namespace          string                 `json:"namespace"`                      // Kubernetes namespace
    DeploymentName     string                 `json:"deployment_name"`                // Deployment name
    UpdateTypes        []string               `json:"update_types"`                   // Required: ["agent"], ["chart"], ["values"], etc.
    Agent              *AgentUpdateConfig     `json:"agent,omitempty"`                // Optional: Required if "agent" in UpdateTypes
    Chart              *ChartUpdateConfig     `json:"chart,omitempty"`                // Optional: Required if "chart" in UpdateTypes
    Values             *ValuesUpdateConfig    `json:"values,omitempty"`               // Optional: Required if "values" in UpdateTypes
    TimeoutSeconds     int64                  `json:"timeout_seconds,omitempty"`
    ScaleUpReplicas    int32                  `json:"scale_up_replicas,omitempty"`
    VerifyDelaySeconds int64                  `json:"verify_delay_seconds,omitempty"`
    Force              string                 `json:"force,omitempty"`                // "rollout" or "rollback"
}
```

## Workflow Output

```json
{
    "release": "streamtime-agent",
    "namespace": "streamtime-agent",
    "revision": 13,
    "status": "upgraded",
    "previous_tag": "0.1.1764445424",
    "new_tag": "0.1.1764445821",
    "previous_chart_version": "0.1.1764445424",
    "new_chart_version": "0.1.1764445821"
}
```

## Workflow Steps

### 1. Validate Input
- Validates `update_types` contains at least one type: "agent", "chart", or "values"
- Validates `target` is "worker" or "operator"
- Validates required configs are provided for each update type

### 2. Determine Latest Versions (If Not Provided)
- If `agent.image_tag` not provided and "agent" in `update_types`:
  - Calls `GetLatestImageTag` activity to query registry for latest SemVer tag
- If `chart.version` not provided and "chart" in `update_types`:
  - Calls `GetLatestChartVersion` activity to query registry for latest SemVer version
- Uses proper SemVer comparison to find the latest version

### 3. Create or Update CRD
- Calls `CreateOrUpdateAgentConfig` activity
- Activity is **idempotent**: If CRD exists with same spec, returns success without update
- CRD contains:
  - Target component (worker or operator)
  - Update types and configurations
  - Registry URL, release name, namespace, deployment name
  - Optional: timeout, scaling, verification delay, force action

### 4. Controller Reconciliation (Automatic)
- Controller watches for CRD changes
- When CRD is created/updated, controller reconciles:
  1. Gets current Helm release info (if exists)
  2. Gets current deployment image tag (if exists)
  3. Determines new image tag and chart version
  4. Merges Helm values (current + new)
  5. Performs Helm upgrade or install
  6. Updates CRD status with:
     - Phase: Pending → Reconciling → Upgraded/Error
     - Previous and new tags/versions
     - Helm revision
     - Status: "upgraded", "restarted", or "installed"

### 5. Force Actions (Optional)
- If `force: "rollout"`: Controller triggers deployment rollout restart (no Helm upgrade)
- If `force: "rollback"`: Controller rolls back Helm release to previous revision

## Key Features

### CRD-Based Declarative Upgrades

The workflow uses a **declarative, Kubernetes-native approach**:

**Benefits**:
- **Separation of concerns**: Workflow declares desired state (CRD), controller implements it
- **Self-upgrade capability**: Controller runs in separate pod, can upgrade worker without terminating itself
- **Observability**: CRD status provides visibility into upgrade progress
- **Kubernetes-native**: Uses standard controller patterns and CRD lifecycle

**How it works**:
1. Workflow creates/updates `StreamtimeAgentConfig` CRD
2. Controller watches CRD and reconciles desired state
3. Controller performs Helm upgrade and updates CRD status
4. CRD status reflects upgrade progress and result

### Idempotent Operations

Both the workflow activity and controller reconciliation are **idempotent**:

- **Workflow Activity**: If CRD exists with same spec, returns success without update
- **Controller Reconciliation**: If CRD status shows upgrade already complete, skips upgrade

This ensures:
- Safe retries: Workflow can be retried without side effects
- Safe reconciliation: Controller can reconcile multiple times without issues
- Consistent state: Desired state matches actual state

### Automatic Latest Version Detection

The workflow automatically queries the registry for the latest versions when not explicitly provided:

- **Image tags**: Queries Docker registry API (`/v2/{image}/tags/list`) and sorts by SemVer
- **Chart versions**: Queries OCI registry for chart tags and sorts by SemVer
- **SemVer comparison**: Uses proper SemVer library for accurate version comparison
- **Fallback**: If no SemVer tags found, falls back to alphabetical sorting

### Separate Controller and Worker

The controller and worker are deployed as **separate Helm charts**:

- **`streamtime-agent` chart**: Worker deployment (Temporal worker only)
- **`streamtime-operator` chart**: Controller deployment (Kubernetes controller only)

This enables:
- **Self-upgrade**: Controller can upgrade worker without terminating itself
- **Independent scaling**: Scale workers and controller independently
- **Independent updates**: Update controller without affecting worker
- **Fault isolation**: Controller failures don't affect worker execution

## Usage Examples

### Update to Latest (Automatic Detection)

```bash
docker compose exec temporal temporal workflow start \
  --address temporal:7233 \
  --tls=false \
  --task-queue fleet-manager-tasks \
  --workflow-id "/organizations/root/test/update-agent-$(date +%s)" \
  --type UpdateStreamtimeAgentWorkflow \
  --input '{
    "target": "worker",
    "update_types": ["agent"]
  }'
```

### Update Image Tag Only (Latest from Registry)

```bash
docker compose exec temporal temporal workflow start \
  --address temporal:7233 \
  --tls=false \
  --task-queue fleet-manager-tasks \
  --workflow-id "/organizations/root/test/update-agent-$(date +%s)" \
  --type UpdateStreamtimeAgentWorkflow \
  --input '{
    "target": "worker",
    "update_types": ["agent"],
    "agent": {}
  }'
```

### Update to Specific Version

```bash
docker compose exec temporal temporal workflow start \
  --address temporal:7233 \
  --tls=false \
  --task-queue fleet-manager-tasks \
  --workflow-id "/organizations/root/test/update-agent-$(date +%s)" \
  --type UpdateStreamtimeAgentWorkflow \
  --input '{
    "target": "worker",
    "update_types": ["agent", "chart"],
    "agent": {
      "image_tag": "0.1.1764535394"
    },
    "chart": {
      "version": "0.1.1764535394"
    }
  }'
```

### Update Chart Version Only

```bash
docker compose exec temporal temporal workflow start \
  --address temporal:7233 \
  --tls=false \
  --task-queue fleet-manager-tasks \
  --workflow-id "/organizations/root/test/update-agent-$(date +%s)" \
  --type UpdateStreamtimeAgentWorkflow \
  --input '{
    "target": "worker",
    "update_types": ["chart"],
    "chart": {
      "version": "0.1.1764535394"
    }
  }'
```

### Update with Custom Helm Values

```bash
docker compose exec temporal temporal workflow start \
  --address temporal:7233 \
  --tls=false \
  --task-queue fleet-manager-tasks \
  --workflow-id "/organizations/root/test/update-agent-$(date +%s)" \
  --type UpdateStreamtimeAgentWorkflow \
  --input '{
    "values": {
      "replicaCount": 2,
      "resources": {
        "limits": {
          "cpu": "500m",
          "memory": "512Mi"
        }
      }
    }
  }'
```

### Update Helm Values

```bash
docker compose exec temporal temporal workflow start \
  --address temporal:7233 \
  --tls=false \
  --task-queue fleet-manager-tasks \
  --workflow-id "/organizations/root/test/update-agent-$(date +%s)" \
  --type UpdateStreamtimeAgentWorkflow \
  --input '{
    "target": "worker",
    "update_types": ["values"],
    "values": {
      "values": {
        "replicaCount": 2,
        "resources": {
          "limits": {
            "cpu": "500m",
            "memory": "512Mi"
          }
        }
      }
    }
  }'
```

### Force Rollout Restart (No Helm Upgrade)

```bash
docker compose exec temporal temporal workflow start \
  --address temporal:7233 \
  --tls=false \
  --task-queue fleet-manager-tasks \
  --workflow-id "/organizations/root/test/update-agent-$(date +%s)" \
  --type UpdateStreamtimeAgentWorkflow \
  --input '{
    "target": "worker",
    "update_types": ["agent"],
    "force": "rollout"
  }'
```

### Force Rollback

```bash
docker compose exec temporal temporal workflow start \
  --address temporal:7233 \
  --tls=false \
  --task-queue fleet-manager-tasks \
  --workflow-id "/organizations/root/test/update-agent-$(date +%s)" \
  --type UpdateStreamtimeAgentWorkflow \
  --input '{
    "target": "worker",
    "update_types": ["agent"],
    "force": "rollback"
  }'
```

## Troubleshooting

### Issue: CRD Not Being Reconciled

**Symptoms**:
- CRD exists but status phase is "Pending"
- Controller logs show no reconciliation events

**Root Cause**: Controller not running or not watching the namespace.

**Solution**:
1. Verify controller is running: `kubectl get pods -n streamtime-agent -l app.kubernetes.io/name=streamtime-operator`
2. Check controller logs: `kubectl logs -n streamtime-agent deployment/streamtime-operator-streamtime-operator`
3. Verify CRD is installed: `kubectl get crd streamtimeagentconfigs.agent.streamtime.ai`
4. Check controller RBAC: `kubectl get clusterrolebinding | grep streamtime-operator`

**Verification**:
```bash
# Check CRD status
kubectl get streamtimeagentconfig streamtime-agent-config -n streamtime-agent -o yaml

# Check controller logs
kubectl logs -n streamtime-agent deployment/streamtime-operator-streamtime-operator | grep -i "reconcile"
```

### Issue: Workflow Reports Success But Deployment Not Updated

**Symptoms**:
- Workflow completes successfully
- CRD status shows "Upgraded"
- Deployment spec still has old image tag

**Root Cause**: Controller reconciliation may have failed or Helm upgrade didn't update deployment.

**Solution**:
1. Check controller logs for errors
2. Check CRD status for error messages
3. Verify Helm release was upgraded: `helm get all streamtime-agent -n streamtime-agent`
4. Manually trigger reconciliation by updating CRD: `kubectl annotate streamtimeagentconfig streamtime-agent-config -n streamtime-agent reconcile=now`

**Verification**:
```bash
# Check deployment spec
kubectl get deployment streamtime-agent-streamtime-helm -n streamtime-agent -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check CRD status
kubectl get streamtimeagentconfig streamtime-agent-config -n streamtime-agent -o jsonpath='{.status.new_tag}'

# Compare - they should match
```

### Issue: RBAC Permission Errors

**Symptoms**:
- `VerifyUpgrade` activity fails with permission errors
- Error: `cannot get resource "deployments" in API group "apps"`

**Root Cause**: Service account in wrong namespace or missing permissions.

**Solution**:
1. Ensure service account exists in `streamtime-agent` namespace
2. Check ClusterRoleBinding references correct namespace
3. Verify no duplicate service accounts in `default` namespace

**Verification**:
```bash
# Check service account
kubectl get serviceaccount -n streamtime-agent

# Check ClusterRoleBinding
kubectl get clusterrolebinding | grep streamtime-agent

# Verify no duplicates in default namespace
kubectl get serviceaccount -n default | grep streamtime-agent
```

### Issue: VerifyUpgrade Takes Too Long

**Symptoms**:
- Workflow completes but verification takes 10+ minutes

**Root Cause**: Default retry settings were too aggressive (20 attempts × 30s = 10 minutes).

**Solution**: Reduced to 5 attempts × 10s = 50 seconds.

**Configuration**:
- `MaxAttempts`: 5 (default)
- `RetryDelay`: 10 seconds (default)
- `VerifyDelaySeconds`: 180 seconds (default, before verification starts)

### Issue: Latest Version Detection Fails

**Symptoms**:
- Workflow fails with "failed to get latest image tag from registry"
- Error querying registry API

**Root Cause**: Registry not accessible or API endpoint incorrect.

**Solution**:
1. Verify registry URL is correct: `registry:5000` (from within cluster) or `localhost:5001` (from host)
2. Test registry API: `curl http://registry:5000/v2/streamtime/streamtime-agent/tags/list`
3. Check network connectivity from agent pod
4. Verify registry supports Docker Registry API v2

**Verification**:
```bash
# Test registry from within cluster
kubectl run -it --rm test-registry --image=curlimages/curl --restart=Never -- \
  curl http://registry:5000/v2/streamtime/streamtime-agent/tags/list

# Check workflow logs for registry query
kubectl logs -n streamtime-agent -l app.kubernetes.io/name=streamtime-helm | grep -i "latest"
```

## Monitoring and Verification

### Check Workflow Status

```bash
docker compose exec temporal temporal workflow show \
  --address temporal:7233 \
  --tls=false \
  --workflow-id "/organizations/root/test/update-agent-<workflow-id>"
```

### Check CRD Status

```bash
# Get CRD status
kubectl get streamtimeagentconfig streamtime-agent-config -n streamtime-agent -o yaml

# Check CRD phase
kubectl get streamtimeagentconfig streamtime-agent-config -n streamtime-agent \
  -o jsonpath='{.status.phase}'

# Check upgrade details
kubectl get streamtimeagentconfig streamtime-agent-config -n streamtime-agent \
  -o jsonpath='{.status}' | jq
```

### Check Controller Logs

```bash
# Controller logs
kubectl logs -f -n streamtime-agent deployment/streamtime-operator-streamtime-operator

# Filter for reconciliation events
kubectl logs -n streamtime-agent deployment/streamtime-operator-streamtime-operator | grep -i "reconcile"
```

### Check Deployment State

```bash
# Get deployment image
kubectl get deployment streamtime-agent-streamtime-helm -n streamtime-agent \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Get Helm release info
helm get all streamtime-agent -n streamtime-agent | grep -A 2 "CHART:"

# Get pod image
kubectl get pods -n streamtime-agent -l app.kubernetes.io/name=streamtime-helm \
  -o jsonpath='{.items[0].spec.containers[0].image}'
```

### Check Workflow Logs

```bash
# Python workflow logs
docker compose logs temporal-worker | grep -i "UpdateStreamtimeAgentWorkflow"

# Go workflow logs (from agent pod)
kubectl logs -n streamtime-agent -l app.kubernetes.io/name=streamtime-helm | grep -i "UpdateAgentWorkflow"
```

### Verify Upgrade Completed

```bash
# Use the helper script
./scripts/get-streamtime-agent-helm-info.sh

# Or manually check CRD status
kubectl get streamtimeagentconfig streamtime-agent-config -n streamtime-agent \
  -o jsonpath='{.status.phase}'  # Should be "Upgraded"
```

## Implementation Details

### CRD Creation Activity

The `CreateOrUpdateAgentConfig` activity is idempotent:

```go
// Check if CRD exists
existing := &agentv1alpha1.StreamtimeAgentConfig{}
err = k8sClient.Get(ctx, client.ObjectKey{...}, existing)

if err == nil {
    // CRD exists - compare specs
    existingSpecJSON, _ := json.Marshal(existing.Spec)
    newSpecJSON, _ := json.Marshal(agentConfig.Spec)
    
    if string(existingSpecJSON) == string(newSpecJSON) {
        // Same spec - return success without update
        return &CreateOrUpdateAgentConfigOutput{
            AlreadyExists: true,
        }, nil
    }
    
    // Different spec - update CRD
    existing.Spec = agentConfig.Spec
    k8sClient.Update(ctx, existing)
} else {
    // CRD doesn't exist - create it
    k8sClient.Create(ctx, agentConfig)
}
```

### Controller Reconciliation

The controller reconciles the CRD by:

1. **Checking if already reconciled**: If `ObservedGeneration == Generation` and `Phase == Upgraded`, skip
2. **Getting current state**: Query Helm release and deployment for current tags/versions
3. **Determining new state**: Use provided tags/versions or query registry for latest
4. **Merging values**: Deep merge current Helm values with new values
5. **Performing upgrade**: Call Helm upgrade or install
6. **Updating status**: Update CRD status with phase, tags, versions, and revision

### Latest Version Detection

The registry activities use SemVer comparison:

```go
// Parse tags as SemVer
for _, tag := range tags {
    version, err := semver.NewVersion(tag)
    if err != nil {
        continue  // Skip non-SemVer tags
    }
    tagsWithVersion = append(tagsWithVersion, tagWithVersion{
        tag:     tag,
        version: version,
    })
}

// Sort by SemVer (highest first)
sort.Slice(tagsWithVersion, func(i, j int) bool {
    return tagsWithVersion[i].version.GreaterThan(tagsWithVersion[j].version)
})

// Return latest
latestTag := tagsWithVersion[0].tag
```

### Error Handling

All activities include comprehensive error handling:
- Nil checks for all outputs
- Graceful degradation (warnings instead of failures where appropriate)
- Detailed logging for debugging
- Non-blocking verification (doesn't fail workflow if verification fails)

## Related Documentation

- [Building and Deploying Streamtime Artifacts](BUILDING_AND_DEPLOYING.md)
- [Workflow vs Deploy Script Comparison](WORKFLOW_VS_DEPLOY_SCRIPT_COMPARISON.md)
- [Testing Agent Commands](TESTING_AGENT_COMMANDS.md)

## Known Issues and Limitations

### Controller and Worker Separation

**Requirement**: Controller and worker must be deployed as separate Helm charts.

**Reason**: Enables self-upgrade capability (controller can upgrade worker without terminating itself).

**Status**: Required architecture, not a limitation.

### Operator Upgrades

**Issue**: Operator upgrades via CRD are not yet implemented.

**Workaround**: Operator upgrades should use regular Helm upgrade activity directly (bypass CRD).

**Status**: Planned for future implementation.

### CRD Single Instance

**Issue**: Only one `StreamtimeAgentConfig` CRD instance is supported per namespace.

**Reason**: CRD name is hardcoded to `streamtime-agent-config`.

**Status**: By design - one upgrade at a time per namespace.

## Future Improvements

1. **Operator Upgrades via CRD**: Support operator upgrades through CRD (currently uses regular Helm activity)
2. **Multiple CRD Instances**: Support multiple concurrent upgrades with named CRD instances
3. **Dry-Run Mode**: Add ability to preview changes without applying
4. **Rollback on Failure**: Automatic rollback if upgrade fails
5. **Metrics**: Add Prometheus metrics for upgrade success/failure rates
6. **Webhook Notifications**: Notify on upgrade completion/failure
7. **Upgrade Progress Tracking**: Real-time progress updates in CRD status

