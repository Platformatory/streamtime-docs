# Streamtime SDK

## Objective

One generated client at the repo root, kept in lockstep with the OpenAPI
document on every pull request, and exercised against a real environment by
a script that calls the Python client directly.

## In scope

- Package location: `streamtime-sdk/` (`streamtime_sdk` import, distribution
  name `streamtime-sdk`). TypeScript types at
  `streamtime-sdk/typescript/api-types.d.ts`. The Fetch runtime SDK is
  `streamtime-sdk/typescript/client/`.
- Orchestrator and test-harness imports use `streamtime_sdk`. Frontend JSDoc
  uses `@streamtime-sdk/api-types` (Vite alias and `jsconfig` paths). The
  React app keeps calling `apiService`.
- Images and Compose install the package from `/streamtime-sdk`. The
  orchestrator image build context is the repo root.
- On `test-pr`, when `manage.py spectacular` differs from
  `streamtime-sdk/streamtime_sdk/_spec_snapshot.json`, the job runs
  `scripts/regen-sdk.sh --spec` and pushes the regenerated tree with
  `SDK_REGEN_TOKEN`. People do not run regen and commit it.
- A repo hook (`.githooks/pre-commit`, enabled with `scripts/install-git-hooks.sh`)
  rejects a commit that stages the generated client, snapshot, or TypeScript types.
  `service_client.py`, `GAPS.md`, and tests stay hand-written and commitable.
- `streamtime-sdk/check_callers.py` imports every `streamtime_sdk` name
  referenced by the orchestrator, the test harness, and `service_client.py`.
  It runs on the same OpenAPI job. Public imports are `streamtime_sdk.api`,
  `streamtime_sdk.models`, and `streamtime_sdk.client`.
- This document: the live exercise script below.
- Registry publish of the committed tree: PyPI `streamtime-sdk` and npm
  `@streamtime.ai/api-types` plus `@streamtime.ai/sdk`, by `publish-sdk.yaml`
  (manual, and dispatched by each release). The publish job does not
  regenerate. Images keep installing the git tree.

## Out of scope

- Implementing or scheduling the live exercise script.
- Auto-committing a regen to `main` outside a pull request.
- Typechecking frontend JSDoc.
- Replacing the hand-written CLI HTTP client or the in-process MCP tools
  with the generated client.
- Cloud-provider fleet scenarios (AWS, OCI, GCP). Those stay env-gated in
  the existing harness.

## Approach

1. `streamtime-sdk` is the only generated tree. `regen-sdk.sh` writes the
   Python client, `typescript/api-types.d.ts`, and the Fetch runtime SDK in
   `typescript/client/`. `--spec FILE` skips the live-gateway fetch. The
   runtime SDK does not replace `api-types.d.ts`.
2. `openapi-diff` still comments before any regen, so the comment describes
   the committed snapshot. Regen follows only when the parsed spec differs
   from the snapshot. The regenerated tree is pushed to the pull request
   branch, never to the default branch.
3. Orchestrator path filters include `streamtime-sdk/**`, so a client-only
   change still runs orchestrator tests.
4. Live exercise (not built in this change). A new script, invokable locally
   and later on a schedule against a real stack. It imports `streamtime_sdk`
   and calls generated operations. It does not go through `HarnessClient`.

   The existing `test-harness` (`./run-tests.sh -m live`) stays the HTTP
   suite. This script is the generated-client suite.

   Local invoke shape:

   ```bash
   cd streamtime-sdk
   ./exercise.sh
   ```

   Required environment: gateway base URL, a bearer token for an org that
   can create fleets, and a kubeconfig for a reachable cluster (kind or a
   real fleet). Cloud credentials are not required for the default path.

   Sequence, matching the current BYOK and Strimzi happy paths:

   1. Seed: organization (when the token's org is not enough), base domain,
      and the kubeconfig secret the BYOK fleet reads.
   2. Create a BYOK fleet (`identifier`, `provider=byok`,
      `tenancy_mode=Shared`, `domain`).
   3. Install the agent (`mode=fleet_bootstrap`) and poll the agent
      connection until `bootstrap_complete` (failure statuses
      `agent_install_failed` and `bootstrap_failed`). Fleet status stays
      pending on that path, so the script must not wait on fleet status.
      Budget the same 2100s bootstrap ceiling the harness uses until a real
      run measures a tighter one.
   4. Create a Strimzi workload on that fleet (`identifier`, `workload=strimzi`,
      `tenancy_mode=Shared`, `kafka_units=1`, `fleet`) and poll until Healthy.
   5. Delete the workload, then the fleet, and poll until Deleted. Delete
      must succeed if the resource is already gone.

   Each step prints the operation id and the resource identifier. A non-zero
   exit leaves the identifiers in the log so a person can delete them. The
   scheduled run uses a dedicated org and the same cleanup.

## Deviations

- **2026-09-23 — agent command model name.** `update_agent_command` imported `PatchedAgentCommand`. The generator now emits `PatchedAgentCommandPatchRequest`. The caller uses that class.
- **2026-09-23 — no `generated` in the import path.** Codegen still writes `api/`, `models/`, and `client.py`, and regen replaces only those files. Callers import `streamtime_sdk.api`, `streamtime_sdk.models`, and `streamtime_sdk.client`.
- **2026-09-23 — CI commits the client.** People do not run `regen-sdk.sh` and commit. When the snapshot is stale, `test-pr` regenerates and pushes with `SDK_REGEN_TOKEN`. The generated paths are not gitignored, because the orchestrator installs that tree. `.githooks/pre-commit` rejects a local commit of them.
- **2026-09-23 — regen on main does not write the branch.** The commit step runs on `pull_request` only and refuses the default branch and fork heads. A spec that parses equal to the snapshot, including whitespace and key order, does not regenerate. Generators are pinned (`openapi-python-client==0.29.1`, `openapi-typescript@7.13.0`, `@hey-api/openapi-ts@0.99.0`).
- **2026-09-23 — JavaScript runtime SDK.** `regen-sdk.sh` also writes `streamtime-sdk/typescript/client/` with `@hey-api/openapi-ts`. `api-types.d.ts` stays the JSDoc source. The React app keeps calling `apiService`.
- **2026-09-23 — registry publish uses the committed tree.** `publish-nightly.yaml` used to upload PyPI `0.0.0.devYYYYMMDD` and npm `0.0.0-nightly.YYYYMMDD` (dist-tag `nightly`) from `main`. As of 2026-09-25 nightlies skip PyPI/npm until trusted publishers are wired; GHCR images (and charts) still publish. Human `release.yaml` still uploads the SDK via OIDC (or optional `PYPI_API_TOKEN` / `NPM_TOKEN`). npm package metadata lives in `streamtime-sdk/npm/` because regen deletes `typescript/client/`.
- **2026-09-23 — temporary token probe removed.** The branch-only `sdk-token-check` job that created and deleted `refs/sdk-token-check` is gone. Regen and release still use `SDK_REGEN_TOKEN` only for the real push.
- **2026-09-24 — regen lives under `scripts/`.** Generator is `scripts/regen-sdk.sh` (CI calls that path). `test-harness/regen-sdk.sh` is a shim. The script installs Astral `uv` when `uvx` is missing so self-hosted runners do not need a preinstalled toolchain.
- **2026-09-24 — PAT push vs checkout extraheader.** `actions/checkout` sets `http.https://github.com/.extraheader` to `GITHUB_TOKEN`, which overrides a PAT in the remote URL and returns 403 on `git push` even when the PAT has `permissions.push`. SDK regen (and coverage/release tag pushes) unset that header before pushing with `SDK_REGEN_TOKEN`.
