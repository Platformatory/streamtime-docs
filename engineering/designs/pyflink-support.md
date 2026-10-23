# PyFlink support: Single-Job Cluster and Job Workspace, deployed from Flink Projects

## Context
Python Flink Projects exist but are stop-at-storage: a `runtime=python` project accepts `.zip` uploads (`artifact_kind=pyflink_zip`) and
`apply_version` refuses to deploy them (`core/services/flink_project_deploy.py:191`, mirrored in `core/models.py:4840` and the UI picker
`ProjectVersionPicker.jsx:10`). Nothing renders a Python job: no `pythonFile`/PythonDriver branch in `charts/streamtime-flink`,
`-session-job` or `-cfk`, no Python fields in `FlinkAdvancedConfigSchema` / `FlinkJobAdvancedConfigSchema`, and no Flink image with Python in
the repo (image is a free string, default `docker.io/flink:1.17`; there is no `flinkVersion`<->image mapping).

Goals / constraints from the user:
- No custom base images. Streamtime ships and selects the PyFlink image.
- No internet at deploy time. The ZIP must carry its dependencies (wheels, or pre-installed packages); nothing is pip-installed from an index.
- Cover **both** Single-Job Cluster (application mode) and Job Workspace (session). Accept **both** dependency layouts (wheelhouse and vendored).

## Design

### A. Image (Streamtime-owned)
- New `docker/flink-python/Dockerfile`: `docker.io/library/flink:<ver>` + python3 + `apache-flink==<ver>` (pin to the Flink version exactly) + `unzip`/pip.
  Multi-arch (amd64/arm64). Built and pushed by the user (never run build scripts): add a `scripts/build-and-push-flink-python.sh` or a target
  in the existing build script; add the image to `preload/registry_images.yaml` so local-registry sync carries it. Fully qualified name.
- GlobalConfiguration keys (seed migration, raise if missing): `flink_python_image`, `flink_python_python_version` (e.g. `3.11`, used for wheel
  tag checks and CI templates). Chart default image stays JVM-only; the backend overrides `flink.image` for Python deploys. Session clusters
  need the same image on the parent Job Workspace (decision B2).
- Spike first: which Flink version(s) to support. PyFlink caps the Python version per Flink release, and the current default (1.17) is old.
- Open-source provider only. CMF (`streamtime-flink-cfk`) deploys of Python are refused with a plain message.

### B. Zip contract and layout detection (upload time)
New `core/services/flink_pyflink_archive.py`, called from `views/flink_project/versions.py` after the upload is stored (today only the 4-byte
`PK\x03\x04` magic is checked, `flink_artifact_upload.py:80`). It reads only the zip central directory plus a few small members; it never
extracts. Limits: entry count, total declared uncompressed size, per-member size for metadata reads (zip-bomb guard); reject absolute paths,
`..`, and symlinks.

Layout detection (the answer to "how does detection work"), by explicit signals, never by guessing:
1. **Entry file**: `main.py` at the zip root (or the project's/deploy's `entry_file`). Missing -> 400 "no main.py in the zip".
2. **Wheelhouse**: `wheels/*.whl` present plus `requirements.txt`. Wheel filenames give tags (`numpy-1.26-cp311-cp311-manylinux2014_x86_64.whl`
   -> python `cp311`, platform `manylinux...x86_64`; `py3-none-any` = pure).
3. **Vendored**: a `deps/` directory holding installed packages, recognised by `*.dist-info/` directories (every pip install writes one).
   `deps/*.dist-info/WHEEL` has `Tag:` lines, and compiled modules are named like `_x.cpython-311-x86_64-linux-gnu.so`, so tags are readable here too.
4. Both 2 and 3 present -> 400 (ambiguous). `requirements.txt` listing packages with neither wheels nor `deps/` -> 400 with a remedy
   ("build with `pip download -d wheels ...`" or `pip install -t deps`). Neither and no requirements -> layout `none` (pure source), fine.
5. `jars/*.jar` (optional): connector JARs (the Kafka connector is essential for Streamtime users); listed in the manifest.
6. `apache-flink` / `pyflink` inside the wheels or deps -> 400 (the image already provides the exact version; shipping another breaks it).

