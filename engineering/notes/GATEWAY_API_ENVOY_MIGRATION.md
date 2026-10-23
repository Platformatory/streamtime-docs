# Envoy Gateway API migration for Kafka workloads

This runbook describes how Fleet Manager replaces workload-scoped
`ingress-nginx` with Kubernetes Gateway API resources reconciled by Envoy
Gateway. It covers both Strimzi and Confluent for Kubernetes (CFK) chart
configuration, verification, cutover, and rollback.

## Architecture

Envoy Gateway and Envoy Proxy are separate parts of the same data path:

```text
Fleet Manager / Helm
        |
        | creates GatewayClass, Gateway, routes and policies
        v
Kubernetes API
        |
        | watched by
        v
Envoy Gateway controller (control plane, envoy-gateway-system)
        |
        | generates xDS configuration, Deployment and LoadBalancer Service
        v
Envoy Proxy (data plane, envoy-gateway-system)
        |
        +-- TLSRoute --> TLS-passthrough Kafka Service
        +-- TCPRoute --> plain or Envoy-terminated Kafka Service
        `-- HTTPRoute --> Bridge, Schema Registry, UI, MDS or C3
```

The `Gateway` belongs to the Kafka workload namespace. Envoy Gateway creates
the proxy Deployment and LoadBalancer Service in its controller namespace.
The generated Service name contains a hash and is not an API contract. Fleet
Manager discovers it using these labels:

```yaml
app.kubernetes.io/managed-by: envoy-gateway
gateway.envoyproxy.io/owning-gateway-name: <gateway-name>
gateway.envoyproxy.io/owning-gateway-namespace: <workload-namespace>
```

### Route selection

| Traffic | Gateway listener | Route | TLS endpoint |
| --- | --- | --- | --- |
| Kafka with broker TLS and SNI | `TLS`, `Passthrough` | `TLSRoute` | Kafka broker |
| Kafka with port-based L4 routing | `TCP` | `TCPRoute` per advertised port | none for Strimzi plain TCP; Kafka broker for CFK |
| Kafka TLS terminated at Envoy | one SNI-specific `TLS`, `Terminate` listener per hostname | `TCPRoute` per listener | Envoy |
| Bridge, Schema Registry, UI, MDS, C3 | `HTTP` or `HTTPS` | `HTTPRoute` | Envoy for HTTPS |

Kafka clients must reach every advertised broker. TLS/SNI mode multiplexes
bootstrap and broker hostnames on one public port. A `TCPRoute` is opaque L4
routing and does not itself imply plaintext: Strimzi plain TCP has no TLS,
whereas CFK port-based routing still carries broker TLS. Without an SNI route
discriminator, each bootstrap/broker endpoint requires its own public port.

## Supported version notes

The local `byok-local` POC ran on Kubernetes 1.29. Envoy Gateway 1.3.3 was
used because that is the Envoy Gateway line compatible with Kubernetes 1.29.
It used Envoy Proxy 1.33.x and the experimental Gateway API route types
required for `TCPRoute` and `TLSRoute`.

Envoy Gateway 1.3 is end-of-life. Production clusters should upgrade
Kubernetes and select a currently supported Envoy Gateway version from the
[official compatibility matrix](https://gateway.envoyproxy.io/news/releases/matrix/)
before rollout. The 1.3.3 pin in Fleet Manager is a compatibility bridge for
the currently supported Kubernetes 1.29 fleet, not a long-term production
target.

Strimzi 0.50 does not natively manage a `type: tlsroute` listener. Native
support was introduced in Strimzi 1.1. Fleet Manager therefore configures a
Strimzi 0.50-compatible `cluster-ip` listener and renders the `TLSRoute` or
`TCPRoute` resources itself. Re-evaluate the direct Strimzi integration when
the operator is upgraded.

## Controller installation

Use one Envoy Gateway controller per fleet. Individual Kafka workloads create
their own Gateway and routes, but deleting one workload must not uninstall the
shared controller.

### Fresh cluster

On a cluster where Gateway API and Envoy Gateway CRDs are not already owned by
another installer, the upstream chart installs the required CRDs:

```bash
helm upgrade --install envoy-gateway \
  oci://docker.io/envoyproxy/gateway-helm \
  --version v1.3.3 \
  --namespace envoy-gateway-system \
  --create-namespace \
  --wait
