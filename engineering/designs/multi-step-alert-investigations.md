# Multi-step Alert Investigations

## Objective

Make automated alert investigations finish, cost a predictable amount, and answer
the questions an on-call engineer asks: what is wrong, is it unusual for this
cluster, has it happened before, and what was done then.

Today (2026-10-09) every investigation started on the live fleet stayed
`pending` forever: each model request is a Temporal activity with pydantic-ai's
default 60 s `start_to_close_timeout` and unlimited retries, a long DeepSeek
generation never fits, and all investigations start at once against one
self-hosted model.

## Decisions (locked)

| Decision | Choice |
|---|---|
| Concurrency | **Global** limit across all orgs: `GlobalConfiguration.assistant_investigation_max_concurrent` (default **1**). Extra investigations wait as `queued` and start FIFO. |
| Playbooks | **Per-org, matched to the alert.** Orgs import YAML (Settings and API). Each playbook declares `match` rules; the most specific enabled match wins, else the platform default playbook from `preload/investigation_playbooks/default.yaml`. |
| Step context | **One agent run per step.** Each step has its own prompt, tool allowlist and budget, and receives prior steps' structured outputs (not transcripts). |
| Report | JSON Schema per playbook (`spec.report.schema`), default includes baseline deviation and similar incidents. Validated server-side; invalid -> `partial`. |
| Similar incidents | **Deterministic first**: same org, same alertname and/or same resource, ranked by label overlap; returns findings + the human close note (RCA). Vector search is a later phase. |

## Playbook YAML

```yaml
apiVersion: streamtime.ai/v1
kind: InvestigationPlaybook
metadata:
  name: kafka-broker-down            # identifier: <=24 chars, lowercase + dash
  description: Broker / KRaft availability incidents
spec:
  priority: 100                      # higher wins among equally specific matches
  match:                             # every listed field must match; omitted = any
    alertnames: [KafkaBrokerContainersDown, AbnormalControllerState]
    severities: [critical, major]
    workload_types: [strimzi]
    labels: {}                       # exact label values
  budget:                            # whole investigation (defaults: GlobalConfiguration)
    max_model_requests: 24
    max_tool_calls: 40
    max_total_tokens: 300000
  steps:
    - id: triage
      title: Confirm the alert and its blast radius
      prompt: |
        ...
      tools: [get_cluster_status, get_cluster_alerts]   # optional allowlist (read-only only)
      budget: {max_model_requests: 4, max_tool_calls: 8}
  report:
    prompt: |
      ...
    schema: { JSON Schema of the final report }
```

## Execution

1. Alert webhook -> `get_or_create_investigation_for_alert` -> status `queued`
   -> `schedule_investigations()`.
2. `schedule_investigations()` (backend, serialized): marks stale `running`
   investigations failed, then starts queued ones FIFO while
   `running < max_concurrent`. Also called after every finalize and cancel.
3. `prepare` returns the resolved playbook (steps, budgets, report schema) —
   snapshotted into the workflow.
4. Workflow runs each step as one agent run (`UsageLimits` from the remaining
   budget), records it with `record_investigation_step` (transcript + output,
   visible in the UI as it happens), then a final report run with tools
   disabled. Budget exhausted -> skip to the report.
5. `finalize` validates the report against the playbook schema, stores it,
   then calls `schedule_investigations()`.

Model requests get a 10 min activity timeout and 3 attempts (was 60 s, unlimited).

## New read-only tools

- `compare_to_baseline(resource_type, identifier, metric_identifiers?)` —
  current value of each baseline metric vs its stored 7d/30d min/max/mean;
  flags `above_baseline_max`, `below_baseline_min`, `within_baseline`,
  `no_baseline`.
- `find_similar_incidents(alertname?, resource?, limit?)` — past investigations
  in the org with their findings, close note (human RCA) and time to close.

## Configuration (GlobalConfiguration, seeded)

