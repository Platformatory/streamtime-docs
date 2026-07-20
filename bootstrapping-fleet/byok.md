---
title: "BYOK with AWS"
parent: Bootstrapping Your Fleet
nav_order: 2
---

# Bring Your Own Kubernetes (BYOK) with AWS

With BYOK, you provision and own the EKS cluster yourself and connect it to
Streamtime, instead of having Streamtime provision the cluster for you. This
page covers the prerequisites your AWS account and cluster need before you
onboard it as a fleet.

---

## Before you start

You'll need:

- An AWS account with permissions to create an EKS cluster, a managed node
  group, IAM roles, and an IAM OIDC provider. Confirm your account ID with
  `aws sts get-caller-identity` — use the **`Account`** field (the 12-digit
  number), never the `UserId` field. Using the wrong one is the single most
  common cause of `AccessDenied` errors when creating the cluster or
  nodegroup.
- `aws` CLI v2, `eksctl` (for OIDC association), and `kubectl`.
- Subnets across at least two AZs, already created. The default VPC's
  per-AZ subnets work for a first cluster; `scripts/provision-streamtime-byok.sh`
  auto-discovers 3 of them if `SUBNET_IDS` isn't set.

> Two reference scripts exist in this repo —
> `scripts/provision-eks-byok.sh` and `scripts/provision-streamtime-byok.sh`.
> They automate the steps below end to end but differ in a couple of ways
> called out inline. `provision-streamtime-byok.sh` is the one that matches
> the verified manual walkthrough this page is based on.

---

## 1. Rough sizing guidelines

The validated reference deployment uses **`t3.xlarge`** nodes,
`minSize=1, maxSize=3, desiredSize=2` — that's a known-working single-cluster
baseline, not a per-KU-tier sizing table.

<!-- TODO(vishal): we don't have a published KU→node-count/type mapping yet.
     If benchstress has one, drop it in here as a table. Until then this
     page only states the one baseline that's actually been proven out. -->

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

**⚠️ Open question — please confirm which of these is actually correct
before this ships:**

- `provision-eks-byok.sh` creates a broad **`streamtime-agent-irsa`** role,
  trusted by the `streamtime-agent`, `cluster-autoscaler`, and
  `kafka-fleet-manager-loki` service accounts, with `AmazonS3FullAccess`
  plus an inline policy covering `eks:*`, EC2 describes, and IAM
  role/policy management scoped to `streamtime-eks-*` roles and
  `streamtime-storage-*` policies.
- `provision-streamtime-byok.sh` and the verified manual guide **only**
  create an IRSA role for the EBS CSI driver (see below) — the agent
  itself gets a plain Kubernetes `cluster-admin` binding with a static
  token, no AWS IAM role at all.

If the agent doesn't need direct AWS API access in the current
architecture, the S3/EKS/IAM-management IRSA role described in
`provision-eks-byok.sh` may be leftover from an earlier design. Documenting
an IRSA role the agent doesn't actually use (or missing one it does) is
worse than a gap — let me know which is current and I'll fix this section.

### EBS CSI driver IRSA role (confirmed by both sources)

Trust policy scoped to the OIDC provider, condition
`<oidc-host>:sub = system:serviceaccount:kube-system:ebs-csi-controller-sa`,
with the `AmazonEBSCSIDriverPolicy` managed policy attached. If you're
rebuilding a cluster and the role already exists, update its trust policy
rather than recreating the role — and if your SSO role can't call
`iam:UpdateAssumeRolePolicy`, create a new role (e.g. suffixed `_v3`) instead
of fighting the permission.

Before installing the addon, double check the trust policy doesn't still
contain the literal string `YOUR_OIDC_ID` — that's the #1 cause of the addon
controller pods crash-looping with `AccessDenied` on `AssumeRoleWithWebIdentity`.

## 3. IP addressing for pods and services

<!-- TODO(vishal): neither script nor the manual guide computes this — they
     just take 3 default-AZ subnets as given. If there's a real number you
     want published (e.g. from a specific sizing exercise), send it over and
     I'll swap this section for the concrete figure. -->

The VPC CNI assigns each pod a routable IP from its node's subnet, so subnet
size — not just node count — caps how many pods will schedule. Undersized
subnets showing up as pods stuck `Pending` is a known failure mode; size
subnets for your target node count with headroom, not just the starting
count.

## 4. Load balancer and default storage class

- **Load balancer**: the verified deployment does **not** install a
  separate AWS Load Balancer Controller. Kong Ingress is exposed via a
  `Service` of type `LoadBalancer`, which EKS's in-tree cloud provider
  turns into a classic ELB automatically — no extra controller install
  needed for this path.
- **EBS CSI driver + default StorageClass**: EKS 1.23+ dropped the in-tree
  EBS provisioner, so `aws-ebs-csi-driver` must be installed as an addon
  (IRSA role above), and a default `StorageClass` must exist:
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
  **This step is easy to skip and expensive to skip** — without it, Loki
  and Prometheus pods (and any other PVC-backed workload) stay `Pending`
  forever, which shows up as the bootstrap workflow timing out after
  ~30 minutes. If that happens: check `kubectl get pods -A | grep Pending`,
  apply the StorageClass above if missing, then
  `helm uninstall kafka-fleet-manager-loki -n monitoring && kubectl delete pvc --all -n monitoring`
  and retry the fleet.

## 5. Generating a kubeconfig for automatic installation

The fleet-manager orchestrator expects a **static bearer token**, not an
exec-based credential plugin — and it's strict about the exact structure.
Getting this wrong surfaces as `TypeError: string indices must be integers,
not 'str'` in the bootstrap workflow, not as an upload-time validation error,
so it's worth getting right the first time.

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
   This expires (24h in the reference example); regenerate with the same
   command and re-upload if a long-running BYOK cluster's fleet connection
   drops.
3. Grab the endpoint and CA data:
   ```bash
   aws eks describe-cluster --name <cluster> --region <region> --query 'cluster.endpoint' --output text
   aws eks describe-cluster --name <cluster> --region <region> --query 'cluster.certificateAuthority.data' --output text
   ```
4. Assemble the kubeconfig **exactly** in this shape:
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
   - Spaces only, no tabs, in the YAML.
5. Paste the file contents into the fleet's kubeconfig field in the
   Streamtime UI (or `POST /organizations/<org>/fleets/<fleet_id>/kubeconfig/`
   if you're driving it via API).

After upload, `InstallStreamtimeAgentWorkflow` and
`BootstrapFleetClusterWorkflow` install the fleet's Helm charts (Kong,
Strimzi, Confluent operator, Prometheus, Loki, and others) — watch
`kubectl get pods -n streamtime-agent -w` and the Temporal UI for progress,
and see the troubleshooting notes above if Loki hangs.
