---
title: Configuration
nav_order: 2
parent: Getting Started
permalink: /getting-started/configuration/
---

# Configuration

Before you create fleets, tell Streamtime about the outside world it
operates in. Each of these has a default, and each can be replaced by
what your organization already runs:

- [DNS & certificates]({{ site.baseurl }}/configuration/domains-certificates/):
  the base domain your fleets publish their endpoints under, and the fleet
  certificate.
- [Identity providers]({{ site.baseurl }}/configuration/identity-providers/):
  how your people sign in, and the tokens Kafka clients use.
- [Cloud Accounts]({{ site.baseurl }}/configuration/fleet-providers/):
  the cloud accounts Streamtime may create fleets in.
- [Connectivity]({{ site.baseurl }}/bring-your-own/connectivity/) and the
  [gateway certificate]({{ site.baseurl }}/bring-your-own/gateway-certificate/):
  how fleets reach Streamtime, and what they trust.
- Everything else, from secrets and registries to email, alerts and AI
  models: [Bring your own]({{ site.baseurl }}/bring-your-own/).

Settings an administrator can change after installation live in the
console's **Settings** screens rather than in environment variables.
Installation-wide settings and the license are not organization
resources: they are set in first-time setup and by the installation's
administrators.
