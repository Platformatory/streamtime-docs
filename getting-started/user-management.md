---
title: User Management
nav_order: 3
parent: Getting Started
permalink: /getting-started/user-management/
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

## Manage access with Terraform

Configure the provider for the organization whose access you manage. Creating
a member invites that person; it does not provision their external identity.
For a new person using built-in sign-in, also set `initial_password` to a
sensitive variable. It is used only for the invitation, not password resets.

{% capture access_ui %}
An organization administrator manages users under **Users**. Configure the
person at the organization's identity provider before they sign in.
{% endcapture %}
{% capture access_api %}
Use `POST /organizations/<org>/members/invite/` to invite a person, then
`GET`, `PUT` or `DELETE /organizations/<org>/members/<email>/` to read,
change their role or remove membership. API keys are managed under
`/organizations/<org>/api-keys/`; OAuth clients under
`/organizations/<org>/oauth-clients/`.
{% endcapture %}
{% capture access_terraform %}
```hcl
resource "streamtime_member" "developer" {
  email = "developer@example.com"
  role  = "Cluster Administrator"
}

resource "streamtime_api_key" "automation" {
  name = "automation"
  role = "Agent"
}

resource "streamtime_oauth_client" "producer" {
  identifier     = "producer"
  name           = "Order producer"
  kafka_clusters = ["orders"]
}
```

The OAuth client requires built-in sign-in. Its access settings cannot be
updated in place, so a change replaces it. API key values and OAuth client
secrets are sensitive and kept in Terraform state after creation; importing
one cannot recover its value. Protect the state storage.

```bash
terraform import streamtime_member.developer developer@example.com
terraform import streamtime_api_key.automation '<key-id>'
terraform import streamtime_oauth_client.producer producer
```

Destroying a member removes membership, not the person's account at their
identity provider. Destroying an API key or OAuth client revokes it.
{% endcapture %}
{% capture access_cli %}
List members with `streamtime org members --org <org>`. Use
`streamtime api-key --help` for API key commands. Member invitations and
OAuth client management use the API or Terraform.
{% endcapture %}
{% capture access_mcp %}
Use the API or Terraform to change organization access. Consult the
connected MCP server's tool list for the reads it supports.
{% endcapture %}
{% include tabs.html id="manage-access" ui=access_ui api=access_api cli=access_cli mcp=access_mcp terraform=access_terraform %}

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
