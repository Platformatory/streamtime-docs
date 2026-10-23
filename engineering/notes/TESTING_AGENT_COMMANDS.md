# Agent Commands Testing Plan - Step by Step

This document provides a **manual step-by-step testing plan** for verifying the agent command system. 

## ⚠️ Important: Manual Execution Required

**DO NOT run all steps at once.** This is a **manual step-by-step process**:

1. **Execute one step at a time**
2. **Verify the results** before proceeding
3. **Wait for operations to complete** (workflows may take time)
4. **Only proceed to the next step** when the current step is successful
5. **Check for errors** at each step before continuing

Each step includes:
- **Purpose**: What this step verifies
- **Commands**: Exact commands to run
- **Expected Output**: What you should see
- **✅ STOP HERE**: Verification point before proceeding

## Prerequisites

- Docker Compose environment running (backend, Temporal, streamtime-agent)
- Kind cluster available or ability to create one
- `kubectl` installed and configured
- `jq` installed for JSON parsing
- Access to Keycloak for authentication

## Important: API Path Format

**⚠️ Note:** All API endpoints accessed through Kong Gateway do **NOT** include the `/api/` prefix in the path.

- ✅ **Correct:** `https://api.streamtime.local:8443/organizations/root/fleet/`
- ❌ **Incorrect:** `https://api.streamtime.local:8443/api/organizations/root/fleet/`

Kong Gateway handles the routing internally, so use paths starting with `/organizations/` directly.

## Important: Manual Step-by-Step Execution

**⚠️ Execute each step manually and verify results before proceeding to the next step.**

Do NOT run all steps at once. Stop after each step, verify the output, and only proceed when the current step is successful.

---

## Step 1: Get Root Organization Token

**Purpose:** Obtain authentication token for API access.

Use the provided script to obtain an authentication token for the root organization:

```bash
./scripts/get-root-token.sh
```

**Expected Output:**
```
Token obtained successfully!

Bearer <token>
```

**Save the token** for use in subsequent API calls:
```bash
export TOKEN=$(./scripts/get-root-token.sh 2>/dev/null | grep "Bearer" | awk '{print $2}')
export AUTH_HEADER="Bearer $TOKEN"
```

**Verification:**
```bash
# Test token is valid
# Note: API path does NOT include /api/ prefix
curl -k -H "Authorization: $AUTH_HEADER" \
  https://api.streamtime.local:8443/organizations/root/
```

**✅ STOP HERE** - Verify you received a valid organization response (JSON with organization details). If successful, proceed to Step 2.

---

## Step 2: Ensure Kind Cluster is Running

**Purpose:** Verify or create the kind cluster that will be used for BYOK fleet testing.

Use the dev fleet setup script to create and verify the kind cluster:

```bash
# Check cluster status
./scripts/setup-dev-fleet.sh --status

# If cluster doesn't exist or needs recreation
./scripts/setup-dev-fleet.sh --force-recreate
```

**Verification:**
```bash
# Verify kind cluster is running
kubectl --kubeconfig=assets-staging/byok-local-kind.yaml cluster-info

# Verify cluster nodes
kubectl --kubeconfig=assets-staging/byok-local-kind.yaml get nodes
```

**Expected Output:**
- Cluster should be accessible
- At least one node should be in `Ready` state

**✅ STOP HERE** - Verify cluster is accessible and nodes are ready. If successful, proceed to Step 3.

---

## Step 3: Create BYOK Fleet

**Purpose:** Create a BYOK fleet that will trigger the workflow and agent commands.

**Note:** The script automatically creates the domain `byok-test.streamtime.local` if it doesn't exist.

Create a script to automate BYOK fleet creation:

**Script: `scripts/create-byok-fleet.sh`**

