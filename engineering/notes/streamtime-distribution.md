# Streamtime Distribution

This document describes the bundled Streamtime distribution - a single container that contains all Streamtime services for easy deployment and evaluation.

## Overview

The Streamtime distribution is a **single-container deployment** that bundles the control plane:
- **Backend** (Django + Uvicorn, SQLite)
- **Gateway** (Kong API Gateway)
- **Frontend** (React production build + Nginx)
- **Temporal Server** (embedded SQLite workflow store)
- **Temporal Worker** (workflow execution)

**MCP** runs in-process on the backend ASGI app (no separate process).

**Not included** (same as `docker-compose-public.yaml` where applicable): **Grafana**, **Loki**, per-fleet **Streamtime Agent** (deploy to target clusters), local Keycloak, Prometheus/Tempo, Postgres.

All services run in a single container managed by systemd, using `After`/`Wants` ordering and readiness waits to mirror compose healthchecks.

## Architecture

### Base Image
- **Base**: `kong:latest` (Debian-based)
- **Process Manager**: systemd (PID 1)
- **File System**: All services share the same filesystem
- **Network**: All services run on localhost within the container

### Service Management

Each service is managed by systemd with its own unit file:
- `fleet-manager-backend/`: Backend service and env (includes in-process MCP at `/organizations/{org}/mcp/`)
- `fleet-manager-gateway/`: Kong Gateway
- `fleet-manager-frontend/`: Frontend
- `fleet-manager-orchestrator/`: Temporal server and worker
- `monitoring/`: readiness helpers (`bundled-wait.sh`)

### Directory Structure

```
/app/
├── backend/              # Django backend (+ in-process MCP)
├── orchestrator/         # Temporal worker
├── backend.env.sh       # Backend environment variables
├── gateway.env.sh        # Kong environment variables
├── frontend.env.sh       # Frontend environment variables
├── temporal-server.env.sh # Temporal server environment variables
├── temporal-worker.env.sh # Temporal worker environment variables

/etc/systemd/system/
├── backend.service
├── gateway.service
├── frontend.service
├── temporal-server.service
└── temporal-worker.service
```

## Building the Image

### Prerequisites
- Docker with buildx support (for multi-arch builds)
- At least 16GB RAM for building
- 10GB free disk space

### Build Command

```bash
docker compose -f streamtime-distribution.yaml build
```

### Build Options

#### Clean Build (No Cache)
```bash
docker compose -f streamtime-distribution.yaml build --no-cache
```

#### Multi-arch Build
```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -f Dockerfile.bundled \
  -t streamtime:latest \
  --push .
```

### Build Process

1. **Base Setup** (Kong + dependencies)
   - Installs systemd, Python, Nginx, Node.js
   - Sets up UV for Python package management

2. **Install Services**
   - Temporal CLI

3. **Install Dependencies**
   - Backend Python packages (Django, Uvicorn, FastMCP, etc.)
   - Orchestrator Python packages
   - Frontend dependencies (npm packages)

4. **Copy Service Files**
   - Application code
   - Environment scripts
   - Systemd unit files
   - Configuration files (Kong)

5. **Build Frontend**
   - Run `npm install` and `npm run build`
   - Copy to `/var/www/html` for Nginx serving

6. **Finalize**
   - Create data directories
   - Enable systemd services
   - Set up environment variables

## Running the Distribution

### Start

```bash
docker compose -f streamtime-distribution.yaml up -d
```

Startup order (enforced by systemd + `/app/bundled-wait.sh`):

1. Backend (runs migrations via `/app/start`, then Uvicorn — includes MCP)
2. Temporal server (waits for backend `/health/`)
3. Temporal worker (waits for Temporal gRPC `:7233`)
4. Kong gateway (waits for backend `/health/`)
5. Frontend (waits for Kong `/api/health/`)

### Deploy Streamtime Agent (separate)

Fleet operations require the agent on each target cluster. Run it outside this image, e.g.:

```bash
STREAMTIME_ORCHESTRATOR_AGENT_API_KEY=dev-agent-key docker compose up streamtime-agent
```

The agent connects to Temporal through Kong with API key authentication.

### Check Service Status

```bash
docker exec streamtime systemctl list-units --type=service --state=running
```

### View Service Logs

```bash
# View all logs
docker exec streamtime journalctl

# View specific service logs
docker exec streamtime journalctl -u backend.service
docker exec streamtime journalctl -u temporal-server.service
```

### Restart Specific Service

```bash
docker exec streamtime systemctl restart backend.service
```

### Stop All Services

```bash
docker compose -f streamtime-distribution.yaml down
```

## Service Configuration

### Environment Variables

Each service has its own environment script in `/app/*.env.sh`. These scripts export environment variables that are sourced by the systemd unit files.

