---
title: Schemas
parent: Streaming
grand_parent: Workloads
nav_order: 21
permalink: /workloads/streaming/kafka-schemas/
---

# Schemas

A Kafka cluster with a schema registry has a **Schemas** section under
**Administration**, next to **Topics**. It shows every subject in the
registry, each subject's versions and each schema, and lets you manage them:

| Task | Who can do it |
|---|---|
| Browse subjects, versions and schemas | Everyone who can see the cluster |
| Register a schema, check compatibility | Administrators and Cluster Administrators |
| Set or clear a subject's compatibility level | Administrators and Cluster Administrators |
| Delete a version or a subject, and remove it permanently | Administrators and Cluster Administrators |

Clusters without a schema registry have no **Schemas** section. Confluent
Platform on VMs doesn't support it.

Every change you make here is recorded in the organization's audit log, with
who made it, the cluster, the subject, the version and the schema ID. The
schema text itself is never recorded.

{: .note }
Managing schemas needs a recent Agent on the cluster's fleet. If the fleet
runs an older Agent, **Schemas** shows a notice and offers browsing only, and
the API answers `agent_update_required`. Run **Update Agent** on the fleet to
enable registering, compatibility changes and deletes.

Schemas that reference other schemas (Protobuf imports, Avro named types
from another subject) can be browsed but not registered here.

{% include api-setup.md id="kafka-schemas" %}

## Browse schemas

{% capture ui %}
1. Open the cluster and select **Administration**, then **Schemas**.
2. Search for a subject, and select it. Its latest version opens, with the
   schema type and schema ID.
3. Choose another **Version** to see an older schema. The compatibility
   level the subject uses is shown beside it.
4. Turn on **Show deleted** to list soft-deleted subjects and versions too.
   They're marked **Deleted**.
{% endcapture %}

{% capture curl %}
```bash
# Whether the cluster has a registry, and its default compatibility level.
curl "$API/kafka/<cluster>/schemas/" -H "Authorization: Bearer $STREAMTIME_TOKEN"

# Subjects; deleted=true adds soft-deleted ones in "deleted_subjects".
curl "$API/kafka/<cluster>/schemas/subjects/?deleted=true" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN"

curl "$API/kafka/<cluster>/schemas/subjects/payments-value/versions/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN"
curl "$API/kafka/<cluster>/schemas/subjects/payments-value/versions/latest/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN"
```
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.kafka_schemas import (
    get_kafka_schema_registry,
    get_kafka_schema_subject_version,
    list_kafka_schema_subjects,
)

