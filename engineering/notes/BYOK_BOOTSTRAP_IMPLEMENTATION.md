# BYOK Bootstrap Rationalization Implementation

## Overview

This document describes the implementation of BYOK (Bring Your Own Kubernetes) bootstrap rationalization and agent connection tracking features.

## Backend Implementation

### 1. Database Models

#### Registry Model
**File**: `fleet-manager-backend/core/models.py`

Represents container/artifact registries with authentication configuration.

**Fields**:
- `identifier`: Unique registry identifier (e.g., "ghcr", "docker-hub")
- `name`: Human-readable name
- `registry_url`: Base registry URL
- `registry_type`: Type ("oci", "docker", "helm_repo")
- `auth_config`: JSON field for authentication (none, username_password, token, oauth)
- `is_public`: Whether registry allows anonymous access
- `rate_limit_info`: Rate limit tracking (JSON)

**Note**: Registries are global (not org-scoped).

#### FleetAgentConnection Model
**File**: `fleet-manager-backend/core/models.py`

Tracks Streamtime Agent connection status per fleet.

**Fields**:
- `fleet`: OneToOne to Fleet
- `organization`: ForeignKey to Organization
- `connected`: Boolean connection status
- `connected_at`: When agent was first connected
- `agent_version`: Agent version from StreamtimeInfo
- `operator_version`: Operator Helm chart version
- `helm_chart_version`: Chart version
- `discovery_probe_metadata`: Last discovery probe result (JSON)
- `last_discovery_probe_at`: Last probe timestamp
- `last_streamtime_info_at`: Last StreamtimeInfo timestamp
- `installation_method`: "automatic" or "manual"

#### SoftwareCatalog Model
**File**: `fleet-manager-backend/core/models.py`

Tracks software versions (OCI artifacts, Helm charts, containers) across registries.

**Fields**:
- `organization`: ForeignKey (nullable for global entries)
- `registry`: ForeignKey to Registry
- `name`: Software name
- `software_type`: "oci_artifact", "helm_chart", "container_image"
- `repository_path`: Path within registry
- `version`: Version string
- `version_metadata`: Additional version info (JSON)
- `published_at`: Publication timestamp
- `status`: "active", "deprecated", "unsupported", "preview"
- `status_remarks`: Deprecation notes
- `digest`: OCI digest for immutable references
- `metadata`: Additional metadata (JSON)

### 2. API Endpoints

#### Bootstrap Configuration
**Endpoint**: `GET /organizations/{org}/fleet/{fleet}/agent/bootstrap/`

Returns bootstrap configuration for manual agent installation:
- Orchestrator address and server name
- Task queue (fleet-specific)
- API key
- TLS settings
- Streamtime URIs
- Default Helm values

**Implementation**: `fleet-manager-backend/core/views/fleet/agent_tasks.py::BootstrapConfigView`

#### Agent Connection Status
**Endpoint**: `GET /organizations/{org}/fleet/{fleet}/agent/connection/`

Returns current agent connection status for a fleet.

**Implementation**: `fleet-manager-backend/core/views/fleet/agent_connection.py::AgentConnectionView`

#### Agent Connection Verification
**Endpoint**: `POST /organizations/{org}/fleet/{fleet}/agent/connection/verify/`

Triggers DiscoveryProbeWorkflow to verify agent connection.

**Implementation**: `fleet-manager-backend/core/views/fleet/agent_connection.py::AgentConnectionVerifyView`

### 3. Services

#### AgentConnectionService
**File**: `fleet-manager-backend/core/services/agent_connection.py`

Manages agent connection status and metadata.

**Methods**:
- `get_agent_connection(fleet)`: Get current connection status
- `mark_agent_connected(fleet, installation_method, versions)`: Mark as connected
- `mark_agent_disconnected(fleet)`: Mark as disconnected
- `update_agent_connection(fleet, discovery_result, streamtime_info_result)`: Update with probe results

### 4. Discovery Probe Integration

**File**: `fleet-manager-backend/core/views/fleet/commands.py`

When `DiscoveryProbeWorkflow` completes successfully:
1. Extracts fleet_id from workflow ID
2. Retrieves discovery probe result
3. Updates FleetAgentConnection with metadata
4. Marks agent as connected

**Implementation**: Added to both `AgentCommandSendView.post()` and `AgentCommandDetailView.patch()`.

