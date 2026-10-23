# BYOK Bootstrap & Agent Connection - Smoke Tests

## Prerequisites

```bash
# Get authentication token
TOKEN=$(./scripts/get-root-token.sh)

# Or manually set if you have a token
export TOKEN="your-token-here"

# Test variables
export ORG_ID="root"
export FLEET_ID="byok-test"  # Replace with your actual fleet ID
```

## 1. Bootstrap Configuration API

### Get Bootstrap Config
```bash
curl -X GET \
  "https://api.streamtime.local:8443/organizations/${ORG_ID}/fleet/${FLEET_ID}/agent/bootstrap/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -k -v
```

**Expected Response** (200 OK):
```json
{
  "orchestrator_address": "fleet-manager-gateway:8443",
  "orchestrator_server_name": "orchestrator.streamtime.local",
  "orchestrator_namespace": "default",
  "orchestrator_task_queue": "/organizations/root/fleet/byok-test/agent-tasks",
  "orchestrator_api_key": "dev-agent-key",
  "orchestrator_tls_enabled": "true",
  "orchestrator_tls_skip_verify": "true",
  "orchestrator_tls_ca_filename": "streamtime.local.crt",
  "streamtime_uri": "https://api.streamtime.local:8443",
  "streamtime_fleet_uri": "/organizations/root/fleet/byok-test/",
  "agent_identity": "streamtime-agent",
  "agent_runtime": "kubernetes",
  "controller_enabled": "false",
  "namespace": "streamtime-agent",
  "helm_values": {
    "replicaCount": 1,
    "image": {
      "repository": "streamtime/streamtime-agent",
      "tag": "latest",
      "pullPolicy": "IfNotPresent"
    },
    "streamtime": {
      "orchestrator": {
        "address": "fleet-manager-gateway:8443",
        "serverName": "orchestrator.streamtime.local",
        "namespace": "default",
        "taskQueue": "/organizations/root/fleet/byok-test/agent-tasks",
        "apiKey": "dev-agent-key",
        "tls": {
          "enabled": true,
          "skipVerify": true,
          "caFileName": "streamtime.local.crt"
        }
      },
      "uri": "https://api.streamtime.local:8443",
      "fleetURI": "/organizations/root/fleet/byok-test/"
    },
    "agent": {
      "identity": "streamtime-agent",
      "runtime": "kubernetes"
    },
    "controller": {
      "enabled": false
    }
  }
}
```

## 2. Agent Connection API

### Get Agent Connection Status
```bash
curl -X GET \
  "https://api.streamtime.local:8443/organizations/${ORG_ID}/fleet/${FLEET_ID}/agent/connection/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -k -v
```

**Expected Response (No Agent Connected)** (200 OK):
```json
{
  "connected": false,
  "fleet": "byok-test",
  "organization": "root"
}
```

**Expected Response (Agent Connected)** (200 OK):
```json
{
  "id": "uuid-here",
  "organization": "root",
  "fleet": "byok-test",
  "connected": true,
  "connected_at": "2024-12-02T10:30:00Z",
  "agent_version": "v1.0.0",
  "operator_version": "v1.0.0",
  "helm_chart_version": "1.0.0",
  "discovery_probe_metadata": {
    "agent_version": "v1.0.0",
    "kubernetes_version": "v1.28.0",
    "cloud_provider": "kind",
    "nodes": {
      "count": 3,
      "total_cpu": "12",
      "total_ram": "32Gi"
    }
  },
  "last_discovery_probe_at": "2024-12-02T10:30:00Z",
  "last_streamtime_info_at": "2024-12-02T10:30:00Z",
  "installation_method": "automatic",
  "created_at": "2024-12-02T10:00:00Z",
  "updated_at": "2024-12-02T10:30:00Z"
}
```

### Verify Agent Connection (Trigger Discovery Probe)
```bash
curl -X POST \
  "https://api.streamtime.local:8443/organizations/${ORG_ID}/fleet/${FLEET_ID}/agent/connection/verify/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -k -v
```

**Expected Response** (201 Created):
```json
{
  "workflow_id": "/organizations/root/fleet/byok-test/command/DiscoveryProbeWorkflow",
  "run_id": "019adaa0-dae0-7483-8661-b3724434d657",
  "status": "dispatched",
  "message": "Discovery probe workflow started. Connection status will be updated when probe completes."
}
```

