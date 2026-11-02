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
- **[Cloud Accounts](/configuration/fleet-providers/)** — the cloud
  accounts (AWS, Oracle, GCP, …) Streamtime may provision fleets in.

Everything else an operator can change after deployment lives in
Streamtime's global settings rather than in environment variables; if a
setting matters to you, it is probably in the console's settings
screens.

## Configure outbound email with Terraform

{% capture mail_ui %}
Configure the organization's outbound mail server in its email settings.
{% endcapture %}
{% capture mail_api %}
Read `/organizations/<org>/smtp-config/` with GET; save settings with PUT.
Omitted fields keep their current values. Omit `password` to keep the
saved password; send an empty string to clear it.
{% endcapture %}
{% capture mail_terraform %}
```hcl
variable "smtp_password" {
  type      = string
  sensitive = true
}

resource "streamtime_smtp_config" "mail" {
  enabled    = true
  host       = "smtp.example.com"
  port       = 587
  encryption = "starttls"
  username   = "streamtime"
  password   = var.smtp_password
  from_email = "streamtime@example.com"
}
```

An organization has one set of mail settings. Import it with
`terraform import streamtime_smtp_config.mail smtp-config`. Destroy stops
Terraform managing the settings and leaves their current values in place.
The password is kept in sensitive state and cannot be recovered by import.

Installation-wide system settings and the installation license are not
Terraform organization resources; configure those through the installation's
administration and setup interfaces.
{% endcapture %}
{% capture mail_cli %}
Use `streamtime smtp --help` for email configuration commands.
{% endcapture %}
{% capture mail_mcp %}
Use the API, CLI or Terraform to change the mail server settings.
{% endcapture %}
{% include tabs.html id="configure-mail" ui=mail_ui api=mail_api cli=mail_cli mcp=mail_mcp terraform=mail_terraform %}
