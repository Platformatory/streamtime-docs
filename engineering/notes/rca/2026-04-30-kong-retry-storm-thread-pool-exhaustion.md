# RCA: Kong retry storm exhausts backend thread pool

**Date:** 2026-04-30  
**Severity:** High — backend becomes unresponsive to all Kong traffic until restart  
**Component:** `fleet-manager-gateway` — Kong upstream retry + keepalive configuration  
**Status:** Fixed

---

## Summary

After a slow or hung backend request, Kong's default `retries: 5` replayed the request five additional times at 30-second intervals. Each retry consumed a `sync_to_async` thread inside the Django backend. With multiple concurrent browser requests, the 16-thread pool was exhausted within seconds. All subsequent Kong requests queued behind the stuck threads indefinitely. Requests sent directly to `localhost:7999` continued to work — confirming the hang was caused entirely by Kong-side retry behaviour, not the backend logic itself.

This incident is distinct from the [2026-04-10 double-validation hang](./2026-04-10-fleet-create-double-validation-hang.md), which introduced CLOSE_WAIT connections via Uvicorn hot-reload. Here there were **zero** CLOSE_WAIT connections — the prior `Connection: close` fix was working correctly. The hang was driven entirely by retry amplification.

---

## Timeline

| Time | Event |
|---|---|
| T+0 | One or more backend requests slow down (blocked thread in sync_to_async) |
| T+0 to T+30 | Kong marks upstream unhealthy, begins `try 2` retry |
| T+30 to T+60 | `try 3` — additional thread consumed per retry per concurrent request |
| T+60 to T+150 | `try 4`, `try 5`, `try 6` at 30s intervals — thread pool saturated |
| T+150 | All `sync_to_async` threads in `futex_wait_queue`; new requests queue in nginx worker |
| Recovery | Gateway container restart (Kong re-establishes fresh connection pool) |

---

## Root Cause Chain

### 1. Kong default `retries: 5` on the backend service

Kong's default for any service without an explicit `retries` value is **5 retries**. When the backend's `read_timeout: 30000` fires (30s), Kong retries the same request up to 5 more times — each with its own 30-second window:

```
[error] upstream timed out (110: Connection timed out) ... try 2
[error] upstream timed out (110: Connection timed out) ... try 3
[error] upstream timed out (110: Connection timed out) ... try 4
[error] upstream timed out (110: Connection timed out) ... try 5
[error] upstream timed out (110: Connection timed out) ... try 6  ← 5 retries exhausted
```

Total wall time for one failed request: up to **5 × 30s = 150s**. With N concurrent browser requests (each having multiple parallel API calls), the thread consumption is:

```
threads_consumed = N_requests × 6 retries × threads_per_request
```

### 2. `sync_to_async` threads cannot be cancelled

Each Kong retry spawns a new backend request → a new `sync_to_async` thread. As documented in the 2026-04-10 RCA, these threads cannot be interrupted by asyncio cancellation. Once the Django thread pool is exhausted (default 16 threads via `threadpool_size`), new requests wait in the nginx queue indefinitely.

### 3. Thread pool evidence

```
# pid 859 — Django worker
Threads: 42

# /proc/859/task/*/wchan:
do_epoll_wait     ← event loop (alive)
do_epoll_wait
futex_wait_queue  ← all remaining 40 threads stuck
futex_wait_queue
... (×38 more)
```

### 4. Kong keepalive pool retains stale connections

Default Kong upstream keepalive: `pool_size=512, idle_timeout=60s, max_requests=10000`.

With 26 ESTABLISHED TCP connections to port 7999 (observed via `/proc/net/tcp`), Kong's pool was holding connections to a saturated backend. When the backend recovered and threads eventually freed, Kong continued routing new work to the same pool of connections — some of which pointed to thread-pool slots that were still draining the previous retry backlog.

### 5. Why `localhost:7999` worked

Direct requests bypassed Kong's retry logic entirely. A single request → a single thread. With at least 2 threads still idle (`do_epoll_wait`), direct requests processed normally. This asymmetry (Kong hung, direct fine) is the diagnostic fingerprint of a Kong-side retry storm rather than a backend logic bug.

---

## Evidence

**Kong error logs showing retry escalation:**
```
[error] ... upstream timed out (110: Connection timed out) while reading response header from upstream,
        client: ..., server: kong, request: "GET /api/organizations/...",
        upstream: "http://172.19.0.14:7999/...", host: "...", response: "504", try 4
[error] ... upstream timed out ... try 5
[error] ... upstream timed out ... try 6
```

**Backend thread state — all threads exhausted:**
```
# 40 of 42 threads in futex_wait_queue; 2 in do_epoll_wait (event loop alive)
```

**TCP connections — no CLOSE_WAIT (prior fix working):**
```
ESTABLISHED: 26   # Kong keepalive pool
TIME_WAIT:   10   # recently closed connections draining
CLOSE_WAIT:   0   # Connection: close fix from 2026-04-10 is working
```