```bash
#!/bin/bash
set -e

# Configuration
KONG_URL="${KONG_URL:-https://api.streamtime.local:8443}"
ORG_ID="${ORG_ID:-root}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-assets-staging/byok-local-kind.yaml}"
FLEET_ID="${FLEET_ID:-byok-test-$(date +%s)}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get token if not set
if [ -z "$TOKEN" ]; then
  TOKEN=$(./scripts/get-root-token.sh 2>/dev/null | grep "Bearer" | awk '{print $2}')
  if [ -z "$TOKEN" ]; then
    echo -e "${RED}Failed to get token${NC}"
    exit 1
  fi
fi

# Verify kubeconfig exists
if [ ! -f "$KUBECONFIG_PATH" ]; then
  echo -e "${RED}Kubeconfig not found at $KUBECONFIG_PATH${NC}"
  echo "Run: ./scripts/setup-dev-fleet.sh --force-recreate"
  exit 1
fi

# Get kubeconfig as base64
KUBECONFIG_B64=$(cat "$KUBECONFIG_PATH" | base64 | tr -d '\n')

echo -e "${YELLOW}Creating BYOK fleet: ${FLEET_ID}${NC}"

# Create BYOK fleet
FLEET_RESPONSE=$(curl -s -k -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  "$KONG_URL/organizations/$ORG_ID/fleet/" \
  -d "{
    \"identifier\": \"$FLEET_ID\",
    \"name\": \"Test BYOK Fleet $FLEET_ID\",
    \"provider\": \"byok\",
    \"tenancy_mode\": \"Shared\",
    \"organization\": \"$ORG_ID\",
    \"domain\": \"streamtime.local\",
    \"advanced_config\": {
      \"kubeconfig\": \"$KUBECONFIG_B64\"
    }
  }")

# Check response
if echo "$FLEET_RESPONSE" | grep -q '"identifier"'; then
  echo -e "${GREEN}✓ Fleet created successfully${NC}"
  echo "$FLEET_RESPONSE" | jq '.' 2>/dev/null || echo "$FLEET_RESPONSE"
  
  # Extract fleet identifier
  ACTUAL_FLEET_ID=$(echo "$FLEET_RESPONSE" | jq -r '.identifier' 2>/dev/null || echo "$FLEET_ID")
  echo "FLEET_ID=$ACTUAL_FLEET_ID" > /tmp/fleet-test.env
  echo "ORG_ID=$ORG_ID" >> /tmp/fleet-test.env
  echo "TOKEN=$TOKEN" >> /tmp/fleet-test.env
  echo -e "${GREEN}Fleet details saved to /tmp/fleet-test.env${NC}"
else
  echo -e "${RED}✗ Failed to create fleet${NC}"
  echo "$FLEET_RESPONSE" | jq '.' 2>/dev/null || echo "$FLEET_RESPONSE"
  exit 1
fi
```

**Usage:**
```bash
chmod +x scripts/create-byok-fleet.sh
./scripts/create-byok-fleet.sh

# Or with custom fleet ID
FLEET_ID="my-test-fleet" ./scripts/create-byok-fleet.sh
```

**✅ STOP HERE** - Verify fleet was created successfully. Check the response shows a valid fleet with status. 

**Save the fleet details:**
```bash
source /tmp/fleet-test.env
echo "FLEET_ID=$FLEET_ID"
echo "ORG_ID=$ORG_ID"
```

If successful, **wait 5-10 seconds** for the workflow to start, then proceed to Step 4.

---

## Step 4: Verify Fleet Creation

**Purpose:** Confirm the fleet exists in Django and check its initial status.

Verify the fleet was created successfully:

```bash
# Load fleet details from previous step
source /tmp/fleet-test.env

# Or set manually
# export FLEET_ID="byok-test-1234567890"
# export ORG_ID="root"
# export TOKEN="<your-token>"

# Get fleet details
curl -s -k -X GET \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/$ORG_ID/fleet/$FLEET_ID/" | jq '.'

# Check fleet status
FLEET_STATUS=$(curl -s -k -X GET \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/$ORG_ID/fleet/$FLEET_ID/" | \
  jq -r '.status')

echo "Fleet Status: $FLEET_STATUS"
```

