# Flink projects

Flink projects let you build Flink applications in **your own CI**, publish each build to
Streamtime as an immutable, numbered **version**, and then **deploy** or **roll back** any
version on a Single-Job Cluster or as a job in a Job Workspace. Streamtime never
runs your builds and never reads your source repository.

Design record: [`plans/flink-project.md`](https://github.com/streamtime-ai/fleet-manager/blob/main/plans/flink-project.md).

## How it fits together

1. **Create a project** (UI: Flink projects, CLI: `streamtime flink-project create`). You get a
   **CI Key**, shown once. It is scoped to that one project and can only upload versions.
2. **Add the pipeline** Streamtime generates (GitHub Actions, GitLab CI, Bitbucket Pipelines, or a
   generic shell script) to your repository and store the key as the CI secret `STREAMTIME_API_KEY`.
   The pipeline builds your project, downloads the Streamtime CLI and runs `streamtime flink-project upload`
   with that key, which can only reach this project's versions.
3. Each build uploads a new version (`streamtime flink-project upload`, or
   `POST /organizations/{org}/flink-projects/{project}/versions/?version=<label>`), and you can also upload a
   file yourself with **Upload Version** on the project page (the version is pre-filled with the next one and
   can be changed). Re-sending the same version with identical bytes is a no-op (safe for CI retries);
   different bytes under an existing version are refused. Publish a new version instead.

The CLI needs only environment variables in CI: `STREAMTIME_API_KEY`, `STREAMTIME_ORG` and `STREAMTIME_URL`
(no `streamtime configure` step). `STREAMTIME_VERIFY_SSL=false` skips certificate checks for local setups.
4. **Deploy** a version (UI, `streamtime flink-project deploy`, or `POST .../deploy/`). Streamtime
   points the cluster or job at that version and starts the normal update. **Roll back** switches to
   the previous version (or one you name).
   For a first deployment there is nothing to update yet: use "Deploy to a new Single-Job Cluster" on a version row (or the
   "Create a Single-Job Cluster / a job in this Job Workspace" buttons in the deploy dialog). They open the normal create form with that
   version already chosen.

A cluster or job runs *either* a JAR location (`application_jar`) *or* a project version (`project_version`),
never both. Creating or editing a cluster/job with `project_version: {"project": "...", "version": "..."}`
works the same way as the deploy endpoint.

### Keeping running state during a switch

"Keep running state" and "Resume from the latest checkpoint" restore the new pods from files the old pods wrote,
so those files must outlive the pods: use shared storage such as an S3 bucket (`s3a://...`), Google Cloud
Storage or HDFS for the cluster's savepoint and checkpoint locations. A local `file://` location (the default)
is lost when the pods are replaced. For such a cluster the deploy dialog disables those two choices, and the
API refuses them with a 422, so only "Start fresh" is possible.

### Rolling back safely

Older code may not be able to read state written by a newer version. Roll back with
`upgrade_mode: stateless` (UI: "Start fresh") if the application does not start.

## Operator setup

Settings live in `GlobalConfiguration` (seeded by migrations 0182 and 0183):

| Key | Default | Meaning |
|---|---|---|
| `artifact_storage_backend` | `local` | `local` (directory) or `s3` (any S3-compatible bucket) |
| `artifact_storage_local_root` | `/data/backend/artifacts` | Directory for the `local` backend. Must be persistent |
| `artifact_storage_max_upload_bytes` | `536870912` | Largest accepted artifact (512 MiB) |
| `artifact_storage_s3_bucket` | | Bucket (s3 backend, required) |
| `artifact_storage_s3_region` / `_endpoint_url` / `_path_style` | | Optional. Endpoint and path-style for MinIO, RustFS and similar |
| `artifact_storage_s3_credentials_secret` | | Path of a root-organization Secret holding JSON `{"access_key_id": "...", "secret_access_key": "..."}`. Unset = default AWS credential chain |
| `artifact_storage_download_url_ttl_seconds` | `900` | Lifetime of links generated for people |
| `artifact_storage_deployed_url_ttl_seconds` | `31536000` | Lifetime of the URL embedded in a deployed cluster/job |
| `artifact_storage_redirect_to_presigned` | `true` | With s3, redirect downloads to a presigned storage URL |
| `fleet_manager_external_url` | seeded by the Helm chart and docker-compose | **Required.** Address clusters use to reach Streamtime (through the gateway) |
| `streamtime_cli_download_url` | (unset) | **Required for generated CI pipelines.** Address of the Streamtime CLI binary (a Linux amd64 build) that pipelines download and use to upload. Without it the CI/CD tab shows a message instead of a pipeline. Publishing the binary there is part of your release process |
| `artifact_download_base_url` | (unset) | Optional. Address Flink clusters download deployed JARs from, when it differs from `fleet_manager_external_url`. Falls back to that key. Changing it changes the JAR address of future deploys and reconciles, which can restart running jobs |

* **Storage.** `local` suits the single-node image and development (docker-compose mounts the
  `artifact-data` volume; the Helm chart has `fleetmanager.api.artifactStorage.persistence`). With more
  than one API replica use an S3-compatible bucket: a ReadWriteOnce volume cannot be shared. Add a
  lifecycle rule to abort incomplete multipart uploads in the bucket.
* **Upload size.** The backend refuses artifacts above `artifact_storage_max_upload_bytes`. The server
  buffers a request body on local disk before the view runs, so keep headroom of
  `max_upload_bytes x concurrent uploads` in the API container's temporary directory. Set a hard
  network-level limit on your ingress if you need one (Kong's authz plugin protects only the `backend`
  route, so an upload-specific Kong route/limit would bypass authentication).
* **Download URLs.** Clusters fetch their JAR with an unauthenticated HTTPS GET to
  `{external_url}/artifacts/download/{token}/{file}`; the signed token is the credential. The URL is
  fixed per deployment, so reconciling does not change the cluster spec. Earlier deployments stay valid
  because the Flink operator can roll a failed upgrade back to the previous spec. A URL stops working
  when its deployment's version is deleted, or once `artifact_storage_deployed_url_ttl_seconds` elapses:
  redeploy (or raise the TTL) before then, or a pod restarted afterwards cannot fetch its JAR.
* **Clusters must be able to reach `artifact_download_base_url`** (or `fleet_manager_external_url` when that is unset) and trust its certificate.
* **Local kind clusters:** `api.streamtime.local` only exists on your host, so pods cannot resolve it.
  `scripts/setup-dev-fleet.sh` runs `scripts/configure-kind-dns.sh`, which adds one CoreDNS entry
  pointing that name at the Docker host (rerun it by hand on an existing cluster; `--dry-run` shows the
  change, `--remove` undoes it). docker-compose seeds `artifact_download_base_url` as
  `http://api.streamtime.local:8000` (the gateway's plain-HTTP port, so no certificate to trust). Local
  development only.
  Flink's application mode only runs JARs that are already inside the pod, so the chart adds an init
  container that downloads the version into `/opt/flink/usrlib` on the JobManager and every TaskManager
  (same URL, same checksum check) before Flink starts. The init container needs the `curl` image
  (`docker.io/curlimages/curl`; override `flink.artifact.image` in air-gapped environments).

### Setting the CLI download address

`streamtime_cli_download_url` is the full URL of a Linux amd64 Streamtime CLI binary: plain `http(s)://host/path`,
no query string (a presigned URL will not work), reachable by CI runners without credentials. Set it one of three ways:

* **docker-compose:** put `STREAMTIME_GLOBAL_STREAMTIME_CLI_DOWNLOAD_URL=https://.../streamtime-linux-amd64` in your `.env`
  (see `env.example`) and recreate the backend (`docker compose up -d`).
* **Helm:** `fleetmanager.globalConfig.streamtime_cli_download_url` in your values.
* **Any running install:** `manage.py shell`, then
  `GlobalConfiguration.set_value("streamtime_cli_download_url", "https://.../streamtime-linux-amd64")`.

The first two only fill the setting while it is still empty, so an edit to `.env` or the Helm values after the first
start does not replace the stored value; use the third way to change it. The same applies to `artifact_download_base_url`
(`fleetmanager.globalConfig.artifact_download_base_url` in Helm).

## Access and keys

* The CI key has the `Artifact Publisher` role and a single-project scope. The permission middleware
  confines it to `flink-projects/{project}/versions/...`; every other path returns 403, whatever its role.
* Rotate a lost or leaked key with `streamtime flink-project rotate-key` (UI: the "CI Key" section on the project page). The old key
  stops working immediately.
* Deploying changes a Flink cluster or job, so it needs both the Flink project and Flink permissions
  (Cluster Administrator and Administrator have them).

## API summary

| Method and path (under `/organizations/{org}/`) | Purpose |
|---|---|
| `GET, POST flink-projects/` | List / create (create returns the one-time key) |
| `GET, PUT, PATCH, DELETE flink-projects/{id}/` | Project (delete refused while a version is deployed) |
| `POST flink-projects/{id}/rotate-key/` | New CI key |
| `GET, POST flink-projects/{id}/versions/?version=` | List / upload (multipart, field `file`, optional `metadata`) |
| `GET, DELETE flink-projects/{id}/versions/{version}/` | One version |
| `GET flink-projects/{id}/versions/{version}/download-url/` | Temporary link for a person |
| `GET flink-projects/{id}/ci-template/?provider=&format=` | Pipeline for your CI |
| `POST flink-projects/{id}/deploy/`, `.../rollback/` | Deploy / roll back (202, returns immediately) |
| `GET flink-projects/{id}/deployments/` | Deployment history |
| `GET /artifacts/download/{token}/{file}` | Signed download (no key) |

## Python (PyFlink) projects

A Python project (runtime **Python**) takes a `.zip` per version. Python versions run on open-source Flink on a
Streamtime-provided PyFlink image; you do not bring a base image.

* **Single-Job Cluster:** deploy the version to the cluster, as for a JAR.
* **Job Workspace:** the Python code lives on the workspace's own pods, so you deploy the version **to the Job Workspace**
  (it restarts to load the code), and then create each job from that same version (the job form offers Python projects
  and starts from the workspace's version) or deploy the version to an existing job, choosing the Python file the job
  runs. A job can only run the version its workspace runs, and a workspace refuses a different version while it has
  Python jobs on another one (the jobs would silently run the new code): delete those jobs, deploy the new version to the
  workspace, then create them again from it.
* **Do not wait for the job inside `main()` in a Job Workspace.** Calling `.wait()` on the result of `execute_sql(...)`
  (the PyFlink examples do, for local runs) makes the submission last as long as the job. The submission is a request
  that times out after about ten seconds, so the job runs but the workspace reports a timeout. Leave `.wait()` out
  of jobs that run in a workspace; it is fine in a Single-Job Cluster.

Flink clusters may have no internet access, so **the zip carries its dependencies** and nothing is installed from an
index when the pods start. The upload is checked and refused with a reason if it does not fit:

| In the zip | Meaning |
|---|---|
| `main.py` at the root | Required. The file that starts the job (deploy can name another with `--entry-file`). |
| `wheels/*.whl` + `requirements.txt` | **Wheelhouse** (both are required; every package `requirements.txt` names must have a wheel, because the pods install offline). Build with `pip download -r requirements.txt -d wheels --only-binary=:all: --python-version <X.Y> --platform manylinux2014_x86_64`. |
| `deps/` (output of `pip install -t deps`) | **Vendored** packages, used as they are. Use one of `wheels/` or `deps/`, not both. |
| `jars/*.jar` | Optional connector JARs (for example the Kafka connector), added to the job's classpath. |

`requirements.txt` without packages in the zip is refused, and so is `apache-flink`/`pyflink` inside the zip (the
image already provides the matching version). Compiled packages must be built for the Python version of the Flink
image (`flink_python_python_version`); the CI template Streamtime generates for Python projects does this for you
(set `STREAMTIME_WHEEL_PLATFORM=manylinux2014_aarch64` for arm64 clusters).

Operator setup (GlobalConfiguration, seeded with defaults): `flink_python_image` (fully qualified image, build it with
`./scripts/build-and-push-flink-python-image.sh`), `flink_python_python_version` (the Python in that image) and
`flink_python_architectures` (the CPU architectures the image is published for, `x86_64` and/or `aarch64`; compiled
packages built for another architecture are refused at deploy time).
