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

### Choosing component versions when you create something

The last step of each create form has a collapsed section — **Bootstrap
Components** when you create a fleet, **Components** when you create a
workload. Closed, it reads **Using recommended versions**, and you can
deploy without opening it: every component gets its catalog default.

Open it to change a component. Each component has its own card:

| Field | What it does |
|---|---|
| **Version** | The versions in the selected registry, newest first. The default is marked *(recommended)*. |
| **Registry** | Shown only when the chart is mirrored in more than one registry. Changing it clears the version and selects the recommended (or newest) version that registry has, so a version is never paired with a registry that does not hold it. |
| **Custom settings** | Shown for components whose settings you can override. Opens the component's default settings as YAML for you to edit. |

Once you change anything, the closed section reads **N version
overrides** instead. If a registry has no versions of a component, the
row says so: pick another registry, or sync packages in **Settings**.
