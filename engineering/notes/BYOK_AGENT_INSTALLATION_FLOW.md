# BYOK Agent Installation Flow - Complete Implementation

## Overview

This document describes the complete BYOK (Bring Your Own Kubernetes) agent installation flow with automatic and manual installation options.

## Implementation Status: ✅ COMPLETE

All backend and frontend components have been implemented and are ready for testing.

## User Flow

### 1. Create BYOK Fleet

**Page**: `KubernetesFleetCreate.js`

User creates a BYOK fleet by providing:
- Fleet identifier
- Kubeconfig file (required for BYOK)
- Optional placement and advanced configuration

**After Creation**:
- Fleet record is created in database
- User is automatically redirected to: `/kubernetes-fleet/{fleet_id}/agent-installation`

### 2. Agent Installation Wizard

**Page**: `AgentInstallationWizard.js`

User is presented with two installation options:

#### Option A: Automatic Installation (Recommended)

**What Happens:**
1. User clicks "Install Automatically" button
2. System calls `POST /organizations/{org}/fleet/{fleet}/agent/InstallStreamtimeAgentWorkflow/`
3. Workflow installs:
   - Streamtime Agent Helm chart
   - Streamtime Operator Helm chart
4. Workflow automatically calls `DiscoveryProbeWorkflow` to verify agent connection
5. Discovery probe updates `FleetAgentConnection` record
6. User sees real-time progress via `WorkflowStatusDisplay` component
7. On success: User is redirected to fleet detail page
8. On failure: Error is shown with retry option

**Duration**: ~2-5 minutes

#### Option B: Manual Installation (Advanced)

**What Happens:**
1. User clicks "Install Manually" button
2. System shows `ManualInstallWizard` component with 4 steps:

**Step 1: Get Configuration**
- Fetches bootstrap config from backend
- Shows key configuration values
- User clicks "Next"

**Step 2: Install Agent Helm Chart**
- Shows Helm install command with all --set flags
- Copy-to-clipboard button
- User runs command in their terminal
- User checks "I've completed this step"
- User clicks "Next"

**Step 3: Install Operator Helm Chart**
- Shows operator Helm install command
- Copy-to-clipboard button
- User runs command in their terminal
- User checks "I've completed this step"
- User clicks "Next"

**Step 4: Verify Installation**
- User clicks "Verify Agent Connection"
- System calls `POST /organizations/{org}/fleet/{fleet}/agent/connection/verify/`
- Triggers `DiscoveryProbeWorkflow`
- Shows real-time verification progress
- On success: Redirects to fleet detail page
- On failure: Shows troubleshooting tips with retry

**Duration**: ~5-10 minutes

### 3. Fleet Detail Page

**Page**: `InfrastructureDetailPage.js`

#### Agent Status Summary (Top of Page)

**If No Agent Connected:**
- Warning alert: "No Streamtime Agent Connected"
- Message: "Install the Streamtime Agent to enable fleet management capabilities"

**If Agent Connected:**
- Compact status card showing:
  - Green "Connected" badge
  - Agent version
  - Last discovery probe timestamp

#### Streamtime Agent Tab

Full agent status page showing:
- Connection status badge
- Agent version, operator version, Helm chart version
- Installation method (automatic/manual)
- Connected timestamp
- Last discovery probe timestamp
- Cluster information from discovery probe:
  - Kubernetes version
  - Cloud provider
  - Node count, total CPU, total RAM
- "Refresh Metadata" button
- Expandable "Full Discovery Results" section (JSON)

## Backend APIs

### Bootstrap Configuration
```bash
GET /organizations/{org}/fleet/{fleet}/agent/bootstrap/
```

Returns:
- Orchestrator settings (address, server name, namespace)
- Fleet-specific task queue
- API key
- TLS configuration
- Streamtime URIs
- Default Helm values

### Agent Connection Status
```bash
GET /organizations/{org}/fleet/{fleet}/agent/connection/
```

