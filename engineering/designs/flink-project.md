# FlinkProject — user-supplied Flink artifacts

## Objective

Let users supply their own Flink artifacts (JAR now, PyFlink zip later) and deploy
them as an Application-mode `Flink` cluster or as a `FlinkJob` on a session-mode
cluster. Users build in their own CI and POST the artifact to Streamtime with a
per-project API key. Each upload is an immutable, versioned artifact; users pick
which version to deploy and can roll back.

## In scope

- `FlinkProject`, `FlinkProjectVersion`, `FlinkProjectDeployment` models; nullable
  `project` / `project_version` FKs on `Flink` and `FlinkJob` (exactly one of
  `application_jar` / `project_version`).
- Artifact storage interface with S3-compatible and local-disk backends, configured
  through `GlobalConfiguration`. Key layout:
  `orgs/<org>/flink-projects/<project>/<version>/<filename>`.
- Multipart upload endpoint; signed, expiring, revocable download URL served through
  Kong (302 to a presigned URL when S3 is configured).
- Per-project scoped API key (`APIKey.scope_resource_type/id`) and an
  `Artifact Publisher` role; key shown once, rotatable.
- CI template generation (GitHub Actions, GitLab CI, generic curl) for the project's
  source location. Source location is metadata only and is never fetched.
- Deploy / rollback endpoints and deployment history; JAR deployment in release 1.
- Frontend, CLI, and docs updates in the same change set.

## Out of scope

- Hosting CI or building artifacts.
- Auto-deploy on upload (upload only registers a version).
- PyFlink deployment (`job_runtime`, `python_file`, archives) — release 2. Python
  zips are accepted and stored in release 1; deploying one returns 422.
- SQL runtime, MCP tools, repository credentials/webhooks.
- Committing the regenerated SDK (CI does this).

## Approach

1. **Spikes first.** (a) Streaming multipart upload inside an async ADRF view
   (fallback: thread-based sync view for upload only). (b) On kind with the Flink
   operator: `https://` `jarURI` in application mode and for `FlinkSessionJob`,
   redirect following, custom-CA TLS, file naming. Fallback is a chart-level init
   container into `/opt/flink/usrlib` with a sha256 check.
   **Delivery:** everything ships on one branch (`feat/flink-project`) and one PR,
   with one commit per step below (not one PR per step).
   **Migrations stay linear:** a single leaf at all times, no merge migrations. Each
   step adds at most one new migration on top of the current leaf; if `origin/main`
   lands a migration first, renumber/re-parent ours on top of it instead of merging.
2. **Foundation (commit 1).** Storage interface + `GlobalConfiguration` keys (S3 secret
   via `fleet_secrets_manager`, not a plain config value), models and migration
   0182 (after main's 0181; renumbered when main added 0175-0181), `APIKey` scope + role, project CRUD, upload/download, Kong routes and body
   limits, optional PVC for the local backend.
3. **Deploy (PR 2).** FKs + validation, artifact resolution to a signed URL in
   `flink_components._build_runtime_values` / `flink_job_components._build_runtime_values`,
   `deploy` / `rollback` / `deployments` endpoints through the existing reconcile
   and job dispatch paths. Run `/regression-check` first.
4. **CI templates + key rotation (PR 3).**
5. **Frontend + CLI + docs (PR 4).**

### Spike result: multipart upload in an async view (2026-10-01)

Tested on the backend's own stack (Django 5.2.8, DRF 3.16.1, adrf 0.1.11, uvicorn
0.38) with a standalone ASGI app, real HTTP uploads of 20–45 MB. **Outcome: the
planned approach works; the sync-view fallback is not needed.** Constraints it
established:

