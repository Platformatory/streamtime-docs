# Nightly publish and OpenAPI SDK regen

## Objective

Every day from `main`: (1) publish every Streamtime container image and
Helm/OCI chart so package rules can select a nightly channel without
`latest` or the unreadable `0.1.{unix}` tags; (2) regenerate the SDK
snapshot and clients from that commit’s OpenAPI (`manage.py spectacular`)
and auto-commit when they drifted.

**Not on `main` today.** `scripts/regen-sdk.sh` exists as a manual
script. No workflow on `main` or this PR runs it or commits its output.
`openapi-diff` on `test-pr` only fails and tells you to regen locally.

## Version

One SemVer prerelease, same string on images and charts:

```
0.0.0-nightly.YYYYMMDD.<github_run_id>
```

UTC date plus the Actions run id. Example: `0.0.0-nightly.20260926.12345678901`.

Also push the floating tag `nightly` (already a reserved package-rule
`default_version` / `version_list` literal). Do **not** move `latest`.

Why this shape:

- Helm requires SemVer; Docker accepts the same tag (`+` build metadata does not).
- `0.0.0-nightly.…` is a prerelease, so `>=1.0.0` and
  `exclude_prerelease` miss it. Dated nightlies are also skipped by rule
  evaluate unless they appear in `version_list`.
- Date identifiers are numeric, so later days sort after earlier days;
  same-day re-runs are unique via `<run_id>` (no overwrite of a prior digest).
- `default_version: nightly` resolves the floating tag after ingest.

Same-day re-runs no longer collide on the dated tag; each gets its own
SemVer. The floating `nightly` tag still moves to the latest successful
publish.

## In scope

- All existing GHCR image publish workflows (backend, frontend, gateway,
  orchestrator, bundled distribution, agent + webhooks, kafka-admin)
- All charts under `charts/` as OCI (existing `build-helm-charts`)
- Kroxylicious proxy-throughput image (existing script)
- Daily schedule plus `workflow_dispatch`
- Regen from **this commit’s** OAS via `manage.py spectacular` (same source
  as `openapi-diff`), then `./regen-sdk.sh` outputs:
  - `streamtime-sdk/streamtime_sdk/_spec_snapshot.json`
  - `streamtime-sdk/streamtime_sdk/` (`api/`, `models/`, `client.py`)
  - `streamtime-sdk/typescript/api-types.d.ts`
- Auto-commit those files to `main` when the spec drifted; no-op when
  snapshot already matches spectacular

## Out of scope

- Retagging `latest`
- Changing the local `0.1.{timestamp}` default in `build-and-push-*.sh`
- Signing / provenance beyond what the called workflows already do
- Auto-commit on PRs (the PR gate stays red until `main` has the snapshot,
  or the author regs locally)
- Fetching OAS from a live gateway (`api.streamtime.local`) — CI must use
  spectacular from the checkout, not whatever is running on the runner
- Regenerating on every PR (would dirty source branches)

## Approach

1. `publish-nightly.yaml` on `main` (04:30 IST, after `test-nightly`).
2. Derive the version once; call each existing `build-*.yaml` with
   `tag_latest=false` and `extra_tags=nightly`.
3. Reuse `build-helm-charts` with `chart_version` set to the same string.
4. **SDK job on `main` only** (same nightly or a sibling workflow after
   `test-nightly` has a backend image): run spectacular in that image,
   feed `regen-sdk.sh` (or the same openapi-python-client +
   openapi-typescript steps) so the snapshot is the latest schema on
   `main`. If `git diff` is empty, exit 0. If not, commit as
   `github-actions[bot]` with a conventional message
   (`chore(api): regen SDK snapshot from spectacular`) and push to
   `main`. `contents: write`. Default `GITHUB_TOKEN` does not retrigger
   workflows — that is intended (no loop). The next `test-pr` / PR
   `openapi-diff` vs `origin/main` sees the new snapshot.
5. First run after 1327 merges should clear the current 24-op stale
   snapshot so `main` is not permanently red on `openapi-diff`.

## Deviations

