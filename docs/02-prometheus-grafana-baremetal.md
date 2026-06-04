# Prometheus & Grafana — Bare-metal / Systemd Setup

Use this when you can't use Docker or want Prometheus and Grafana managed as native systemd services.

---

## Versions Used

| Tool | Version |
|------|---------|
| Prometheus | 2.52.0 |
| Node Exporter | 1.8.1 |
| Grafana | Latest stable |

---

## Step 1 — Install Node Exporter

```bash
cd /opt
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.1/node_exporter-1.8.1.linux-amd64.tar.gz
tar -xvzf node_exporter-1.8.1.linux-amd64.tar.gz
mv node_exporter-1.8.1.linux-amd64 node_exporter
cd node_exporter
./node_exporter &
```

Node Exporter starts on port **9100**.

Verify:
```bash
curl http://localhost:9100/metrics
```

### Run as a systemd service (recommended for production)

```bash
sudo useradd --no-create-home --shell /bin/false node_exporter

sudo cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
ExecStart=/opt/node_exporter/node_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
sudo systemctl status node_exporter
```

---

## Step 2 — Install Prometheus

```bash
cd /opt
wget https://github.com/prometheus/prometheus/releases/download/v2.52.0/prometheus-2.52.0.linux-amd64.tar.gz
tar -xvzf prometheus-2.52.0.linux-amd64.tar.gz
mv prometheus-2.52.0.linux-amd64 prometheus
cd prometheus
```

### Edit prometheus.yml

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['<vm-ip>:9100']
        labels:
          instance: 'vm-name'

  - job_name: 'springboot-app'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['<app-ip>:8084']
        labels:
          instance: 'springboot-app'
```

### Start Prometheus

```bash
cd /opt/prometheus
./prometheus --config.file=prometheus.yml &
```

Prometheus runs on port **9090**.

### Run as a systemd service (recommended)

```bash
sudo useradd --no-create-home --shell /bin/false prometheus
sudo mkdir /etc/prometheus /var/lib/prometheus
sudo cp /opt/prometheus/prometheus /usr/local/bin/
sudo cp /opt/prometheus/prometheus.yml /etc/prometheus/

sudo cat > /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --storage.tsdb.retention.time=7d
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
sudo systemctl status prometheus
```

---

## Step 3 — Install Grafana

```bash
sudo apt-get install -y apt-transport-https software-properties-common wget

wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"

sudo apt-get update
sudo apt-get install grafana -y

sudo systemctl start grafana-server
sudo systemctl enable grafana-server
```

Grafana runs on port **3000**.

Access: `http://<server-ip>:3000`
Default login: `admin` / `admin`

---

## Step 4 — Configure Grafana

### Add Prometheus Data Source

1. Settings → Data Sources → Add data source
2. Select **Prometheus**
3. URL: `http://<prometheus-ip>:9090`
4. Click **Save & Test**

### Import Dashboards

| Dashboard | ID |
|-----------|----|
| Node Exporter Full | `1860` |
| JVM / Spring Boot | `4701` |

Go to **Create → Import**, enter the ID, select your data source, and import.

---

## Firewall Rules

```bash
sudo ufw allow 9090/tcp   # Prometheus
sudo ufw allow 3000/tcp   # Grafana
sudo ufw allow 9100/tcp   # Node Exporter
```

---

**Next:** [Application Monitoring](03-application-monitoring.md)