- A custom `FileUploadHandler` set via `request._request.upload_handlers` before the
  first body access streams chunks; sha256 and size were exact and nothing was kept
  on the request. Parsing is sync DRF code, so run `request.data` / `request.FILES`
  inside `sync_to_async` (adrf's `AsyncRequest` only overrides auth).
- **Django's ASGI handler buffers the whole body before the view runs** (throttled
  upload: view started after the body had fully arrived). Memory is fine (spools to
  disk past `FILE_UPLOAD_MAX_MEMORY_SIZE`), but each in-flight upload costs up to
  `max_upload_bytes` of temp disk in the backend container, and a cap in the handler
  cannot save that disk. Enforce the limit early: Kong `request-size-limiting`, plus a
  `Content-Length` pre-check in the view (413). Document disk headroom.
- Cap inside the handler works (`StopUpload`; rejected at the cap with 413).
- **A request without `Content-Length` (chunked) parses as empty and the view would
  return 200.** The upload view must return 411 when `Content-Length` is missing and
  400 when no file was parsed. `curl -F` always sends `Content-Length`, so the
  generated CI templates are fine.
- Consequence for storage: the handler runs sync in a worker thread, so the storage
  interface gets a **sync upload writer** (`begin_upload(key)` → `write(chunk)` /
  `commit()` / `abort()`; local = temp file + rename, S3 = boto3 multipart) used by
  the handler; read, presign, exists and delete stay async.

Key design points:
- Signed URLs are deterministic per deployment (expiry fixed on the deployment row)
  so repeated reconciles do not change the spec. Long TTL is acceptable only because
  every download checks `revoked` in the database.
- A scoped key is rejected by the permission middleware on any path outside its
  project, in addition to the view-level scope check.
- Same version + same sha256 on upload is idempotent (200); different sha256 is 409.
- Rollback is a deploy of an earlier version through the existing update workflows;
  `upgrade_mode` can be overridden because savepoints from a newer version may not
  restore on an older one.

## Deviations

- **No Create/Update/Delete workflows for `FlinkProject`.** It provisions no
  infrastructure (it is a catalog resource like `Secret` / `APIKey`); deployments
  reuse the existing `Flink` and `FlinkJob` workflows.
- **Artifact reference is an FK to `FlinkProjectVersion`**, not the generic
  `artifact_package` FK sketched in
  `docs/flink/dev-to-deployment-lifecycle-technical-design.md` §4.7, to keep the
  change minimal. Update that doc when implemented.

- **2026-10-04 — Only `project_version` is stored on `Flink` / `FlinkJob`.** No separate
  `project` FK: the project is `project_version.project`, so a second column would only
  add a consistency rule to maintain.
- **2026-10-04 — "Version XOR `application_jar`" is enforced in `clean()`, not by a DB
  constraint.** `application_jar` lives inside a JSON column, which a `CheckConstraint`
  cannot inspect portably across SQLite and Postgres. `save()` already runs `full_clean()`.
  The serializer/schema half lands with the deploy change (`FlinkJob.application_jar` is
  still required by its Pydantic schema until then).
- **2026-10-04 — `GlobalConfiguration` keys use underscores** (`artifact_storage_backend`,
  `_local_root`, `_max_upload_bytes`, `_s3_*`), matching the existing `container_registry_*`
  keys. Seeded with local-backend defaults by migration 0182.
- **2026-10-04 — Storage writes use boto3 in worker threads, not aioboto3**, because the
  upload handler is sync (see the spike result).
- **2026-10-04 — `Artifact Publisher` is not in `ALLOWED_API_KEY_ROLES`.** That list gates
  the generic API-key endpoint; the role is only issued as a project-scoped key at
  project creation (`create_flink_project_api_key`), so no unscoped publisher key exists.
  Permissions are split into `organization.flink_project` and
  `organization.flink_project_artifact` so the publisher only gets artifact add/view.
- **2026-10-04 — Upload size is capped by the backend, not Kong.** Kong's authz plugin
  only protects the route named `backend`, so a separate upload route would bypass auth,
  and `request-size-limiting` on `backend` would cap every API call. The view enforces
  `artifact_storage_max_upload_bytes` from `Content-Length` (413) and during streaming.
  Operators who need a hard network-level cap should set one on their ingress.
