#!/bin/bash
# View service logs
set -e

COMPONENT="${1:-}"
if [ -z "$COMPONENT" ]; then
    echo "Usage: ./logs.sh [component] [options]"
    echo "Components: blvm, experimental, commons"
    exit 1
fi
shift

FOLLOW=false
LINES=50

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--follow) FOLLOW=true; shift ;;
        -n|--lines) LINES="$2"; shift 2 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

case "$COMPONENT" in
    blvm|experimental)
        SERVICE_NAME="blvm"
        ;;
    commons)
        SERVICE_NAME="blvm-commons"
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

if [ "$FOLLOW" = true ]; then
    journalctl -u "$SERVICE_NAME" -f
else
    journalctl -u "$SERVICE_NAME" -n "$LINES"
fi