registry = get_kafka_schema_registry.sync(ORG, "<cluster>", client=client)
subjects = list_kafka_schema_subjects.sync(ORG, "<cluster>", client=client, deleted=True)
schema = get_kafka_schema_subject_version.sync(
    ORG, "<cluster>", "payments-value", "latest", client=client
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import {
  getKafkaSchemaRegistry,
  getKafkaSchemaSubjectVersion,
  listKafkaSchemaSubjects,
} from "./client";

const cluster = { org_identifier: org, kafka_id: "<cluster>" };
const { data: registry } = await getKafkaSchemaRegistry({ path: cluster });
const { data: subjects } = await listKafkaSchemaSubjects({
  path: cluster,
  query: { deleted: true },
});
const { data: schema } = await getKafkaSchemaSubjectVersion({
  path: { ...cluster, subject: "payments-value", version: "latest" },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("GET", "/kafka/<cluster>/schemas/subjects/?deleted=true", nil)
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="browse-schemas-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet.
{% endcapture %}

{% capture mcp %}
Not available in MCP.
{% endcapture %}

{% include tabs.html id="browse-schemas" ui=ui api=api cli=cli mcp=mcp %}

## Register a schema

Registering under a new subject creates it. Registering under an existing
subject adds a version, if the schema is compatible under the subject's
compatibility level. Registering a schema identical to an existing version
returns that version and creates nothing.

Subjects are usually named after the topic: `<topic>-value` for message
values and `<topic>-key` for keys.

{% capture ui %}
1. In **Administration → Schemas**, select **Register schema**. To add a
   version to a subject, select the subject and then **Register new
   version**.
2. Enter the **Subject**, choose the **Schema type** (**Avro**, **JSON
   Schema** or **Protobuf**) and paste the **Schema**, up to 1 MiB.
3. Optionally select **Check compatibility** first (see below).
4. Select **Register**. The new version opens. A schema that isn't
   compatible is refused with the registry's reason, and nothing is
   registered.
{% endcapture %}

{% capture curl %}
```bash
curl -X POST "$API/kafka/<cluster>/schemas/subjects/payments-value/versions/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"schema_type": "avro",
       "schema": "{\"type\":\"record\",\"name\":\"Payment\",\"fields\":[{\"name\":\"id\",\"type\":\"string\"}]}"}'
# {"subject": "payments-value", "id": 12, "version": 1}
```
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.kafka_schemas import register_kafka_schema
from streamtime_sdk.models import SchemaCandidate, SchemaType

registered = register_kafka_schema.sync(
    ORG, "<cluster>", "payments-value",
    client=client,
    body=SchemaCandidate(schema=open("payment.avsc").read(), schema_type=SchemaType.AVRO),
)
print(registered.id, registered.version)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { readFileSync } from "node:fs";
import { registerKafkaSchema } from "./client";

const { data: registered } = await registerKafkaSchema({
  path: { org_identifier: org, kafka_id: "<cluster>", subject: "payments-value" },
  body: { schema: readFileSync("payment.avsc", "utf8"), schema_type: "avro" },
});
```
{% endcapture %}
{% capture go %}
```go
schema, err := os.ReadFile("payment.avsc")
if err != nil {
    return err
}
resp, err := call("POST", "/kafka/<cluster>/schemas/subjects/payments-value/versions/",
    map[string]string{"schema": string(schema), "schema_type": "avro"})
if err != nil {
    return err
}
defer resp.Body.Close()
// 200 with {"subject", "id", "version"}; 409 schema_incompatible; 422 schema_invalid.
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="register-schema-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet.
{% endcapture %}

{% capture mcp %}
Not available in MCP.
{% endcapture %}

{% include tabs.html id="register-schema" ui=ui api=api cli=cli mcp=mcp %}

| Answer | Meaning | What to do |
|---|---|---|
| `409 schema_incompatible` | The schema breaks the subject's compatibility level | Change the schema, or change the subject's compatibility level |
| `422 schema_invalid` | The registry can't parse the schema as the chosen type | Fix the schema text, or choose the right type |
| `424 agent_update_required` | The fleet's Agent predates schema management | Run **Update Agent** on the fleet |

## Check compatibility before registering

The check asks the registry the same question registering would, without
registering anything. Under a level that covers all versions (for example
**Backward, all versions**) the schema is checked against every version;
otherwise against the latest. A subject with no versions is always
compatible.

{% capture ui %}
1. In the register dialog, enter the subject, type and schema.
2. Select **Check compatibility**. The dialog shows **Compatible**, or
   **Not compatible** with the registry's reasons.
{% endcapture %}

{% capture curl %}
```bash
curl -X POST "$API/kafka/<cluster>/schemas/subjects/payments-value/compatibility/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"schema_type": "avro", "schema": "<schema text>"}'
# {"compatible": false, "messages": ["..."]}
```
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.kafka_schemas import check_kafka_schema_compatibility
from streamtime_sdk.models import SchemaCandidate, SchemaType

verdict = check_kafka_schema_compatibility.sync(
    ORG, "<cluster>", "payments-value",
    client=client,
    body=SchemaCandidate(schema=candidate_text, schema_type=SchemaType.AVRO),
)
if not verdict.compatible:
    print("\n".join(verdict.messages))
```
{% endcapture %}
{% capture typescript %}
```typescript
import { checkKafkaSchemaCompatibility } from "./client";

const { data: verdict } = await checkKafkaSchemaCompatibility({
  path: { org_identifier: org, kafka_id: "<cluster>", subject: "payments-value" },
  body: { schema: candidateText, schema_type: "avro" },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("POST", "/kafka/<cluster>/schemas/subjects/payments-value/compatibility/",
    map[string]string{"schema": candidateText, "schema_type": "avro"})
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="check-compatibility-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet.
{% endcapture %}

{% capture mcp %}
Not available in MCP.
{% endcapture %}

{% include tabs.html id="check-compatibility" ui=ui api=api cli=cli mcp=mcp %}

## Set or clear a subject's compatibility level

A subject uses the registry's default level unless it sets its own. The
levels are **Backward**, **Backward, all versions**, **Forward**, **Forward,
all versions**, **Full**, **Full, all versions** and **None** (API values
`BACKWARD`, `BACKWARD_TRANSITIVE`, `FORWARD`, `FORWARD_TRANSITIVE`, `FULL`,
`FULL_TRANSITIVE`, `NONE`). The registry's default level can't be changed
here.

{% capture ui %}
1. In **Administration → Schemas**, select the subject.
2. Choose a level in **Compatibility**. It applies at once.
3. To go back to the registry's default, choose **Registry default**.
{% endcapture %}

{% capture curl %}
```bash
# Set
curl -X PUT "$API/kafka/<cluster>/schemas/subjects/payments-value/config/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"compatibility": "FULL"}'
# {"subject": "payments-value", "compatibility": "FULL", "inherited": false}

# Clear: the registry default applies again ("inherited": true)
curl -X DELETE "$API/kafka/<cluster>/schemas/subjects/payments-value/config/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN"
```
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.kafka_schemas import (
    clear_kafka_schema_subject_compatibility,
    set_kafka_schema_subject_compatibility,
)
from streamtime_sdk.models import CompatibilityLevel, SubjectCompatibilityRequest

set_kafka_schema_subject_compatibility.sync(
    ORG, "<cluster>", "payments-value",
    client=client,
    body=SubjectCompatibilityRequest(compatibility=CompatibilityLevel.FULL),
)
clear_kafka_schema_subject_compatibility.sync(ORG, "<cluster>", "payments-value", client=client)
```
{% endcapture %}
{% capture typescript %}
```typescript
import {
  clearKafkaSchemaSubjectCompatibility,
  setKafkaSchemaSubjectCompatibility,
} from "./client";

const subject = { org_identifier: org, kafka_id: "<cluster>", subject: "payments-value" };
await setKafkaSchemaSubjectCompatibility({ path: subject, body: { compatibility: "FULL" } });
await clearKafkaSchemaSubjectCompatibility({ path: subject });
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("PUT", "/kafka/<cluster>/schemas/subjects/payments-value/config/",
    map[string]string{"compatibility": "FULL"})
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="schema-compatibility-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet.
{% endcapture %}

{% capture mcp %}
Not available in MCP.
{% endcapture %}

{% include tabs.html id="schema-compatibility" ui=ui api=api cli=cli mcp=mcp %}

## Delete a version or a subject

Deleting happens in two steps:

- A **soft delete** stops a version, or every version of a subject, being
  used for new data. The schemas and their IDs are kept, so messages
  already written with them still decode.
- A **permanent delete** removes something that is already soft-deleted.
  Messages written with it can no longer be decoded. It cannot be undone.

Either way you type the subject name to confirm, and the API needs
`confirm=true`. Deleting something already deleted, or absent, succeeds with
`"deleted": false`.

{% capture ui %}
1. In **Administration → Schemas**, select the subject.
2. To delete one version, choose it in **Version** and select **Delete
   version**. To delete the whole subject, select **Delete subject**.
3. Type the subject name and confirm.
4. To remove it permanently, turn on **Show deleted**, select the deleted
   subject or version, then **Delete permanently** (**Delete subject
   permanently** for a subject). Type the subject name again and confirm.
{% endcapture %}

{% capture curl %}
```bash
# Soft-delete one version, then remove it permanently
curl -X DELETE "$API/kafka/<cluster>/schemas/subjects/payments-value/versions/1/?confirm=true" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN"
curl -X DELETE "$API/kafka/<cluster>/schemas/subjects/payments-value/versions/1/?confirm=true&permanent=true" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN"

# Soft-delete a subject, then remove it permanently
curl -X DELETE "$API/kafka/<cluster>/schemas/subjects/payments-value/?confirm=true" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN"
curl -X DELETE "$API/kafka/<cluster>/schemas/subjects/payments-value/?confirm=true&permanent=true" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN"
```
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.kafka_schemas import (
    delete_kafka_schema_subject,
    delete_kafka_schema_subject_version,
)

delete_kafka_schema_subject_version.sync(
    ORG, "<cluster>", "payments-value", "1", client=client, confirm=True
)
delete_kafka_schema_subject.sync(ORG, "<cluster>", "payments-value", client=client, confirm=True)
delete_kafka_schema_subject.sync(
    ORG, "<cluster>", "payments-value", client=client, confirm=True, permanent=True
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { deleteKafkaSchemaSubject, deleteKafkaSchemaSubjectVersion } from "./client";

const subject = { org_identifier: org, kafka_id: "<cluster>", subject: "payments-value" };
await deleteKafkaSchemaSubjectVersion({ path: { ...subject, version: "1" }, query: { confirm: true } });
await deleteKafkaSchemaSubject({ path: subject, query: { confirm: true } });
await deleteKafkaSchemaSubject({ path: subject, query: { confirm: true, permanent: true } });
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("DELETE", "/kafka/<cluster>/schemas/subjects/payments-value/?confirm=true", nil)
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="delete-schema-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet.
{% endcapture %}

{% capture mcp %}
Not available in MCP.
{% endcapture %}

{% include tabs.html id="delete-schema" ui=ui api=api cli=cli mcp=mcp %}

A permanent delete of something still live is refused with
`409 subject_not_soft_deleted`: soft-delete it first.

## Find a topic's schemas

Topics link to the subjects named after them, and each link opens
**Schemas** with that subject selected:

- In **Administration → Topics**, the **Schema** column links **Value** and
  **Key** for topics with a `<topic>-value` or `<topic>-key` subject.
- In a topic, the **Schemas** tab lists every subject that belongs to it:
  the message value and key subjects, and subjects named after the topic and
  record type (`<topic>-<record name>`). A subject that belongs to a longer
  topic name, such as `orders-v2-value` for topic `orders`, isn't linked from
  `orders`.
- When the topic's own configuration sets how its subjects are named, only
  matching subjects are linked. A topic whose schemas are named after the
  record type alone can't be matched by name; the tab says so and links to
  the full list.

A subject named `<topic>-value` or `<topic>-key` links back to its topic
when that topic exists.

Reading messages doesn't depend on these links: each message is decoded
with the schema whose ID it carries.

{% capture ui %}
1. Open **Administration → Topics** and select **Value** or **Key** in a
   topic's **Schema** column, or open the topic and its **Schemas** tab.
2. Select a subject to open it in **Schemas**.
{% endcapture %}

{% capture curl %}
```bash
curl "$API/kafka/<cluster>/topics/orders/schemas/" -H "Authorization: Bearer $STREAMTIME_TOKEN"
# {"subjects": [{"subject": "orders-value", "role": "value", "match": "exact"},
#               {"subject": "orders-com.acme.Order", "role": "record", "match": "prefix"}],
#  "strategy": null}
```
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.kafka_topics import list_kafka_topic_schema_subjects

linked = list_kafka_topic_schema_subjects.sync(ORG, "<cluster>", "orders", client=client)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { listKafkaTopicSchemaSubjects } from "./client";

const { data: linked } = await listKafkaTopicSchemaSubjects({
  path: { org_identifier: org, kafka_id: "<cluster>", topic: "orders" },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("GET", "/kafka/<cluster>/topics/orders/schemas/", nil)
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="topic-schemas-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet.
{% endcapture %}

{% capture mcp %}
Not available in MCP.
{% endcapture %}

{% include tabs.html id="topic-schemas" ui=ui api=api cli=cli mcp=mcp %}
