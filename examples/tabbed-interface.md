---
title: Tabbed interface
nav_exclude: true
---
# Example: tabbed interface

This page demonstrates `tabs.html` and `code-tabs.html`, the components the
task pages use to present each task in the UI, API, CLI and MCP interfaces.
It is excluded from navigation.

## Create a Kafka cluster

Prerequisites apply to every interface: a fleet in **Running** state and a
cloud account registered.

{% capture ui %}
1. In the sidebar, go to **Kafka clusters** and select **Create cluster**.
2. Choose the fleet, give the cluster an **Identifier**, and set
   **Cluster capacity**.
3. Select **Create**. The cluster appears in the list with the status
   **Provisioning**, then **Running**.
{% endcapture %}

{% capture curl %}
```bash
curl -sk -X POST "https://api.example.com/organizations/<org>/kafka/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"identifier": "orders", "fleet": "<fleet>"}'
```
Poll until the cluster reports **Running**:
```bash
curl -sk "https://api.example.com/organizations/<org>/kafka/orders/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN"
```
{% endcapture %}

{% capture python %}
```python
from streamtime_sdk.api.default import create_kafka
from streamtime_sdk.models import KafkaCreate

create_kafka(
    organization="<org>",
    body=KafkaCreate(identifier="orders", fleet="<fleet>"),
)
```
{% endcapture %}

{% capture typescript %}
```typescript
import { createKafka } from "./sdk.gen";

await createKafka({
  path: { organization: "<org>" },
  body: { identifier: "orders", fleet: "<fleet>" },
});
```
{% endcapture %}

{% capture go %}
```go
resp, err := http.Post(
    "https://api.example.com/organizations/<org>/kafka/",
    "application/json",
    strings.NewReader(`{"identifier":"orders","fleet":"<fleet>"}`),
)
```
{% endcapture %}

{% capture api %}{% include code-tabs.html id="example-create-kafka-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
```bash
streamtime kafka create --org <org> --fleet <fleet> --identifier orders
```
{% endcapture %}

{% include tabs.html id="example-create-kafka" ui=ui api=api cli=cli %}

A tab whose interface can't do the task yet still shows, with a plain note —
here the MCP tab of a scaling task:

{% capture ui2 %}
Scaling keeps the same identifier and only changes capacity.
{% endcapture %}
{% capture api2 %}
Same endpoint as above, `PATCH` instead of `POST`.
{% endcapture %}
{% capture mcp2 %}
Ask in plain language, e.g. *"what is the status of the orders cluster?"* —
MCP reads state, it does not change it.
{% endcapture %}

{% include tabs.html id="example-scale-kafka" ui=ui2 api=api2 mcp=mcp2 %}