**Expected Response:**
- Fleet should exist with status "Provisioning" or "Healthy"
- Fleet should have `id`, `identifier`, `provider: "byok"`
- Fleet should have `advanced_config` with kubeconfig

**✅ STOP HERE** - Verify fleet exists and has correct details. Note the fleet status. 

**Expected statuses:**
- `Provisioning` - Workflow has started
- `Healthy` - Workflow completed successfully
- `Error` - Workflow failed (check logs)

If status is `Provisioning` or `Healthy`, proceed to Step 5. If `Error`, check logs and troubleshoot.

---

## Step 5: Check Temporal if Workflow is Running

**Purpose:** Verify the parent workflow (ByokProvider) was started in Temporal.

Verify the parent workflow (ByokProvider) is running in Temporal:

**Method 1: Using Temporal CLI**

```bash
# Get workflow ID (format: /organizations/{org_id}/fleet/{fleet_id}/)
WORKFLOW_ID="/organizations/$ORG_ID/fleet/$FLEET_ID/"

# Check workflow status
docker compose exec temporal temporal workflow show \
  --address temporal:7233 \
  --tls=false \
  --workflow-id "$WORKFLOW_ID"
```

**Method 2: Using Fleet Manager API**

```bash
# Get workflow status via API
curl -s -k -X GET \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/$ORG_ID/workflows/$WORKFLOW_ID/" | jq '.'
```

**Method 3: Using Temporal Web UI**

1. Navigate to `http://localhost:8233` (Temporal Web UI)
2. Search for workflow ID: `/organizations/{org_id}/fleet/{fleet_id}/`
3. Verify workflow status is `RUNNING` or `COMPLETED`

**Expected Output:**
- Workflow should be visible in Temporal
- Status should be `RUNNING` during execution
- Workflow should have execution history showing activities and child workflows

**Verification Checklist:**
- [ ] Workflow exists in Temporal
- [ ] Workflow status is `RUNNING` or `COMPLETED`
- [ ] Workflow has execution history
- [ ] Workflow shows child workflow executions

**✅ STOP HERE** - Verify the parent workflow is running in Temporal. Check the execution history.

**What to look for:**
- Workflow status should be `RUNNING` or `COMPLETED`
- Execution history should show activities being executed
- Look for child workflow executions in the history

If workflow is running and shows activity, **wait 10-30 seconds** for child workflows to start, then proceed to Step 6.

---

## Step 6: Check Streamtime Agent Child Workflow

**Purpose:** Verify the child workflow (BootstrapFleetClusterWorkflow) is running and check agent logs.

Verify the child workflow (BootstrapFleetClusterWorkflow) is running and check agent logs:

**6.1: Check Child Workflow in Temporal**

```bash
# List child workflows (workflows with "agent-tq" task queue)
docker compose exec temporal temporal workflow list \
  --address temporal:7233 \
  --tls=false \
  --task-queue agent-tq

# Or search for specific workflow pattern
docker compose exec temporal temporal workflow list \
  --address temporal:7233 \
  --tls=false \
  --query "WorkflowType='BootstrapFleetClusterWorkflow'"
```

**6.2: Check Streamtime Agent Logs**

```bash
# Check agent container logs
docker compose logs -f streamtime-agent

# Or filter for specific workflow
docker compose logs streamtime-agent | grep -i "BootstrapFleetClusterWorkflow"

# Check for command execution logs
docker compose logs streamtime-agent | grep -i "HelmInstall\|HelmUninstall"
```

**6.3: Check Agent Pod Logs (if running in Kubernetes)**

```bash
# Get agent pod name
AGENT_POD=$(kubectl get pods -n default -l app=streamtime-agent -o jsonpath='{.items[0].metadata.name}')

# View logs
kubectl logs -f $AGENT_POD -n default

# Or check specific workflow
kubectl logs $AGENT_POD -n default | grep -i "BootstrapFleetClusterWorkflow"
```

