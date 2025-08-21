---
title: Kubernetes Day2 Standard Operating Procedures (SOP)
nav_order: 4
layout: Operations

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
1. Check node readiness and nsure all nodes have STATUS=Ready.
	```kubectl get nodes -o wide```
    
2. Check control plane components and verify etcd, scheduler, and controller-manager are healthy.
	```$> kubectl get componentstatuses```

3. Check pod health across namespaces. No pods should be stuck in CrashLoopBackOff or Pending state.
    ```$> kubectl get pods --all-namespaces```

4. Check persistent volumes. All PVs should be in Bound state.
	```$> kubectl get pv```
5. Check cluster events
    ```$> kubectl get events --sort-by=.metadata.creationTimestamp```

**Validation**
* All nodes show Ready status.  
* All pods in operational namespaces are running without restarts beyond acceptable thresholds.  
* No critical events are reported.

**Rollback**
* Not applicable; this SOP is for verification only.

### 2. Namespace Creation & Resource Quota Adjustment

**Purpose**  
 To create new Kubernetes namespaces or modify quotas for existing workloads while maintaining fair resource allocation.

**Prerequisites**
* kubectl access with appropriate RBAC permissions  
* Approved change request

**Procedure**
1. Create a new namespace
	```$\> kubectl create namespace \<namespace-name\>```
2. Apply a resource quota
    ```
    cat \<\<EOF | kubectl apply \-f \-  
    apiVersion: v1  
    kind: ResourceQuota  
    metadata:  
        name: \<quota-name\>  
        namespace: \<namespace-name\>  
    spec:  
        hard:  
            cpu: "10"  
            memory: 32Gi  
            pods: "50"  
    EOF
    ```
**Update quota if needed**
```$> kubectl edit resourcequota <quota-name> -n <namespace-name>```

**Validation**
```$> kubectl describe namespace <namespace-name>```
```$> kubectl describe resourcequota -n <namespace-name>```
Check that the quota matches approved values.

**Rollback**
* To delete namespace:
```$> kubectl delete namespace <namespace-name>```
* To revert quota changes, restore from the previous YAML definition.

### 3. Node Maintenance & Drain {#5.3-node-maintenance-&-drain}

**Purpose**  
 To safely perform maintenance on a Kubernetes node (e.g., kernel patching, hardware replacement) without impacting running workloads.

**Prerequisites**

* kubectl access with cluster-admin privileges  
* Maintenance window approved in change management system

**Procedure**

1. Mark node as unschedulable:  
```$> kubectl cordon <node-name>```

2. Drain workloads from the node:  
```$> kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data```

3. Perform maintenance (OS updates, hardware replacement, etc.).  
4. Bring node back into scheduling:  
   $\> kubectl uncordon \<node-name\>

**Validation**

* *‘*kubectl get nodes*’* shows nodes in Ready state.  
* No workloads stuck in Pending state after uncordoning.

**Rollback**
* If maintenance fails, uncordon the node to resume workload scheduling.

### 4. Restart Kafka Brokers (CFK)

**Purpose**  
To restart Kafka broker pods running under Confluent for Kubernetes without causing downtime.

**Prerequisites**
* kubectl access with namespace permissions for CFK  
* Confirm rolling restart strategy in Kafka configuration

**Procedure**
1. Identify broker pods:  
   ```$> kubectl get pods -n <cfk-namespace\> -l app=kafka```
2. Restart a broker (one at a time):  
```$> kubectl delete pod <broker-pod-name> -n <cfk-namespace>```
3. Wait for the pod to be recreated and reach Running state before restarting the next broker.

**Validation**

* Verify all brokers are in Running state.
```kubectl get pods```
* Kafka client tests confirm no data loss or downtime.

**Rollback**
* If restart causes issues, redeploy from last known good configuration or scale from backup node pool.

### 5. Download Logs

**Purpose**  
To collect relevant logs for troubleshooting incidents within agreed SLA timelines.

**Prerequisites**

* kubectl access to affected namespaces  
* Storage location for saving logs

**Procedure**

