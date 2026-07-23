---
title: "BYOK with AWS"
parent: Bootstrapping Your Fleet
nav_order: 6
---

# BYOK with AWS: Prerequisites

This page covers the AWS-account and EKS-cluster prerequisites specific to
BYOK on AWS — sizing, IAM/IRSA, networking, and the kubeconfig format the
orchestrator expects. See [Advanced Usage (BYOK)](byok.html) for the
provider-agnostic walkthrough of the Streamtime UI flow itself.

---

## Before you start

You'll need:

- An AWS account with permissions to create an EKS cluster, a managed node
  group, IAM roles, and an IAM OIDC provider. Confirm your account ID with
  `aws sts get-caller-identity` — use the **`Account`** field (the 12-digit
  number), never the `UserId` field. Using the wrong one is the most common
  cause of `AccessDenied` errors when creating the cluster or nodegroup.
- `aws` CLI v2, `eksctl` (for OIDC association), and `kubectl`.
- Subnets across at least two AZs, already created. The default VPC's
  per-AZ subnets work for a first cluster.

> `scripts/provision-streamtime-byok.sh` automates every step below end to
> end against a fresh or existing cluster.

---

## 1. Sizing guidelines

A fleet is sized in **Kafka Units (KU)**, where 1 KU = 20 MB/s of
throughput, up to a **maximum of 40 KU per cluster**. The recommended node
size is **4 vCPU / 16 GB RAM per Kafka unit** — for AWS that maps directly
to `t3.xlarge`, which is what the reference deployment uses:
`minSize=1, maxSize=3, desiredSize=2` at the lower end of the range. Scale
the node count and instance type up toward the 40 KU ceiling based on your
target tier and tenancy model (shared/dedicated), and leave headroom above
your current KU target so a node isn't pinned at capacity before
autoscaling kicks in.

## 2. IRSA role and policy

An OIDC identity provider must be associated with the cluster before any
IRSA role can work, and **this has to be redone for every new cluster** —
a fresh cluster gets a fresh OIDC ID, and any role still trusting the old
one will fail with `AccessDenied: ... AssumeRoleWithWebIdentity`:

```bash
eksctl utils associate-iam-oidc-provider --cluster <cluster> --region <region> --approve
aws eks describe-cluster --name <cluster> --region <region> \
  --query 'cluster.identity.oidc.issuer' --output text
# the hex string after /id/ is your OIDC ID — save it
```

The only IRSA role BYOK requires is for the **EBS CSI driver**. The
Streamtime agent itself doesn't need direct AWS API access — it operates
through a Kubernetes `cluster-admin` binding (see [Section 5](#5-generating-a-kubeconfig-for-automatic-installation)),
not an IAM role.

Create the EBS CSI role with a trust policy scoped to the OIDC provider,
condition `<oidc-host>:sub = system:serviceaccount:kube-system:ebs-csi-controller-sa`,
and attach the `AmazonEBSCSIDriverPolicy` managed policy. If you're
rebuilding a cluster and the role already exists, update its trust policy
to the new OIDC provider rather than recreating the role — and if your SSO
role can't call `iam:UpdateAssumeRolePolicy`, create a new role (e.g.
suffixed `_v3`) instead of fighting the permission.

Before installing the addon, double-check the trust policy doesn't still
contain a literal placeholder OIDC ID — that's the most common cause of the
addon's controller pods crash-looping with `AccessDenied` on
`AssumeRoleWithWebIdentity`.

## 3. IP addressing for pods and services

The VPC CNI assigns each pod a routable IP from its node's subnet, so
subnet size — not just node count — caps how many pods will schedule.
Undersized subnets showing up as pods stuck `Pending` is a known failure
mode; size subnets for your target node count with headroom, not just the
starting count.

## 4. Load balancer and default storage class

- **Load balancer**: no separate AWS Load Balancer Controller install is
  needed. Kong Ingress is exposed via a `Service` of type `LoadBalancer`,
  which EKS's in-tree cloud provider turns into a classic ELB
  automatically.
- **EBS CSI driver + default StorageClass**: EKS 1.23+ dropped the in-tree
  EBS provisioner, so `aws-ebs-csi-driver` must be installed as an addon
  (using the IRSA role above), and a default `StorageClass` must exist:
  ```yaml
  apiVersion: storage.k8s.io/v1
  kind: StorageClass
  metadata:
    name: ebs-sc
    annotations:
      storageclass.kubernetes.io/is-default-class: 'true'
  provisioner: ebs.csi.aws.com
  volumeBindingMode: WaitForFirstConsumer
  parameters:
    type: gp3
  ```
  Skipping this is the most common cause of a stuck bootstrap: without a
  default `StorageClass`, Loki and Prometheus (and any other PVC-backed
  workload) stay `Pending` forever, which surfaces as the bootstrap
  workflow timing out after roughly 30 minutes. If that happens, check
  `kubectl get pods -A | grep Pending`, apply the `StorageClass` above if
  it's missing, then:
  ```bash
  helm uninstall kafka-fleet-manager-loki -n monitoring
  kubectl delete pvc --all -n monitoring
  ```
  and retry the fleet.

## 5. Generating a kubeconfig for automatic installation

The fleet-manager orchestrator expects a **static bearer token**, not an
exec-based credential plugin, and it's strict about the exact structure —
getting this wrong surfaces as `TypeError: string indices must be integers,
not 'str'` in the bootstrap workflow rather than as an upload-time
validation error.

1. Create a service account and bind it to `cluster-admin`:
   ```bash
   kubectl create serviceaccount streamtime-admin -n kube-system
   kubectl create clusterrolebinding streamtime-admin-binding \
     --clusterrole=cluster-admin \
     --serviceaccount=kube-system:streamtime-admin
   ```
2. Generate a token (shown once — save it):
   ```bash
   kubectl create token streamtime-admin -n kube-system --duration=24h
   ```
   Regenerate with the same command and re-upload if a long-running BYOK
   cluster's fleet connection drops after the token expires.
3. Grab the endpoint and CA data:
   ```bash
   aws eks describe-cluster --name <cluster> --region <region> --query 'cluster.endpoint' --output text
   aws eks describe-cluster --name <cluster> --region <region> --query 'cluster.certificateAuthority.data' --output text
   ```
4. Assemble the kubeconfig in exactly this shape:
   ```yaml
   apiVersion: v1
   kind: Config
   clusters:
   - cluster:
       server: https://<endpoint>
       certificate-authority-data: <ca-data>
     name: <cluster-name>
   contexts:
   - context:
       cluster: <cluster-name>
       user: streamtime-admin
     name: <cluster-name>-context
   current-context: <cluster-name>-context
   users:
   - name: streamtime-admin
     user:
       token: <token>
   ```
   Three rules the workflow enforces strictly:
   - `clusters[].name` must be a short cluster name, **not** the cluster ARN.
   - `users[].user` must be a **nested object** containing `token:` — a flat
     `user: <token>` string will fail.
   - Spaces only, no tabs, anywhere in the file.
5. Paste the file contents into the fleet's kubeconfig field in the
   Streamtime UI (or `POST /organizations/<org>/fleets/<fleet_id>/kubeconfig/`
   if you're driving it via API).

After upload, `InstallStreamtimeAgentWorkflow` and
`BootstrapFleetClusterWorkflow` install the fleet's Helm charts (Kong,
Strimzi, Confluent operator, Prometheus, Loki, and others). Watch
`kubectl get pods -n streamtime-agent -w` and the Temporal UI for progress.