## 3. Agent Task APIs (Existing - for reference)

### Install Streamtime Agent
```bash
curl -X POST \
  "https://api.streamtime.local:8443/organizations/${ORG_ID}/fleet/${FLEET_ID}/agent/InstallStreamtimeAgentWorkflow/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "registry_url": "registry:5000",
    "image_tag": "latest",
    "namespace": "streamtime-agent"
  }' \
  -k -v
```

**Expected Response** (201 Created):
```json
{
  "workflow_id": "/organizations/root/fleet/byok-test/command/InstallStreamtimeAgentWorkflow",
  "run_id": "019adaa0-dae0-7483-8661-b3724434d657",
  "status": "dispatched",
  "task_queue": "fleet-manager-tasks",
  "fleet_task_queue": "/organizations/root/fleet/byok-test/agent-tasks"
}
```

### Update Streamtime Agent
```bash
curl -X POST \
  "https://api.streamtime.local:8443/organizations/${ORG_ID}/fleet/${FLEET_ID}/agent/UpdateStreamtimeAgentWorkflow/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "target": "worker",
    "registry_url": "registry:5000",
    "update_types": ["agent"],
    "agent": {
      "image_tag": "v1.0.1"
    }
  }' \
  -k -v
```

### Refresh Metadata (Discovery Probe)
```bash
curl -X POST \
  "https://api.streamtime.local:8443/organizations/${ORG_ID}/fleet/${FLEET_ID}/agent/DiscoveryProbeWorkflow/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}' \
  -k -v
```

## 4. Command Status API (Check Workflow Results)

### Get Command Status by Run ID
```bash
# Use the run_id from any of the above workflow dispatches
export RUN_ID="019adaa0-dae0-7483-8661-b3724434d657"

curl -X GET \
  "https://api.streamtime.local:8443/organizations/${ORG_ID}/commands/${RUN_ID}/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -k -v
```

**Expected Response** (200 OK):
```json
{
  "id": "uuid-here",
  "organization": "root",
  "command_handler": "DiscoveryProbeWorkflow",
  "command_aggregate": "/organizations/root/fleet/byok-test/command/DiscoveryProbeWorkflow",
  "command_id": "019adaa0-dae0-7483-8661-b3724434d657",
  "status": "completed",
  "request": {},
  "result": {
    "result": {
      "agent_version": "v1.0.0",
      "kubernetes_version": "v1.28.0",
      "cloud_provider": "kind",
      "nodes": {
        "count": 3,
        "total_cpu": "12",
        "total_ram": "32Gi"
      }
    }
  },
  "start": "2024-12-02T10:30:00Z",
  "end": "2024-12-02T10:31:00Z",
  "created_at": "2024-12-02T10:30:00Z"
}
```

## 5. Test Sequence for Full Flow

### Scenario 1: Automatic Bootstrap (with kubeconfig)

```bash
# 1. Install agent
curl -X POST \
  "https://api.streamtime.local:8443/organizations/${ORG_ID}/fleet/${FLEET_ID}/agent/InstallStreamtimeAgentWorkflow/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"registry_url": "registry:5000", "image_tag": "latest", "namespace": "streamtime-agent"}' \
  -k | jq -r '.run_id' > /tmp/install_run_id.txt

# 2. Wait a few seconds for installation
sleep 10

# 3. Check installation status
INSTALL_RUN_ID=$(cat /tmp/install_run_id.txt)
curl -X GET \
  "https://api.streamtime.local:8443/organizations/${ORG_ID}/commands/${INSTALL_RUN_ID}/" \
  -H "Authorization: Bearer $TOKEN" \
  -k | jq '.status'

# 4. Check agent connection (should be connected after successful install)
curl -X GET \
  "https://api.streamtime.local:8443/organizations/${ORG_ID}/fleet/${FLEET_ID}/agent/connection/" \
  -H "Authorization: Bearer $TOKEN" \
  -k | jq '.connected'

### Scenario 2: Manual Bootstrap (without kubeconfig)

```bash
# 1. Get bootstrap configuration
curl -X GET \
  "https://api.streamtime.local:8443/organizations/${ORG_ID}/fleet/${FLEET_ID}/agent/bootstrap/" \
  -H "Authorization: Bearer $TOKEN" \
  -k | jq '.'

