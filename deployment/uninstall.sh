#!/bin/bash
# Uninstall components
set -e

COMPONENT="${1:-}"
if [ -z "$COMPONENT" ]; then
    echo "Usage: ./uninstall.sh [component]"
    echo "Components: blvm, experimental, commons"
    exit 1
fi

if [ "$EUID" -ne 0 ]; then echo "Run as root"; exit 1; fi

case "$COMPONENT" in
    blvm)
        SERVICE_NAME="blvm"
        INSTALL_DIR="/opt/blvm"
        DATA_DIR="/var/lib/blvm"
        CONFIG_DIR="/etc/blvm"
        ;;
    experimental)
        SERVICE_NAME="blvm"
        INSTALL_DIR="/opt/blvm"
        DATA_DIR="/var/lib/blvm"
        CONFIG_DIR="/etc/blvm"
        ;;
    commons)
        SERVICE_NAME="blvm-commons"
        INSTALL_DIR="/opt/blvm-commons"
        DATA_DIR="/var/lib/blvm-commons"
        CONFIG_DIR="/etc/blvm-commons"
        ;;
    *)
        echo "❌ Unknown component: $COMPONENT"
        exit 1
        ;;
esac

read -p "Uninstall $COMPONENT? This will stop the service and remove files. (y/N): " confirm
if [ "$confirm" != "y" ]; then
    echo "Cancelled"
    exit 0
fi

if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl stop "$SERVICE_NAME"
fi

if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl disable "$SERVICE_NAME"
fi

rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
systemctl daemon-reload

rm -rf "$INSTALL_DIR" 2>/dev/null || true
rm -rf "$DATA_DIR" 2>/dev/null || true
rm -rf "$CONFIG_DIR" 2>/dev/null || true

echo "✅ Uninstalled: $COMPONENT"
echo "⚠️  Data directory $DATA_DIR was removed. Backup first if needed."