```

Confirm the APIs required by the workload charts:

```bash
kubectl api-resources --api-group=gateway.networking.k8s.io
kubectl api-resources --api-group=gateway.envoyproxy.io
```

The first command must include `gatewayclasses`, `gateways`, `httproutes`,
`tcproutes`, `tlsroutes`, and `referencegrants`. The second must include
`envoyproxies`; JWT-protected HTTP routes also require `securitypolicies`.

### Cluster with existing Gateway API CRDs

Do not let two Helm releases claim the same cluster-scoped CRDs. This is
common on clusters that already run Kong, a cloud-provider Gateway
implementation, or provider-managed Gateway API CRDs.

First install a compatible experimental Gateway API bundle if the cluster
does not already serve `TCPRoute` and `TLSRoute`. For Kubernetes 1.29 and the
local Envoy Gateway 1.3 POC:

```bash
kubectl apply --server-side \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/experimental-install.yaml
```

Then install only the Envoy-specific CRDs before using Helm's
`--skip-crds`. The flag skips *all* chart CRDs, including Envoy's:

```bash
ENVOY_VERSION=v1.3.3
ENVOY_CHART_DIR=$(mktemp -d)

helm pull oci://docker.io/envoyproxy/gateway-helm \
  --version "${ENVOY_VERSION}" \
  --untar \
  --untardir "${ENVOY_CHART_DIR}"

kubectl apply --server-side \
  -f "${ENVOY_CHART_DIR}/gateway-helm/crds/generated/"

helm upgrade --install envoy-gateway \
  oci://docker.io/envoyproxy/gateway-helm \
  --version "${ENVOY_VERSION}" \
  --namespace envoy-gateway-system \
  --create-namespace \
  --skip-crds \
  --wait
```

Set `gatewayApi.skipCrds: true` in workload configuration when Fleet Manager
must follow this path. Fleet Manager performs an API-resource preflight before
installing the workload chart.

## Helm chart configuration

Both workload charts keep `gatewayApi.enabled: false` in `values.yaml` so an
in-place chart upgrade does not require Gateway API CRDs unexpectedly. Fleet
Manager explicitly enables Gateway API for new clusters.

### Shared settings

```yaml
gatewayApi:
  enabled: true
  createGateway: true

  # Managed installs use a workload-unique class to avoid cluster-scoped Helm
  # ownership conflicts. For a pre-provisioned shared class, set create to
  # false and provide its name.
  createGatewayClass: true
  className: <workload-namespace>-envoy
  controllerName: gateway.envoyproxy.io/gatewayclass-controller

  name: <workload-chart>-gateway
  namespace: ""
  controllerNamespace: envoy-gateway-system
  proxyNamespace: envoy-gateway-system

  # Set only when compatible Gateway API and Envoy CRDs are already installed.
  skipCrds: false

  service:
    annotations: {}

  legacyIngress:
    enabled: false
```

Use `gatewayApi.service.annotations` for cloud load-balancer settings formerly
placed on the nginx controller Service. The charts create an `EnvoyProxy`
configuration and attach it to the Gateway infrastructure.

The charts intentionally use different value formats for route API versions:
Strimzi expects the complete `gateway.networking.k8s.io/v1alpha2`, while CFK
expects only `v1alpha2`. The chart-specific examples below show the correct
form. With the pinned Envoy Gateway 1.3.3 stack, `TCPRoute` and `TLSRoute`
remain experimental and `v1` is rejected.

### Strimzi TLS/SNI mode

```yaml
gatewayApi:
  enabled: true
  routeApiVersion: gateway.networking.k8s.io/v1alpha2
  kafka:
    mode: TLS
    port: 9094
    backendPort: 9094
    hostname: "*.kafka.example.com"
    bootstrap:
      hostname: bootstrap.kafka.example.com
      service:
        name: kafka-fm-kafka-external-bootstrap
    brokers:
      hostnameTemplate: broker-{nodeId}.kafka.example.com
      # Leave empty for Strimzi 0.50 auto-detection. With the default
      # external:9094 listener this resolves to kafka-fm-broker-{nodeId}.
      serviceNameTemplate: ""
      idOffset: 0
    tls:
      mode: Passthrough
      brokerCertificate:
        secretName: tls-kafka-external
        certificate: tls.crt
        key: tls.key
