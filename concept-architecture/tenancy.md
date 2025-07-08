---
title: Tenancy
nav_order: 4
parent: Concepts & Architecture
---

# Tenancy

Streamtime supports three types of tenancy models for both Kubernetes fleets and Kafka clusters. Tenancy determines the level of resource isolation and sharing between different users or workloads.

## Tenancy Types

| Tenancy Type | Description | Details |
| --- | --- | --- |
| Shared | Multiple workloads share the same Kubernetes and Kafka cluster resources. | This model maximizes resource utilization and cost efficiency, but offers the least isolation. |
| Isolated | Each workload has a logically isolated Kafka cluster within a shared Kubernetes fleet. | Kubernetes resources are shared, but Kafka clusters are separated at the logical level for improved security and performance. |
| Dedicated | Each workload has a dedicated Kubernetes cluster and a dedicated Kafka cluster. | This provides complete resource isolation, highest security, and performance guarantees. |

{: .note }
> The tenancy model can be applied at both the Kubernetes fleet level and the Kafka cluster level.
> For example, a dedicated Kafka cluster will run on a dedicated Kubernetes cluster, while a shared Kafka cluster will run on a shared Kubernetes cluster.  


## How Tenancy Works
- **Shared Tenancy**: Multiple Kafka clusters run on the same Kubernetes cluster, sharing resources like CPU, memory, and storage. This is cost-effective but may lead to resource contention.
- **Isolated Tenancy**: Each Kafka cluster runs in its own namespace within a shared Kubernetes cluster, providing logical separation. This allows for better security and performance while still sharing the underlying Kubernetes resources.
- **Dedicated Tenancy**: Each Kafka cluster runs on its own dedicated Kubernetes cluster, ensuring full resource isolation. This is ideal for high-security or high-performance workloads, as it guarantees that resources are not shared with other workloads.     


## When to Use Each Tenancy Type
- **Shared**: Use when cost savings are a priority and workloads do not require strict isolation.
- **Isolated**: Use when moderate isolation is needed, such as for production workloads that require logical separation but can share Kubernetes resources.
- **Dedicated**: Use for workloads that require the highest level of security, performance, and resource isolation, such as regulated industries or high-performance applications.      


---

## Use Cases

- **Shared**: Development, testing, or low-risk production.
- **Isolated**: Production workloads with moderate isolation needs.
- **Dedicated**: Regulated industries, high-security, or high-performance requirements.

---