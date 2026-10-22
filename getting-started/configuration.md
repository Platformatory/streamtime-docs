---
title: Configuration
nav_order: 2
parent: Getting Started
permalink: /getting-started/configuration/
---

Before bootstrapping fleets, tell Streamtime about the outside world it
will operate in. These settings are shared across the organization:

- **[Domains & Certificates](/configuration/domains-certificates/)** —
  the base domain your fleets answer on and the gateway certificate
  everything in a fleet trusts.
- **[Identity Providers](/configuration/identity-providers/)** — the
  OIDC provider your users sign in with and workloads authenticate
  against.
- **[Fleet Providers](/configuration/fleet-providers/)** — the cloud
  accounts (AWS, Oracle, GCP, …) Streamtime may provision fleets in.

Everything else an operator can change after deployment lives in
Streamtime's global settings rather than in environment variables; if a
setting matters to you, it is probably in the console's settings
screens.