Result is stored on the version as a derived, immutable `manifest` (new SchemaField `FlinkPyflinkManifestSchema` on `FlinkProjectVersion`:
`layout`, `entry_file`, `python_tags`, `platform_tags`, `jars`, `wheel_count`). Compatibility checks, at upload and again at deploy:
python tag vs `flink_python_python_version` and platform tag vs the target fleet's architecture where known -> 422 with a plain message
("numpy was built for Python 3.12 but this platform runs Python 3.11"). Versions uploaded before this release have no manifest; the deploy
path computes it on the fly.

### C. Single-Job Cluster (application mode)
- Backend (`flink_components.py:322-338`): for a `pyflink_zip` version set `flink.image=flink_python_image` and a new
  `flink.python = {entry_file, layout, ...}` block in place of `application_jar`; keep the signed `artifact` {url, filename, sha256}.
- Schema: `FlinkAdvancedConfigSchema` gains `python_entry_file: Optional[str]` (override of the manifest entry), `application_args` reused as
  program args, `entry_class` ignored for Python. No `job_runtime` field: the runtime follows the version's `artifact_kind`.
  (`extra="forbid"` means this schema change is required.)
- Chart `charts/streamtime-flink`: when `.Values.flink.python` is set:
  - init container 1 (existing curl) downloads the zip; init container 2 (PyFlink image, `python3 -m zipfile`, pip) verifies sha256,
    extracts the zip into emptyDir `streamtime-python-app` (mounted `/opt/flink/pyapp`), for `wheelhouse` runs
    `pip install --no-index --find-links wheels -r requirements.txt --target /opt/flink/pyapp/site`, for `vendored` uses `deps/` as is,
    and copies `jars/*.jar` into `/opt/flink/usrlib`. Init containers sit in the shared pod template, so the JobManager and every TaskManager
    get identical code and deps with no network and no `-pyreq`.
  - main container env `PYTHONPATH=/opt/flink/pyapp/site:/opt/flink/pyapp`.
  - `job:` block renders `entryClass: org.apache.flink.client.python.PythonDriver`, `jarURI: local:///opt/flink/python/flink-python.jar (a copy of the PyFlink jar; a second jar inside /opt/flink/opt makes Flink refuse to start)`
    (exact operator contract to be confirmed in the spike), `args: ["-pyclientexec","python3","-pyexec","python3","-py","/opt/flink/pyapp/<entry>", ...app args]`.
  - `values.yaml` defaults (python block empty), per CLAUDE.md no Helm `default` for static fallbacks. Add helm-unittest cases for JAR unchanged,
    wheelhouse, vendored, jars, missing entry.
- Memory: Python workers run outside the JVM heap; set `python.fn-execution.memory.managed` and a larger managed-memory fraction for Python
  targets in the sizing code (`flink_components.py` L378-395), and document it.

### D. Job Workspace (session jobs)
Constraint found in research: `FlinkSessionJob.job.jarURI` is fetched by the operator and uploaded to the JobManager; a `.py` path must exist
on the JobManager's filesystem, and the operator's session-job support for PythonDriver is unconfirmed. So this phase starts with a spike and
a decision gate:
- **D0 spike (first task, 1 day)**: with the operator version we ship, try a `FlinkSessionJob` running PythonDriver with a file present on the
  session JobManager. Outcome decides D1 or D2.
- **D1 (if the operator supports it)**: the Job Workspace's session cluster uses the PyFlink image; each job's files are made available through
  a workspace-level shared volume populated by an init/sidecar from the job's version. Dependencies are per workspace, not per job (conflicts
  between jobs in one workspace are surfaced in the UI helper text).
- **D2 (if not)**: a Streamtime-managed submit step: a Kubernetes Job on the PyFlink image that prepares the zip (same init logic as C) and runs
  `flink run -m <session-jm-rest> -pyclientexec python3 -py main.py -pyfs <deps dir>`, with `-pyfs` shipping deps to TaskManagers via the
  distributed cache. This replaces the operator's lifecycle for those jobs (cancel/suspend/upgrade-with-savepoint), which is the costly part.
  Reconcile, deploy and delete flows in `flink_job_components.py` and the orchestrator's FlinkJob workflows would need a Python branch.