Returns:
- `connected`: boolean
- `agent_version`: string
- `operator_version`: string
- `helm_chart_version`: string
- `discovery_probe_metadata`: object
- `last_discovery_probe_at`: timestamp
- `installation_method`: "automatic" | "manual"

### Verify Agent Connection
```bash
POST /organizations/{org}/fleet/{fleet}/agent/connection/verify/
```

Triggers `DiscoveryProbeWorkflow` and returns:
- `workflow_id`: string
- `run_id`: string
- `status`: "dispatched"
- `message`: string

### Install Agent
```bash
POST /organizations/{org}/fleet/{fleet}/agent/InstallStreamtimeAgentWorkflow/
```

Body:
```json
{
  "registry_url": "registry:5000",
  "image_tag": "latest",
  "namespace": "streamtime-agent"
}
```

Returns:
- `workflow_id`: string
- `run_id`: string
- `status`: "dispatched"
- `task_queue`: "fleet-manager-tasks"
- `fleet_task_queue`: "/organizations/{org}/fleet/{fleet}/agent-tasks"

## Workflow Sequence

### Automatic Installation Workflow

1. **InstallStreamtimeAgentWorkflow** (Parent - runs on `fleet-manager-tasks`)
   - Fetches fleet details and kubeconfig from backend
   - Gets dynamic Helm values from `TokenActivities`
   - Installs streamtime-agent-helm chart (via HelmActivities)
   - Installs streamtime-operator-helm chart (via HelmActivities)
   - **Calls DiscoveryProbeWorkflow** (Child - runs on fleet-specific task queue)
   - Returns success with verification result

2. **DiscoveryProbeWorkflow** (Child - runs on `/organizations/{org}/fleet/{fleet}/agent-tasks`)
   - Executes Go child workflow on agent
   - Collects cluster information
   - Returns discovery probe results
   - Command audit updates `FleetAgentConnection` automatically

### Agent Connection Update

When `DiscoveryProbeWorkflow` completes with status="completed":
1. Command audit handler detects completion
2. Extracts fleet_id from workflow ID
3. Calls `AgentConnectionService.update_agent_connection()`
4. Updates `FleetAgentConnection` record with:
   - `connected = True`
   - `connected_at = now()`
   - `discovery_probe_metadata = result`
   - `last_discovery_probe_at = now()`
   - `agent_version` from discovery result

## Database Models

### FleetAgentConnection
Tracks agent connection status per fleet:
- One-to-one relationship with Fleet
- Stores versions, metadata, timestamps
- Updated automatically by discovery probe
- Idempotent - handles repeated probes

### Registry (Future)
Container/artifact registries with authentication

### SoftwareCatalog (Future)
Software version tracking across registries

## Components

### Frontend Components Created

1. **AgentInstallationWizard.js** - Post-creation wizard with automatic/manual options
2. **ManualInstallWizard.jsx** - Multi-step guided installation UI
3. **BootstrapInstructions.jsx** - Templated installation commands
4. **AgentStatusCard.jsx** - Reusable agent status display (compact and full views)
5. **WorkflowStatusDisplay.jsx** - Real-time workflow progress (already existed)

### Backend Services Created

1. **AgentConnectionService** - Manages connection status and metadata
2. **AgentTasksService** - Dispatches agent workflows (already existed, enhanced)

### Backend Views Created

1. **BootstrapConfigView** - Returns bootstrap configuration
2. **AgentConnectionView** - Returns connection status
3. **AgentConnectionVerifyView** - Triggers verification workflow

## Testing

### Quick Test Flow

1. **Create BYOK Fleet**:
   - Go to `/kubernetes-fleet/create`
   - Select BYOK provider
   - Upload kubeconfig
   - Submit

2. **Automatic Installation**:
   - After creation, you'll be redirected to agent installation wizard
   - Click "Install Automatically"
   - Watch progress in real-time
   - Wait for verification to complete
   - You'll be redirected to fleet detail page

