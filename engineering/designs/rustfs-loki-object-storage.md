# RustFS for Loki object storage

## Objective

Replace the Grafana Loki chart’s bundled MinIO (Quay images no longer pull anonymously) with RustFS: S3-compatible object storage we control, using standalone single-PVC for development and distributed HA for production.

## In scope

- Official RustFS Helm chart as a fleet bootstrap component (install before Loki)
- `development` / `non-prod`: standalone (1 pod, 1 data PVC)
- `production`: distributed HA (`replicaCount: 4`, `drivesPerNode: 1`)
- Wire Loki to RustFS S3 when fleet has **no** cloud `logs_storage`
- Skip RustFS install when cloud `logs_storage` is present (existing AWS/GCP/Azure/OCI/DO path unchanged)
- Disable Loki `minio.enabled` in package presets
- Post-install Job to create Loki buckets (`chunks`, `ruler`, `admin`)
- Package rule + helm preload for chart discovery/sync

## Out of scope

- RustFS for WarpStream, Kafka tiered storage, or Flink (future shared object store)
- Migrating existing fleets’ MinIO data into RustFS
- RustFS Operator / multi-tenant CRDs
- Exposing RustFS console via Ingress (in-cluster only)

## Approach

1. Add `rustfs` to `_COMPONENT_REGISTRY_MAP` (`install_order` 49, namespace `monitoring`, release/fullname `rustfs`).
2. Preload `helm_repos/helm__charts_rustfs_com__rustfs.json` with environment templates; add `package_rules.yaml` entry (chart `1.0.0`).
3. In `BootstrapResolverService`: if `metadata.logs_storage` → cloud Loki path, `rustfs.install=false`; else generate credentials, inject into RustFS + Loki S3 values (`s3ForcePathStyle`, HTTP endpoint `rustfs-svc.monitoring.svc.cluster.local:9000`), `minio.enabled=false`.
4. RustFS `extraManifests` Job (helm hook) creates buckets with an S3 client against that endpoint.
5. Tests for skip-on-cloud and apply-rustfs-to-loki.

## Deviations

- **2026-09-24 — Bootstrap UI + schema.** Added `rustfs` to `BootstrapConfigSchema` and frontend `BOOTSTRAP_COMPONENTS` so it appears in the fleet bootstrap components editor (was registry-only before).
- **2026-09-25 — Default StorageClass.** Presets set `storageclass.name` to `""` so PVCs omit `storageClassName` and use the cluster default (kind `standard`, cloud default GP*). Replaces hardcoded `local-path` / `gp3`.
- **2026-09-25 — Explicit SC injection.** Empty `storageclass.name` makes the RustFS chart omit `storageClassName`. That works on first create, but a later helm upgrade against a Bound PVC (e.g. `standard`) tries to patch the field to null and fails (immutable). `ByokProvider` now injects the concrete default StorageClass name from `ResolveDefaultStorageClassWorkflow` into bootstrap values before install/upgrade.
- **2026-09-25 — Fleet-stable RustFS credentials.** Credentials are persisted on `fleet.metadata.rustfs_object_storage` and reused across `compute-components` calls. A Loki- or RustFS-only component UPDATE also expands to the coupled pair so both releases stay on the same keys.
- **2026-09-25 — Mirror bucket-init image.** The post-install Job image is `bucketInitJob.image.*` (default official `rustfs/rc`), listed in `preload/registry_images.yaml`, and rendered into `extraManifests` only after `apply_image_registry_overrides` so private-registry fleets pull via the mirror. (Earlier draft used `bitnamilegacy/minio-client`; switched to first-party `rc`.)