**Expected Log Output:**
- Agent should show workflow execution logs
- Should see "BootstrapFleetClusterWorkflow" started
- Should see Helm install activities being executed
- Should see command request/response logs

**Verification Checklist:**
- [ ] Child workflow exists in Temporal with task queue "agent-tq"
- [ ] Child workflow status is `RUNNING` or `COMPLETED`
- [ ] Agent logs show workflow execution
- [ ] Agent logs show Helm install/uninstall activities
- [ ] No errors in agent logs

**✅ STOP HERE** - Verify child workflow is running and agent logs show activity.

**What to look for:**
- Child workflow should exist with task queue `agent-tq`
- Agent logs should show workflow execution
- Look for Helm install/uninstall activity in logs

If child workflow is running and agent logs show activity, **wait 30-60 seconds** for commands to be created and executed, then proceed to Step 7.

---

## Step 7: Check Command Requests/Responses in Django

**Purpose:** Verify AgentCommand records were created and updated in Django database.

Verify that AgentCommand records were created and updated in Django:

**7.1: List All Commands for Fleet**

```bash
# Get all commands for the fleet
curl -s -k -X GET \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/$ORG_ID/fleet/$FLEET_ID/commands/" | jq '.'
```

**Expected Response:**
```json
{
  "count": 2,
  "results": [
    {
      "id": "<uuid>",
      "command_class": "HelmInstall",
      "version": "v1",
      "status": "completed",
      "request": {
        "release": "...",
        "namespace": "...",
        "chartName": "..."
      },
      "response": {
        "release": "...",
        "revision": 1
      },
      "workflow_id": "...",
      "command_id": "<run_id>",
      "created_at": "...",
      "started_at": "...",
      "completed_at": "..."
    }
  ]
}
```

**7.2: Get Specific Command Details**

```bash
# Get command by ID (from previous response)
COMMAND_ID="<command-uuid>"

curl -s -k -X GET \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/$ORG_ID/fleet/$FLEET_ID/commands/$COMMAND_ID/" | jq '.'
```

**7.3: Verify Command Status Progression**

```bash
# Monitor command status changes
for i in {1..30}; do
  echo "Check $i:"
  curl -s -k -X GET \
    -H "Authorization: Bearer $TOKEN" \
    "https://api.streamtime.local:8443/organizations/$ORG_ID/fleet/$FLEET_ID/commands/" | \
    jq -r '.results[] | "\(.command_class): \(.status)"'
  echo ""
  sleep 5
done
```

**Expected Command Status Flow:**
1. `pending` - Command created, workflow not started yet
2. `running` - Workflow started, command executing
3. `completed` - Command executed successfully
4. `failed` - Command execution failed (if error occurred)

**7.4: Verify Command Data Integrity**

```bash
# Check that all required fields are present
curl -s -k -X GET \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/$ORG_ID/fleet/$FLEET_ID/commands/" | \
  jq '.results[] | {
    command_class,
    version,
    status,
    has_request: (.request != null),
    has_response: (.response != null),
    has_workflow_id: (.workflow_id != null and .workflow_id != ""),
    has_command_id: (.command_id != null and .command_id != "")
  }'
```

**Verification Checklist:**
- [ ] Commands are created in Django database
- [ ] Commands have correct `command_class` (e.g., "HelmInstall", "HelmUninstall")
- [ ] Commands have correct `version` (e.g., "v1")
- [ ] Commands have `request` payload with correct structure
- [ ] Commands have `response` payload after completion
- [ ] Commands have `workflow_id` pointing to child workflow
- [ ] Commands have `command_id` (run_id) from Temporal
- [ ] Command status progresses: pending → running → completed
- [ ] Commands are associated with correct fleet and organization

**✅ STOP HERE** - Verify all commands are present with correct data. Check status progression.

**If commands are not visible yet:**
- Commands may take 30-60 seconds to appear
- Wait and check again: `sleep 30 && <check command again>`
- Verify the child workflow is still running

