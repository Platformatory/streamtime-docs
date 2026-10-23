---
title: Notes
nav_exclude: true
search_exclude: true
---

Engineering notes, moved from `fleet-manager/docs/`.

| Document | |
|---|---|
| [Issue #1217 — Strimzi CRDs not upgraded on operator version change](./1217-strimzi-crd-upgrade-plan.md) | 1217-strimzi-crd-upgrade-plan |
| [Agents](./AGENTS.md) | AGENTS |
| [Agent Command Tracking](./AGENT_COMMAND_TRACKING.md) | AGENT_COMMAND_TRACKING |
| [Agent Management Page - Complete Implementation](./AGENT_MANAGEMENT_PAGE.md) | AGENT_MANAGEMENT_PAGE |
| [Agent Status and UI Implementation Guide](./AGENT_STATUS_AND_UI_IMPLEMENTATION.md) | AGENT_STATUS_AND_UI_IMPLEMENTATION |
| [Kafka Replicator API Testing - cURL Commands](./API_TESTING_REPLICATOR.md) | API_TESTING_REPLICATOR |
| [Workload Identity Provisioning APIs (AWS IRSA / OCI Workload Identity)](./AWS_IRSA_PROVISIONING_APIS.md) | AWS_IRSA_PROVISIONING_APIS |
| [Building and Deploying Streamtime Agent and Helm Chart](./BUILDING_AND_DEPLOYING.md) | BUILDING_AND_DEPLOYING |
| [BYOK Agent Installation Flow - Complete Implementation](./BYOK_AGENT_INSTALLATION_FLOW.md) | BYOK_AGENT_INSTALLATION_FLOW |
| [BYOK Bootstrap Rationalization Implementation](./BYOK_BOOTSTRAP_IMPLEMENTATION.md) | BYOK_BOOTSTRAP_IMPLEMENTATION |
| [BYOK Bootstrap & Agent Connection - Smoke Tests](./BYOK_BOOTSTRAP_SMOKE_TESTS.md) | BYOK_BOOTSTRAP_SMOKE_TESTS |
| [BYO Observability — End-to-End Flow](./BYO_OBSERVABILITY_FLOW.md) | BYO_OBSERVABILITY_FLOW |
| [Envoy Gateway API migration for Kafka workloads](./GATEWAY_API_ENVOY_MIGRATION.md) | GATEWAY_API_ENVOY_MIGRATION |
| [Kafka UI Single Sign-On (SSO) Guide](./KAFKA_UI_SSO.md) | KAFKA_UI_SSO |
| [Deploy fleet-manager Helm on local kind (customer-like)](./KIND_FLEET_MANAGER_HELM.md) | KIND_FLEET_MANAGER_HELM |
| [Package Catalog Management](./PACKAGE_CATALOG.md) | PACKAGE_CATALOG |
| [Package Catalog API Examples](./PACKAGE_CATALOG_EXAMPLES.md) | PACKAGE_CATALOG_EXAMPLES |
| [Package Catalog Quick Start](./PACKAGE_CATALOG_QUICKSTART.md) | PACKAGE_CATALOG_QUICKSTART |
| [Plan: Agent Health Check and Discovery Features](./PLAN_AGENT_HEALTH_AND_DISCOVERY.md) | PLAN_AGENT_HEALTH_AND_DISCOVERY |
| [Plan: Certificate Renewal During Maintenance Window](./PLAN_CERT_RENEWAL_MAINTENANCE_WINDOWS.md) | PLAN_CERT_RENEWAL_MAINTENANCE_WINDOWS |
| [Fleet Manager Documentation](./README.md) | README |
| [Registries_And_Helm](./REGISTRIES_AND_HELM.md) | REGISTRIES_AND_HELM |
| [Kafka Replicator API Test Results](./REPLICATOR_API_TEST_RESULTS.md) | REPLICATOR_API_TEST_RESULTS |
| [Streamtime Agent Documentation Index](./STREAMTIME_AGENT_INDEX.md) | STREAMTIME_AGENT_INDEX |
| [Streamtime Agent Troubleshooting Guide](./STREAMTIME_AGENT_TROUBLESHOOTING.md) | STREAMTIME_AGENT_TROUBLESHOOTING |
| [Streamtime Agent Update Workflow Documentation](./STREAMTIME_AGENT_UPDATE_WORKFLOW.md) | STREAMTIME_AGENT_UPDATE_WORKFLOW |
| [Streamtime Info](./STREAMTIME_INFO.md) | STREAMTIME_INFO |
| [Agent Commands Testing Plan - Step by Step](./TESTING_AGENT_COMMANDS.md) | TESTING_AGENT_COMMANDS |
| [Testing Streamtime Agent Features](./TESTING_STREAMTIME_AGENT_FEATURES.md) | TESTING_STREAMTIME_AGENT_FEATURES |
| [Workflow vs Deploy Script Comparison](./WORKFLOW_VS_DEPLOY_SCRIPT_COMPARISON.md) | WORKFLOW_VS_DEPLOY_SCRIPT_COMPARISON |
| [Agent Tasks API Testing](./agent-tasks-api-testing.md) | agent-tasks-api-testing |
| [ASGI Server Configuration](./asgi-configuration.md) | asgi-configuration |
| [DNS / TLS provider smoke checklist](./dns-tls-provider-smoke.md) | dns-tls-provider-smoke |
| [Fleet Selection Strategy Design](./fleet-selection-strategy-design.md) | fleet-selection-strategy-design |
| [Fleet Manager Secrets Management System](./secrets-management.md) | secrets-management |
| [Streamtime Distribution](./streamtime-distribution.md) | streamtime-distribution |

### Flink

| [Technical Design: Flink Development-to-Deployment Lifecycle, VCS-Driven Builds & Multi-Runtime Support](./flink/dev-to-deployment-lifecycle-technical-design.md) | dev-to-deployment-lifecycle-technical-design |
| [Flink projects](./flink/flink-projects.md) | flink-projects |
| [Technical Design: Flink Metrics Monitoring Gaps](./flink/metrics-monitoring-gaps-technical-design.md) | metrics-monitoring-gaps-technical-design |
| [Flink Feature Roadmap — Prioritized Technical Designs](./flink/roadmap.md) | roadmap |
| [Flink Units & Flink Cluster UX — Design Discussion](./flink/units-and-cluster-ux.md) | units-and-cluster-ux |
| [Technical Design: Flink Units & Flink Cluster/Job Provisioning](./flink/units-technical-design.md) | units-technical-design |

### For-Frontend

| [Blocked Files Security Configuration](./for-frontend/BLOCKED_FILES.md) | BLOCKED_FILES |
| [Feature Flags System Guide](./for-frontend/FEATURE_FLAGS_GUIDE.md) | FEATURE_FLAGS_GUIDE |

### Plans

| [Built-in Django OIDC](./plans/builtin-django-oidc.md) | builtin-django-oidc |
| [DigitalOcean bootstrap provider](./plans/digitalocean-bootstrap-provider.md) | digitalocean-bootstrap-provider |

### Rca

| [RCA: Fleet CREATE causes permanent Kong→Django connection hang](./rca/2026-04-10-fleet-create-double-validation-hang.md) | 2026-04-10-fleet-create-double-validation-hang |
| [RCA: Kong retry storm exhausts backend thread pool](./rca/2026-04-30-kong-retry-storm-thread-pool-exhaustion.md) | 2026-04-30-kong-retry-storm-thread-pool-exhaustion |
| [RCA: Cruise Control never rebalances — undersized hardcoded `brokerCapacity`](./rca/2026-08-06-cruise-control-broker-capacity-ceiling.md) | 2026-08-06-cruise-control-broker-capacity-ceiling |

### Runbooks

| [BYOVM Grafana dashboards show "No data"](./runbooks/byovm-grafana-no-data.md) | byovm-grafana-no-data |
| [Certificate renewal windows (existing fleets)](./runbooks/certificate-renewal-windows.md) | certificate-renewal-windows |
| [Fleet alert rules migration (existing fleets)](./runbooks/fleet-alert-rules-migration.md) | fleet-alert-rules-migration |
| [Migrate Kafka clusters to fleet-only alert delivery (#1521)](./runbooks/migrate-kafka-alerting.md) | migrate-kafka-alerting |