- **2026-10-04 — The version label is the `?version=` query parameter, not a form field.**
  The storage key needs the version when the file part starts, and a multipart text field
  may arrive after the file. `curl -X POST "$URL/versions/?version=1.4.0" -F file=@app.jar`.
- **2026-10-04 — Download URLs use the existing `fleet_manager_external_url` key** (no new
  `public_base_url`); the TTL and redirect settings are seeded by migration 0183. The
  version row is written before bytes are committed to storage, so a racing duplicate
  upload can never overwrite the winner's artifact.
  The chart (API Deployment) and docker-compose emit `STREAMTIME_GLOBAL_FLEET_MANAGER_EXTERNAL_URL`,
  which startup seeding writes into the key when it is empty; the code reads only
  GlobalConfiguration (no env fallback).
- **2026-10-04 — Upload and download paths are exempt from `RequestTimeoutMiddleware`**
  (25 s cap; the upload exemption matches only `/organizations/<org>/flink-projects/<id>/versions/`), and the download path from `OrgJWTUserCheckMiddleware` so `HEAD` works.
- **2026-10-04 — `application_jar` is optional on FlinkJob (decision: option A).** Chosen after
  the `/regression-check` impact report. Exactly one of `application_jar` / `project_version`
  must be set, enforced by `FlinkJob.clean()` and the serializer (not by a Pydantic default).
  Existing rows are untouched. Updated in the same change: the job and cluster form-schema
  endpoints (no longer list it as required), `FlinkSerializer.validate`, and the job PATCH
  dispatch condition (also fires on `project_version`).
- **2026-10-04 — Deployments are recorded by one code path.** `apply_version` (deploy and
  rollback endpoints) and the serializer `save()` hook (create / PATCH with `project_version`)
  both append a `FlinkProjectDeployment`; chart values mint the signed URL from the target's
  active deployment, whose expiry is fixed, so rebuilding values yields the identical URL.
  Earlier deployments are not revoked on redeploy: the Flink operator may roll back to the
  previous spec, which still points at the previous URL. The URL lifetime is
  `artifact_storage_deployed_url_ttl_seconds` (default 1 year): redeploy before it elapses,
  or raise it, otherwise a pod restarted after expiry cannot fetch its JAR.
- **2026-10-04 — Operator `jarURI` spike not run.** Whether the Flink Kubernetes Operator and
  JobManager can fetch an `https://` `jarURI` through Kong (redirects, the dev self-signed CA)
  needs a real cluster that can reach Streamtime's external URL. The URL is injected as
  `flink.application_jar` / `job.applicationJar` exactly like any remote JAR. If fetching
  fails in a given environment, the planned fallback is a chart init container that downloads
  the artifact (with a sha256 check) into `/opt/flink/usrlib`. Verify before relying on it.
- **2026-10-08 — Spike result: application mode cannot use a remote `jarURI`; JAR is downloaded by an init
  container.** On a real cluster (Flink 1.17, Kubernetes operator) a FlinkDeployment with an `http://`
  `jarURI` failed with `Only "local" is supported as schema for application mode`; the cluster never
  started (the URL itself was reachable from a pod and returned the exact file). So for application-mode
  clusters of the open-source provider, `streamtime-flink` now has `flink.artifact.{url,filename,sha256,image}`:
  an init container in the shared pod template downloads the JAR into `/opt/flink/usrlib` (checksum verified),
  the same on the JobManager and every TaskManager, and `application_jar` is `local:///opt/flink/usrlib/<file>`.
  The backend (`FlinkComponentsService._build_runtime_values`) sets both. Not changed: the CMF provider
  (`streamtime-flink-cfk`) still receives the URL, and session jobs still receive `job.applicationJar` as a URL
  (the operator downloads for session jobs; still to be verified on a cluster).
