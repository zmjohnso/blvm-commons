#!/bin/bash
# Show status of installed components
set -e

echo "=== Bitcoin Commons Status ==="
echo ""

for component in blvm experimental commons; do
    case "$component" in
        blvm|experimental)
            SERVICE_NAME="blvm"
            INSTALL_DIR="/opt/blvm"
            if [ "$component" = "blvm" ]; then
                BINARY_NAME="blvm"
            else
                BINARY_NAME="blvm-experimental"
            fi
            BINARY_PATH="$INSTALL_DIR/$BINARY_NAME"
            ;;
        commons)
            SERVICE_NAME="blvm-commons"
            BINARY_PATH=""
            ;;
    esac
    
    if systemctl list-unit-files | grep -q "${SERVICE_NAME}.service"; then
        if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
            STATUS="✅ Running"
            # For node components, try to get detailed status
            if [ "$component" != "commons" ] && [ -x "$BINARY_PATH" ] 2>/dev/null; then
                echo -n "$component: $STATUS"
                # Try to get node status (non-blocking, timeout quickly)
                NODE_STATUS=$("$BINARY_PATH" status 2>/dev/null | head -3 || echo "")
                if [ -n "$NODE_STATUS" ]; then
                    echo ""
                    echo "  $NODE_STATUS" | sed 's/^/  /'
                else
                    echo ""
                fi
            else
                echo "$component: $STATUS"
            fi
        else
            STATUS="❌ Stopped"
            echo "$component: $STATUS"
        fi
    else
        echo "$component: Not installed"
    fi
done

echo ""
echo "Use 'systemctl status blvm' or 'systemctl status blvm-commons' for details"

