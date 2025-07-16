#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEMD_SRC_DIR="$SCRIPT_DIR"
SYSTEMD_DEST_DIR="/etc/systemd/system"

echo "🔧 Installing systemd services from $SYSTEMD_SRC_DIR..."

for service_file in "$SYSTEMD_SRC_DIR"/*.service; do
    service_name=$(basename "$service_file")

    echo "Installing $service_name..."
    sudo cp "$service_file" "$SYSTEMD_DEST_DIR/$service_name"
    sudo chmod 644 "$SYSTEMD_DEST_DIR/$service_name"
    sudo systemctl enable "$service_name"
    sudo systemctl restart "$service_name"
done

echo "Reloading systemd daemon..."
sudo systemctl daemon-reexec

echo "All services installed, enabled, and started."