# BYOVM Control Center topology

## Objective

Make Control Center follow the selected BYOVM production topology while keeping Development clusters free of Control Center configuration, credentials, and reconciliation.

## In scope

- Add Control Center to Production Minimum in both Individual and Shared allocation modes.
- Keep Control Center available for Production Full HA.
- Omit the Control Center role, variables, credentials, and reconciliation from every Development topology.
- Require basic authentication for the Control Center UI when Control Center is deployed.
- Return reusable Kafka client properties, CA material, and Control Center credentials only when applicable.
- Keep secret values out of new Temporal activity inputs by resolving the CP access secret inside the Ansible activity.

## Out of scope

- Changing the Test dialog name.
- Making client properties a one-time download.
- Supporting arbitrary service colocation beyond the existing Individual and Shared allocation modes.
- Changing Kafka TLS hostname-verification policy or unrelated REST authentication behavior.

## Approach

1. Derive the Control Center role from environment, topology, and allocation mode when building BYOVM assignments.
2. Gate inventory groups, cp-ansible variables, credential exposure, and reconciliation on the presence of that role.
3. Materialize the default Kafka and Control Center credentials only inside the Ansible activity, using secret references in workflow inputs.
4. Preserve the existing connection-configuration endpoint and always-available client properties behavior.
5. Cover role allocation, reconciliation boundaries, credential visibility, and generated connection configuration in focused tests.

## Deviations

- **2026-10-11 — Production Minimum includes Control Center.** Legacy `.cursor/plans/` documents described Production Minimum without Control Center. The product requirement changed: Production Minimum now receives a dedicated Control Center VM in Individual mode or an appropriately sized service VM in Shared mode.
- **2026-10-11 — Development excludes Control Center.** Legacy topology documentation included Control Center in Development Full HA. Current requirements exclude Control Center from both Development Minimum and Development Full HA, including configuration and credentials.
- **2026-10-13 — No legacy credential backfill.** CP-Ansible has no existing customer deployments, so default access material is created only at the initial create-reconciliation boundary. Update, no-op, connection, and credential-management paths do not carry compatibility backfill logic.