- **2026-09-23 — publish tranche only.** `test-nightly` already runs on `main` (landed with the self-hosted PR CI change). This change adds image and chart publish. Regenerating the SDK snapshot from spectacular and auto-committing it is still not in `publish-nightly.yaml`.
- **2026-09-23 — SDK regen is a PR gate.** The package lives at repo-root `streamtime-sdk` (Python `streamtime_sdk`, types in `streamtime-sdk/typescript/`). When `manage.py spectacular` differs from the committed snapshot, `openapi-diff` regenerates that tree in the job workspace and fails until the author commits it. It does not push to the PR branch or to `main`.
- **2026-09-23 — publish the committed SDK, do not regen on main.** Nightly uploads that tree to PyPI and npm. It does not run `regen-sdk.sh` and does not commit to `main`. PyPI version is `0.0.0.devYYYYMMDD` because the image tag is not valid on PyPI. No registry token is stored.
- **2026-09-25 — trusted publishers must be per-workflow; optional token fallback.** A PyPI/npm trusted publisher registered only for `release.yaml` does not cover `publish-nightly.yaml` (`invalid-publisher`). Register a second publisher with workflow `publish-nightly.yaml` and environment `pypi` / `npm`, or set `PYPI_API_TOKEN` / `NPM_TOKEN` on those GitHub Environments as a temporary fallback. SDK Docker builds now `chown` `dist/` so later jobs do not hit EACCES on checkout.
- **2026-09-25 — nightly skips PyPI/npm for now.** `publish-nightly.yaml` publishes GHCR images (and Helm/OCI charts) only. SDK registry uploads stay on `release.yaml` until npm/PyPI trusted publishers are configured.
- **2026-09-23 — human release is a separate workflow.** `release.yaml` (`workflow_dispatch` on `main`) bumps the latest stable tag (patch, minor, or major) unless the release manager types a version. It calls the image and chart workflows with that version, publishes the SDK, then pushes the git tag. Image and chart workflows no longer run on a tag push, so the tag does not publish a second copy. A prerelease does not move `latest`. Kroxylicious is included on a stable release only, because its build script always pushes `latest`. Catalog Package rows still come from registry sync, not from this job. PyPI and npm are not Package rows. Nightly stays `0.0.0-nightly.YYYYMMDD` and still does not move `latest`.
- **2026-09-25 — release is tag-then-GHCR; SDK out of path.** GitHub cannot pre-fill `workflow_dispatch` with a computed SemVer. `validate` lists stable tags and writes the resolved next version to the job summary; `confirm` uses environment `release` (add required reviewers so a human sees that version before proceeding); then `tag` pushes the annotated git tag; then all GHCR image/chart jobs publish with that same tag. PyPI/npm are skipped until trusted publishers exist.
- **2026-09-26 — unique nightly SemVer per run.** Version is
  `0.0.0-nightly.YYYYMMDD.<GITHUB_RUN_ID>` so same-day re-publishes do not
  overwrite a prior digest. Floating `nightly` still moves. `streamtime-kafka-admin`
  build now sets package visibility to public after push (it was private /
  anonymous 404 while siblings were public).
- **2026-10-07 — nightly publish repaired; rules can select nightlies.** Every
  nightly since the repository moved to `streamtime-ai` failed:
  - **Image path.** backend, frontend, gateway and orchestrator passed
    `streamtime-ai/<name>` to mr-smithers, which also prefixes `githubOrg`
    (`ghcr.io/streamtime-ai/streamtime-ai/<name>`). They now pass the bare
    name with `githubOrg` set.
  - **No sudo on the runner.** Chart publish reads the chart name with
    `helm show chart`, not an apt-installed `yq`. Kroxylicious gets JDK 21
    (`setup-java`) and Maven in user space, with `SKIP_JAVA_AUTOINSTALL`.
  - **kafka-admin non-root check.** It inspects the pulled image instead of
    running `crane` with an empty entrypoint.
  - **Chart publish checks out `inputs.sha`.**

  On the fleet-manager side, versions were parsed as PEP 440, which rejects
  `0.0.0-nightly.…`. Backend `core/services/versions.py` (copy:
  orchestrator `shared/versions.py`) parses SemVer 2.0 and orders nightlies by
  date, then run id. A rule selects nightlies with a version list entry, or with
  a constraint naming a prerelease of the same release: `>=0.0.0-nightly.0`
  (npm semantics). `>=1.0.0` and criteria-less rules still skip them. Charts
  have no floating `nightly` tag (Helm needs SemVer), so a chart rule uses the
  constraint, and the newest nightly wins when the rule has no default version.
