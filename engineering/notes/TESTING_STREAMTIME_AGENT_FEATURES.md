# Testing Streamtime Agent Features

This document describes the testing procedures for Streamtime agent features, including early failure detection, discovery probe, and streamtime info.

## Testing Rules

**Important**: Always create parent workflows via Temporal CLI. The parent workflows run on the Python worker (task-queue: `fleet-manager-tasks`), which then execute the Go child workflows on the agent (task-queue: `agent-tq`). This ensures proper command auditing in Django.

When testing new Streamtime agent features, follow these procedures:

### 1. Build and Deploy Streamtime Agent

Build and deploy the streamtime agent image into Kind using the existing script with `--no-cache` flag:

```bash
# From project root
cd scripts
./deploy-streamtime-agent.sh

# Or with explicit NO_CACHE flag
NO_CACHE=true ./deploy-streamtime-agent.sh
```

**Note**: The `bootstrap-byok-fleet.sh` script sets `NO_CACHE=true` by default when calling `deploy-streamtime-agent.sh`.

**What to verify:**
- Image builds successfully
- Image is loaded into Kind cluster
- Helm chart deployment succeeds
- Agent pod starts and is running

### 2. Check Agent Logs

Monitor the streamtime-agent pod logs using kubectl:

```bash
# Get pod name
kubectl get pods -n default | grep streamtime-agent

# Tail logs
kubectl logs -f -n default <pod-name> streamtime-agent

# Or use label selector
kubectl logs -f -n default -l app.kubernetes.io/name=streamtime-agent
```

**What to look for:**
- Early failure detection: Check for connectivity verification messages
  - Success: "Orchestrator connectivity verified successfully"
  - Failure: "CRITICAL: Cannot connect to orchestrator" with troubleshooting steps
- Discovery probe: Check for discovery activity execution logs
- Streamtime info: Check for StreamtimeInfo activity execution logs
- Workflow registrations: Verify all workflows are registered
- Activity registrations: Verify all activities are registered
- Any errors or warnings

### 3. Check Orchestrator Worker Logs

Monitor the Temporal worker (orchestrator) logs through docker-compose:

```bash
# From project root
docker compose logs -f temporal-worker

# Or with tail
docker compose logs --tail=100 -f temporal-worker
```

**What to look for:**
- Workflow execution logs
- Activity execution logs
- Command audit activity calls
- Any errors or warnings
- Child workflow execution logs

### 4. Check Workflow History

Inspect workflow execution history through Temporal CLI in the orchestrator container:

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

**What to look for:**
- Workflow execution events
- Activity execution events
- Child workflow execution events
- Command audit activity calls
- Workflow completion/failure status
- Return values from workflows

### 5. Verify Commands Logged in Django

Verify that workflow executions are tracked in Django through the API:

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

**What to verify:**
- Commands are created with correct `command_handler` (workflow name)
- Commands have correct `command_aggregate` (workflow_id)
- Commands have correct `command_id` (run_id)
- Commands have correct `status` (pending → running → completed/failed)
- Commands have `request` data (workflow input)
- Commands have `result` data (workflow output) when completed
- Commands have `start` and `end` timestamps
- Both parent and child workflows are tracked separately

## Testing Specific Features

### Testing Early Failure Detection

1. **Test successful connection:**
   - Deploy agent normally
   - Check agent logs for "Orchestrator connectivity verified successfully"
   - Agent should start normally

2. **Test connection failure:**
   - Stop orchestrator or break connectivity
   - Deploy agent
   - Check agent logs for "CRITICAL: Cannot connect to orchestrator"
   - Verify troubleshooting steps are logged
   - Agent should fail to start

### Testing Discovery Probe

1. **Execute discovery probe workflow via Python parent workflow:**
   ```bash
   # Always create the parent workflow via Temporal CLI
   # This ensures the Python parent workflow executes, which then calls the Go child workflow
   # This ensures proper command auditing in Django
   docker compose exec temporal temporal workflow start \
     --address temporal:7233 \
     --tls=false \
     --namespace default \
     --type DiscoveryProbeWorkflow \
     --task-queue fleet-manager-tasks \
     --workflow-id /organizations/root/command/DiscoveryProbeWorkflow-$(date +%s) \
     --input '{"organization": "root", "fleet_id": "byok-test"}'
   ```
   
   **Note**: The parent workflow runs on the Python worker (task-queue: `fleet-manager-tasks`), which then executes the Go child workflow on the agent (task-queue: `agent-tq`).

2. **Verify in logs:**
   - Check agent logs for discovery activity execution
   - Check orchestrator logs for workflow execution
   - Check workflow history for completion

3. **Verify in Django:**
   - Check commands API for DiscoveryProbeWorkflow entries
   - Verify result contains discovery data (nodes, cloud provider, etc.)

### Testing Streamtime Info

1. **Execute streamtime info workflow via Python parent workflow:**
   ```bash
   # Always create the parent workflow via Temporal CLI
   # This ensures the Python parent workflow executes, which then calls the Go child workflow
   # This ensures proper command auditing in Django
   docker compose exec temporal temporal workflow start \
     --address temporal:7233 \
     --tls=false \
     --namespace default \
     --type StreamtimeInfoWorkflow \
     --task-queue fleet-manager-tasks \
     --workflow-id /organizations/root/command/StreamtimeInfoWorkflow-$(date +%s) \
     --input '{"organization": "root"}'
   ```
   
   **Note**: The parent workflow runs on the Python worker (task-queue: `fleet-manager-tasks`), which then executes the Go child workflow on the agent (task-queue: `agent-tq`).

2. **Verify in logs:**
   - Check agent logs for StreamtimeInfo activity execution
   - Check orchestrator logs for workflow execution

3. **Verify in Django:**
   - Check commands API for StreamtimeInfoWorkflow entries
   - Verify result contains:
     - Version
     - List of workflows
     - List of activities
     - Bootstrap state (stub)

## Common Issues and Troubleshooting

### Agent Not Starting

- Check agent logs for connectivity errors
- Verify orchestrator is running: `docker compose ps temporal`
- Verify Kong gateway is running: `docker compose ps kong`
- Check network connectivity from agent pod to orchestrator

### Workflows Not Executing

- Check workflow is registered in agent logs
- Verify task queue matches: `agent-tq`
- Check orchestrator logs for workflow dispatch
- Verify Temporal namespace is correct

### Commands Not Logged

- Check orchestrator logs for command audit activity calls
- Verify command audit activity is registered
- Check Django logs for API errors
- Verify organization identifier is correct

### Child Workflows Not Tracked

- Check parent workflow logs for child execution
- Verify child workflow returns command audit data
- Check parent workflow extracts command audit from child result
- Verify both parent and child have separate command records

## Testing Checklist

- [ ] Agent builds and deploys successfully
- [ ] Agent starts and connects to orchestrator
- [ ] Early failure detection works (success case)
- [ ] Early failure detection works (failure case)
- [ ] Discovery probe workflow executes
- [ ] Discovery probe returns cluster information
- [ ] Streamtime info workflow executes
- [ ] Streamtime info returns version, workflows, activities
- [ ] All workflows are tracked in Django
- [ ] All child workflows are tracked separately
- [ ] Command records have correct status progression
- [ ] Command records have request and result data
- [ ] Workflow history shows correct execution flow

