#!/bin/bash
# Install BLVM Node - Base Build
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTALL_DIR="/opt/blvm"
DATA_DIR="/var/lib/blvm"
CONFIG_DIR="/etc/blvm"
CONFIG_FILE="$CONFIG_DIR/blvm.toml"
SERVICE_USER="blvm"
SERVICE_NAME="blvm"
BINARY_NAME="blvm"
BINARY_URL="https://github.com/BTCDecoded/blvm/releases/latest/download/blvm-linux-x86_64.tar.gz"

RPC_PASSWORD=""
RPC_PORT="8332"
P2P_PORT="8333"

while [[ $# -gt 0 ]]; do
    case $1 in
        --rpc-password) RPC_PASSWORD="$2"; shift 2 ;;
        --version) BINARY_URL="https://github.com/BTCDecoded/blvm/releases/download/$2/blvm-linux-x86_64.tar.gz"; shift 2 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

if [ "$EUID" -ne 0 ]; then echo "Run as root"; exit 1; fi

if [ -z "$RPC_PASSWORD" ]; then
    RPC_PASSWORD=$(openssl rand -hex 32)
fi

if ! id "$SERVICE_USER" &>/dev/null; then
    useradd -r -s /bin/false -d "$DATA_DIR" "$SERVICE_USER"
fi

mkdir -p "$INSTALL_DIR" "$DATA_DIR" "$CONFIG_DIR"
chown -R "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR" "$CONFIG_DIR"

cd /tmp
wget -q "$BINARY_URL" -O blvm.tar.gz
tar -xzf blvm.tar.gz
cp blvm "$INSTALL_DIR/$BINARY_NAME"
chmod +x "$INSTALL_DIR/$BINARY_NAME"
chown root:root "$INSTALL_DIR/$BINARY_NAME"

cat > "$CONFIG_FILE" << EOF
# NodeConfig (blvm-node) — network is selected via \`blvm --network\`; RPC bind via \`--rpc-addr\`.
listen_addr = "0.0.0.0:${P2P_PORT}"
protocol_version = "BitcoinV1"
max_peers = 125
transport_preference = "tcponly"
enable_self_advertisement = true

[storage]
data_dir = "${DATA_DIR}"
database_backend = "auto"

[storage.pruning]
mode = { type = "disabled" }

[rpc_auth]
required = true
tokens = ["${RPC_PASSWORD}"]

[logging]
level = "info"
EOF

chmod 640 "$CONFIG_FILE"
chown root:"$SERVICE_USER" "$CONFIG_FILE"

cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=BLVM Node
After=network.target
Documentation=https://btcdecoded.org

[Service]
Type=notify
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${DATA_DIR}
ExecStart=${INSTALL_DIR}/${BINARY_NAME} --config ${CONFIG_FILE} --rpc-addr 0.0.0.0:${RPC_PORT} --network mainnet
Restart=always
RestartSec=10
# Watchdog configuration (60 seconds)
WatchdogSec=60
NotifyAccess=all
# Resource limits
LimitNOFILE=65536
LimitNPROC=4096
# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${DATA_DIR}
# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl start ${SERVICE_NAME}
sleep 2

if systemctl is-active --quiet ${SERVICE_NAME}; then
    echo "✅ Installed: ${SERVICE_NAME}"
    echo "RPC: 127.0.0.1:${RPC_PORT} — Authorization: Bearer <token> (rpc_auth token in ${CONFIG_FILE})"
else
    echo "❌ Failed. Check: journalctl -u ${SERVICE_NAME}"
    exit 1
fi
