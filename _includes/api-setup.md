{%- comment -%}
  The API setup every task page shares: token, base URL, the Python and
  TypeScript clients, and the Go request helper the Go examples call.

    {% include api-setup.md id="strimzi" %}

  Params:
    id  unique, kebab-case prefix for this page's tab ids
{%- endcomment -%}
{%- assign p = include.id -%}
The API examples below share this setup:

{% capture setup_curl %}
```bash
export STREAMTIME_TOKEN=<your-access-token>
export API=https://api.example.com/organizations/<org>
```
{% endcapture %}
{% capture setup_python %}
```python
import os
from streamtime_sdk.client import AuthenticatedClient

client = AuthenticatedClient(
    base_url="https://api.example.com",
    token=os.environ["STREAMTIME_TOKEN"],
)
ORG = "<org>"
```
{% endcapture %}
{% capture setup_ts %}
Uses the generated client in `streamtime-sdk/typescript/client`.

```typescript
import { client } from "./client/client.gen";

client.setConfig({
  baseUrl: "https://api.example.com",
  headers: { Authorization: `Bearer ${process.env.STREAMTIME_TOKEN}` },
});
const org = "<org>";
```
{% endcapture %}
{% capture setup_go %}
```go
package main

import (
    "bytes"
    "crypto/rand"
    "encoding/hex"
    "encoding/json"
    "net/http"
    "os"
)

const api = "https://api.example.com/organizations/<org>"

// newKey returns a random idempotency key.
func newKey() string {
    b := make([]byte, 16)
    rand.Read(b)
    return hex.EncodeToString(b)
}

// call sends one request with the access token and a JSON body (or none).
// An optional idempotency key is sent as the Idempotency-Key header.
func call(method, path string, body any, idempotencyKey ...string) (*http.Response, error) {
    var buf bytes.Buffer
    if body != nil {
        if err := json.NewEncoder(&buf).Encode(body); err != nil {
            return nil, err
        }
    }
    req, err := http.NewRequest(method, api+path, &buf)
    if err != nil {
        return nil, err
    }
    req.Header.Set("Authorization", "Bearer "+os.Getenv("STREAMTIME_TOKEN"))
    req.Header.Set("Content-Type", "application/json")
    if len(idempotencyKey) > 0 {
        req.Header.Set("Idempotency-Key", idempotencyKey[0])
    }
    return http.DefaultClient.Do(req)
}
```
{% endcapture %}
{%- capture tid -%}{{ p }}-setup-api{%- endcapture -%}
{% include code-tabs.html id=tid curl=setup_curl python=setup_python typescript=setup_ts go=setup_go %}
