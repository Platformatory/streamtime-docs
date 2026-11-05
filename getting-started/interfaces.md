---
title: Interfaces
nav_order: 3
parent: Getting Started
has_children: true
permalink: /getting-started/interfaces/
---

# Interfaces

Everything in Streamtime can be done from more than one place. Every
interface talks to the same API through the same gateway, so what you do
in one shows up in all the others.

| Interface | For | Signs in with |
|---|---|---|
| **Console** | People, in the browser | Your organization's identity provider |
| **API** (HTTP) | Scripts and integrations | A sign-in token, or an API key |
| **SDKs** (Python, TypeScript) | Applications | A sign-in token, or an API key |
| **CLI** (`streamtime`) | People in a terminal, and CI | `streamtime login`, or an API key |
| **MCP** | AI assistants and agents | An API key with the **MCP Agent** role, or a sign-in token |
| **Terraform** | Infrastructure as code | An API key, or your CLI login |

Every task page in these docs shows the task in each interface, in tabs.

## Addresses

Your installation has two addresses: the console (for example
`https://console.example.com`) and the API (for example
`https://api.example.com`). Every API path starts with your organization:
`https://api.example.com/organizations/<org>/…`.

## API keys

Scripts, CI, Terraform and MCP clients use an API key rather than a
person's sign-in. Create one with the role it needs, and send it in the
`X-Streamtime-Key` header. See [API keys and OAuth clients]({{ site.baseurl }}/getting-started/api-keys/).

## API

```bash
export API=https://api.example.com/organizations/<org>

# With an API key
curl "$API/fleet/" -H "X-Streamtime-Key: $STREAMTIME_API_KEY"

# With a sign-in token
curl "$API/fleet/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
```

Operations that change something in a fleet return `202` with an
**Operation ID** at once; poll the resource's status until it is done.
The OpenAPI document is served at `https://api.example.com/api/schema/public/`.

## SDKs

Generated from the same OpenAPI document as the API:

```bash
pip install streamtime-sdk          # Python
npm install @streamtime.ai/sdk      # TypeScript
```

Use the SDK version that matches your installation. The API examples in
these docs show the setup for each language.

## CLI

The CLI isn't published to a package index yet. Install it from the
`streamtime-cli` folder of the Streamtime source, with
[uv](https://docs.astral.sh/uv/):

```bash
uv tool install ./streamtime-cli
```

Then sign in, as yourself or with an API key:

```bash
# As yourself: opens your identity provider in the browser
# (--grant password for a terminal without a browser).
streamtime login --org <org> --streamtime-url https://api.example.com

# With an API key; saved in ~/.streamtime/config.yaml.
streamtime configure --org <org> --api-key <key> --streamtime-url https://api.example.com

streamtime fleet list
```

In CI, skip both: set `STREAMTIME_API_KEY`, `STREAMTIME_ORG` and
`STREAMTIME_URL`. `streamtime config show` prints the current context, and
`--help` works on every command.

## MCP

The MCP server is part of the API, at
`https://api.example.com/organizations/<org>/mcp/` (HTTP transport). Point
your MCP client at it with an API key that has the **MCP Agent** role:

```json
{
  "mcpServers": {
    "streamtime": {
      "url": "https://api.example.com/organizations/<org>/mcp/",
      "headers": { "X-Streamtime-Key": "<mcp-agent-key>" }
    }
  }
}
```

MCP tools read status, metrics, logs, alerts and benchmarks, and can
create a Kafka cluster; they see exactly what the API sees for that
organization.

## Terraform

Install the `streamtime-ai/streamtime` provider and point it at your
installation: see [Terraform]({{ site.baseurl }}/getting-started/terraform/).
Every resource is listed in the
[Terraform provider reference]({{ site.baseurl }}/terraform/).