**If commands show `pending` status:**
- This is normal initially
- Wait for status to change to `running` then `completed`
- Monitor with: `watch -n 5 '<check command command>'`

If all checks pass, **testing is complete** ✅

---

## Quick Reference: Step-by-Step Commands

**Copy and paste these commands one step at a time. Wait for each step to complete before proceeding.**

### Step 1: Get Token
```bash
export TOKEN=$(./scripts/get-root-token.sh 2>/dev/null | grep "Bearer" | awk '{print $2}')
# Note: API path does NOT include /api/ prefix
curl -k -H "Authorization: Bearer $TOKEN" https://api.streamtime.local:8443/organizations/root/
# ✅ Verify: Should return organization JSON
```

### Step 2: Check Cluster
```bash
./scripts/setup-dev-fleet.sh --status
kubectl --kubeconfig=assets-staging/byok-local-kind.yaml cluster-info
# ✅ Verify: Cluster should be accessible
```

### Step 3: Create Fleet
```bash
./scripts/create-byok-fleet.sh
source /tmp/fleet-test.env
echo "FLEET_ID=$FLEET_ID"
# ✅ Verify: Fleet created successfully, note the FLEET_ID
# ⏳ Wait: 5-10 seconds for workflow to start
```

### Step 4: Verify Fleet
```bash
# Note: API path does NOT include /api/ prefix
curl -s -k -X GET -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/$ORG_ID/fleet/$FLEET_ID/" | jq '.'
# ✅ Verify: Fleet exists with status "Provisioning" or "Healthy"
```

### Step 5: Check Parent Workflow
```bash
WORKFLOW_ID="/organizations/$ORG_ID/fleet/$FLEET_ID/"
docker compose exec temporal temporal workflow show \
  --address temporal:7233 --tls=false --workflow-id "$WORKFLOW_ID"
# ✅ Verify: Workflow exists and is RUNNING
# ⏳ Wait: 10-30 seconds for child workflows to start
```

### Step 6: Check Child Workflow
```bash
# Check child workflows
docker compose exec temporal temporal workflow list \
  --address temporal:7233 --tls=false --task-queue agent-tq

# Check agent logs
docker compose logs streamtime-agent | tail -50
# ✅ Verify: Child workflow exists, agent logs show activity
# ⏳ Wait: 30-60 seconds for commands to be created
```

### Step 7: Check Commands
```bash
# Note: API path does NOT include /api/ prefix
curl -s -k -X GET -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/$ORG_ID/fleet/$FLEET_ID/commands/" | jq '.'

# Monitor command status (optional)
watch -n 5 'curl -s -k -X GET -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/$ORG_ID/fleet/$FLEET_ID/commands/" | \
  jq -r ".results[]? | \"\(.command_class): \(.status)\""'
# ✅ Verify: Commands exist with correct data and status progression
```

---

## Detailed Step-by-Step Instructions

For detailed instructions with explanations, see the sections below:

**Step 1: Get Token**
```bash
export TOKEN=$(./scripts/get-root-token.sh 2>/dev/null | grep "Bearer" | awk '{print $2}')
curl -k -H "Authorization: Bearer $TOKEN" https://api.streamtime.local:8443/organizations/root/
```

**Step 2: Check Cluster**
```bash
./scripts/setup-dev-fleet.sh --status
kubectl --kubeconfig=assets-staging/byok-local-kind.yaml cluster-info
```

**Step 3: Create Fleet**
```bash
./scripts/create-byok-fleet.sh
source /tmp/fleet-test.env
echo "FLEET_ID=$FLEET_ID"
```

**Step 4: Verify Fleet**
```bash
curl -s -k -X GET -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/$ORG_ID/fleet/$FLEET_ID/" | jq '.'
```

**Step 5: Check Parent Workflow**
```bash
WORKFLOW_ID="/organizations/$ORG_ID/fleet/$FLEET_ID/"
docker compose exec temporal temporal workflow show \
  --address temporal:7233 --tls=false --workflow-id "$WORKFLOW_ID"
```

