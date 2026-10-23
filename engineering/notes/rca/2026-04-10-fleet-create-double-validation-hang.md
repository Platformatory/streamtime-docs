# RCA: Fleet CREATE causes permanent Kong→Django connection hang

**Date:** 2026-04-10  
**Severity:** High — backend becomes unresponsive to all Kong traffic until restart  
**Component:** `fleet-manager-backend` — `FleetListView.post`, `RequestTimeoutMiddleware`  
**Status:** Fixed

---

## Summary

Creating a BYOK fleet via `POST /organizations/{org}/fleet/` caused an 11-second backend stall. If the stall coincided with a Uvicorn hot-reload (code change), the backend entered a permanent hang state where the Kong→Django connection pool was left with dead keep-alive connections. All subsequent requests through Kong timed out indefinitely. Recovery required force-killing the Django worker process.

---

## Timeline

| Time | Event |
|---|---|
| 08:39:11 | `FleetSerializer.validate()` completes (first run) |
| 08:39:11–23 | Backend stalls — event loop blocked for ~11 seconds |
| 08:39:23 | `/metrics/` request processed — confirms event loop was not fully blocked but HTTP response delayed |
| ~08:39 | Uvicorn hot-reload triggered by `views.py` change |
| Post-reload | Uvicorn logs "Waiting for connections to close / background tasks to complete" — hangs indefinitely |
| Recovery | `kill -9 <worker-pid>` via `docker exec backend sh -c "kill -9 1162"` |

---

## Root Cause Chain

### 1. Double validation in `FleetListView.post`

`views.py` explicitly called `serializer.is_valid()` at line 85, then immediately called `sync_to_async(self.create)()` at line 104. DRF's `CreateModelMixin.create` constructs a **new serializer** from `request.data` and calls `is_valid()` again:

```python
# views.py — BEFORE FIX
serializer = FleetCreateSerializer(data=data, context={'request': request})
if not await sync_to_async(serializer.is_valid)():          # ← validation run #1
    return Response(...)

response = await sync_to_async(self.create)(request, ...)   # ← self.create runs validation #2
```

`FleetSerializer.validate()` runs:
- `Organization.objects.get(...)` — DB query
- `BootstrapProvider.objects.filter(...)` — DB query  
- `provider_class.validate_advanced_configs(...)` — provider hook
- `bootstrap_resolver_service.validate_bootstrap_config_sync(...)` — version resolution

Each call takes ~5–6 seconds. Running it twice = ~11 seconds of synchronous blocking inside a `sync_to_async` thread.

### 2. Cancelled coroutine, uncancellable thread

`RequestTimeoutMiddleware` uses `asyncio.wait_for(timeout=25s)`. When the timeout fires:

- The **asyncio coroutine** is cancelled via `CancelledError` — the HTTP response is abandoned
- The **`sync_to_async` thread** continues running — Python threads cannot be cancelled

The thread eventually completes its work (DB queries finish) and tries to deliver the result back to the cancelled asyncio task via `asgiref`'s `loop.call_soon_threadsafe`. If the event loop is shutting down (Uvicorn hot-reload), this call blocks indefinitely — the thread is stuck waiting on a `futex` (observed via `/proc/<pid>/task/<tid>/wchan`).

### 3. CLOSE_WAIT connections block Uvicorn reload

Uvicorn's HTTP/1.1 handler keeps one socket per connection open until its associated asyncio task completes. Kong had already closed its side of the connections (`FIN` sent), putting them in `CLOSE_WAIT`. The Django worker held these sockets open waiting for the stuck threads. Uvicorn's reloader waited for all connections to close — which never happened:

```
INFO:     Waiting for connections to close. (CTRL+C to force quit)
INFO:     Waiting for background tasks to complete. (CTRL+C to force quit)
```

### 4. Kong pool reuses dead connections

The 504 response returned by the middleware did not include `Connection: close`. Uvicorn preserved the keep-alive connection. Kong's upstream pool treated the TCP connection as live and routed subsequent requests to it. The Django worker had abandoned the connection, so those requests never received a response.

