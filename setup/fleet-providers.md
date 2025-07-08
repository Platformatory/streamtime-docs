---
title: "Fleet Providers"
nav_order: 4
parent: Shared Cloud Accounts & Services

---

# Fleet Providers

A Fleet Provider is a cloud platform where Streamtime provisions and manages Kubernetes fleets. Supported providers include AWS, GCP, OCI, and Azure.

To enable automated cluster management, you must create a cloud provider account and provide the necessary credentials to Streamtime.

## Supported Fleet Providers

| Provider | Description | Status/Notes |
| --- | --- | --- |
| AWS | Amazon Web Services, a widely used cloud platform. | - |
| GCP | Google Cloud Platform, known for its data analytics and machine learning capabilities. | - |
| OCI | Oracle Cloud Infrastructure, focused on enterprise applications and databases. | - |
| Azure | Microsoft Azure, a comprehensive cloud platform with strong enterprise integration. | Experimental |

Each fleet provider allows you to bootstrap and operate Kubernetes clusters, which serve as the foundation for running Kafka clusters and other workloads.

## When to Use a Fleet Provider
- **Multi-cloud Deployments**: When you want to leverage multiple cloud providers for redundancy or specific features.
- **Regional Compliance**: If your workloads require deployment in specific regions for compliance or latency.
- **Cost Optimization**: Choose a provider based on cost efficiency for your workloads.

## Steps to Add a Fleet Provider

1. **Create a Cloud Provider Account**  
   Sign in to your chosen cloud provider (AWS, GCP, OCI, or Azure) and create an account or use an existing one.

![Fleet Provider]({{ site.baseurl }}/assets/images/fleet-provider.png)

2. **Set Up Required Permissions**  
   Create a service account, IAM user, or application registration with the necessary permissions to provision and manage Kubernetes clusters and related resources.

3. **Generate Credentials**  
   - **AWS**: Access Key ID and Secret Access Key (with EKS and related permissions)
   - **GCP**: Service Account JSON key (with GKE and related permissions)
   - **Azure**: Client ID, Client Secret, Tenant ID, and Subscription ID (with AKS and related permissions)
   - **OCI**: User OCID, Tenancy OCID, API Key, and related details

4. **Add Credentials to Streamtime**  
   In the Streamtime platform UI or CLI, add your cloud provider credentials. These credentials are used to automate the creation and management of Kubernetes fleets.

5. **Validate Connection**  
   Streamtime will verify the credentials and permissions before enabling fleet provisioning.

See the platform UI or CLI for detailed, provider-specific setup instructions.

---