**Step 6: Check Child Workflow**
```bash
docker compose exec temporal temporal workflow list \
  --address temporal:7233 --tls=false --task-queue agent-tq
docker compose logs streamtime-agent | tail -50
```

**Step 7: Check Commands**
```bash
curl -s -k -X GET -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/$ORG_ID/fleet/$FLEET_ID/commands/" | jq '.'
```

---

## Automated Test Script (Optional - Not Recommended for Initial Testing)

**⚠️ Note:** The automated script is provided for convenience, but **manual step-by-step execution is recommended** for initial testing and debugging.

If you want to run all steps automatically (not recommended for first-time testing):

**Script: `scripts/test-agent-commands-e2e.sh`**

**⚠️ Warning:** This script runs all steps automatically. Use only after you've verified each step works manually.

```bash
#!/bin/bash
set -e

# Load configuration
source scripts/test-agent-commands-config.sh

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Agent Commands End-to-End Test ===${NC}"
echo ""

# Step 1: Get token
echo -e "${YELLOW}Step 1: Getting root token...${NC}"
export TOKEN=$(./scripts/get-root-token.sh 2>/dev/null | grep "Bearer" | awk '{print $2}')
if [ -z "$TOKEN" ]; then
  echo -e "${RED}✗ Failed to get token${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Token obtained${NC}"
echo ""

# Step 2: Check kind cluster
echo -e "${YELLOW}Step 2: Checking kind cluster...${NC}"
if ! kubectl --kubeconfig=assets-staging/byok-local-kind.yaml cluster-info &>/dev/null; then
  echo -e "${YELLOW}  Cluster not found, creating...${NC}"
  ./scripts/setup-dev-fleet.sh --force-recreate
fi
echo -e "${GREEN}✓ Cluster ready${NC}"
echo ""

# Step 3: Create fleet
echo -e "${YELLOW}Step 3: Creating BYOK fleet...${NC}"
./scripts/create-byok-fleet.sh
source /tmp/fleet-test.env
echo -e "${GREEN}✓ Fleet created: $FLEET_ID${NC}"
echo ""

# Step 4: Verify fleet
echo -e "${YELLOW}Step 4: Verifying fleet creation...${NC}"
FLEET_STATUS=$(curl -s -k -X GET \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/$ORG_ID/fleet/$FLEET_ID/" | \
  jq -r '.status')
echo -e "${GREEN}✓ Fleet status: $FLEET_STATUS${NC}"
echo ""

# Step 5: Check Temporal workflow
echo -e "${YELLOW}Step 5: Checking Temporal workflow...${NC}"
WORKFLOW_ID="/organizations/$ORG_ID/fleet/$FLEET_ID/"
WORKFLOW_STATUS=$(docker compose exec -T temporal temporal workflow show \
  --address temporal:7233 \
  --tls=false \
  --workflow-id "$WORKFLOW_ID" 2>/dev/null | grep -i "Status:" | head -1 || echo "Not found")
echo -e "${GREEN}✓ Workflow: $WORKFLOW_STATUS${NC}"
echo ""

# Step 6: Check agent child workflow
echo -e "${YELLOW}Step 6: Checking agent child workflow...${NC}"
CHILD_WORKFLOWS=$(docker compose exec -T temporal temporal workflow list \
  --address temporal:7233 \
  --tls=false \
  --task-queue agent-tq 2>/dev/null | grep -i "BootstrapFleetClusterWorkflow" | wc -l || echo "0")
echo -e "${GREEN}✓ Found $CHILD_WORKFLOWS child workflow(s)${NC}"
echo ""

# Step 7: Check commands in Django
echo -e "${YELLOW}Step 7: Checking commands in Django...${NC}"
sleep 10  # Wait for commands to be created
COMMAND_COUNT=$(curl -s -k -X GET \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/$ORG_ID/fleet/$FLEET_ID/commands/" | \
  jq -r '.count // (. | length) // 0')
echo -e "${GREEN}✓ Found $COMMAND_COUNT command(s)${NC}"

if [ "$COMMAND_COUNT" -gt 0 ]; then
  echo ""
  echo -e "${YELLOW}Command Details:${NC}"
  curl -s -k -X GET \
    -H "Authorization: Bearer $TOKEN" \
    "https://api.streamtime.local:8443/organizations/$ORG_ID/fleet/$FLEET_ID/commands/" | \
    jq -r '.results[]? | "  \(.command_class) (\(.version)): \(.status)"'
fi

echo ""
echo -e "${BLUE}=== Test Complete ===${NC}"
echo ""
echo "Fleet ID: $FLEET_ID"
echo "Organization: $ORG_ID"
echo ""
echo "To check commands manually:"
echo "  curl -k -H \"Authorization: Bearer $TOKEN\" \\"
echo "    https://api.streamtime.local:8443/organizations/$ORG_ID/fleet/$FLEET_ID/commands/"
```

