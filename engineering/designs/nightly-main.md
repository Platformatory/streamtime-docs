# Nightly on main

## Objective

Run the full unit matrix on `main` overnight, then the slow extras
(SQLite single-node, hermetic OpenAPI fuzz), so every-PR
`test-pr` can stay path-filtered and short. This is not a git branch.

## In scope

- Schedule on `main` (02:00 IST) plus `workflow_dispatch`
- **Units first** — `test-units.yaml` (all suites, postgres,
  agent/kafka-admin without `-race`; **no** OpenAPI)
- Backend SQLite (bundled / `DATABASE=embedded`)
- Hermetic backend OpenAPI fuzz (reuse the SQLite job’s backend image)
- One backend image build shared by sqlite + fuzz

## Out of scope

- Kong / live stack (`test-integration`) — **suspended** (legacy compose
  smoke). `test-harness` live is also not wired into Actions.
- Artifact publish (images + Helm/OCI) — `publish-nightly.yaml`
- AI review (PR-only)
- OpenAPI snapshot / SDK regen (PR `test-pr` only)
- Go `test -race` (dropped from nightly for wall-clock; PR units cover
  agent/kafka-admin without the race detector)
- In-process Hypothesis property tests (dropped; weak ROI vs wall-clock)

## Approach

1. `test-pr` runs on `pull_request` only (path-filtered). Main-branch units
   and coverage come from `test-nightly` → `test-units`, not from a
   push-to-main `test-pr`.
2. `test-nightly` calls `test-units.yaml` for a full unit pass (no path
   filter, no OpenAPI), then owns sqlite (xdist, no cov) and HTTP fuzz.
   Same self-hosted runner; concurrency group `nightly-main` so it does
   not cancel a PR `test-pr`.
3. OpenAPI fuzz uses `HYPOTHESIS_MAX_EXAMPLES=3` and a 40-minute job cap
   so it can finish.
4. Image builds use the same persistent BuildKit cache as `test-pr`
   (`plans/self-hosted-pr-ci.md`).
5. Unit failure does not skip the fuzz phase (`if: always()` after units)
   so both lanes still report.

## Deviations

- **2026-09-25 — units are in nightly.** Spec originally left PR units out of
  nightly. Nightly runs a full unit matrix via dedicated `test-units.yaml`,
  then sqlite/fuzz as a second phase.
- **2026-09-25 — do not nest `test-pr` in nightly.** Calling `test-pr` via
  `workflow_call` pulled in openapi-diff (stale snapshot fails; regen is
  PR-only). Nightly units live in `test-units.yaml` with no OpenAPI job.
  Nested helm/kafka-admin need `pull-requests: write` on the `units` caller
  job or the run exits `startup_failure` with zero jobs.
- **2026-09-25 — suspend live-stack CI.** `test-integration` (compose smoke)
  no longer runs on push to main (`if: false` + workflow_dispatch only).
  `test-harness` live was never an Actions workflow; keep it that way so it
  does not compete for the single self-hosted runner.
- **2026-09-26 — xdist + PR coverage drop.** Backend/orch CI uses
  `pytest -n auto --dist loadfile`. PR/`test-pr` passes `--no-cov`; nightly
  `test-units` keeps `--cov=.`.
- **2026-09-26 — uv/npm package caches on the runner.** Runtime `uv pip`
  uses `/opt/actions-runner/cache/uv`; image builds use BuildKit uv cache
  mounts. Frontend `st-frontend-*` volumes are kept across daily prune.
- **2026-09-26 — test-pr is PR-only.** No `push` to `main`; main units and
  coverage badges come from `test-nightly`.
- **2026-09-26 — README badges from nightly.** `failed/total` per suite
  (postgres + sqlite), coverage, stable + nightly semver; no `test-pr`
  badge. `coverage-main` updates the README marker block with the run URL.
- **2026-09-26 — serial pytest again.** Dropped CI `-n auto` for backend/
  orch/sqlite — xdist isolation still roughly doubles product failures.
  Frontend job cap is 45m; nightly units enable Vitest coverage; Vitest
  `isolate: false` + existing CI hang excludes.
- **2026-09-26 — drop Go `-race` from nightly.** Not worth the wall-clock
  right now; agent/kafka-admin still run without `-race` in `test-units`.
- **2026-09-26 — sqlite xdist, no cov.** Nightly/dispatch sqlite uses
  `-n auto --dist loadfile` (pytest-django per-worker DB files) and
  `--no-cov`; coverage badges stay on postgres `test-units`.
- **2026-09-26 — sqlite + fuzz + kafka-admin on README.** Sqlite nightly
  keeps serial pytest but enables `--cov` for a `backend-sqlite` coverage
  badge. Fuzz and kafka-admin emit `summary.json` and get Status cells;
  orchestrator job timeout raised to 60m so junit.xml is not lost mid-run.
- **2026-09-26 — xdist worker crash hang.** Detect pytest via
  `PYTEST_XDIST_WORKER` in `core.apps.ready` so bootstrap does not
  `asyncio.run` on remotes. CI uses `--max-worker-restart=0` so a dead
  worker fails the job instead of hanging until Actions cancels.
- **2026-09-26 — drop in-process Hypothesis.** Removed `core/tests/fuzz/`
  property tests and the `hypothesis` dependency. Nightly keeps hermetic
  OpenAPI HTTP fuzz only; JWT/sink helper unit checks live in
  `tests/test_fuzz_helpers.py`.