#### Backend (`backend.env.sh`)
```bash
export DATABASE=embedded
export EMBEDDED_DB_PATH=/data/backend
export UVICORN_HOST=0.0.0.0
export UVICORN_PORT=7999
# ... (see file for full list)
```

#### Gateway (`gateway.env.sh`)
```bash
export KONG_DATABASE=off
export KONG_DECLARATIVE_CONFIG=/etc/kong/kong.yml
export KONG_LOG_LEVEL=info
# ... (see file for full list)
```

#### Temporal Server (`temporal-server.env.sh`)
```bash
export TEMPORAL_ADDRESS=localhost:7233
export TEMPORAL_CLI_ADDRESS=localhost:7233
# ... (see file for full list)
```

### Systemd Unit Files

Each service has a systemd unit file that defines:
- Service dependencies (After/Requires)
- ExecStart command
- Restart policy
- Logging configuration

Example: `backend.service`
```ini
[Unit]
Description=Streamtime Backend
After=network.target
Requires=network.target

[Service]
Type=simple
WorkingDirectory=/app/backend
ExecStart=/bin/bash -c "source /app/backend.env.sh && exec /app/start"
Restart=always
RestartSec=5
```

Readiness waits (e.g. gateway waits for `http://localhost:7999/health/`) live in `monitoring/bundled-wait.sh` and mirror docker compose `healthcheck` / `depends_on` behaviour.

## Exposed Ports

All services are directly accessible on the host machine via `localhost`.

| Service | Internal Port | Host Port | Purpose |
|---------|---------------|-----------|---------|
| Backend | 7999 | 7999 | Django API |
| Kong Proxy (HTTPS) | 8443 | 8443 | Console and API — open https://localhost:8443 |
| Kong Proxy (HTTP) | 8000 | 8000 | API Gateway |
| Kong Admin | 8001 | 8001 | Admin API |
| Kong Admin GUI | 8002 | 8002 | Admin UI |
| Frontend | 3000 | 3000 | React App (Nginx, plain HTTP; Kong serves it on 8443) |
| Temporal gRPC | 7233 | 7233 | Workflow API |
| Temporal UI | 8233 | 8233 | Temporal Dashboard |
| Temporal Worker | 9100 | 9100 | Metrics |
| MCP (via backend) | — | — | AI tools at `/organizations/{org}/mcp/` on the API port |

## Data Persistence

All data is stored in the Docker volume `streamtime-data`:
- Backend database: `/data/backend/` (SQLite)
- Temporal database: `/data/temporal/` (SQLite)

Container environment variables from `streamtime-distribution.yaml` override defaults in `backend.env.sh` and `gateway.env.sh` via `/proc/1/environ` (same pattern as the temporal worker).

## Conventions

### Service Configuration Pattern

Each service follows this pattern:

1. **Environment Script** (`*.env.sh`)
   - Located in `/app/`
   - Contains all environment variables
   - Uses `export` for all variables
   - Source before running the service

2. **Systemd Unit** (`*.service`)
   - Located in `/etc/systemd/system/`
   - Sources environment script in ExecStart
   - Uses `Type=simple`
   - Always includes `Restart=always`
   - Outputs to journal

3. **Dependencies**
   - `After=network.target` on all services
   - `Wants=` for soft ordering (service still starts if optional dep is slow)
   - `Requires=` only for hard dependencies (e.g. worker → temporal server)
   - `bundled-wait.sh` ExecStartPre hooks for HTTP/TCP readiness

### File Naming

- Environment scripts: `<service>.env.sh`
- Systemd units: `<service>.service`
- Configuration files: service-specific naming

### Port Assignment

- Frontend: 3000
- Backend: 7999
- Kong: 8000-8002
- Temporal: 7233, 8233, 9000
- MCP / assistant: served via backend API (no separate port)

## Troubleshooting

### Service Won't Start

Check logs:
```bash
docker exec streamtime journalctl -u <service>.service --no-pager
```

### Database Issues

Check if data directory exists:
```bash
docker exec streamtime ls -la /data/
```

### Port Conflicts

Check what's listening:
```bash
docker exec streamtime netstat -tuln | grep <port>
```

### Rebuild Cleanly

```bash
docker compose -f streamtime-distribution.yaml down
docker compose -f streamtime-distribution.yaml build --no-cache
docker compose -f streamtime-distribution.yaml up -d
```

## Tagging Convention

### Version Tagging

```bash
# Build with tag
docker buildx build -f Dockerfile.bundled -t streamtime:latest .

# Tag for registry
docker tag streamtime:latest ghcr.io/platformatory/streamtime:latest
docker tag streamtime:latest ghcr.io/platformatory/streamtime:v1.0.0

# Push to registry
docker push ghcr.io/platformatory/streamtime:latest
docker push ghcr.io/platformatory/streamtime:v1.0.0
```

