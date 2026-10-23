Requirements Analysis: BYOVM Fleet and Kafka on BYO VMs
Scope reviewed
I reviewed the two plans associated with the BYO VM/Kafka feature:

.cursor/plans/byo-vm-fleet.md — Tranche 1: BYO VM fleet creation

.cursor/plans/kafka-on-byo-vms.md — Tranche 2: Confluent Platform on BYO VMs

I treated the other plan documents in .cursor/plans—OIDC and reusable package-version UI—as unrelated to this feature.

No files were changed, no code was built, no commit was made, and no pull request was created, as requested.

Overall assessment
The plans are unusually detailed and define most of the following sufficiently:

Backend data models and validation.

Provider/workload identifiers.

Fleet and Kafka workflow boundaries.

Frontend behavior and leakage-prevention tests.

Agent and Kubernetes exclusion rules.

The Paramiko versus Ansible responsibility boundary.

The backend-owned compute-components contract.

Required tests and explicit out-of-scope items.

The implementation should be split into two sequential deliverables. Tranche 1 must produce a healthy BYOVM fleet and pass the real Ansible-SSH POC before Tranche 2 begins. This ordering is an explicit merge gate, not merely a suggested development sequence. 

I would not start full implementation yet without decisions on the blocking items below.

Inputs required before implementation
1. Confirm the delivery boundary and sequencing
Required decision
Please confirm whether the desired delivery is:

Option A — Recommended: two PRs/deliverables:

Tranche 1, including the Ansible SSH POC.

Tranche 2 only after Tranche 1 and its POC are green.

Option B: one long-lived implementation branch, but still reviewed and merged through two independently green milestones.

Option C: one combined PR containing both tranches.

Recommendation
Use two PRs. Tranche 1 is independently useful and explicitly stops after the fleet becomes healthy; it excludes Kafka and cp-ansible. 

Tranche 2 expressly depends on the healthy fleet and successful SSH-based PlaybookExecutor proof. 

A combined implementation would weaken the stated gate because the production cp-ansible integration could be developed before its foundational transport proof had independently passed.

2. Supported Debian versions and privilege contract
The plan says:

Docker installation is performed on Debian “as root.” 

The runtime requirement is “root / passwordless sudo.” 

Ubuntu and RHEL are out of scope. 

Required decisions
Please specify:

Which Debian releases are supported:

Debian 12 only?

Debian 11 and 12?

Whether ssh_user may be:

root; or

a non-root user with passwordless sudo; or

both.

If a non-root user is supported, should validation run a command such as:

sudo -n true

and fail before Temporal dispatch if it does not work?

Must /tmp and the eventual installation directory permit executable files?

What minimum free disk, CPU, and RAM should cause validation to fail rather than merely be recorded?

Recommendation
Support Debian 12, allow either root or passwordless sudo, and validate sudo -n true during the in-request check. This avoids accepting a fleet that passes SSH authentication but is guaranteed to fail during Docker or Java installation.

3. Network reachability model
There are two distinct callers that must reach every VM:

The backend process performs in-request Paramiko validation before persistence. 

The Temporal orchestrator worker later performs Paramiko and Ansible SSH operations. 

These processes may run in different networks or Kubernetes namespaces.

Required decisions
Please confirm:

Must every ansible_host:ssh_port be reachable from both the backend and orchestrator worker?

In hosted deployments, what outbound IP ranges should customers allowlist?

Is split routing supported—for example:

backend reaches a bastion publicly;

orchestrator reaches hosts privately?

Is IPv6 supported, or IPv4 only?

Are hostnames allowed for ansible_host, despite the plan describing it as an IP field? 

Are outbound proxies or SOCKS proxies out of scope?

Recommendation
Document and enforce that the backend and orchestrator must both reach the same bastion or host endpoints. Otherwise, successful create-time validation would not prove that the workflow can operate the fleet.

4. SSH host-key verification policy
The plans define key authentication, timeout handling, and optional bastions, but do not define host identity verification. The inventory contains no host-key fingerprint or known-hosts data. 

Required decision
Choose one:

Strict verification: require a host-key fingerprint or known_hosts entry for every VM and bastion.

Trust on first use: capture the host key during validation, persist it, and require the workflow and Ansible to match it later.

Insecure acceptance: automatically accept unknown host keys.

Recommendation
Use trust on first use, persisting fingerprints collected during the synchronous validation. Both Paramiko and Ansible should then enforce those fingerprints. Automatically accepting any host key in production would make the uploaded private key vulnerable to man-in-the-middle attacks.

This decision affects the Pydantic schema, secret storage, Ansible inventory generation, error messages, and tests, so it should be settled before coding.

5. SSH private-key format and lifecycle
The plan specifies one uploaded private key, stored in a secret and removed from persisted advanced configuration. 

However, it does not specify the accepted key formats or rotation behavior.

Required decisions
Please clarify:

Supported formats:

OpenSSH private keys?

PEM RSA?

ECDSA?

Ed25519?

Are encrypted/passphrase-protected private keys supported?

If yes, the schema needs a passphrase secret or an alternative unlocking mechanism.

Is one key required to authenticate to:

every inventory host; and

the bastion?

Can the bastion require a different user/key?

How is a key rotated after fleet creation?

Should fleet UPDATE/check-hosts permit replacing the key?

On fleet deletion, must the SSH secret be deleted immediately?

Is /organizations/{org}/fleet/{id}/ssh-private-key the single canonical storage location, or should FleetResources.ssh_private_key also be populated?

The file inventory calls for a possible FleetResources.ssh_private_key migration, while the behavioral section describes a path-based secret. 

Recommendation
Use the existing secrets abstraction with the named secret path as the sole source of truth. Avoid adding a database field that could imply key material is stored directly in the relational database unless that field is an existing secret reference type.

6. Bastion behavior
The bastion schema only contains host, port, and user. 

Required decisions
Please confirm:

Does the bastion always use the same uploaded SSH key?

Does ansible_host represent the target address as resolved:

by the backend/orchestrator; or

from the bastion?

Should DNS resolution occur locally or on the bastion?

Must Ansible use ProxyCommand, or should a temporary SSH config be generated?

Are multi-hop bastions out of scope?

Are bastion host keys subject to the same verification policy as target VMs?

Recommendation
Use one key for bastion and targets for the first version, support one hop only, and generate controlled SSH configuration for Ansible without shelling out from application code.

7. DNS ownership and record creation
The plans require:

shared-{fleet}.{domain} to resolve to the Kong host through one A record. 

Kafka broker, bootstrap, Schema Registry, and Control Center DNS records during Tranche 2. 

Kubernetes external-dns bootstrap to be skipped for VM fleets. 

It is unclear which component actually creates these records for VM fleets.

Required decisions
Choose the DNS operating model:

Fleet Manager calls the configured DNS provider APIs.

The customer pre-creates all DNS records.

Fleet Manager returns required records and waits for the customer to create them.

A separate Streamtime DNS service creates them.

Also clarify:

Should shared-{fleet}.{domain} point specifically to the host earmarked for Kong?

For broker records, should each record point to its broker’s ansible_host, another public IP, or the supplied fqdn?

What happens when ansible_host is a private RFC1918 address?

Should DNS readiness be checked before the fleet or Kafka cluster becomes Healthy?

What TTL should be used?

Are CNAME records acceptable, or must records be A/AAAA?

This is a blocking decision because the workflow cannot safely infer externally routable addresses from SSH addresses.

8. Certificate selection, contents, and distribution
The create wizard requires a base domain with an uploaded certificate and disables automatic certificate creation.  The workflow must then install certificate files for Kong/Grafana, and Tranche 2 must use custom certificates for Confluent Platform. 

Required decisions
Please clarify:

Does the existing domain certificate always include:

shared-{fleet}.{domain};

all broker names;

bootstrap;

Schema Registry;

Control Center?

Is a wildcard certificate required?

How does the workflow retrieve:

certificate chain;

private key;

CA certificate?

Are the same certificate and private key used for shared services and Kafka?

What filesystem owner/mode should be used on hosts?

How is renewal handled after deployment?

Should fleet UPDATE redistribute renewed certificates?

Should failure to find a complete matching certificate reject the fleet synchronously?

Recommendation
Require a wildcard certificate covering *.{domain} plus an appropriate chain, validate coverage before fleet persistence, and define a refresh workflow for rotation. Without a renewal path, long-lived fleets will eventually fail TLS.

9. Shared-service placement and cross-host routing
Each shared service must appear on exactly one shared-service host, but services may be distributed among several hosts.  Kong must route to loopback or upstream services over host ports. 

Required decisions
Please confirm:

May Kong, Prometheus, Grafana, Loki, and Alertmanager be spread across multiple VMs?

If yes, should Kong target:

each service’s ansible_host;

its fqdn;

or its inventory name?

Which addresses should Prometheus use to scrape every node exporter?

Which Loki URL should every Promtail use?

Must all inventory hosts be mutually reachable on service ports?

Are TLS and authentication required on east-west traffic?

Should internal service addresses be persisted in metadata?

Does the Kong host need all service ports reachable even if the browser only accesses 8443?

Recommendation
Permit distribution, but explicitly require host-to-host connectivity on the necessary ports. Generate routing from the backend-validated inventory, preferably using fqdn for stable identities and ansible_host only for SSH.

10. Persistent volumes, backups, and credentials for shared services
The plan lists containers and endpoints but does not define storage, retention, or generated credentials.

Required decisions
Please provide:

Host installation root, for example /opt/streamtime/fleet-manager.

Data directories and ownership for:

Prometheus;

Grafana;

Loki;

Alertmanager;

Kong configuration.

Retention defaults for Prometheus and Loki.

Whether existing data is retained on fleet DELETE.

Whether Compose DELETE uses:

docker compose down; or

docker compose down -v.

Grafana administrator credential generation policy.

Kong or endpoint authentication requirements.

Exact contents and consumer contract of shared-credentials.

Whether credentials rotate on UPDATE/redeploy.

Backup/restore expectations.

The plan says DELETE performs docker compose down and does not destroy VMs, but data-deletion semantics are not specified. 

Recommendation
Persist data in named host directories, retain it on ordinary delete, and expose a separately confirmed destructive purge operation if needed.

11. Image and dependency version pins
The implementation must raise if shared-service image tags, SSH timeout, or cp-ansible collection version are missing. 

No actual defaults are provided.

Required inputs
Please supply approved pins for:

ansible-core

confluent.platform collection

Default Confluent Platform package version

Prometheus

Grafana

Loki

Alertmanager

Kong

node_exporter

Promtail

Also specify:

Registry host for each image.

Whether images must be pinned by digest rather than mutable tags.

Supported architecture: amd64 only, or arm64 too?

Whether Docker Hub credentials or registry mirrors need to be supported.

Whether the environment has access to Docker’s Debian repository, image registries, Ansible Galaxy, and Confluent package repositories.

The plans explicitly exclude air-gapped mirrors, but production egress requirements still need documentation. 

12. Kafka capacity derivation: which hosts count?
The plan requires mapping VM facts into the existing BYOK node shape and using the existing KU derivation logic.  Tranche 2 then ranks fleets using the persisted derived capacity. 

The unresolved question is which inventory hosts contribute to Kafka capacity.

Required decision
Should capacity be derived from:

all VM hosts;

only hosts with purpose=kafka;

controllers plus Kafka hosts;

every Confluent role host;

or the minimum usable capacity across role groups?

Including shared-service, Flink, Connect, or UI hosts would overstate Kafka capacity. Conversely, using all CPU and RAM while allowing role colocation could double-count resources.

Recommendation
Derive Kafka capacity only from hosts eligible to act as brokers, subtract explicit reserved resources, and separately validate minimum controller and ancillary-role capacity. Continue using the existing formula, but define the input node set precisely.

13. Resource reservations and minimum hardware
Topology collects CPU, available RAM, and disk, but KU derivation is described mainly in CPU/RAM terms. 

Required inputs
Please define:

Reserved CPU/RAM per host for the OS.

Reserved resources on shared-service hosts.

Minimum disk space:

for Docker/shared services;

controllers;

brokers;

Schema Registry;

Control Center.

Required filesystem or mount point for Kafka data.

Whether Kafka data is installed on / or a configurable data mount.

Whether disk capacity affects KU or merely preflight validation.

Whether heterogeneous broker nodes are supported.

Without this, a fleet could be marked healthy and selected based on CPU/RAM even though its root volume cannot accommodate Kafka.

14. Port and firewall requirements
The plan names service ports and JMX ports but does not provide a complete connectivity matrix. Shared-service ports include Kong 8000/8443, Prometheus 9090, Loki 3100, Grafana 3000, Alertmanager 9094, and node exporter 9100.  Tranche 2 adds controller JMX 8079 and broker JMX 8080. 

Required inputs
Please provide or approve:

The complete inbound/outbound firewall matrix.

Which ports must be externally accessible.

Which ports are host-to-host only.

Kafka client listener ports and controller quorum ports.

Schema Registry and Control Center ports.

Whether Fleet Manager should detect occupied ports before installation.

Whether it may modify ufw, nftables, iptables, security groups, or none of these.

Expected behavior when Docker or another process already owns a required port.

Recommendation
Fleet Manager should validate ports but not modify cloud firewalls or security groups on customer-owned VMs.

15. Fleet and Kafka failure/retry semantics
The plans define the happy path but do not fully define status transitions or compensation.

Required decisions
Please specify:

Fleet state after:

synchronous validation succeeds but secret persistence fails;

dispatch fails;

topology succeeds but Compose fails;

only one shared-service host fails;

DNS or certificate setup fails.

Whether Temporal retries should be automatic and with what limits.

Whether a retry is idempotent.

Whether a failed create can be resumed from the UI.

Whether partial installations should be automatically removed.

Whether DELETE should work from Failed/Creating states.

Exact use of HTTP 201 versus 202; the plan currently permits either. 

Whether the existing command resource should be returned and shown for VM operations, even though agent-specific command pages are excluded.

Recommendation
Return 202 Accepted once persistence and dispatch succeed, use deterministic idempotent Compose/Ansible operations, retain diagnostics on failure, and permit retry and delete from Failed state.

16. Fleet UPDATE/check-hosts contract
Tranche 1 says topology should be collected again on Fleet UPDATE/check-hosts, but the precise public operation is not defined.

Required decisions
Please clarify whether UPDATE can modify:

host inventory;

host purposes;

IPs/FQDNs;

shared-service placement;

bastion;

SSH key;

domain/certificate.

Also define:

Whether removing a host automatically stops node_exporter and Promtail there.

Whether moving Prometheus/Loki migrates data.

Whether changing a host used by an existing Kafka cluster is forbidden.

Whether fleet capacity may shrink below allocated Kafka units.

Whether an update is rejected while Kafka exists.

Which existing API endpoint initiates “check hosts.”

