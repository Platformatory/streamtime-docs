# Agent Command Tracking

This document describes how to track workflow executions using the AgentCommand model for audit and monitoring purposes.

## Testing

See [TESTING_STREAMTIME_AGENT_FEATURES.md](TESTING_STREAMTIME_AGENT_FEATURES.md) for detailed testing procedures.

## Overview

The AgentCommand model tracks all workflow executions (both parent and child workflows) in the Django database. This provides:
- **Audit trail**: Complete history of all workflow executions
- **Monitoring**: Track workflow status and results
- **Debugging**: View request/response data for troubleshooting

## Architecture

### Command Audit-Based Tracking

We use a single idempotent command audit activity for tracking workflow executions:

- **command_audit**: Called at the beginning and end of workflows (parent and child)
- **Idempotent**: Can be called multiple times with the same `command_id` - will upsert the record
- **Upsert Key**: `command_id` (Temporal run_id) - unique identifier
- **No Interceptors**: Manual tracking in workflows for better control

### Parent vs Child Workflow Tracking

**Parent Workflows (Python)**:
- Call `command_audit` activity directly at start and end
- Use their own `run_id` as `command_id`
- Track their own execution lifecycle

**Child Workflows (Go)**:
- For simple wrapper workflows (e.g., DiscoveryProbeWorkflow, StreamtimeInfoWorkflow):
  - Child workflows do NOT audit - parent handles all command audit
  - Child workflow_id: `{parent_aggregate}/subprocess/{workflow_type}` (e.g., `/organizations/root/fleet/byok-test/command/DiscoveryProbeWorkflow/subprocess/DiscoveryProbeWorkflow`)
  - Only the parent workflow audits using the parent's `workflow_id` (the `subject` from dispatch API)
