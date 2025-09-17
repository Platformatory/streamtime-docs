---
#title: Confluent Platform Day2 Standard Operating Procedures (SOP)
nav_order: 4
parent: Operations

---

# Introduction

This document serves as the Day 2 Operations Runbook for managing Kubernetes clusters deployed with Confluent for Kubernetes (CFK) in a production environment. It contains detailed Standard Operating Procedures (SOPs) for operational tasks, incident handling, and lifecycle management to ensure the cluster and Confluent Platform components remain secure, stable, and performant after initial deployment.

**Purpose**

* Provide a single reference for daily operational tasks, troubleshooting, and change management.  
* Reduce operational risk by defining consistent processes for common maintenance and incident scenarios.  
* Enable faster resolution times through documented step-by-step procedures and validation checks.

**Audience**

This runbook is intended for:

* Site Reliability Engineers (SREs)  
* DevOps Teams  
* Incident Response Teams

# Scope 

This runbook defines the operational processes, maintenance routines, and incident-handling procedures for Kubernetes and Confluent Platform in a production setting. It covers Day 2 operations, all activities performed after the initial cluster deployment and to ensure continuous availability, scalability, and security.

## &nbsp;&nbsp;In Scope 

* **Kubernetes Day 2 Operations**  
  * Cluster maintenance and upgrades  
  * Node lifecycle management (add/remove/drain/maintenance)  
  * Namespace and resource quota adjustments  
  * Persistent volume management  
  * Network policy changes  
  * Monitoring, alerting, and logging setup  
  * Backup and restore procedures (*if applicable*)  
  * Security patching (*if applicable*)


* **CFK / Confluent Platform Day 2 Operations**  
  * Broker restart procedures  
  * System status assessment  
  * Log retrieval and retention  
  * JMX metrics collection  
  * Enhanced/extended alerting setup  
  * Cluster creation and BAU support  
  * Credential and RBAC management  
  * Confluent Platform upgrades  
  * Operator upgrades  
  * Connector lifecycle management  
  * Capacity planning and scaling  
  * Security updates for Kafka components  
* **Incident Response**  
  * Severity classification (P1, BAU)  
  * Escalation and communication protocol  
  * On-call roster management  
* **Change Management**  
  * Request submission, approval workflow  
  * Audit trail and rollback procedures

## &nbsp;&nbsp;Out of Scope

* Initial design and deployment of Kubernetes clusters (Day 0/Day 1 activities)  
* Application-level configuration or business logic changes  
* Vendor-specific SLA enforcement outside the agreed operational scope  
* Direct management of non-Kubernetes infrastructure 

# Day 2 Operations Overview

**Definition**

Day 2 operations refer to all post-deployment activities required to keep the Kubernetes cluster and Confluent Platform workloads running efficiently. Where Day 0 is planning and Day 1 is deployment, Day 2 is about ongoing care, feeding, and evolution of the system.

**Key Objectives**

* Maintain cluster health and application availability.  
* Ensure security and compliance through patches, upgrades, and RBAC enforcement.  
* Enable scalability as workloads and traffic grow.  
* Detect and resolve incidents quickly to minimize downtime.  
* Provide operational actions for audit purpose

**Primary Activities in Day 2**

* **Monitoring & Health Checks** – Continuous observation of cluster and Kafka components, with proactive remediation for anomalies.  
* **Capacity & Performance Management** – Scaling nodes, adjusting resource quotas, and tuning workloads to prevent bottlenecks.  
* **Incident Handling** – Classifying issues (P1, BAU), executing predefined SOPs, and ensuring communication to stakeholders.  
* **Maintenance Tasks** – Controlled restarts, version upgrades, security patching, and operator updates.  
* **Change Management** – Applying new configurations or features in a controlled and reversible manner.  
* **Security Operations** – Managing credentials, RBAC roles, network policies, and security scans.  
* **Backup & Recovery** – Ensuring business continuity through tested recovery procedures.

# Support Model & SLA

A well-defined Support Model ensures that incidents are handled efficiently, with clear escalation paths and measurable Service Level Agreements (SLAs) for different severity. This section outlines how the support team will operate, who responds, and how quickly issues are resolved.

### **Support Model Structure**

* **Engineering / Vendor Support**  
  * Addresses product defects, advanced performance tuning, and deep-root cause analysis.  
  * Works with Confluent or Kubernetes vendors as needed.

### **Communication Channels**