```

For TLS termination at Envoy, set `gatewayApi.kafka.tls.mode: Terminate` and
provide `certificateRefs`. Envoy Gateway 1.3 attaches `TCPRoute`, rather than
`TLSRoute`, to a terminating TLS listener. The chart therefore creates one
SNI-specific listener and `TCPRoute` for bootstrap and for every broker, all
on the same public port. It also configures the Strimzi external backend
listener without TLS so Envoy forwards the decrypted Kafka stream correctly.
SASL authentication remains at Kafka.

### Strimzi broker node IDs

Do not infer existing broker node IDs from `replicas`. Separate broker and
controller pools can acquire sparse IDs after scale-up, and every advertised
broker must have a matching route and Service reference. Discover the IDs
before enabling Gateway API:

```bash
NS=<workload-namespace>
kubectl -n "${NS}" get kafkanodepool broker -o json |
  jq -c '.status.nodeIds | sort'
```

Copy the exact result into chart values; its length must equal `replicas`:

```yaml
replicas: 3
gatewayApi:
  enabled: true
  kafka:
    brokers:
      nodeIds: [0, 1, 6]
```

That one list drives Strimzi advertised hosts/ports, per-broker Gateway
listeners and routes, and backend Service names. Confirm the Services before
cutover:

```bash
kubectl -n "${NS}" get service \
  kafka-fm-kafka-external-bootstrap \
  kafka-fm-broker-0 \
  kafka-fm-broker-1 \
  kafka-fm-broker-6
```

Fresh installs can leave `nodeIds: []`. The chart reserves separate broker
and controller ID ranges so later multi-pool scale-up remains deterministic.
The explicit migration list does not reassign existing nodes; Strimzi consults
it only when assigning IDs for new nodes.

### Strimzi plain TCP mode

```yaml
gatewayApi:
  enabled: true
  routeApiVersion: gateway.networking.k8s.io/v1alpha2
  kafka:
    mode: TCP
    port: 9094
    brokerPortStart: 9095
```

The bootstrap listener uses `9094`; broker `N` uses
`brokerPortStart + N`. Advertised ports and generated Gateway listeners must
remain identical.

### Strimzi HTTP routes and JWT parity

```yaml
gatewayApi:
  http:
    enabled: true
    port: 443
    tls:
      enabled: true
      certificateRefs:
        - name: tls-kafka-external

  routes:
    kafkaBridge:
      enabled: true
      hostname: bridge.kafka.example.com
      service:
        name: kafka-bridge-bridge-service
        port: 8080
    schemaRegistry:
      enabled: true
      hostname: schema.kafka.example.com
      service:
        name: schema-registry
        port: 8081
    kafkaUi:
      enabled: true
      hostname: ui.kafka.example.com
      service:
        name: kafka-ui
        port: 8080
    kafkaConnect:
      # Route-only: enable when a separate KafkaConnect Service exists.
      enabled: true
      hostname: connect.kafka.example.com
      service:
        name: kafka-connect-api
        port: 8083
```

When `oauth.issuer` and `oauth.jwksEndpoint` are configured, the Strimzi chart
replaces the old Kong JWT plugins with Envoy `SecurityPolicy` resources
targeting the Bridge and Schema Registry HTTPRoutes.

Kafka Connect is not created by this workload chart. Its disabled-by-default
`gatewayApi.routes.kafkaConnect` entry can expose the REST Service of a
separately deployed `KafkaConnect` resource; set its hostname and Service
mapping only when that Service exists.

### CFK Kafka

CFK TLS mode uses `staticForHostBasedRouting` and one TLSRoute per broker:

```yaml
gatewayApi:
  enabled: true
  routeApiVersion: v1alpha2
  kafka:
    enabled: true
    mode: TLS
    port: 9092
    brokerPrefix: my-cluster-b
    domain: kafka.example.com
    serviceNamePrefix: kafka-
    serviceNameSuffix: -internal
    servicePort: 9092
    tls:
      mode: Passthrough
```

CFK TCP mode uses `staticForPortBasedRouting` and one listener/TCPRoute per
broker. Despite the value name `TCP`, the CFK external listener remains
TLS-enabled and Envoy forwards the encrypted bytes opaquely:

```yaml
gatewayApi:
  enabled: true
  routeApiVersion: v1alpha2
  kafka:
    mode: TCP
    host: kafka.example.com
    brokerPortStart: 9094
