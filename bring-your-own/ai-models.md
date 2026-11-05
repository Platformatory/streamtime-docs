---
title: AI models
parent: Bring your own
nav_order: 12
permalink: /bring-your-own/ai-models/
---

# AI models

**Streamtime AI** (the assistant you chat with, and the investigations
it runs on alerts) uses a model you choose, with your own account. Each
organization sets its own.

| Provider | What you need |
|---|---|
| **OpenAI** | An API key |
| **OpenAI-compatible (self-hosted)** | The endpoint of your own server (vLLM, Ollama, LiteLLM …), usually ending in `/v1`, and an API key if it requires one. Streamtime must be able to reach it |
| **Anthropic (Claude)** | An API key |
| **Groq** | An API key |
| **Google (Gemini)** | An API key |

**Embedding model (optional).** To find similar past incidents by meaning,
Streamtime also uses an embedding model: OpenAI, OpenAI-compatible
servers and Google offer one; Anthropic and Groq don't. Without it,
incidents are matched by alert name and resource only. With OpenAI the
default is `text-embedding-3-small`.

The API key is stored as a secret and only its last four characters are
ever shown.

{% include api-setup.md id="ai-models" %}

## Choose the model

{% capture ui %}
1. Open **Streamtime AI** and its settings. When no model is set, the
   assistant shows **Open AI Model Config**.
2. On the **Model** tab, choose the **Provider**.
3. For **OpenAI-compatible (self-hosted)**, enter the **Endpoint URL** and
   turn on **Requires an API key** if your server needs one.
4. Enter the **API Key**. The **Model** list then loads; choose a model or
   type its name.
5. Optionally choose an **Embedding model**.
6. Select **Save**.

The **Investigations** and **Advanced** tabs tune how the assistant
investigates alerts.
{% endcapture %}

{% capture curl %}
```bash
curl -X PUT "$API/assistant/ai-model-config/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"provider": "anthropic", "model_name": "<model>", "api_key": "<api-key>"}'

# A self-hosted OpenAI-compatible server: provider "openai" with its endpoint.
curl -X PUT "$API/assistant/ai-model-config/" \
  -H "Authorization: Bearer $STREAMTIME_TOKEN" -H "Content-Type: application/json" \
  -d '{"provider": "openai", "api_endpoint": "https://llm.example.com/v1",
       "model_name": "<model>", "api_key": "<api-key>",
       "embedding_model_name": "<embedding-model>"}'
```

`provider` is `openai`, `anthropic`, `groq` or `google`.
`GET $API/assistant/ai-model-config/` shows what is set, with the key
masked.
{% endcapture %}
{% capture python %}
```python
from streamtime_sdk.api.assistant import organizations_assistant_ai_model_config_update
from streamtime_sdk.models import StreamtimeAIModelConfigUpdate

organizations_assistant_ai_model_config_update.sync(
    ORG,
    client=client,
    body=StreamtimeAIModelConfigUpdate.from_dict(
        {"provider": "anthropic", "model_name": "<model>", "api_key": "<api-key>"}
    ),
)
```
{% endcapture %}
{% capture typescript %}
```typescript
import { organizationsAssistantAiModelConfigUpdate } from "./client";

await organizationsAssistantAiModelConfigUpdate({
  path: { org_identifier: org },
  body: { provider: "anthropic", model_name: "<model>", api_key: "<api-key>" },
});
```
{% endcapture %}
{% capture go %}
```go
resp, err := call("PUT", "/assistant/ai-model-config/", map[string]any{
    "provider":   "anthropic",
    "model_name": "<model>",
    "api_key":    "<api-key>",
})
if err != nil {
    return err
}
defer resp.Body.Close()
```
{% endcapture %}
{% capture api %}{% include code-tabs.html id="ai-model-set-api" curl=curl python=python typescript=typescript go=go %}{% endcapture %}

{% capture cli %}
Not available in the CLI yet. Use the console or the API.
{% endcapture %}

{% capture mcp %}
Not available in MCP. An MCP client brings its own model; this setting
is for Streamtime AI inside the console.
{% endcapture %}

{% include tabs.html id="ai-model-set" ui=ui api=api cli=cli mcp=mcp %}
