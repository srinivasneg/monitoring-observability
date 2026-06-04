# Server Maintenance Plan — KVM Infrastructure

A structured runbook for planned maintenance windows on KVM-based on-premise servers. Designed for a Saturday downtime → Sunday restart cycle.

---

## Maintenance Window Structure

| Phase | When | Duration |
|-------|------|----------|
| Pre-maintenance prep | 1–2 days before | 1–2 hours |
| Execution (shutdown + updates) | Saturday | 2–4 hours |
| Restart sequence | Sunday evening | 1–2 hours |
| Post-maintenance verification | Sunday evening | 30 mins |

---

## Phase 1 — Pre-Maintenance Preparation (1–2 Days Before)

### A. Notify the Team

Send a reminder email 24–48 hours before:
- Maintenance window (start and end time)
- Which applications will be unavailable
- Expected impact
- Point of contact during maintenance

### B. Check VM Health

In Cockpit or CLI — confirm everything is stable before you touch it:

```bash
# List all VMs and their state
sudo virsh list --all

# Check host resources
free -h
df -h
uptime
```

Look for: any VM already in error state, high disk usage (>80%), memory pressure.

### C. Take Backups

**For each VM:**

```bash
# Optional: snapshot the VM
sudo virsh snapshot-create-as <vmname> pre-maintenance-$(date +%Y%m%d) \
  "Pre-maintenance snapshot" --disk-only

# Backup PostgreSQL
pg_dump -U <user> -h <host> <database> > /backup/<database>_$(date +%Y%m%d).sql

# Backup MySQL/MariaDB
mysqldump -u root -p <database> > /backup/<database>_$(date +%Y%m%d).sql

# Backup important configs
cp -r /etc/nginx /backup/nginx_$(date +%Y%m%d)
crontab -l > /backup/crontab_$(date +%Y%m%d).txt
```

**Back up KVM XML configs on the host:**

```bash
sudo virsh list --all
sudo virsh dumpxml <vmname> > /backup/<vmname>.xml
```

### D. Check Pending Updates (Do NOT install yet)

```bash
sudo apt update && sudo apt list --upgradable
```

Review the list. Know what's coming before you apply it.

---

## Phase 2 — Maintenance Execution (Saturday)

### A. Gracefully Stop Applications (Inside Each VM)

SSH into each VM and stop services in this order:

```bash
# 1. Stop application services
sudo systemctl stop <your-app>      # Tomcat, Node, Python, Java, etc.

# 2. Stop web servers
sudo systemctl stop nginx
sudo systemctl stop apache2

# 3. Stop databases last
sudo systemctl stop postgresql
sudo systemctl stop mysql
sudo systemctl stop mongodb
```

> Stopping in the correct order prevents data corruption — app writes must stop before DB is shut down.

### B. Shutdown All VMs

Via Cockpit: Virtual Machines → Power Off

Or via CLI:

```bash
sudo virsh shutdown <vmname>

# Verify all are shut down
sudo virsh list --all
# All should show "shut off"
```

### C. Apply Host Updates

```bash
sudo apt update
sudo apt upgrade -y
sudo apt dist-upgrade -y
```

If a kernel update was applied:

```bash
sudo reboot
```

### D. Post-Reboot Host Health Check

```bash
uptime                  # Confirm clean boot
free -h                 # Memory available
df -h                   # Disk space
journalctl -xe          # Check for any boot errors
sudo virsh list --all   # Confirm VMs are still listed (shut off)
```

---

## Phase 3 — Restart Sequence (Sunday Evening)

**Start in dependency order: DB → App → Web**

### Step 1 — Start Database VMs First

```bash
sudo virsh start <db-vm>
```

Wait for DB to fully start before proceeding:

```bash
# SSH into DB VM and verify
systemctl status postgresql
systemctl status mysql
```

### Step 2 — Start Application Backend VMs

```bash
sudo virsh start <app-vm>
```

Verify inside the VM:

```bash
systemctl status <app-service>
# Check logs for startup errors
journalctl -u <app-service> -n 50
```

### Step 3 — Start Web / Frontend VMs

```bash
sudo virsh start <web-vm>
```

Verify:

```bash
systemctl status nginx
curl -I http://localhost
```

---

## Phase 4 — Post-Maintenance Verification

For each VM:

```bash
# Resource usage
free -h
top -bn1 | head -20

# Service status
systemctl status <db-service>
systemctl status <app-service>
systemctl status nginx

# Application logs
tail -50 /var/log/<app>.log

# Test DB read/write
psql -U <user> -c "SELECT 1;"
```

**Test from the outside:**
- Log into the application dashboard
- Run a test transaction
- Check application logs for errors

---

## Phase 5 — Post-Maintenance Documentation

Create a short internal report and save it:

```
Maintenance Report — <date>
============================
Start time    : 
End time      : 
Updates applied:
  - <list packages updated>
Kernel update : Yes / No
VM snapshots  : /backup/...
Issues found  :
  - <none / describe>
Services restarted :
  - <list>
Sign-off      : <your name>
```

---

## Rollback Plan

### Within 5 Minutes — Service Issue

```bash
# Restart the affected service
sudo systemctl restart <service>

# Check logs
journalctl -u <service> -n 100
```

### Within 30 Minutes — Bad VM State

Restore from snapshot:

```bash
sudo virsh snapshot-revert <vmname> pre-maintenance-<date>
sudo virsh start <vmname>
```

### Within 30 Minutes — Bad Kernel (Host)

At boot → **Advanced options** → select the **previous kernel version**.

After booting old kernel:

```bash
# Pin the old kernel to prevent auto-upgrade
sudo apt-mark hold linux-image-<old-version>
```

### Within 1 Hour — Multiple VMs Failing

Abort the maintenance window:

1. Start all VMs from last known good snapshots
2. Notify the team that maintenance is postponed
3. Schedule a post-mortem before rescheduling

---

## Quick Reference Commands

```bash
# Host — list VMs
sudo virsh list --all

# Host — VM power control
sudo virsh start <vmname>
sudo virsh shutdown <vmname>
sudo virsh destroy <vmname>    # force off (last resort)

# Host — snapshots
sudo virsh snapshot-list <vmname>
sudo virsh snapshot-create-as <vmname> <snapshot-name>
sudo virsh snapshot-revert <vmname> <snapshot-name>

# Host — dump VM config
sudo virsh dumpxml <vmname> > /backup/<vmname>.xml

# Backup PostgreSQL
pg_dump -U postgres <dbname> > /backup/<dbname>_$(date +%Y%m%d).sql

# Backup MySQL
mysqldump -u root -p <dbname> > /backup/<dbname>_$(date +%Y%m%d).sql
```
