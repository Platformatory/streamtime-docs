---
title: Stream Processing
nav_order: 2
parent: Workloads
permalink: /workloads/stream-processing/
has_toc: false
has_children: true
---

# Stream Processing

Compute that reads from your streaming platforms, transforms the data,
and writes it back — continuously, at the speed the data arrives.

| Platform | Status | In short |
|---|---|---|
| [**Apache Flink**](flink.html) | Supported | Stateful stream processing: projects hold your code, deployments run it against your Kafka clusters |
| **Kafka Streams** | BYO runtime | A Java library, not a Streamtime-managed platform: your applications run it, Streamtime's clusters provide the streams |

## Apache Flink

A Flink deployment runs either one job (application mode) or the jobs you
submit to it (session mode), and runs builds registered to a **Flink
project** by version. See [Apache Flink](flink.html) for every deployment
task: create a deployment, submit and manage jobs, check status, change or
upgrade it, monitor it, and delete it.

### Flink projects

Flink runs through **projects**: a project holds your application code
and builds, and from it you roll out **deployments** that consume and
produce on the Kafka clusters in your organization.

Your builds stay in **your own artifact store**: an OCI registry (GitHub
Packages, GHCR, Docker Hub, Harbor, JFrog's OCI repositories) or a JFrog
Artifactory repository. Streamtime keeps only where each build is and its
sha256 fingerprint. Your Flink clusters pull the build from the store
themselves and refuse to start if it does not match the fingerprint CI
registered. The store needs to keep every build that is still deployed, and
the cluster's nodes need to reach it. Builds uploaded to Streamtime no
longer run on Apache Flink clusters.

{% capture ui %}
1. In the sidebar, go to **Flink projects** and select **Create
   project**.
2. On the project page, under **Artifact store**, choose the store type,
   enter its https address and the sign-in clusters use to read builds
   (read access is enough), then select **Connect store**.
3. To try your job on your own machine first, open the **CI/CD** tab and
   under **Local development** select **Show local environment files**. They
   run the same version of Flink as your clusters and never contain the CI
   Key (add it to your own `.env`).
4. On the **CI/CD** tab, pick your CI system and copy the pipeline into
   your repository. Add the project's CI Key and the store credential as CI
   secrets as the steps say. Each push builds, pushes to your store and
   registers a version.
5. Select **Deploy a version** on a registered version. This moves the
   project's one deployment (its **HEAD**) to that version, forward or back;
   choosing an older version is a rollback. The deployment consumes and
   produces on your Kafka clusters; its status appears in the project view.
6. Open the job to see which step its deployment is on (the cluster is ready,
   the release is fetched and verified, the job is running). If it failed,
   the reason is shown at the top with what to do next. Open **Logs** and
   choose **Release** to read the fetch and verify step. Operators also see
   the JobManager and TaskManager logs of the shared cluster.
{% endcapture %}

{% capture api %}
```bash
# Where is a deployment, and why did the last one fail?
curl "$STREAMTIME_URL/organizations/$ORG/flink/nightly-rollup/jobs/orders-enrich/readiness/" \
  -H "Authorization: Bearer $TOKEN"
# The newest lines of the release's fetch and verify step (at most 500)
curl "$STREAMTIME_URL/organizations/$ORG/flink/nightly-rollup/jobs/orders-enrich/logs/?component=release&lines=200" \
  -H "Authorization: Bearer $TOKEN"

# The files of the local development environment (the CI Key is never in them)
curl "$STREAMTIME_URL/organizations/$ORG/flink-projects/orders-enrich/dev-env/" \
  -H "Authorization: Bearer $TOKEN"

# Connect the store (the credential is stored securely and never returned)
curl -X PUT "$STREAMTIME_URL/organizations/$ORG/flink-projects/orders-enrich/store/" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"store_type": "oras", "url": "https://ghcr.io", "authentication": "token", "token": "'"$STORE_TOKEN"'"}'

# Register a build CI pushed (digest is the sha256 of the artifact file)
curl -X POST "$STREAMTIME_URL/organizations/$ORG/flink-projects/orders-enrich/releases/" \
  -H "X-Streamtime-Key: $CI_KEY" -H "Content-Type: application/json" \
  -d '{"version": "1.4.0", "store_type": "oras", "location": "ghcr.io/acme/orders-enrich:1.4.0", "digest": "sha256:<64 hex characters>"}'
```
For a Python project, add `"declared": {"layout": "wheelhouse", "entry_file": "main.py"}` to the release.
{% endcapture %}

{% capture cli %}
```bash
streamtime flink-project create --identifier orders-enrich --name "Orders enrichment"
streamtime flink-project init orders-enrich   # docker-compose, .env.example and a starter job in this directory
export STREAMTIME_STORE_TOKEN=...   # read from the environment, never printed
streamtime flink-project store set orders-enrich --store oras --url https://ghcr.io
streamtime flink-project release register orders-enrich --version 1.4.0 \
  --store oras --location ghcr.io/acme/orders-enrich:1.4.0 --digest sha256:<64 hex characters>
streamtime flink-project head set orders-enrich --version 1.4.0 --cluster nightly-rollup --wait
streamtime flink-project head show orders-enrich
streamtime flink list
streamtime flink job status nightly-rollup orders-enrich   # which step it is on, and why the last one failed
streamtime flink job logs nightly-rollup orders-enrich     # the fetch and verify step of the release
```
{% endcapture %}

{% capture mcp %}
MCP reads deployment and cluster state; it does not create or start
Flink deployments.
{% endcapture %}

{% include tabs.html id="flink-project" ui=ui api=api cli=cli mcp=mcp %}

## Kafka Streams

Kafka Streams is a client library inside your own Java applications —
Streamtime does not deploy it. What Streamtime provides is the
platform it runs against: the Kafka clusters, their authentication,
and the monitoring of the topics Streams applications read and write.