1. Get logs for a specific pod (complete logs):  
```$> kubectl logs <pod-name> -n <namespace> ```
2. Get logs for last 2 hrs for a specific pod:
```$> kubectl lgos <pod-name> -n <namespace> --since=2h```
3. Get logs for last 1 hr for a specific pod:
```$> kubectl lgos <pod-name> -n <namespace> --since=1h```
2. For a previous container instance (if it restarted):  
```$> kubectl logs <pod-name> -n <namespace> --previous```
3. Export logs to a file:  
```$> kubectl logs <pod-name> -n <namespace> > /tmp/<pod-name>.log```
4. Compress and send logs to the incident tracker or client:  
```$> tar -czvf logs.tar.gz /tmp/*.log```

**Validation**

* Logs are complete for the specified time period.  
* Files are accessible to relevant teams.

**Rollback**
* Not applicable; log retrieval is read-only.

### 6. System Status Assessment

**Purpose**  
To perform a complete health assessment of the Kubernetes cluster and Confluent Platform components during incidents or routine audits.

**Prerequisites**
* kubectl access with read permissions to all relevant namespaces  
* Access to monitoring dashboards (Grafana, Prometheus, Confluent Control Center)

**Procedure**
1. Check Kubernetes node health:  
```$> kubectl get nodes -o wide```  
2. Check pod status for all namespaces:  
```$> kubectl get pods --all-namespaces```
3. Check Kafka broker status in Confluent Control Center or via CLI:  
```$> kafka-broker-api-versions --bootstrap-server <broker-list> ```
4. Check Kafka Controller Quorum (KRaft mode):  
```kubectl exec -it <kafka-pod> -n <namespace> -- kafka-metadata-quorum.sh describe --status```
5. Review cluster events for anomalies:  
```$> kubectl get events --sort-by=.metadata.creationTimestamp```

**Validation**
* All nodes are Ready.  
* No critical pods in CrashLoopBackOff or Pending.  
* Kafka brokers and Zookeeper nodes report healthy status.

**Rollback**
* Not applicable; assessment is read-only.

### 7. JMX Metrics Retrieval (Kafka & CFK)

**Purpose**  
 To gather JMX metrics from Kafka brokers for performance and health analysis.

**Prerequisites**
* JMX enabled in Kafka configuration  
* Access to JMX exporter endpoint or port-forward capability

**Procedure**
1. Identify the broker pod to collect metrics from:  
```$> kubectl get pods -n <namespace> -l app=kafka ```
2. Port-forward JMX port (e.g., 5555\) to local machine:  
```$> kubectl port-forward <broker-pod-name> -n <namespace> 5555:5555```  
3. Use JMX client (e.g., jconsole, jmxterm) to connect:  
```jconsole localhost:5555```  
4. Navigate through MBeans to retrieve metrics such as:  
   ```sh
   kafka.server:type=BrokerTopicMetrics  
   kafka.network:type=RequestMetrics  
   kafka.controller:type=KafkaController
   ```

**Validation**
* Metrics are accessible without errors.  
* Data matches expectations based on workload.

**Rollback**
* Close port-forward session and disconnect JMX client.

### 8. Enhanced / Extended Alerts Setup

**Purpose**  
To configure and validate monitoring alerts for proactive issue detection.

**Prerequisites**
* Access to Prometheus and Alertmanager configuration  
* Access to Slack, email, or PagerDuty for notifications

**Procedure**
1. Review existing alert rules in Prometheus:  
```$> kubectl get configmap prometheus-server -n <namespace> -o yaml```
2. Add new alert rules (e.g., high broker CPU, partition under-replicated):  
```Update Prometheus rule files with thresholds. ```
3. Reload Prometheus configuration:  
```$> kubectl delete pod <prometheus-pod> -n <namespace>```
4. Test alert by simulating conditions (e.g., scale down a broker).  
5. Verify alert delivery to configured channels (Slack/PagerDuty).

**Validation**
* Alert triggers when threshold is breached.  
* Notifications are received in the correct channel.

**Rollback**
* Restore previous alert rule configuration from backup.

### 9. Cluster Creation

