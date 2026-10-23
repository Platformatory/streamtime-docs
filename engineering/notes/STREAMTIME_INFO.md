# Streamtime Info

This document describes the StreamtimeInfo feature that provides information about the Streamtime agent itself.

## Testing

See [TESTING_STREAMTIME_AGENT_FEATURES.md](TESTING_STREAMTIME_AGENT_FEATURES.md) for detailed testing procedures.

## Overview

The StreamtimeInfo feature allows querying the Streamtime agent for:
- Agent version information
- List of registered workflows and activities
- Bootstrap state (stub: will contain versions of shared service operators)

## Architecture

### Activity: StreamtimeInfo

The `StreamtimeInfo` activity returns a `StreamtimeInfoResult` struct containing:

```go
type StreamtimeInfoResult struct {
    Version    string                // Streamtime agent version (from STREAMTIME_AGENT_IMAGE_TAG)
    Workflows  []string              // List of registered workflow names
    Activities []string              // List of registered activity names
    Bootstrap  BootstrapState        // Bootstrap state (stub)
}
```

### Bootstrap State (Stub)

The bootstrap state is currently a stub that will be enhanced to track:
- Which shared service operators are installed (e.g., Redis, Nginx, Cert-Manager)
- Versions of installed operators
- Installation status

```go
type BootstrapState struct {
    Status   string                 // "unknown", "not_bootstrapped", "bootstrapped", "partial"
    Services []BootstrapServiceInfo // List of shared service operators and their versions
}

type BootstrapServiceInfo struct {
    Name    string // Service name (e.g., "redis", "nginx", "cert-manager")
    Version string // Version of the service operator
    Status  string // "installed", "not_installed", "unknown"
}
```

## Usage

### As an Activity

The `StreamtimeInfo` activity can be called directly from any workflow:

```go
var result *activities.StreamtimeInfoResult
err := workflow.ExecuteActivity(ctx, activities.ActivityNameStreamtimeInfo).Get(ctx, &result)
```

### As a Workflow

The `StreamtimeInfoWorkflow` wraps the activity and provides command auditing:

```go
// Input
input := StreamtimeInfoWorkflowInput{
    Organization: "root",
    FleetID:      "fleet-1", // Optional
}

// Execute workflow
result := await workflow.execute_child_workflow(
    "StreamtimeInfoWorkflow",
    input,
    task_queue="agent-tq"
)
```

### Python Parent Workflow

A Python parent workflow can be created to wrap the Go workflow (similar to `DiscoveryProbeWorkflow`):

```python
from workflows.agent_command_helper import execute_agent_command_child_workflow

result = await execute_agent_command_child_workflow(
    workflow_name="StreamtimeInfoWorkflow",
    input_data={
        "organization": "root",
        "fleet_id": "fleet-1",
    },
    task_queue="agent-tq"
)
```

## Example Response

```json
{
  "version": "v1.0.0",
  "workflows": [
    "TeardownFleetClusterWorkflow",
    "HelmInstallWorkflow",
    "HelmUninstallWorkflow",
    "DiscoveryProbeWorkflow",
    "StreamtimeInfoWorkflow"
  ],
  "activities": [
    "StreamtimeHealthPong",
    "StreamtimeHealthDiscovery",
    "StreamtimeHealthTopology",
    "HelmInstall",
    "HelmUninstall",
    "DiscoveryProbe",
    "StreamtimeInfo"
  ],
  "bootstrap": {
    "status": "unknown",
    "services": []
  }
}
```

## Implementation Details

### Registration

The StreamtimeInfo activity is registered in `streamtime-agent/internal/worker/runner.go`:

1. Workflow and activity names are collected during registration
2. These names are passed to `NewStreamtimeInfoActivities()`
3. The activity is registered with the worker

### Version

The version is read from `config.ImageTag`, which is set from the `STREAMTIME_AGENT_IMAGE_TAG` environment variable.

### Future Enhancements

The bootstrap state will be enhanced to:
- Query Kubernetes for installed Helm releases
- Check for specific operators (Redis, Nginx, Cert-Manager, etc.)
- Report versions of installed operators
- Determine bootstrap status based on required vs installed services

