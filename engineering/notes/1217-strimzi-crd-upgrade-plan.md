# Issue #1217 — Strimzi CRDs not upgraded on operator version change

## 1. Root cause confirmation

**Confirmed. Single choke point, not Strimzi-specific.** Every Helm upgrade in the
agent — for every component, not just Strimzi — goes through one function that
never re-applies a chart's `crds/` directory, exactly matching stock Helm
behavior:

- `streamtime-agent/internal/helm/installer.go:329` — `Client.Upgrade()`.
  It loads the target chart (`loader.Load(chartPath)` at line 507, giving a
  `*chart.Chart` that already has `.CRDObjects()` available) and runs
  `action.NewUpgrade(actionConfig)` (line 469) → `upgrade.RunWithContext(...)`
  (line 519). `action.Upgrade.SkipCRDs` (line 471) is a red herring — per the
  Helm SDK, that field only takes effect when `upgrade.Install == true`
  (i.e. `helm upgrade --install` falling back to a fresh install). This repo's
  `Upgrade()` never sets `upgrade.Install = true`, so `SkipCRDs` here is a
  no-op and CRDs are simply never touched on a real upgrade.

**Every version-bump path funnels into this one function:**

- `streamtime-agent/internal/activities/helm.go:141-228` — the `HelmInstall`
  activity (used by both fleet bootstrap and workload deploy) checks if the
  release already exists and is `deployed`; if so it silently builds a
  `HelmUpgradeInput` and calls `h.Upgrade(...)` instead ("idempotent
  behavior", line 186-190). So *any* re-run of an install path against an
  existing cluster — not just an explicit "update" call — lands in
  `Client.Upgrade()`.
- `streamtime-agent/internal/workflows/strimzi.go:383-451` —
  `UpdateStrimziWorkloadWorkflow` calls `ActivityNameHelmUpgrade` directly.
- `streamtime-agent/internal/workflows/cfk.go:93,617` — mirrors the Strimzi Go
  workflow exactly (`SkipCRDs: chartConfig.SkipCRDs` passed through, no
  CRD-specific handling anywhere in the file).
- `fleet-manager-orchestrator/workflows/fleet_provider_base.py:343`
  (`bootstrap_cluster`, called from `byok_provider.py:197`,
  `aws_provider.py:3167`, `azure_provider.py:1911`, `gcp_provider.py:1936`,
  `oci_provider.py:3666`) builds the **operator** chart entries (Strimzi at
  `bootstrap_resolver.py:26-37`, CFK at `bootstrap_resolver.py:49-59`) and
  dispatches them via `BootstrapFleetClusterWorkflow`
  (`streamtime-agent/internal/workflows/bootstrap.go:70`), which always calls
  `ActivityNameHelmInstall` — meaning a fleet re-bootstrap that bumps the
  Strimzi/CFK operator's `resolved_version` on an *existing* cluster also
  falls through the idempotent-upgrade branch above.

**On the "CFK already solves this" premise (corrected):** it doesn't, at
least not in this codebase. I checked `cfk.go` and `cfk.py` line-by-line
against `strimzi.go`/`strimzi.py` — the CRD-related comments in `cfk.py:558`
and `cfk.py:772` ("still verifies its CRDs are actually being served",
"prove that every API...") are about **Gateway API CRDs** (Envoy Gateway,
shared with Strimzi too, see `bootstrap_resolver.py:90-100`), not about the
CFK/Strimzi operator's own CRDs. There is no orchestrator- or agent-side code
that special-cases CFK's operator CRDs at all. If CFK genuinely survives an
operator upgrade unscathed in practice, it's because Confluent's upstream
`confluent-for-kubernetes` chart likely bundles its own pre-upgrade Helm hook
Job that runs `kubectl apply` on its CRDs internally — that would be chart-side
behavior in a chart we don't vendor or control, not something this repo
implemented. The commit `39d280078` (IRSA fix applied only to `cfk.py`) is a
precedent for the *pattern* of one operator's code path getting a fix the
other didn't — not evidence that this specific bug is already fixed for CFK.
Given that, **the fix should not be Strimzi-specific**: CFK operator upgrades
have the identical exposure and should get the same fix.

**Existing reusable mechanism found:** `ApplyManifest` activity
(`streamtime-agent/internal/activities/kubernetes.go:102-167`) already does
exactly the operation we need — split a multi-doc YAML string, decode each
object, and apply it with `dynamicClient.Resource(mapping.Resource)...Patch(...,
types.ApplyPatchType, ..., metav1.PatchOptions{FieldManager: "streamtime-agent",
Force: boolPtr(true)})`. That's a server-side apply with forced conflict
resolution — the right primitive for re-applying CRDs. It's currently only
wired up for `domain_certificate.go:93`, nothing CRD-related.

## 2. Proposed fix

Apply the target chart's bundled CRDs (`chart.CRDObjects()`, obtained free
from the `loader.Load()` call that already happens) via a server-side-apply
patch, gated by the same `SkipCRDs` flag that already threads end-to-end from
`bootstrap_resolver.py` → `ChartInstallConfig.skip_crds` → Go `HelmUpgradeInput.SkipCRDs`.

