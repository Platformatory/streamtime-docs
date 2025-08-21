---
title: "Oracle"
parent: Bootstrapping Your Fleet
nav_order: 2
---

# Bootstrapping on Oracle (OKE)

Oracle Cloud Infrastructure (OCI) is supported as a bootstrap provider for creating Kubernetes fleets in Streamtime, enabling you to deploy and manage Kafka clusters on Oracle Kubernetes Engine (OKE) with integrated automation.



### Prerequisites:

  **1. Before you can create a Kubernetes fleet in **StreamTime**, you need a user that belongs to a group with the right level of permissions in OCI.**  
  * **Create a Group** in OCI for StreamTime users (e.g., streamtime-admins).  
  * **Add your user** to this group.  
  * **Attach a policy** to the group that grants the required permissions. The policy should include the following statement:

            Allow group <group-name> to manage all-resources in compartment id <compartment-id>

  This ensures that StreamTime can provision, manage, and monitor all OCI resources (compute, networking, storage, and OKE clusters) within the specified compartment.

  **2. Generate an API key for the user. Refer to the official documentation-**  [Managing API Keys](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm#two)
<br>

#### Steps to Create a Bootstrap Provider on Oracle in StreamTime


**Step-1: Create a Bootstrap Provider**
Navigate to **Settings → Bootstrap Providers → Select OCI OKE → Next**  

![Creating a Bootstrap Provider showing identifier field and cloud provider options.][image1]




<br>

**Step-2: Fill in the Configuration Form**  

![Using the configuration file downloaded during API key creation, provide the following details][image2]

- **Tenancy OCID** – OCID of the OCI Tenancy in which the resources should be created.  
- **User OCID** – OCID of the IAM user StreamTime will use to create and manage resources.  
- **Key Fingerprint** – Fingerprint of the above user’s API key.  
- **Private Key** – Paste the PEM private key that matches the API key.  
- **Defined Tags** – Tags that StreamTime will automatically apply to every OCI resource it provisions (compute, networking, storage, OKE). Enter tags as `namespace.key=value`. Using defined tags ensures consistent ownership, cost allocation, governance, and auditing across all StreamTime-created resources. When you create the tag key definition, you choose its value type, which determines how users assign values to resources. StreamTime automatically applies these defined tags to all resources it creates in OCI. 
**You can add multiple tags,** ensuring that every compute, network, and storage resource provisioned through StreamTime is consistently tagged under your chosen namespace, making it easier to:  

  * Track resource ownership and usage  
  * Align deployments with cost centers or projects  
  * Enforce governance policies  
  * Simplify reporting and auditing across your environment  

By defining and applying these tags at the StreamTime level, you get end-to-end visibility and control over your OCI resources without needing to manually tag them later.  
[Learn more about defined tags in Oracle Cloud Infrastructure](https://docs.oracle.com/en-us/iaas/Content/Tagging/Tasks/managingtagsandtagnamespaces.htm#overviewtags)  


[image1]: ../assets/images/oci/create-bootstrap-provider-basic-info.png

[image2]: ../assets/images/oci/create-bootstrap-provider-oci-credentials.png
---

## When to Use Oracle (OKE)

- **Oracle Cloud Preference**: When your workloads or data reside primarily in OCI.
- **OKE Features**: If you want to leverage Oracle’s managed Kubernetes capabilities.
- **Enterprise Integration**: For organizations using Oracle Cloud services and databases.
- **Regional Compliance**: When you need to deploy clusters in specific OCI regions for compliance or latency.

---

## Key Features

- **Managed Kubernetes (OKE)**: Automated provisioning and management of OKE clusters.
- **Flexible Tenancy**: Support for shared, isolated, or dedicated tenancy models.
- **Integrated Security**: Leverage OCI IAM and security features.
- **Scalable Throughput**: Define Kafka units and scale clusters as needed.
- **Placement Options**: Deploy in any supported OCI region.

---

## How to Deploy on Oracle (OKE)




### Prerequisites:

* An OCI account with appropriate permissions.  
* API keys configured in Streamtime for OCI access.  
* A defined compartment in OCI where the fleet will live.  
* A Base Domain is required (you can add it in the Settings Panel).   
* (Optional) SSH key for accessing worker nodes.

<br>

#### Steps to Create a OKE on StreamTime

**Step-1:Bootstrap provider selection**  
Navigate to  **Bootstrap Providers → Add Kubernetes Fleet → Select OCI OKE** 


**![Selection screen to choose a Bootstrap Provider, including Bring Your Own Kubernetes, AWS EKS, GCP GKE, OCI OKE, and Azure AKS.][image3]**

<br> 

**Step-2: Basic Configuration** 
 Basic Configuration step with fields for Identifier, Tenancy, Base Domain, Alert Channels, and sliders for Max Tenants and Max Kafka Units
**![Basic Configuration step with fields for Identifier, Tenancy, Base Domain, Alert Channels, and sliders for Max Tenants and Max Kafka Units][image4]**

* **Identifier**

  * A unique name you assign to your Kubernetes fleet (Use the auto-generated name or provide your own unique name. Here it is `scared-finch`).

  * Must be unique within your account.

* **Tenancy**

  * Defines how resources are shared, refer the docs for more information [Tenancy in Streamtime](https://docs.streamtime.ai/concept-architecture/tenancy.html#tenancy)

* **Base Domain**

  * The root domain used for accessing services in the fleet.

  * For example: if you set example.com, your workloads will be exposed as service.example.com.

  * The Base Domain must be configured prior to fleet creation if it’s not already set in the Settings panel., Refer to the docs on [Domains](https://docs.streamtime.ai/setup/domains-certificates.html)


* **Alert Channels**

  * Where Streamtime will send alerts for fleet events (scaling issues, failures, upgrades, etc.).

  * Can be things like Slack channels, Email etc

* **Max Tenants**

  * The maximum number of tenants (isolated workspaces or projects) that can be hosted in this fleet.

  * Example: If you set 5, you can host up to 5 different tenants (clusters) on this fleet.

* **Max Kafka Units**

  * The maximum Kafka capacity units (a resource abstraction Streamtime uses for sizing Kafka clusters).

  * One “Kafka Unit” typically maps to a certain amount of broker resources (CPU, memory, storage, throughput). Refer, [Scaling Kafka Clusters in Streamtime](https://docs.streamtime.ai/concept-architecture/tenancy.html#tenancy)

  * Setting this defines how much Kafka workload this fleet can handle.

  * Example: If you set 10, tenants can request Kafka resources up to 10 units in total.

<br> 

**Step-3: Placement Configuration** 

**![OCI Placement configuration form with fields for Account, Region, and Compartment OCID.][image5]**

* **Account** 
  * This is the OCI account you already onboarded into Streamtime (via API keys).

  * Example: fantastic-guan (your configured account).

* **Region**
  *  The OCI region where your Kubernetes fleet (and Kafka Cluster cluster) will be deployed.

  * Example: ap-hyderabad-1.

* **Compartment OCID** 
  * You must paste the OCID of the OCI compartment where your Kubernetes resources should live.

  * This decides which compartment Streamtime will use to spin up the fleet/cluster.

  * Navigate to: Identity & Security → Compartments → [Your Compartment] → OCID

  * Looks like: ocid1.compartment.oc1..aaaaaaaexampleuniqueID12345

  <br>

  **In the OCI Console, you can locate your Compartment OCID by navigating to:**  

    OCI Console → Identity & Security → Compartments → [Your Compartment] → OCID

<br> 

**Step-4: Advanced Configuration**  

**![Advance configuration form with fields for VCN, Node Shape, KMS Key OCID,Checkbox for Public cluster, API Server Allowed CIDRs and SSH Public Key.][image6]**

* **VCN (Virtual Cloud Network)**

  * The VCN provides the networking backbone for your Kubernetes fleet, including subnets for both the control plane and worker nodes.

  * You can **create a new VCN** or **select an existing VCN** from your OCI account.

  * Streamtime will use this VCN to allocate IP addresses, route traffic, and manage network security for the cluster.

    **Tip:** Ensure the VCN has enough IP address space for all nodes and services in your fleet.  
    

* **Node Shape**  
  * This defines the compute instance shape for worker nodes
     

* **KMS Key OCID** (Optional)

  * KMS Key OCID (Optional): If you have a customer-managed encryption key stored in OCI Vault, you can specify its OCID (Oracle Cloud Identifier) here. This key will be used to securely encrypt your Kubernetes cluster data and node volumes, providing an additional layer of data protection and control over encryption keys. If you choose to leave this field blank, Oracle-managed encryption keys will be used by default, meaning Oracle handles all encryption management without requiring you to specify a custom key. Using a customer-managed key gives you greater control over key lifecycle, rotation, and access, enhancing your overall security posture.

* **Public Cluster**(Checkbox)

  * If checked, the Kubernetes API server endpoint will be publicly accessible.

  * If unchecked, it will be private and accessible only within the VCN.

*  **API Server Allowed CIDRs**

    * These are CIDR ranges allowed to access the Kubernetes API server (control plane) and for SSH into worker nodes.

    * Example shown: 0.0.0.0/0 → This means the API server is open to all IPs (security risk).

    * Best practice: Restrict to your office IP or VPN CIDR (e.g., 203.x.x.x/32).

*  **SSH Public Key**

    * Here you can provide your SSH public key.  
    * This allows you to SSH into the OKE worker nodes.

    * If left blank, you won’t be able to SSH into nodes directly (still manageable via Kubernetes API).

[image3]: ../assets/images/oci/bootstrap-provider-selection.png
[image4]: ../assets/images/oci/basic-configuration-oci.png
[image5]: ../assets/images/oci/oci-placement-configuration.png
[image6]: ../assets/images/oci/oci-advance-configuration.png

---

## **Creating a Confluent for Kubernetes (CFK) Cluster on OCI with StreamTime**

Oracle Cloud Infrastructure (OCI) is supported in StreamTime as a deployment provider, allowing you to create and manage **Confluent for Kubernetes (CFK)** clusters on **Oracle Kubernetes Engine (OKE)** with built‑in automation, observability, and guardrails.

#### **What StreamTime Creates for You**

* **CFK Components**: Kafka brokers (KRaft or ZooKeeper‑based depending on CP version), Schema Registry (if enabled), REST Proxy/Control Center (when selected), and supporting services.  
* **Kubernetes Objects**: Namespaces, Deployments/StatefulSets, Services (LB/ClusterIP), PersistentVolumeClaims.  
* **Networking**: LoadBalancers/ingress according to your **Outbound Access** and **Private Access** choices.  
* **Storage**: Block Volumes‑backed Persistent Volumes sized per your config.

### **Prerequisites**

* **An OCI Kubernetes Fleet**  
Before you can create a CFK cluster, ensure that you have a **Kubernetes Fleet** already bootstrapped on OCI OKE using StreamTime.

* **Cluster-Level Permissions**  
The user or group must have sufficient permissions in OCI to deploy workloads into the fleet. This includes access to compute, networking, and Kubernetes resources in the selected compartment.

#### **Steps to Create a CFK Cluster on OCI in StreamTime**

**Step-1: Select Cluster Type**
Navigate to **Clusters → Create Cluster →** select **Confluent Platform** (Commercial) **→** Click **Begin Configuration**.



![Cluster Type selection screen showing options for Confluent Platform, Apache Kafka, WarpStream, Redpanda, and AutoMQ. ][image7]

**Step-2: Basic Configuration**
Configure the core identity and placement of your CFK cluster.


![The Basic Configuration form that includes the Identifier field that is filled as juicy-antelope here (Is auto-generated or can be filled manually), a tag that can be set (Multiple tags can be added), and the cloud provider OCI is selected with your preferred region, tenancy and and Kafka Units slider.][image9]

* **Identifier**  
  * Human-readable cluster ID  
  * Auto-generated (editable). Use lowercase letters and hyphens; must be unique per project.  
  * *Example*: `juicy-antelope`

* **Tags**  
  * Key/value labels applied to StreamTime objects  
  * Useful for environment, owner, cost-center, etc.  
  * *Example*: `environment=non-prod`

* **Cloud Provider**  
  * Target cloud for deployment  
  * *Guidance*: Choose **OCI**  
* **Region**  
  * OCI region where the Fleet is created  
  * Must match an existing Fleet region  
  * *Example*: `ap-hyderabad-1`  
* **Tenancy**  
  * Defines the resource sharing model  
  * Options: **Shared**, **Dedicated** or **Isolated,** Refer to the docs on [Tenancy](https://docs.streamtime.ai/concept-architecture/tenancy.html#tenancy)  
* **Kafka Units (KU)**  
  * Baseline throughput capacity  
  * Each KU ≈ 20 MB/s aggregate  
* **Alert Channels**  
  * Health and incident notifications  
  * Optional; choose Slack/Email channels configured in Settings

<br>

**Sizing Tip-**
1 KU (\~20 MB/s) is good for dev/test or light prod. For production with replication factor \= 3 and bursty writes, consider higher suitable KU to avoid broker IO saturation.

<br>

**Step‑3: Fleet Selection**
* Select the OKE Fleet that will host this CFK cluster.  
* Pick a Fleet with sufficient free capacity (OCPUs/RAM), available LB quotas, and the required Kubernetes version for your CFK/CP version.  
* This ensures that StreamTime deploys the Confluent Platform inside your existing OKE-based fleet.


![Fleet Selection dialog showing available OKE fleets and capacity/health status, with “juicy-cockroach” selected][image10]

Good to know: StreamTime validates Fleet health and versions before proceeding (e.g., Kubernetes API reachable, CNI/CSI ready, LB quota).

<br>

**Step-4: Advanced Configuration**
Fine‑tune networking, security, components, and storage.

**![Advance configuration of the OKE cluster][image11]**

* **Optimization Goal**
You have three choices for controlling how the cluster manages egress networking (traffic going out of the cluster):

  - **Cost** → Optimized for lowest cost.  
    - Limits or routes outbound traffic through shared, cheaper paths.  
    - Best for dev/test clusters where traffic is light.  

  - **Balanced (default)** → Mix between performance and cost.  
    - Suitable for most production environments.  
    - Provides decent throughput with moderate costs.  

  - **Performance** → Optimized for maximum throughput and lowest latency.  
    - Uses premium networking resources.  
    - Best for high-throughput, latency-sensitive production workloads.  


<br>

* **Cluster Access**
Controls how clients connect to Kafka brokers:

  - **Internal** → Only workloads inside the OKE VCN (Virtual Cloud Network) can access Kafka. (Good for private, secure setups where clients run in the same fleet.)  
  - **External** → Only external/public clients can connect (via public endpoints).  
  - **Internal & External** → Both OCI internal apps and external clients can connect.  

<br>

* **Authentication Mechanism**
Defines how clients authenticate to Kafka:

  - **SASL/OAUTH** → OAuth-based authentication.  
    - More secure, integrates with identity providers.  
    - Recommended for production.  

  - **SASL/PLAIN** → Username/password-based authentication.  
    - Simpler but less secure.  
    - More suitable for dev/test.  

<br>

* **Additional System Admins**
You can assign extra system administrators who will have full access to manage the CFK cluster.  

<br>

* **Admin Type**  
Instead of adding users one by one, you can assign an IAM Group. All members of that group will inherit admin privileges.  

<br>

* **Storage Tier Configuration**
Defines how Kafka tiered storage manages log segment offloading to external storage:

  - **Aggressive** → Offloads data to external storage quickly, keeping local disk usage minimal.  
    (Suitable when you want to optimize for cost and use cloud storage heavily)  

  - **Balanced** → Default option. Keeps a healthy balance between local disk and external storage usage.  

  - **Conservative** → Keeps data locally for longer before offloading to external storage.  
    (Useful if you want faster local access and rely less on cloud storage)  

<br>

* **Tiered Storage Bucket Name**
The name of the bucket where Kafka log segments will be stored once offloaded.  

<br>

* **Tiered Storage Provider**
Choose where offloaded Kafka data will be stored:

  - **AWS**  
    - **AWS Account** → Your AWS account ID.  
    - **Region** → The AWS region where your S3 bucket exists.  

  - **OCI**  
    - **OCI Account** → Your Oracle Cloud Infrastructure account ID (Tenancy OCID).  
    - **Region** → The OCI region where the bucket exists.  
    - **Compartment ID** → OCID of the compartment where the storage bucket resides.  
    - **Identity Domain OCID** → OCID of the identity domain used for access and authentication.  



**Once all steps are complete-**  
- Review the configuration.  
- Click **Create Cluster**.  

--- 

[image7]: ../assets/images/oci/create-Kafka-ClusterTypeSelection.png

[image9]: ../assets/images/oci/create-Kafka-Basic-configuratio.png

[image10]: ../assets/images/oci/create-Kafka-Fleet-Selection.png

[image11]: ../assets/images/oci/create-Kafka-Advance-configuration.png
