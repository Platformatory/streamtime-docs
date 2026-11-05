---
title: User Management
nav_order: 4
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

{% include api-setup.md id="members" %}

## Invite a member

Inviting someone gives them access to this organization. It doesn't create
their account at your identity provider: set them up there first.

{% capture ui %}
1. Go to **Settings → Team Members** and invite a member.
2. Enter their **Email** and **Select Role**: **Administrator**,
   **Billing Administrator**, **Cluster Administrator**, **Infrastructure
   Administrator** or **Project Owner**.
3. With Streamtime identity as the sign-in, also set a **Password**; they
   sign in with this email and password.
4. Save. **Update Member Role** changes a role later; removing a member
   ends their access to the organization.
{% endcapture %}

{% capture curl %}
```bash
curl -X POST "$API/members/invite/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"email": "developer@example.com", "role": "Cluster Administrator"}'
```

Read, change or remove a member at `$API/members/<email>/` with `GET`,
`PATCH` or `DELETE`. Send `password` in the invite only with Streamtime
identity.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.organizations import organizations_members_invite_create
from streamtime_sdk.models import OrganizationMemberInviteRequest

organizations_members_invite_create.sync(
    ORG,
    client=client,
    body=OrganizationMemberInviteRequest.from_dict(
        {"email": "developer@example.com", "role": "Cluster Administrator"}
    ),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsMembersInviteCreate } from "./client";

await organizationsMembersInviteCreate({
  path: { org_identifier: org },
  body: { email: "developer@example.com", role: "Cluster Administrator" },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/members/invite/", map[string]any{
    "email": "developer@example.com",
    "role":  "Cluster Administrator",
})
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="member-invite-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Inviting isn't available in the CLI yet. List members with:

```bash
streamtime org members --org <org>
```
{% endcapture %}

{% capture mcp %}
Not available in MCP.
{% endcapture %}

{% capture terraform %}
```hcl
resource "streamtime_member" "developer" {
  email = "developer@example.com"
  role  = "Cluster Administrator"
}
```

Creating the resource invites the person. For a new person signing in
with Streamtime identity, also set `initial_password` from a sensitive
variable; it is used only for the invitation. Destroying the resource
removes their membership, not their account at your identity provider.

```bash
terraform import streamtime_member.developer developer@example.com
```

See [streamtime_member]({{ site.baseurl }}/terraform/member/).
{% endcapture %}

{% include tabs.html id="member-invite" ui=ui api=api cli=cli mcp=mcp terraform=terraform %}

For API keys and OAuth clients, see
[API keys and OAuth clients]({{ site.baseurl }}/getting-started/api-keys/).

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