Recommendation
For the first release, make inventory and service placement immutable after Kafka is deployed; allow SSH-key rotation and check-hosts separately.

17. Kafka role colocation policy
The advanced configuration says “colocation allowed” while also preferring hosts based on a single fleet-purpose enum. 

Required decisions
Please define exactly which combinations are permitted:

Controller + broker?

Broker + Schema Registry?

Broker + Control Center?

Controller + ancillary service?

Can one purpose=kafka host appear in all four role lists?

Can a purpose=controller host also be a broker?

May kafka-ui hosts be used only for Control Center, or can a Kafka-purpose host be used?

Are role lists sets with duplicate values rejected?

Does “≥3 unique controllers” mean three different physical inventory entries even when other roles are colocated?

Recommendation
Require three distinct controller hosts, at least one distinct broker host, and permit Schema Registry/Control Center colocation only with broker hosts for small non-production deployments. Shared-service hosts should never be eligible, consistent with the plan. 

18. Authentication and client-access contract
The plan provides sasl_protocol with default scram, but does not define the resulting credentials or client interface. 

Required decisions
Please clarify:

Supported values beyond scram.

SCRAM mechanism: SHA-256 or SHA-512.

Initial principal/user creation.

Password generation and storage.

Whether TLS client authentication is supported.

Kafka listener layout:

internal;

external;

controller;

inter-broker.

Whether clients resolve broker FQDNs directly.

Exact output resource/endpoints/secrets contract.

Confluent license handling, if required for Control Center or enterprise features.

19. Confluent package repository and licensing
Tranche 2 forces package installation through cp-ansible but does not state how repository access and licenses are handled. 

Required inputs
Please provide:

Supported Confluent Platform version or version range.

Whether Confluent repository credentials are required.

How repository GPG keys are obtained.

Whether a Confluent license is required and, if so:

where it is stored;

how it enters all.vars;

which components receive it.

Whether outbound internet access from each target VM is mandatory.

Upgrade and downgrade policy.

20. Kafka UPDATE and DELETE behavior
The success criteria say:

UPDATE is performed through the packages endpoint.

DELETE uninstalls Confluent Platform while leaving fleet shared services running. 

The workflow section says CREATE/UPDATE run the full collection and DELETE is supported, but does not define operational details. 

Required decisions
Please specify:

Supported update types:

package version only;

custom property changes;

role changes;

certificate rotation.

Rolling versus all-at-once upgrade.

Whether downgrades are forbidden.

Whether the update requires a backup/checkpoint.

Exact cp-ansible tags or variables used for uninstall.

Whether DELETE preserves Kafka data directories.

Whether DNS records, Prometheus scrape jobs, and Grafana dashboards are removed.

Whether generated Kafka secrets are removed immediately.

Whether a failed uninstall blocks deletion of the database row.

21. Prometheus and Grafana content
The plan requires JMX scraping and dashboards but does not identify exact dashboards or PromQL behavior beyond adding cpansible support. 

Required inputs
Please provide:

Required Prometheus scrape job names and labels.

Whether hostnames or IPs should be used as scrape targets.

Controller and broker JMX exporter configuration.

Dashboard JSON sources and expected UIDs.

Folder naming and overwrite policy in Grafana.

Whether dashboards are provisioned through files or Grafana API.

How scrape configuration is removed during DELETE.

Whether promtool check config is required before Prometheus reload.

Reload mechanism and rollback behavior if new configuration is invalid.

22. CLI expectations
Both tranches list CLI modifications, but no CLI UX or payload contract is specified. Tranche 1 lists fleet CLI work, and Tranche 2 lists Kafka CLI work. 

Required decisions
Please clarify:

Is CLI support required for the first release or may it follow the UI/API?

Should the SSH key be accepted as:

a file path;

stdin;

inline PEM?

Should host inventory be passed as YAML/JSON file or repeated flags?

Should CLI output include per-host validation failures?

How should role assignment be represented?

Must the CLI support key rotation and check-hosts?

23. POC test environment
The Tranche 1 POC must use an actual SSH connection plugin and an ephemeral SSH server; skipped or connection=local tests are explicitly unacceptable. 

Required confirmation
Please confirm that CI runners support at least one of:

Docker/Podman for an ephemeral sshd container; or

installation and startup of a local sshd process.

Also confirm:

Whether CI permits binding a random localhost port.

Whether OpenSSH client utilities are installed.

Whether tests may generate ephemeral Ed25519/RSA keys.

Whether the worker image itself must run this test during image build, or only in CI.

Recommendation
Use a local sshd process when possible to avoid Docker-in-Docker dependence, while still proving Ansible’s real SSH transport.

Non-blocking clarifications
These can reasonably be implemented using conventional defaults, but confirmation would reduce rework.

A. Exact create response
The plan says the fleet create endpoint can return 201/202. 

I recommend standardizing on 202 because installation continues asynchronously.

B. fqdn versus generated FQDN
Both name and fqdn are supplied, while name is already described as a DNS label under the fleet domain. 

Please confirm whether fqdn should:

be derived as {name}.{fleet-domain} and omitted from user input; or

remain user-supplied and be validated against the selected domain.

Derivation would avoid conflicting values.

C. Duplicate addresses and names
The validator requirements do not explicitly mention uniqueness.

I recommend requiring unique:

host name;

fqdn;

(ansible_host, ssh_port) unless there is an explicit reason to represent the same machine more than once;

service entries;

role-list entries.

D. Synchronous validation concurrency limit
The plan asks to connect to all hosts in parallel. 

For large fleets, unbounded concurrency could exhaust backend worker sockets. I recommend a configurable semaphore and a maximum inventory size.

E. Maximum inventory size
No maximum host count is provided. Please provide an expected scale—for example 10, 50, 100, or 500 hosts—because it affects:

request timeout;

Paramiko concurrency;

Ansible forks;

Temporal activity timeouts;

UI array performance;

secret and metadata payload size.

F. Source of the displayed OS value
Topology stores both OS ID/version and a potentially more useful pretty name. The UI requirement only says to show OS. I recommend displaying PRETTY_NAME with ID/version as fallback.

Requirements that are already sufficiently clear
The following do not need additional product input unless you want to change the plan:

Provider API key is byovm, displayed as BYOVM. 

Host inventory belongs in advanced configuration, not placement. 

Any host SSH failure prevents persistence and Temporal dispatch. 

Shared services use Paramiko plus Docker Compose, not Ansible. 

cp-ansible uses the in-process Ansible Python API rather than an Ansible subprocess. 

VM fleets must not expose agent or Kubernetes-specific UI and actions. 

purpose is a closed enum rather than free text. 

Every shared service is assigned exactly once and only to shared-service hosts. 

Kubernetes Kafka SKUs must reject VM fleets. 

cpansible must use only healthy, dedicated BYOVM fleets. 

The backend-generated compute-components inventory is canonical; the orchestrator must not reconstruct it from raw form fields. 

Kafka and SSH private keys/PEMs must not appear in compute-components responses. 

Existing Kafka detail pages are deliberately out of scope. 

Minimum response needed to unblock implementation
At minimum, I need answers to these eight blocking questions:

Are Tranche 1 and Tranche 2 delivered as two sequential PRs?

Which Debian versions and privilege model are supported?

What is the SSH host-key verification policy?

What SSH private-key formats, passphrase behavior, bastion credentials, and rotation behavior are supported?

Who creates the shared-service and Kafka DNS records, and which IPs should they target?

What certificate coverage and certificate-rotation model is required?

Which hosts count toward derived Kafka capacity, and what minimum hardware/disk rules apply?

What exact version pins should be used for ansible-core, cp-ansible, Confluent Platform, and the seven shared-service images?

The remaining questions can be resolved incrementally, but DNS, certificates, SSH security, capacity, runtime support, and dependency versions affect core schemas and architecture and should not be guessed.

Checks performed
✅ find .cursor/plans -maxdepth 2 -type f -print | sort

✅ cat .cursor/plans/byo-vm-fleet.md

✅ cat .cursor/plans/kafka-on-byo-vms.md

✅ rg -n "class (Byok|BYOK|.*Provider)|CLOUD_PROVIDERS|KAFKA_CLUSTER_PROVIDERS|class Fleet\\b|byok_capacity_kafka_units|FleetResources|GlobalConfiguration" fleet-manager-backend -g '*.py'

✅ git branch --all --no-color

✅ git status --short --branch — working tree remained clean; no changes, commits, or PR were created.

Below are the response for the eight blocking questions and i've included few others for your reference. Go through the response and let me know if you have any questions or clarification. Do not make any code changes or create PR. 

1. Are Tranche 1 and Tranche 2 delivered as two sequential PRs?
   [Response] - Two separate PR.

2. Which Debian versions and privilege model are supported?
   [Response] - Debian 12

3. What is the SSH host-key verification policy?
   [Response] - Trust on first use

4. What SSH private-key formats, passphrase behavior, bastion credentials, and rotation behavior are supported?
   [Response] - Use the existing secrets abstraction with the named secret path as the sole source of truth

5. Who creates the shared-service and Kafka DNS records, and which IPs should they target?
   [Response] - The customer is expected to create.