# 2. User installs agent manually using the instructions
# (This happens outside the system)

# 3. User clicks "I've completed installation" - triggers verification
curl -X POST \
  "https://api.streamtime.local:8443/organizations/${ORG_ID}/fleet/${FLEET_ID}/agent/connection/verify/" \
  -H "Authorization: Bearer $TOKEN" \
  -k | jq -r '.run_id' > /tmp/verify_run_id.txt

# 4. Wait for verification to complete
sleep 10

# 5. Check verification status
VERIFY_RUN_ID=$(cat /tmp/verify_run_id.txt)
curl -X GET \
  "https://api.streamtime.local:8443/organizations/${ORG_ID}/commands/${VERIFY_RUN_ID}/" \
  -H "Authorization: Bearer $TOKEN" \
  -k | jq '.status'

# 6. Check agent connection (should be connected after successful verification)
curl -X GET \
  "https://api.streamtime.local:8443/organizations/${ORG_ID}/fleet/${FLEET_ID}/agent/connection/" \
  -H "Authorization: Bearer $TOKEN" \
  -k | jq '.'
```

## 6. Error Cases to Test

### Non-existent Fleet
```bash
curl -X GET \
  "https://api.streamtime.local:8443/organizations/${ORG_ID}/fleet/non-existent-fleet/agent/bootstrap/" \
  -H "Authorization: Bearer $TOKEN" \
  -k -v
```

**Expected Response** (404 Not Found):
```json
{
  "detail": "Fleet 'non-existent-fleet' not found for organization 'root'"
}
```

### Non-existent Organization
```bash
curl -X GET \
  "https://api.streamtime.local:8443/organizations/non-existent-org/fleet/${FLEET_ID}/agent/bootstrap/" \
  -H "Authorization: Bearer $TOKEN" \
  -k -v
```

**Expected Response** (404 Not Found):
```json
{
  "detail": "Organization 'non-existent-org' not found"
}
```

### Invalid Authentication
```bash
curl -X GET \
  "https://api.streamtime.local:8443/organizations/${ORG_ID}/fleet/${FLEET_ID}/agent/bootstrap/" \
  -H "Authorization: Bearer invalid-token" \
  -k -v
```

**Expected Response** (401 Unauthorized)

## 7. Database Verification

### Check FleetAgentConnection Records
```bash
# Connect to database
docker exec -it db psql -U fleetmanager -d fleetmanager

# Query agent connections
SELECT 
  id, 
  organization_id, 
  fleet_id, 
  connected, 
  connected_at, 
  agent_version, 
  installation_method,
  last_discovery_probe_at
FROM core_fleetagentconnection;

# Exit
\q
```

### Check Registry Records
```sql
SELECT 
  id, 
  identifier, 
  name, 
  registry_url, 
  registry_type, 
  is_public
FROM core_registry;
```

### Check SoftwareCatalog Records
```sql
SELECT 
  id, 
  name, 
  software_type, 
  version, 
  status, 
  registry_id
FROM core_softwarecatalog;
```

## 8. Cleanup Commands

### Delete Agent Connection (if needed for testing)
```bash
# This would need to be done via database or Django admin
docker exec -it db psql -U fleetmanager -d fleetmanager -c \
  "DELETE FROM core_fleetagentconnection WHERE fleet_id = (SELECT id FROM core_fleet WHERE identifier = '${FLEET_ID}');"
```

## Test Results Checklist

- [ ] Bootstrap config endpoint returns correct values
- [ ] Agent connection status returns "not connected" initially
- [ ] Agent connection verify triggers discovery probe
- [ ] Discovery probe completion updates agent connection
- [ ] Agent connection status shows "connected" after probe
- [ ] Discovery probe metadata is stored correctly
- [ ] Install agent workflow dispatches successfully
- [ ] Bootstrap workflow dispatches successfully
- [ ] Update agent workflow dispatches successfully
- [ ] Command status API returns workflow results
- [ ] Error cases return appropriate status codes
- [ ] Database records are created correctly

## Notes

- All endpoints require valid authentication token
- Use `-k` flag to skip SSL verification for self-signed certificates
- Replace `${ORG_ID}` and `${FLEET_ID}` with actual values
- Run `./scripts/get-root-token.sh` to get a valid token
- Check workflow status via command API using the returned `run_id`

