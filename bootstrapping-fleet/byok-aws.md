---
title: "BYOK with AWS"
parent: Bootstrapping Your Fleet
nav_order: 6
---

# BYOK with AWS: Prerequisites

This page covers the AWS-account and EKS-cluster prerequisites specific to
BYOK on AWS — sizing, the IAM role Streamtime needs, and the kubeconfig
format Streamtime expects. See [Advanced Usage (BYOK)](byok.html) for the
provider-agnostic walkthrough of the Streamtime UI flow itself.

This page assumes you already have a working EKS cluster (OIDC provider
associated, `kubectl` access configured) — that setup is standard EKS
administration and isn't specific to Streamtime.

---

## 1. Recommended EKS sizing for bring-your-own clusters

One Kafka Unit (KU) is Streamtime's measure of Kafka throughput and
resource need (1 KU = 20 MB/s). Use the table below to size an EKS
cluster that will host Streamtime.

| Cluster capacity | Platform nodes | Kafka / data nodes | Node size (balanced) |
|---|---|---|---|
| 1–3 units | 3 | 3 | 2 vCPU / 8 GB (`m6i.large`) |
| 4+ units | 3 | Match capacity (one data node per unit, minimum 3) | Scale vCPU/memory with capacity |

Guidance:

- These sizes assume the cluster is dedicated to Streamtime. Don't pack
  unrelated workloads onto the same nodes.
- Platform nodes run monitoring, operators, and the agent. Kafka/data
  nodes run your brokers.
- You may combine platform and Kafka nodes into a single node group if
  you prefer a simpler layout (for example, 6 nodes for 1–3 units of
  capacity).
- Spread nodes across availability zones for resilience.
- No cluster should run with fewer than 3 nodes: for the node group's
  autoscaling config, use `minSize=3, desiredSize=3, maxSize=6` as a
  starting point, and raise `maxSize` further for higher-capacity tiers.
- Use general-purpose-plus memory-optimized instance families (the `m5`/`m6i`
  series) rather than burstable `t`-series instances, which aren't suitable
  for sustained Kafka workloads.

## 2. IAM role for Streamtime

Streamtime uses a single IRSA (IAM Roles for Service Accounts) role,
trusted by your cluster's OIDC provider, for its in-cluster service
accounts — including the one used to create and write to the S3 bucket
that backs log/metrics storage.

Create the role with this trust policy, scoped to the `streamtime-agent`,
`cluster-autoscaler`, and `kafka-fleet-manager-loki` service accounts:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::<account-id>:oidc-provider/<oidc-host>"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "<oidc-host>:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "<oidc-host>:sub": [
          "system:serviceaccount:streamtime-agent:streamtime-agent*",
          "system:serviceaccount:kube-system:cluster-autoscaler*",
          "system:serviceaccount:monitoring:kafka-fleet-manager-loki*"
        ]
      }
    }
  }]
}
```

Attach the AWS-managed `AmazonS3FullAccess` policy, then add the
following inline policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {"Sid": "STSValidation", "Effect": "Allow",
      "Action": ["sts:GetCallerIdentity"], "Resource": "*"},
    {"Sid": "EKSCluster", "Effect": "Allow", "Action": "eks:*",
      "Resource": "arn:aws:eks:<region>:<account-id>:cluster/<cluster-name>"},
    {"Sid": "EKSNodegroups", "Effect": "Allow", "Action": "eks:*",
      "Resource": "arn:aws:eks:<region>:<account-id>:nodegroup/<cluster-name>/*"},
    {"Sid": "EC2Describe", "Effect": "Allow",
      "Action": ["ec2:DescribeSubnets", "ec2:DescribeSecurityGroups",
                 "ec2:DescribeInstances", "ec2:DescribeInstanceTypes"],
      "Resource": "*"},
    {"Sid": "IAMEKSRoles", "Effect": "Allow",
      "Action": ["iam:PassRole", "iam:GetRole", "iam:ListAttachedRolePolicies",
                 "iam:ListRolePolicies", "iam:GetRolePolicy"],
      "Resource": "arn:aws:iam::<account-id>:role/streamtime-eks-*"},
    {"Sid": "IAMServiceLinkedRole", "Effect": "Allow",
      "Action": ["iam:GetRole", "iam:CreateServiceLinkedRole"],
      "Resource": "arn:aws:iam::<account-id>:role/aws-service-role/eks-nodegroup.amazonaws.com/*"},
    {"Sid": "IAMStoragePolicyManage", "Effect": "Allow",
      "Action": ["iam:CreatePolicy", "iam:DeletePolicy",
                 "iam:GetPolicy", "iam:ListPolicies"],
      "Resource": "arn:aws:iam::<account-id>:policy/streamtime-storage-*"},
    {"Sid": "IAMStoragePolicyAttach", "Effect": "Allow",
      "Action": ["iam:AttachRolePolicy", "iam:DetachRolePolicy",
                 "iam:ListAttachedRolePolicies", "iam:GetRole",
                 "iam:UpdateAssumeRolePolicy"],
      "Resource": "arn:aws:iam::<account-id>:role/<irsa-role-name>"}
  ]
}
```

> **Note for review:** this is copied verbatim from
> `provision-eks-byok.sh`, which is the script Streamtime uses to
> provision its own reference clusters end to end — so the policy covers
> more than S3/Loki access; it also grants `eks:*` on the cluster and
> nodegroups, and `iam:*` scoped to `streamtime-eks-*`/`streamtime-storage-*`
> resources. Worth confirming with Avinash whether an already-existing
> BYOK cluster's role needs this full scope, or just the S3 + trust-policy
> portion, before this goes live.

## 3. IP addressing for pods and services

Size your subnets for your target node count with headroom, not just the
starting count — undersized subnets surface as pods stuck in a `Pending`
state as the cluster grows.

## 4. Load balancer and storage class

- **Load balancer**: Streamtime exposes its endpoints through a standard
  Kubernetes `Service` of type `LoadBalancer`. On EKS this provisions a
  load balancer automatically — no separate load balancer controller
  needs to be installed.
- **Default storage class**: Streamtime runs several components that
  need persistent storage. Your cluster must have a default
  `StorageClass` configured — on EKS this means the EBS CSI driver addon
  is installed and a `StorageClass` is marked as default. Without one,
  Streamtime's storage-backed components will stay stuck in a `Pending`
  state and bootstrapping the fleet will not complete.

## 5. Generating a kubeconfig for the Streamtime Agent's automatic installation

Streamtime expects a static token in the kubeconfig for user
authentication when using Automatic Installation of the agent. See
[Advanced Usage (BYOK)](byok.html) for more on the Automatic Installation
flow.

Assuming the kubeconfig is set to the EKS cluster, the following commands
can be used to generate a kubeconfig with a static token for an EKS
cluster:

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
   Three rules Streamtime enforces strictly:
   - `clusters[].name` must be a short cluster name, **not** the cluster ARN.
   - `users[].user` must be a **nested object** containing `token:` — a flat
     `user: <token>` string will fail.
   - Spaces only, no tabs, anywhere in the file.
5. Upload the kubeconfig as a Secret in the **Agent Management** section
   of the fleet. See the [Kubeconfig section](byok.html) of the BYOK
   documentation for the full walkthrough.