- **2026-10-08 — chart digest is opt-in; build jobs reset the workspace (#1427).**
  `build-helm-charts.yaml` hard-coded `charts/fleet-manager` in its digest job,
  which `check-chart-discovery.sh` rejects (`test-nightly` helm lint), and the
  job ran on every nightly with no workspace reset, so checkout failed on
  root-owned `test-reports/` left by test jobs (EACCES). The job is now
  `chart-digest` and runs only when the caller passes `digest_chart`; only
  `build-release-artifacts.yaml` does (`charts/fleet-manager`). Nightly and
  release skip it. It and every image build job (backend, frontend, gateway,
  orchestrator, agent, distribution) now reset the workspace before checkout.
  The CI fixes from the 2026-10-07 entry land on `main` in their own PR,
  cherry-picked from #1393.
- **2026-10-08 — kroxylicious builds in Docker; nightly does not move `latest`.**
  Supersedes the 2026-10-07 JDK/Maven setup. The filter jars are built in a
  Maven stage of `docker/kroxylicious-proxy-throughput/Dockerfile`, so the
  script only builds, tags and pushes: no JDK, Maven or package installs on
  the runner or a developer machine, and no `setup-java` in the workflows. The
  script always pushed `:latest`; it now takes `TAG_LATEST` (default `true`),
  and `publish-nightly.yaml` sets it to `false`.
- **2026-10-08 — main pushes do not publish charts.** `build-release-artifacts`
  called `build-helm-charts` with no version, so every chart was packaged as
  version `main` (not SemVer) and failed. It only needs the `fleet-manager`
  digest for the bundle (the render reads the chart from source), so it passes
  `digest_only: true`; charts publish on nightly and release only. Without a
  version the digest package is `0.0.0-g<short sha>`.
- **2026-10-08 — SemVer parsing ships with #1393, not with the CI fix.** The
  #1427 fix (#1432) changes only CI, publishing and reporting. It carries the
  CI part of the 2026-10-07 entry but not the SemVer modules; until #1393 merges,
  nightlies publish to GHCR but package rules cannot select them.
- **2026-10-08 — release can finish a failed publish.** `release.yaml` pushes
  the git tag before publishing, and refused an existing tag, so 1.1.16 (tag
  and images out, no charts or kroxylicious) could not be completed. With
  `republish` and `version` set to the existing tag it builds the tag's commit
  (every build workflow now takes `sha`), publishes only images whose tag is
  missing and charts not yet published (`build-helm-charts` `skip_existing`),
  and never moves `latest`. Publish jobs require `confirm` to have passed, not
  only a skipped tag job. Release candidates publish kroxylicious with
  `TAG_LATEST=false`. Report jobs (release, nightly) reset the workspace.
  `test-temporal-replay` and `fleet-manager-orchestrator/tests/replay/` are
  removed: the workflow failed on every PR (no `streamtime_sdk`), and the
  tests replayed nothing (a stub JSON existence check). The patch-ID rule and
  list live in `deploy/streamti.me/README.md`.
- **2026-10-08 — no GitHub environments.** The org is on GitHub Free and the
  repo is private: environments there cannot require reviewers or restrict
  branches, and none had any. `release`'s `confirm` and the
  `production-secrets` jobs (`build-release-artifacts` `publish-oci`,
  `promote-production`, `sync-production-secrets`) no longer name an
  environment; their secrets and `POSTGRES_HOST` are repository secrets /
  variables. `confirm` records the resolved version but does not gate.
- **2026-10-08 — SDK publish.** `publish-sdk.yaml` (manual; dispatched by
  `release.yaml` after `tag`) publishes the committed `streamtime-sdk/` tree:
  PyPI `streamtime-sdk` by trusted publishing (pending publisher: repo
  `streamtime-ai/fleet-manager`, workflow `publish-sdk.yaml`, any environment)
  and npm `@streamtime.ai/api-types` / `@streamtime.ai/sdk` with the
  `NPM_TOKEN` repository secret. The npm scope is `@streamtime.ai` (the org
  that owns it), not `@streamtime-ai`. Release dispatches instead of calling it
  as a reusable workflow, because PyPI trusts the top-level workflow file.
  Versions already published are skipped. Nightlies are not published to
  PyPI / npm. First npm publish (manual): `0.0.0-preview.20261008`.
- **2026-10-15 — nightly pins the deploy files.** After the API, UI, gateway,
  orchestrator, and Helm chart publishes succeed, `pin-deploy` parses
  `deploy/nightly.streamti.me/values.yaml` and `argocd-app.yaml` with
  ruamel.yaml (installed into a uv virtualenv under `$RUNNER_TEMP`; the
  uv binary comes from the official installer when it is not on `PATH`,
  with no host pip) and sets every `ghcr.io/streamtime-ai/` image tag plus the
  `streamtime-ha` chart `targetRevision` to that run's version. The git
  values ref stays `main`. The job commits both files to `main` as
  `github-actions[bot]` (`chore(deploy): pin nightly to <tag>`). `effectiveSemver`
  and upstream images are left alone. A `GITHUB_TOKEN` push does not start
  another workflow, and those deploy paths are not in this workflow's path
  filters.
