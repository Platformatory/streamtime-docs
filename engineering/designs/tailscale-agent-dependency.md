# Tailscale as a dependency of the streamtime-agent chart

## Objective

Fleets on the org's tailnet currently get Tailscale from a separate
`streamtime_tailscale` bootstrap component. The orchestrator installs it
before the agent (`plans/tailscale-fleet-connectivity.md`). This has three
problems:

- Manual installs never get it. They are handed the tailnet orchestrator
  address with nothing in the fleet that can reach it.
- Tailscale has a separate upgrade lifecycle from the agent that depends on
  it.
- The orchestrator has to run Helm against the fleet's kubeconfig.

The fix is for the agent chart to own Tailscale. Every install of
`streamtime-agent` (automatic, manual, or the operator's self-upgrade)
installs or upgrades the pinned Tailscale version with it. The agent does not
call the orchestrator until its tailnet path works. The orchestrator touches
Tailscale only for break-glass repair, using the kubeconfig.

## In scope

- `charts/streamtime-agent` depends on `charts/streamtime-tailscale`,
  conditional on `tailscale.enabled`. The Tailscale version is pinned per
  agent chart release.
- Agent startup gate: an init container that waits until the orchestrator
  address resolves and accepts TCP connections.
- The `streamtime-tailscale` chart has no install-path hooks that the
  agent's readiness depends on. `helm --wait` must not deadlock (see
  `project-infra-shared-gatewayclass-deadlock`, which hit exactly this).
- OAuth input. Values `tailscale.operator.oauth.{clientId,clientSecret}`
  from the org's privileged client (decision: reuse the org client, no
  per-fleet client), or `existingSecret`. Upgrades keep the secret even when
  the new values omit it.
- Automatic bootstrap. `InstallStreamtimeAgentWorkflow` passes the Tailscale
  values to the agent chart install and drops the separate pre-agent install.
- Manual bootstrap. `get_bootstrap_config` (`core/services/agent_tasks.py`)
  and the UI's values.yaml and instructions include the Tailscale block when
  the org uses Tailscale.
- Self-upgrade. The `StreamtimeAgentConfig` controller upgrade must:
  - pick up the new chart's pinned Tailscale defaults;
  - keep the OAuth secret;
  - roll back on failure.
- Teardown (decision 2026-10-03). A fleet delete leaves the agent release,
  and so its Tailscale components, installed, as it already does for the
  agent, with its tailnet devices (see Deviations 2026-10-04). Installing a
  new fleet's agent on the same cluster
  (upgrade over the leftover release) must work. Uninstalling the agent
  release by hand runs the chart's `pre-delete` egress and DNS cleanup.
- Remove the `streamtime_tailscale` bootstrap component and everything
  behind it:
  - the resolver entry;
  - the schema field;
  - the package rule;
  - the preload `helm_repos` entry;
  - the orchestrator's pre-agent install and `_remove_tailscale` paths;
  - the BootstrapConfigEditor entry.
- Tests for both bootstrap modes, upgrade and teardown.

## Out of scope

- Registry over the tailnet (roadmap step 3).
- Migrating fleets that already have the separate `streamtime-tailscale`
  release. Only dev fleets have it. They are re-bootstrapped after a
  documented manual cleanup (decision 2026-10-03).
- A restricted OAuth client per fleet (decision 2026-10-03: reuse the org
  client).
- Kong ingress over the tailnet. It stays in `fleet-manager-infra-shared`
  and is unchanged.
- The infra-shared GatewayClass deadlock. It is deliberately deferred.

## Approach

1. **Chart dependency.**
   - Add `streamtime-tailscale` to `charts/streamtime-agent/Chart.yaml`:
     - `repository: file://../streamtime-tailscale`
     - `condition: tailscale.enabled`
     - `alias: tailscale`
   - The resources render in the agent's release namespace. One Helm release
     covers both the agent and Tailscale.
   - The local `build-and-push-chart.sh` gains `helm dependency build` before
     `helm package`, the same as CI's `build-helm-charts.yaml`.
   - The agent chart's `values.yaml` sets `tailscale.enabled: false`, so
     non-Tailscale installs render nothing extra.
2. **No hook deadlocks.**
   - In `streamtime-tailscale`, `dns-sync` (the Corefile or
     `coredns-custom` edit) and the CoreDNS restart become ordinary
     resources and Jobs, not `post-install`/`post-upgrade` hooks.
   - `egress-ready` as a hook is dropped. The agent's init container is the
     readiness gate.
   - Only the `pre-delete` egress and device cleanup stay hooks.
   - A unit test asserts that no install or upgrade hook remains in the
     Tailscale templates.
3. **Agent startup gate.**
   - When `tailscale.enabled`, the agent Deployment gets a
     `wait-for-orchestrator` init container that resolves
     `streamtime.orchestrator.address` and loops until a TCP connect
     succeeds, logging each attempt. It has a bounded per-attempt timeout
     and no overall deadline; the pod stays in Init.
   - Image: fully qualified, overridable, and in
     `preload/registry_images.yaml`.
4. **OAuth secret retention.**
   - Support `tailscale.operator.oauth.existingSecret`.
   - When the inline secret is empty on upgrade, look up the existing
     `operator-oauth` Secret and reuse it. This mirrors the controller's
     existing `apiKey` preservation.
   - Never fall back silently to a missing secret. If neither the values nor
     the cluster has it, rendering fails with a clear message.
