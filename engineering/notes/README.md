# Fleet Manager Documentation

This directory contains comprehensive documentation for the Fleet Manager platform.

## Core Documentation

### [Kind control-plane Helm](KIND_FLEET_MANAGER_HELM.md)
Install `charts/fleet-manager` on the local kind cluster (`setup-dev-fleet.sh`) with local control-plane images, local OCI charts, and in-cluster Postgres/Redis/MinIO/Temporal/Kong — mimics the customer chart contract without GitOps/ESO.

### [ASGI Configuration](asgi-configuration.md)
Complete guide for production deployment with Uvicorn ASGI server:
- Environment variables and configuration
- Performance tuning and optimization
- Troubleshooting async/sync compatibility issues
- Migration patterns and best practices
- Production considerations and monitoring

### [Secrets Management](secrets-management.md)
HashiCorp Vault integration for secure credential storage:
- Vault configuration and setup
- Encrypted fields for sensitive data
- Kubeconfig management through secrets manager
- Security best practices

## Additional Resources

### [Envoy Gateway API migration](GATEWAY_API_ENVOY_MIGRATION.md)
Migration and operations guide for replacing Kafka workload `ingress-nginx`
with Envoy Gateway:

- Strimzi and CFK Gateway, TLSRoute, TCPRoute, and HTTPRoute configuration
- Verified local proof of concept and Kafka produce/consume checks
- TLS passthrough/termination behavior, observability, cutover, and rollback

### [AWS IRSA Provisioning APIs](AWS_IRSA_PROVISIONING_APIS.md)
API contracts and workflow behavior for AWS IRSA-backed object storage and node pool provisioning:
- Dispatch endpoints for `ProvisionObjectStorageWorkflow` and `ProvisionNodePoolWorkflow`
- Request/response payloads and command tracking patterns
- Required AWS IAM permissions and runtime expectations

### [Integration Tests](https://github.com/streamtime-ai/fleet-manager/blob/main/integration-tests/README.md)
Comprehensive smoke test suite for end-to-end validation:
- Multi-realm authentication testing
- Cross-tenant security verification
- Complete CRUD operations testing
- Temporal workflow dispatch verification

### [AI Assistant Instructions](https://github.com/streamtime-ai/fleet-manager/blob/main/AGENTS.md)
Complete guide for AI assistants working with Fleet Manager:
- Architecture and conventions
- Technology stack overview
- Code patterns and best practices
- Development playbooks

## Quick Reference

### Development Setup
```bash
# Start the stack
docker compose up -d

# Run smoke tests
docker compose exec integration-tests python test_smoke_suite.py
```

### Production Deployment
```bash
# Set production environment variables
export UVICORN_WORKERS=4
export UVICORN_RELOAD=false
export UVICORN_LOG_LEVEL=info

# Deploy with production Dockerfile
docker compose -f docker-compose.prod.yml up -d
```

### Troubleshooting
- **Async Issues**: See [ASGI Configuration](asgi-configuration.md#troubleshooting-async-sync-issues)
- **Secrets**: See [Secrets Management](secrets-management.md)
- **Testing**: See [Integration Tests](https://github.com/streamtime-ai/fleet-manager/blob/main/integration-tests/README.md)

## Contributing

When adding new documentation:
1. Create new `.md` files in this directory
2. Update this index with links and descriptions
3. Add references from relevant README files
4. Follow the documentation standards in [AGENTS.md](https://github.com/streamtime-ai/fleet-manager/blob/main/AGENTS.md)
