# Workload Identity Provisioning APIs (AWS IRSA / OCI Workload Identity)

This document covers the Fleet Manager APIs used to trigger workload-identity-based provisioning for:

- object storage (S3 bucket + IAM policy attachment)
- node pools (EKS managed node group)

It also documents how to fetch execution status and results.

## Scope and flow

These APIs dispatch workflows to the fleet agent queue:

- `ProvisionObjectStorageWorkflow`
- `ProvisionNodePoolWorkflow`
- `ScaleNodePoolWorkflow`

At runtime, the agent:

1. validates workload identity (`ValidateWorkloadIdentityWorkflow`)
2. detects provider/region from cluster environment
3. performs cloud API calls using IRSA credentials (no static AWS keys in request payload)

## Endpoint

Use the generic agent workflow dispatch endpoint:

- `POST /organizations/{org_identifier}/fleet/{fleet_id}/agent/{workflow_type}/`

For this doc:

- `{workflow_type}` = `ProvisionObjectStorageWorkflow`, `ProvisionNodePoolWorkflow`, or `ScaleNodePoolWorkflow`

## Authentication

Use a standard org bearer token (same as other backend APIs):

```bash
TOKEN=$(./scripts/get-root-token.sh -q)
```

## API 1: Provision object storage (AWS IRSA)

### Request

`POST /organizations/root/fleet/{fleet_id}/agent/ProvisionObjectStorageWorkflow/`

Request body fields:

- `bucket_name` (optional): defaults to `streamtime-{fleet_id}`
- `region` (optional): overrides auto-detected region
- `project_id`, `compartment_id`, `subscription_id`, `resource_group_name` are cross-cloud fields and not needed for AWS

Example:

```bash
curl -sk -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "bucket_name": "streamtime-my-fleet-logs",
    "region": "us-west-2"
  }' \
  https://api.streamtime.local:8443/organizations/root/fleet/my-fleet/agent/ProvisionObjectStorageWorkflow/
```

### Immediate response (dispatch)

Returns dispatch metadata, not final cloud result:

```json
{
  "workflow_id": "/organizations/root/fleet/my-fleet/command/ProvisionObjectStorageWorkflow",
  "run_id": "9f4b8fbe-....",
  "status": "dispatched",
  "task_queue": "/organizations/root/fleet/my-fleet/agent-tasks",
  "fleet_task_queue": "/organizations/root/fleet/my-fleet/agent-tasks"
}
```

### Runtime behavior on AWS

The agent uses IRSA (`AWS_ROLE_ARN` + `AWS_WEB_IDENTITY_TOKEN_FILE`) and performs:

- `sts:GetCallerIdentity` for identity validation
- `s3:CreateBucket` (+ versioning enable)
- `iam:CreatePolicy` with S3 RW permissions for bucket and objects
- `iam:AttachRolePolicy` to the assumed IRSA role

## API 2: Provision node pool (AWS IRSA)

### Request

`POST /organizations/root/fleet/{fleet_id}/agent/ProvisionNodePoolWorkflow/`

Required fields:

- `node_pool_name`
- `instance_type`
- `node_count` (>=1)

Optional AWS overrides:

- `cluster_name`
- `node_role_arn`
- `subnet_ids`
- `region`
- `labels`

If omitted, cluster name/subnets/node role are auto-discovered from live cluster + EKS APIs.

Example:

```bash
curl -sk -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "node_pool_name": "kafka-workers-a",
    "instance_type": "m6i.large",
    "node_count": 3,
    "labels": {
      "streamtime.io/workload": "kafka"
    }
  }' \
  https://api.streamtime.local:8443/organizations/root/fleet/my-fleet/agent/ProvisionNodePoolWorkflow/
```

### Immediate response (dispatch)

Same response structure as object storage dispatch:

- `workflow_id`
- `run_id`
- `status=dispatched`
- task queue metadata

### What the agent discovers (AWS node pool)

