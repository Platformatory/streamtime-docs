# DNS / TLS provider smoke checklist

Human verification after fleet bootstrap. One row per provider.

| Provider | external-dns | cert-manager ACME | Notes |
|----------|--------------|-------------------|-------|
| Route 53 | A/CNAME in zone | `monitoring-tls` Ready, R53 TXT | Inline AWS keys on BaseDomain |
| Cloudflare | Records in zone | Ready, CF TXT | Zone ID from validate-by-domain |
| GoDaddy | Records in zone | **Upload PEM only** | `auto_create_certificates` must be false |
| STDNS | stdns-webhook sidecar | Ready, stdns-cm-webhook logs Present/CleanUp | Onboarding = zone claim only |

## STDNS webhook logs

```bash
kubectl -n cert-manager logs deploy/stdns-cm-webhook | grep '"action":"Present"'
```

## API checks

- `POST /organizations/{org}/base-domains/dns-provider/validate/` with provider credentials
- `compute-components` includes `certManager.*` when `auto_create_certificates` and provider allowed

## Kafka workload regression (internal listeners)

After deploying Strimzi or CFK with `Internal & External` access:

1. `kubectl -n {kafka-id} get certificate external-kafka-cert` → Ready (external auto-TLS only)
2. `kubectl -n {kafka-id} get secret tls-kafka-external` → cert-manager-managed (not empty static secret)
3. In-cluster internal bootstrap still works:
   - **Strimzi:** `kafka-fm-kafka-bootstrap.{kafka-id}.svc.cluster.local:9092` with `security.protocol=SASL_PLAINTEXT` (or `:9093` + SSL for mTLS listener)
   - **CFK:** `kafka.{kafka-id}.svc.cluster.local:9093` with expected SASL mode
4. Internal-only clusters (`cluster_access=Internal`) must deploy without `external-kafka-cert`, per-kafka nginx, or external cert validation errors

External DNS / HTTPS checks (external plane only):

- `dig {kafka-id}-bootstrap.{domain}` → per-kafka nginx LB IP (Strimzi)
- `dig kafka-ui-{kafka-id}.{domain}` → Kong LB IP
- Kafka UI loads over HTTPS when external access is enabled