**Where:** `streamtime-agent/internal/helm/installer.go`, inside
`Client.Upgrade()`, right after the chart is loaded (line 507) and before
`upgrade.RunWithContext(...)` (line 519):

```go
chart, err := loader.Load(chartPath)
...
if !req.SkipCRDs {
    if err := c.applyChartCRDs(chart); err != nil {
        return nil, NewError(ErrCodeUpgrade, "apply chart CRDs before upgrade", err)
    }
}
release, err := upgrade.RunWithContext(ctx, req.Release, chart, vals)
```

`applyChartCRDs` is a small unexported helper on `Client` (same package,
so it can reuse `c.getter.ToRESTConfig()` exactly as `newActionConfig` already
does at line 618) that:
1. Builds a `dynamic.Interface` from the REST config (same as
   `kubernetes.go:114-121`).
2. Iterates `chrt.CRDObjects()` (`[]chart.CRD`, each with `.File.Data` raw
   YAML bytes) — no new fetch, parsing, or version-diff logic needed, this is
   the exact same bytes Helm would install fresh with today.
3. Decodes each into `unstructured.Unstructured` and applies it via
   `types.ApplyPatchType` with `FieldManager: "streamtime-agent"`,
   `Force: true` — identical pattern to `ApplyManifest`.

Why gate on `SkipCRDs` rather than doing this unconditionally for every
chart: `bootstrap_resolver.py:60-89` shows Kong's `gateway-operator` component
deliberately sets `skip_crds=True` to avoid clobbering Envoy Gateway's newer
Gateway API CRDs with its own older bundled ones (see the comment there about
the `ValidatingAdmissionPolicy` rejection). If CRD-apply-on-upgrade were
unconditional, a later Kong chart bump would resurrect exactly that conflict.
Gating on the existing flag makes upgrade-time CRD handling symmetric with
install-time CRD handling per component — Strimzi and CFK (`skip_crds` unset,
defaults to `False`) get the fix; Kong/envoy_gateway's deliberate deferral is
preserved.

**Why not a Strimzi-only hook, and not a new orchestrator-level flag:** the
same bug and the same fix apply to CFK; putting it once in `Client.Upgrade()`
covers both (and Kong/cert-manager/anything else added later) with a single
change, using a flag that already exists and is already plumbed through every
layer (`bootstrap_resolver.py` → `ChartInstallConfig` → `HelmUpgradeInput`).
No new config surface, no per-resource special-casing.

## 3. Where this hook lives (summary)

| File | Change |
|---|---|
| `streamtime-agent/internal/helm/installer.go` | Add `applyChartCRDs(chrt *chart.Chart) error` on `Client`; call it from `Upgrade()` before `upgrade.RunWithContext`, gated by `!req.SkipCRDs` |
| `streamtime-agent/internal/helm/installer_test.go` | New tests (see below) |

No orchestrator (Python) or backend changes are needed — `skip_crds` is
already resolved per-component in `bootstrap_resolver.py` and already flows
through `ChartInstallConfig`/`HelmUpgradeInput` unchanged.

## 4. Edge cases