| Field | Discovery order | How |
|---|---|---|
| `cluster_name` | 1. IMDS tag | `GET /latest/meta-data/tags/instance/aws:eks:cluster-name` — works when instance metadata tags are enabled on the node group |
| | 2. Node labels | Kubernetes `Nodes().List()` → reads `alpha.eksctl.io/cluster-name` or `eks.amazonaws.com/cluster-name` label |
| | 3. `aws-node` DaemonSet | Reads `CLUSTER_NAME` env var from the VPC CNI DaemonSet in `kube-system` — always present on EKS, requires no IAM permission |
| `subnet_ids` | EKS API | `eks:DescribeCluster` → `resourcesVpcConfig.subnetIds` |
| `node_role_arn` | EKS API | `eks:ListNodegroups` + `eks:DescribeNodegroup` on first existing nodegroup → `nodeRole` |

### Runtime behavior on AWS

The agent uses IRSA and performs:

- `sts:GetCallerIdentity` for identity validation
- auto-discovery: cluster name (three-path fallback), subnet IDs, node role ARN
- `eks:CreateNodegroup`
- polling until node group becomes `ACTIVE`
- non-fatal tainting pass via `TaintNodesByLabelWorkflow`

## Getting final status and outputs

The dispatch APIs return only workflow start metadata. Use command APIs to track completion and fetch results.

### List by run_id

```bash
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/?command_id=${RUN_ID}"
```

### List by workflow handler

```bash
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://api.streamtime.local:8443/organizations/root/commands/?command_handler=ProvisionNodePoolWorkflow&limit=20"
```

### Result shape (completed)

When completed, command records include workflow result payload (`result`) populated by command-audit updates. Typical fields include:

- object storage: `provider`, `bucket_name`, `bucket_id`, `region`, `iam_binding_id`, `identity`
- node pool: `provider`, `node_pool_name`, `node_pool_id`, `node_count`, `instance_type`

## AWS IAM permissions checklist

Minimum permissions expected by current implementation:

- identity validation:
  - `sts:GetCallerIdentity`
- object storage provisioning:
  - `s3:CreateBucket`
  - `s3:PutBucketVersioning`
  - `s3:ListBucket`
  - `s3:GetObject`
  - `s3:PutObject`
  - `s3:DeleteObject`
  - `s3:DeleteBucket` (for teardown workflows)
  - `iam:CreatePolicy`
  - `iam:AttachRolePolicy`
  - `iam:ListEntitiesForPolicy`
  - `iam:DetachRolePolicy`
  - `iam:DeletePolicy`
- node pool provisioning and scaling:
  - `eks:*` scoped to the specific cluster ARN: `arn:aws:eks:REGION:ACCOUNT_ID:cluster/CLUSTER_NAME`
  - `iam:PassRole` (for node role used by EKS node group)

  Using `eks:*` scoped to a cluster ARN rather than a per-action allowlist means you don't need to update the policy every time a new `eks:` action is added (e.g. `eks:UpdateNodegroupConfig` for scaling). Add the following statement to your IRSA role's trust/permission policy:

  ```json
  {
    "Effect": "Allow",
    "Action": "eks:*",
    "Resource": "arn:aws:eks:us-east-1:522814700700:cluster/streamtime-byok-demo"
  }
  ```

## API 3: Scale node pool (AWS IRSA)

### Request

`POST /organizations/root/fleet/{fleet_id}/agent/ScaleNodePoolWorkflow/`

**Required:**

- `node_pool_name`: name of the existing EKS managed node group
- `node_count`: desired node count after scaling (>= 0)

**Optional overrides:**

- `cluster_name`: override auto-discovered cluster name
- `region`: override auto-detected region

Example — scale `kafka-workers-a` to 5 nodes:

```bash
curl -sk -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "node_pool_name": "kafka-workers-a",
    "node_count": 5
  }' \
  https://api.streamtime.local:8443/organizations/root/fleet/vivacious-mosquito/agent/ScaleNodePoolWorkflow/
```

Scale down to 2:

```bash
  -d '{"node_pool_name": "kafka-workers-a", "node_count": 2}'
```

### Runtime behavior on AWS

The agent validates workload identity, then calls:

