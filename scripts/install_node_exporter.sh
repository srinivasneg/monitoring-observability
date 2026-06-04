#!/bin/bash
# install_node_exporter.sh — Install Node Exporter on any Linux VM
#
# Installs Node Exporter as a systemd service.
# Run this on every VM you want to monitor with Prometheus.
#
# Usage:
#   bash install_node_exporter.sh [version]
#   bash install_node_exporter.sh 1.8.1   # specific version
#   bash install_node_exporter.sh          # uses default version below

set -e

VERSION="${1:-1.8.1}"
INSTALL_DIR="/opt/node_exporter"
BINARY_URL="https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/node_exporter-${VERSION}.linux-amd64.tar.gz"

echo "=== Installing Node Exporter v${VERSION} ==="

# Check if already running
if systemctl is-active --quiet node_exporter; then
    echo "Node Exporter is already running."
    systemctl status node_exporter --no-pager
    exit 0
fi

# Create user
if ! id node_exporter &>/dev/null; then
    useradd --no-create-home --shell /bin/false node_exporter
    echo "✓ Created node_exporter user"
fi

# Download and install
echo "Downloading Node Exporter..."
cd /tmp
wget -q "$BINARY_URL" -O node_exporter.tar.gz
tar -xzf node_exporter.tar.gz
mv "node_exporter-${VERSION}.linux-amd64/node_exporter" /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter
rm -rf node_exporter.tar.gz "node_exporter-${VERSION}.linux-amd64"
echo "✓ Binary installed at /usr/local/bin/node_exporter"

# Create systemd service
cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

echo "✓ Systemd service created"

# Enable and start
systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# Firewall rule
if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
    ufw allow 9100/tcp
    echo "✓ Firewall rule added for port 9100"
fi

# Verify
sleep 2
if systemctl is-active --quiet node_exporter; then
    echo ""
    echo "=== Node Exporter installed successfully ==="
    echo "  Running on port 9100"
    echo "  Metrics: http://$(hostname -I | awk '{print $1}'):9100/metrics"
    echo ""
    echo "Add this to your prometheus.yml:"
    echo "  - targets: ['$(hostname -I | awk '{print $1}'):9100']"
    echo "    labels:"
    echo "      instance: '$(hostname)'"
else
    echo "✗ Node Exporter failed to start"
    journalctl -u node_exporter -n 20
    exit 1
fi