- **2026-10-08 — Orchestrator waited for a FlinkDeployment name that does not exist.** The first end-to-end
  deploy showed `FlinkCreateWorkflow` polling `<release>` while the chart renders `<release>-streamtime-flink`
  (also in the published default chart), so a healthy open-source cluster stayed `Provisioning` and the
  create workflow failed when its attempts ran out. Not specific to project versions. The wait now uses
  `shared/helm_names.helm_fullname`, which mirrors the chart's `fullname` helper (`fullnameOverride`,
  `nameOverride`, release-contains-chart-name), behind `workflow.patched("flink-status-wait-chart-fullname")`.
  The CMF provider's wait and the session job wait are unchanged. Needs an orchestrator rebuild.
- **2026-10-08 — Savepoint / last-state upgrades are refused when the saved state would not survive.** A real
  deploy of 2.0.0 with "Keep running state" crash-looped the JobManager: the operator took a savepoint into the
  wizard's default `file:///tmp/flink-savepoints`, which lives on the old pod and was gone when the new pod
  tried to restore it. `core/services/flink_state_storage.py` now makes the deploy and rollback endpoints answer
  422 with a plain-language reason when the requested (or, with no choice, the configured) mode needs durable
  state and the cluster's savepoint / checkpoint location is local or unset (durable: s3, s3a, gs, hdfs, abfs,
  oss and similar). Targets that never ran are exempt. The deploy dialog applies the same rule (`stateModeSupport`
  in `utils.js`): the unusable choices are disabled with the reason and "Start fresh" is selected. Not covered:
  changing `project_version` through a cluster PATCH, which bypasses these endpoints.
- **2026-10-08 — Status wait accepted the previous spec's READY.** After a Helm upgrade the update workflow's wait
  ran 2 s later, read the old JobManager's `READY` before the operator noticed the change, and Streamtime reported
  Healthy while the new pods were still starting. `WaitUntilStatus` has a new optional
  `require_observed_generation` (agent, backwards compatible): the status only counts once
  `status.observedGeneration >= metadata.generation`. The orchestrator sets it for open-source Flink clusters
  behind `workflow.patched("flink-status-wait-observed-generation")`. Needs the agent image and orchestrator rebuilt.
- **2026-10-08 — The generation guard also covers Flink session jobs.** A job update reads the previous spec's
  `RUNNING` for a moment after the Helm upgrade, the same as a cluster. `FlinkJobCreateWorkflow` (which the update
  workflow reuses) now sets `require_observed_generation` behind `workflow.patched("flink-job-status-wait-observed-generation")`,
  and the agent's `DeployFlinkJobWorkloadWorkflow` passes it to `WaitUntilStatus`. Verified on a real session job
  that the JAR is fetched by the operator from the signed URL (no init container needed for session jobs).
- **2026-10-08 — Follow-up PR (branch feat/flink-project-followups).** (1) Flink Project wording follows the
  Flink create form: Single-Job Cluster, Job Workspace, Runtime, Build tool, Source provider, Repository URL,
  Build branch, CI/CD, State handling. (2) `FlinkProject.language` is renamed `runtime` (migration 0196, API
  field and `?runtime=` filter, CLI `--runtime`; the `--language` flag is gone, safe because the CLI command
  group is unreleased). (3) Build tools depend on the runtime (java: maven/gradle/other; scala: + sbt; python:
  pip/other), enforced by the API and mirrored in the create form. (4) **Upload Version** on the project page
  (file + editable, pre-filled next version) using the existing upload endpoint, no API change. (5) The CI
  template block uses theme colours (it was unreadable in dark mode). (6) CI templates upload with the Streamtime
  CLI instead of `curl`: the pipeline downloads the CLI from the operator-set `streamtime_cli_download_url`
  (no seed migration; the CI/CD tab answers 409 with a plain message until it is set) and runs
  `streamtime flink-project upload`. The CLI authenticates from `STREAMTIME_API_KEY`/`STREAMTIME_ORG`/
  `STREAMTIME_URL` with no config file, has `flink-project update`, and now has its first tests. Building and
  publishing the CLI binary is outside this repo's pipelines today (deployment work on the user's side).

