# Wazuh — All-in-One Installation & Agent Setup

Wazuh is an open-source **SIEM (Security Information and Event Management)** platform. This guide covers single-node installation and connecting Linux agents.

---

## What Wazuh Does

- **Threat detection** — monitors logs and system calls for suspicious activity
- **Log analysis** — aggregates and parses logs across all agents
- **File integrity monitoring (FIM)** — detects unauthorized file changes
- **Vulnerability detection** — scans for known CVEs on agents

---

## Components

| Component | Description |
|-----------|-------------|
| Wazuh Manager | Collects, analyzes, and stores security data |
| OpenSearch (Indexer) | Search and storage backend (replaces Elasticsearch) |
| Wazuh Dashboard | Web UI for monitoring and management |

---

## System Requirements (All-in-One)

| Resource | Minimum |
|----------|---------|
| OS | Ubuntu 20.04 / 22.04 or CentOS/RHEL 7/8 |
| vCPUs | 4+ |
| RAM | **8 GB minimum** — do not undersize |
| Disk | 20 GB+ |
| Access | Root or sudo |

> ⚠️ Running Wazuh on less than 8GB RAM will cause OOM kills on the indexer. Size your VM accordingly.

---

## Step 1 — Install Wazuh All-in-One

```bash
curl -sO https://packages.wazuh.com/4.8/wazuh-install.sh
chmod +x wazuh-install.sh
sudo ./wazuh-install.sh -a
```

The script installs and configures all three components automatically. It takes 5–15 minutes.

After completion, note the generated admin credentials from the output.

---

## Step 2 — Access the Dashboard

```
https://<wazuh-server-ip>
```

Default login: `admin` / `admin`

You will be prompted to change the password on first login.

---

## Step 3 — Verify Services

```bash
sudo systemctl status wazuh-manager
sudo systemctl status wazuh-dashboard
sudo systemctl status wazuh-indexer
```

All three should show `active (running)`.

Enable on boot:
```bash
sudo systemctl enable wazuh-manager wazuh-dashboard wazuh-indexer
```

---

## Step 4 — Firewall Configuration

```bash
sudo ufw allow 443/tcp    # Dashboard HTTPS
sudo ufw allow 1514/udp   # Agent communication
sudo ufw allow 1515/tcp   # Agent enrollment
```

---

## Step 5 — Add a Linux Agent

### Option A: Script Method

On the agent machine:

```bash
curl -sO https://packages.wazuh.com/4.8/wazuh-agent.sh
chmod +x wazuh-agent.sh
sudo ./wazuh-agent.sh --manager-ip <WAZUH_SERVER_IP>

sudo systemctl start wazuh-agent
sudo systemctl enable wazuh-agent
```

Then go to the Wazuh Dashboard → Agents → approve the pending agent.

### Option B: Web-Based Deployment (Recommended)

1. Open the Wazuh Dashboard
2. Click **Deploy New Agent**
3. Select OS type (Linux / Windows) and Wazuh version
4. Fill in:
   - Wazuh manager IP or hostname
   - Agent name
   - Group (use `default` if unsure)
5. Copy the generated commands and run them on the agent server

This method auto-generates the exact install command for your OS and manager version.

---

## Useful Commands

```bash
# View manager logs
tail -f /var/ossec/logs/ossec.log

# List all registered agents
/var/ossec/bin/agent_control -l

# Restart Wazuh manager
sudo systemctl restart wazuh-manager

# Check agent connectivity from manager
/var/ossec/bin/agent_control -i <agent-id>
```

---

## Troubleshooting

### Dashboard not loading

```bash
sudo systemctl status wazuh-dashboard
sudo journalctl -u wazuh-dashboard -n 50
```

Check that the indexer is healthy first — dashboard depends on it.

### Agent registered but showing offline

- Confirm ports 1514/udp and 1515/tcp are open between agent and manager
- Check agent logs: `tail -f /var/ossec/logs/ossec.log`
- Restart agent: `sudo systemctl restart wazuh-agent`

### Indexer OOM crash

Increase VM RAM to at least 8GB. Wazuh indexer (OpenSearch) is memory-intensive.

---

## Reference

- [Official Wazuh Documentation](https://documentation.wazuh.com/current/installation-guide/index.html)
- [Wazuh GitHub](https://github.com/wazuh/wazuh)

---

**Next:** [Server Maintenance Plan](05-server-maintenance-plan.md)