| Key | Default |
|---|---|
| `assistant_investigation_max_concurrent` | 1 |
| `assistant_investigation_max_tool_calls` | 40 |
| `assistant_investigation_max_total_tokens` | 300000 |
| `assistant_investigation_stale_after_seconds` | 3600 |
| `assistant_investigation_max_tool_rounds` (existing) | per-step default model requests |

## Out of scope

- Vector / embedding similarity (phase 4 of the conversations plan).
- Per-org concurrency limits.
- Editing playbooks in a form UI (import/export YAML only).

## Deviations

- **Timeouts are code constants, not GlobalConfiguration.** Model request (10 min, 3 attempts), tool call (3 min), the 40 min soft deadline and the 50 min execution timeout live in `workflows/investigate_alert.py`. They bound Temporal history and must be fixed when the worker registers the activities. Budgets (requests, tool calls, tokens) are configurable.
- **Queue state is `metadata.run_state` (queued → running → done), not new `findings_status` values.** `findings_status` keeps `pending` until finalize, so existing consumers (frontend, MCP, CLI) are unchanged.
- **Legacy single-run path kept.** If prepare returns no `plan` (older backend), the workflow runs the previous single investigation.
- **The alert brief is part of the playbook (`spec.brief`), not the `auto_investigate` preload prompt.** The prompt carried its own tool list, plan and single-run report format, which contradicted each step's tools and output and the playbook's report schema. `brief` holds only the alert context and the observe-only mission (`{{placeholders}}` checked at import; omitted → the platform default's). The preload prompt and its `assistant_prompt_auto_investigate` key are removed (migration 0188). The MCP prompt `auto_investigate` keeps its name and argument but is built from the playbook the alert would get (brief + steps + report schema); its org comes from the MCP request, no longer from the argument.
- **Similar incidents can also match by meaning (embeddings), from the configured AI provider.** The locked decision was "deterministic first"; embeddings are added on top, not instead. `StreamtimeAIModelConfig.embedding_model_name` (optional): OpenAI defaults to `text-embedding-3-small`; a custom endpoint without a model is probed (`/models`, then `/embeddings`, likely names first, cached 10 min); Anthropic, Groq and Google without a model have none. Vectors live in `InvestigationEmbedding` (not conversation metadata), written at finalize and again when the operator closes with a note, and only compared within the same model. With no embeddings, `find_similar_incidents` ranks by rules and says so (`ranking`, `ranking_note`). `POST …/assistant/embedding-models/` checks the saved provider only, never a URL from the request.
- **Liveness, not just the stale timeout.** Before claiming slots, the scheduler asks Temporal about every running investigation (after a 60 s grace) and fails those whose workflow ended without finalizing (terminated, failed, timed out, missing), with a plain reason. The workflow also finalizes with the underlying error when it fails part-way. Queued investigations of an organization without an AI provider are failed with guidance instead of started.
- **Tool calls are counted from pydantic-ai's usage (executed calls).** Counting tool-call parts in the transcript included a batch pydantic-ai refused at `tool_calls_limit`, so steps looked over budget when they were not.
- **Playbooks are preloadable.** Manifest `investigation_playbooks[]` (a document plus `organization`), also read from `preload/investigation_playbooks/organizations/<org>/*.yaml`; validated like an import (invalid → manifest rejected), overwritten on every sync, skipped with a warning for an organization that does not exist.
- **The report is inside the budget.** Steps cannot spend 1 model request and a fifth of the tokens (at most 20,000), held back for the report; the report then runs on whatever the investigation has left (at most 2 requests). If nothing is left, no report is written and the investigation says so.
- **Liveness watches the investigation's own run** (`metadata.run_workflow_id`), not `conversation.workflow_id`, which a later Cancel command (alert resolved) overwrites while the run continues. A dispatch failure frees its slot and the scheduler claims again (up to 3 rounds per call).
- **Report and wrap-up runs get no tools** (`allowed_tools=[]`), on top of the per-step allowlist.