---

## Troubleshooting

### Issue: Token not working
- Verify Keycloak is running: `docker compose ps keycloak`
- Check token expiration
- Verify credentials in `scripts/get-root-token.sh`

### Issue: Kind cluster not accessible
- Run: `./scripts/setup-dev-fleet.sh --force-recreate`
- Verify Docker is running
- Check kind cluster: `kind get clusters`

### Issue: Workflow not found in Temporal
- Verify Temporal is running: `docker compose ps temporal`
- Check workflow ID format matches: `/organizations/{org_id}/fleet/{fleet_id}/`
- Check Temporal logs: `docker compose logs temporal`

### Issue: Agent child workflow not running
- Verify streamtime-agent is running: `docker compose ps streamtime-agent`
- Check agent logs: `docker compose logs streamtime-agent`
- Verify agent is connected to Temporal
- Check task queue name matches: `agent-tq`

### Issue: Commands not appearing in Django
- Verify backend is running: `docker compose ps fleet-manager-backend`
- Check backend logs: `docker compose logs fleet-manager-backend`
- Verify `execute_agent_command_child_workflow` is being called
- Check that `create_agent_command_record` activity is executing
- Verify database connection

### Issue: Command status stuck in "pending"
- Check if child workflow started successfully
- Verify `start_child_workflow` completed
- Check Temporal for workflow execution errors
- Verify agent is processing the workflow

---

## Success Criteria

The test is successful when:

1. ✅ Fleet is created successfully
2. ✅ Parent workflow (ByokProvider) is running in Temporal
3. ✅ Child workflow (BootstrapFleetClusterWorkflow) is running in Temporal with task queue "agent-tq"
4. ✅ Agent logs show workflow execution
5. ✅ AgentCommand records are created in Django
6. ✅ Commands have correct request payloads
7. ✅ Commands progress from "pending" → "running" → "completed"
8. ✅ Commands have response payloads after completion
9. ✅ Commands have correct workflow_id and command_id (run_id)
10. ✅ Helm charts are installed in the Kubernetes cluster

---

## Next Steps

After successful testing:

1. Verify Helm releases in cluster:
   ```bash
   kubectl --kubeconfig=assets-staging/byok-local-kind.yaml get helmreleases -A
   helm --kubeconfig=assets-staging/byok-local-kind.yaml list -A
   ```

2. Check fleet metadata for helm_releases:
   ```bash
   curl -s -k -X GET \
     -H "Authorization: Bearer $TOKEN" \
     "https://api.streamtime.local:8443/organizations/$ORG_ID/fleet/$FLEET_ID/" | \
     jq '.metadata.helm_releases'
   ```

3. Clean up test fleet (optional):
   ```bash
   curl -k -X DELETE \
     -H "Authorization: Bearer $TOKEN" \
     "https://api.streamtime.local:8443/organizations/$ORG_ID/fleet/$FLEET_ID/"
   ```

