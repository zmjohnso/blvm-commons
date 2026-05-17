#!/bin/bash
# Install BLVM Experimental Node - Custom Features
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTALL_DIR="/opt/blvm"
DATA_DIR="/var/lib/blvm"
CONFIG_DIR="/etc/blvm"
CONFIG_FILE="$CONFIG_DIR/blvm.toml"
SERVICE_USER="blvm"
SERVICE_NAME="blvm"
BINARY_NAME="blvm-experimental"
BINARY_URL="https://github.com/BTCDecoded/blvm/releases/latest/download/blvm-experimental-linux-x86_64.tar.gz"

RPC_PASSWORD=""
RPC_PORT="8332"
P2P_PORT="8333"
FEATURES="utxo-commitments,dandelion,ctv"
BUILD_FROM_SOURCE=false
SOURCE_DIR=""
CUSTOM_BINARY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --rpc-password) RPC_PASSWORD="$2"; shift 2 ;;
        --features) FEATURES="$2"; shift 2 ;;
        --build-from-source) BUILD_FROM_SOURCE=true; shift ;;
        --source-dir) SOURCE_DIR="$2"; BUILD_FROM_SOURCE=true; shift 2 ;;
        --custom-binary) CUSTOM_BINARY="$2"; shift 2 ;;
        --version) BINARY_URL="https://github.com/BTCDecoded/blvm/releases/download/$2/blvm-experimental-linux-x86_64.tar.gz"; shift 2 ;;
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

if [ -n "$CUSTOM_BINARY" ]; then
    cp "$CUSTOM_BINARY" "$INSTALL_DIR/$BINARY_NAME"
elif [ "$BUILD_FROM_SOURCE" = true ]; then
    if [ -z "$SOURCE_DIR" ]; then
        SOURCE_DIR="/tmp/blvm-source"
        git clone https://github.com/BTCDecoded/blvm.git "$SOURCE_DIR"
    fi
    cd "$SOURCE_DIR"
    if ! command -v cargo &> /dev/null; then
        echo "❌ Install Rust: https://rustup.rs/"
        exit 1
    fi
    cargo build --release --features "$FEATURES" --bin blvm
    cp "target/release/blvm" "$INSTALL_DIR/$BINARY_NAME"
else
    cd /tmp
    wget -q "$BINARY_URL" -O blvm-experimental.tar.gz
    tar -xzf blvm-experimental.tar.gz
    cp blvm "$INSTALL_DIR/$BINARY_NAME" 2>/dev/null || \
    cp blvm-experimental "$INSTALL_DIR/$BINARY_NAME" 2>/dev/null || \
    find . -name "blvm*" -type f -executable | head -1 | xargs -I {} cp {} "$INSTALL_DIR/$BINARY_NAME"
fi

chmod +x "$INSTALL_DIR/$BINARY_NAME"
chown root:root "$INSTALL_DIR/$BINARY_NAME"

cat > "$CONFIG_FILE" << EOF
# Experimental node: build must include \`utxo-commitments\` for aggressive pruning below.
listen_addr = "0.0.0.0:${P2P_PORT}"
protocol_version = "BitcoinV1"
max_peers = 125
transport_preference = "tcponly"
enable_self_advertisement = true

[storage]
data_dir = "${DATA_DIR}"
database_backend = "auto"

[storage.pruning]
mode = { type = "aggressive", keep_from_height = 0, keep_commitments = true, keep_filtered_blocks = false, min_blocks = 288 }
incremental_prune_during_ibd = true
prune_window_size = 288
min_blocks_for_incremental_prune = 288
auto_prune = true
auto_prune_interval = 144
min_blocks_to_keep = 288

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
Description=BLLVM Node (Experimental)
After=network.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${DATA_DIR}
ExecStart=${INSTALL_DIR}/${BINARY_NAME} --config ${CONFIG_FILE} --rpc-addr 0.0.0.0:${RPC_PORT} --network mainnet
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${DATA_DIR}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl start ${SERVICE_NAME}
sleep 2

if systemctl is-active --quiet ${SERVICE_NAME}; then
    echo "✅ Installed: ${SERVICE_NAME} (Features: ${FEATURES})"
    echo "RPC: 127.0.0.1:${RPC_PORT} — use Authorization: Bearer <rpc_auth token> (see ${CONFIG_FILE})"
else
    echo "❌ Failed. Check: journalctl -u ${SERVICE_NAME}"
    exit 1
fi
