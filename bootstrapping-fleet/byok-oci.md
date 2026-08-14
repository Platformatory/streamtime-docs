---
title: "BYOK with OCI"
parent: Bootstrapping Your Fleet
nav_order: 7
---

# BYOK with OCI: Prerequisites

This page covers the prerequisites required for using an Oracle Kubernetes
Engine (OKE) cluster through Bring Your Own Kubernetes (BYOK) in Streamtime
— sizing, the workload identity policy Streamtime needs, and the kubeconfig
format Streamtime expects. See [Advanced Usage (BYOK)](byok.html) for the
provider-agnostic walkthrough of the Streamtime UI flow itself.

This page assumes you already have a working OKE cluster (or are about to
create one) — `kubectl` access configured, and administrative access to the
tenancy to create Dynamic Groups and IAM policies.

---

## 1. Recommended OKE sizing for bring-your-own clusters

One Kafka Unit (KU) is Streamtime's measure of Kafka throughput and
resource need (1 KU = 20 MB/s). The following table can be used as a
reference to size an OKE node pool that will be used to run Kafka using
Streamtime — actual sizing might vary depending on your workload.

| Kafka Units | CPU (per broker) | Memory (per broker) |
|-------------|------------------|---------------------|
| 2           | 2 OCPU           | 8 GB                |
| 8           | 8 OCPU           | 32 GB               |
| 16          | 16 OCPU          | 64 GB               |
| 32          | 32 OCPU (cap     | 128 GB              |
|             |         reached) |                     |

CPU scales 1:1 with Kafka Units and caps at 32 OCPU

Guidance:

- Add headroom on top of the table above for the Kafka operator,
  Strimzi/CFK controllers, and the Streamtime agent itself — roughly 1
  extra OCPU / 2 GB per node pool covers those.
- Use flexible shapes (`VM.Standard.E4.Flex` or `VM.Standard.E5.Flex`)
  sized to the table above so OCPU/memory can be tuned independently of
  the shape name.
- Spread nodes across availability domains for resilience.
- These sizes assume the cluster is dedicated to Streamtime. Don't pack
  unrelated workloads onto the same node pool.

## 2. Workload identity policy

Streamtime's agent authenticates to OCI using **OKE Workload Identity** —
it never receives static OCI API keys. This requires:

- **An Enhanced-tier OKE cluster.** Workload Identity is only available on
  Enhanced clusters; Basic clusters don't support it. There's no in-place
  upgrade path from Basic to Enhanced.
- **Workload Identity enabled on the cluster**, done before any node pools
  are created so new nodes pick up the cluster-level configuration.

No `ServiceAccount` annotation is needed on the agent pod — OCI reads
identity from the pod's projected Kubernetes service account token and
exchanges it automatically at the OKE metadata endpoint.

**Dynamic Group** — create one in the **root tenancy** (not a child
compartment) with this matching rule:

```
ANY {resource.type='workloadidentity', resource.namespace='streamtime-agent', instance.compartment.id='<your-compartment-ocid>'}
```

Both conditions matter: `resource.type`/`resource.namespace` cover the
agent's own workload identity token (scoped to the `streamtime-agent`
namespace — adjust if you install into a different namespace), while
`instance.compartment.id` covers the node VM's instance-principal fallback
that OCI uses for some API calls (notably creating node pools).

**IAM policies** — two are required, both in the root tenancy:

Compartment-level (object storage for log shipping, cluster, and network access):
```
Allow dynamic-group <dg-name> to manage object-family in compartment <compartment-name>
Allow dynamic-group <dg-name> to manage cluster-node-pools in compartment <compartment-name>
Allow dynamic-group <dg-name> to manage clusters in compartment <compartment-name>
Allow dynamic-group <dg-name> to use virtual-network-family in compartment <compartment-name>
```

Tenancy-level (required specifically for creating node pools — OKE's
control plane makes cross-compartment calls that no compartment-scoped
grant satisfies):
```
Allow dynamic-group <dg-name> to manage all-resources in tenancy
```

## 3. IP addressing for pods and services

Plan **two separate subnets**, not one: a node subnet, and a separate load
balancer subnet. OCI's Cloud Controller Manager does not allow a single
subnet to serve both node pools and Kubernetes `Service` load balancers —
each subnet needs enough headroom for your target node count and expected
number of load-balanced services, not just the starting count. As a rough
reference point, a production fleet typically runs on the order of
**100–200 pods and services** combined (Kafka brokers, operators,
monitoring, and the agent), scaling up toward the higher end for larger KU
tiers.

If your cluster uses the default Flannel overlay networking, pod IPs come
from an internal overlay range and don't consume VCN address space at all.
If it uses VCN-Native Pod Networking instead, size a dedicated pod subnet
generously — each pod consumes a real VCN IP in that mode.

## 4. Load balancer and storage class

- **Load balancer**: Streamtime exposes its endpoints through a standard
  Kubernetes `Service` of type `LoadBalancer`, requesting an OCI Network
  Load Balancer. OKE's Cloud Controller Manager provisions this
  automatically — no separate load balancer controller needs to be
  installed — but it can only auto-detect the load balancer subnet from
  [section 3](#3-ip-addressing-for-pods-and-services) if that subnet is
  kept separate from your node subnet.
- **Default storage class**: Streamtime runs several components that need
  persistent storage. Your cluster must have a default `StorageClass`
  configured — OKE ships the OCI Block Volume CSI driver and marks
  `oci-bv` default automatically, but confirm this wasn't disabled:
  ```bash
  kubectl get storageclass
  ```
  You should see exactly one StorageClass marked `(default)`. Without one,
  Streamtime's storage-backed components will stay stuck in a `Pending`
  state and bootstrapping the fleet will not complete.

## 5. Generating a kubeconfig for the Streamtime Agent's automatic installation

Streamtime expects a static token in the kubeconfig for user
authentication when using Automatic Installation of the agent. This
kubeconfig is only used to install the Streamtime Agent, and the token in
it should be short-lived. See [Advanced Usage (BYOK)](byok.html) for more
on the Automatic Installation flow.

Assuming your kubeconfig is set to the OKE cluster (`oci ce cluster
create-kubeconfig --cluster-id <cluster-ocid> --file $HOME/.kube/config
--region <region> --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT`),
the following commands generate a kubeconfig with a static token:

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
3. Grab the endpoint and CA data:
   ```bash
   oci ce cluster get --cluster-id <cluster-ocid> \
     --query 'data.endpoints."public-endpoint"' --raw-output
   kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'
   ```

### Step 4: assemble the kubeconfig

Assemble the kubeconfig in exactly this shape:

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
- `clusters[].name` must be a short cluster name, **not** the cluster OCID.
- `users[].user` must be a **nested object** containing `token:` — a flat
  `user: <token>` string will fail.
- Spaces only, no tabs, anywhere in the file.

### Step 5: upload the kubeconfig

Upload/paste the kubeconfig file as a Secret in the **Agent Management**
section of the fleet. See the [Kubeconfig section](byok.html) of the
BYOK documentation.