- **2026-09-26 — pin CI to `large`.** All workflows use
  `runs-on: [self-hosted, large]` (`github-runner-01`). A second
  `self-hosted` machine (`gitlab-runner-gh`) was stealing jobs and broke
  nightly sqlite (image built on one host, tests on the other).
- **2026-10-08 — suites ran but tested nothing (#1427).** CI-only fixes; the
  test failures they uncover are tracked separately.
  - Backend jobs source `backend.env.sh` (`FLEET_MANAGER_ENV=production`), which
    now requires `DJANGO_SECRET_KEY`; `test-pr`, `test-nightly` and `test-units`
    set a test-only key. Fuzz forces `FLEET_MANAGER_ENV=development`; its
    `:-development` default never applied after sourcing that file.
  - `openapi-diff` runs spectacular with `--no-deps`, so it blanks `REDIS_URL`
    (LocMem) instead of failing on an unreachable Redis.
  - Vitest `isolate: true`. `isolate: false` leaked mocks and module state
    between files on a worker (103 of 331 files failed together, passed
    alone). The frontend job takes roughly 2-3x longer.
  - Helm lint/unittest checks every chart before failing, and runs on every PR.
    The coverage step's `if:` used a nested `${{ }}` and was always true.
  - `test-pr` passes `github.head_ref` through `env`, not inline in the script.
  - Backend and orchestrator `pytest.ini` add `--continue-on-collection-errors`:
    a file that fails to import is one error, not an empty run (a stale import
    in `test_cpansible.py` had hidden every backend test; restore: #1434).
  - Job limits: backend-fuzz 40 to 60 min (runs took 34-35 min), frontend 45
    to 60 min, so a slow run fails on its results instead of being cancelled.
  - Frontend unit tests are off in `test-pr` and `test-units` until the suite
    is fast with `isolate: true` (2,008s locally vs 615s with `isolate: false`):
    #1435. The jobs run when the repo variable `ST_RUN_FRONTEND_TESTS` is `true`.
    Image builds never depended on them.
  - Helm charts are a reported suite (`helm`): `helm unittest` writes JUnit per
    chart, `summarize-test-reports.py` merges them (repeatable `--junit` /
    `--coverage-xml`, coverage weighted by lines) into `reports-helm`, so Helm
    shows in the PR test report and gets README status + coverage badges.
    Checks and template coverage after the lint/unit step run on `always()`
    (a failing chart had skipped coverage, discovery and CRD drift since at
    least 2026-09-25). Coverage no longer needs `bc` (`sudo apt-get`).
  - `.github/scripts/test_*.py` run in `test-pr` setup on every PR; two had run
    only inside AI review, which skips when no model is served.
  - Fuzz: `HYPOTHESIS_MAX_EXAMPLES` was never read (neither Hypothesis nor
    Schemathesis reads it), so every operation ran the default 100 examples.
    `fuzz/config.py` passes it to Schemathesis; default 10.
- **2026-10-08 — follow-ups from the first green publish (#1427).**
  - `build-release-artifacts` ignores pushes that touch only `README.md` and
    `.github/badges/**`: each nightly badge commit rebuilt and pushed four
    images and attempted a production publish.
  - GHCR visibility cannot be set through the REST API (the kafka-admin step got
    404 and only warned). kafka-admin and kroxylicious now assert the package is
    anonymously pullable (`.github/scripts/assert-ghcr-public.sh`); an org admin
    makes it public once in the package settings.
  - Chart tests use Helm v3.14.4 like chart publish and the GitOps render, with
    `helm-unittest` pinned to 1.0.3 (1.1+ does not load on Helm 3.14). Same
    results as Helm 4.3: 918 passed, 5 failed.
  - Chart publish retries `helm dependency update` (an upstream repo timed out).
  - With every check on `always()`, the CRD drift check ran for the first time
    on this runner and failed: `yq` is not installed. `test-helm-charts` now
    installs a pinned mikefarah `yq` v4 in user space; the CRDs are in sync.
  - Release's GHCR check logs in with a throwaway `DOCKER_CONFIG`, so the token
    does not stay on the shared runner. `build-streamtime-agent` and
    `build-distribution` pin `actions/checkout@v4` instead of `@master`.
- **2026-10-08 — failing nightly tests become issues.** The last job of
  `test-nightly` (`triage`, `main` only) runs `triage-nightly-failures.py` on
  the run's `reports-*`. It is `continue-on-error` and a script failure is only
  a warning, so it can never fail the nightly. `triage-nightly` is a manual
  re-run / dry-run of the same step for any past run. One issue per failing test file (pytest module, Go
  package, Helm test file, Vitest file; postgres + sqlite share one; fuzz is
  one file), labelled `ci-failure`, deduplicated by a fingerprint marker
  (`sha256(family|file)[:16]`) in the body. Each issue has a code-written
  summary, a table of failing tests, and every test's full failure output
  (JUnit / go test JSON), capped to GitHub's size limit. Lifecycle: comment on
  each nightly where it still fails, close when every test passes and every
  suite of its family ran, reopen on regression; never reopen issues closed as
  not planned. The AI review model, when served, investigates new and
  regressed files (read-only tools) and files them through
  `file_failure_issue` with a likely cause; the tool only accepts tonight's
  fingerprints and returns the existing issue instead of a duplicate. Uses the
  workflow `GITHUB_TOKEN` (`issues: write`); refuses to create more than 80
  issues in one run.