6. What certificate coverage and certificate-rotation model is required?
   [Response] - It will follow the same model as Bring Your Certificates in Kubernetes (There is no established way to renew / rotate certificates for non auto generated certificates in Kubernetes Fleets, apart from doing it through a helm upgrade in the UI

7. Which hosts count toward derived Kafka capacity, and what minimum hardware/disk rules apply?
   [Response] - minimum 3 hosts for Kafka capacity, Hardware Requirements as defind in the URL- https://docs.confluent.io/platform/current/installation/system-requirements.html#hardware

8. What exact version pins should be used for ansible-core, cp-ansible, Confluent Platform, and the seven shared-service images?
   [Response] - 

   	ansible-core	--> Ansible 11.x [ansible-core 2.18] & Python 3.11 - 3.12
	confluent.platform collection --> https://docs.confluent.io/ansible/current/ansible-install.html#install-cp-with-ansible-playbooks
	Confluent Platform --> User selection from drop down menu - 8.1.5, 8.2.3, 8.3.0. Also refer to steps for installation vi cp-ansible playbook in URL https://docs.confluent.io/ansible/current/ansible-install.html#install-cp-with-ansible-playbook
	Prometheus  --> The latest stable version or the version deployed in Kubernetes
	Grafana	    --> The latest stable version or the version deployed in Kubernetes
	Loki	    --> The latest stable version or the version deployed in Kubernetes
	Alertmanager --> The latest stable version or the version deployed in Kubernetes
	Kong	    --> The latest stable version or the version deployed in Kubernetes
	node_exporter --> The latest stable version or the version deployed in Kubernetes
	Promtail     --> The latest stable version or the version deployed in Kubernetes

9. Are Shared Services deployed individual VMs or single VM?	
  [Response] - Shared services should be deployed on 3 VMs. The topology depends on the number of VMs provided. We need atleast 3 VMs for brokers + controllers. The rest can be used for the other components + shared services. Shared services will take least priority in assignment i.e., atleast 1 and atmost 3, depending on availability.

10. Must /tmp and the eventual installation directory permit executable files?
    [Response] - the file or directory permission should only be 755

	
11. Which SSH private-key format and lifecycle
   [Response] - Use the existing secrets abstraction with the named secret path as the sole source of truth. Avoid adding a database field that could imply key material is stored directly in the relational database unless that 
                field is an existing secret reference type.	
	
12. Should shared-{fleet}.{domain} point specifically to the host earmarked for Kong?
    [Response] - Yes

13. Certificate selection, contents, and distribution
   [Response] - Shared services certificate should be created. 
                Kraft, Broker, Schema Registry, Control Center, Connect - CA, host certificate and host key will be provided by customer. Provision to upload them in Streamtime UI
        
14. Whether Compose DELETE uses which of the below commands. The plan says DELETE performs docker compose down and does not destroy VMs, but data-deletion semantics are not specified.
	docker compose down; or
	docker compose down -v.
    [Reponse] -  It should delete the data, similar to Kubernetes

15. Data directories and ownership for:

    Prometheus
    Grafana
    Loki
    Alertmanager
    Kong configuration

    Retention defaults for Prometheus and Loki.

   [Response] - Since these will be running on docker, it will be a docker volume with the permissions managed by the docker user. The default retention can be 15 days. In the future, the retention can be calculated based on the available disk space. This requires us to understand how much storage is required per day of telemetry per component.

16. Please provide below information: 
    
    	- Grafana administrator credential generation policy.
    	  [Response] - Grafana administrator credential generation policy. - Same as the Kubernetes fleet - auto generated but idempotent. Stored in the shared credentials secret.
	
	- Kong or endpoint authentication requirements.
	  [Response] - Kong or endpoint authentication requirements - Same as the Kubernetes fleet - basic auth for shared services (Prometheus, Loki)
	  
	- Exact contents and consumer contract of shared-credentials.
	  [Response] - Shared credentials format for VMs - {"metrics": {"username": "<>", "password": "<>"}, "alerts": {"username": "<>", "password": "<>"}, "logs": {"username": "<>", "password": "<>"}, "dashboard": {"username": "<>", "password": "<>"}}
	  
    	- Whether credentials rotate on UPDATE/redeploy.
    	  [Response] - hether credentials rotate on UPDATE/redeploy. - No credentials should be idempotent. Should not rotate on UPDATE/redeploy. This is by design since customers might be scraping metrics using the credentials and it should not break.
Copy
Follow-up Analysis
Thank you. These responses settle the overall delivery sequence and several important operational choices:

Tranche 1 and Tranche 2 will be separate PRs.

Debian 12 is the sole target OS.

SSH host keys will use trust on first use.

The SSH private key will use the existing secret abstraction rather than a database field containing key material.

Customers own DNS record creation.

Shared-service credentials must remain stable across reconciliation.

Docker-managed volumes will be deleted with the fleet.

Prometheus and Loki initially use 15-day retention.

Kafka supports selectable Confluent Platform versions 8.1.5, 8.2.3, and 8.3.0.

However, several answers expose additional ambiguities or conflicts with the written plans. I would want the clarifications below before implementation.

I attempted to verify the supplied Confluent documentation URLs, but internet access to those pages was blocked in this environment by an HTTP 403/tunnel restriction. The observations below therefore compare your answers primarily against the checked-in requirements and the current repository.

Blocking clarifications
1. Python version must be reconciled with Ansible 11 / ansible-core 2.18
You specified:

Ansible 11.x

ansible-core 2.18

Python 3.11–3.12

The orchestrator image currently runs Python 3.13, not 3.11 or 3.12. 

Clarification required
May Tranche 1 change the orchestrator base image from:

python:3.13-slim-bookworm
to:

python:3.12-slim-bookworm
If so, should only the orchestrator move to Python 3.12, or should the backend image also be aligned?

Recommendation
Change only the orchestrator to Python 3.12 unless the backend shares a dependency that requires it. That minimizes scope while satisfying the stated Ansible runtime compatibility.

This is blocking because the required Ansible version and current worker runtime are presently incompatible according to the support range you supplied.

2. The SSH key-format question remains unanswered
Responses 4 and 11 establish where the key is stored, but do not establish what kinds of keys are accepted.

The current requirements say only that ssh_private_key is uploaded, written to a secret, and removed from stored advanced configuration. 

Clarification required
Please confirm the intended initial policy:

Supported algorithms/formats:

RSA in OpenSSH format;

RSA in traditional PEM/PKCS#1 format;

PKCS#8;

Ed25519 OpenSSH;

ECDSA OpenSSH.

Are passphrase-encrypted SSH keys supported?

Does the same key authenticate to both the bastion and destination VMs?

Is SSH-key rotation out of scope for the first release?

Recommended first-release policy
Accept unencrypted RSA, Ed25519, and ECDSA keys supported by Paramiko.

Reject passphrase-protected keys with a clear validation error.

Use the same key for the bastion and destination hosts.

Defer key rotation to a future explicit fleet action.

Without this decision, the UI and API cannot accurately tell users what key file they may upload.

3. Trust-on-first-use needs a persistence contract
“Trust on first use” requires more than Paramiko’s permissive AutoAddPolicy. The first connection must record an identity that later connections verify. Otherwise every connection trusts a new key and the system is effectively operating with host-key verification disabled.

Clarification required
Please approve or amend this proposed behavior:

During the synchronous create validation:

connect to every host;

capture each server host-key algorithm and SHA-256 fingerprint;

capture the bastion fingerprint when present.

Persist those fingerprints outside the SSH private-key secret, such as in sanitized fleet metadata or a dedicated secret.

Every subsequent Paramiko and Ansible connection must require the stored fingerprint.

If a host key changes:

fail the check/workflow;

show the affected host and old/new fingerprint;

require an explicit user-approved “trust new host key” operation.

Additional question
Where should the fingerprints live?

Fleet.metadata;

advanced_config as server-generated read-only values;

a separate secret path;

or the SSH secret payload alongside the private key?

Recommendation
Store non-secret fingerprints in Fleet.metadata, while keeping only private material in the secrets provider.

4. Privilege behavior is still unspecified
“Debian 12” resolves the OS, but not whether SSH must be as root or may use passwordless sudo. The plan currently says both “as root” and “root / passwordless sudo.” 

Clarification required
Please select one:

A: ssh_user must be root.

B — Recommended: ssh_user may be root or a user for which sudo -n true succeeds.

C: any SSH user is allowed, and privilege failure occurs asynchronously.

If option B is selected, please confirm that synchronous SSH validation should run sudo -n true and reject the fleet before persistence if it fails.

5. Shared-service placement conflicts with the existing input model
The original plan makes shared-service placement explicitly user-controlled:

each host includes a shared_services list;

each of the five services must appear on exactly one host;

several services can be colocated;

the host must have purpose=shared-services. 

Your new response says:

shared services should be deployed on up to three VMs;

actual topology depends on the number of VMs;

shared services have the lowest assignment priority;

at least one and at most three hosts are used.

That sounds like automatic placement, rather than the user-provided earmarks in the original schema.

Clarification required
Which model should be authoritative?

Option A — Original plan
The user explicitly assigns each shared service to one to three hosts through hosts[].shared_services. Fleet Manager validates those assignments but does not choose placement.

Option B — Automatic placement
The user supplies hosts and purposes, and Fleet Manager automatically distributes the five shared services over one to three eligible hosts.

Option C — Recommended hybrid
The user may earmark up to three shared-service hosts. If the individual services are not manually assigned, Fleet Manager deterministically distributes them, with all five still having exactly one active instance.

Also clarify
Does “shared services should be deployed on 3 VMs” mean:

distribute the five services across as many as three hosts, with one active instance of each; or

run three replicas of each service?

The checked-in plan clearly describes one placement of each service, not three replicas. 

6. Three Kafka hosts versus the Tranche 2 role requirements
Your response says at least three VMs are needed for brokers plus controllers. The Tranche 2 plan separately requires:

at least three unique controller hosts;

at least one broker;

at least one Schema Registry host;

at least one Control Center host;

colocation is allowed. 

A three-VM minimum works only if roles can overlap.

Clarification required
For a minimum three-host installation, should the topology be:

all three hosts are controllers;

one or all three are also brokers;

Schema Registry and Control Center are colocated on those same hosts?

Please confirm the exact colocation matrix:

Role combination	Allowed?
Controller + broker	?
Controller + Schema Registry	?
Controller + Control Center	?
Broker + Schema Registry	?
Broker + Control Center	?
Kafka role + shared services	?
Recommendation
For the minimum topology:

three distinct controller hosts;

all three may also be brokers;

Schema Registry and Control Center may colocate with broker hosts;

shared services should not colocate with Kafka roles unless fewer hosts would otherwise make the deployment impossible.

However, the last point would conflict with the current single-valued purpose enum and should be explicitly decided.

7. “Hardware requirements from Confluent documentation” is not yet machine-enforceable
Referencing Confluent’s system-requirements documentation is useful for operator guidance, but implementation needs explicit thresholds and a deterministic capacity formula.

The plan requires the system to:

collect CPU, RAM, and disk;

persist topology;

convert eligible hosts into the node shape understood by the existing KU helper;

derive a concrete max_kafka_units value. 

Clarification required
Please specify:

Which hosts contribute to KU:

only purpose=kafka;

controller plus Kafka;

every non-shared-services host;

or hosts actually assigned as brokers in Tranche 2.

Minimum resources per host:

vCPU;

RAM;

disk.

Whether the minimum is:

a hard Tranche 1 fleet-creation requirement;

a warning;

or a Tranche 2 Kafka-creation requirement.

Which disk mount should be checked:

/;

/var/lib;

a user-provided Kafka data path.

Whether disk affects KU derivation or only eligibility.

Recommendation
For Tranche 1:

collect all hosts;

derive capacity only from Kafka-purpose hosts;

require at least three Kafka-capable hosts;

use the existing CPU/RAM KU formula;

enforce disk separately as a preflight minimum.

For Tranche 2:

recompute or validate usable capacity using the selected broker assignments so controllers or shared-service hosts do not inflate Kafka capacity.

8. Exact image pins are still required
“Latest stable or the version deployed in Kubernetes” leaves two non-equivalent choices and does not give deterministic pins.

The plan explicitly requires GlobalConfiguration image tags/pins and says the workflow should raise if they are missing. 

The current BYOK advanced configuration permits blank chart versions meaning “latest,” so existing Kubernetes configuration does not necessarily provide a single authoritative application image version. 

Clarification required
Please choose one policy:

Option A — Recommended
At implementation time, identify and seed exact versions matching the default Kubernetes chart image versions. Once seeded, they remain pinned and do not automatically float.

Option B
Provide an explicit approved version for every image before implementation.

Option C
Resolve the latest stable tags dynamically at runtime.

I strongly recommend against option C because:

deployments would not be reproducible;

UPDATE could unintentionally upgrade services;

rollback tests would be unreliable;

“latest” can change or disappear.

Promtail-specific clarification
Should Tranche 1 still deploy Promtail, or should it use Grafana Alloy?

The plan explicitly requires Promtail and says Alloy is out of scope.  Because this implementation targets a future deployment lifecycle, I would like explicit confirmation that retaining Promtail is intentional.

9. Exact confluent.platform collection pin is still needed
The supplied URL explains installation, but the implementation still needs a fixed collection version for:

the worker image;

requirements.yml or its equivalent;

cp_ansible_collection_version;

reproducible tests.

The Tranche 2 plan requires the collection to be baked into the image and requires its configuration key to be present. 

Clarification required
Please provide or approve a process for selecting the exact collection version compatible with all three offered CP package versions:

8.1.5

8.2.3

8.3.0

Recommendation
Select one collection release that officially supports all three. If no single release does, the design must either:

bake multiple collection versions and select at runtime; or

narrow the CP version dropdown.

10. Certificate behavior contains a conflict
The original plan says:

BYOVM uses a base domain with already-uploaded custom certificates;

automatic certificate creation is disabled;

custom certificate files are installed for Kong and Grafana. 

Your responses say both:

follow the existing bring-your-own-certificate model;

“Shared services certificate should be created.”

The repository’s existing base-domain model stores a custom certificate and key directly on the domain and tracks whether certificates are auto-created.  The current domain API requires certificate and key uploads when automatic certificate creation is disabled. 

Clarification required
Who creates the shared-service certificate?

A: Customer uploads it at the base-domain level, and Fleet Manager only distributes it.

B: Fleet Manager issues it from the organization CA.

C: Customer uploads it during BYOVM fleet creation.

D: Customer uploads it later during a dedicated certificate action.

Recommendation
Use option A to remain consistent with the current BYOC Kubernetes model and the original plan.

Also confirm whether the shared-service certificate must cover:

shared-{fleet}.{domain}
or whether a wildcard certificate for:

*.{domain}
is mandatory.

11. Kafka certificate upload shape needs to be defined
You stated that KRaft, broker, Schema Registry, Control Center, and Connect certificates will be customer-provided through the UI.

This introduces new fields that are not in the Tranche 2 plan’s defined Kafka advanced-config payload. That payload currently contains only role assignments, version/authentication, and optional properties. 

It also says PEMs must never be returned in compute-components JSON. 

Clarification required
For each component, will the customer provide:

CA certificate only;

host certificate;

host private key?

I assume the customer will not provide the CA private key. Please confirm.

Also decide:

One wildcard/component certificate shared by all hosts, or a separate certificate per host?

Are certificates uploaded:

once per Kafka cluster;

once per host;

once per role?

Required SANs:

host fqdn;

generated broker DNS;

bootstrap DNS;

internal hostname;

IP address?

Where are certificate/key pairs stored in the secret provider?

Is certificate replacement performed through Kafka UPDATE/packages, or is rotation out of scope?

Is Kafka Connect actually in scope for certificate upload?

Kafka Connect is explicitly out of scope for Tranche 2.  Therefore, unless scope is changing, no Connect certificate UI should be introduced.

12. DNS readiness and lifecycle need a contract
The customer will create all DNS records. That resolves ownership, but not workflow behavior.

Clarification required
Should the product:

Show the exact required DNS records before installation?

Validate that records resolve to the expected addresses?

Block Healthy until DNS resolves?

Retry DNS checks during propagation?

Leave records untouched on DELETE?

Warn the customer to delete them manually?

Recommendation
Fleet Manager should generate and display the required record set.

It should verify resolution before marking the resource healthy.

It should never create or delete customer-managed records.

DELETE should return/display the records the customer may remove.

Also confirm how Kafka DNS target IPs are determined. ansible_host may be a private SSH address and therefore may not be appropriate for public client DNS.

13. 755 cannot be the universal file permission
You stated that files or directories should “only be 755.”

That would make private certificate keys and configuration files containing credentials world-readable on the VM. It is also unsuitable for files that do not need the executable bit.

Clarification required
May implementation use standard secure permissions instead?

Recommended defaults:

Resource	Mode
Installation directories	0755
Non-secret configuration files	0644
SSH private key on temporary control-node path	0600
TLS private keys	0600
Credential-bearing config files	0600 or 0640
Executable scripts	0755
Docker volume data	Component-specific UID/GID and least privilege
Recommendation
Treat 755 as the required directory mode, not a universal file mode.

This should be clarified before implementation because applying 755 to TLS private keys would be a security defect.

14. Docker volume deletion needs exact semantics
You confirmed that DELETE should remove data, similar to Kubernetes.

Clarification required
Please confirm that Tranche 1 fleet DELETE should execute the equivalent of:

docker compose down --volumes --remove-orphans
and additionally delete:

generated Compose files;

generated Kong configuration;

Prometheus configuration;

certificates copied to VM hosts;

credential-bearing environment files;

bind-mounted data directories, if any.

Docker’s --volumes removes named and anonymous Docker volumes but will not delete bind-mounted host directories.

Recommendation
Use named Docker volumes where practical, delete them during fleet DELETE, and explicitly remove generated secrets/configuration from host storage.

Important but non-blocking clarifications
15. Shared-service Docker volume ownership
“Managed by the Docker user” is not precise because each container commonly runs under its own image-specific UID/GID; Docker itself does not normalize application volume permissions.

Suggested implementation assumption
Use official image defaults.

Initialize volumes with the UID/GID expected by each image.

Avoid running all containers as root merely to simplify volume ownership.

Verify write access during health checks.

Please confirm this is acceptable.

16. Fifteen-day retention scope
Please confirm:

Prometheus: --storage.tsdb.retention.time=15d.

Loki: retention enabled and configured for 360h.

Grafana, Alertmanager, and Kong have no time-based retention requirement.

There is no minimum free-space guard beyond installation preflight for the first release.

17. Basic authentication coverage
You said Kong should provide basic authentication for Prometheus and Loki. The shared credential contract also contains credentials for alerts and dashboard:

{
  "metrics": {"username": "...", "password": "..."},
  "alerts": {"username": "...", "password": "..."},
  "logs": {"username": "...", "password": "..."},
  "dashboard": {"username": "...", "password": "..."}
}
Clarification required
Should Kong basic authentication protect all four public routes?

Route	Credential key	Authentication
/metrics	metrics	Basic auth
/logs	logs	Basic auth
/alerts	alerts	Basic auth
/grafana	dashboard	Grafana login, Kong basic auth, or both?
Recommendation
Kong basic auth for metrics, logs, and alerts.

Grafana’s own login for /grafana, without a second Kong login.

The dashboard credential represents the Grafana admin credential.

18. Credential generation and persistence
The idempotency requirement is clear: credentials must not rotate during retry, UPDATE, or redeploy.

Suggested implementation assumption
Read shared-credentials first.

Generate only missing values.

Store the completed secret before launching Compose.

Reuse it on every retry/update.

Delete it only during successful or explicitly forced fleet deletion.

Please confirm whether deletion and recreation of the same fleet identifier should generate new credentials. I recommend yes.

19. Customer DNS and UI placement
Because DNS is customer-managed, please confirm where required-record instructions should appear:

create wizard before Save;

fleet overview;

failed workflow details;

CLI output;

all of the above.

The original UI plan does not currently define a DNS-instruction step.

20. Confluent version dropdown behavior
Please confirm:

default selection among 8.1.5, 8.2.3, and 8.3.0;

whether versions are statically configured or seeded in GlobalConfiguration;

whether downgrades are forbidden;

whether every version is available for both CREATE and UPDATE.

Recommendation
Default to the newest approved version, configure the allowlist server-side, and reject downgrades unless explicitly supported.

Consolidated minimal answers still needed
To proceed without making architectural assumptions, the minimum remaining decisions are:

May the orchestrator image move from Python 3.13 to Python 3.12?

Which SSH key algorithms/formats are accepted, and are passphrase-protected keys rejected?

Where are TOFU host fingerprints persisted, and how is an intentional host-key change approved?

Are non-root SSH users with passwordless sudo supported?

Is shared-service placement manual, automatic, or hybrid—and does “three VMs” mean distribution or replication?

What Kafka-role colocation combinations are allowed in the three-host minimum topology?

Which exact hosts count toward KU capacity, and what enforceable CPU/RAM/disk thresholds apply?

Should exact shared-service image tags be frozen from the Kubernetes defaults at implementation time?

What exact confluent.platform collection version supports all three CP package versions?

Who creates the shared-service certificate, and where is it uploaded?

What is the Kafka certificate upload cardinality and secret-storage shape?

Does customer-managed DNS resolution block Healthy?

May secure file-specific modes be used instead of applying 755 to every file?

Does DELETE remove named volumes, generated configuration, certificates, and bind-mounted data?

Which public routes receive Kong basic authentication?

Once these are answered, I do not foresee another major requirements-discovery round. The remaining implementation details can be derived from established repository patterns and covered through the tests enumerated in both plans.

Checks performed
✅ rg -n "prometheus.*(image|version)|grafana.*(image|version)|loki.*(image|version)|alertmanager.*(image|version)|kong.*(image|version)|node.?exporter|promtail|certificate|custom.*cert|shared-credentials" fleet-manager-backend fleet-manager-orchestrator -g '*.py' -g '*.yml' -g '*.yaml'

✅ rg -n "FROM python|python_version|requires-python" fleet-manager-orchestrator/Dockerfile fleet-manager-backend/Dockerfile* fleet-manager-orchestrator -g 'pyproject.toml' -g 'Dockerfile*'

✅ nl -ba fleet-manager-orchestrator/Dockerfile

✅ nl -ba fleet-manager-backend/core/models.py

✅ nl -ba fleet-manager-backend/core/views/organization/domains.py

✅ nl -ba fleet-manager-backend/fleet_provider/byok_provider.py

⚠️ Official Confluent documentation URL retrieval — blocked by an HTTP 403/tunnel restriction in the execution environment.

✅ git status --short --branch — working tree remains clean; no files, commits, or pull requests were created.

Pls find below my response to "Consolidated minimal answers still needed". Check and let me know if you have any other questions. Do not make any code changes, do not raise any PR.

1. The orchestrator image currently runs Python 3.13, and python version that can be reconciled with Ansible 11 / ansible-core 2.18 requires Pyton 3.11 - 3.12. Can the orchestrator image move from Python 3.13 to Python 3.12?
   [Response] - As per https://clouddocs.f5.com/products/orchestration/ansible/devel/f5_modules/ansible_python_compatibility_report.html, ansible should work with 3.13 as well. We will use Python 3.13

2. Which SSH key algorithms/formats are accepted, and are passphrase-protected keys rejected?
   [Response] - Accept unencrypted RSA, Ed25519, and ECDSA keys supported by Paramiko. Reject passphrase-protected keys with a clear validation error. Use the same key for the bastion and destination hosts.  Defer key rotation to a future explicit fleet action.

3. Where are TOFU host fingerprints persisted, and how is an intentional host-key change approved?
   [Response] - Store non-secret fingerprints in Fleet.metadata, while keeping only private material in the secrets provider.

4. Are non-root SSH users with passwordless sudo supported?
   [Response] - Debian 12 should be minimum OS requirement. the provided user will have sudo privileges. Passwordless sudo will be enabled but any other alternative? 

5. Is shared-service placement manual, automatic, or hybrid—and does “three VMs” mean distribution or replication?
   [Response] - Automatic. The VM topology to be followed is listed below.
   
   Environment - Dev
   ------------------
   
   Minimum - 
   	      VM1 - Kraft + Broker
   	      VM2 - Kraft + Broker
   	      VM3 - Kraft + Broker
   	      VM4 - Shared Services
   
   Full	-
   	     VM1 - Kraft + Broker
   	     VM2 - Kraft + Broker
   	     VM3 - Kraft + Broker
   	     VM4 - Schema Registry
   	     VM5 - Connect
   	     VM6 - Rest Proxy
   	     VM7 - Shared Services
   	     
   	     
   Environment - Production
   -------------------------
   
   Minimum - 

   	     VM1 - Kraft
   	     VM2 - Kraft
   	     VM3 - Kraft
   	     VM4 - Broker
   	     VM5 - Broker
   	     VM6 - Broker
   	     VM7 - Shared Services   	
   	
   Full - 

   	     VM1 - Kraft
   	     VM2 - Kraft
   	     VM3 - Kraft
   	     VM4 - Broker
   	     VM5 - Broker
   	     VM6 - Broker
   	     VM7 - Schema Registry  
	     VM8 - Schema Registry
   	     VM9 - Connect
   	     VM10 - Connect
   	     VM11 - Rest Proxy
   	     VM12 - Rest Proxy
   	     VM13 - Control Center
   	     VM14 - Shared Services
   	     VM15 - Shared Services
   	       

6. What Kafka-role colocation combinations are allowed in the three-host minimum topology?
   [Response] - Refer to the updated topology in #5.

7. Which exact hosts count toward KU capacity, and what enforceable CPU/RAM/disk thresholds apply?
   [Respose] - The host capacity is based on the VM topology in #5.

8. Should exact shared-service image tags be frozen from the Kubernetes defaults at implementation time?
   [Repose] - At implementation time, identify and seed exact versions matching the default Kubernetes chart image versions. Once seeded, they remain pinned and do not automatically float.

9. What exact confluent.platform collection version supports all three CP package versions?
   [Respose] - Will support only 8.3.0 version. Other versions should be dropped and not required.

10. Who creates the shared-service certificate, and where is it uploaded?
    [Response] - It should support only user provided certificates i.e., certificates provided in "DNS & Certificates" under Settings page. The certificate must be wildcard certificate *.{domain} (similar to k8s)

11. What is the Kafka certificate upload cardinality and secret-storage shape?
    [Response] - Customer will provide certificates for all CP nodes which includes CA Certificate, host certificate and host private key.
    
12. Does customer-managed DNS resolution block Healthy?
    [Response] - 
    Fleet Manager should generate and display the required record set.
    It should verify resolution before marking the resource healthy.
    It should never create or delete customer-managed records.
    DELETE should return/display the records the customer may remove.

13. May secure file-specific modes be used instead of applying 755 to every file?
    [Response] - Use the recommended defaults.
    
14. Does DELETE remove named volumes, generated configuration, certificates, and bind-mounted data?
    [Response] - Use named Docker volumes where practical, delete them during fleet DELETE, and explicitly remove generated secrets/configuration from host storage.

15. Which public routes receive Kong basic authentication?
    [Response] - Prometheus, Loki and Alert Manager should have Kong basic auth. Grafana should handled its own authentication.
Copy
Clarification Review
Thank you. Most of the infrastructure and security decisions are now sufficiently clear.

The following are settled:

Keep the orchestrator on Python 3.13.

Accept unencrypted RSA, Ed25519, and ECDSA SSH keys.

Reject passphrase-protected SSH keys.

Use one SSH key for the bastion and destination hosts.

Defer SSH-key rotation.

Persist TOFU fingerprints in Fleet.metadata.

Automatically place services according to a Development or Production topology.

Support Confluent Platform 8.3.0 only.

Pin shared-service images to exact versions identified from the Kubernetes defaults at implementation time.

Use customer-uploaded wildcard domain certificates for shared services.

Treat customer DNS as declarative: Fleet Manager displays and verifies records but does not create or delete them.

Use secure file-specific permissions.

Delete Docker volumes and generated secret/configuration files during fleet deletion.

Apply Kong basic authentication to Prometheus, Loki, and Alertmanager; Grafana retains its own authentication.

I still have a small set of material questions. Most arise because the new prescribed topology changes parts of the checked-in plan rather than merely filling in missing details.

Remaining blocking questions
1. How does the user select Development versus Production?
The new topology has two operating modes, but neither plan currently defines an environment or topology field.

The Tranche 1 schema currently describes only:

SSH private key;

optional bastion;

host inventory. 

The Tranche 2 schema currently describes only role assignments, CP version, authentication, and custom properties. 

Clarification required
Where should the environment be selected?

Option A — Recommended: Fleet advanced configuration gains:

{
  "environment": "development" | "production"
}
The fleet validates inventory against that environment.

Option B: Kafka advanced configuration contains the environment.

Option C: Environment is inferred from fleet host count.

Option D: It is an organization-level setting.

Recommendation
Put environment in the BYOVM fleet advanced configuration because it determines which host purposes the inventory must contain before Kafka is created.

Please also confirm the exact wire values and UI labels:

Wire value	UI label
development	Development
production	Production
I do not recommend inferring the environment from host count. A seven-host Development full topology and seven-host Production minimum topology would be ambiguous.

2. Does automatic placement replace both shared-service earmarks and Kafka role assignment?
The new answer says service placement is automatic. The current plans say two different things:

Tranche 1
The user assigns individual shared services through each host’s shared_services list, and every service must appear exactly once. 

Tranche 2
The user manually chooses controllers, brokers, Schema Registry, and Control Center through multi-select fields. 

Clarification required
Does the new topology make all role assignment automatic?

Option A — Recommended interpretation
The user assigns each VM a single purpose.

Fleet Manager validates that the purposes match the selected environment/topology.

shared_services is no longer manually selected.

Tranche 2 automatically maps purpose values into cp-ansible groups.

The Kafka advanced form no longer asks users to select controller/broker/component hosts.

Option B
Shared-service placement is automatic.

Kafka roles remain manually selected in Tranche 2.

Option C
Both remain manually assigned, and “automatic” only refers to distributing the five shared-service containers among hosts marked shared-services.

The answer materially changes the API and UI scope, so one model needs to be designated authoritative.

3. What does “automatic” mean for multiple eligible hosts?
Even if the user continues assigning host purposes, Fleet Manager still needs a deterministic mapping algorithm.

Clarification required
For hosts with the same purpose, should the system:

use them all;

use the minimum required number;

choose the first hosts in inventory order;

or reject any count that is not one of the exact prescribed topologies?

For example, what happens to:

a Development fleet with four Kafka hosts and one shared-service host;

a Production fleet with five brokers;

a Production fleet with two Schema Registry hosts but no Connect hosts;

an inventory with extra unassigned hosts?

Recommendation
Treat the topology tables as minimums, not exact-only shapes:

validate minimum counts;

use every recognized role host;

allow extra hosts with valid purposes;

never silently leave a valid role host unused;

enforce one cluster per fleet as already planned. 

If only the listed “Minimum” and “Full” shapes are supported, please state that explicitly.

4. Connect and REST Proxy now conflict with the Tranche 2 scope
The updated topology includes:

Kafka Connect;

REST Proxy.

However, Tranche 2 explicitly excludes Connect and REST/Replicator. 

The success criteria describe only KRaft, Kafka, Schema Registry, and Control Center. 

Clarification required
Choose one:

Option A — Recommended for the existing two-PR scope: Connect and REST Proxy hosts may exist as reserved inventory purposes, but Tranche 2 does not install those components.

Option B: Expand Tranche 2 to install Connect and REST Proxy.

Option C: Remove Connect and REST Proxy from the full topology for these PRs.

If Option B is chosen, the checked-in plan requires a scope update because it affects:

Pydantic schemas;

cp-ansible groups and variables;

certificate uploads;

DNS records;

ports;

monitoring;

workflows;

frontend tests;

DELETE behavior.

5. Development topology omits Schema Registry and Control Center
The Development minimum contains only:

three KRaft + broker VMs;

one shared-services VM.

Development full adds Schema Registry, Connect, and REST Proxy, but still does not list Control Center.

The current Tranche 2 plan requires both:

at least one Schema Registry assignment;

at least one Control Center assignment. 

The overall workload description also says that cp-ansible installs Schema Registry and Control Center. 

Clarification required
Please specify component requirements by topology:

Environment/topology	Schema Registry	Control Center
Development minimum	Required / omitted / colocated?	Required / omitted / colocated?
Development full	Required / omitted?	Required / omitted / colocated?
Production minimum	Required / omitted / colocated?	Required / omitted / colocated?
Production full	Required	Required
Likely interpretation requiring confirmation
A possible intended model is:

Development minimum: Schema Registry and Control Center omitted.

Development full: Schema Registry installed; Control Center omitted.

Production minimum: Kafka only; Schema Registry and Control Center omitted.

Production full: both installed.

If that is correct, schema_registry and control_center cannot remain universally required fields in Tranche 2.

6. What happens to the single purpose enum for KRaft + broker hosts?
The existing fleet schema gives each host one required purpose. The relevant values are:

controller;

kafka;

schema-registry;

kafka-connect;

rest-proxy;

kafka-ui;

shared-services. 

The Development topology requires each of VM1–VM3 to be both KRaft and broker.

Clarification required
Choose one data model:

Option A — Add a combined purpose
kafka-controller-broker
Option B — Make purpose a list
"purposes": ["controller", "kafka"]
Option C — Keep one primary purpose and let environment topology infer the second role
For example, all Development kafka hosts automatically become controllers and brokers.

Option D — Separate inventory classification from component role assignment
{
  "purpose": "kafka",
  "roles": ["controller", "broker"]
}
Recommendation
Use explicit roles rather than inferring them invisibly. If the UI must remain simple, change the purpose schema to include a combined Development choice such as Controller and broker. This preserves the original closed-enum behavior and keeps topology visible to users.

7. Shared services across two Production VMs remain undefined
Production full includes two shared-services VMs. The original plan requires each of the five shared services to appear on exactly one host, so this is distribution, not replication. 

Clarification required
How should the five services be split?

Suggested deterministic assignment:

Shared-services host 1
Kong

Prometheus

Alertmanager

Shared-services host 2
Grafana

Loki

But that creates a dependency on host 1 for the single public gateway and requires Kong to reach Grafana/Loki on host 2.

Alternatively:

Host 1
Kong

Grafana

Prometheus

Host 2
Loki

Alertmanager

Please specify or approve a distribution.

Also confirm:

shared-{fleet}.{domain} points only to the Kong host.

No active-active Kong is required.

Prometheus and Loki remain single-instance services.

There is no shared-services failover in Tranche 1.

node_exporter and Promtail still run on every inventory host as required by the plan. 

8. Capacity still lacks an enforceable calculation
“The host capacity is based on the VM topology” tells us which machines exist but does not define how CPU, RAM, and disk translate to KU.

The checked-in requirement is explicit that implementation must call the existing KU derivation helper using VM hosts represented as nodes.  Tranche 2 also uses that result to rank fleet eligibility. 

Clarification required
Please confirm this proposed rule:

Development
Count the three or more combined KRaft/broker hosts toward KU.

Production
Count broker hosts only toward KU. Controller and ancillary-component hosts do not contribute to broker capacity.

Both
Use the existing FleetSizingService._derive_ku_capacity_from_probe CPU/RAM formula.

Do not count shared-service, Schema Registry, Connect, REST Proxy, or Control Center hosts.

Require at least three capacity-contributing hosts.

Treat disk as a separate pass/fail preflight rather than inventing a new KU formula.

If this rule is accepted, one final input remains: the minimum free disk per broker/controller host and the filesystem path to inspect.

Without an explicit disk threshold, the hardware requirement still cannot be programmatically enforced.

9. Passwordless sudo is the correct non-interactive alternative
You asked whether there is an alternative to passwordless sudo.

For unattended Paramiko and Ansible execution, the practical initial options are:

SSH directly as root.

SSH as a non-root user with passwordless sudo.

Store a sudo password as another secret and provide it to both Paramiko and Ansible.

Use a preinstalled privileged helper/agent.

Options 3 and 4 add new secrets, UI fields, and operational risk. They are not described in the plans.

Recommended contract
Allow:

direct root login; or

a non-root user for which sudo -n true succeeds.

Reject:

interactive sudo;

password-based SSH;

sudo requiring a TTY;

privilege escalation requiring a password.

The synchronous preflight should test:

sudo -n true
for non-root users. The runtime should consistently use non-interactive sudo.

Confirmation needed
Please confirm that this root-or-passwordless-sudo policy is acceptable.

10. The exact cp-ansible collection version remains unanswered
Dropping CP 8.1.5 and 8.2.3 simplifies compatibility, but it does not provide the exact confluent.platform collection pin.

The plan requires:

a cp_ansible_collection_version configuration value;

baking the collection into the orchestrator image. 

Clarification required
Please provide the exact collection version approved for Confluent Platform 8.3.0, or approve this implementation-time rule:

Select and pin the latest confluent.platform collection version that officially supports CP 8.3.0 and ansible-core 2.18; record that exact version in GlobalConfiguration and the worker build. Do not float it automatically.

The same exact pin must be used in local tests, CI, and the production worker image.

11. Per-node Kafka certificate mapping is still required
“Customer will provide certificates for all CP nodes” establishes that certificates are per node, but the API and secret shape remain unspecified.

The compute-components response must not contain PEMs; it may contain only materialized file-path placeholders. 

Clarification required
Please confirm the following proposed model.

One shared CA certificate per Kafka cluster
/organizations/{org}/kafka/{kafka_id}/certificates/ca
Contents:

CA certificate only;

no CA private key.

One TLS secret per assigned CP host
/organizations/{org}/kafka/{kafka_id}/certificates/hosts/{host_name}
Contents:

{
  "certificate": "<PEM>",
  "private_key": "<PEM>"
}
Validation
For every selected CP host:

certificate parses;

private key parses;

certificate matches private key;

certificate is not expired;

certificate chains to the uploaded CA;

SAN contains the inventory fqdn;

SAN contains every advertised DNS name assigned to that host.

UI
The Kafka advanced step shows a certificate/key upload row for every CP host selected by the resolved topology.

Questions
Is one cluster-level CA certificate correct?

Is the CA private key explicitly not uploaded?

Is one certificate/key pair per VM correct?

Should the same host certificate be used for all CP services colocated on that VM?

Is certificate rotation deferred, like SSH-key rotation?

12. DNS target addresses need an explicit field
Fleet Manager must verify that customer DNS resolves correctly. To do that, it needs to know the expected externally reachable address.

The current host schema contains:

fqdn;

ansible_host, described as the SSH IP. 

The SSH IP may be:

a private address;

reachable only through a bastion;

different from the client-facing address.

Clarification required
Should each host add a separate field such as:

{
  "public_address": "203.0.113.10"
}
or:

{
  "advertised_address": "203.0.113.10"
}
This would be the expected DNS target, while ansible_host remains strictly the management/SSH address.

Alternatively, should Fleet Manager merely verify that each required hostname resolves, without validating its resolved IP?

Recommendation
Add advertised_address. Otherwise “verify resolution” proves only that a record exists, not that it points to the correct VM.

For shared-{fleet}.{domain}, the advertised address should be the Kong host’s advertised address.

Non-blocking confirmations
These do not need to delay Tranche 1 design if the recommended assumptions are accepted.

A. Python 3.13
I will treat Python 3.13 as an explicit project decision. The existing orchestrator image already uses it. 

The Tranche 1 POC should therefore be treated as the final compatibility gate:

install the exact ansible-core pin on Python 3.13;

execute a real remote SSH play;

fail the PR if the POC cannot run.

That is stronger evidence for this codebase than a third-party compatibility table.

B. TOFU key changes
You specified fingerprint storage but not intentional replacement. Since SSH-key rotation is deferred, I recommend also deferring host-key replacement:

a changed fingerprint causes a hard failure;

users must contact an administrator or recreate the fleet.

A future explicit “trust replacement host key” operation can update the stored fingerprint safely.

C. Wildcard certificate
The existing custom-domain model stores certificate/key material and requires it when automatic creation is disabled. 

I will assume the selected domain must have a valid uploaded wildcard certificate covering *.{domain} and that Tranche 1 only distributes it to Kong/Grafana.

D. DNS and Healthy
I will assume:

Tranche 1 fleet Healthy requires shared-{fleet}.{domain} to resolve.

Tranche 2 Kafka Healthy requires all generated Kafka records to resolve.

DNS checks use bounded Temporal retries.

no DNS records are created or deleted.

delete confirmation/results list the records customers may remove.

E. Authentication
The intended route model is now clear:

Route	Authentication
/metrics	Kong basic auth using shared-credentials.metrics
/logs	Kong basic auth using shared-credentials.logs
/alerts	Kong basic auth using shared-credentials.alerts
/grafana	Grafana’s native login using shared-credentials.dashboard
This aligns with the endpoint set required by Tranche 1. 

Minimum answer set
The shortest set of answers needed to close requirements analysis is:

Where is Development/Production selected?

Does automatic placement replace manual shared-service and Kafka role assignment?

Are the listed topologies minimums or the only accepted exact shapes?

Are Connect and REST Proxy still out of scope?

For each topology, are Schema Registry and Control Center required, omitted, or colocated?

How should Development represent combined KRaft + broker in the host-purpose schema?

How are the five shared services distributed across two Production shared-service hosts?

Approve or amend the proposed KU host-counting rule and provide minimum disk/path requirements.

Confirm root or passwordless sudo -n as the only privilege modes.

Approve implementation-time selection and freezing of the exact cp-ansible collection version.

Approve or amend the proposed cluster-CA plus per-host certificate secret model.

Should the inventory add an advertised/public address for DNS verification?

After these decisions, I would consider the requirements sufficiently defined for Tranche 1 and Tranche 2 implementation planning.

Checks performed
✅ nl -ba .cursor/plans/byo-vm-fleet.md

✅ nl -ba .cursor/plans/kafka-on-byo-vms.md

✅ nl -ba fleet-manager-backend/core/schemas/fleet_config_schema.py

✅ nl -ba fleet-manager-orchestrator/Dockerfile

✅ git status --short --branch — the working tree remains clean; no files, commits, builds, or pull requests were created.

My response below. Do not make any code changes, do not create any PR.  let me know if you have any questions or clarifications.

1. Where is Development/Production selected?
   [Response] - There should be option to select in Advance Configuration. Use the recommendatation 

2. Does automatic placement replace manual shared-service and Kafka role assignment?
   [Response] - Change in scope. Deploy Shared Services based on the environment and topology selection (minimum, full)

3. Are the listed topologies minimums or the only accepted exact shapes?
   [Response] - Exach shapes

4. Are Connect and REST Proxy still out of scope?
   [Response] - Connect and REST Proxy are included in the scope. 

5. For each topology, are Schema Registry and Control Center required, omitted, or colocated?
   [Response] - Refer to the topology for minimum or full for developement and Production. Schema Registry and Control Center will be applicable only for Full in development and production environment. . Also the name of the full in Production should display "Full HA" in streamtime UI.

6. How should Development represent combined KRaft + broker in the host-purpose schema?
   [Response] - Use Option A

7. How are the five shared services distributed across two Production shared-service hosts?
   [Response] - Host1 - Kong, Grafana, Prometheus
    		Host2 - Loki, Alert Manager

8. Approve or amend the proposed KU host-counting rule and provide minimum disk/path requirements.
   [Response] - Not Applicable. VM will be shared by customer and use the same for deployment

9. Confirm root or passwordless sudo -n as the only privilege modes.
   [Response] - User will have sudo privileges and can SSH without password.

10. Approve implementation-time selection and freezing of the exact cp-ansible collection version.
    [Response] - 8.3.0

11. Approve or amend the proposed cluster-CA plus per-host certificate secret model.
    [Response] - One shared CA certificate per Kafka cluster, One TLS secret per assigned CP host

12. Should the inventory add an advertised/public address for DNS verification?
    [Response] - DNS server IP address can be requested from customer
Copy
Requirements Review
Thank you. The responses resolve most topology questions, but six material clarifications remain. The most important are:

Development Full still has no Control Center host.

Removing KU capacity conflicts with the existing fleet-selection contract.

A DNS server IP does not identify the target IP expected in an A record.

The exact-shape topology needs a deterministic host-to-role assignment contract.

Passwordless SSH and passwordless sudo are different requirements.

The collection version and Confluent Platform version need to be distinguished explicitly.

Connect and REST Proxy are now confirmed in scope, which is a substantive expansion of Tranche 2 and will require the checked-in plan to be treated as superseded where it excludes those components. The current plan explicitly lists Connect and REST as out of scope. 

No code, files, commits, builds, or pull requests were created.

Confirmed requirements
Fleet advanced configuration
The BYOVM advanced configuration will include:

Environment
├── Development
└── Production

Topology
├── Minimum
└── Full / Full HA
Recommended wire values:

{
  "environment": "development",
  "topology": "minimum"
}
and:

{
  "environment": "production",
  "topology": "full"
}
Recommended UI labels:

Environment	Topology wire value	UI label
Development	minimum	Minimum
Development	full	Full
Production	minimum	Minimum
Production	full	Full HA
The environment and topology belong in fleet advanced configuration because they determine the required inventory shape. The current plan already places inventory in advanced configuration rather than placement. 

Exact topology validation
The four listed topologies are exact shapes, not minimum counts. Fleet validation must reject missing or additional role hosts.

Shared-service placement
Shared-service placement is automatic:

Development Minimum: all shared services on its one shared-services host.

Development Full: all shared services on its one shared-services host.

Production Minimum: all shared services on its one shared-services host.

Production Full / Full HA:

Shared host 1: Kong, Grafana, Prometheus.

Shared host 2: Loki, Alertmanager.

node_exporter and Promtail still run on every host unless separately changed; that remains an explicit Tranche 1 requirement. 

Development combined role
Development uses a new combined purpose, corresponding to:

controller-broker
Recommended UI label:

Controller and broker
This supplements the existing closed purpose enum, which currently has separate controller and kafka values. 

Certificates
Shared services use the customer-provided wildcard certificate from Settings → DNS & Certificates.

Kafka uses one shared CA certificate per cluster.

Every assigned CP host gets its own TLS secret containing its host certificate and host private key.

Secure file-specific permissions are allowed.

Certificates and generated secret/configuration files are removed from hosts on DELETE.

Authentication
Prometheus: Kong basic authentication.

Loki: Kong basic authentication.

Alertmanager: Kong basic authentication.

Grafana: native Grafana authentication.

Shared credentials remain idempotent across retries and updates.

Confluent Platform
Only Confluent Platform 8.3.0 is supported.

Connect and REST Proxy are included.

The orchestrator remains on Python 3.13.

SSH accepts unencrypted RSA, Ed25519, and ECDSA keys supported by Paramiko.

Passphrase-protected keys are rejected.

TOFU fingerprints are persisted in Fleet.metadata.

Remaining blocking clarifications
1. Development Full has no Control Center host
You said Schema Registry and Control Center apply only to Full topologies in both environments.

However, the Development Full topology previously supplied was:

VM1 - KRaft + Broker
VM2 - KRaft + Broker
VM3 - KRaft + Broker
VM4 - Schema Registry
VM5 - Connect
VM6 - REST Proxy
VM7 - Shared Services
There is no Control Center VM.

The current Tranche 2 plan expects a control_center role/group and previously required at least one Control Center host. 

Clarification required
Which Development Full shape is correct?

Option A — Recommended: add a dedicated VM
VM1 - Controller + Broker
VM2 - Controller + Broker
VM3 - Controller + Broker
VM4 - Schema Registry
VM5 - Connect
VM6 - REST Proxy
VM7 - Control Center
VM8 - Shared Services
Option B: colocate Control Center
Please specify where:

Schema Registry host;

Connect host;

REST Proxy host;

one controller/broker host;

or shared-services host.

Option C: no Control Center in Development Full
If this is selected, the statement that Control Center applies to Development Full should be revised.

2. Exact topology needs an explicit host-role assignment model
The current fleet plan requires every inventory host to have a purpose enum. 

“Automatic placement” could mean either:

The user assigns purposes, and Fleet Manager validates the exact count.

The user enters an ordered list of generic hosts, and Fleet Manager assigns purposes based on list order.

Clarification required
Please confirm which model applies.

Option A — Recommended
The user selects a purpose for every host. Fleet Manager:

validates exact purpose counts for the selected environment/topology;

automatically derives shared-service placements and cp-ansible groups from those purposes;

does not ask users to repeat role assignments during Kafka creation.

For example, Production Full / Full HA must contain exactly:

Purpose	Count
Controller	3
Broker	3
Schema Registry	2
Connect	2
REST Proxy	2
Control Center	1
Shared services	2
Total	15
Option B
Fleet Manager assigns roles by inventory order:

hosts[0:3] → controllers
hosts[3:6] → brokers
...
I recommend against this because reordering a UI array could silently change the deployment topology.

Follow-up confirmation
Assuming Option A, should the Kafka create advanced step remove all manual host multi-selects and show only a read-only topology summary plus certificates/authentication?

The existing plan currently expects manual controller, broker, Schema Registry, and Control Center assignments.  Automatic topology would supersede that design.

3. KU cannot simply be “not applicable” without replacing fleet selection logic
The checked-in requirements currently use derived Kafka units for two purposes:

Tranche 1 derives and persists VM capacity using the existing BYOK formula. 

Tranche 2 uses remaining KU to determine and rank eligible fleets. 

Your response says KU host counting is “Not Applicable” because the VMs are supplied by the customer.

Customer ownership does not by itself resolve what values the existing API requires or how fleet eligibility works.

Clarification required
Please choose a replacement contract.

Option A — Recommended: remove KU as a BYOVM capacity concept
For BYOVM:

do not derive vm_capacity_kafka_units;

do not set capacity from CPU/RAM;

hide the KU field in UI as already planned;

eligibility is based on:

exact valid topology;

Healthy fleet;

Dedicated tenancy;

no existing Kafka cluster;

continue posting a compatibility value such as kafka_units=1 only because the existing serializer requires it;

do not use that value to size CP or rank BYOVM fleets.

This fits the exact one-cluster-per-fleet topology better than pretending the predefined cluster is a variable KU pool.

Option B
Keep the original derived KU behavior.

If so, the capacity-contributing hosts and CPU/RAM calculation still must be specified.

Important consequence
If Option A is accepted, several original Tranche 1 success criteria and tests must be removed or rewritten because they explicitly require derived KU. 

Topology collection should still persist CPU, RAM, disk, and OS for inventory visibility and preflight diagnostics even if KU derivation is removed.

4. “DNS server IP” is different from the expected DNS record target
A DNS server IP answers DNS queries. It does not tell Fleet Manager which IP a record should resolve to.

For example:

DNS resolver:
10.0.0.53

Required record:
broker-1.example.com → 203.0.113.21
Knowing 10.0.0.53 lets Fleet Manager query the DNS server, but it does not establish whether 203.0.113.21 is the correct broker address.

The host schema currently only defines ansible_host, described as the SSH IP.  That could be a private address behind a bastion rather than the advertised Kafka address.

Clarification required
I recommend adding both concepts:

{
  "dns_server": "10.0.0.53",
  "hosts": [
    {
      "ansible_host": "10.10.0.21",
      "advertised_address": "203.0.113.21"
    }
  ]
}
Where:

dns_server is optional and identifies a customer DNS resolver.

ansible_host is the SSH/control address.

advertised_address is the expected A/AAAA record target.

Please confirm:

Should dns_server be optional or required?

Is it one resolver for the whole fleet?

Should each host supply advertised_address?

Is advertised_address always an IP, or may it be another hostname?

Should DNS verification query the supplied resolver rather than the worker’s system resolver?

Alternative
If ansible_host is guaranteed to be both the SSH address and advertised DNS target, no new host field is needed. Please explicitly confirm that guarantee if it is intended.

5. Passwordless SSH does not imply passwordless sudo
The response says:

User will have sudo privileges and can SSH without password.

Key-based SSH authentication only proves that SSH does not need a password. The remote user may still receive a password prompt when running sudo.

Because this is non-interactive automation, Paramiko and Ansible cannot respond unless another password secret and prompt-handling design are added.

The original plan already allows root or passwordless sudo. 

Clarification required
Please confirm this precise precondition:

The SSH user must be able to execute sudo -n true successfully without a password or interactive prompt.

The synchronous validation would run:

sudo -n true
and reject the host if it fails.

No sudo password would be requested or stored.

This is the strongly recommended approach.

6. Confirm that both collection and product version are 8.3.0
Your answer to the collection-version question was 8.3.0. You also previously selected Confluent Platform 8.3.0.

Please confirm that these are two distinct pins:

confluent.platform Ansible collection: 8.3.0
Confluent Platform package version:     8.3.0
The collection version is baked into the orchestrator image, while the package version is emitted through cp-ansible variables. The plan requires the collection to be baked and configured separately. 

If 8.3.0 only refers to the Confluent Platform product, the collection pin remains unresolved.

Scope details needed for Connect and REST Proxy
Because these components are newly included, four smaller decisions are needed. These can be answered together.

7. Component groups and installation
Please confirm that compute-components must now include:

kafka_controller
kafka_broker
schema_registry
kafka_connect
kafka_rest
control_center
The current plan lists only the first four groups excluding Connect and REST Proxy. 

8. DNS names
Please confirm the desired generated names.

Recommended:

{kafka}-connect-{i}.{domain}
{kafka}-rest-proxy-{i}.{domain}
Should these records be:

created/displayed for every instance;

required to resolve before Kafka becomes Healthy;

protected by the same customer-managed DNS policy?

9. Certificates
Please confirm that Connect and REST Proxy hosts follow the same per-host certificate model:

one cluster CA certificate;

one host certificate;

one host private key per VM.

10. Monitoring
Should Connect and REST Proxy receive JMX exporter configuration and Prometheus scrape jobs in this tranche?

The current monitoring requirement mentions only controller :8079 and broker :8080. 

If yes, the required JMX ports and dashboard/PromQL expectations need to be specified or delegated to cp-ansible defaults.

Certificate workflow clarification
11. Where are per-host CP certificates uploaded?
The shared-services wildcard certificate location is settled: Settings → DNS & Certificates.

The per-host CP certificate location is not yet settled.

Recommended workflow
During Kafka creation, after the fleet topology is selected:

Fleet Manager resolves all CP hosts automatically.

Advanced Configuration renders one certificate/key upload section per CP host.

The customer uploads:

one cluster CA certificate;

one certificate and key per host.

Backend validates all pairs.

PEM material is written directly to the secret abstraction.

Persisted Kafka advanced configuration keeps only secret references or host names, never PEM values.

Compute-components contains materialization placeholders, never PEMs, consistent with the plan. 

Confirmation requested
Please confirm this workflow and whether certificate replacement/rotation is out of scope for these two PRs.

One topology naming clarification
12. Should API wire values remain stable while only the UI label changes?
You requested Full HA for Production in the UI.

I recommend:

{
  "environment": "production",
  "topology": "full"
}
with UI label:

Full HA
rather than using full-ha as a different production-only wire value.

That produces a simple matrix:

Environment	Wire value	UI label
Development	minimum	Minimum
Development	full	Full
Production	minimum	Minimum
Production	full	Full HA
Please confirm.

Recommended exact topology interpretation
Subject to the unresolved Development Control Center question, I understand the desired shapes as follows.

Development Minimum
Purpose	Count
Controller and broker	3
Shared services	1
Total	4
Development Full
Current interpretation, but incomplete because Control Center placement is unresolved:

Purpose	Count
Controller and broker	3
Schema Registry	1
Connect	1
REST Proxy	1
Control Center	TBD
Shared services	1
Total	7 or 8
Production Minimum
Purpose	Count
Controller	3
Broker	3
Shared services	1
Total	7
Production Full / Full HA
Purpose	Count
Controller	3
Broker	3
Schema Registry	2
Connect	2
REST Proxy	2
Control Center	1
Shared services	2
Total	15
Fleet creation should reject an inventory whose counts differ from the selected exact topology.

Short answer set requested
The remaining questions can be answered concisely as follows:

Development Full: add a Control Center VM, colocate it, or omit Control Center?

Do users assign each host’s purpose, with Fleet Manager only validating and deriving placement?

Remove KU derivation and use exact topology/one-cluster-per-fleet eligibility?

For DNS, do we need both a fleet resolver address and a per-host advertised address?

Must sudo -n true succeed?

Are both the collection and CP product pinned to 8.3.0?

Confirm Connect/REST cp-ansible groups, DNS names, TLS, and JMX monitoring.

Are CP certificates uploaded during Kafka advanced configuration and rotation deferred?

Should topology wire value stay full, displayed as Full HA only for Production?

Once these points are settled, the functional requirements will be complete enough to plan the two implementation PRs without substantial assumptions.

Checks performed
✅ nl -ba .cursor/plans/byo-vm-fleet.md

✅ nl -ba .cursor/plans/kafka-on-byo-vms.md

✅ nl -ba fleet-manager-backend/core/schemas/fleet_config_schema.py

✅ nl -ba fleet-manager-orchestrator/Dockerfile

✅ git status --short --branch — working tree remains clean; no code changes, commits, builds, or pull requests were created.

- **`dns_server`** is optional and identifies a customer DNS resolver.
- **`ansible_host`** is the SSH/control address.
- **`advertised_address`** is the expected A/AAAA record target.

can you explain this? i will then provide my response to #4.
Copy
Explanation of the Three Network Fields
These fields represent three different parts of the connection path:

Fleet Manager ──SSH──> VM
       │
       └──DNS query──> DNS resolver

Customer/application ──DNS name──> advertised VM address
They may contain the same IP in a simple environment, but they can be different in private networks, bastion-based deployments, split DNS, and NAT environments.

1. dns_server: where Fleet Manager asks DNS questions
{
  "dns_server": "10.0.0.53"
}
dns_server identifies the DNS resolver that Fleet Manager should query when verifying customer-created DNS records.

For example, Fleet Manager may need to verify:

shared-fleet1.example.com
kafka1-b0.example.com
kafka1-bootstrap.example.com
It can ask the supplied resolver:

Query 10.0.0.53:
What address does kafka1-b0.example.com resolve to?
The resolver might answer:

kafka1-b0.example.com → 203.0.113.21
Important distinction
10.0.0.53 is not the Kafka broker’s address. It is only the server answering the DNS query.

This is analogous to public DNS resolvers such as:

8.8.8.8
1.1.1.1
Those addresses belong to DNS resolvers, not to the website or application being looked up.

Why would a customer provide this?
A customer-provided resolver is useful when records exist only in private or corporate DNS:

Customer DNS resolver: 10.0.0.53
Private DNS record:     kafka1-b0.corp.example.com → 10.20.1.21
Fleet Manager’s normal system resolver might not know about corp.example.com, while the customer’s resolver does.

Why optional?
If it is omitted, Fleet Manager can use the backend/orchestrator environment’s normal configured resolver—for example the resolver from /etc/resolv.conf.

Suggested scope
I would model dns_server once per fleet, not once per host:

{
  "dns_server": "10.0.0.53",
  "hosts": [...]
}
It could accept:

an IPv4 resolver address;

an IPv6 resolver address.

Supporting custom DNS ports, DNS-over-TLS, or DNS-over-HTTPS does not appear necessary for the initial implementation unless the customer requires it.

2. ansible_host: how Fleet Manager reaches the VM over SSH
{
  "ansible_host": "10.20.1.21"
}
ansible_host is the management/control address used for:

Paramiko SSH validation;

system-information collection;

Docker and Compose installation;

Ansible SSH for Confluent Platform;

subsequent host checks and deletion.

The existing plan already defines ansible_host as the host IP used with ssh_user and ssh_port.  It also requires the create request to SSH-connect to every inventory host using those connection details. 

Direct-access example
{
  "ansible_host": "10.20.1.21",
  "ssh_port": 22,
  "ssh_user": "streamtime"
}
Fleet Manager connects directly to:

10.20.1.21:22
Bastion example
{
  "bastion": {
    "host": "198.51.100.10",
    "port": 22,
    "user": "jump-user"
  },
  "hosts": [
    {
      "ansible_host": "10.20.1.21",
      "ssh_port": 22,
      "ssh_user": "streamtime"
    }
  ]
}
The connection path becomes:

Fleet Manager
    │
    │ SSH
    ▼
198.51.100.10       Bastion
    │
    │ forwarded SSH connection
    ▼
10.20.1.21          Target VM
Here, 10.20.1.21 may not be reachable directly from the internet. That is acceptable because it is only the management address reached through the bastion.

Key characteristic
ansible_host answers this question:

At which address should Fleet Manager establish the SSH control connection to this VM?

It does not necessarily answer:

At which address should Kafka clients reach the VM?

3. advertised_address: where customer-created DNS should point
{
  "advertised_address": "203.0.113.21"
}
advertised_address is the expected client-facing address for the VM.

The customer creates a DNS record such as:

kafka1-b0.example.com → 203.0.113.21
Fleet Manager can then verify:

Query the configured DNS resolver.

Resolve kafka1-b0.example.com.

Compare the result with advertised_address.

Mark DNS ready only if they match.

The Tranche 2 plan requires generated DNS names for brokers, bootstrap, Schema Registry, and Control Center.  The Tranche 1 plan similarly requires shared-{fleet}.{domain} to point to the Kong host. 

Why not always use ansible_host?
Because SSH/control traffic and client traffic can use different network paths.

For example:

Private SSH address:  10.20.1.21
Public client address: 203.0.113.21
The VM may sit behind NAT:

Kafka client
    │
    ▼
203.0.113.21         Public/NAT address
    │
    ▼
10.20.1.21           VM private address
In that case:

{
  "ansible_host": "10.20.1.21",
  "advertised_address": "203.0.113.21"
}
If Fleet Manager incorrectly expected DNS to resolve to ansible_host, it would reject the valid customer record:

kafka1-b0.example.com → 203.0.113.21
because it would be comparing it to the private address 10.20.1.21.

Private-only example
In an entirely private deployment, the two values may be identical:

{
  "ansible_host": "10.20.1.21",
  "advertised_address": "10.20.1.21"
}
The DNS record would then be:

kafka1-b0.corp.example.com → 10.20.1.21
That is valid if Kafka clients use the same private network.

Complete example
Consider a customer with:

a private corporate DNS server;

target VMs reachable over SSH through a bastion;

public/NAT addresses for Kafka clients.

Fleet input
{
  "dns_server": "10.0.0.53",
  "bastion": {
    "host": "198.51.100.10",
    "port": 22,
    "user": "jump-user"
  },
  "hosts": [
    {
      "name": "broker-1",
      "fqdn": "broker-1.example.com",
      "purpose": "kafka",
      "ansible_host": "10.20.1.21",
      "advertised_address": "203.0.113.21",
      "ssh_user": "streamtime",
      "ssh_port": 22
    }
  ]
}
What each field means
Field	Value	Meaning
dns_server	10.0.0.53	Ask this DNS resolver when checking records
Bastion host	198.51.100.10	First SSH hop
ansible_host	10.20.1.21	Private address used to manage the VM
advertised_address	203.0.113.21	Address Kafka clients should reach
fqdn	broker-1.example.com	Human/customer hostname associated with the host
Connection flow
Fleet Manager
  └─ SSH via 198.51.100.10
       └─ manages VM at 10.20.1.21
DNS verification flow
Fleet Manager
  └─ asks resolver 10.0.0.53:
       “What is kafka1-b0.example.com?”

Resolver response:
  kafka1-b0.example.com → 203.0.113.21

Expected advertised_address:
  203.0.113.21

Result:
  Match → DNS check passes
Shared-services example
Suppose the Kong/shared-services VM has:

{
  "name": "shared-1",
  "ansible_host": "10.20.1.50",
  "advertised_address": "203.0.113.50"
}
The customer creates:

shared-fleet1.example.com → 203.0.113.50
Fleet Manager:

installs Kong through SSH at 10.20.1.50;

queries shared-fleet1.example.com;

expects it to resolve to 203.0.113.50;

verifies the HTTPS endpoint using the customer’s wildcard certificate;

marks shared-service DNS ready.

The plan requires the one shared hostname to point to the host running Kong. 

Broker and bootstrap DNS example
Assume three brokers:

Broker	SSH/control address	Advertised address
Broker 0	10.20.1.21	203.0.113.21
Broker 1	10.20.1.22	203.0.113.22
Broker 2	10.20.1.23	203.0.113.23
Customer-created records could be:

kafka1-b0.example.com → 203.0.113.21
kafka1-b1.example.com → 203.0.113.22
kafka1-b2.example.com → 203.0.113.23
The bootstrap record has a design choice:

Multiple-address bootstrap record
kafka1-bootstrap.example.com → 203.0.113.21
kafka1-bootstrap.example.com → 203.0.113.22
kafka1-bootstrap.example.com → 203.0.113.23
Load-balancer bootstrap record
kafka1-bootstrap.example.com → 203.0.113.100
If a customer load balancer is supported, the bootstrap target might not correspond to any single host. In that situation, the model might also need a cluster-level bootstrap_advertised_address.

For the initial design, the simpler assumption would be a multi-address bootstrap record containing every broker’s advertised_address.

What if all three are the same in a simple setup?
A small private environment might use:

{
  "dns_server": "10.0.0.53",
  "ansible_host": "10.20.1.21",
  "advertised_address": "10.20.1.21"
}
That is perfectly valid:

10.0.0.53 answers DNS queries;

Fleet Manager SSHs to 10.20.1.21;

clients also connect to 10.20.1.21.

Separate fields still make the roles unambiguous.

Why fqdn is not sufficient
The current inventory also contains fqdn. 

For example:

{
  "fqdn": "broker-1.internal.example.com"
}
This is a hostname, not necessarily an address Fleet Manager can compare against a generated record.

It could itself resolve differently depending on the network:

From the corporate network:
broker-1.internal.example.com → 10.20.1.21

From public DNS:
broker-1.internal.example.com → no record
The Tranche 2 workflow also generates separate service names such as:

kafka1-b0.example.com
kafka1-bootstrap.example.com
Those names are not necessarily identical to the inventory fqdn. The advertised address therefore gives Fleet Manager a concrete expected target.

Recommended interpretation for question #4
My recommendation is:

Fleet-level field
{
  "dns_server": "10.0.0.53"
}
Optional.

One resolver per fleet.

IPv4 or IPv6 address.

Used for DNS checks.

If omitted, use the system resolver.

Host-level fields
{
  "ansible_host": "10.20.1.21",
  "advertised_address": "203.0.113.21"
}
ansible_host is required and used only for SSH/control access.

advertised_address is required for any host receiving a client-facing DNS name.

advertised_address should initially be an IPv4 or IPv6 address, not another hostname.

Shared-services hosts not running Kong would not necessarily need an advertised address.

Controller-only hosts might not need one unless clients or other CP components access them through generated DNS.

Verification
resolved A/AAAA values == expected advertised_address
For a record with multiple valid targets, such as bootstrap:

resolved address set == expected broker advertised-address set
This makes the DNS readiness check deterministic rather than checking only that some record exists.

Simplified alternatives
If this feels too complex, there are two simpler contracts.

Alternative A: one address per host
Declare that:

ansible_host is always both:
1. the SSH address; and
2. the DNS target/client address.
Then advertised_address is unnecessary.

This is simple but excludes common bastion/NAT/split-network deployments.

Alternative B: do not validate record targets
Accept only dns_server, query each required name, and pass when it returns at least one A/AAAA record.

This supports more network models but cannot detect a record pointing to the wrong VM.

Recommendation
Keep separate ansible_host and advertised_address. It is a small schema addition that avoids conflating management and client traffic.

Checks referenced
✅ nl -ba .cursor/plans/byo-vm-fleet.md | sed -n '176,184p;242,251p'

✅ nl -ba .cursor/plans/byo-vm-fleet.md | sed -n '83,94p'

✅ nl -ba .cursor/plans/kafka-on-byo-vms.md | sed -n '156,160p'

✅ git status --short --branch — no files were changed, and no commit or pull request was created.

Below are my response to "Short answer set requested". Go throgh them and let me know if you have any questions. Do not make any code changes, do not raise any PR.  Notice the correction mentioned for #4.

1. Development Full: add a Control Center VM, colocate it, or omit Control Center?
   [Response] - Omit Control Center for Development envrionment.

2. Do users assign each host’s purpose, with Fleet Manager only validating and deriving placement?
   [Response] - Use Option A
   
3. Remove KU derivation and use exact topology/one-cluster-per-fleet eligibility?
   [Response] - Use Option A. I will update the success criteria and tests based on the recent changes.

4. For DNS, do we need both a fleet resolver address and a per-host advertised address?
   [Response] - Small correction which I forgot to mention earlier. ansible will be executed from the orchestrator-worker using the ansible python SDK. Which assumes that VMs are reachable from orchestrator-worker from the streamtime deployment. 

5. Must sudo -n true succeed?
   [Response] - Not required. 

6. Are both the collection and CP product pinned to 8.3.0?
   [Response] - You need to download ansible playbook for Confluent Platform. Refer to link https://docs.confluent.io/ansible/current/ansible-download.html#download-the-cp-collection-from-the-github-source-repository
                The CP will be installed using cp-ansible playbook which you will be building it and assume installation using internet.


7. Confirm Connect/REST cp-ansible groups, DNS names, TLS, and JMX monitoring.
   [Response] - The compute component must include below listed components:
    		kafka_controller
		kafka_broker
		schema_registry
		kafka_connect
		kafka_rest
		control_center

8. Are CP certificates uploaded during Kafka advanced configuration and rotation deferred?
    [Response] - Provide option to customer to upload one cluster CA certificate, one certificate and key for one cluster. Usually customer will have SAN containing list of all hosts within the certificate.

9. Should topology wire value stay full, displayed as Full HA only for Production?
   [Response] - Use recommendation.
Copy
Requirements Review
Thank you. These responses settle the principal product model:

Development omits Control Center.

Users assign a purpose to each host.

Fleet Manager validates the inventory against one of four exact topology shapes.

Fleet Manager derives component placement from those purposes.

BYOVM no longer derives or ranks by Kafka Units.

BYOVM eligibility becomes exact-topology, Healthy, Dedicated, and one-cluster-per-fleet based.

Production uses the stable wire value full, displayed as Full HA.

Kafka uses one cluster CA plus one cluster-wide certificate/key pair whose SANs cover all required hosts.

cp-ansible is downloaded from the GitHub source repository and baked for internet-connected installation.

The compute-components model includes controller, broker, Schema Registry, Connect, REST Proxy, and Control Center groups.

There are five remaining material clarifications. Two of the responses—DNS/reachability and sudo—clarify part of the question but do not yet provide an implementable contract.

No code, files, commits, builds, or pull requests were created.

Final topology understanding
Unless corrected, I now understand the exact topology matrix as follows.

Development Minimum
Purpose	Count
Controller and broker	3
Shared services	1
Total	4
Installed Confluent components:

KRaft controllers;

Kafka brokers.

Not installed:

Schema Registry;

Connect;

REST Proxy;

Control Center.

Development Full
Purpose	Count
Controller and broker	3
Schema Registry	1
Connect	1
REST Proxy	1
Shared services	1
Total	7
Installed Confluent components:

KRaft controllers;

Kafka brokers;

Schema Registry;

Connect;

REST Proxy.

Not installed:

Control Center.

Production Minimum
Purpose	Count
Controller	3
Broker	3
Shared services	1
Total	7
Installed Confluent components:

KRaft controllers;

Kafka brokers.

Not installed:

Schema Registry;

Connect;

REST Proxy;

Control Center.

Production Full / Full HA
Purpose	Count
Controller	3
Broker	3
Schema Registry	2
Connect	2
REST Proxy	2
Control Center	1
Shared services	2
Total	15
Installed Confluent components:

KRaft controllers;

Kafka brokers;

Schema Registry;

Connect;

REST Proxy;

Control Center.

The existing plan currently treats Schema Registry and Control Center as universally required, so the updated implementation will need topology-dependent optional groups instead. 

Remaining material clarifications
1. Direct worker reachability does not fully resolve DNS targeting
Your correction establishes this important requirement:

The orchestrator worker directly reaches the VMs and runs Ansible through the Python API.

That means ansible_host is an address routable from the orchestrator worker. It may eliminate the need for a bastion in many deployments, but it does not necessarily establish what the customer-created DNS record should point to.

For example:

Orchestrator worker network:
ansible_host = 10.20.1.21

Kafka client network:
broker DNS = 203.0.113.21
The orchestrator can directly reach the private address while clients use a public NAT address.

Clarification required
Please choose one of these contracts.

Option A — Simplest
Guarantee that ansible_host is both:

the SSH/Ansible address reachable from the backend and orchestrator; and

the address customer DNS records must resolve to.

Under this contract:

{
  "ansible_host": "10.20.1.21"
}
and:

kafka1-b0.example.com → 10.20.1.21
No advertised_address field is needed.

Option B — More flexible
Keep separate fields:

{
  "ansible_host": "10.20.1.21",
  "advertised_address": "203.0.113.21"
}
Fleet Manager uses ansible_host for SSH.

Kafka advertised listeners and customer DNS use advertised_address.

Recommendation
If all Streamtime and Kafka clients are guaranteed to share the same routed network, use Option A. Otherwise use Option B.

Backend reachability also needs confirmation
The checked-in Tranche 1 plan requires the backend, before persistence or Temporal dispatch, to Paramiko-connect to every host. 

Therefore, please confirm one of:

the backend and orchestrator worker can both directly reach every ansible_host; or

synchronous validation should be moved away from the backend.

The latter would be a significant change because the current success criterion requires failure before a fleet row is persisted or Temporal is dispatched. 

Minimal answer needed
Please confirm:

ansible_host is reachable from both the backend and orchestrator worker, and customer DNS records resolve to that same address.

If that sentence is true, neither dns_server nor advertised_address is strictly required. Fleet Manager can use its normal resolver and compare DNS results against ansible_host.

If customer-private DNS cannot be queried through the Streamtime deployment’s normal resolver, an optional dns_server is still needed.

2. Privilege escalation remains operationally unresolved
You answered that sudo -n true is not required.

There are two possible meanings:

Interpretation A
The user has passwordless sudo, but Fleet Manager should not test it synchronously.

In that case, runtime commands can still use:

sudo -n ...
and installation fails asynchronously if the customer configured sudo incorrectly.

Interpretation B
The user may need to enter a sudo password.

That cannot work with the currently defined non-interactive workflow because:

there is no sudo-password field;

no sudo-password secret is defined;

Paramiko commands cannot interactively prompt;

the Ansible inventory does not contain ansible_become_password;

the plan forces ansible_become without defining password handling. 

Clarification required
Please confirm this proposed contract:

The SSH user must have passwordless sudo. Fleet Manager does not have to run sudo -n true during synchronous validation, but all runtime privilege escalation is non-interactive. If passwordless sudo is not actually configured, the Temporal workflow fails with a clear host-specific error.

Under that contract:

no sudo password is collected;

no interactive prompt is supported;

root SSH is not required;

the customer is responsible for passwordless sudo;

a failed privilege check occurs in the workflow rather than the create request.

This is implementable. Allowing sudo that requires a password is not implementable without additional credentials and schema changes.

3. An exact cp-ansible source revision is still required
Your answer explains how cp-ansible should be obtained:

download the collection from its GitHub source repository;

build it;

bake it into the worker;

assume target installation has internet access.

That resolves the installation mechanism, but the worker build still needs an immutable Git reference.

Without a pin, a future image build could pull different code while still claiming to support CP 8.3.0.

Clarification required
Please approve this rule:

During implementation, identify the GitHub release tag corresponding to Confluent Platform/collection 8.3.0, pin the worker build to that exact tag and resolved commit SHA, build the collection artifact from that source, and install the built artifact into the worker image.

The build should not use:

main
master
latest
HEAD
without a commit pin.

Important distinction
These may or may not use the same version number:

Confluent Platform package:        8.3.0
confluentinc/cp-ansible Git tag:   TBD
built confluent.platform version:  TBD
If the official source repository tag for this CP release is not literally 8.3.0, the implementation should use the officially corresponding release tag rather than assuming version-number equality.

Recommendation
Permit the implementer to determine and lock the exact compatible source tag/commit during Tranche 2, with a test or build assertion recording the installed collection version.

4. Empty component groups need an explicit response contract
You confirmed that compute-components supports all six groups:

kafka_controller
kafka_broker
schema_registry
kafka_connect
kafka_rest
control_center
But not every topology installs all six components.

The current workflow requirement says it should fail if compute-components is missing groups or hosts.  That behavior must change now that component presence is topology-dependent.

Clarification required
For components omitted by a selected topology, should compute-components:

Option A — Recommended: include an empty group
Development Minimum example:

{
  "all": {
    "children": {
      "kafka_controller": {
        "hosts": {
          "vm1": {},
          "vm2": {},
          "vm3": {}
        }
      },
      "kafka_broker": {
        "hosts": {
          "vm1": {},
          "vm2": {},
          "vm3": {}
        }
      },
      "schema_registry": {
        "hosts": {}
      },
      "kafka_connect": {
        "hosts": {}
      },
      "kafka_rest": {
        "hosts": {}
      },
      "control_center": {
        "hosts": {}
      }
    }
  }
}
Option B: omit unused groups entirely
{
  "all": {
    "children": {
      "kafka_controller": {...},
      "kafka_broker": {...}
    }
  }
}
Recommendation
Use Option A if cp-ansible accepts empty groups. It provides a stable response shape and clearly communicates that the component is supported but disabled for this topology.

If cp-ansible treats an empty group differently or rejects it, use Option B and validate required groups based on environment/topology.

5. Connect and REST Proxy requirements remain incomplete
The response confirms their compute-component group names, but the earlier question also covered:

DNS;

TLS;

JMX monitoring.

These now need decisions because Connect and REST Proxy are newly in scope.

DNS
Recommended names
For Development Full:

{kafka}-connect.{domain}
{kafka}-rest-proxy.{domain}
For Production Full / Full HA, where two hosts exist per component:

{kafka}-connect-0.{domain}
{kafka}-connect-1.{domain}

{kafka}-rest-proxy-0.{domain}
{kafka}-rest-proxy-1.{domain}
Alternatively, use one shared name with multiple A/AAAA records:

{kafka}-connect.{domain} → [connect host 1, connect host 2]
{kafka}-rest-proxy.{domain} → [REST host 1, REST host 2]
Clarification required
Which naming model should Fleet Manager display and verify?

Recommendation
Use per-host records for deterministic certificates and diagnostics, plus an optional component-level multi-address record if the service requires a stable shared endpoint.

TLS
The new cluster-wide certificate must include SANs for:

every broker name;

bootstrap name;

every Schema Registry name;

every Connect name;

every REST Proxy name;

every Control Center name when applicable;

any inventory FQDN required by cp-ansible.

Confirmation requested
Please confirm that the one cluster certificate/key pair is copied to every CP node and used for every enabled CP component.

JMX monitoring
The current plan specifies only:

controller JMX at 8079;

broker JMX at 8080. 

Clarification required
Choose one:

Option A — Recommended initial scope: enable and monitor JMX only for controllers and brokers.

Option B: enable JMX scraping for Schema Registry, Connect, REST Proxy, and Control Center too.

If Option B is selected, please provide or approve cp-ansible’s standard JMX exporter ports for those components and whether dashboards are required in the same PR.

Certificate model is now clear, subject to SAN validation
Your answer changes the earlier per-host model to a simpler cluster-wide model.

I understand it as:

Kafka cluster
├── CA certificate
├── cluster certificate
└── cluster private key
The same cluster certificate and key are installed on every CP host.

No host-specific certificate secret is needed.

Proposed secret
/organizations/{org}/kafka/{kafka_id}/tls
Conceptual contents:

{
  "ca_certificate": "<PEM>",
  "certificate": "<PEM>",
  "private_key": "<PEM>"
}
Proposed validation
Before dispatch:

Parse the CA certificate.

Parse the cluster certificate.

Parse the private key.

Verify certificate/private-key match.

Reject expired or not-yet-valid certificates.

Verify the cluster certificate chains to the uploaded CA.

Calculate every DNS name required by the chosen topology.

Verify that every required name is covered by:

an exact SAN; or

a valid wildcard SAN.

The compute-components response contains only control-node file-path placeholders; it never contains PEM data, consistent with the existing plan. 

One minor confirmation
Should certificate rotation be completely out of scope for both PRs?

I recommend yes, matching the decision to defer SSH-key rotation.

Topology and placement rules now understood
Assuming the topology tables above are correct, the intended flow is:

User selects environment and topology in fleet advanced configuration.

User supplies the exact required number of hosts.

User assigns each host a purpose.

Fleet Manager validates exact counts.

Tranche 1 deploys shared services automatically.

Tranche 2 derives cp-ansible groups from host purposes.

Kafka creation does not ask users to select hosts again.

Only one Kafka cluster can use the fleet.

KU is retained only as any compatibility field required by existing serializers, not as BYOVM capacity or eligibility logic.

This is a deliberate change from the current plan, which puts manual host assignment in Kafka advanced configuration. 

Recommended topology wire values
Your answer approves the stable wire value recommendation:

{
  "environment": "development",
  "topology": "full"
}
UI:

Development / Full
and:

{
  "environment": "production",
  "topology": "full"
}
UI:

Production / Full HA
This avoids environment-specific API values while preserving the requested product terminology.

Final concise questions
I need only the following final answers:

Is ansible_host guaranteed to be reachable from both backend and orchestrator, and should customer DNS point to that same address?

Is passwordless sudo still a customer precondition, with no synchronous sudo -n true validation and no sudo password support?

May implementation pin the officially corresponding cp-ansible Git tag and commit SHA for CP 8.3.0?

Should topology-disabled cp-ansible groups be empty or omitted?

What DNS naming model should Connect and REST Proxy use?

Is the single cluster certificate/key copied to every CP host and used for all enabled components?

Should JMX monitoring cover only controllers/brokers or all enabled CP components?

Is Kafka certificate rotation out of scope?

After these answers, I would consider the revised requirements fully specified enough for implementation planning.

Checks performed
✅ nl -ba .cursor/plans/byo-vm-fleet.md

✅ nl -ba .cursor/plans/kafka-on-byo-vms.md

✅ nl -ba fleet-manager-orchestrator/Dockerfile

✅ git status --short --branch — the working tree remains clean; no changes, commits, builds, or pull requests were created.

Pls find below my response for "Final concise question".  Let me know if you have any questions. Do not make any code changes, do not raise any PR.

1. Is ansible_host guaranteed to be reachable from both backend and orchestrator, and should customer DNS point to that same address?
   [Response] - Orchestrator-worker is the ansible-host. Use orchestrator-worker for connecting to VMs via ssh and perform installation

2. Is passwordless sudo still a customer precondition, with no synchronous sudo -n true validation and no sudo password support?
   [Response] - Yes. customer is expected to provide passwordless ssh connectivity with sudo privileges.

3. May implementation pin the officially corresponding cp-ansible Git tag and commit SHA for CP 8.3.0?
   [Response] - Yes

4. Should topology-disabled cp-ansible groups be empty or omitted?
   [Response] - Use Option A

5. What DNS naming model should Connect and REST Proxy use?
   [Response] - Use recommendation

6. Is the single cluster certificate/key copied to every CP host and used for all enabled components?
   [Response] - Yes

7. Should JMX monitoring cover only controllers/brokers or all enabled CP components?
   [Response] - all enabled CP components

8. Is Kafka certificate rotation out of scope?
   [Response] - Yes.
Copy
Final Review
Thank you. Items 2–8 are sufficiently clear:

Customers must provide key-based, passwordless SSH and passwordless sudo.

cp-ansible will be pinned to the official CP 8.3.0-compatible Git tag and commit.

Disabled cp-ansible groups remain present with empty hosts.

Connect and REST Proxy use the recommended per-host DNS naming convention.

One cluster certificate/key is distributed to every enabled CP host.

JMX monitoring covers all enabled CP components.

Kafka certificate rotation is out of scope.

There is one terminology issue that exposes two remaining decisions.

orchestrator-worker versus ansible_host
These are not the same thing:

Orchestrator worker = Ansible control node
ansible_host        = Target VM address
For example:

kafka-1:
  ansible_host: 10.20.1.21
  ansible_user: streamtime
The connection is:

Orchestrator worker
        │
        │ Ansible SSH
        ▼
10.20.1.21
ansible_host / target VM
This matches the plan’s architecture: the orchestrator worker is the Ansible control node, and Ansible’s SSH plugin connects from it to inventory hosts. 

Therefore, I interpret your answer as:

Only the orchestrator worker is required to establish operational SSH connections to the VMs. Each inventory entry’s ansible_host is the target VM address reachable from that worker.

Please confirm that interpretation.

Remaining decision 1: synchronous backend SSH validation
The original Tranche 1 plan requires the backend to SSH-connect to every VM before saving the fleet:

POST reaches the backend.

Backend uses Paramiko to connect to every host.

Any failure returns HTTP 400.

No fleet row is saved.

No Temporal workflow is dispatched. 

Your latest response instead says to use the orchestrator worker for SSH and installation.

If the backend cannot reach the VMs, the original synchronous validation cannot remain unchanged.

Please choose one
Option A — Recommended given your latest response
Move host SSH validation into the orchestrator workflow:

POST fleet
  → validate schema
  → save fleet and SSH secret
  → dispatch Temporal
  → orchestrator worker SSH-checks every VM
  → failure sets fleet Failed with per-host errors
Consequences:

Fleet POST returns 202, not an SSH-related 400.

A fleet row exists before SSH connectivity is proven.

SSH failures appear in fleet status/details.

The success criterion and tests requiring “no persistence/no dispatch on SSH failure” must be updated.

Only the orchestrator worker needs network access to target VMs.

Option B
Keep synchronous validation in the backend.

Consequences:

Both backend and orchestrator worker must reach every ansible_host.

The original HTTP 400/no-persistence behavior remains.

The backend still needs Paramiko and access through any configured bastion.

Option C
Have the backend synchronously call a new orchestrator-side connectivity-check service before persistence.

I do not recommend this because it introduces a new synchronous backend-to-worker RPC contract outside the current architecture.

Recommendation
Use Option A if the network guarantee intentionally applies only to the orchestrator worker.

This is a material requirements change because synchronous all-host validation is currently a primary Tranche 1 success criterion. 

Remaining decision 2: DNS record target
Saying that the orchestrator worker reaches the VMs does not establish what address customer-created DNS records should target.

Example:

ansible_host used by worker:   10.20.1.21
client-facing/NAT address:     203.0.113.21
Please confirm one contract
Option A — Simplest
Customer DNS points to ansible_host.

kafka-b0.example.com → 10.20.1.21
Under this rule:

no advertised_address field is needed;

Kafka advertised listeners use generated DNS names resolving to ansible_host;

Fleet Manager uses its normal DNS resolver unless private DNS requires otherwise.

Option B
Customer DNS may point somewhere other than ansible_host.

In that case, every DNS-bearing host requires:

{
  "ansible_host": "10.20.1.21",
  "advertised_address": "203.0.113.21"
}
Fleet Manager compares DNS results to advertised_address.

Recommendation
Use Option A only if Kafka clients and the orchestrator worker share routing to the same VM addresses. Otherwise, Option B is required.

Applied assumptions from the other answers
Unless corrected, these are now final.

Privileges
Authentication uses the uploaded SSH key.

No SSH password is collected.

The remote user has passwordless sudo.

No sudo password is collected.

Runtime uses non-interactive privilege escalation.

Misconfigured sudo produces a host-specific workflow failure.

cp-ansible source
Determine the official Git tag compatible with CP 8.3.0.

Pin both tag and resolved commit SHA.

Build the collection from that source.

Bake it into the orchestrator worker image.

Do not build from floating main, master, or HEAD.

Disabled groups
A Development Minimum inventory retains empty groups:

all:
  children:
    kafka_controller:
      hosts:
        vm1: {}
        vm2: {}
        vm3: {}
    kafka_broker:
      hosts:
        vm1: {}
        vm2: {}
        vm3: {}
    schema_registry:
      hosts: {}
    kafka_connect:
      hosts: {}
    kafka_rest:
      hosts: {}
    control_center:
      hosts: {}
The workflow validates groups according to topology rather than treating every empty group as an error. This supersedes the current blanket requirement to fail on missing groups or hosts. 

Connect and REST Proxy DNS
I interpret “use recommendation” as per-host names:

{kafka}-connect-0.{domain}
{kafka}-connect-1.{domain}

{kafka}-rest-proxy-0.{domain}
{kafka}-rest-proxy-1.{domain}
For Development Full, where there is one instance:

{kafka}-connect-0.{domain}
{kafka}-rest-proxy-0.{domain}
Using the -0 suffix even for a single instance gives one stable naming convention across Development and Production.

Please correct this only if you instead want unsuffixed Development names.

TLS
One secret per Kafka cluster contains:

{
  "ca_certificate": "<PEM>",
  "certificate": "<PEM>",
  "private_key": "<PEM>"
}
The certificate/key pair is installed on every enabled CP host. Its SANs must cover every generated component hostname required by the selected topology.

Monitoring
JMX exporter and Prometheus scraping apply to all enabled groups:

controllers;

brokers;

Schema Registry;

Connect;

REST Proxy;

Control Center where present.

The implementation may use the official cp-ansible defaults for component-specific JMX exporter ports, provided those ports are deterministically pinned in generated configuration and included in host preflight checks.

Rotation
Kafka certificate rotation is out of scope. Replacing the certificate requires a future explicit feature.

Short response needed
Only two answers remain:

Should SSH validation move into the Temporal workflow, or must the backend also reach every VM and preserve synchronous HTTP 400 validation?

Must customer DNS resolve directly to ansible_host, or should inventory include a separate advertised_address?

After these two decisions, I have no further product-level questions.

Checks performed
✅ nl -ba .cursor/plans/byo-vm-fleet.md | sed -n '9,15p;38,48p;83,94p'

✅ nl -ba .cursor/plans/kafka-on-byo-vms.md | sed -n '150,160p'

✅ git status --short --branch — no files were changed, and no commit or pull request was created.

Pls find my response below. Check and let me know if you have any questions.

1. Should SSH validation move into the Temporal workflow, or must the backend also reach every VM and preserve synchronous HTTP 400 validation?
   [Response] - Option B -Keep synchronous validation in the backend.

2. Must customer DNS resolve directly to ansible_host, or should inventory include a separate advertised_address?
   [Response] - Customer DNS points to ansible_host.


Only the orchestrator worker is required to establish operational SSH connections to the VMs. Each inventory entry’s ansible_host is the target VM address reachable from that worker. --> I confirm this.
Copy
Pls find my response below. Check and let me know if you have any questions.

1. Should SSH validation move into the Temporal workflow, or must the backend also reach every VM and preserve synchronous HTTP 400 validation?
   [Response] - Option B -Keep synchronous validation in the backend.

2. Must customer DNS resolve directly to ansible_host, or should inventory include a separate advertised_address?
   [Response] - Customer DNS points to ansible_host.
Copy
Requirements Confirmation
Thank you. These answers close the two remaining questions. I have no further product-level clarifications at this time.

Final SSH connectivity contract
The requirements are now:

Backend validation

The backend must be able to reach every VM at ansible_host:ssh_port.

It performs synchronous Paramiko validation before persisting the fleet or dispatching the Temporal workflow.

If any VM is unreachable or authentication fails, the request returns HTTP 400, no fleet row is created, and no workflow is dispatched. This preserves the original Tranche 1 contract. 

Orchestrator operations

The orchestrator worker is the Ansible control node.

It must be able to reach every target VM at ansible_host:ssh_port.

It performs operational SSH activity, shared-service installation, topology discovery, and the later cp-ansible deployment.

Ansible uses its SSH connection plugin through the Python API rather than invoking the Ansible CLI. 

Therefore, both processes need network connectivity, but for different reasons:

Backend
  └── Paramiko SSH validation before persistence
       └── ansible_host:ssh_port

Orchestrator worker
  ├── Paramiko installation and host operations
  └── Ansible Python API / SSH connection plugin
       └── ansible_host:ssh_port
The earlier statement that only the orchestrator establishes operational SSH connections remains compatible with this model: the backend connects only for synchronous validation, while the orchestrator performs installation and lifecycle operations.

Final DNS contract
Customer-created DNS records must resolve directly to the applicable VM’s ansible_host.

For example:

shared-{fleet}.{domain} → Kong host ansible_host
{kafka}-b0.{domain}     → Broker 0 ansible_host
{kafka}-connect-0.{domain} → Connect host ansible_host
Consequently:

No separate advertised_address field is required.

ansible_host is both the SSH/control address and the expected A/AAAA record target.

Kafka advertised hostnames are generated from the fleet domain and resolved to the relevant VM’s ansible_host.

Fleet Manager verifies customer-managed DNS but does not create or delete the records.

The customer’s networking must permit Kafka clients to reach those addresses.

If the records exist in private DNS, Streamtime’s runtime DNS configuration must be able to resolve them; no separate customer-provided dns_server field is currently required.

This aligns with the compute-components requirement to emit SSH addressing and separately derive advertised hostnames/listener mappings from fleet and host metadata. 

No source files were modified, so there was nothing to commit and no pull request was created.
