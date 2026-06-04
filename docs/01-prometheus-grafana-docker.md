# Prometheus & Grafana — Docker Setup (Recommended)

The easiest way to run Prometheus and Grafana in production. Everything runs in containers with persistent volumes.

---

## Prerequisites

- Docker and Docker Compose installed
- Ports 9090 and 3000 open on the monitoring VM
- Node Exporter running on each VM you want to monitor (see [install_node_exporter.sh](../scripts/install_node_exporter.sh))

---

## Step 1 — Create Project Structure

```bash
mkdir monitoring && cd monitoring
mkdir prometheus
```

Expected layout:
```
monitoring/
├── docker-compose.yml
└── prometheus/
    └── prometheus.yml
```

---

## Step 2 — Create Prometheus Configuration

Create `prometheus/prometheus.yml` — see the full config at [`configs/prometheus.yml`](../configs/prometheus.yml).

Minimal example for multiple VMs:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node_exporter'
    scrape_interval: 30s
    static_configs:
      - targets: ['<vm1-ip>:9100']
        labels:
          instance: 'vm1-name'
      - targets: ['<vm2-ip>:9100']
        labels:
          instance: 'vm2-name'
```

> Always add an `instance` label — raw IPs in dashboards become unreadable once you have more than 2–3 VMs.

---

## Step 3 — Create Docker Compose File

See full config at [`configs/docker-compose.monitoring.yml`](../configs/docker-compose.monitoring.yml).

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.retention.time=7d"
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    volumes:
      - grafana_data:/var/lib/grafana
    ports:
      - "3000:3000"

volumes:
  prometheus_data:
  grafana_data:
```

---

## Step 4 — Start the Stack

```bash
docker compose up -d
```

---

## Step 5 — Verify

- Prometheus: `http://<server-ip>:9090`
- Grafana: `http://<server-ip>:3000` (default login: `admin` / `admin`)

Check all scrape targets are UP:
```
http://<server-ip>:9090/targets
```

Expected status: `node_exporter → UP`

---

## Step 6 — Install Node Exporter on Each VM

Run on every VM you want to monitor:

```bash
# Quick install via Docker
docker run -d \
  --name=node-exporter \
  -p 9100:9100 \
  --restart unless-stopped \
  prom/node-exporter

# Verify
curl http://localhost:9100/metrics
```

Or use the install script: `bash scripts/install_node_exporter.sh`

---

## Step 7 — Configure Grafana

### Add Prometheus Data Source

1. Settings → Data Sources → Add data source
2. Select **Prometheus**
3. URL: `http://prometheus:9090` *(use container name, not IP)*
4. Click **Save & Test**

### Import Node Exporter Dashboard

1. Create → Import
2. Dashboard ID: **`1860`**
3. Select your Prometheus data source
4. Click Import

This gives you CPU, memory, disk, and network metrics out of the box.

---

## Troubleshooting

### Duplicate metric entries in Grafana

**Symptom:** Same VM appears twice — once as `172.168.x.x:9100` and once as `vm-name`.

**Cause:** You added `instance` labels after Prometheus already stored data with raw IPs.

**Fix:**
```bash
docker compose down
docker volume rm monitoring_prometheus_data
docker compose up -d
```

> This wipes stored metrics. Acceptable for short-retention setups; for production, plan the label scheme before first scrape.

### Target showing as DOWN

- Check Node Exporter is running: `curl http://<vm-ip>:9100/metrics`
- Check firewall: `sudo ufw allow 9100/tcp`
- Check Prometheus config syntax: `docker logs prometheus`

### Grafana can't connect to Prometheus

- Use `http://prometheus:9090` (container name), not `http://localhost:9090`
- Both services must be in the same Docker network (docker-compose handles this automatically)

---

**Next:** [Bare-metal Setup](02-prometheus-grafana-baremetal.md) | [Application Monitoring](03-application-monitoring.md)
