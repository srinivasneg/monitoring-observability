# Monitoring & Observability Stack

A production-tested runbook for setting up a complete monitoring and security observability stack using **Prometheus**, **Grafana**, **Node Exporter**, and **Wazuh SIEM** — plus a structured server maintenance plan for KVM-based infrastructure.

> Written from real-world DevOps experience managing on-premise and cloud VMs in production.

---

## 📁 Repository Structure

```
monitoring-observability/
├── docs/
│   ├── 01-prometheus-grafana-docker.md       # Docker-based setup (recommended)
│   ├── 02-prometheus-grafana-baremetal.md    # Bare-metal / systemd setup
│   ├── 03-application-monitoring.md          # Spring Boot, Langflow, Node.js metrics
│   ├── 04-wazuh-installation.md              # Wazuh all-in-one + agent setup
│   └── 05-server-maintenance-plan.md         # KVM server maintenance runbook
├── configs/
│   ├── prometheus.yml                        # Prometheus scrape config (multi-VM)
│   └── docker-compose.monitoring.yml         # Prometheus + Grafana Docker Compose
└── scripts/
    ├── install_node_exporter.sh              # Install Node Exporter on any Linux VM
    └── server_maintenance_checklist.sh       # Pre/post maintenance health checks
```

---

## 🚀 Quick Start

| Goal | Guide |
|------|-------|
| Set up Prometheus + Grafana (Docker) | [Docker Setup](docs/01-prometheus-grafana-docker.md) |
| Set up without Docker | [Bare-metal Setup](docs/02-prometheus-grafana-baremetal.md) |
| Monitor Spring Boot / Langflow / Node.js | [Application Monitoring](docs/03-application-monitoring.md) |
| Set up Wazuh SIEM | [Wazuh Installation](docs/04-wazuh-installation.md) |
| Plan a server maintenance window | [Maintenance Plan](docs/05-server-maintenance-plan.md) |

---

## 🛠️ Stack Overview

| Tool | Purpose | Port |
|------|---------|------|
| Prometheus | Metrics collection & storage | 9090 |
| Grafana | Visualization & dashboards | 3000 |
| Node Exporter | Linux VM metrics (CPU, RAM, Disk) | 9100 |
| Wazuh Manager | SIEM — threat detection, log analysis | 1514/1515 |
| Wazuh Dashboard | Web UI for security monitoring | 443 |

---

## 🏗️ Architecture

```
Linux VMs
  └── Node Exporter (:9100)
        │
        ▼
  Prometheus (:9090)  ◄── Application metrics (/metrics, /actuator/prometheus)
        │
        ▼
  Grafana (:3000)  ──►  Dashboards + Alerts


Linux VMs
  └── Wazuh Agent
        │
        ▼
  Wazuh Manager  ──►  Wazuh Dashboard (OpenSearch)
```

---

## 📌 Grafana Dashboard IDs (Ready to Import)

| Dashboard | ID |
|-----------|----|
| Node Exporter Full | `1860` |
| JVM Micrometer (Spring Boot) | `4701` |

---

## ⚡ Versions Tested

| Tool | Version |
|------|---------|
| Prometheus | 2.52.0 |
| Node Exporter | 1.8.1 |
| Grafana | Latest stable |
| Wazuh | 4.8 |
| Ubuntu | 20.04 / 22.04 LTS |

---

## 📌 Key Lessons from Production

- Always use `instance` labels in Prometheus config — raw IPs in dashboards are unreadable at scale.
- When switching from IP-based to label-based scraping, **wipe Prometheus data volume** to avoid duplicate metric series.
- Wazuh all-in-one needs **8GB+ RAM** — don't run it on a small VM or it will OOM.
- Docker port bindings for Node Exporter must use `--net=host` or expose `9100` — otherwise container metrics only, not host metrics.
- During KVM host maintenance, always stop VMs in **reverse dependency order** (web → app → DB) and start in forward order.

---

## 📄 License

MIT — use freely, attribution appreciated.
