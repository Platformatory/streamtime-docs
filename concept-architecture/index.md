---
title: "Concepts & Architecture"
nav_order: 2
layout: home
---

# Concept & Architecture

Streamtime provides a unified platform to deploy, manage, and operate Kafka clusters and Kubernetes fleets across multiple cloud providers. The architecture is designed for flexibility, scalability, and security, supporting a variety of deployment models and tenancy options.

## Architecture Overview

The following diagram illustrates the high-level architecture of Streamtime:

![Streamtime Architecture]({{ site.baseurl }}/assets/images/architecture.png)

## Key Concepts

- **Fleet Provider**: Supported cloud providers (AWS, GCP, OCI, Azure) where Kubernetes fleets are provisioned.
- **Kubernetes Fleet**: Managed Kubernetes clusters that host Kafka clusters and other workloads.
- **Kafka Cluster**: Different Kafka distributions supported (CFK, Apache Kafka, WarpStream, Redpanda, AutoMQ).
- **Kafka Unit Size**: Kafka clusters are sized by units (1 unit = 20 MBps throughput), allowing flexible scaling.
- **Tenancy**: Resource isolation models—shared, isolated, and dedicated—applied at both Kubernetes and Kafka cluster levels.

Explore the sections below for detailed explanations of each concept and architectural component.   