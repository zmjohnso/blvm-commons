#!/bin/bash
# Update installed components
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

COMPONENT="${1:-}"
if [ -z "$COMPONENT" ]; then
    echo "Usage: ./update.sh [component] [options]"
    echo "Components: blvm, experimental, commons"
    exit 1
fi
shift

VERSION="latest"
while [[ $# -gt 0 ]]; do
    case $1 in
        --version) VERSION="$2"; shift 2 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

if [ "$EUID" -ne 0 ]; then echo "Run as root"; exit 1; fi

case "$COMPONENT" in
    blvm)
        SERVICE_NAME="blvm"
        INSTALL_DIR="/opt/blvm"
        BINARY_NAME="blvm"
        BINARY_URL="https://github.com/BTCDecoded/blvm/releases/latest/download/blvm-linux-x86_64.tar.gz"
        if [ "$VERSION" != "latest" ]; then
            BINARY_URL="https://github.com/BTCDecoded/blvm/releases/download/${VERSION}/blvm-linux-x86_64.tar.gz"
        fi
        ;;
    experimental)
        SERVICE_NAME="blvm"
        INSTALL_DIR="/opt/blvm"
        BINARY_NAME="blvm-experimental"
        BINARY_URL="https://github.com/BTCDecoded/blvm/releases/latest/download/blvm-experimental-linux-x86_64.tar.gz"
        if [ "$VERSION" != "latest" ]; then
            BINARY_URL="https://github.com/BTCDecoded/blvm/releases/download/${VERSION}/blvm-experimental-linux-x86_64.tar.gz"
        fi
        ;;
    commons)
        SERVICE_NAME="blvm-commons"
        INSTALL_DIR="/opt/blvm-commons"
        BINARY_NAME="blvm-commons"
        BINARY_URL="https://github.com/BTCDecoded/blvm-commons/releases/latest/download/blvm-commons-linux-x86_64.tar.gz"
        if [ "$VERSION" != "latest" ]; then
            BINARY_URL="https://github.com/BTCDecoded/blvm-commons/releases/download/${VERSION}/blvm-commons-linux-x86_64.tar.gz"
        fi
        ;;
    *)
        echo "❌ Unknown component: $COMPONENT"
        exit 1
        ;;
esac

if ! systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo "❌ Service $SERVICE_NAME not running. Install first."
    exit 1
fi

echo "Updating $COMPONENT..."
systemctl stop "$SERVICE_NAME"

cd /tmp
wget -q "$BINARY_URL" -O "${BINARY_NAME}.tar.gz"
tar -xzf "${BINARY_NAME}.tar.gz"
cp "$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
chmod +x "$INSTALL_DIR/$BINARY_NAME"
chown root:root "$INSTALL_DIR/$BINARY_NAME"

systemctl start "$SERVICE_NAME"
sleep 2

if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "✅ Updated: $COMPONENT"
else
    echo "❌ Update failed. Check: journalctl -u $SERVICE_NAME"
    exit 1
fi

