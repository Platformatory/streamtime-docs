# Flink Feature Roadmap — Prioritized Technical Designs

**Status:** Draft
**Owner:** Ashwin Venkatesan
**Last updated:** 2026-09-03

Three workstreams, in priority order. Each has its own technical design doc; this page is just
the index and the reasoning for the ordering.

| # | Workstream | Design doc | Why this order |
|---|---|---|---|
| 1 | Cluster creation interface/APIs + management plane | [`units-technical-design.md`](./units-technical-design.md) | Foundation — introduces Flink Units, fixes the mode-visibility drift bug, and defines the Job Workspace management plane (Add Job, capacity checks) everything else builds on. |
| 2 | Cluster monitoring — metrics & dashboards | [`metrics-monitoring-gaps-technical-design.md`](./metrics-monitoring-gaps-technical-design.md) | Needs #1's `job_name`-scoped data model (per-job `FlinkJob` rows) to make job-level dashboard drill-down meaningful; also the only way to validate #1's FU sizing formula against real usage. |
| 3 | Development-to-deployment lifecycle / VCS integration / multi-runtime | [`dev-to-deployment-lifecycle-technical-design.md`](./dev-to-deployment-lifecycle-technical-design.md) | Builds on #1's artifact-reference model (`artifact_package` on `Flink`/`FlinkJob`) and is best validated once #2's monitoring exists to observe the effect of a redeploy. Now also covers VCS-driven build execution, generalized registry credentials, and PyFlink/SQL job runtimes — previously split into a separate deferred document, merged back in since all of it builds on the same artifact-reference foundation. |

Product/UX framing for #1 and the artifact/VCS discussion for #3 lives in
[`units-and-cluster-ux.md`](./units-and-cluster-ux.md).