* **Primary:** Incident Tracker  
* **Secondary:**   
  * WhatsApp group   
  * Slack Channel

### **SLA Definitions**

| Severity | Description | Response Time |
| ----- | :---- | ----- |
| **Critical** | Complete outage or severe degradation impacting production with no workaround. | 30 minutes |
| **Others** |  Functionality loss or performance impact with a workaround available | 60 mins \- 2 Hrs |

* Engineering Team/Vendor acknowledges the incident in Incident Tracker within SLA response time.  
* Keep the client updated at agreed communication intervals.

# Kubernetes Day 2 SOPs

This section documents step-by-step procedures for core Kubernetes operational tasks. Each SOP follows the structure:

* **Purpose** – Why the task is needed.  
* **Prerequisites** – Access, permissions, or tools required.  
* **Procedure** – Step-by-step commands and actions.  
* **Validation** – How to confirm successful execution.  
* **Rollback** – How to revert changes if needed.

### 1.  Cluster Health Verification

**Purpose**
 To confirm that the Kubernetes cluster is functioning correctly, all nodes are ready, and workloads are running as expected.

**Prerequisites**
* kubectl access with cluster-admin privileges  
* Access to monitoring tools (Prometheus/Grafana or equivalent)

**Procedure**
1. Check node readiness and ensure all nodes have STATUS=Ready.
```bash
$> kubectl get nodes -o wide
```
    
2. Check control plane components and verify etcd, scheduler, and controller-manager are healthy.
```bash
$> kubectl get componentstatuses
```

3. Check pod health across namespaces. No pods should be stuck in CrashLoopBackOff or Pending state.
```bash
$> kubectl get pods --all-namespaces
```

4. Check persistent volumes. All PVs should be in Bound state.
```bash
$> kubectl get pv
```

5. Check cluster events
```bash
$> kubectl get events --sort-by=.metadata.creationTimestamp
```

**Validation**
* All nodes show Ready status.  
* All pods in operational namespaces are running without restarts beyond acceptable thresholds.  
* No critical events are reported.

**Rollback**
* Not applicable; this SOP is for verification only.

### 2. Node Maintenance & Drain {#5.3-node-maintenance-&-drain}

**Purpose**  
 To safely perform maintenance on a Kubernetes node (e.g., kernel patching, hardware replacement) without impacting running workloads.

**Prerequisites**

* kubectl access with cluster-admin privileges  
* Maintenance window approved in change management system  
* Ensure sufficient cluster capacity to reschedule workloads from the node being drained:  
  * Add a new node or confirm that existing nodes have enough spare resources.  
  * If workloads include Kafka pods, verify pod anti-affinity rules are satisfied — checking capacity alone may not be sufficient to guarantee successful rescheduling.
  
**Procedure**

1. Mark node as unschedulable:  
```bash
$> kubectl cordon <node-name>
```

2. Drain workloads from the node:  
```bash
$> kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

3. Perform maintenance (OS updates, hardware replacement, etc.).  
4. Bring node back into scheduling:  
   $> kubectl uncordon <node-name>

**Validation**

* *‘*kubectl get nodes*’* shows nodes in Ready state.  
* No workloads stuck in Pending state after uncordoning.

**Rollback**
* If maintenance fails, uncordon the node to resume workload scheduling.

### 3. Restart Kafka Brokers (CFK)

**Purpose**  
To restart Kafka broker pods running under Confluent for Kubernetes without causing downtime.

**Prerequisites**
* kubectl access with namespace permissions for CFK  
* Confirm rolling restart strategy in Kafka configuration

**Procedure**

*Option A – Restart all brokers sequentially using StatefulSet rollout (preferred for full restart):*

1. Identify the StatefulSet managing Kafka brokers:
```bash
$> kubectl get statefulsets -n <cfk-namespace>
```
2. Trigger a rolling restart:
```bash
$> kubectl rollout restart statefulset <kafka-statefulset-name> -n <cfk-namespace>
```
3. Monitor rollout status:
```bash
$> kubectl rollout status statefulset <kafka-statefulset-name> -n <cfk-namespace>
```

**Validation**

* Verify all brokers are in Running state:
```bash
$> kubectl get pods -n <cfk-namespace> -l app=kafka
```
* Kafka client tests confirm no data loss or downtime.

**Rollback**
* If restart causes issues, redeploy from last known good configuration or scale from backup node pool.
*Option B – Restart individual brokers manually (one at a time):*  
1. Identify broker pods:  
```bash
   $> kubectl get pods -n <cfk-namespace> -l app=kafka