- `eks:UpdateNodegroupConfig` — sets `desiredSize`, `minSize`, and `maxSize` to `node_count`
- `eks:DescribeNodegroup` — polls until node group status is `ACTIVE` (20 min timeout)

The cluster name is auto-discovered from the `aws-node` DaemonSet `CLUSTER_NAME` env var (same three-path fallback as node pool provisioning). No additional IAM permission beyond `eks:*` on the cluster ARN is required.

### Response

Same dispatch structure as other workflows. When complete, the command record `result` contains:

```json
{
  "provider": "aws",
  "node_pool_name": "kafka-workers-a",
  "node_pool_id": "arn:aws:eks:us-east-1:522814700700:nodegroup/streamtime-byok-demo/kafka-workers-a/...",
  "node_count": 5
}
```

---

## Using the provisioned S3 bucket from Kafka pods (AWS)

The S3 bucket and IAM policy created by `ProvisionObjectStorageWorkflow` are designed to be consumed by Kafka workloads running in the same BYOK cluster via IRSA. No static credentials are needed — pods that use a service account annotated with the same IRSA role ARN get automatic S3 access via the projected web identity token.

### What was provisioned

After `ProvisionObjectStorageWorkflow` completes:

- An S3 bucket named `streamtime-{fleet_id}` (e.g. `streamtime-vivacious-mosquito`) with versioning enabled
- An IAM policy granting `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket` scoped to that bucket, attached to the IRSA role the agent runs under (e.g. `arn:aws:iam::522814700700:role/streamtime-agent-irsa`)

The same IRSA role can be annotated onto any service account in the cluster — those pods then inherit the bucket access automatically.

### Kafka Tiered Storage (Strimzi)

Strimzi supports S3-compatible tiered storage via the `kafka-tiered-storage-aws` plugin. Configure it in the `Kafka` CR:

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
  namespace: kafka
