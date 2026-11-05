---
title: Packages
parent: Bring your own
nav_order: 8
permalink: /bring-your-own/packages/
---

# Packages

Streamtime installs only what is in its **package catalog**: the charts
and images behind each workload and platform component, with their
versions. The catalog is synced from Streamtime's tracked repositories
during first-time setup (**Package Catalog**), and you can add your own:

- **Your own Helm repositories** to track, so their charts and versions
  appear in the catalog.
- **Packages and package rules**: which versions are offered and which is
  the default for new workloads.
- **Helm Values** on a workload, to change its chart settings for that
  workload only.

See [Package Management]({{ site.baseurl }}/getting-started/package-management/)
for the catalog, version policy and air-gapped installations, and the
Terraform resources
[streamtime_helm_repository]({{ site.baseurl }}/terraform/helm-repository/),
[streamtime_tracked_repository]({{ site.baseurl }}/terraform/tracked-repository/),
[streamtime_package]({{ site.baseurl }}/terraform/package/) and
[streamtime_package_rule]({{ site.baseurl }}/terraform/package-rule/).