```

CFK's chart-managed external listener remains TLS-enabled. Kafka TLS
termination at Envoy is therefore rejected at Helm-render time rather than
silently forwarding plaintext to a TLS backend. Use passthrough for CFK until
the chart supports a verified plaintext external backend or explicit
Gateway-to-backend TLS origination.

CFK HTTPRoutes cover Control Center, Schema Registry, and MDS:

```yaml
gatewayApi:
  http:
    enabled: true
    port: 443
    tls:
      enabled: true
      certificateRefs:
        - name: tls-kafka-external
  routes:
    controlCenter:
      enabled: true
    schemaRegistry:
      enabled: true
    mds:
      enabled: true
    kafkaConnect:
      # Route-only: enable when a separate CFK Connect Service exists.
      enabled: true
      hostname: connect.kafka.example.com
      service:
        name: connect
        port: 8083
```

The disabled-by-default `gatewayApi.routes.kafkaConnect` entry can expose a
separately deployed CFK Connect REST Service. The CFK workload chart does not
create a Connect custom resource.

### Legacy annotation mapping

Ingress-controller annotations are not copied to Gateway API objects. Their
intent maps as follows:

| Legacy behavior | Legacy annotation or field | Gateway API / Envoy replacement |
| --- | --- | --- |
| Select the workload ingress controller | `ingressClassName` / Strimzi listener `class` | `GatewayClass`, `Gateway.spec.gatewayClassName`, and route `parentRefs` |
| Preserve Kafka broker TLS and route by SNI | `nginx.ingress.kubernetes.io/ssl-passthrough: "true"` | `TLS` listener with `Passthrough` plus `TLSRoute` |
| Treat the upstream as HTTPS | `nginx.ingress.kubernetes.io/backend-protocol: HTTPS` | no separate setting in passthrough mode; Envoy forwards encrypted bytes and the broker terminates TLS |
| Do not force HTTP-to-HTTPS redirect | `nginx.ingress.kubernetes.io/ssl-redirect: "false"` | explicit HTTP listener and `HTTPRoute`; no redirect policy is attached |
| Require a bearer JWT on REST endpoints | `konghq.com/plugins` JWT plugin | Envoy `SecurityPolicy` targeting the `HTTPRoute` |
| Publish DNS | `external-dns.alpha.kubernetes.io/*` | equivalent annotations on `TLSRoute`, `TCPRoute`, or `HTTPRoute` |

Any rewrite, redirect, timeout, or header annotation not listed here must be
translated deliberately into Gateway API matches/filters or an Envoy policy;
do not assume an Ingress annotation is honored after migration.

## Migration and cutover

Use a parallel migration so DNS can move independently from workload
configuration:

1. Install Envoy Gateway and verify all required CRDs.
2. Apply a separate POC Gateway and routes without removing current
   Ingresses.
3. Test each HTTP hostname with `curl --resolve` against the Envoy address.
4. Test Kafka bootstrap and every advertised broker hostname against Envoy.
5. Verify route status and both controller/proxy metrics.
6. Lower DNS TTL, then point route hostnames to the Envoy LoadBalancer.
7. Monitor Kafka connection/authentication errors, Envoy 4xx/5xx responses,
   upstream resets, and endpoint readiness.
8. Enable the chart-managed Gateway resources.
9. Disable legacy Ingress rendering and uninstall the workload's
   ingress-nginx release only after DNS caches and existing Kafka connections
   have drained.

Do not change a Kafka advertised port until clients, DNS/firewalls, Gateway
listeners, and chart values are ready for the same cutover. Port 443 is useful
for an initial parallel migration; 9092 is the CFK chart default.

## Automated Kafka verification

The reusable verifier creates a temporary client Pod and topic, checks TLS,
authenticated metadata, produce/consume, and Envoy metrics, then removes only
the resources it created:

```bash
scripts/verify-envoy-kafka-gateway.sh
```

It works for either workload type and verifies every configured broker
endpoint. Use `GATEWAY_TEST_BROKER_ENDPOINTS` as a comma-separated
`hostname:port` list. For example, CFK host-based TLS mode can use broker 0 as
its bootstrap endpoint:

```bash
GATEWAY_TEST_NAMESPACE=my-cfk \
GATEWAY_TEST_GATEWAY_NAME=fleet-manager-cfk-gateway \
GATEWAY_TEST_BOOTSTRAP_HOST=my-cfk-b0.kafka.example.com \
GATEWAY_TEST_BROKER_ENDPOINTS=my-cfk-b0.kafka.example.com:9092,my-cfk-b1.kafka.example.com:9092 \
GATEWAY_TEST_KAFKA_PORT=9092 \
GATEWAY_TEST_TLS=true \
GATEWAY_TEST_CLIENT_CONFIG=/secure/path/client.properties \
scripts/verify-envoy-kafka-gateway.sh
```

Set `GATEWAY_TEST_TLS_CA_FILE=/secure/path/ca.crt` when the broker or Envoy
certificate is signed by a private CA. OpenSSL is run with
`-verify_return_error`, so a hostname or trust failure fails the verification.

For Strimzi plain TCP mode, set `GATEWAY_TEST_TLS=false`, keep
`GATEWAY_TEST_KAFKA_PORT` at the bootstrap port, and list each broker's
dedicated port:

```bash
GATEWAY_TEST_TLS=false \
GATEWAY_TEST_KAFKA_PORT=9094 \
GATEWAY_TEST_BROKER_ENDPOINTS=broker-0.kafka.example.com:9095,broker-1.kafka.example.com:9096 \
scripts/verify-envoy-kafka-gateway.sh
```

CFK `mode: TCP` still carries broker TLS through each `TCPRoute`; keep
`GATEWAY_TEST_TLS=true` and list the dedicated CFK broker ports.

For an environment where workload DNS already points to Envoy, set
`GATEWAY_TEST_USE_HOST_ALIASES=false`. `hostAliases` accepts only an IP; when
the Gateway publishes a DNS hostname, the verifier fails with guidance rather
than writing an invalid Pod.

The equivalent manual test follows. It works for either workload type when
the bootstrap endpoint, broker host aliases, image, and credentials are
adjusted. This example matches the local Strimzi POC:

```bash
GATEWAY_IP=$(kubectl -n usual-mite get gateway envoy-poc \
  -o jsonpath='{.status.addresses[0].value}')
TEST_SUFFIX="$(date -u +%Y%m%d%H%M%S)-$$"
TEST_POD="envoy-kafka-client-${TEST_SUFFIX}"
TEST_TOPIC="envoy-gateway-test-${TEST_SUFFIX}"
TEST_MESSAGE="hello-through-envoy-${TEST_SUFFIX}"

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${TEST_POD}
  namespace: usual-mite
spec:
  restartPolicy: Never
  hostAliases:
    - ip: "${GATEWAY_IP}"
      hostnames:
        - usual-mite-bootstrap.local.streamti.me
        - usual-mite-b0.local.streamti.me
  containers:
    - name: kafka-client
      image: docker.io/platformatorylabs/strimzi-kafka-tiered-storage:latest-kafka-4.1.1
      command: ["sleep", "3600"]
EOF

kubectl -n usual-mite wait \
  --for=condition=Ready "pod/${TEST_POD}" \
  --timeout=120s

kubectl -n usual-mite cp \
  /secure/path/client.properties \
  "${TEST_POD}:/tmp/client.properties"

kubectl -n usual-mite exec "${TEST_POD}" -- \
  /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server usual-mite-bootstrap.local.streamti.me:443 \
  --command-config /tmp/client.properties \
  --create \
  --topic "${TEST_TOPIC}" \
  --partitions 1 \
  --replication-factor 1

printf '%s\n' "${TEST_MESSAGE}" |
kubectl -n usual-mite exec -i "${TEST_POD}" -- \
  /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server usual-mite-bootstrap.local.streamti.me:443 \
  --producer.config /tmp/client.properties \
  --topic "${TEST_TOPIC}"

kubectl -n usual-mite exec "${TEST_POD}" -- \
  /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server usual-mite-bootstrap.local.streamti.me:443 \
  --consumer.config /tmp/client.properties \
  --topic "${TEST_TOPIC}" \
  --group "envoy-gateway-test-${TEST_SUFFIX}" \
  --from-beginning \
  --max-messages 1 \
  --timeout-ms 15000
```

Expected output includes:

```text
hello-through-envoy-<timestamp-and-pid>
Processed a total of 1 messages
```

Clean up only the test resources created above:

```bash
kubectl -n usual-mite exec "${TEST_POD}" -- \
  /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server usual-mite-bootstrap.local.streamti.me:443 \
  --command-config /tmp/client.properties \
  --delete \
  --group "envoy-gateway-test-${TEST_SUFFIX}"

kubectl -n usual-mite exec "${TEST_POD}" -- \
  /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server usual-mite-bootstrap.local.streamti.me:443 \
  --command-config /tmp/client.properties \
  --delete \
  --topic "${TEST_TOPIC}"

kubectl -n usual-mite delete pod "${TEST_POD}"
```

## Health and observability

Kubernetes removes unready Service endpoints from Envoy's backend set, so
existing workload readiness probes remain authoritative. Verify them during
cutover:

```bash
kubectl -n <workload-namespace> get pods
kubectl -n <workload-namespace> get endpointslices
```

Envoy Gateway controller metrics are exposed on its Service:

```text
envoy-gateway.envoy-gateway-system.svc:19001/metrics
```

Each generated Envoy Proxy exposes Prometheus metrics on container port
`19001` at `/stats/prometheus`. Select its Pod with the owning-Gateway labels:

```bash
kubectl -n envoy-gateway-system get pods \
  -l gateway.envoyproxy.io/owning-gateway-name=<gateway-name>,gateway.envoyproxy.io/owning-gateway-namespace=<workload-namespace>
```

Prometheus discovery should scrape both endpoints. During migration, alert on
Gateway `Programmed=False`, route `Accepted=False`, route
`ResolvedRefs=False`, Envoy upstream connection failures, HTTP 5xx rates, and
Kafka client authentication/metadata failures.

## Rollback

Rollback is values-driven and intentionally makes the Gateway and legacy
Ingress paths mutually exclusive:

```yaml
gatewayApi:
  enabled: true
  legacyIngress:
    enabled: true
```

Then:

1. Ensure the retained `ingress_nginx` workload component is explicitly
   installed; it is resolvable but no longer installed by default.
2. Upgrade the workload chart with the rollback values.
3. Wait for the nginx LoadBalancer and all legacy Ingress backends.
4. Test Kafka bootstrap, every broker, and each HTTP component against nginx.
5. Restore DNS to the nginx LoadBalancer.
6. Wait for DNS TTL and long-lived Kafka connections to drain.
7. Remove the workload Gateway/routes if the Helm rollback did not already do
   so.

Do not uninstall the shared Envoy Gateway controller while another workload
Gateway still uses it. A rollback does not require deleting CRDs.

To return to Gateway API after resolving the incident:

```yaml
gatewayApi:
  enabled: true
  legacyIngress:
    enabled: false
```

Repeat route-status and end-to-end verification before moving DNS back.

## Troubleshooting

### Gateway has no address

```bash
kubectl -n <namespace> describe gateway <name>
kubectl -n envoy-gateway-system get pods
kubectl -n envoy-gateway-system logs deployment/envoy-gateway
```

Check `GatewayClass` acceptance, proxy scheduling, load-balancer provisioning,
and the `EnvoyProxy` service annotations.

### Route is not accepted

Inspect `status.parents[].conditions`. Common causes are a wrong
`parentRefs.sectionName`, a hostname that does not intersect the listener
hostname, a missing experimental CRD, or a route kind omitted from
`allowedRoutes.kinds`.

### Route has unresolved references

Confirm the Service name and port. For cross-namespace backends or TLS
Secrets, add the appropriate `ReferenceGrant`. Fleet Manager's default routes
and backends are in the workload namespace and do not need one.

### Kafka bootstrap works but broker access fails

This almost always means the Kafka metadata advertises a hostname or port that
does not match a Gateway listener/route. Verify metadata, DNS/host aliases,
one TLSRoute per broker for passthrough SNI mode, one terminating listener plus
TCPRoute per broker for Envoy-terminated TLS, and one public port per broker
in plain TCP mode.

### Helm reports CRD ownership errors

Use the existing-CRD installation path. Verify all required standard,
experimental, and Envoy-specific CRDs, then install the controller with the
real Helm `--skip-crds` option. A `crds.enabled=false` chart value is not a
substitute; the upstream 1.3 chart does not define that value.
