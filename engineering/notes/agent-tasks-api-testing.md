# Agent Tasks API Testing

This document contains cURL commands for testing the agent task APIs.

## Prerequisites

- Backend running at `https://api.streamtime.local:8443`
- Valid authentication token (OAuth token from Keycloak)
- Organization identifier: `root`
- Fleet identifier: `byok-test`

## Authentication

First, get an authentication token using the `get-root-token.sh` script:

```bash
# Get root organization token from Keycloak
TOKEN=$(./scripts/get-root-token.sh 2>&1 | grep "^Bearer " | head -1 | sed 's/^Bearer //')

# Verify token was extracted
echo "Token extracted (first 50 chars): ${TOKEN:0:50}..."

# Or export it for use in subsequent commands
export TOKEN=$(./scripts/get-root-token.sh 2>&1 | grep "^Bearer " | head -1 | sed 's/^Bearer //')
```

The token should be included in the `Authorization` header for all API requests.

## Base URL

```
https://api.streamtime.local:8443
```

## API Endpoints

### 1. Install Streamtime Agent

**Endpoint:** `POST /organizations/{org_identifier}/fleet/{fleet_id}/agent/InstallStreamtimeAgentWorkflow/`

**cURL Command:**
```bash
curl -X POST \
  "https://api.streamtime.local:8443/organizations/root/fleet/byok-test/agent/InstallStreamtimeAgentWorkflow/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "registry_url": "registry:5000",
    "image_tag": "latest",
    "namespace": "streamtime-agent"
  }' \
  -k -v
```

**Expected Response:**
```json
{
  "workflow_id": "/organizations/root/fleet/byok-test/command/InstallStreamtimeAgentWorkflow",
  "run_id": "uuid-here",
  "status": "dispatched",
  "task_queue": "/organizations/root/fleet/byok-test/agent-tasks"
}
```

### 2. Update Streamtime Agent

**Endpoint:** `POST /organizations/{org_identifier}/fleet/{fleet_id}/agent/UpdateStreamtimeAgentWorkflow/`

**cURL Command:**
```bash
curl -X POST \
  "https://api.streamtime.local:8443/organizations/root/fleet/byok-test/agent/UpdateStreamtimeAgentWorkflow/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "update_types": ["config"],
    "agent": {
      "chart": "streamtime-agent",
      "version": "latest"
    }
  }' \
  -k -v
```

### 3. Refresh Metadata (Discovery Probe)

**Endpoint:** `POST /organizations/{org_identifier}/fleet/{fleet_id}/agent/DiscoveryProbeWorkflow/`

**cURL Command:**
```bash
curl -X POST \
  "https://api.streamtime.local:8443/organizations/root/fleet/byok-test/agent/DiscoveryProbeWorkflow/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}' \
  -k -v
```

## Testing Notes

### Common Issues

1. **401 Unauthorized**: Check that the token is valid and included in the Authorization header
2. **404 Not Found**: Verify the organization and fleet identifiers are correct
3. **400 Bad Request**: Check the request body format and required fields
4. **502 Bad Gateway**: Backend may have crashed - check backend logs
5. **OIDC_FETCH_ERROR**: Kong Gateway OIDC fetch error - 5XX errors are no longer cached, so retry should work

### Cache Behavior

The Kong Gateway plugin has been updated to prevent caching of 5XX errors:
- **5XX errors**: Return `nil` from cache functions, preventing error caching
- **4XX errors**: Can be cached briefly (client errors)
- **Network errors**: Return `nil` to prevent caching
- **Successful responses (200)**: Cached with configured TTL

This ensures that transient server errors don't get cached and subsequent requests will retry.

### Debugging

To see full request/response details, use `-v` flag:
```bash
curl -v -X POST ...
```

To see only headers:
```bash
curl -i -X POST ...
```

To save response to file:
```bash
curl -X POST ... -o response.json
```

## Test Results

### Install Streamtime Agent - 2025-12-01

**Get Token:**
```bash
TOKEN=$(./scripts/get-root-token.sh 2>&1 | grep "^Bearer " | head -1 | sed 's/^Bearer //')
```

**Request:**
```bash
curl -X POST \
  'https://api.streamtime.local:8443/organizations/root/fleet/byok-test/agent/InstallStreamtimeAgentWorkflow/' \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  --data-raw '{
    "registry_url": "registry:5000",
    "image_tag": "latest",
    "namespace": "streamtime-agent"
  }' \
  -k -i
```

**Response:**
```json
{
  "workflow_id": "/organizations/root/fleet/byok-test/command/InstallStreamtimeAgentWorkflow",
  "run_id": "019ada9b-71b0-7a61-bd5a-9add25f73124",
  "status": "dispatched",
  "task_queue": "/organizations/root/fleet/byok-test/agent-tasks"
}
```

**Status:** PASS ✅
**Notes:** 
- Token extraction works correctly
- OIDC error caching fix resolved the 401 errors
- Validation fix resolved the 400 errors (not adding organization/fleet_id to InstallStreamtimeAgentInput)
- Fleet-specific task queue is being generated correctly: `/organizations/root/fleet/byok-test/agent-tasks`
- Workflow dispatched successfully with run_id