- Validation in the meantime: `validate_project_version_source` (models.py:4820-4852) and `apply_version` accept Python for `Flink(mode=application)`
  only until D lands; clear 422 message for the rest. Remove the guards per target as each lands.

### E. Backend validation and API
- Replace the JAR-only guards (`models.py:4840`, `flink_project_deploy.py:191`) with per-target rules (mode, provider, image availability).
- Deploy request gets optional `entry_file`; `apply_version` stores it in `advanced_configuration.python_entry_file`.
- `FlinkProjectMetadataSchema.entry_class/default_args` are unused today: decide per kind (entry file default for Python; wire or remove for JAR).
- OpenAPI changes are consumed by CLI, frontend, SDK (CI regenerates; never commit SDK). Run `/regression-check` first.

### F. CI templates and CLI
- `flink_project_ci_templates.py` `pip` profile (L88-95) currently zips the repo root. Replace with: `pip download -r requirements.txt -d wheels
  --only-binary=:all: --python-version <flink_python_python_version> --platform manylinux2014_x86_64` (plus arm64 option), then zip
  `main.py`, source, `wheels/`, `requirements.txt`, `jars/`. The version comes from GlobalConfiguration at render time.
- CLI: `flink-project deploy --entry-file`; optional `flink-project pack <dir>` building a correct zip locally (wheelhouse for the right platform)
  so developers do not hand-roll it. Flink commands: `--entry-file` for create/update; docs.

### G. Frontend
- `ProjectVersionPicker.jsx`: allow `pyflink_zip` for application clusters and Python-capable workspaces; keep JAR-only elsewhere.
- Flink and job forms: when the chosen version is Python, hide Entry class, show Entry file (prefilled from the manifest) and program args;
  labels "Python application" not "JAR". Versions tab: show layout, Python tag, wheel count, jars. Upload dialog: surface the 400/422 layout
  messages in plain language. Detail pages: "Python file" instead of "JAR Path". Terminology rules from CLAUDE.md apply.

### H. Other considerations
- Version pinning: the zip must not contain `apache-flink`; the Streamtime image pins it. Mismatch between the image's Flink and the cluster `flinkVersion` is a hard failure, so one image per Flink version and a mapping config.
- Architecture: arm64 vs amd64 fleets and wheel platform tags (checked at deploy where the fleet arch is known).
- Air-gapped: image and wheels both come from Streamtime; the curl init image is already configurable.
- Security: executes user code like a JAR does; bounded archive inspection prevents zip-bombs and path traversal.
- Observability: Python worker failures surface in TaskManager logs; add the Python tag to deployment status payloads.
- Size: wheelhouses (numpy, pyarrow) are large; check `artifact_storage_max_upload_bytes` default and the 25 s Kong timeout exemption.
- Docs: update `docs/flink/flink-projects.md` (replace the "not supported yet" line), `plans/flink-project.md` Out-of-scope/Deviations, and fix the
  stale section 3.7 of `docs/flink/dev-to-deployment-lifecycle-technical-design.md`.

## Order of work (one commit per step, linear migrations starting after 0196)
1. D0 spike (operator + PythonDriver on application and session) and Flink/Python version decision.
2. Image + config keys (Dockerfile, seed migration, registry sync).
3. Archive inspection + manifest field + migration + upload validation + tests.
4. Application mode: components, chart, helm-unittest, deploy guards, API `entry_file`.
5. CLI, CI templates, docs.
6. Frontend.
7. Job Workspace (D1 or D2 per the spike).
8. Live test on a kind fleet; antipattern and regression checks.

## Verification
- Backend: `./run-tests.sh` on archive inspection (valid wheelhouse, vendored, ambiguous, missing entry, bomb, traversal, wrong Python tag),
  deploy service (Python accepted for application clusters, refused for CMF), components builders, upload view.
