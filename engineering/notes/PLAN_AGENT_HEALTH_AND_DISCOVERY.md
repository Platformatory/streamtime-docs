# Plan: Agent Health Check and Discovery Features

## Overview

This plan documents the implementation of three key features for the streamtime-agent:

1. **Early Failure Detection**: Fail immediately on startup if agent cannot connect to orchestrator
2. **Discovery Probe Workflow**: Comprehensive discovery workflow that collects Kubernetes cluster information
3. **Streamtime Info**: Returns agent version, registered workflows/activities, and bootstrap state

## Features Implemented

### 1. Early Failure Detection

**Location**: `streamtime-agent/internal/worker/runner.go`

**Implementation**:
- After `client.Dial()` succeeds, verify connectivity using `OperatorService().DescribeNamespace()`
- If health check fails, log clear error messages with troubleshooting steps
- Agent fails immediately before worker starts

**What to verify**:
- Success case: Agent logs "Orchestrator connectivity verified successfully"
- Failure case: Agent logs "CRITICAL: Cannot connect to orchestrator" with troubleshooting steps

### 2. Discovery Probe Workflow

**Locations**:
- `streamtime-agent/internal/activities/discovery.go` - Discovery activity
- `streamtime-agent/internal/workflows/discovery.go` - Go workflow
- `fleet-manager-orchestrator/workflows/discovery_probe.py` - Python parent workflow

**Implementation**:
- Comprehensive cluster discovery activity that collects:
  - Agent version and deployment age
  - Kubernetes version, cloud provider (AWS, GCP, Azure, OCI, Digital Ocean), region
  - Node information (count, details, CPU/RAM/disk)
  - Resource information (total and allocatable)
  - Network information (Pod CIDR, Service CIDR, CNI detection)
  - Hardware information (instance type, zone, region)
  - Workload information (deployments, statefulsets, daemonsets, pods per namespace)
  - Prerequisites evaluation (IngressClass, StorageClass, CNI, RBAC)
  - Diagnostics (API server version, component status)
- Go workflow wraps the activity and returns command audit data
- Python parent workflow provides command auditing for tracking in Django

**What to verify**:
- Discovery probe workflow executes successfully
- Returns comprehensive cluster information
- Command is tracked in Django with discovery data in result field

### 3. Streamtime Info

**Locations**:
- `streamtime-agent/internal/activities/streamtime_info.go` - StreamtimeInfo activity
- `streamtime-agent/internal/workflows/streamtime_info.go` - Go workflow

**Implementation**:
- Returns agent information:
  - Version (from `STREAMTIME_AGENT_IMAGE_TAG`)
  - List of registered workflow names
  - List of registered activity names
  - Bootstrap state (stub for future enhancement)
- Activity receives workflow/activity names during registration
- Workflow wraps activity with command auditing

**What to verify**:
- StreamtimeInfo workflow executes successfully
- Returns version, workflows, activities
- Command is tracked in Django

## Testing Rules

**Important**: Always create parent workflows via Temporal CLI. The parent workflows run on the Python worker (task-queue: `default`), which then execute the Go child workflows on the agent (task-queue: `agent-tq`). This ensures proper command auditing in Django.

### 1. Build and Deploy Streamtime Agent

**Procedure**:
```bash
# From project root
cd scripts
./deploy-streamtime-agent.sh

# Or with explicit NO_CACHE flag
NO_CACHE=true ./deploy-streamtime-agent.sh
```

**Note**: The `bootstrap-byok-fleet.sh` script sets `NO_CACHE=true` by default.

**What to verify**:
- Image builds successfully
- Image is loaded into Kind cluster
- Helm chart deployment succeeds
- Agent pod starts and is running

### 2. Check Agent Logs

**Procedure**:
```bash
# Get pod name
kubectl get pods -n default | grep streamtime-agent

# Tail logs
kubectl logs -f -n default <pod-name> streamtime-agent

# Or use label selector
kubectl logs -f -n default -l app.kubernetes.io/name=streamtime-agent
```

**What to look for**:
- Early failure detection: "Orchestrator connectivity verified successfully" or "CRITICAL: Cannot connect to orchestrator"
- Discovery probe: Discovery activity execution logs
- Streamtime info: StreamtimeInfo activity execution logs
- Workflow registrations: All workflows registered
- Activity registrations: All activities registered
- Any errors or warnings

### 3. Check Orchestrator Worker Logs

**Procedure**:
```bash
# From project root
docker compose logs -f temporal-worker

# Or with tail
docker compose logs --tail=100 -f temporal-worker
```

**What to look for**:
- Workflow execution logs
- Activity execution logs
- Command audit activity calls
- Any errors or warnings
- Child workflow execution logs

### 4. Check Workflow History

**Procedure**:
```bash
# List workflows
docker compose exec temporal temporal workflow list \
  --address temporal:7233 \
  --tls=false

# Show workflow history
docker compose exec temporal temporal workflow show \
  --address temporal:7233 \
  --tls=false \
  --workflow-id <workflow-id>

# Show workflow history with run-id
docker compose exec temporal temporal workflow show \
  --address temporal:7233 \
  --tls=false \
  --workflow-id <workflow-id> \
  --run-id <run-id>
```