- For other workflows:
  - Return command audit data in their return value (struct with `CommandAudit` field)
  - Parent workflow extracts command audit data and calls `command_audit` activity
  - Use their own `run_id` as `command_id` (different from parent's `run_id`)
  - Each workflow execution (parent and child) has its own unique tracking record

### Field Names (Rationalized)

- **command_handler**: Workflow name (e.g., "ByokProvider", "InstallStreamtimeAgentWorkflow")
- **command_aggregate**: Temporal workflow ID (e.g., "/organizations/root/fleet/byok-test/")
- **command_id**: Temporal run_id (unique command execution identifier)
- **status**: pending → running → completed/failed
- **request**: Workflow input data
- **result**: Workflow output data (captures return value)
- **start**: Timestamp when workflow started
- **end**: Timestamp when workflow completed/failed

## API Endpoints

### List Commands

**GET** `/organizations/{org_identifier}/commands/`

Query parameters:
- `command_handler`: Filter by workflow name (e.g., "DiscoveryProbeWorkflow")
- `command_aggregate`: Filter by workflow ID / command aggregate (e.g., "/organizations/root/fleet/byok-test/command/DiscoveryProbeWorkflow")
- `status`: Filter by status (pending, running, completed, failed, timeout)
- `command_id`: Filter by specific run_id
- `fleet_id`: Filter by fleet_id (extracted from command_aggregate pattern)
- `cluster_id`: Filter by cluster_id (extracted from command_aggregate pattern)
- `start_date`: Filter by start timestamp (ISO format, gte)
- `end_date`: Filter by end timestamp (ISO format, lte)
- `created_after`: Filter by created_at timestamp (ISO format, gte)
- `created_before`: Filter by created_at timestamp (ISO format, lte)
- `limit`: Limit number of results (default: 100)
- `format`: Response format - `run_ids` (list of run_ids), `summary` (summary fields), or default (full objects)

**Examples:**

```bash
# List all commands for an organization
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/"

# Filter by command handler (workflow name)
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/?command_handler=ByokProvider"

# Filter by command aggregate (workflow ID)
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/?command_aggregate=/organizations/root/fleet/byok-test/"

# Filter by status
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/?status=completed"

# Combine filters
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/?command_handler=DiscoveryProbeWorkflow&status=completed&limit=10"

# Filter by both command_handler and command_aggregate (list all runs for a handler under an aggregate)
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/?command_handler=DiscoveryProbeWorkflow&command_aggregate=/organizations/root/fleet/byok-test/command/DiscoveryProbeWorkflow"

# Get just run_ids
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/?command_handler=DiscoveryProbeWorkflow&format=run_ids"

# Get summary format
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/?command_aggregate=/organizations/root/fleet/byok-test/command/DiscoveryProbeWorkflow&format=summary"

# Filter by fleet_id
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/?fleet_id=byok-test"

# Filter by date range
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/?created_after=2025-11-26T00:00:00Z&created_before=2025-11-26T23:59:59Z"
```

**Response:**
```json
[
  {
    "id": "uuid",
    "organization": "root",
    "command_handler": "BootstrapFleetClusterWorkflow",
    "command_aggregate": "/organizations/root/command/BootstrapFleetClusterWorkflow",
    "command_id": "run-id-123",
    "status": "completed",
    "request": {
      "fleet_id": "byok-test",
      "organization": "root",
      "redis_release": "byok-test-redis",
      ...
    },
    "result": {
      "redis": {"status": "installed", "revision": 1},
      "nginx": {"status": "installed", "revision": 1}
    },
    "start": "2025-11-24T20:00:00Z",
    "end": "2025-11-24T20:05:00Z",
    "created_at": "2025-11-24T20:00:00Z"
  }
]
```

### Dispatch Command

**POST** `/organizations/{org_identifier}/commands/dispatch/`

Programmatically dispatch a command workflow. This endpoint validates inputs, dispatches the workflow via Temporal, and returns the workflow run ID for tracking. The command is NOT persisted at dispatch time - command audit happens later in the workflow execution.

**Request Body:**
```json
{
  "command_handler": "DiscoveryProbeWorkflow",
  "args": {
    "fleet_id": "byok-test"
  },
  "subject": "/organizations/root/fleet/byok-test/command/DiscoveryProbeWorkflow"
}
```

**Fields:**
- `command_handler` (required): Workflow name (e.g., "DiscoveryProbeWorkflow", "StreamtimeInfoWorkflow")
- `args` (required): Workflow input data (workflow-specific, without organization)
- `subject` (required): Command aggregate / workflow_id (e.g., "/organizations/root/fleet/byok-test/command/DiscoveryProbeWorkflow")

**Subject Patterns:**
- Fleet-level: `/organizations/{org}/fleet/{fleet_id}/command/{command_handler}`
- Cluster-level: `/organizations/{org}/fleet/{fleet_id}/tenants/{cluster_id}/command/{command_handler}`

**Validation:**
- Command handler must exist in registry
- Subject (aggregate) structure must match expected patterns
- Organization, Fleet, and optionally Kafka cluster must exist
- Args must match the workflow's Pydantic input schema

**Response:**
```json
{
  "workflow_id": "/organizations/root/fleet/byok-test/command/DiscoveryProbeWorkflow",
  "run_id": "019ac1a5-d831-734d-b38a-560f888770f5",
  "status": "dispatched"
}
```

**Example:**
```bash
# Dispatch a fleet-level command
curl -k -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.streamtime.local:8443/organizations/root/commands/dispatch/" \
  -d '{
    "command_handler": "DiscoveryProbeWorkflow",
    "args": {
      "fleet_id": "byok-test"
    },
    "subject": "/organizations/root/fleet/byok-test/command/DiscoveryProbeWorkflow"
  }'

# Dispatch a cluster-level command
curl -k -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.streamtime.local:8443/organizations/root/commands/dispatch/" \
  -d '{
    "command_handler": "DiscoveryProbeWorkflow",
    "args": {
      "fleet_id": "byok-test"
    },
    "subject": "/organizations/root/fleet/byok-test/tenants/my-cluster/command/DiscoveryProbeWorkflow"
  }'
```

**Error Responses:**
- `400 Bad Request`: Invalid request format or validation failure
- `404 Not Found`: Organization, Fleet, or Kafka cluster not found
- `409 Conflict`: Workflow already started
- `503 Service Unavailable`: Temporal service unavailable

### Get Command by ID

**GET** `/organizations/{org_identifier}/commands/{command_id}/`

The `command_id` can be either:
- UUID of the AgentCommand record
- Temporal run_id (command_id field)

**Example:**
```bash
# Get by UUID
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/123e4567-e89b-12d3-a456-426614174000/"

# Get by run_id
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/run-id-123/"
```

### Cancel Command

**DELETE** `/organizations/{org_identifier}/commands/{run_id}/cancel/`

Cancel a running command workflow. The command must be command audited (workflow must have started) before it can be canceled.

**Example:**
```bash
curl -k -X DELETE \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/019ac1a5-d831-734d-b38a-560f888770f5/cancel/"
```

**Response:**
```json
{
  "detail": "Command workflow canceled."
}
```

### Terminate Command

**DELETE** `/organizations/{org_identifier}/commands/{run_id}/terminate/`

Force terminate a running command workflow. The command must be command audited (workflow must have started) before it can be terminated.

**Example:**
```bash
curl -k -X DELETE \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/019ac1a5-d831-734d-b38a-560f888770f5/terminate/"
```

**Response:**
```json
{
  "detail": "Command workflow terminated."
}
```

### Signal Command

**POST** `/organizations/{org_identifier}/commands/{run_id}/signal/`

Send a signal to a running command workflow. The command must be command audited (workflow must have started) before it can be signaled.

**Request Body:**
```json
{
  "signal_name": "MySignal",
  "signal_args": ["arg1", "arg2"]
}
```

**Example:**
```bash
curl -k -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.streamtime.local:8443/organizations/root/commands/019ac1a5-d831-734d-b38a-560f888770f5/signal/" \
  -d '{
    "signal_name": "MySignal",
    "signal_args": ["arg1", "arg2"]
  }'
```

**Response:**
```json
{
  "detail": "Signal sent to command workflow."
}
```

### Create/Update Command (Upsert)

**POST** `/organizations/{org_identifier}/commands/{command_handler}/`

This endpoint is called internally by workflows via the `update_command_status` activity. It uses `command_id` (run_id) as the unique identifier for upsert.

**Payload:**
```json
{
  "command_handler": "BootstrapFleetClusterWorkflow",
  "command_aggregate": "/organizations/root/command/BootstrapFleetClusterWorkflow",
  "command_id": "run-id-123",
  "status": "running",
  "request": {...},
  "result": {...}  // Optional, typically set on completion
}
```

`command_handler` is required in both the path and payload, must name a registered workflow handler, and must match the path parameter. `status` and `request` are required; `result` is optional.

## Usage in Workflows

### Command Audit Interface

All workflows (parent and child) should use the command audit interface:

- **command_audit**: Called at the beginning of the workflow (status: "running")
- **command_audit**: Called at the end of the workflow (status: "completed" or "failed", with result)
- **Idempotent**: Can be called multiple times - uses `command_id` (run_id) for upsert

### Understanding Command Audit

#### Parent Workflows (Python)

Parent workflows run in the Python orchestrator and should call the `command_audit` activity directly:

1. **At workflow start**: Call `command_audit` with status "running" and the workflow input as `request`
2. **At workflow end (success)**: Call `command_audit` with status "completed" and the workflow return value as `result`
3. **At workflow end (failure)**: Call `command_audit` with status "failed" and error details as `result`

The parent workflow uses its own `run_id` as the `command_id` for tracking.

#### Child Workflows (Go)

Child workflows run in the Go agent and have a different pattern:

1. **Return command audit data**: The Go workflow returns a struct that includes a `CommandAudit` field containing tracking information
2. **Parent extracts command audit**: The Python parent workflow extracts the command audit data from the child's return value
3. **Parent calls command audit activity**: The parent workflow calls the `command_audit` activity using the child's `run_id` from the command audit data

**Important**: The child workflow's `run_id` is different from the parent's `run_id`. Each workflow execution has its own unique `run_id`, which is used as the `command_id` for tracking.

**Go Workflow Return Structure**:
```go
type BootstrapFleetClusterOutput struct {
    FleetID      string                        `json:"fleet_id"`
    Organization string                        `json:"organization"`
    Redis        *activities.HelmInstallOutput `json:"redis"`
    Nginx        *activities.HelmInstallOutput `json:"nginx"`
    CommandAudit *CommandAuditData             `json:"command_audit,omitempty"`
}

type CommandAuditData struct {
    Organization     string `json:"organization"`
    CommandHandler   string `json:"command_handler"`   // Workflow name
    CommandAggregate string `json:"command_aggregate"` // Workflow ID
    CommandID        string `json:"command_id"`        // Run ID (unique identifier)
    Status           string `json:"status"`            // "completed" or "failed"
    Request          string `json:"request,omitempty"` // Workflow input (JSON string)
    Result           string `json:"result,omitempty"`  // Workflow output (JSON string)
}
```

The Go struct serializes to JSON automatically, which Python receives as a dict. The parent workflow extracts the `command_audit` field and uses it to call the `command_audit` activity.

### Tracking Parent Workflows

For parent workflows, call `command_audit` at the beginning and end:

```python
from activities.backend import BackendActivities
from temporalio import workflow
from temporalio.common import RetryPolicy
from datetime import timedelta

@workflow.defn
class MyWorkflow:
    @workflow.run
    async def run(self, workflow_input: dict):
        workflow_info = workflow.info()
        org_id = "root"  # Extract from workflow_id or input
        workflow_id = workflow_info.workflow_id
        run_id = workflow_info.run_id
        
        # Command audit: workflow start
        try:
            await workflow.execute_activity(
                BackendActivities.command_audit,
                {
                    "organization": org_id,
                    "command_handler": "MyWorkflow",
                    "command_aggregate": workflow_id,
                    "command_id": run_id,
                    "status": "running",
                    "request": workflow_input,
                },
                start_to_close_timeout=timedelta(seconds=10),
                retry_policy=RetryPolicy(maximum_attempts=3)
            )
        except Exception as e:
            workflow.logger.warning(f"Failed to command audit workflow start: {e}")
        
        try:
            # ... workflow logic ...
            result = {"success": True, "data": "..."}
            
            # Command audit: workflow end (success)
            try:
                await workflow.execute_activity(
                    BackendActivities.command_audit,
                    {
                        "organization": org_id,
                        "command_handler": "MyWorkflow",
                        "command_aggregate": workflow_id,
                        "command_id": run_id,
                        "status": "completed",
                        "result": result,  # Workflow return value
                    },
                    start_to_close_timeout=timedelta(seconds=10),
                    retry_policy=RetryPolicy(maximum_attempts=3)
                )
            except Exception as e:
                workflow.logger.warning(f"Failed to command audit workflow end: {e}")
            
            return result
            
        except Exception as e:
            # Command audit: workflow end (failure)
            try:
                await workflow.execute_activity(
                    BackendActivities.command_audit,
                    {
                        "organization": org_id,
                        "command_handler": "MyWorkflow",
                        "command_aggregate": workflow_id,
                        "command_id": run_id,
                        "status": "failed",
                        "result": {"error": str(e)},
                    },
                    start_to_close_timeout=timedelta(seconds=10),
                    retry_policy=RetryPolicy(maximum_attempts=3)
                )
            except Exception as command_audit_error:
                workflow.logger.warning(f"Failed to command audit workflow failure: {command_audit_error}")
            
            raise
```

### Tracking Child Workflows

For child workflows, use the `execute_agent_command_child_workflow` helper which:
1. Executes the child workflow using `execute_child_workflow` (blocks until child completes)
2. Extracts command audit data from the child's return value
3. Calls the `command_audit` activity using the child's `run_id`

```python
from workflows.agent_command_helper import execute_agent_command_child_workflow

# In your parent workflow
bootstrap_result = await execute_agent_command_child_workflow(
    workflow_name="BootstrapFleetClusterWorkflow",
    input_data={
        "fleet_id": fleet_id,
        "organization": org_id,
        "redis_release": f"{fleet_id}-redis",
        ...
    },
    task_queue="agent-tq",
    start_to_close_timeout=timedelta(minutes=15),
    retry_policy=retry_policy
)

# The helper automatically:
# 1. Executes the child workflow (blocks until completion)
# 2. Extracts command audit data from child's return value (result["command_audit"])
# 3. Calls command_audit activity with child's run_id (command_id)
```

**How Child Workflow Command Audit Works**:

1. **Go workflow returns struct**: The child workflow (Go) returns a struct with a `CommandAudit` field containing:
   - `command_id`: The child workflow's `run_id` (from `workflow.GetInfo(ctx).WorkflowExecution.RunID`)
   - `command_handler`: The workflow name (e.g., "BootstrapFleetClusterWorkflow")
   - `command_aggregate`: The child workflow's workflow ID
   - `status`: "completed" or "failed"
   - `request`: Serialized workflow input (JSON string)
   - `result`: Serialized workflow output (JSON string)

2. **Python receives as dict**: The Go struct serializes to JSON, which Python receives as a dict:
   ```python
   {
       "fleet_id": "byok-test",
       "organization": "root",
       "redis": {...},
       "nginx": {...},
       "command_audit": {
           "command_id": "019aba73-98c4-7421-b9ee-43fd54aed101",  # Child's run_id
           "command_handler": "BootstrapFleetClusterWorkflow",
           "command_aggregate": "/organizations/root/command/BootstrapFleetClusterWorkflow",
           "status": "completed",
           "request": "{...}",
           "result": "{...}"
       }
   }
   ```

3. **Parent extracts and audits**: The helper extracts `result["command_audit"]` and calls the `command_audit` activity:
   ```python
   command_audit_data = result["command_audit"]
   await workflow.execute_activity(
       BackendActivities.command_audit,
       {
           "organization": command_audit_data["organization"],
           "command_handler": command_audit_data["command_handler"],
           "command_aggregate": command_audit_data["command_aggregate"],
           "command_id": command_audit_data["command_id"],  # Child's run_id
           "status": command_audit_data["status"],
           "request": request_data,
           "result": result_data,
       }
   )
   ```

**Important Notes**:
- The child workflow's `run_id` is different from the parent's `run_id`
- Each workflow execution (parent and child) has its own unique `command_id` (run_id)
- The child workflow does NOT call the command_audit activity directly - it returns command audit data in its return value
- The parent workflow is responsible for calling the command_audit activity using the child's command audit data

**The result field captures the workflow's return value:**
- If workflow returns a dict, it's stored as-is in the `result` field
- If workflow returns a non-dict (string, int, etc.), it's wrapped: `{"result": <value>}`
- If workflow returns None, `result` will be `null`

**Example return values:**
```python
# Workflow returns dict
return {"status": "success", "data": "..."}
# Result field: {"status": "success", "data": "..."}

# Workflow returns string
return "completed"
# Result field: {"result": "completed"}

# Workflow returns None (implicit)
# Result field: null
```

**Important:**
- Always capture the workflow's return value in the `result` field
- For child workflows (Go), the command audit data includes the serialized return value in `result` (JSON string)
- For parent workflows (Python), manually capture the return value before returning

## Command Audit Activity

### command_audit

Single idempotent activity for tracking workflow execution state:

```python
@activity.defn
async def command_audit(command_data: dict) -> Dict[str, Any]:
    """
    Command audit workflow execution - idempotent activity for tracking workflow state.
    
    Can be called multiple times with the same command_id - will upsert the record.
    Called at the beginning and end of workflows (parent and child) to track execution.
    
    Args:
        command_data: {
            "organization": str,  # Required
            "command_handler": str,  # Workflow name (e.g., "ByokProvider")
            "command_aggregate": str,  # Workflow ID
            "command_id": str,  # Run ID (unique identifier for upsert)
            "status": str,  # "running", "completed", "failed"
            "request": Optional[dict],  # Workflow input data (typically at start)
            "result": Optional[dict],  # Workflow return value/response (typically at end)
        }
    """
```

**Upsert Logic:**
- Uses `command_id` (run_id) as unique identifier
- If record exists: updates status, request, result, timestamps
- If record doesn't exist: creates new record
- Idempotent: Can be called multiple times safely
- Sets `start` timestamp for "running" status
- Sets `end` timestamp for "completed"/"failed" status

## Querying Commands

### By Command Handler (Workflow Name)

Find all executions of a specific workflow:

```bash
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/?command_handler=BootstrapFleetClusterWorkflow"
```

### By Command Aggregate (Workflow ID)

Find all commands for a specific workflow instance:

```bash
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/?command_aggregate=/organizations/root/fleet/byok-test/"
```

### By Status

Find all completed commands:

```bash
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/?status=completed"
```

### Combined Filters

Find completed DiscoveryProbeWorkflow executions:

```bash
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/?command_handler=DiscoveryProbeWorkflow&status=completed&limit=10"
```

### List All Runs for Command Handler and Aggregate

List all run IDs for a specific command handler under a specific aggregate:

```bash
# List all runs for DiscoveryProbeWorkflow under a specific aggregate
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/?command_handler=DiscoveryProbeWorkflow&command_aggregate=/organizations/root/fleet/byok-test/command/DiscoveryProbeWorkflow"

# Get just the run_ids
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/?command_handler=DiscoveryProbeWorkflow&command_aggregate=/organizations/root/fleet/byok-test/command/DiscoveryProbeWorkflow&format=run_ids"

# Get summary format (run_id, status, start, end, command_handler, command_aggregate)
curl -k -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/?command_handler=DiscoveryProbeWorkflow&command_aggregate=/organizations/root/fleet/byok-test/command/DiscoveryProbeWorkflow&format=summary"
```

**Response Format Options:**

1. **Default (full objects)**:
```json
[
  {
    "id": "uuid",
    "organization": "root",
    "command_handler": "DiscoveryProbeWorkflow",
    "command_aggregate": "/organizations/root/fleet/byok-test/command/DiscoveryProbeWorkflow",
    "command_id": "019ac1a5-d831-734d-b38a-560f888770f5",
    "status": "completed",
    "request": {...},
    "result": {...},
    "start": "2025-11-26T19:31:02Z",
    "end": "2025-11-26T19:31:03Z",
    "created_at": "2025-11-26T19:31:02Z"
  }
]
```

2. **format=run_ids**:
```json
[
  "019ac1a5-d831-734d-b38a-560f888770f5",
  "019ac17a-0791-772b-82ba-5df2d5cc1caf"
]
```

3. **format=summary**:
```json
[
  {
    "run_id": "019ac1a5-d831-734d-b38a-560f888770f5",
    "status": "completed",
    "start": "2025-11-26T19:31:02Z",
    "end": "2025-11-26T19:31:03Z",
    "command_handler": "DiscoveryProbeWorkflow",
    "command_aggregate": "/organizations/root/fleet/byok-test/command/DiscoveryProbeWorkflow"
  }
]
```

## Best Practices

1. **Always track workflow start**: Call `update_command_status` with status "running" at the beginning
2. **Capture return values**: Store workflow return value in `result` field
3. **Track completion/failure**: Always call `update_command_status` at the end with appropriate status
4. **Use helper for child workflows**: Use `execute_agent_command_child_workflow` which handles tracking automatically
5. **Handle errors gracefully**: Don't let tracking failures break workflow execution

## Example: Complete Workflow with Command Audit

```python
from temporalio import workflow
from temporalio.common import RetryPolicy
from datetime import timedelta
from activities.backend import BackendActivities
from workflows.agent_command_helper import execute_agent_command_child_workflow

@workflow.defn
class MyWorkflow:
    @workflow.run
    async def run(self, workflow_input: dict) -> dict:
        workflow_info = workflow.info()
        org_id = workflow_input.get("organization", "root")
        workflow_id = workflow_info.workflow_id
        run_id = workflow_info.run_id
        
        # Command audit: workflow start
        try:
            await workflow.execute_activity(
                BackendActivities.command_audit,
                {
                    "organization": org_id,
                    "command_handler": "MyWorkflow",
                    "command_aggregate": workflow_id,
                    "command_id": run_id,
                    "status": "running",
                    "request": workflow_input,
                },
                start_to_close_timeout=timedelta(seconds=10),
                retry_policy=RetryPolicy(maximum_attempts=3)
            )
        except Exception as e:
            workflow.logger.warning(f"Failed to command audit workflow start: {e}")
        
        try:
            # Execute child workflow (uses execute_child_workflow - blocks until child completes)
            child_result = await execute_agent_command_child_workflow(
                workflow_name="ChildWorkflow",
                input_data={"organization": org_id, "data": "..."},
                task_queue="agent-tq",
            )
            
            # Workflow logic
            result = {
                "success": True,
                "child_result": child_result,
                "data": "processed"
            }
            
            # Command audit: workflow end (success)
            try:
                await workflow.execute_activity(
                    BackendActivities.command_audit,
                    {
                        "organization": org_id,
                        "command_handler": "MyWorkflow",
                        "command_aggregate": workflow_id,
                        "command_id": run_id,
                        "status": "completed",
                        "result": result,  # Capture return value
                    },
                    start_to_close_timeout=timedelta(seconds=10),
                    retry_policy=RetryPolicy(maximum_attempts=3)
                )
            except Exception as e:
                workflow.logger.warning(f"Failed to command audit workflow end: {e}")
            
            return result  # Return value is captured in result field
            
        except Exception as e:
            # Command audit: workflow end (failure)
            try:
                await workflow.execute_activity(
                    BackendActivities.command_audit,
                    {
                        "organization": org_id,
                        "command_handler": "MyWorkflow",
                        "command_aggregate": workflow_id,
                        "command_id": run_id,
                        "status": "failed",
                        "result": {"error": str(e)},
                    },
                    start_to_close_timeout=timedelta(seconds=10),
                    retry_policy=RetryPolicy(maximum_attempts=3)
                )
            except Exception as command_audit_error:
                workflow.logger.warning(f"Failed to command audit workflow failure: {command_audit_error}")
            
            raise
```

## Troubleshooting

### Commands not appearing

1. Verify `update_command_status` activity is being called
2. Check backend logs for errors
3. Verify organization exists
4. Check that `command_id` (run_id) is provided

### Result field is empty

1. Ensure you're capturing the workflow return value
2. For child workflows, the helper automatically captures it
3. For parent workflows, manually capture before returning

### Status not updating

1. Verify activity is executing successfully
2. Check backend logs for errors
3. Verify `command_id` matches existing record for updates
