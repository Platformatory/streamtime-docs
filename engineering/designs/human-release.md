# Human release

## Objective

Let a release manager cut a SemVer release from `main` in Actions:
resolve the next tag from existing git tags, confirm it, create the
git tag, then publish every GHCR image and Helm chart with that same
tag.

## In scope

- `workflow_dispatch` on `main` only (`release.yaml`)
- Walk stable `X.Y.Z` tags (ignore nightlies / dev); bump patch/minor/major
  or accept an exact override (`X.Y.Z` / `X.Y.Z-rc.N`)
- Confirm job records the resolved version (no environment gate on the Free plan; see Deviations in nightly-publish.md)
- Annotated git tag on the dispatch SHA, then GHCR publish
- Step summary listing every image and chart

## Out of scope

- Dynamic pre-fill of the Run workflow form (GitHub cannot compute defaults
  from the repo at form-render time — empty **version** + **bump** is the
  “next tag” path; the resolved value appears in validate/confirm summaries)
- PyPI / npm until trusted publishers exist
- Publishing from a raw `git tag` push
- Catalog Package row inserts (registry sync)

## Approach

1. `validate` — `check-release-version.py` lists tags, resolves version,
   writes summary (recent tags + next patch/minor/major table).
2. `confirm` — `environment: release`; shows resolved version; waits for
   approval when the environment has required reviewers.
3. `tag` — push annotated tag with `SDK_REGEN_TOKEN`.
4. Image/chart reusable workflows — same `image_tag` / `chart_version`.
5. `report` — artefact table; fail if tag or any required publish failed.

## Deviations

- **2026-09-25 — tag before publish.** Spec originally published then tagged.
  Order is now confirm → git tag → GHCR so the tag exists first and all
  artefacts share it. Orphan tags are possible if publish fails after tag.
