# Agent Management Page - Complete Implementation

## Overview

Comprehensive agent management page at `/kubernetes-fleet/{fleetId}/agent` that provides a step-by-step guided experience for installing, bootstrapping, and managing the Streamtime Agent.

## Page URL

```
/kubernetes-fleet/{fleetId}/agent
```

## Features

### Connection-Aware UI

The page automatically detects and displays the current state:
- ✅ Agent installed or not
- ✅ Cluster bootstrapped or not
- ✅ Last discovery probe results
- ✅ Agent version and configuration

### Step-by-Step Flow

**Step 1: Install Streamtime Agent**
- If not installed: Shows installation options
  - "Install Agent Only" button (mode="agent_only")
  - "Install Agent + Bootstrap Cluster" button (mode="fleet_bootstrap")
  - Manual instructions option
- If installed: Shows agent info
  - Agent version
  - Installation timestamp
  - Current Helm configuration (expandable)
  - "Reinstall Agent (Destructive)" button with warning

**Step 2: Bootstrap Fleet Cluster**
- If not bootstrapped: Shows bootstrap option
  - Description of what will be installed
  - "Bootstrap Now" button (calls ByokProvider with action="CREATE")
  - Manual instructions option
- If bootstrapped: Shows operator info
  - List of installed operators
  - Endpoints (Kong, Prometheus, etc.)
  - "Re-bootstrap Cluster (Destructive)" button with warning

**Step 3: Verify Connection**
- Shows last discovery probe results
- Displays cluster summary (Kubernetes version, nodes, CPU, RAM)
- "Refresh Metadata" button
- Expandable full discovery results

## Workflow Modes

### InstallStreamtimeAgentWorkflow

Now supports two modes via the `mode` parameter:

#### Mode: "agent_only" (Default)
1. Install streamtime-agent Helm chart
2. Install streamtime-operator Helm chart
3. Run discovery probe (pre-bootstrap)
4. Return success

**Duration**: ~2-5 minutes

#### Mode: "fleet_bootstrap"
1. Install streamtime-agent Helm chart
2. Install streamtime-operator Helm chart
3. Run discovery probe (pre-bootstrap)
4. **Call ByokProvider workflow** with action="CREATE"
   - Installs CFK operator
   - Installs Strimzi operator
   - Installs Kong API Gateway
   - Installs Prometheus & Grafana
   - Installs Loki
5. Run discovery probe (post-bootstrap)
6. Return success with bootstrap results

**Duration**: ~10-15 minutes

## API Endpoints

### Bootstrap Status
```bash
GET /organizations/{org}/fleet/{fleet}/agent/bootstrap-status/
```

Returns:
```json
{
  "bootstrapped": true,
  "operators": [
    {
      "namespace": "confluent",
      "deployments": 1,
      "pods": 3,
      "status": "healthy"
    }
  ],
  "endpoints": [
    {"type": "kong", "address": "10.x.x.x"}
  ],
  "last_bootstrap_at": "2025-12-02T10:00:00Z"
}
```

### Install Agent (Enhanced)
```bash
POST /organizations/{org}/fleet/{fleet}/agent/InstallStreamtimeAgentWorkflow/
```

Body:
```json
{
  "registry_url": "registry:5000",
  "image_tag": "latest",
  "namespace": "streamtime-agent",
  "mode": "agent_only"  // or "fleet_bootstrap"
}
```

Calls ByokProvider with action="CREATE"

## Destructive Actions

### Reinstall Agent
- **Warning**: "This will uninstall and reinstall the agent. All agent data will be reset."
- **Consequences**:
  - Agent temporarily unavailable
  - Agent data reset
  - Need to re-verify connection
- **Action**: Uninstall → Install → Verify

### Re-bootstrap Cluster
- **Warning**: "This will tear down and rebuild all operators and infrastructure."
- **Consequences**:
  - All operators removed and reinstalled
  - Existing Kafka clusters may be affected
  - Endpoints recreated
  - Takes 10-15 minutes
- **Action**: Teardown (ByokProvider DELETE) → Bootstrap (ByokProvider CREATE)

## User Flow

### New Fleet Creation
1. User creates BYOK fleet with kubeconfig
2. Redirected to `/kubernetes-fleet/{fleetId}/agent`
3. Sees Step 1 with two options:
   - **Quick**: "Install Agent + Bootstrap Cluster" (one workflow, ~15 min)
   - **Incremental**: "Install Agent Only" then manually bootstrap later

### Existing Fleet
1. User navigates to `/kubernetes-fleet/{fleetId}/agent`
2. Page detects current state
3. Shows completed steps with checkmarks
4. Shows pending steps with warnings
5. Offers destructive actions for re-installation

## Implementation Details

### Backend

**Files Modified:**
- `core/services/agent_tasks.py` - Added `get_bootstrap_status()` method
- `core/views/fleet/agent_tasks.py` - Added `BootstrapStatusView`
- `core/command_dispatch.py` - Added `mode` field to `InstallStreamtimeAgentInput`
- `fleet_manager/urls.py` - Added bootstrap-status route

**Workflow Updated:**
- `workflows/install_streamtime_agent.py` - Added fleet bootstrap mode

### Frontend

**Files Created:**
- `pages/AgentManagementPage.js` - Main agent management page
- `components/AgentTasks/DestructiveActionDialog.jsx` - Warning dialog

**Files Modified:**
- `services/agentTasksService.js` - Added `getBootstrapStatus()`
- `config/routes.js` - Changed route to `/agent`
- `pages/KubernetesFleetCreate.js` - Updated redirect to `/agent`

## Testing

### Test Agent-Only Installation
```bash
curl -X POST \
  "https://api.streamtime.local:8443/organizations/root/fleet/byok-test/agent/InstallStreamtimeAgentWorkflow/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "registry_url": "registry:5000",
    "image_tag": "latest",
    "namespace": "streamtime-agent",
    "mode": "agent_only"
  }' \
  -k
```

### Test Full Bootstrap
```bash
curl -X POST \
  "https://api.streamtime.local:8443/organizations/root/fleet/byok-test/agent/InstallStreamtimeAgentWorkflow/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "registry_url": "registry:5000",
    "image_tag": "latest",
    "namespace": "streamtime-agent",
    "mode": "fleet_bootstrap"
  }' \
  -k
```

### Test Bootstrap Status
```bash
curl -X GET \
  "https://api.streamtime.local:8443/organizations/root/fleet/byok-test/agent/bootstrap-status/" \
  -H "Authorization: Bearer $TOKEN" \
  -k
```

## Benefits

✅ **One-Click Bootstrap**: Install agent and bootstrap cluster in a single workflow
✅ **Flexible**: Choose agent-only or full bootstrap
✅ **Connection-Aware**: Automatically detects current state
✅ **Guided Experience**: Step-by-step with clear progress
✅ **Safe Destructive Actions**: Warnings before dangerous operations
✅ **Real-time Progress**: Live workflow status updates
✅ **Complete Visibility**: View configurations, versions, and discovery results

## Production Ready! 🚀

The agent management system is fully implemented and tested, providing a comprehensive solution for BYOK fleet lifecycle management.

