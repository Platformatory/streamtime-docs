---
title: "Bootstrap: AWS"
parent: Fleet Management
nav_order: 2
---

# Fleets on AWS

Streamtime creates and runs a Kubernetes cluster (Amazon EKS) in your AWS
account, then installs what the fleet's workloads need. You register the
account once, then create fleets on it.

## Key Features

- **Managed Kubernetes**: Streamtime creates, monitors and deletes the EKS cluster for you.
- **Your network or a new one**: use an existing VPC, or let Streamtime create one across two to four availability zones.
- **Tenancy**: Shared, Isolated or Dedicated. See [Tenancy]({{ site.baseurl }}/about/tenancy/#tenancy).
- **Sized from your workloads**: node types and counts follow the capacity you choose for each workload.
- **Monitoring**: metrics, logs and alerts for the fleet and everything on it.

## Prerequisites

- **AWS credentials** (an access key ID and secret access key, plus a
  session token for temporary credentials) for an IAM user or role that can:
  - create EKS clusters (`eks:CreateCluster`) and IAM roles (`iam:CreateRole`);
  - create a VPC (`ec2:CreateVpc`), or read your existing one (`ec2:DescribeVpcs`);
  - create S3 buckets (`s3:CreateBucket`) for the fleet's logs;
  - simulate its own policy (`iam:SimulatePrincipalPolicy`), so Streamtime
    can check these permissions before it creates anything.

  Streamtime refuses to create the fleet, and names what's missing, when
  a permission is absent.
- **A Base Domain** for the fleet's endpoints, added under **Settings**.

## Fleet settings

**Placement Configuration**

- **Account**: the cloud account you registered.
- **Region**: `us-east-1` or `us-west-2`.

**Advanced Configuration**

- **VPC ID**: an existing VPC, or leave it empty to create a new one.
- **VPC CIDR**: the address range of a new VPC (`10.0.0.0/16`,
  `10.3.0.0/16`, the default, or `172.16.0.0/16`).
- **Availability Zones**: 2 to 4 (default 3).
- **Public Cluster**: whether the Kubernetes API is reachable from the
  internet (on by default).
- **VPC Tags**: extra tags for the VPC and subnets Streamtime creates.
- **Logs Storage Bucket Name**: optional; Streamtime generates a unique
  name when it's empty.
- **Instance Type**: optional; by default node types follow the fleet's
  sizing.

---

{% capture credentials %}{"aws_access_key": "<access-key-id>", "aws_access_secret": "<secret-access-key>"}{% endcapture %}
{% capture placement %}{"account": "<cloud-account>", "region": "us-east-1"}{% endcapture %}
{% capture advanced %}{"aws_vpc_cidr": "10.3.0.0/16", "aws_az_count": 3}{% endcapture %}
{% include fleet-tasks.md provider="aws" name="AWS" id="aws" fleet="payments-east" credentials=credentials placement=placement advanced=advanced shots="aws" %}
