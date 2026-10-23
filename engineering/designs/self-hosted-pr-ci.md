# Self-hosted PR CI

## Objective

One self-hosted runner (`github-runner-01`, label `large`). `test-pr` is the
only every-PR unit workflow. Reports are one comment per commit (a later push
posts a new comment; partial updates in the same run edit that commit's
comment). Auth is not fuzzed here — Kong owns that.

## In scope

- Path-filtered unit suites on PRs (postgres backend, no sqlite, no HTTP fuzz)
- Nightly on main: SQLite single-node, hermetic HTTP OpenAPI fuzz (`plans/nightly-main.md`)
- Decodeable fake JWT on fuzz requests so audit-log actors can be attributed
- One comment per commit for the test report, OpenAPI diff, and AI review. A new push posts a new comment. Partial suite updates in the same run edit that commit's comment.
- Advisory local-model AI review (prefer Qwen3.8-27B-FP8 on dgx1 then dgx2; `DeepSeek-v4.1-Flash-EXL3` is also acceptable; thinking off). After the review comment, reply once to unanswered human questions and concerns (in-thread for line comments, a new comment for conversation comments).
- Reviewer may use read-only tools (`gh` PR+comments, `plans/`, file/grep/diff)
- Hang-safety (pytest-timeout, MagicMock guard, job timeouts)

## Out of scope

- GitHub Free private branch-protection required checks (403)
- Product Streamtime MCP as the reviewer runtime
- Fuzzing Kong authn/authz (covered by gateway Pongo tests)

## Approach

1. Delete leftover per-suite `pull_request` workflows on this branch so `test-pr` is the only PR unit entry.
2. HTTP OpenAPI fuzz is nightly-only (`test-nightly`); it fails the job on 5xx; undocumented 4xx stay in JUnit.
3. If the review model is not served, skip **all** AI-review output (no comment, no skip placeholder, no replies).
4. Disable legacy `test-backend` / `test-frontend` / `test-orchestrator` / `test-gateway` / `test-streamtime-agent` workflows in GitHub until this PR reaches `main`.
5. OpenAPI HTTP fuzz is nightly-only (`test-nightly`). PR pytest is the unit suite only.
6. Backend and orchestrator images use a persistent BuildKit builder (`st-ci`) and a local layer cache on the runner (`/opt/actions-runner/cache/buildkit`). Do not use `type=gha`.
7. All jobs use `runs-on: [self-hosted, large]` so they stay on `github-runner-01` (local Docker images / BuildKit cache). Do not schedule on other `self-hosted` machines.

## Deviations