### 5. BYOK Provider Updates

**File**: `fleet-manager-backend/fleet_provider/byok_provider.py`

#### Advanced Configuration Schema
Updated `get_advanced_configs()` to include:
- `bootstrap_method`: Choice between "automatic" and "manual"
- `kubeconfig`: Required for automatic, optional for manual

#### Validation
Updated `validate_advanced_configs()` to:
- Skip kubeconfig validation for manual bootstrap
- Require and validate kubeconfig for automatic bootstrap

### 6. Environment Configuration

#### Orchestrator Config
**File**: `fleet-manager-orchestrator/utils/orchestrator_config.py`

Updated `get_orchestrator_address()` to use:
1. Primary: `STREAMTIME_ADVERTISED_ORCHESTRATOR_ADDRESS`
2. Default: `"fleet-manager-gateway:8443"`

#### Docker Compose
**File**: `docker-compose.yaml`

Added environment variables to both `temporal-worker` and `backend` services:
- `STREAMTIME_ADVERTISED_ORCHESTRATOR_ADDRESS`

## Database Migration

**Migration**: `core/migrations/0080_add_agent_connection_and_catalog_models.py`

Created and applied successfully. Includes:
- Registry model
- FleetAgentConnection model
- SoftwareCatalog model
- Indexes for performance
- Unique constraints

## Frontend Implementation (Pending)

The following frontend tasks remain:

### 1. Fleet Creation UI Update
**File**: `fleet-manager-frontend/src/pages/KubernetesFleetCreate.js`

Add bootstrap method choice in advanced config step for BYOK:
- Radio group: "Automatic (with kubeconfig)" or "Manual (install yourself)"
- Conditional kubeconfig upload (only for automatic)
- Display default Helm values for manual
- Link to bootstrap instructions

### 2. Bootstrap Instructions Component
**File**: `fleet-manager-frontend/src/components/AgentTasks/BootstrapInstructions.jsx` (NEW)

Display templated installation instructions:
- Helm install commands with --set flags
- kubectl apply YAML manifests
- Copy-to-clipboard functionality
- Uses bootstrap config from backend API

### 3. Bootstrap Tab
**File**: `fleet-manager-frontend/src/pages/InfrastructureDetailPage.js`

Add Bootstrap tab for BYOK fleets without connected agent:
- Show bootstrap instructions
- Display default Helm values
- "I've completed the installation" button
- Trigger DiscoveryProbeWorkflow on completion
- Show WorkflowStatusDisplay component
- Handle success/failure

### 4. Streamtime Agent Tab
**File**: `fleet-manager-frontend/src/pages/InfrastructureDetailPage.js`

Add Streamtime Agent tab (separate from Bootstrap):
- Full agent status and information
- Connection status badge
- Version information (agent, operator, Helm chart)
- Discovery probe metadata
- Operator installation status
- "Refresh Metadata" button

### 5. Agent Status Summary
**File**: `fleet-manager-frontend/src/pages/InfrastructureDetailPage.js`

Add summary section on fleet detail page:
- Warning if no agent connected (link to Bootstrap/Agent tab)
- Compact status card if connected:
  - Connection status badge
  - Agent version
  - Operator version
  - Last discovery probe timestamp
  - Link to full details

## Testing

### Backend Testing
1. Test bootstrap config endpoint returns correct values
2. Test agent connection status tracking
3. Test discovery probe integration
4. Test BYOK provider validation (automatic vs manual)

### Frontend Testing (Pending)
1. Test bootstrap method selection in fleet creation
2. Test manual bootstrap instructions display
3. Test agent connection verification flow
4. Test agent status display

## API Documentation

All endpoints are documented with OpenAPI/Swagger:
- Bootstrap config endpoint
- Agent connection endpoints
- Command audit endpoints

Access Swagger UI at: `https://api.streamtime.local:8443/api/schema/swagger-ui/`

## Future Enhancements

1. **Software Catalog Integration**: Complete implementation of software catalog service and APIs for version management
2. **Auto Bootstrap Flow**: Implement automatic verification and operator setup after agent installation
3. **Agent Health Monitoring**: Add periodic health checks and alerting
4. **Multi-Agent Support**: Support multiple agents per fleet (if needed)
5. **Agent Upgrade Management**: Automated agent upgrade workflows