- **CRD schema changes breaking existing CRs:** Server-side apply patches the
  `CustomResourceDefinition` object itself, not the CRs stored under it —
  existing `Kafka`/`KafkaTopic`/etc. objects in etcd are untouched by this
  step. The real risk is narrower: if a new CRD manifest drops a `served`/
  `storage` API version that existing CRs still use, the apply can fail (API
  server validation) or, if forced through, make old stored objects
  inaccessible until a storage migration runs. Strimzi and CFK both keep
  backward-compatible version lists across minor/patch bumps in practice, but
  a major version jump is exactly where this could bite. Mitigation: let the
  apply fail loudly (return the error, don't force past a rejected CRD
  update) rather than silently swallowing it — `Client.Upgrade()` already
  returns an error on failure here in the proposed fix, so this falls out
  for free. A dry-run/version-diff step is not needed up front; add one only
  if this actually bites in practice (YAGNI).
- **Downgrades:** applying an older chart's CRDs over a newer one can hit the
  same served/storage-version removal problem in reverse. Out of scope here —
  Helm itself has no downgrade protection either, and neither does the rest
  of this codebase's chart handling; not a new risk introduced by this fix.
- **Skipped versions (e.g. 0.40 → 0.45 in one hop):** not a special case —
  `chart.CRDObjects()` always reflects the *target* version's bundled CRDs
  regardless of how far the version jump is, so this is handled the same as
  a single-minor-version bump.
- **First-time install vs. subsequent upgrade:** unaffected — `Install()`
  already installs CRDs correctly via `install.SkipCRDs` (line 184) and is
  untouched by this change; the fix only touches the `Upgrade()` path.
- **`SkipCRDs=True` components (Kong/envoy_gateway):** explicitly preserved,
  see section 2.

## 5. Testing approach

**Reproduce the bug (manual, on a kind or BYOK cluster):**
1. `./scripts/setup-dev-fleet.sh` to get a fleet with Strimzi installed at an
   older chart version (pin via `bootstrap_resolver.py`'s registry/package
   rules or a `PackageRule` override, per `/package-upgrade`).
2. Confirm CRDs installed match that version:
   `kubectl get crd kafkas.kafka.strimzi.io -o jsonpath='{.spec.versions}'`.
3. Trigger an operator version bump to a newer Strimzi chart (via whatever
   path resolves `resolved_version` for the `strimzi` component — a package
   sync picking up a new default, or a `PackageRule` pin change) and dispatch
   the fleet's bootstrap/update workflow.
4. Without the fix: CRDs stay on the old schema, operator pod crash-loops or
   errors on CR fields the old CRD doesn't recognize. With the fix: CRD
   `spec.versions` reflects the new chart's bundled CRDs and the operator
   comes up clean.

**Automated (`streamtime-agent/run-tests.sh`, never raw `go test`):**
- New unit test in `installer_test.go` (same fake-`actionConfigFactory` +
  `kubefake.PrintingKubeClient` pattern already used by
  `TestUpgradePreserveExistingReleaseSkipsPendingCleanup`): assert
  `Upgrade()` calls the CRD-apply path when `SkipCRDs=false` and skips it
  when `SkipCRDs=true`. Use a `dynamic/fake` client (already an established
  pattern in this repo — see `activities/delete_namespace_test.go`,
  `activities/openshift_discovery_test.go`) to assert the CRD objects from a
  fixture chart's `crds/` dir get a `Patch` call with `types.ApplyPatchType`.
- Negative test: a chart with no `crds/` directory — `Upgrade()` proceeds
  normally with zero CRD-apply calls (covers the common case, e.g. the
  `fleet-manager-strimzi` wrapper chart which has no `crds/` of its own).
- Regression test for the Kong/envoy_gateway case: `SkipCRDs=true` upgrade
  never touches the dynamic client's CRD resource at all.

**End-to-end verification across a real version bump:** deploy against two
consecutive real Strimzi chart releases (e.g. current pinned version →
next minor) on a disposable kind cluster, per `/live-fleet-debug`; assert via
`kubectl get crd -o yaml` diff that the CRD `spec.versions` list changed to
match the new chart, and that the operator pod is `Running` (not
`CrashLoopBackOff`) post-upgrade. Always `./scripts/cleanup-byok-resources.sh`
/ `./scripts/purge-cloud-account.sh` after, per CLAUDE.md.
