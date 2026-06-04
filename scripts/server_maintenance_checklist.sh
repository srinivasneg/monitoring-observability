#!/bin/bash
# server_maintenance_checklist.sh
#
# Run pre-maintenance or post-maintenance health checks on the KVM host.
#
# Usage:
#   bash server_maintenance_checklist.sh pre    # before maintenance
#   bash server_maintenance_checklist.sh post   # after restart

set -e

MODE="${1:-pre}"
REPORT_FILE="maintenance_report_$(date +%Y%m%d_%H%M%S).txt"

log() {
    echo "$1" | tee -a "$REPORT_FILE"
}

separator() {
    log ""
    log "──────────────────────────────────────────"
    log "$1"
    log "──────────────────────────────────────────"
}

log "=== Server Maintenance Checklist ==="
log "Mode      : $MODE"
log "Timestamp : $(date)"
log "Host      : $(hostname)"
log ""

# ── Host Resources ─────────────────────────────────────────────────────────
separator "HOST RESOURCES"

log "Uptime:"
uptime | tee -a "$REPORT_FILE"

log ""
log "Memory:"
free -h | tee -a "$REPORT_FILE"

log ""
log "Disk Usage:"
df -h | tee -a "$REPORT_FILE"

# ── VM Status ──────────────────────────────────────────────────────────────
separator "VM STATUS"

if command -v virsh &>/dev/null; then
    log "All VMs:"
    sudo virsh list --all | tee -a "$REPORT_FILE"
else
    log "virsh not found — skipping VM check"
fi

# ── Pre-maintenance specific ───────────────────────────────────────────────
if [ "$MODE" = "pre" ]; then

    separator "PENDING UPDATES"
    sudo apt update -qq
    UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -v "Listing" | wc -l)
    log "Packages with available updates: $UPGRADABLE"
    apt list --upgradable 2>/dev/null | grep -v "Listing" | tee -a "$REPORT_FILE" || true

    separator "PRE-MAINTENANCE CHECKLIST"
    log "[ ] Team notified (24–48h before)"
    log "[ ] VM snapshots taken"
    log "[ ] PostgreSQL backups done"
    log "[ ] MySQL backups done"
    log "[ ] KVM XML configs backed up"
    log "[ ] Nginx/app configs backed up"
    log "[ ] Checked no VM in error state"
    log "[ ] Pending updates reviewed"
    log ""
    log "Run backup commands:"
    log "  sudo virsh dumpxml <vmname> > /backup/<vmname>.xml"
    log "  pg_dump -U postgres <db> > /backup/<db>_\$(date +%Y%m%d).sql"

fi

# ── Post-maintenance specific ──────────────────────────────────────────────
if [ "$MODE" = "post" ]; then

    separator "BOOT ERRORS CHECK"
    log "Recent journal errors:"
    sudo journalctl -p err -b --no-pager | tail -20 | tee -a "$REPORT_FILE" || true

    separator "SERVICE STATUS"
    SERVICES=("nginx" "postgresql" "mysql" "docker")
    for svc in "${SERVICES[@]}"; do
        if systemctl list-unit-files | grep -q "^${svc}.service"; then
            STATUS=$(systemctl is-active "$svc" 2>/dev/null || echo "not-installed")
            log "  $svc: $STATUS"
        fi
    done

    separator "POST-MAINTENANCE CHECKLIST"
    log "[ ] All VMs started in correct order (DB → App → Web)"
    log "[ ] DB services verified inside each VM"
    log "[ ] App services verified inside each VM"
    log "[ ] Web servers responding"
    log "[ ] Application login tested"
    log "[ ] Logs checked for errors"
    log "[ ] Monitoring (Prometheus/Grafana) showing all VMs UP"
    log ""
    log "Fill in maintenance report fields:"
    log "  Updates applied  : "
    log "  Kernel updated   : Yes / No"
    log "  Issues found     : "
    log "  Snapshot location: /backup/"
    log "  Sign-off         : "

fi

separator "REPORT SAVED"
log "Report written to: $REPORT_FILE"
echo ""
echo "Done. Report: $REPORT_FILE"