---

## Fixes Applied

### Fix 1: Disable retries on the backend service

`fleet-manager-gateway/kong.yml` and `kong.singlenode.yaml`:

```yaml
- name: backend
  url: http://...
  retries: 0       # ← added; was 5 (Kong default)
  connect_timeout: 10000
  write_timeout: 30000
  read_timeout: 30000
```

**Rationale:** The backend is not idempotent for POST/PATCH requests. Retrying a timed-out write can cause duplicate operations. For GET requests, the retry amplification risk outweighs any availability benefit — a 30s timeout is already a generous read window.

### Fix 2: Reduce upstream keepalive pool aggressiveness

`docker-compose.yaml` gateway environment and `fleet-manager-gateway/gateway.env.sh`:

```bash
KONG_UPSTREAM_KEEPALIVE_IDLE_TIMEOUT=5     # seconds (was 60)
KONG_UPSTREAM_KEEPALIVE_POOL_SIZE=64        # connections (was 512)
KONG_UPSTREAM_KEEPALIVE_MAX_REQUESTS=100    # per-connection (was 10000)
```

| Setting | Old | New | Effect |
|---|---|---|---|
| `IDLE_TIMEOUT` | 60s | 5s | Stale connections evicted 12× faster after a backend incident |
| `POOL_SIZE` | 512 | 64 | Limits simultaneous connections Kong can hold to the backend |
| `MAX_REQUESTS` | 10000 | 100 | Connections cycle more frequently, reducing reuse of connections to still-recovering backend workers |

---

## Impact on other services

### gRPC (`temporal-grpc` service)

**Not affected.** `retries: 0` was set only on the `backend` service entry. The `temporal-grpc` service entry is separate and unchanged.

The global `KONG_UPSTREAM_KEEPALIVE_*` settings apply to all upstream pools, including the gRPC connection pool. The practical effect: gRPC connections idle for more than 5 seconds will be re-established by Kong on the next call. The Temporal client reconnects transparently — there is no correctness or ordering impact. Workflow execution latency on the first call after an idle period may increase by one TCP + TLS handshake RTT (~10–50ms).

### Other services (frontend, grafana, loki, mcp)

Unaffected by `retries: 0` (change is backend-scoped). Keepalive pool changes apply globally but these services are not under load conditions that would be sensitive to idle timeout reduction.

---

## Recovery Procedure (if hang recurs before fix is deployed)

```bash
# 1. Confirm it is a Kong-side retry storm (not a backend logic bug):
#    Direct request works → Kong retry storm. Direct also hangs → backend logic bug.
curl http://localhost:7999/health/

# 2. If Kong retry storm confirmed, restart only the gateway to flush the connection pool:
docker compose restart fleet-manager-gateway

# 3. If direct requests also hang, fall back to backend worker restart:
docker exec backend sh -c "cat /proc/$(ls /proc | grep -E '^[0-9]+$' | sort -n | tail -1)/status | grep Pid"
docker exec backend sh -c "kill -9 <worker-pid>"
```

---

## Prevention

| Guard | Location | What it prevents |
|---|---|---|
| `retries: 0` on backend service | `kong.yml`, `kong.singlenode.yaml` | Retry amplification turning one slow request into 5× thread consumption |
| `KEEPALIVE_IDLE_TIMEOUT=5s` | Kong env | Stale connections are evicted quickly after a backend recovery |
| `KEEPALIVE_POOL_SIZE=64` | Kong env | Caps the number of connections Kong can hold open simultaneously |
| `Connection: close` on 504 (from 2026-04-10 fix) | `RequestTimeoutMiddleware` | Prevents Kong from reusing a connection that carried a timeout response |
| All `requests`/`subprocess` calls have explicit timeouts (from 2026-04-29 audit) | Backend | Reduces frequency of the slow requests that trigger the retry amplification |

---

## Lessons Learned

1. **Kong's `retries` default is 5 — always set it explicitly on stateful services.** POST/PATCH endpoints are not retry-safe. Even GET endpoints can cause thread exhaustion if retries interact with a slow backend. Default to `retries: 0` on any service where retry-on-timeout is not explicitly desired.

2. **The diagnostic fingerprint of a Kong retry storm is:** Kong returns 504, direct requests succeed, thread count is high with threads in `futex_wait_queue`, zero CLOSE_WAIT, elevated ESTABLISHED count matching the keepalive pool. Do not mistake this for a backend bug.

3. **Kong's keepalive pool outlives individual request failures.** After a backend incident, the pool retains connections to workers that may still be draining their retry backlog. A shorter `IDLE_TIMEOUT` and smaller `POOL_SIZE` are defense-in-depth: the pool recovers faster and holds fewer connections to saturated workers.

4. **Restart the gateway, not just the backend, when Kong retry storms are suspected.** Restarting the backend clears the thread pool but leaves Kong's keepalive pool pointing at a fresh process — which then gets hit immediately by queued retries. Restarting the gateway clears both sides simultaneously.