### Tag Format

- `latest`: Most recent build
- `v<major>.<minor>.<patch>`: Semantic versioning
- `v<major>.<minor>.<patch>-<build>`: With build number

Example:
```bash
docker tag streamtime:latest ghcr.io/platformatory/streamtime:v1.0.0
docker tag streamtime:latest ghcr.io/platformatory/streamtime:v1.0.0-build.123
```

## Building for Production

### Multi-Arch Build

```bash
# Create buildx builder
docker buildx create --name multiarch --use

# Build for multiple architectures
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -f Dockerfile.bundled \
  -t ghcr.io/platformatory/streamtime:latest \
  --push .
```

### Size Optimization

Current image size: ~3.5GB

To reduce size:
1. Use multi-stage builds for frontend
2. Clean npm cache after build
3. Remove build dependencies
4. Use Alpine base image

## Development Workflow

### Making Changes

1. Edit service files (code, config, env scripts)
2. Rebuild: `docker compose -f streamtime-distribution.yaml build`
3. Restart: `docker compose -f streamtime-distribution.yaml restart streamtime`

### Testing Locally

```bash
# Build
docker compose -f streamtime-distribution.yaml build

# Start
docker compose -f streamtime-distribution.yaml up

# Access services
curl -k https://localhost:8443      # Console (through Kong, with the stored certificate)
curl http://localhost:3000          # Frontend (Nginx directly)
curl http://localhost:7999/health/  # Backend (direct)
curl http://localhost:8000/api/health/  # Backend via Kong
curl http://localhost:8233          # Temporal UI
```

## Security Considerations

- **Superuser Emails**: Configured in `backend.env.sh` as `SUPER_USER_EMAILS`
- **Secrets**: All secrets are in environment scripts (use Vault in production)
- **Authentication**: Handled by Kong Gateway (OAuth/OIDC)
- **Network**: All services run on localhost within container

## Performance

- **Memory**: ~2-3GB RAM usage
- **CPU**: Minimal when idle, scales with load
- **Startup**: ~30-60 seconds for all services
- **Storage**: ~3.5GB image size

## Limitations

1. **Single Container**: All services in one process namespace
2. **Development**: Not for production workloads
3. **Scaling**: Cannot scale individual services
4. **Updates**: Requires full image rebuild

## File Organization

Service configuration files are organized by component:

### Backend (`fleet-manager-backend/`)
- `backend.service` - Systemd unit file
- `backend.env.sh` - Environment variables

### Gateway (`fleet-manager-gateway/`)
- `gateway.service` - Systemd unit file
- `gateway.env.sh` - Environment variables
- `kong.singlenode.yaml` - Kong declarative configuration

### Frontend (`fleet-manager-frontend/`)
- `frontend.service` - Systemd unit file
- `frontend.env.sh` - Environment variables

### Orchestrator (`fleet-manager-orchestrator/`)
- `temporal-server.service` - Temporal server systemd unit
- `temporal-server.env.sh` - Temporal server environment
- `temporal-worker.service` - Temporal worker systemd unit
- `temporal-worker.env.sh` - Temporal worker environment

### MCP Server (in-process on backend)
- Mounted at `/organizations/{org_id}/mcp/` on the Django ASGI app
- No separate systemd unit; Kong routes MCP and assistant traffic to the backend

### Monitoring (`monitoring/`)
- `bundled-wait.sh` - HTTP/TCP readiness helpers for systemd

## Parity with docker-compose-public

| Component | Bundled (systemd) | docker-compose-public |
|-----------|-------------------|------------------------|
| SQLite backend | yes | yes |
| SQLite Temporal | yes | yes |
| Kong singlenode routing (`/api` prefix) | yes | yes |
| Loki | no | yes |
| Grafana | no | yes |
| MCP | yes | yes |
| External OIDC (Auth0) | yes | yes |
| Local Keycloak | no | no |
| Prometheus / Tempo | no | no (commented out) |
| Per-fleet agent | deploy separately | deploy separately |

## Future Enhancements

- Add Prometheus for control-plane metrics
- Optional external PostgreSQL for production single-node
- Production-optimized image variant

## See Also

- [Backend API Documentation](https://github.com/streamtime-ai/fleet-manager/blob/main/fleet-manager-backend/README.md)
- [Frontend Development Guide](https://github.com/streamtime-ai/fleet-manager/blob/main/fleet-manager-frontend/README.md)
- [Kong Gateway Configuration](https://github.com/streamtime-ai/fleet-manager/blob/main/fleet-manager-gateway/README.md)
- [Temporal Workflows](https://github.com/streamtime-ai/fleet-manager/blob/main/fleet-manager-orchestrator/README.md)