---

## Evidence

**Log gap proves double validation:**
```
08:39:11,665  FleetSerializer validation successful   ← first is_valid() completes
              [11.4 second gap — second is_valid() running]
08:39:23,026  /metrics/ 200 OK
```

**`/proc` confirms stuck threads in CLOSE_WAIT:**
```
# All 33 threads in futex_wait_queue — not on DB, blocked in asgiref
tid=1162 wchan=do_epoll_wait    ← event loop
tid=1166..1533 wchan=futex_wait_queue   ← sync_to_async threads

# Multiple CLOSE_WAIT TCP connections (state=08)
0E0013AC:1F3F 030013AC:EC5C  08   ← Kong closed, Uvicorn holding
0E0013AC:1F3F 0D0013AC:C232  08
...
```

**Postgres shows no active queries** — threads finished DB work but were blocked returning results to the cancelled asyncio tasks.

---

## Fixes Applied

### Fix 1: Remove double validation — `core/views/fleet/views.py`

Use the already-validated serializer directly instead of calling `self.create()`:

```python
# BEFORE
response = await sync_to_async(self.create)(request, *args, **kwargs)

# AFTER — perform_create uses the serializer that is_valid() already ran on
await sync_to_async(self.perform_create)(serializer)
headers = self.get_success_headers(serializer.data)
response = Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)
```

**Impact:** Validation runs once (~6s → total ~1s for DB write). Request completes well within the 25s timeout.

### Fix 2: Force connection close on timeout — `fleet_manager/middleware.py`

```python
# BEFORE
return JsonResponse({'detail': 'Request timed out.'}, status=504)

# AFTER
response = JsonResponse({'detail': 'Request timed out.'}, status=504)
response['Connection'] = 'close'
return response
```

**Impact:** Uvicorn closes the TCP socket after sending the 504. Kong's pool drops the dead connection and opens a fresh one for the next request.

---

## Recovery Procedure (if hang recurs)

```bash
# 1. Identify the stuck worker PID (look for the process with many threads)
docker exec backend sh -c "ls /proc/ | grep -E '^[0-9]+$' | sort -n"
# Check which is the Django worker (not PID 1 or the resource tracker):
docker exec backend sh -c "cat /proc/<pid>/status | grep Threads"

# 2. Force-kill the worker — Uvicorn watcher respawns it in seconds
docker exec backend sh -c "kill -9 <worker-pid>"

# 3. Verify respawn
docker exec backend sh -c "ls /proc/ | grep -E '^[0-9]+$' | sort -n"
```

---

## Live forensics note (2026-05-01): `py-spy` usage

During a later recurrence, stack capture was done with `py-spy` from inside the backend container to identify where the worker was parked while requests timed out.

### What was run

```bash
# Temporary install in running container (debug session only)
docker compose exec fleet-manager-backend sh -c "uv pip install --system py-spy"

# Capture stack dump from stuck worker
docker compose exec fleet-manager-backend sh -c "py-spy dump -p <worker-pid>"
docker compose exec fleet-manager-backend sh -c "py-spy dump --locals -p <worker-pid>"
```

### Why this is acceptable

- `py-spy` is sampling-only and low-overhead for short, on-demand incident debugging.
- It helped confirm the worker was stalled around auditlog/middleware signal handling during reload-era hangs.

### Production guidance

- Do **not** permanently bake `py-spy` into production images by default.
- Prefer ephemeral/incident-only use (temporary install or debug container/session), then remove.
- Some hardened production environments block process inspection (`ptrace`) unless additional privileges are granted; validate policy before relying on this approach.

---

## Prevention

| Guard | Location | What it prevents |
|---|---|---|
| Never call `self.create()` after explicit `is_valid()` | Pattern/code review | Double validation re-triggering expensive hooks |
| `Connection: close` on all 504 responses | `RequestTimeoutMiddleware` | Kong reusing stale connections after timeout |
| `perform_create` timing log | `views.py` | Surfaces regressions immediately in logs |
| Tests (see `test_fleet_create_double_validation.py`) | CI | Catches re-introduction of double validation and missing response headers |
| All `requests`/`httpx`/`subprocess` calls must have explicit timeouts | Code review | Prevents indefinite thread hangs in sync_to_async contexts |

