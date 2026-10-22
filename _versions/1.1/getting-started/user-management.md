---
title: "User Management"
permalink: "/1.1/getting-started/user-management/"
nav_exclude: true
search_exclude: true
version_snapshot: "1.1"
---


Streamtime is multi-tenant: everything belongs to an **organization**,
and users belong to organizations.

## Organizations

An organization is a tenant: its fleets, workloads, settings, users and
secrets are isolated from every other organization. Organization
identifiers are short slugs (lowercase and dashes, ≤ 24 characters) and
appear in every API path.

{% capture ui %}
1. In the sidebar, go to **Organizations** and select **Create
   organization**.
2. Give it a **Name** and **Identifier**, then select **Create**.
3. Open the organization and add users under **Users**.
{% endcapture %}

{% capture cli %}
```bash
streamtime org list
streamtime org get <org>
```
{% endcapture %}

{% capture mcp %}
MCP is scoped to one organization — the one in its URL — and reads its
state; it does not create organizations.
{% endcapture %}

{% capture http %}
```bash
curl -X POST "https://<streamtime-api-endpoint>/organizations/" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"identifier": "acme", "name": "Acme"}'
```

Invite a user into an organization:

```bash
curl -X POST "https://<streamtime-api-endpoint>/organizations/acme/members/invite/" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"email": "dev@acme.example"}'
```
*Paths from the committed OpenAPI snapshot; bodies are schema-derived and
not executed against a live deployment.*
{% endcapture %}

{% capture api %}{% include code-tabs.html id="create-organization-api" curl=http python=none typescript=none go=none %}{% endcapture %}

{% include tabs.html id="create-organization" ui=ui api=api cli=cli mcp=mcp %}

## Users and invites

Users sign in through the organization's identity provider (see
[Identity Providers](/configuration/identity-providers/)). An
organization's administrator invites users; an invite grants access to
that organization only.

## Roles and super users

- **Super users** (the `SUPER_USER_EMAILS` / `fleetmanager.superUserEmails`
  list) can create organizations and have complete administrator
  privileges everywhere. Typically just the deployment owner.
- **Organization administrators** manage their organization: users,
  fleets, workloads and settings.
- **Members** use what their organization gives them access to.

## First steps after login

1. Sign in to the `root` organization (your email must be in the super
   user list — see [Installation](/getting-started/installation/)).
2. Create an organization for your team.
3. Invite your teammates.
4. Configure the organization: [Configuration](/getting-started/configuration/).
