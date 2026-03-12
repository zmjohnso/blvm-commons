#!/bin/bash
# Show/edit config file
set -e

COMPONENT="${1:-}"
if [ -z "$COMPONENT" ]; then
    echo "Usage: ./config.sh [component] [--edit]"
    echo "Components: blvm, experimental, commons"
    exit 1
fi
shift

EDIT=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --edit|-e) EDIT=true; shift ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

case "$COMPONENT" in
    blvm|experimental)
        CONFIG_FILE="/etc/blvm/blvm.toml"
        INSTALL_DIR="/opt/blvm"
        if [ "$COMPONENT" = "blvm" ]; then
            BINARY_NAME="blvm"
        else
            BINARY_NAME="blvm-experimental"
        fi
        BINARY_PATH="$INSTALL_DIR/$BINARY_NAME"
        ;;
    commons)
        CONFIG_FILE="/etc/blvm-commons/app.toml"
        BINARY_PATH=""
        ;;
    *)
        echo "❌ Unknown component: $COMPONENT"
        exit 1
        ;;
esac

if [ "$EDIT" = true ]; then
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Config file not found: $CONFIG_FILE"
        exit 1
    fi
    if [ -z "$EDITOR" ]; then
        EDITOR="nano"
    fi
    sudo "$EDITOR" "$CONFIG_FILE"
else
    # Use blvm config show if available, otherwise fall back to cat
    if [ -n "$BINARY_PATH" ] && [ -x "$BINARY_PATH" ]; then
        if "$BINARY_PATH" config show 2>/dev/null; then
            # Success, output already shown
            :
        else
            # Fall back to cat if command fails
            if [ -f "$CONFIG_FILE" ]; then
                cat "$CONFIG_FILE"
            else
                echo "❌ Config file not found: $CONFIG_FILE"
                exit 1
            fi
        fi
    else
        if [ -f "$CONFIG_FILE" ]; then
            cat "$CONFIG_FILE"
        else
            echo "❌ Config file not found: $CONFIG_FILE"
            exit 1
        fi
    fi
fi