5. **Automatic bootstrap.**
   - Backend: `resolve_agent_orchestrator_helm_config` returns the full
     `tailscale` values block, from today's `tailscale_component_values`
     plus `enabled`, `clientSecret`, `egress` and `dns`.
   - Orchestrator: `install_streamtime_agent.py` merges that block under
     `tailscale` into the agent chart values, behind a new `workflow.patched`
     id. It removes the old pre-agent install behind the same patch.
   - The activity timeout covers the init-gate wait.
6. **Manual bootstrap.**
   - `get_bootstrap_config` adds the same `tailscale` block, including the
     secret, because the user downloads the values file to install.
   - `BootstrapInstructions` mentions that the values file contains the
     tailnet credentials and must be stored securely.
   - The manual install command stays a single `helm install` of the agent
     chart.
7. **Self-upgrade correctness.**
   - The controller builds upgrade values from the release's user-supplied
     values (`release.Config`) merged with the requested changes, not
     `ComputedValues`. Old computed values override the new chart's
     defaults, which pins the old Tailscale image forever.
   - Upgrades run with `atomic=true`, so a failed Tailscale rollout rolls
     back to the working release.
   - A Go test covers both.
8. **Upgrade reliability.**
   - Evaluate a `ProxyGroup` (egress, 2 replicas) plus a PDB, so the agent
     keeps a path while egress pods restart.
   - If the operator version or the cluster size makes that impractical, keep
     the single-pod egress and record the decision as a deviation.
   - Either way, a post-upgrade check confirms the agent reconnects. This is
     the existing `UpdateAgentWorkflow` verify step, since the agent polls
     again after its pod restarts.
9. **Teardown.**
   - No Helm uninstall and no device deletion on fleet delete (see Deviations
     2026-10-04). `delete_tailnet_device` stays registered for break-glass
     use.
   - The `pre-delete` hooks still cover a manual `helm uninstall` of the
     agent.
   - Verified live (2026-10-04): with the devices deleted, the leftover
     egress proxy could not log in again, hence the change above.
10. **Removal of the bootstrap component.**
    - Delete the `streamtime_tailscale` component across:
      - the resolver;
      - the schema;
      - `package_rules.yaml`;
      - `helm_repos`;
      - the frontend editor;
      - the orchestrator `tailscale_fleet` helpers.
    - Infra-shared tailnet values are untouched.
11. **Verification.**
    - Run the chart unit tests, `./run-tests.sh` for the backend,
      orchestrator, agent (Go) and frontend, and `/regression-check` for the
      agent-config payload.
    - Live, on a fresh fleet (k3-badami after cleanup):
      - automatic install;
      - manual install;
      - agent chart upgrade (a pinned Tailscale bump);
      - a failed-upgrade rollback;
      - after teardown, a new fleet installs on the same cluster.

## Deviations

- **2026-10-05 — the controller trusts the gateway certificate too.** Agent upgrades run
  in `streamtime-operator` (the StreamtimeAgentConfig controller), which pulls the agent
  chart from the registry over the tailnet; it lacked `gatewayCA` and failed with
  `x509: certificate signed by unknown authority` (seen live on elderly-marlin). The
  operator chart takes `gatewayCA` (own ConfigMap, `SSL_CERT_DIR` like the agent), and
  the install passes the agent's `tailscale_values.gatewayCA` as a values document.

- **2026-10-05 — the agent never uninstalls a release to retry it.** A failed or
  interrupted (`pending-*`) release is upgraded in place (`pending-*` is first marked
  `failed` so Helm accepts the upgrade); a timed-out install returns its error for the
  activity retry instead of uninstalling and reinstalling on the spot; `cleanupPending`
  marks failed instead of uninstalling when there is no revision to roll back to.
  Uninstall-and-reinstall left the release's volumes behind, so a Strimzi broker
  crash-looped on `Invalid cluster.id` (seen on developed-alpaca and sick-raven). Only a
  release stuck `uninstalling` is still removed before installing.

- **2026-10-04 — fleet delete keeps the tailnet devices.** Deleting them while
  the agent's Tailscale keeps running left the egress proxy with an identity
  the tailnet no longer knows (`node not found`). The next fleet installed on
  that cluster then hung at the agent's startup check. Seen live on k3-badami
  (`forthcoming-koi`). The operator logs in again by itself; its proxies do
  not. The next fleet's install renames the devices. A cluster that is never
  reused leaves its devices on the tailnet until they are removed by hand.

_None._
- Manual install (PR #1393 review): one path of numbered copy-paste steps
  replaces the "Helm commands" / "Values file" tabs. Settings are written to
  `/tmp` with `cat` heredocs (Agent values from the backend's bootstrap config,
  Operator values with `gatewayCA` on private-network fleets), both charts are
  installed with `helm upgrade --install … -f`, then `kubectl wait` and the
  files are removed. The `--set` path is gone: it dropped the CA bundle and the
  Tailscale values, so it could not verify the orchestrator on those fleets.
- Fresh clusters (2026-10-06): the agent installs before bootstrap brings Gateway
  API, so `streamtime-tailscale` renders the egress `BackendTLSPolicy` only when
  its CRD exists, and fleet bootstrap re-applies the agent's values at its end
  (values-only update, same chart version; patch `agent-values-after-bootstrap`).
- Kong: the host-less `backend-tunnel` route on `/` matched the agent's gRPC calls
  and refused them (404); `temporal-grpc` now also matches the gRPC content type.