spec:
  kafka:
    tieredStorage:
      type: custom
      remoteStorageManager:
        className: io.strimzi.kafka.tieredstorage.RemoteStorageManager
        classpath: /opt/kafka/libs/tiered-storage/*
        config:
          storage.backend.class: io.strimzi.kafka.tieredstorage.storage.s3.S3StorageBackend
          storage.s3.bucket.name: streamtime-vivacious-mosquito
          storage.s3.region: us-east-1
          # No access key / secret key — IRSA provides credentials via the pod's
          # projected token at AWS_WEB_IDENTITY_TOKEN_FILE.
          storage.s3.credentials.provider.class: com.amazonaws.auth.WebIdentityTokenCredentialsProvider
    template:
      pod:
        serviceAccountName: strimzi-kafka-sa   # must be annotated with the IRSA role ARN
```

The Kafka broker pods must run under a service account that carries the IRSA annotation:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: strimzi-kafka-sa
  namespace: kafka
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::522814700700:role/streamtime-agent-irsa
```

EKS's pod identity webhook injects `AWS_ROLE_ARN` and `AWS_WEB_IDENTITY_TOKEN_FILE` into every pod that uses this service account. The AWS SDK picks them up automatically — no `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` needed.

### Confluent for Kubernetes (CFK)

CFK's `KafkaTopic` tiered storage and `ConfluentRolebinding` both support S3 via IAM roles. Configure the `KafkaRestClass` or the broker's `ConfigOverrides`:

```yaml
apiVersion: platform.confluent.io/v1beta1
kind: Kafka
metadata:
  name: kafka
  namespace: confluent
spec:
  podTemplate:
    serviceAccountName: confluent-sa    # annotated with IRSA role ARN
  configOverrides:
    server:
      - "confluent.tier.feature=true"
      - "confluent.tier.backend=S3"
      - "confluent.tier.s3.bucket=streamtime-vivacious-mosquito"
      - "confluent.tier.s3.region=us-east-1"
      # Credentials come from the pod's projected IRSA token automatically
      # when AWS_WEB_IDENTITY_TOKEN_FILE is set by the EKS pod identity webhook.
```

Service account annotation (same pattern as Strimzi):

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: confluent-sa
  namespace: confluent
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::522814700700:role/streamtime-agent-irsa
```

### Generic workload (StatefulSet / Deployment)

Any pod in the cluster can access the bucket by:

1. Creating a service account annotated with the IRSA role ARN
2. Referencing it in the pod spec
3. Using the AWS SDK (any language) — credentials are resolved automatically from the projected token

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kafka-connect
  namespace: kafka
spec:
  template:
    spec:
      serviceAccountName: strimzi-kafka-sa
      containers:
        - name: kafka-connect
          image: my-connect-image
          env:
            # These are injected automatically by EKS pod identity webhook;
            # shown here for clarity only — do NOT hard-code them.
            # AWS_ROLE_ARN: arn:aws:iam::522814700700:role/streamtime-agent-irsa
            # AWS_WEB_IDENTITY_TOKEN_FILE: /var/run/secrets/eks.amazonaws.com/serviceaccount/token
            - name: S3_BUCKET
              value: streamtime-vivacious-mosquito
            - name: AWS_REGION
              value: us-east-1
```

### Verifying bucket access from a pod

```bash
# Run a debug pod under the annotated SA
kubectl run s3-test --rm -it --restart=Never \
  --image=amazon/aws-cli \
  --serviceaccount=strimzi-kafka-sa \
  --namespace=kafka \
  -- s3 ls s3://streamtime-vivacious-mosquito/

# Expect: empty listing (or existing objects) with no credential errors.
# A 403/NoCredentialsError means the SA annotation is missing or wrong.
```

### IAM role ARN discovery

The IRSA role ARN used by the provisioning workflow (and that should be annotated on Kafka service accounts) can be found from the agent's own service account:

```bash
kubectl get sa streamtime-agent -n streamtime-agent \
  -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
# e.g.: arn:aws:iam::522814700700:role/streamtime-agent-irsa
```

### Next steps

- **Bucket per workload**: If you need separate buckets per Kafka cluster (isolation between tenants), dispatch `ProvisionObjectStorageWorkflow` with an explicit `bucket_name` per workload, then reference that name in the Kafka CR.
- **Cross-namespace access**: The IRSA role is cluster-scoped — any SA in any namespace can be annotated with the same role ARN. Use IAM policy conditions (`aws:RequestedRegion`, `sts:RoleSessionName`) to tighten access if needed.
- **Bucket lifecycle**: Use `DestroyObjectStorageWorkflow` (dispatched the same way) to empty and delete the bucket + detach the IAM policy when a fleet is torn down.
- **OCI equivalent**: On OKE, Kafka pods get bucket access automatically via the node's resource principal — no SA annotation needed. The same `KafkaTopic`/`ConfluentRolebinding` config applies but uses OCI Object Storage SDK config (`oci.bucket.name`, `oci.region`) instead of S3 config.

---

## Review notes (current behavior)

- API surface is workflow-dispatch oriented: synchronous cloud resource output is not returned directly from POST.
- Status/result retrieval is centralized in `/organizations/{org}/commands/`.
- AWS path is implemented end-to-end for object storage and node pools.
- Node pool auto-discovery is built in; explicit overrides are supported if environment metadata is incomplete.
- Node pool creation is idempotent for "already exists" retries (workflow continues by describing and waiting for `ACTIVE`).

---

# OCI Workload Identity Provisioning APIs

This section documents the same two workflows running on OCI (OKE) clusters using OCI Workload Identity. No OCI credentials are passed in the request — the agent running in the cluster acquires resource-principal credentials automatically via the OKE IMDS.

## How OCI Workload Identity works

The agent's K8s service account token is exchanged at the OKE IMDS (port 12250 at `kubernetes.default.svc`) for a short-lived Resource Principal Session Token (RPST). The OCI Go SDK handles this automatically via `auth.OkeWorkloadIdentityConfigurationProvider()`. No SA annotation is required on the agent pod (unlike AWS IRSA).

## Prerequisites — OCI side setup

Before `ProvisionObjectStorageWorkflow` or `ProvisionNodePoolWorkflow` will succeed, the following must be configured in OCI by an operator with tenancy-admin permissions.

### 1. OKE Enhanced cluster with Workload Identity enabled

OCI Workload Identity is only available on Enhanced clusters. When creating or updating the cluster:

```bash
# Enable WI via REST (oci CLI flag not exposed):
oci raw-request \
  --http-method PUT \
  --target-uri "https://containerengine.${REGION}.oraclecloud.com/20180222/clusters/${CLUSTER_OCID}" \
  --request-body '{"endpointConfig":{"subnetId":"<subnet-ocid>","isPublicIpEnabled":true,"nsgIds":[],"isWorkloadIdentityEnabled":true}}'
```

The `provision-oke-byok.sh` script handles this automatically.

### 2. Dynamic Group

Create a Dynamic Group in the root tenancy. The matching rule must include `instance.compartment.id` in addition to `resource.type='workloadidentity'` because the OCI SDK uses node VM instance principal credentials alongside the workload identity token:

```
ANY {
  resource.type='workloadidentity',
  resource.namespace='streamtime-agent',
  instance.compartment.id='<compartment-ocid>'
}
```

> **Why `instance.compartment.id` instead of `resource.cluster_id`?**
> The OCI SDK's workload identity provider internally falls back to node instance principal credentials for some API paths. Using `instance.compartment.id` ensures both the workload identity resource principal and the node VM instance principal match the group. A rule using only `resource.cluster_id` will fail silently for certain API calls.

> **OCI CLI `update --matching-rule` bug**: The `oci iam dynamic-group update --matching-rule` flag is silently ignored. To update an existing Dynamic Group's rule, use the raw REST API:
> ```bash
> oci raw-request --http-method PUT \
>   --target-uri "https://identity.${REGION}.oraclecloud.com/20160918/dynamicGroups/${DG_OCID}" \
>   --request-body "{\"matchingRule\":\"ANY {resource.type='workloadidentity', resource.namespace='streamtime-agent', instance.compartment.id='${COMPARTMENT_ID}'}\"}"
> ```

### 3. IAM Policies

OCI requires **two separate policies** because node pool creation requires tenancy-level `manage all-resources` — granular per-resource permissions at the compartment level are insufficient for `CreateNodePool`.

**Compartment-level policy** (object storage and basic cluster access):

```
Allow dynamic-group <DG_NAME> to manage object-family in compartment <compartment-name>
Allow dynamic-group <DG_NAME> to manage cluster-node-pools in compartment <compartment-name>
Allow dynamic-group <DG_NAME> to manage clusters in compartment <compartment-name>
Allow dynamic-group <DG_NAME> to use virtual-network-family in compartment <compartment-name>
```

**Tenancy-level policy** (required for `CreateNodePool` to succeed — empirically confirmed):

```
Allow dynamic-group <DG_NAME> to manage all-resources in tenancy
```

> **Why `manage all-resources in tenancy`?**
> Empirical testing against a live OKE cluster confirmed that all granular combinations (`manage cluster-node-pools`, `manage clusters`, `manage instances`, `use subnets`, `manage cluster-family`) fail at the compartment level when the agent tries to create a node pool. Only `manage all-resources in tenancy` at the tenancy level succeeds. This is a known OCI IAM behavior for OKE node pool operations where the control plane makes cross-compartment API calls internally.

> **IAM policies cannot be created by the agent**: OCI resource principals (even with `manage policies`) cannot create IAM policies. The operator must pre-create the policies above. The `CreateStorageIAMBinding` activity on OCI returns a placeholder `BindingID` acknowledging this constraint rather than attempting to create a policy.

### 4. No service-account annotation needed

Unlike AWS IRSA (where the SA must be annotated with `eks.amazonaws.com/role-arn`) and Azure (where the SA needs `azure.workload.identity/client-id`), OCI requires no SA annotation. The OKE node's IMDS provides the credentials automatically to all pods in the cluster once WI is enabled.

## API 1: Provision object storage (OCI)

### Request

`POST /organizations/root/fleet/{fleet_id}/agent/ProvisionObjectStorageWorkflow/`

**Strictly required:** nothing — the agent discovers everything from the cluster environment.

**Optional overrides:**

- `bucket_name`: defaults to `streamtime-{fleet_id}`
- `compartment_id`: auto-discovered from OCI IMDS if omitted (see "What the agent discovers" below)
- `region`: auto-detected from the workload identity provider

Minimal example (no fields required):

```bash
curl -sk -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}' \
  https://api.streamtime.local:8443/organizations/root/fleet/my-fleet/agent/ProvisionObjectStorageWorkflow/
```

With optional bucket name:

```bash
curl -sk -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"bucket_name": "streamtime-my-fleet"}' \
  https://api.streamtime.local:8443/organizations/root/fleet/my-fleet/agent/ProvisionObjectStorageWorkflow/
```

### What the agent discovers (OCI object storage)

| Field | Source | How |
|---|---|---|
| `compartment_id` | OCI IMDS | `GET http://169.254.169.254/opc/v2/instance/compartmentId` with `Authorization: Bearer Oracle` header — always reachable from any OKE pod |
| `region` | Workload identity provider config | Derived when acquiring OKE resource principal credentials |

### Runtime behavior on OCI

The agent uses `auth.OkeWorkloadIdentityConfigurationProvider()` and performs:

- Identity validation via OCI Identity API (`GetUser` / `ListCompartments`)
- `objectstorage.CreateBucket` in the auto-discovered compartment
- IAM binding: returns a placeholder (operator must pre-create policies — see prerequisites above)

Bucket creation is idempotent: a 409 "already exists" response is treated as success on subsequent runs.

> **Note on OCI 409 errors**: OCI Object Storage returns 409 `BucketAlreadyExists` for both "bucket exists" and "not authorized" conditions. If the bucket does not appear after a successful workflow run, check that the compartment-level policy grants `manage object-family` to the Dynamic Group.

## API 2: Provision node pool (OCI)

### Request

`POST /organizations/root/fleet/{fleet_id}/agent/ProvisionNodePoolWorkflow/`

**Strictly required:**

- `node_pool_name`: max 32 characters (OCI limit — longer names are truncated automatically)
- `instance_type`: OCI shape name, e.g. `VM.Standard.E4.Flex`
- `node_count`: number of nodes (>= 1)

**Everything else is auto-discovered** — no `compartment_id`, `cluster_id`, `subnet_id`, or `availability_domain` needed.

Minimal example:

```bash
curl -sk -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "node_pool_name": "kafka-workers",
    "instance_type": "VM.Standard.E4.Flex",
    "node_count": 3
  }' \
  https://api.streamtime.local:8443/organizations/root/fleet/my-fleet/agent/ProvisionNodePoolWorkflow/
```

Optional labels:

```bash
  -d '{
    "node_pool_name": "kafka-workers",
    "instance_type": "VM.Standard.E4.Flex",
    "node_count": 3,
    "labels": {"streamtime.io/workload": "kafka"}
  }'
```

Optional override fields (only needed if auto-discovery fails or you want to override placement):

- `compartment_id`: override IMDS-discovered compartment OCID
- `cluster_id`: override node-label-discovered cluster OCID
- `subnet_id`: override subnet discovered from existing node pool
- `availability_domain`: override AD discovered from existing node pool

### What the agent discovers (OCI node pool)

| Field | Source | How |
|---|---|---|
| `compartment_id` | OCI IMDS | `GET http://169.254.169.254/opc/v2/instance/compartmentId` (`Authorization: Bearer Oracle`) — 5 s timeout |
| `cluster_id` | Kubernetes node label | `k8sClient.CoreV1().Nodes().List()` → reads `oke.oraclecloud.com/cluster.id` label set automatically by OKE on every node |
| `subnet_id` | Existing node pool | `containerengine.ListNodePools` + `containerengine.GetNodePool` → `PlacementConfigs[0].SubnetId` |
| `availability_domain` | Existing node pool | Same call → `PlacementConfigs[0].AvailabilityDomain` |
| `kubernetes_version` | Existing node pool | `GetNodePool.KubernetesVersion` — uses the OKE-specific version (e.g. `v1.32.10`), not the control plane version |
| OS image OCID | Existing node pool | `GetNodePool.NodeSourceDetails` (`NodeSourceViaImageDetails.ImageId`) |
| OCPUs / memory | Existing node pool | `GetNodePool.NodeShapeConfig` — defaults to 2 OCPUs / 16 GB if not present in existing pool |

**Prerequisite for auto-discovery**: the cluster must have at least one existing node pool. The agent reads from it to match the new pool to the cluster's existing image, version, and placement.

### Runtime behavior on OCI

The agent uses OKE Workload Identity and performs:

- Identity validation
- IMDS call to discover `compartment_id`
- Node label read to discover `cluster_id`
- `containerengine.ListNodePools` + `containerengine.GetNodePool` to discover k8s version, OS image OCID, OCPUs, memory, subnet OCID, and availability domain
- `containerengine.CreateNodePool` with `NodeSourceViaImageDetails` and `CreateNodeShapeConfigDetails`
- Polls the work request until `SUCCEEDED` or `FAILED`
- Non-fatal tainting pass via `TaintNodesByLabelWorkflow` (nodes may still be joining when taint is attempted)

## OCI IAM permissions checklist

Minimum IAM permissions required (must be pre-created by operator — agent cannot create its own policies):

**Compartment-level** (grant to the Dynamic Group):
- `manage object-family` — bucket creation and object management
- `manage cluster-node-pools` — node pool CRUD
- `manage clusters` — cluster read/update
- `use virtual-network-family` — subnet + VCN access during node pool creation

**Tenancy-level** (grant to the Dynamic Group):
- `manage all-resources in tenancy` — required for `CreateNodePool` to succeed (granular policies insufficient)

## API 3: Scale node pool (OCI Workload Identity)

### Request

`POST /organizations/root/fleet/{fleet_id}/agent/ScaleNodePoolWorkflow/`

**Required:**

- `node_pool_name`: name of the existing OKE node pool
- `node_count`: desired node count after scaling (>= 0)

**Optional overrides:**

- `compartment_id`: override IMDS-discovered compartment OCID
- `cluster_id`: override node-label-discovered cluster OCID
- `node_pool_id`: OCID of the node pool (skips `ListNodePools` lookup if provided)

Minimal example — scale `kafka-workers` to 4 nodes:

```bash
curl -sk -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "node_pool_name": "kafka-workers",
    "node_count": 4
  }' \
  https://api.streamtime.local:8443/organizations/root/fleet/my-oke-fleet/agent/ScaleNodePoolWorkflow/
```

Scale down:

```bash
  -d '{"node_pool_name": "kafka-workers", "node_count": 2}'
```

### Runtime behavior on OCI

The agent validates workload identity, then:

1. Auto-discovers `compartment_id` from OCI IMDS (`http://169.254.169.254/opc/v2/instance/compartmentId`).
2. If `node_pool_id` is not provided, lists node pools via `containerengine.ListNodePools` (filtered by compartment + cluster) and finds the pool matching `node_pool_name`.
3. Calls `containerengine.UpdateNodePool` with `NodeConfigDetails.Size = node_count`.

Unlike `ProvisionNodePool`, the scale operation does not poll a work request — `UpdateNodePool` applies the size change asynchronously via the OKE control plane. The response is returned immediately once the API call succeeds.

### Response

When complete:

```json
{
  "provider": "oci",
  "node_pool_name": "kafka-workers",
  "node_pool_id": "ocid1.nodepool.oc1.ap-mumbai-1.aaaaaaaa...",
  "node_count": 4
}
```

> **Note**: OCI scales node pools by updating the desired size — the control plane adds or removes nodes in the background. Check the OKE console or `oci ce node-pool get` to confirm nodes have reached `ACTIVE` state.

## OCI IAM: `ScaleNodePool` permissions

Scaling uses `containerengine.UpdateNodePool`. This is covered by the existing `manage cluster-node-pools` compartment-level policy and `manage all-resources in tenancy` tenancy-level policy already required for provisioning — no additional permissions are needed.