- Helm: `helmunittest/helm-unittest` on `streamtime-flink` (and the session-job chart if touched); `helm template` of a Python values file.
- Frontend: vitest for picker, forms, versions tab. CLI: tests for `--entry-file`/`pack`.
- Live: build a small PyFlink Kafka job zip offline (wheelhouse), upload by UI, deploy to a Single-Job Cluster on the kind fleet with the network
  blocked for pods (NetworkPolicy deny egress), confirm running and a checkpoint; repeat with a vendored zip; then the Job Workspace path.

## Progress and deviations
- **2026-10-12 — Application mode (A, B, C, E, F, G) is implemented; Job Workspace (D) and the live run are not.**
  Archive inspection (`core/services/flink_pyflink_archive.py`), `FlinkProjectVersion.manifest` (migration 0200),
  config seeds (0201, 0203), chart Python mode, deploy rules, `entry_file` on deploy, CI template, CLI `--entry-file`,
  frontend picker/dialog/versions column are in.
- **Deviation:** the entry file is stored as `python_entry_file` on the cluster's advanced configuration and sent
  as `entry_file` on deploy; there is no `job_runtime` field (the runtime follows the version's artifact kind).
- **Deviation:** versions uploaded before the manifest existed are refused at deploy with "upload again" rather than
  inspected on the fly.
- **2026-10-12 — Verified live on the kind fleet (operator 1.9.0, Flink 1.17.2, Python 3.10):** a wheelhouse zip (PyYAML compiled + six)
  deployed through the chart ran to FINISHED and the TaskManager's Python function imported both from the offline wheels. The first run failed
  with "Found 2 flink-python jar" (Flink scans /opt/flink/opt itself), so the stable jar name is now a copy outside that folder.
  Not yet exercised live: the vendored layout, jars/, and the full Streamtime deploy path (UI/API) rather than the chart alone.
- **2026-10-12 — D0 spike result (Job Workspace).** On operator 1.9.0 / Flink 1.17.2 a `FlinkSessionJob` runs a Python job when
  (1) the session cluster runs the PyFlink image, (2) the archive is already unpacked on the session cluster's pods (the same init containers,
  but at workspace level), and (3) the job uses `jarURI` = the PyFlink jar over http(s) (the operator downloads it, so `local://` does not
  work here), `entryClass` PythonDriver and args `["-py", "<file>"]` only. **`-pyclientexec`/`-pyexec` must not be sent to a session
  job:** PythonDriver rejects them and exits the JobManager JVM, which takes the whole workspace down. Consequence: the Python code is
  tied to the *workspace's* pods, not to a job, so deploying a different Python version means rolling the whole workspace. D1 therefore
  needs a workspace-level "Python bundle", or D2 (a Streamtime-run submit step). Decision pending.
- **2026-10-12 — Job Workspace implemented as a workspace-level Python version (D1).** The workspace (session cluster) carries the
  `project_version` (Python only) and renders the same init containers with `python.workspace=true` (no job started). A Python job
  must run the workspace's version (409 otherwise) and is submitted with `entryClass` PythonDriver, args `["-py", file]`, and the
  archive itself as `jarURI` under a `.jar` name (signed URL; the operator only needs a file to upload). To make that work the image
  now carries the PyFlink jar in `/opt/flink/lib/flink-python.jar` (PythonDriver on the JobManager classpath); a copy under
  `/opt/flink/opt` would break application mode. Verified live: session job FINISHED, application job FINISHED with the lib jar.
- **2026-10-12 — Also verified live:** the vendored layout and `jars/` (job FINISHED, connector jar present in usrlib), and the backend's real
  chart values for an application cluster and a Job Workspace rendered through the chart (database changes rolled back).
- **Create form:** choosing a Python version in the Flink create form shows "Python file" instead of the JAR location and main class.
  Creating a *job* straight from a Python version is not offered: a Python job is created from a JAR and then switched with the deploy dialog,
  because it must run its workspace's version.
- **Open:** seeded image name/tag (`ghcr.io/streamtime-ai/streamtime-flink-python:1.17.2`, Python 3.10) are unverified choices until the image is
  published; the full API-to-operator run on a registered fleet (Temporal workflows) was not exercised.
