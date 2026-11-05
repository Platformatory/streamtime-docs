---
title: Email
parent: Bring your own
nav_order: 11
permalink: /bring-your-own/email/
---

# Email

With your own mail server, Streamtime emails the people who created a
resource:

- **Resource health:** when a resource they created becomes healthy or
  needs attention.
- **Alerts:** when an alert starts or clears on a resource they created.
- **Weekly performance report** for each cluster they created.

You choose which of these go out. Without a mail server, nothing is
emailed; everything stays visible in the console.

## Before you start

- The mail server's host name or IP address, its port and connection
  security: usually 587 with STARTTLS, or 465 with SSL/TLS.
- A username and password, if the server needs a sign-in.
- A **From address** the server allows Streamtime to send from.
- The web address of your Streamtime console, for the links in emails.

{% include api-setup.md id="email" %}

## Set up email

{% capture ui %}
1. Go to **Settings → SMTP Email** (also a step of first-time setup).
2. Turn on **Send notification emails**.
3. Under **Mail server**, enter **SMTP server**, **Connection security**,
   **Port** and, if needed, **Timeout (seconds)**.
4. Under **Sign in**, enter **Username (optional)** and **Password**, or
   leave both blank if the server accepts mail without signing in.
5. Under **Sender**, enter **From address**, **From name (optional)** and
   **Link address in emails**.
6. Under **Which emails to send**, choose resource health, alerts and the
   weekly performance report.
7. Under **Test the settings**, select **Send test email**, then save.
{% endcapture %}

{% capture curl %}
```bash
curl -X PUT "$API/smtp-config/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"enabled": true, "host": "smtp.example.com", "port": 587,
       "encryption": "starttls", "username": "streamtime", "password": "<password>",
       "from_email": "streamtime@example.com", "from_name": "Streamtime",
       "link_base_url": "https://console.example.com",
       "status_emails_enabled": true, "alert_emails_enabled": true,
       "weekly_report_enabled": true}'

# Send a test (to the signed-in user if "to" is left out).
curl -X POST "$API/smtp-config/test/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"to": "you@example.com"}'
```

`encryption` is `starttls`, `ssl` or `none`. Leave `password` out to keep
the saved one; send an empty value to remove it. The password is never
returned.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.email import (
    organizations_smtp_config_partial_update,
    organizations_smtp_config_test_create,
)
from streamtime_sdk.models import PatchedOrganizationSmtpConfig, SmtpTestRequest

organizations_smtp_config_partial_update.sync(
    ORG,
    client=client,
    body=PatchedOrganizationSmtpConfig.from_dict({
        "enabled": True,
        "host": "smtp.example.com",
        "port": 587,
        "encryption": "starttls",
        "from_email": "streamtime@example.com",
    }),
)
organizations_smtp_config_test_create.sync(
    ORG, client=client, body=SmtpTestRequest.from_dict({"to": "you@example.com"})
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import {
  organizationsSmtpConfigPartialUpdate,
  organizationsSmtpConfigTestCreate,
} from "./client";

const path = { org_identifier: org };
await organizationsSmtpConfigPartialUpdate({
  path,
  body: {
    enabled: true,
    host: "smtp.example.com",
    port: 587,
    encryption: "starttls",
    from_email: "streamtime@example.com",
  },
});
await organizationsSmtpConfigTestCreate({ path, body: { to: "you@example.com" } });
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("PATCH", "/smtp-config/", map[string]any{
    "enabled":    true,
    "host":       "smtp.example.com",
    "port":       587,
    "encryption": "starttls",
    "from_email": "streamtime@example.com",
})
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="email-set-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime smtp set --enable --host smtp.example.com --port 587 --security starttls \
  --username streamtime --password --from-email streamtime@example.com \
  --link-address https://console.example.com \
  --status-emails --alert-emails --weekly-report
streamtime smtp test
streamtime smtp show
```

`--password` prompts for it; `--password-stdin` reads it from standard
input.
{% endcapture %}

{% capture mcp %}
MCP can read the settings (the `get_smtp_config` tool): *"Is outbound
email set up?"* Changing them isn't available in MCP.
{% endcapture %}

{% capture terraform %}
```hcl
variable "smtp_password" {
  type      = string
  sensitive = true
}

resource "streamtime_smtp_config" "mail" {
  enabled       = true
  host          = "smtp.example.com"
  port          = 587
  encryption    = "starttls"
  username      = "streamtime"
  password      = var.smtp_password
  from_email    = "streamtime@example.com"
  from_name     = "Streamtime"
  link_base_url = "https://console.example.com"
}
```

```bash
terraform import streamtime_smtp_config.mail smtp-config
```

An organization has one set of mail settings. `terraform destroy` stops
managing them and leaves their current values in place. The password is
kept in sensitive state and can't be recovered by an import.

See [streamtime_smtp_config]({{ site.baseurl }}/terraform/smtp-config/).
{% endcapture %}

{% include tabs.html id="email-set" ui=ui api=api cli=cli mcp=mcp terraform=terraform %}
