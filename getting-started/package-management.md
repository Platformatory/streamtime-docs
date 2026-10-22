---
title: Package Management
nav_order: 4
parent: Getting Started
permalink: /getting-started/package-management/
---

Streamtime deploys workloads from a **package catalog**: the charts and
container images it is allowed to install, with their versions. Nothing
runs in a fleet that is not in the catalog, which is what makes
air-gapped and compliance-sensitive installations possible.

## What the catalog holds

| Kind | What it is |
|---|---|
| **Charts** | The Helm charts behind each workload and platform component (Kafka operators, gateways, monitoring) |
| **Images** | The container images those charts run |

Each tracked chart and image carries a **default version** — what new
workloads get — and a list of versions an existing workload can be
moved to.

## Version policy

- Versions are SemVer. Upgrades roll forward: a workload moves from its
  current version to a newer one through a scheduled operation (see
  [Scheduled Operations](/operations/scheduled-operations/)).
- Auto-upgrade can be enabled per workload so patch versions apply
  themselves; disable it to stay on a version you have tested.
- Version support follows the product's support policy: the current line
  plus the previous one. Older versions stop receiving security fixes.

## Air-gapped installations

For a cluster with no internet access, the catalog is mirrored into
your own registry: Streamtime's required charts and images are
pre-staged, and the catalog points at the mirror. The console lists
every package it expects so you can diff the mirror against what it
needs.

## How this shows up in the UI

When you create or upgrade a workload, the **Version** selectors are
populated from the catalog — you pick from what Streamtime can actually
install, never a free-text version.