**Purpose**  
To provision new Kubernetes clusters or namespaces for CFK workloads and ensure smooth daily operations.

**Prerequisites**
* Approved cluster sizing plan  
* Access to infrastructure provisioning tool (e.g., Terraform, eksctl, gcloud CLI, kubectl)  
* Network and security configurations approved

**Procedure**

1. Provision the cluster using the approved method (Terraform, eksctl, gcloud CLI, etc.).  
2. Configure RBAC roles and service accounts for application teams.  
3. Deploy CFK Operator and required CRDs.  
4. Deploy Kafka, Zookeeper, Schema Registry, Connect, and other Confluent components.  
5. Verify deployments by checking pod status and running test workloads.  
6. Document cluster details and update BAU runbook.

**Validation**
* All components are deployed and running.  
* Cluster passes initial health checks.

**Rollback**
* Destroy the cluster using the same tool (terraform destroy, eksctl delete cluster, etc.) if provisioning fails.
 

### 10. Credential Addition

**Purpose**  
 To securely add or rotate credentials for Kafka, Schema Registry, Connect, or Kubernetes RBAC accounts.

**Prerequisites**

* Approval from change management  
* Access to secret management system (Kubernetes Secrets, HashiCorp Vault, etc.)

**Procedure**
1. Create or update Kubernetes Secret:
```kubectl create secret generic <secret-name> --from-literal=username=<user> --from-literal=password=<password> -n <namespace>``` 
2. Patch the deployment or StatefulSet to mount the updated secret.  
3. Restart affected pods if they don’t pick up new secrets automatically.

**Validation**
* Applications authenticate successfully using new credentials.

**Rollback**
* Restore previous secret from backup or Vault.

### 11. Confluent Platform (CP) Upgrades

**Purpose**  
 To upgrade CFK-managed Confluent components to a newer supported version.

**Prerequisites**
* Compatibility check completed  
* Backup of data and configurations  
* Maintenance window approved

**Procedure**
1. Review release notes for the target CFK version (check compatibility with Kubernetes and CP)
2. Backup existing CFK configuration:
```$> kubectl get confluent -n <namespace> -o yaml > cfk-all-backup.yaml```
3. Upgrade the CFK Operator Helm chart or manifest:  
   * For Helm: 
     ```$> helm upgrade cfk confluentinc/confluent-for-kubernetes --version <target-version>```
   * For YAML manifests: apply the updated manifest
4. Monitor Operator logs to ensure no failures:
```kubectl logs -n <namespace> deploy/confluent-operator```
5. Sequentially upgrade platform components (Kafka, Zookeeper, Connect, SR, etc.) using the updated CRDs.
6. Validate:  
   * Check cluster health via:
```$> kubectl get pods```
   * Verify Kafka broker status (logs, metrics, JMX).  
   * Run smoke tests (produce/consume to a test topic).

**Expected Outcome**:
* Operator and all Confluent Platform pods run with the new version.  
* No disruption to workloads beyond expected rolling restart downtime.

**Validation**
* All components run the new version.  
* No errors in logs after upgrade.

### 12. Operator Upgrades

**Purpose**  
To upgrade the Confluent for Kubernetes (CFK) operator to the latest stable version.

**Prerequisites**
* Review release notes for breaking changes  
* Backup existing CRDs and configurations

**Procedure**
1. Download the updated operator manifest from Confluent’s repository.  
2. Apply the updated manifest:  
```$> kubectl apply -f <cfk-operator-manifest>.yaml```
3. Monitor operator pod restart and logs.

**Validation**
* Operator pod runs the new version.  
* Managed resources are unaffected.

**Rollback**
* Reapply previous operator manifest from backup.

### 13. Rollback Procedure
**Purpose**
Safely revert to a previous stable CFK version if upgrade fails.

**Procedure**
1. Identify previous working version of CFK.  
2. Roll back Operator:
   * Helm: ```helm rollback cfk <revision>```
   * YAML: apply the last known good manifest.
3. Restore backup CRDs and custom resources from pre-upgrade YAMLs.  
4. Restart affected pods if needed: 
   ```$> kubectl rollout restart statefulset <component>```
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