- **2026-09-22 — fake JWT.** Original fuzz note was “no JWT”. Writes still `jwt.decode(verify_signature=False)` for audit-log actor; seed a matching org member.
- **2026-09-22 — comment split.** One report comment overflowed GitHub’s 64 KiB cap. Test / OpenAPI / fuzz / AI reviews each have their own sticky comment. Comments list failures only.
- **2026-09-22 — AI review tools.** Packed-only prompt could not see a 50k-truncated diff. Bounded tool loop plus packed fallback if the host rejects `tools`. Fallback includes bounded diffs and source; if those are unavailable the job skips (no comment). Silent skip when the model is down.
- **2026-09-22 — OpenAPI snapshot stale.** `openapi-diff` failing because spectacular has 24 operations not in `_spec_snapshot.json` is the intended gate (`./regen-sdk.sh`), not a runner bug.
- **2026-09-22 — OpenAPI schema compare.** Snapshot/main diffs resolve local `$ref`s and compare `components` (schemas, parameters, requestBodies, responses). Serializer field type/required/enum edits fail the gate even when operation objects still point at the same schema name.
- **2026-09-22 — DeepSeek fallback.** dgx1 currently serves `DeepSeek-v4.1-Flash-EXL3` at `http://10.10.40.11:8000`. That id is an accepted fallback when Qwen is not on `/v1/models`.
- **2026-09-22 — PR vs nightly.** Sqlite, HTTP OpenAPI fuzz, and agent `-race` moved to `test-nightly` on `main` so the one runner is not occupied for ~50 extra minutes on every PR. (In-process Hypothesis was later dropped — see `plans/nightly-main.md`.)
- **2026-09-23 — per-suite coverage in the README.** `coverage-main.yaml` runs after `test-nightly` completes on `main`. It reads that run's artifacts, writes one SVG per suite, and pushes with `SDK_REGEN_TOKEN`. Suites that run did not measure stay as they were. Helm stays per chart in the job log. No single repository percentage.
- **2026-09-26 — README status + version badges.** Dropped the meaningless `test-pr` badge. README shows nightly workflow status, stable semver (`1.x.y` from git tags), nightly version (`0.0.0-nightly.YYYYMMDD.<run_id>` from last successful `publish-nightly`), and a per-suite table of `failed/total` (postgres vs sqlite separate) plus coverage. Status badges link to the triggering nightly run URL; `coverage-main` listens only to `test-nightly`.
- **2026-09-26 — serial pytest; frontend 45m.** CI no longer uses pytest-xdist (isolation still red). Frontend timeout raised to 45m; Vitest `isolate: false`.
- **2026-09-23 — prune keeps other active runs.** `prune-runner-disk.sh` no longer removes every `backend-test`/`orchestrator-test` tag except the current run. It keeps tags for unfinished workflow runs (GitHub API) and images still attached to a container, and fails closed if that list is unavailable. It no longer force-removes arbitrary `node:22` containers; only `fleet-manager.ci=1`, `fuzz-`/`frontend-`/`pg-` names, or test images.
- **2026-09-22 — Local image cache.** `type=gha` marked layers CACHED then re-downloaded ~173 MB into a throwaway BuildKit container (~5–15 min). Orchestrator hit the 15-minute job cap during that download. Cache now lives on the runner; orchestrator timeout is 25 minutes as a cushion.
- **2026-09-22 — Go compile cache.** Agent and kafka-admin were remounting `GOCACHE` on `/tmp` inside `--rm` containers, so every PR recompiled. Cache now lives under `/opt/actions-runner/cache/go` (or `~/.cache/streamtime-go` locally). kafka-admin `-race` moved to nightly with the agent.
- **2026-09-22 — AI review compose timeout.** Tool rounds stay at 60s. The final write (and packed fallback) is sized for a full `max_tokens` completion at ~30 tok/s plus 90s prefill (~227s for 4096 tokens). The previous 60s compose timeout skipped the sticky comment after eight tool rounds. Job cap is 18 minutes.
- **2026-09-22 — AI review without `gh`.** Self-hosted runner has no GitHub CLI. `gh_pr_view` / `gh_pr_comments` now use the GitHub REST API with `GITHUB_TOKEN`, then `github.event.pull_request` from `GITHUB_EVENT_PATH`, then `gh` if present. Approach step 4 (disable leftover Actions workflows in the GitHub UI) stays an operator step and is not verifiable from the diff.
- **2026-09-23 — comments follow the commit.** Test, OpenAPI, and AI review comments are stamped with `GITHUB_SHA`. The same run may edit that comment (partial reports). The next push posts a new one. The AI review also replies once to unanswered human questions and concerns; line comments get an in-thread reply, conversation comments get a new comment. A later push does not answer the same comment again.
- **2026-09-26 — xdist; PR skips coverage.** Backend postgres/sqlite and orchestrator CI use `pytest -n auto --dist loadfile --max-worker-restart=0`. `test-pr` uses `--no-cov`; nightly `test-units` keeps `--cov=.` for badges. Nightly sqlite is `--no-cov` too (badges from postgres). `core.apps.ready` skips Temporal bootstrap under xdist workers (`PYTEST_XDIST_WORKER`).
- **2026-09-26 — pin all jobs to `large`.** `runs-on: [self-hosted, large]` so every job lands on `github-runner-01`. Prevents cross-runner Docker image misses (nightly #14 sqlite).
- **2026-09-26 — persistent uv + npm caches.** CI mounts `/opt/actions-runner/cache/uv` into test containers (`UV_CACHE_DIR`). Backend/orch Dockerfiles use BuildKit `--mount=type=cache` for `uv pip`. Frontend named volumes are labeled and daily prune no longer runs `docker volume prune` (only dangling anonymous volumes).
- **2026-09-26 — test-pr is PR-only.** Removed `push: branches: [main]`. Main-branch units/coverage are `test-nightly` only, so CI hotfixes to main no longer start a competing `test-pr`.
- **2026-09-26 — drop Go `-race` from nightly.** Agent/kafka-admin race detector passes removed; ordinary unit runs in `test-units` remain.