**What to look for**:
- Workflow execution events
- Activity execution events
- Child workflow execution events
- Command audit activity calls
- Workflow completion/failure status
- Return values from workflows

### 5. Verify Commands Logged in Django

**Procedure**:
```bash
# Get root organization token
TOKEN=$(./scripts/get-root-token.sh)

# Set Kong URL
KONG_URL="https://api.streamtime.ai:8443"

# List all commands for root organization
curl -s -k --http1.1 \
  -H "Authorization: Bearer $TOKEN" \
  "$KONG_URL/organizations/root/commands/" | jq

# Filter by command_handler
curl -s -k --http1.1 \
  -H "Authorization: Bearer $TOKEN" \
  "$KONG_URL/organizations/root/commands/?command_handler=DiscoveryProbeWorkflow" | jq

# Filter by command_aggregate (workflow_id)
curl -s -k --http1.1 \
  -H "Authorization: Bearer $TOKEN" \
  "$KONG_URL/organizations/root/commands/?command_aggregate=<workflow-id>" | jq

# Get specific command by command_id (run_id)
curl -s -k --http1.1 \
  -H "Authorization: Bearer $TOKEN" \
  "$KONG_URL/organizations/root/commands/<command-id>/" | jq
```

**What to verify**:
- Commands are created with correct `command_handler` (workflow name)
- Commands have correct `command_aggregate` (workflow_id)
- Commands have correct `command_id` (run_id)
- Commands have correct `status` (pending → running → completed/failed)
- Commands have `request` data (workflow input)
- Commands have `result` data (workflow output) when completed
- Commands have `start` and `end` timestamps
- Both parent and child workflows are tracked separately

## Testing Checklist

### Early Failure Detection
- [ ] Agent builds and deploys successfully
- [ ] Agent starts and connects to orchestrator (success case)
- [ ] Agent fails with clear error message when orchestrator unavailable (failure case)
- [ ] Troubleshooting steps are logged in failure case

### Discovery Probe
- [ ] Discovery probe workflow executes successfully
- [ ] Discovery probe returns cluster information (nodes, cloud provider, etc.)
- [ ] Command is tracked in Django with discovery data
- [ ] Result data contains all expected fields

### Streamtime Info
- [ ] StreamtimeInfo workflow executes successfully
- [ ] StreamtimeInfo returns version, workflows, activities
- [ ] Command is tracked in Django
- [ ] Result data contains all expected fields

### General
- [ ] All workflows are tracked in Django
- [ ] All child workflows are tracked separately
- [ ] Command records have correct status progression
- [ ] Command records have request and result data
- [ ] Workflow history shows correct execution flow

## Important Constraints

### Temporal Payload Size Limit

**2 MB limit** for workflow/activity return values. The discovery probe must ensure the returned data stays within this limit. If the data approaches the limit, consider:
- Summarizing detailed information (e.g., sample nodes instead of all nodes)
- Using compression if needed
- Storing detailed data externally and returning references

### Django JSONField Limit

The `result` field in `AgentCommand` model uses Django's `JSONField` (PostgreSQL JSONB in production):
- **No hard limit in Django model**: The field definition doesn't enforce a size limit
- **Database limits**: PostgreSQL JSONB has a practical limit of ~1GB, but performance degrades with large values
- **Primary constraint**: The Temporal 2 MB limit is the primary constraint we need to respect
- **Recommendation**: Keep result payloads under 2 MB to align with Temporal limits and ensure good performance

## Files Modified/Created

### Go Agent Files
- `streamtime-agent/internal/worker/runner.go` - Early failure detection, StreamtimeInfo registration
- `streamtime-agent/internal/activities/discovery.go` - Discovery activity (new)
- `streamtime-agent/internal/workflows/discovery.go` - Discovery workflow (new)
- `streamtime-agent/internal/activities/streamtime_info.go` - StreamtimeInfo activity (new)
- `streamtime-agent/internal/workflows/streamtime_info.go` - StreamtimeInfo workflow (new)

### Python Orchestrator Files
- `fleet-manager-orchestrator/workflows/discovery_probe.py` - Python parent workflow (new)
- `fleet-manager-orchestrator/workflows/streamtime_info.py` - Python parent workflow (new)

### Documentation Files
- `docs/TESTING_STREAMTIME_AGENT_FEATURES.md` - Testing procedures (new)
- `docs/STREAMTIME_INFO.md` - StreamtimeInfo documentation (new)
- `docs/PLAN_AGENT_HEALTH_AND_DISCOVERY.md` - This plan document (new)
- `docs/AGENT_COMMAND_TRACKING.md` - Updated with testing reference

## Next Steps

1. Build and deploy the streamtime agent
2. Test early failure detection (success and failure cases)
3. Test discovery probe workflow
4. Test streamtime info workflow
5. Verify all commands are tracked in Django
6. Review logs and workflow history
7. Document any issues or improvements needed

