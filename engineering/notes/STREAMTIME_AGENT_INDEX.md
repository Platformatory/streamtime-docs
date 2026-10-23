# Streamtime Agent Documentation Index

This directory contains comprehensive documentation for the Streamtime Agent update workflow and related functionality.

## Quick Start

1. **Build and Push Artifacts**: [Building and Deploying](BUILDING_AND_DEPLOYING.md)
2. **Update Agent**: [Update Workflow Guide](STREAMTIME_AGENT_UPDATE_WORKFLOW.md)
3. **Troubleshoot Issues**: [Troubleshooting Guide](STREAMTIME_AGENT_TROUBLESHOOTING.md)

## Documentation Files

### Core Documentation

- **[STREAMTIME_AGENT_UPDATE_WORKFLOW.md](STREAMTIME_AGENT_UPDATE_WORKFLOW.md)**
  - Complete guide to the UpdateStreamtimeAgentWorkflow
  - Architecture, inputs/outputs, workflow steps
  - Usage examples and best practices
  - Implementation details

- **[STREAMTIME_AGENT_TROUBLESHOOTING.md](STREAMTIME_AGENT_TROUBLESHOOTING.md)**
  - Common issues and solutions
  - Debugging commands
  - Verification checklist
  - RBAC and permission issues

- **[BUILDING_AND_DEPLOYING.md](BUILDING_AND_DEPLOYING.md)**
  - How to build and push agent image and Helm chart
  - Naming conventions
  - Registry management
  - Scripts reference

### Comparison and Reference

- **[WORKFLOW_VS_DEPLOY_SCRIPT_COMPARISON.md](WORKFLOW_VS_DEPLOY_SCRIPT_COMPARISON.md)**
  - Detailed comparison between workflow and deploy script
  - Differences in behavior
  - Recommendations for parity

## Key Concepts

### CRD-Based Declarative Upgrades

The workflow uses a **declarative, Kubernetes-native approach** via `StreamtimeAgentConfig` CRD:

**Why**: 
- Separates concerns: Workflow declares desired state, controller implements it
- Enables self-upgrade: Controller can upgrade worker without terminating itself
- Provides observability: CRD status shows upgrade progress
- Kubernetes-native: Uses standard controller patterns

**How**: 
1. Workflow creates/updates `StreamtimeAgentConfig` CRD
2. Controller watches CRD and reconciles desired state
3. Controller performs Helm upgrade and updates CRD status
4. CRD status reflects upgrade progress and result

### Separate Controller and Worker

The controller and worker are deployed as **separate Helm charts**:

**Why**:
- Self-upgrade capability: Controller can upgrade worker without terminating itself
- Independent scaling: Scale workers and controller independently
- Independent updates: Update controller without affecting worker
- Fault isolation: Controller failures don't affect worker execution

**How**:
- `streamtime-agent` chart: Worker deployment (Temporal worker only)
- `streamtime-operator` chart: Controller deployment (Kubernetes controller only)
- Both use the same Docker image (different entry points)

### Automatic Latest Version Detection

The workflow automatically queries the registry for the latest versions when not explicitly provided:

**Why**: Simplifies upgrades by automatically finding the latest available version.

**How**:
- Queries Docker registry API for latest SemVer image tag
- Queries OCI registry for latest SemVer chart version
- Uses proper SemVer comparison to find the latest version
- Falls back to alphabetical sorting if no SemVer tags found

### Idempotent Operations

Both the workflow activity and controller reconciliation are **idempotent**:

**Why**: Enables safe retries and consistent state.

**How**:
- Workflow Activity: If CRD exists with same spec, returns success without update
- Controller Reconciliation: If CRD status shows upgrade already complete, skips upgrade

## Common Workflows

### Update to Latest

```bash
docker compose exec temporal temporal workflow start \
  --address temporal:7233 \
  --tls=false \
  --task-queue fleet-manager-tasks \
  --workflow-id "/organizations/root/test/update-agent-$(date +%s)" \
  --type UpdateStreamtimeAgentWorkflow \
  --input '{}'
```

### Update Image Tag Only

```bash
docker compose exec temporal temporal workflow start \
  --address temporal:7233 \
  --tls=false \
  --task-queue fleet-manager-tasks \
  --workflow-id "/organizations/root/test/update-agent-$(date +%s)" \
  --type UpdateStreamtimeAgentWorkflow \
  --input '{
    "image_tag": "0.1.1764445821",
    "chart_version": "0.1.1764445424"
  }'
```

### Build and Deploy

```bash
# Build and push artifacts (image + both charts)
./scripts/build-and-push-streamtime.sh

# Deploy latest (both worker and operator)
./scripts/deploy-streamtime-agent.sh
```

**Note**: The deploy script deploys both the `streamtime-agent` (worker) and `streamtime-operator` (controller) charts.

## Verification

### Quick Verification

```bash
# Check deployment image
kubectl get deployment streamtime-agent-streamtime-helm -n streamtime-agent \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check Helm release
helm get all streamtime-agent -n streamtime-agent | grep -A 2 "CHART:"

# Use helper script
./scripts/get-streamtime-agent-helm-info.sh
```

### Comprehensive Verification

See [Troubleshooting Guide](STREAMTIME_AGENT_TROUBLESHOOTING.md#verification-checklist) for complete checklist.

## Scripts Reference

### Build and Push

- `scripts/build-and-push-streamtime.sh`: Build and push image and both charts (worker + operator)
- `scripts/deploy-streamtime-agent.sh`: Deploy both worker and operator to Kubernetes
- `scripts/list-registry-contents.sh`: List all images and charts in registry

### Verification

- `scripts/get-streamtime-agent-helm-info.sh`: Get Helm release information

## Architecture

### Component Separation

The Streamtime Agent consists of two separate deployments:

- **`streamtime-agent` Chart (Worker)**: Temporal worker that executes workflows
- **`streamtime-operator` Chart (Controller)**: Kubernetes controller that reconciles `StreamtimeAgentConfig` CRDs

### Upgrade Workflow Architecture

```
UpdateStreamtimeAgentWorkflow (Python)
  └─> UpdateAgentWorkflow (Go - Child Workflow)
      ├─> GetLatestImageTag (if needed)
      ├─> GetLatestChartVersion (if needed)
      └─> CreateOrUpdateAgentConfig (Activity)
            └─> StreamtimeAgentConfig CRD
                  └─> Controller reconciles CRD
                        └─> Helm Upgrade/Install
                              └─> Updates CRD Status
```

### Key Features

- **CRD-Based**: Declarative upgrades via `StreamtimeAgentConfig` CRD
- **Separate Deployments**: Controller and worker run in separate pods
- **Self-Upgrade**: Controller can upgrade worker without terminating itself
- **Automatic Latest Detection**: Queries registry for latest SemVer tags/versions
- **Idempotent**: Both workflow activity and controller reconciliation are idempotent

## Related Documentation

- [Testing Agent Commands](TESTING_AGENT_COMMANDS.md)
- [Agent Command Tracking](AGENT_COMMAND_TRACKING.md)

## Support

For issues or questions:
1. Check [Troubleshooting Guide](STREAMTIME_AGENT_TROUBLESHOOTING.md)
2. Review workflow logs
3. Verify deployment state
4. Check RBAC permissions

