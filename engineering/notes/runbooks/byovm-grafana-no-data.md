# BYOVM Grafana dashboards show "No data"

The BYOVM dashboards do not collect host metrics themselves. The reconciler
starts a `node_exporter` container on every fleet VM and configures the
Prometheus container on the shared-services VM to scrape each host on TCP
port `9100`. Grafana then queries that Prometheus instance.

An empty **Job** selector on the **Node Exporter Metrics** dashboard means that
Prometheus has not ingested any `node_exporter` series. This is a collection or
networking problem, not a Grafana panel-query problem.

## VM and network requirements

For every VM in the topology:

1. The SSH user must have passwordless `sudo` access. Reconcile installs Docker
   and starts the exporter through Docker Compose.
2. The VM must be able to pull `prom/node-exporter:v1.9.0` from its container
   registry.
3. TCP port `9100` must be reachable **from the shared-services VM that runs
   Prometheus**. Add a narrowly scoped inbound rule to the VM firewall and the
   cloud firewall/security group; do not expose `9100` to the public internet.
4. The address entered as **Host/IP Address** must resolve and be routable from
   the shared-services VM. A public address is not interchangeable with a
   private address unless the network supports that route.

Re-run the BYOVM reconciliation after deploying a fleet created before node
exporter support was added. Merely opening an existing Grafana dashboard does
not install the exporter or rewrite Prometheus configuration.

## Verify the exporter on each VM

Run the following commands on each fleet VM:

```bash
cd /opt/streamtime/shared-services
sudo docker compose ps node_exporter
curl --fail --silent http://127.0.0.1:9100/metrics | head
```

The container must be running and the second command must return metrics whose
names begin with `node_`. If Compose is provided as the legacy standalone
binary, use `sudo docker-compose` instead.

If the container is absent, inspect the reconciliation workflow failure and
Compose logs:

```bash
cd /opt/streamtime/shared-services
sudo docker compose logs --tail=100 node_exporter
```

## Verify connectivity from Prometheus

On the shared-services VM, test every configured host address (substitute the
actual value):

```bash
curl --fail --silent http://HOST_OR_IP:9100/metrics | head
```

If localhost works on a target VM but this remote request fails, fix routing,
the host firewall, or the cloud security-group/network ACL. For example, allow
TCP `9100` only from the Prometheus VM's private IP or subnet.

Then inspect Prometheus's view of its targets through the VM-local Kong route.
Prometheus is intentionally exposed only to the Compose network, so
`127.0.0.1:9090` is not reachable directly from the VM host:

```bash
curl --fail --silent http://127.0.0.1:8000/metrics/api/v1/targets \
  | python3 -m json.tool
curl --get --fail --silent http://127.0.0.1:8000/metrics/api/v1/query \
  --data-urlencode 'query=up{job="node-exporter"}' \
  | python3 -m json.tool
```

Each fleet host should have an active target with `health: "up"`, and the
instant query should return `1`. The target's `lastError` explains common
failures such as connection timeout, connection refused, or DNS resolution.

The generated Prometheus configuration is stored at:

```text
/opt/streamtime/shared-services/prometheus.yml
```

After changing this file for diagnosis, prefer re-running reconciliation so
the desired configuration is regenerated consistently. If an emergency manual
change is required, restart Prometheus with `sudo docker compose restart
prometheus`.

## Verify Grafana only after Prometheus is healthy

Once `up{job="node-exporter"}` returns one series per fleet host, refresh the
dashboard and select values in **Job**, **Nodename**, and **Instance**. If
Prometheus is healthy but Grafana remains empty, verify that the provisioned
Prometheus datasource URL is `http://prometheus:9090` and use Grafana's query
inspector to check for datasource errors.
