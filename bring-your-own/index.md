---
title: Bring your own
nav_order: 3
has_children: true
permalink: /bring-your-own/
---

# Bring your own

Every dependency Streamtime needs has a default, so a trial needs none of
these. Each can be swapped for what your organization already runs. Most
are set during [first-time setup]({{ site.baseurl }}/getting-started/installation/)
and can be changed later in **Settings**.

| What | Default | Bring your own | Page |
|---|---|---|---|
| Infrastructure | A Kubernetes cluster Streamtime creates in your cloud account | Your own Kubernetes cluster, or your own virtual machines | [Infrastructure]({{ site.baseurl }}/bring-your-own/infrastructure/) |
| Sign-in | **Streamtime identity**, built in | Any OIDC identity provider | [Identity providers]({{ site.baseurl }}/configuration/identity-providers/) |
| Private connection | — | Tailscale, another tunnel, or your own network | [Connectivity]({{ site.baseurl }}/bring-your-own/connectivity/) |
| Gateway certificate | Generated from the Streamtime CA | Your own certificate | [Gateway certificate]({{ site.baseurl }}/bring-your-own/gateway-certificate/) |
| DNS and fleet certificates | **Streamtime Managed** | Your DNS zone (AWS Route53, Cloudflare, GoDaddy), or records you manage | [DNS & certificates]({{ site.baseurl }}/configuration/domains-certificates/) |
| Secrets | Built-in secret store | HashiCorp Vault | [Secrets]({{ site.baseurl }}/bring-your-own/secrets/) |
| Container images | Public registries, cached inside each fleet | A private mirror registry | [Container registry]({{ site.baseurl }}/bring-your-own/container-registry/) |
| Charts and packages | Streamtime's package catalog | Your own Helm repositories and packages | [Packages]({{ site.baseurl }}/bring-your-own/packages/) |
| Observability | Streamtime's own dashboards, metrics and logs | A copy to Datadog, Grafana Cloud or New Relic | [Bring Your Own Observability]({{ site.baseurl }}/operations/alerts-diagnostics/byo-observability/) |
| Alert destinations | Alerts in the console | Slack, PagerDuty or a webhook | [Alert channels]({{ site.baseurl }}/bring-your-own/alert-channels/) |
| Email | — | Your SMTP server | [Email]({{ site.baseurl }}/bring-your-own/email/) |
| AI models | — | OpenAI, Anthropic, Google, Groq, or a model you host | [AI models]({{ site.baseurl }}/bring-your-own/ai-models/) |
| Durable Executor | Built in | **Streamtime Managed**, or a Temporal service you run | [Durable Executor]({{ site.baseurl }}/bring-your-own/durable-executor/) |

How these fit together: [Architecture]({{ site.baseurl }}/about/architecture/).
