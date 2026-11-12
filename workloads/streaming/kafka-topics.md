---
title: Topics, messages and schemas
parent: Streaming
grand_parent: Workloads
nav_order: 20
permalink: /workloads/streaming/kafka-topics/
---

# Topics, messages and schemas

Every Kafka cluster's page has a **Manage Topics** view, with three tabs:

| Tab | What you can do |
|---|---|
| **Configuration** | List topics; create, change and delete them. Partitions can only grow |
| **Messages** | Read messages on a topic, oldest or newest first, ten at a time. Reading never affects the applications consuming the topic |
| **Schemas** | Links to the subjects that belong to the topic. Shown when the cluster has a schema registry. Schemas are browsed and managed in [Schemas]({{ site.baseurl }}/workloads/streaming/kafka-schemas/) |

Confluent Platform on VMs shows **Configuration** only.

Creating, changing and deleting topics is shown in every interface,
including Terraform, on each platform's page, for example
[Apache Kafka]({{ site.baseurl }}/workloads/streaming/apache-kafka/#manage-topics).
Message contents are never written to logs.

{% include api-setup.md id="kafka-topics" %}

## Browse messages

{% capture ui %}
1. Open the cluster and select **Manage Topics**, then the **Messages**
   tab.
2. Choose the topic, and **Oldest first** or **Newest first**.
3. Each row shows the partition, offset, timestamp, key and value. Load
   more to page through.
{% endcapture %}

{% capture curl %}
```bash
curl "$API/kafka/<cluster>/topics/payments/messages/?position=latest" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN"

# Next page: pass the cursor the response returned.
curl "$API/kafka/<cluster>/topics/payments/messages/?cursor=<cursor>" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN"
```
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.kafka_topics import list_kafka_topic_messages
from streamtime_sdk.models import ListKafkaTopicMessagesPosition

page = list_kafka_topic_messages.sync(
    ORG, "<cluster>", "payments",
    client=client, position=ListKafkaTopicMessagesPosition.LATEST,
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { listKafkaTopicMessages } from "./client";

const { data: page } = await listKafkaTopicMessages({
  path: { org_identifier: org, kafka_id: "<cluster>", topic: "payments" },
  query: { position: "latest" },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("GET", "/kafka/<cluster>/topics/payments/messages/?position=latest", nil)
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="kafka-messages-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet.
{% endcapture %}

{% capture mcp %}
Reading messages isn't available in MCP. MCP can read a topic's
configuration: *"What is the retention of the payments topic on the
orders cluster?"*
{% endcapture %}

{% include tabs.html id="kafka-messages" ui=ui api=api cli=cli mcp=mcp %}

## Browse schemas

Schemas are browsed and managed in **Administration → Schemas**: see
[Schemas]({{ site.baseurl }}/workloads/streaming/kafka-schemas/). A topic's
**Schemas** tab, and the **Schema** column of the topic list, link to its
subjects there.