3. **Verify Agent Status**:
   - Go to "Streamtime Agent" tab
   - See connection status, versions, and cluster info
   - Click "Refresh Metadata" to run another discovery probe

### Manual Test with cURL

See `docs/BYOK_BOOTSTRAP_SMOKE_TESTS.md` for comprehensive API testing commands.

## Configuration

### Environment Variables

**Backend & Temporal Worker** (`docker-compose.yaml`):
- `STREAMTIME_ADVERTISED_ORCHESTRATOR_ADDRESS` - Primary orchestrator address

These are used by `orchestrator_config.py` to generate bootstrap configuration.

### Task Queues

- **Parent Workflows**: `fleet-manager-tasks` (default)
- **Child Workflows**: `/organizations/{org}/fleet/{fleet}/agent-tasks` (fleet-specific)

## Key Features

✅ **Automatic Installation**: One-click agent installation with verification
✅ **Manual Installation**: Guided step-by-step installation with copy-paste commands
✅ **Real-time Progress**: Live workflow status updates
✅ **Agent Connection Tracking**: Automatic status updates via discovery probe
✅ **Agent Status Display**: Comprehensive agent information on fleet detail page
✅ **Idempotent Operations**: Repeated discovery probes update metadata correctly
✅ **Error Handling**: Proper error messages and retry options
✅ **Multi-tenant**: All operations are org and fleet-scoped

## Next Steps

1. **Test the Flow**: Create a BYOK fleet and test both installation methods
2. **Bootstrap Cluster**: After agent installation, run "Bootstrap the Agent" to install operators
3. **Monitor Status**: Use the Streamtime Agent tab to monitor connection and metadata
4. **Software Catalog**: Implement software catalog APIs for version management (deferred)

## Files Modified/Created

### Backend
- ✅ `core/models.py` - Added Registry, FleetAgentConnection, SoftwareCatalog models
- ✅ `core/views/fleet/agent_tasks.py` - Added BootstrapConfigView
- ✅ `core/views/fleet/agent_connection.py` - Added connection API views
- ✅ `core/services/agent_connection.py` - Added connection service
- ✅ `core/services/agent_tasks.py` - Added get_bootstrap_config method
- ✅ `core/serializers.py` - Added AgentConnectionSerializer
- ✅ `core/views/fleet/commands.py` - Added discovery probe integration
- ✅ `fleet_provider/byok_provider.py` - Updated advanced config
- ✅ `fleet_manager/urls.py` - Added new routes

### Orchestrator
- ✅ `workflows/install_streamtime_agent.py` - Already had discovery probe verification
- ✅ `utils/orchestrator_config.py` - Updated env var handling

### Frontend
- ✅ `pages/AgentInstallationWizard.js` - Post-creation wizard
- ✅ `components/AgentTasks/ManualInstallWizard.jsx` - Manual installation UI
- ✅ `components/AgentTasks/BootstrapInstructions.jsx` - Installation instructions
- ✅ `components/AgentTasks/AgentStatusCard.jsx` - Status display component
- ✅ `services/agentTasksService.js` - Added bootstrap and connection methods
- ✅ `pages/InfrastructureDetailPage.js` - Agent tab and summary already in place
- ✅ `pages/KubernetesFleetCreate.js` - Redirect already in place
- ✅ `config/routes.js` - Route already configured

### Documentation
- ✅ `docs/BYOK_BOOTSTRAP_IMPLEMENTATION.md` - Implementation guide
- ✅ `docs/BYOK_BOOTSTRAP_SMOKE_TESTS.md` - API test commands
- ✅ `docs/BYOK_AGENT_INSTALLATION_FLOW.md` - Complete flow documentation
- ✅ `scripts/test-bootstrap-apis.sh` - Automated test script

## Ready for Testing! 🚀

The complete BYOK agent installation flow is now implemented and ready for end-to-end testing.