---

## Lessons Learned

1. **`sync_to_async` threads survive coroutine cancellation.** `asyncio.wait_for` is not a hard timeout for synchronous code running in the thread pool. Design views so blocking work is minimal and timeouts are a last resort, not a normal occurrence.

2. **DRF's `self.create()` is not idempotent with pre-validated serializers.** Calling it after `is_valid()` constructs a new serializer and re-runs all validators. When validators make DB calls, the cost doubles.

3. **`Connection: close` is mandatory on error responses in a proxied setup.** A keep-alive connection that carries a timeout error becomes a poison pill for the upstream pool.

4. **Single Uvicorn worker amplifies connection issues.** One stuck thread blocks the entire reload and all keep-alive connections. Consider `UVICORN_WORKERS=2` in development to isolate failures.

---

## Follow-up audit (2026-04-29): blocking calls without timeouts

A follow-up investigation after another occurrence of the same hang identified a class of latent bugs: synchronous external I/O calls inside `sync_to_async` thread-pool workers with no timeout. Any of these can trigger the same failure chain independently of the original double-validation bug.

### How to identify

Any `sync_to_async` thread that is blocked indefinitely on I/O will:
- Show `wchan=futex_wait_queue` in `/proc/<pid>/task/<tid>/wchan` (not `do_epoll_wait`)
- Leave the event loop responsive (metrics still return 200) but prevent new work from being scheduled
- Eventually fill the thread pool, at which point Kong connections stall

### Instances found and fixed

| File | Call | Problem | Fix |
|---|---|---|---|
| `core/license_utils.py` | `requests.get(jwks_url, timeout=10)` | `LicenseValidator()` instantiated fresh per-request — 1-hour JWKS cache was on the discarded instance, so every `GET /license/` hit `streamtime.ai` over the network | Made `_validator` a module-level singleton so the cache is actually shared |
| `core/views/shared/monitoring_utils.py` | 5× `session.get(...)` | No timeout — Prometheus/Loki/OpenCost queries could block indefinitely | Added `timeout=10` to all calls |
| `core/views/shared/utils.py` | 5× `session.get(...)` | Same as above (duplicate of monitoring_utils pattern) | Added `timeout=10` to all calls |
| `utils/auth.py` `AzureAuthProvider` | `requests.post(azure_ad_url)` | No timeout on Azure AD token fetch | Added `timeout=10` |
| `utils/auth.py` `OCIAuthProvider` | `subprocess.run(["oci", "ce", "cluster", "generate-token", ...])` | No timeout — OCI CLI makes network calls and can hang indefinitely | Added `timeout=30` |

### Instances found but not fixed (dead code)

| File | Reason not fixed |
|---|---|
| `fleet_manager/auth0_utils.py` | 20+ `requests` calls with no timeout, but `auth0_middleware`'s `__call__` is fully commented out and `Auth0User`/`Auth0Org` are only imported by that dead middleware — not reachable from any active request path |
| `fleet_manager/auth0_middleware.py` | Same — middleware is disabled |

### Rule going forward

Every `requests`, `httpx` (sync client), or `subprocess.run` call in the backend must have an explicit `timeout` argument. There is no safe default — the OS-level TCP timeout can be minutes. Sync views and `sync_to_async` blocks are particularly exposed because threads cannot be cancelled once started.

```python
# Always
requests.get(url, timeout=10)
requests.post(url, data=data, timeout=10)
subprocess.run(cmd, timeout=30)
httpx.Client(timeout=10.0)  # or per-request: client.get(url, timeout=10.0)

# Never
requests.get(url)           # no timeout = indefinite block
subprocess.run(cmd)         # no timeout = indefinite block
```
