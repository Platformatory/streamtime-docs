# Certificate renewal windows (existing fleets)

Auto-TLS Certificates now schedule cert-manager renewal inside the org's
maintenance window via `spec.renewal.windows` — available starting
**cert-manager v1.21.0** (see [`package_rules.yaml`](https://github.com/streamtime-ai/fleet-manager/blob/main/fleet-manager-backend/preload/package_rules.yaml)).

## Prerequisite: upgrade cert-manager first

**Existing fleets must have cert-manager upgraded to `>=1.21.0` before renewal
windows are enabled.** On older cert-manager versions, the `Certificate` CRD
does not define `spec.renewal`/`spec.duration` — server-side apply of those
fields is rejected by CRD validation, so the agent's
`UpdateCertificateRenewalWindowsWorkflow` patch will fail until the fleet's
cert-manager is upgraded.

Helm charts render `spec.duration`/`spec.renewal` conditionally on
`.Values.certManager.renewal` being set (empty by default), so this is safe to
roll out in phases: fleets that haven't upgraded yet simply keep the old
uncontrolled renewal schedule until they do.

## Order of operations

1. Upgrade cert-manager on the fleet to `>=1.21.0` (per-fleet Helm upgrade of
   the `cert-manager` release, same as any other package bump).
2. Deploy the Fleet Manager backend/orchestrator/agent code that adds renewal
   window support.
3. Changing the org's maintenance window (Settings → Maintenance Window)
   dispatches `SyncOrgCertificateRenewalWindowsWorkflow`, which patches
   `spec.duration`/`spec.renewal` onto every already-provisioned auto-TLS
   Certificate in that fleet — no Helm upgrade or broker rollout needed.
4. New Kafka clusters and new fleet bootstraps pick up renewal windows
   automatically from `certManager.renewal` in compute-components — no
   separate action needed once cert-manager is upgraded.

## Notes

- If no renewal window fires before a cert's calculated expiry deadline,
  cert-manager still renews it at the default `renewBefore` time rather than
  letting it expire — this is a safety net, not something to rely on for
  scheduling.
- Prefer daily or weekly maintenance windows for certificate renewal.
  Monthly-only windows risk missing the 30-day `renewBefore` deadline
  entirely if the monthly window falls just after it.
- ACME certs (Let's Encrypt) are capped at ~90 days by the issuer regardless
  of the requested `duration: 8760h` — cert-manager clamps to the issuer's
  max. Only **renewal timing** is controlled by the maintenance window; actual
  certificate validity stays ~90 days.