```
2. Restart a broker (one at a time):  
```bash
$> kubectl delete pod <broker-pod-name> -n <cfk-namespace>
```
3. Wait for the pod to be recreated and reach Running state before restarting the next broker.

**Validation**

* Verify all brokers are in Running state.
```bash
$> kubectl get pods
```
* Kafka client tests confirm no data loss or downtime.



**Rollback**
* If restart causes issues, redeploy from last known good configuration or scale from backup node pool.

### 4. Download Logs

**Purpose**  
To collect relevant logs for troubleshooting incidents within agreed SLA timelines.

**Prerequisites**

* kubectl access to affected namespaces  
* Storage location for saving logs

**Procedure**

1. Get logs for a specific pod (complete logs):  
```bash
$> kubectl logs <pod-name> -n <namespace>
```
2. Get logs for last 2 hrs for a specific pod:
```bash
$> kubectl lgos <pod-name> -n <namespace> --since=2h
```
3. Get logs for last 1 hr for a specific pod:
```bash
$> kubectl lgos <pod-name> -n <namespace> --since=1hbash
```
2. For a previous container instance (if it restarted):  
```bash
$> kubectl logs <pod-name> -n <namespace> --previousbash
```
3. Export logs to a file:  
```bash
$> kubectl logs <pod-name> -n <namespace> > /tmp/<pod-name>.logbash
```
4. Compress and send logs to the incident tracker or client:  
```bash
$> tar -czvf logs.tar.gz /tmp/*.logbash
```

**Validation**

* Logs are complete for the specified time period.  
* Files are accessible to relevant teams.

**Rollback**
* Not applicable; log retrieval is read-only.

### 5. System Status Assessment

**Purpose**  
To perform a complete health assessment of the Kubernetes cluster and Confluent Platform components during incidents or routine audits.

**Prerequisites**
* kubectl access with read permissions to all relevant namespaces  
* Access to monitoring dashboards (Grafana, Prometheus, Confluent Control Center)

**Procedure**
1. Check Kubernetes node health:  
```bash
$> kubectl get nodes -o wide
```  
2. Check pod status for all namespaces:  
```bash
$> kubectl get pods --all-namespacesbash
```
3. Check Kafka broker status in Confluent Control Center or via CLI:  
```bash
$> kafka-broker-api-versions --bootstrap-server <broker-list>
bash```
4. Check Kafka Controller Quorum (KRaft mode):  
```bash
%> kubectl exec -it <kafka-pod> -n <namespace> -- kafka-metadata-quorum.sh describe --status
```
5. Review cluster events for anomalies:  
```bash
$> kubectl get events --sort-by=.metadata.creationTimestamp
```

**Validation**
* All nodes are Ready.  
* No critical pods in CrashLoopBackOff or Pending.  
* Kafka brokers and Zookeeper nodes report healthy status.

**Rollback**
* Not applicable; assessment is read-only.

### 6. JMX Metrics Retrieval (Kafka & CFK)

**Purpose**  
 To perform health check on Kafak Brokers for performance.

**Prerequisites**
* Streamtime UI 

**Procedure**
1. 

**Validation**
* Metrics are accessible without errors.  
* Data matches expectations based on workload.

**Rollback**
* Close port-forward session and disconnect JMX client.

### 7. Enhanced / Extended Alerts Setup

**Purpose**  
To configure and validate monitoring alerts for proactive issue detection.

**Prerequisites**
* Access to Prometheus and Alertmanager configuration  
* Access to Slack, email, or PagerDuty for notifications

**Procedure**
1. Review existing alert rules in Prometheus:  
```bash
$> kubectl get configmap prometheus-server -n <namespace> -o yaml
```
2. Add new alert rules (e.g., high broker CPU, partition under-replicated):  
```bash
Update Prometheus rule files with thresholds.
```
3. Reload Prometheus configuration:  
```bash
$> kubectl delete pod <prometheus-pod> -n <namespace>
```
4. Test alert by simulating conditions (e.g., scale down a broker).  
5. Verify alert delivery to configured channels (Slack/PagerDuty).

**Validation**
* Alert triggers when threshold is breached.  
* Notifications are received in the correct channel.

**Rollback**
* Restore previous alert rule configuration from backup.

### 8. Credential Addition

**Purpose**  
To securely add or rotate credentials in Confluent for Kubernetes (CFK), use Kubernetes Secrets or integrate with Vault. Credential updates for Kafka, Schema Registry, Connect, or Kubernetes RBAC accounts follow a similar pattern. 

**Prerequisites**

* Approval from change management  
* Access to secret management system (Kubernetes Secrets, HashiCorp Vault, etc.)
* Knowledge of the authentication mechanism enabled (e.g., SASL/PLAIN, SASL/SCRAM, Basic Auth, mTLS)


**Procedure**
**Using Kubernetes Secrects**

*Kafka (CFK, SASL/PLAIN)*  
1. Create a Kubernetes Secret with SASL/PLAIN user credentials:  
```bash
   kubectl create secret generic <user-secret> \
     --from-literal=username=<username> \
     --from-literal=password=<password> \
     -n <namespace>
```
2. Reference the secret in the Kafka CR under spec.kafka.authentication.type: plain.
3. Restart broker pods if changes are not picked up dynamically.

*Kafka (CFK, SASL/SCRAM)*

1. Create the user via the Confluent CLI or by updating the KafkaUser custom resource:
```bash
apiVersion: platform.confluent.io/v1beta1
kind: KafkaUser
metadata:
  name: <username>
  namespace: <namespace>
spec:
  authentication:
    type: scram-sha-512
```
2. Apply the resource:
```bash
kubectl apply -f <kafkauser>.yaml
```

*Schema Registry (CFK, Basic Auth)*

1. Create a Kubernetes Secret for the Basic Auth credentials:
```bash
kubectl create secret generic <sr-credentials> \
  --from-literal=basic.username=<username> \
  --from-literal=basic.password=<password> \
  -n <namespace>
```
2. Update the Schema Registry CR to mount the secret under spec.config.
3. Restart the Schema Registry pod(s) if required.


*Redpanda (SASL/SCRAM)*

1. Use rpk acl user create to add a new SASL/SCRAM user:
```bash
rpk acl user create <username> -p <password> --api-urls <redpanda-broker>
```

2. Update client configurations with the new credentials.

**Validation**

* Clients can authenticate using the new credentials.
* Relevant pods (Kafka, Schema Registry, Redpanda) show no authentication errors in logs.

**Rollback**

* Revert to the previous credentials from backup or Vault.
* Remove the faulty user/secret if authentication fails.


### 9. Upgrade Confluent For Kubernetes (CFK)

**Purpose**  
 To upgrade CFK-managed Confluent components to a newer supported version. The following paths are supported:
 
 Upgrade both Confluent Platform and CFK:
 
 Step 1. Upgrade CFK.
 Step 2. Upgrade Confluent Platform Using Confluent for Kubernetes.


**Prerequisites**
* Compatibility check completed  
* Backup of data and configurations  
* Maintenance window approved

**Procedure**
1. If upgrading CFK 2.x to 3.x to deploy and manage Confluent Platform 7.x, set the annotation for the components you want to use Log4j:
```bash
kubectl annotate <CR kind> <CR name> \
    platform.confluent.io/use-log4j1=true \
     --namespace <namespace>
```
The ```platform.confluent.io/use-log4j1=true``` annotation is required to use Confluent Platform 7.x with CFK 3.0+.

2. Disable resource reconciliation - To prevent Confluent Platform components from rolling restarts, temporarily disable resource reconciliation of the components in each namespace where the Confluent Platform is deployed, specifying the CR kinds and CR names (*whichever is applicable*):

```bash
kubectl annotate connect connect \
    platform.confluent.io/block-reconcile=true \
     --namespace <namespace>
```
```bash
kubectl annotate controlcenter controlcenter \
     platform.confluent.io/block-reconcile=true \
     --namespace <namespace>
```
```bash
kubectl annotate kafkarestproxy kafkarestproxy \
     platform.confluent.io/block-reconcile=true \
     --namespace <namespace>
```
```bash
kubectl annotate kafka kafka \
     platform.confluent.io/block-reconcile=true \
     --namespace <namespace>
```
```bash
kubectl annotate ksqldb ksqldb \
     platform.confluent.io/block-reconcile=true \
     --namespace <namespace>
```
```bash
kubectl annotate schemaregistry schemaregistry \
     platform.confluent.io/block-reconcile=true \
     --namespace <namespace>
```
```bash
kubectl annotate kraftcontroller kraftcontroller \
     platform.confluent.io/block-reconcile=true \
     --namespace <namespace>
```

3. Add the CFK Helm repo:
```bash
helm repo add confluentinc https://packages.confluent.io/helm
```
```bash
helm repo update
```

4. Get the CFK chart
* From the Helm repo
  
  a. Get the latest CFK chart
```bash
helm pull confluentinc/confluent-for-kubernetes --untar
```

  b. Get a specific version of the CFK chart
```bash
helm pull confluentinc/confluent-for-kubernetes --version <CFK image tag> --untar
```

5. Upgrade Confluent Platform custom resource definitions (CRDs)
```bash
kubectl apply -f confluent-for-kubernetes/crds/
```

**If the command returns an error similar to the below:**
```bash
The CustomResourceDefinition "kafkas.platform.confluent.io" is invalid:
metadata.annotations: Too long: must have at most 262144 bytes make: ***
[install-crds] Error 1
```

Run the following command:
```bash
kubectl apply --server-side=true -f <CRD>
```

**If running kubectl apply with the --server-side=true flag returns an error similar to the below:**
```bash
Apply failed with 1 conflict: conflict with "helm" using
apiextensions.k8s.io/v1: .spec.versions Please review the fields
above--they currently have other managers.
```

Run kubectl apply with an additional flag, --force-conflicts:

```bash
kubectl apply --server-side=true --force-conflicts -f <CRD>
```

6. Upgrade CFK

Find the default values.yaml file:
```bash
mkdir -p <CFK-home>

helm pull confluentinc/confluent-for-kubernetes \
  --untar \
  --untardir=<CFK-home> \
  --namespace <namespace>
```

The `values.yaml` file is in the `<CFK-home>/confluent-for-kubernetes` directory. Create a copy of the `values.yaml` file to customize CFK configuration. Do not edit the default `values.yaml` file. 

Save your copy to any file location; we will refer to this location as `<path-to-values-file>`. Open `values.yaml` and modify parameter `namespaced: false`

In values.yaml, set parameter `namespaced: false`

**Install CFK using the customized configuration**
```bash
helm upgrade --install confluent-operator \
  confluentinc/confluent-for-kubernetes \
  --values <path-to-values-file> \
  --namespace <namespace>
```

7. Upgrade CFK to a specific version, such as a hotfix or a patch version (if applicable) - *If Applicable* 

In values.yaml, update the CFK image.tag to the image tag of the CFK version specified in Confluent for Kubernetes image tags:

```bash
image:
  tag: "<CFK image tag>"
```
  
Run the following command:
```bash
helm upgrade --install confluent-operator \
  confluentinc/confluent-for-kubernetes \
  --values <path-to-values-file> \
  --namespace <namespace>
```


8. Enable resource reconciliation for each Confluent Platform components that you disabled reconciliation in the first step above.
```bash
kubectl annotate <component CR kind> <cluster name> \
  platform.confluent.io/block-reconcile- \
  --namespace <namespace>
```

9. Upgrade CFK init container

In each Confluent Platform component CR, update the CFK init container image tag to the version of CFK you are upgrading to

```bash
kind: <Confluent component>
spec:
  image:
    init: confluentinc/confluent-init-container:<CFK_version>
```

### 9. Upgrade Confluent Platform Using Confluent for Kubernetes

**Purpose**  
 To upgrade CFK-managed Confluent Platform components to a newer supported version. 

**Prerequisites**
* Compatibility check completed  
* Backup of data and configurations  
* Maintenance window approved

**NOTE**

Upgrade KRaft-based Confluent Platform 7.x deployments in the following order:

1. KRaft
2. Kafka
3. Other Confluent components, excluding Control Center and Control Center (Legacy), in any order
4. Control Center


Upgrade KRaft-based Confluent Platform 8.0.0 deployments in the following order. For more information, see Upgrade Control Center from 2.0 or 2.1 to 2.2 in Confluent Platform 8.0.

1. Control Center
2. KRaft
3. Kafka
4. Other Confluent components, excluding Control Center and Control Center (Legacy), in any order

**Procedure**
1. Review release notes for the target CFK version (check compatibility with Kubernetes and CP)
2. Backup existing CFK configuration:
```bash
$> kubectl get confluent -n <namespace> -o yaml > cfk-all-backup.yaml
```
3. Upgrade KRaft

a. In the KRaftController CR, update the component image tag. The tag is the Confluent Platform release you want to upgrade to.
```bash
kind: KRaftController
spec:
  image:
    application: confluentinc/cp-server:<tag>
```

b. In the same KRaftController CR, verify that the CFK init container image tag has been updated during the CFK upgrade process. The image tag should be the current version of CFK
```bash
spec:
  image:
    init: confluentinc/confluent-init-container:3.0.0
```

c. Upgrade KRaft
```
kubectl apply -f <KRaftController CR> --name <namespace>
```

4. Upgrade Kafka

Upgrade Kafka that is deployed in the KRaft mode to the latest version in the following steps:

a. In the Kafka CR, update the component image tag. The tag is the Confluent Platform release you want to upgrade to.
```bash
kind: Kafka
spec:
  image:
    application: confluentinc/cp-server:<tag>
```

b. In the same Kafka CR, verify that the CFK init container image tag has been updated during the CFK upgrade process. The image tag should be the current version of CFK
```bash
spec:
  image:
    init: confluentinc/confluent-init-container:3.0.0
```

c. Upgrade Kafka
```bash
kubectl apply -f <Kafka CR> --name <namespace>
```

5. Update metadata version of KRaft and Kafka
After verifying that the cluster behavior and performance meet your expectations, increment the metadata version for the controllers and brokers by running the kafka-features tool with the upgrade argument:

```bash
./bin/kafka-features upgrade --bootstrap-server <server:port> --metadata 4.0
```

6. Upgrade other Confluent Platform components

Upgrade Confluent Platform components as below:

a. In the component CR, update the component image tag. The tag is the Confluent Platform release you want to upgrade to:
```bash
spec:
  image:
    application: <component image>:<tag>
```

b. If upgrading Control Center, specify the Control Center release as the Control Center image tag, the Prometheus image tag, and the Alertmanager image tag in the ControlCenter CR. Control Center is on independent versions and does not follow Confluent Platform releases.

<c3-tag> is the Control Center release you are installing.

```bash
kind: ControlCenter
spec:
  image:
    application: confluentinc/cp-enterprise-control-center-next-gen:<c3-tag>
    init: confluentinc/confluent-init-container:3.0.0
  services:
    prometheus:
      image: confluentinc/cp-enterprise-prometheus:<c3-tag>
      pvc:
        dataVolumeCapacity: 10Gi
    alertmanager:
      image: confluentinc/cp-enterprise-alertmanager:<c3-tag>
```
c. In the same component CR, verify that the CFK init container image tag has been updated during the CFK upgrade process. The image tag should be the current version of CFK
```bash
spec:
  image:
    init: confluentinc/confluent-init-container:3.0.0
```

d. Upgrade the component
```bash
kubectl apply -f <component CR> --name <namespace>
```

**Expected Outcome**:
* Operator and all Confluent Platform pods run with the new version.  
* No disruption to workloads beyond expected rolling restart downtime.

**Validation**
* All components run the new version.  
* No errors in logs after upgrade.

### 12. Rollback Procedure

**Purpose**
Safely revert to a previous stable CFK version if upgrade fails.

**Procedure**
1. Identify previous working version of CFK.  
2. Roll back Operator:
   * Helm: ```bash
   helm rollback cfk <revision>
   ```
   * YAML: apply the last known good manifest.
3. Restore backup CRDs and custom resources from pre-upgrade YAMLs.  
4. Restart affected pods if needed: 
   ```bash
   $> kubectl rollout restart statefulset <component>
   ```
5. Verify Confluent Platform cluster stability:  
   * Brokers should form quorum.  
   * Schema Registry, Connect, ksqlDB should serve requests.
6. Communicate rollback action to stakeholders.

**Expected Outcome**:
* Cluster returns to the last known working version.  
* No lingering upgrade artifacts or partial deployments.

**Monitoring and Validation**

* **During upgrade/rollback**:
  * Watch `kubectl get pods -w` for rolling restart progress.  
  * Monitor Kafka broker logs for rebalancing or ISR shrinkage.  
  * Track Prometheus/Grafana dashboards (CPU, memory, partitions, lag).

* **Post change**:
  * Confirm health checks  
  * Validate Confluent Control Center dashboards (if deployed)  
  * Run integration tests (producers/consumers, connector tasks)
  
  
[//]: #
  [Upgrade CFK]: <https://docs.confluent.io/operator/current/co-upgrade-cfk.html#co-upgrade-cfk>
