# ASGI Server Configuration

The Fleet Manager backend runs on **Uvicorn** (ASGI server) for production deployments. This provides better performance and async capabilities compared to Django's development server.

## Environment Variables

Configure Uvicorn via environment variables:

```bash
# Uvicorn Configuration
UVICORN_HOST=0.0.0.0                    # Bind address
UVICORN_PORT=8000                       # Port number
UVICORN_WORKERS=4                       # Number of worker processes (production)
UVICORN_RELOAD=false                    # Disable reload in production
UVICORN_LOG_LEVEL=info                  # Log level (debug/info/warning/error)
UVICORN_TIMEOUT_KEEP_ALIVE=5            # Keep-alive timeout (seconds)

# OAuth Configuration
OAUTH_VERIFY_SSL=true                   # Enable SSL verification for OAuth
```

## Production Docker Configuration

```dockerfile
# Use production Dockerfile
FROM fleet-manager-backend:prod

# Set production environment variables
ENV UVICORN_WORKERS=4
ENV UVICORN_RELOAD=false
ENV UVICORN_LOG_LEVEL=info
ENV OAUTH_VERIFY_SSL=true
```

## Performance Tuning

- **Workers**: Set `UVICORN_WORKERS` to `2 * CPU_CORES` for CPU-bound workloads
- **Keep-alive**: Lower `UVICORN_TIMEOUT_KEEP_ALIVE` (2-5s) behind load balancers
- **Logging**: Use `UVICORN_LOG_LEVEL=warning` in production to reduce log volume
- **Memory**: Monitor memory usage with multiple workers

## Troubleshooting Async/Sync Issues

If you encounter async/sync compatibility issues, follow this diagnostic guide:

### 1. Identify the Problem

**Common Error Messages:**
```
SynchronousOnlyOperation: You cannot call this from an async context
RuntimeError: There is no current event loop
SyntaxError: 'await' outside async function
```

**Diagnostic Commands:**
```bash
# Check for asyncio.run in request paths (should only be in startup)
grep -r "asyncio\.run" fleet-manager-backend/core/views.py

# Check for await outside async functions
grep -r "^\s*await" fleet-manager-backend/core/views.py

# Check for boto3 in async views
grep -r "boto3\." fleet-manager-backend/core/views.py
```

### 2. Fix Options

**Option A: Convert to Async (Recommended)**
```python
# Before (sync)
def my_view(request):
    result = some_sync_function()
    return Response(result)

# After (async)
async def my_view(request):
    result = await sync_to_async(some_sync_function)()
    return Response(result)
```

**Option B: Keep Sync (If async not needed)**
```python
# Ensure no await calls in sync functions
def my_view(request):
    result = some_sync_function()  # No await here
    return Response(result)
```

**Option C: Use sync_to_async Wrapper**
```python
from asgiref.sync import sync_to_async

async def my_view(request):
    # Wrap sync Django ORM calls
    user = await sync_to_async(User.objects.get)(id=1)
    return Response({"user": user.email})
```

### 3. Common Patterns

**Django ORM in Async Views:**
```python
#  Correct
async def my_view(request):
    users = await sync_to_async(list)(User.objects.all())
    return Response(users)

#  Incorrect
async def my_view(request):
    users = User.objects.all()  # Will raise SynchronousOnlyOperation
    return Response(users)
```

**HTTP Requests in Async Views:**
```python
#  Correct (use httpx)
import httpx

async def my_view(request):
    async with httpx.AsyncClient() as client:
        response = await client.get("https://api.example.com")
    return Response(response.json())

#  Incorrect (requests is sync)
import requests

async def my_view(request):
    response = requests.get("https://api.example.com")  # Blocks event loop
    return Response(response.json())
```

**S3 Operations in Async Views:**
```python
#  Correct (use aioboto3)
import aioboto3

async def my_view(request):
    session = aioboto3.Session()
    async with session.client('s3') as s3:
        response = await s3.get_object(Bucket='my-bucket', Key='file.txt')
    return Response(response)

#  Incorrect (boto3 is sync)
import boto3

async def my_view(request):
    s3 = boto3.client('s3')  # Blocks event loop
    response = s3.get_object(Bucket='my-bucket', Key='file.txt')
    return Response(response)
```

### 4. Testing Async Compatibility

```bash
# Test with curl
curl -X POST "http://localhost:8000/api/endpoint" \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'

# Check logs for async errors
docker logs fleet-manager-backend | grep -i "synchronous\|async\|await"
```

### 5. Migration Checklist

When converting views to async:

- [ ] Change `def` to `async def`
- [ ] Wrap Django ORM calls with `sync_to_async()`
- [ ] Replace `requests` with `httpx`
- [ ] Replace `boto3` with `aioboto3`
- [ ] Ensure all `await` calls are in async functions
- [ ] Test with multiple concurrent requests
- [ ] Monitor memory usage and performance

## ASGI vs WSGI

### Why ASGI?

- **Async Support**: Native async/await support for better concurrency
- **WebSocket Support**: Built-in WebSocket handling
- **Better Performance**: More efficient for I/O-bound operations
- **Future-Proof**: Django's recommended approach for modern applications

### Migration Benefits

- **Improved Throughput**: Better handling of concurrent requests
- **Resource Efficiency**: Lower memory usage per request
- **Scalability**: Better performance under load
- **Modern Patterns**: Support for async libraries (httpx, aioboto3)

## Production Considerations

### Load Balancer Configuration

When using ASGI behind a load balancer:

```nginx
# Nginx configuration
upstream fleet_manager {
    server 127.0.0.1:8000;
    server 127.0.0.1:8001;
    server 127.0.0.1:8002;
    server 127.0.0.1:8003;
}

server {
    listen 80;
    server_name api.example.com;
    
    location / {
        proxy_pass http://fleet_manager;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # ASGI-specific settings
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}
```

### Monitoring

Monitor ASGI performance with:

```bash
# Check worker processes
ps aux | grep uvicorn

# Monitor memory usage
docker stats fleet-manager-backend

# Check async compatibility
docker logs fleet-manager-backend | grep -E "(async|await|sync)"
```

### Health Checks

ASGI health check endpoint:

```python
# In Django views
async def health_check(request):
    return JsonResponse({
        "status": "healthy",
        "server": "asgi",
        "workers": os.environ.get("UVICORN_WORKERS", 1)
    })
```

## Development vs Production

### Development
- Single worker process
- Auto-reload enabled
- Debug logging
- Development server fallback

### Production
- Multiple worker processes
- Auto-reload disabled
- Optimized logging
- ASGI server required

## Troubleshooting Common Issues

### Issue: "SynchronousOnlyOperation" Error

**Cause**: Calling Django ORM from async context without proper wrapping.

**Solution**:
```python
# Wrap ORM calls
from asgiref.sync import sync_to_async

async def my_view(request):
    users = await sync_to_async(list)(User.objects.all())
    return Response(users)
```

### Issue: Memory Leaks

**Cause**: Not properly closing async resources.

**Solution**:
```python
# Use context managers
async def my_view(request):
    async with httpx.AsyncClient() as client:
        response = await client.get("https://api.example.com")
    return Response(response.json())
```

### Issue: Slow Performance

**Cause**: Blocking operations in async views.

**Solution**:
- Replace `requests` with `httpx`
- Replace `boto3` with `aioboto3`
- Use `sync_to_async` for Django ORM calls
- Avoid blocking I/O operations
