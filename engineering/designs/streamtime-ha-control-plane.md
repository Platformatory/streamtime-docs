# HA Streamtime control plane

## Objective

`charts/fleet-manager` stays the dependency-free headless contract for the managed site. A sibling umbrella, `charts/streamtime-ha`, is the batteries-included installer: one `helm upgrade --install` brings up a highly available Streamtime control plane (Postgres, Temporal, Redis, Kong, API, UI, orchestrator workers) from a small values file.

## In scope

- Record the working docker-compose control plane and the configuration that must not be copied into the HA install.
- App-chart fixes the umbrella should not have to paper over: current image repositories, one secret channel for the OIDC client secret, a single migration execution mode, and headless built-in identity.
- Umbrella chart: CloudNativePG Postgres 16 (three instances; databases `fleetmanager`, `temporal`, `temporal_visibility`), Temporal server on that Postgres (frontend, history, matching, and Temporal's internal worker), Redis Sentinel (three replicas) behind a master proxy, Kong with `kong-authz-proxy` on the ingress controller, generated secrets, TLS mode, and observability hooks.
- Identity default `builtin` on the umbrella; `external` keeps today's issuer values. No Keycloak subchart.
- Helm unit tests, a headless built-in identity backend test, and an install note.

## Out of scope

- Moving streamti.me off operator-installed Postgres, Temporal, Redis, and Kong.
- Keycloak, Vault, KEDA, PgBouncer, and a bundled Prometheus, Grafana, Loki, or Tempo stack.
- Relaxing the headless license or registry-token requirements.
- Turning docker-compose into HA. Compose stays the single-node record.
- Changing `numHistoryShards` on an existing Temporal database.
- Gateway API for this control plane. Routes stay Kubernetes Ingress plus `KongPlugin` resources. The Gateway API remains the fleet data-plane Envoy path.

## Approach

1. Keep `charts/fleet-manager` free of Postgres, Temporal, Redis, and Kong subcharts. Add `charts/streamtime-ha` and wire the app chart in as a `file://` dependency.
2. Default app images to `ghcr.io/streamtime-ai/streamtime-{api,ui,orchestrator}` tagged with `appVersion`. `fleetmanager.gateway_image` stays the fleet data-plane image and is not the control-plane Kong image.
3. HA database name is `fleetmanager` (the chart and kind guide). Compose's `fleet_manager` / user `postgres` stays the dev exception. Compose Temporal is `start-dev` on SQLite; the unused `temporal` database there is not the HA persistence model.
4. Secrets the chart can invent (Fernet key, JWT, Django secret, cookie key, Kong authz key and salt, internal service key, Postgres and Redis passwords, built-in admin password) are generated once into the control-plane Secret when `bootstrapSecrets.generate` is true, and reused on upgrade via `lookup`. License, GHCR, and Quay credentials stay required values. `oidc.clientSecret` and the unused top-level `orchestrator.apikey` are removed; the client secret is only `bootstrapSecrets.oidcClientSecret`.
5. Headless bootstrap reads `STREAMTIME_GLOBAL_OIDC_MODE`. `builtin` skips the external issuer keys and calls `configure_builtin_provider`. `external` (the default when the mode is unset) still requires issuer, JWKS, token, authorize, and client id.
6. `fleetmanager.api.migration.mode` is `initContainer` (default) or `job`. Job mode runs one migrate Job per release revision and API pods only wait (`migrate --check`). See Deviations for why this is not a pre-install hook.
7. Kong stays db-less with the ingress controller. `KONG_PLUGINS=bundled,kong-authz-proxy`. The image is `ghcr.io/streamtime-ai/streamtime-gateway` (`effectiveSemver: 3.9.1`). Do not set `KONG_DECLARATIVE_CONFIG`. Authentication is the existing `kong-authz-proxy` `KongPlugin` attached with `konghq.com/plugins`.
8. Pin CloudNativePG, Temporal, and Kong in `Chart.lock`. Do not float `>=1.0.0-0`. Do not depend on current Bitnami charts.
9. TLS: `tls.mode` `selfsigned` or `letsencrypt`. The umbrella owns the ClusterIssuer; the app chart's `createClusterIssuer` is false. Ingress TLS is separate from the fleet gateway certificate the API generates.
10. Observability hooks only: PrometheusRule and ServiceMonitors, plus the CloudNativePG PodMonitor. Autoscaling stays off until opted in; CPU requests are set so an HPA can be enabled.

Working compose control plane (do not copy the misplaced parts):

- Postgres 14, databases `fleet_manager` and `temporal` (user `postgres`). Temporal is `temporalio/temporal start-dev` on SQLite, so the `temporal` database is unused. Namespace `default`, UI on 8233.
- Redis 7, no persistence. Django cache db 0. Kong rate limit db 1, fail closed.
- Kong db-less from `fleet-manager-gateway/kong.yml`, plugin built at container start. `Dockerfile.prod` bakes the rock into `docker.io/kong:3.9.1` and copies `kong.trial.yaml` without setting `KONG_DECLARATIVE_CONFIG`.
- Identity is Keycloak 24.0.1 plus `keycloak-init` (`STREAMTIME_INCLUDE_KEYCLOAK_BOOTSTRAP`). Bootstrap mode is interactive. Built-in Django OIDC exists but the wizard sets it, not compose.
- The API migrates inside the process (twice). TLS is `certs/streamtime.local.*` with `OAUTH_VERIFY_SSL=false`.
- Chart image defaults were `ghcr.io/platformatory/streamtime-*:v0.0.1-main-7acf81f`. Compose hardcodes JWT, the Kong cookie key, and Keycloak admin. The chart's Keycloak Job inlines `streamtime` / `streammanager` and targets a Service the chart does not create. Headless bootstrap required an external issuer. Rate limiting defaulted off with `fault_tolerant: true`. `rateLimiting.trustedProxies` is unused.

Install:

```bash
helm dependency build charts/streamtime-ha --skip-refresh
helm upgrade --install streamtime charts/streamtime-ha \
  --namespace streamtime --create-namespace \
  --wait --timeout 20m \
  -f my-values.yaml
```

`my-values.yaml` supplies `domain`, `adminEmail`, `license`, and GHCR plus Quay username and token. The built-in admin password is printed by `NOTES.txt` via `kubectl get secret`.

`numHistoryShards` is 512 and cannot be changed later without a new Temporal database.

## Deviations

- **2026-10-10 — Migrate Job is not a pre-install hook.** A Helm pre-install hook runs before the Postgres cluster exists, so it cannot wait for the primary. Job mode creates a normal Job named with `.Release.Revision` (one execution per install or upgrade). Its command retries `manage.py migrate` until Postgres accepts connections. API pods in job mode only run `migrate --check` in a loop. Temporal schema setup and namespace creation use the same rule (`schema.useHelmHooks` and `namespaces.useHelmHooks` false) so those Jobs retry until Postgres is up instead of blocking the release. `helm upgrade --install --wait --timeout 20m` waits for them.
- **2026-10-10 — Small values file uses `global.streamtime`.** Helm forwards only `global` into subcharts. `domain`, `adminEmail`, `license`, GHCR and Quay username and token, and `identityMode` live under `global.streamtime`. Chart values still win when they are non-empty. `identityMode: builtin` applies while `fleetmanager.oidc.mode` remains the chart default `external`.
- **2026-10-10 — Subcharts are vendored.** CloudNativePG 0.29.1, Temporal 1.7.0, Kong 3.4.1, and cert-manager v1.21.2 are unpacked under `charts/streamtime-ha/vendor` and pinned in `Chart.lock` as `file://` dependencies. The published GitHub release tarballs did not download reliably through Helm. Kong's unused Bitnami Postgres subchart stays inside the vendored Kong package and is not installed (`postgresql.enabled: false`). Redis is the chart's own Sentinel plus HAProxy, not Bitnami.
- **2026-10-10 — Temporal roles use basic-auth Secrets.** CloudNativePG managed-role passwords must be `kubernetes.io/basic-auth` secrets (`username` and `password`). `streamtime-temporal-db` and `streamtime-temporal-visibility-db` are generated once via `lookup`. Temporal's SQL stores read those secrets. The fleetmanager database owner still uses the control-plane Secret.
- **2026-10-12 — A clean checkout must build dependencies first.** `charts/*.tgz` is not committed. Local installs run `helm dependency build charts/streamtime-ha --skip-refresh` before `helm upgrade --install`. Argo CD installs `oci://ghcr.io/streamtime-ai/streamtime-ha`, which is packaged after that build, and does not use `path: charts/streamtime-ha`.
- **2026-10-14 — ACME challenge is configurable.** `tls.acme.challenge` is `http01` (Kong ingress class) or `dns01` (Cloudflare `apiTokenSecretRef`). The chart does not create that Secret and does not accept the token in values. Nightly uses `dns01` and Secret `cloudflare-api-token` key `api-token`.
- **2026-10-14 — Postgres can run without CloudNativePG.** `postgres.mode: standalone` with `installOperator: false` installs one pod and the Service `streamtime-postgres-rw`. The ready Job creates the Temporal roles with `CREATEDB` and does not create the Temporal databases. `operator` remains the default. Nightly uses `standalone`.
- **2026-10-15 — Kong ingress controller is pinned.** DB-less Kong 3.9 rejects certificate config from the floating `3.5` controller tag (`value must be null`). The controller image is `docker.io/kong/kubernetes-ingress-controller:3.5.6` and `effectiveSemver` is `3.9.2`. The gateway image is built from `docker.io/kong:3.9.2`.
- **2026-10-15 — The ready Job creates the Temporal databases.** Both Postgres modes create the `temporal` and `temporal_visibility` roles and databases, connected as the fleetmanager user, and skip them when they already exist. Temporal `createDatabase` is false. The schema Job still runs `setup-schema` and `update-schema`.
- **2026-10-15 — Built-in admin password is a values input.** `global.streamtime.adminPassword` is the sign-in password when `identityMode` is `builtin`. `fleet-manager.fleetmanager.bootstrapSecrets.builtinAdminPassword` wins when it is set. An empty value is still generated once. External identity does not generate one. On upgrade, a non-empty explicit password replaces the previous Secret value. Headless bootstrap resets the built-in admin user to that password even when setup is already complete. Other generated secrets still keep their previous values.
