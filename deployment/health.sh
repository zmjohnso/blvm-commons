#!/bin/bash
# Check RPC health/connectivity
set -e

COMPONENT="${1:-}"
if [ -z "$COMPONENT" ]; then
    echo "Usage: ./health.sh [component]"
    echo "Components: blvm, experimental, commons"
    exit 1
fi

case "$COMPONENT" in
    blvm|experimental)
        SERVICE_NAME="blvm"
        INSTALL_DIR="/opt/blvm"
        if [ "$COMPONENT" = "blvm" ]; then
            BINARY_NAME="blvm"
        else
            BINARY_NAME="blvm-experimental"
        fi
        BINARY_PATH="$INSTALL_DIR/$BINARY_NAME"
        ;;
    commons)
        SERVICE_NAME="blvm-commons"
        echo "⚠️  Commons doesn't have RPC, checking service status only"
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            echo "✅ Service is running"
        else
            echo "❌ Service is not running"
            exit 1
        fi
        exit 0
        ;;
    *)
        echo "❌ Unknown component: $COMPONENT"
        exit 1
        ;;
esac

if ! systemctl list-unit-files | grep -q "${SERVICE_NAME}.service"; then
    echo "❌ Service $SERVICE_NAME not installed"
    exit 1
fi

# Check service status
if ! systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "❌ Service is not running"
    exit 1
fi

# Use blvm binary health command
if [ ! -f "$BINARY_PATH" ]; then
    echo "❌ Binary not found: $BINARY_PATH"
    exit 1
fi

if "$BINARY_PATH" health 2>/dev/null; then
    echo "✅ Node is healthy"
else
    echo "❌ Health check failed"
    exit 1
fi

