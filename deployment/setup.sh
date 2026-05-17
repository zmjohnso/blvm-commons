#!/bin/bash
# Bitcoin Commons Deployment Setup Script
# Path of Least Resistance - Automated Setup

set -e

echo "=== Bitcoin Commons Deployment Setup ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check prerequisites
echo "Checking prerequisites..."
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found. Please install Docker first.${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose not found. Please install Docker Compose first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker found${NC}"

# Create directory structure
echo ""
echo "Creating directory structure..."
mkdir -p governance-data
mkdir -p governance-keys/nostr
mkdir -p governance-config
mkdir -p governance-logs
mkdir -p archival-data
mkdir -p archival-config
mkdir -p utxo-1-data
mkdir -p utxo-1-config
mkdir -p utxo-2-data
mkdir -p utxo-2-config
mkdir -p utxo-3-data
mkdir -p utxo-3-config

echo -e "${GREEN}✅ Directories created${NC}"

# Generate Nostr keys
echo ""
echo "Generating Nostr bot keys..."
if command -v nostr-tool &> /dev/null; then
    echo "Using nostr-tool..."
    for bot in gov dev research network; do
        if [ ! -f "governance-keys/nostr/${bot}.nsec" ]; then
            nostr-tool generate > "governance-keys/nostr/${bot}.nsec" 2>/dev/null || {
                echo -e "${YELLOW}⚠️  nostr-tool generate failed, using random key${NC}"
                openssl rand -hex 32 > "governance-keys/nostr/${bot}.nsec"
            }
            nostr-tool convert "governance-keys/nostr/${bot}.nsec" > "governance-keys/nostr/${bot}.npub" 2>/dev/null || {
                echo -e "${YELLOW}⚠️  Could not convert to npub, will need to do manually${NC}"
            }
            chmod 600 "governance-keys/nostr/${bot}.nsec"
            echo -e "${GREEN}✅ Generated ${bot} key${NC}"
        else
            echo -e "${YELLOW}⚠️  ${bot}.nsec already exists, skipping${NC}"
        fi
    done
else
    echo -e "${YELLOW}⚠️  nostr-tool not found. Generating placeholder keys.${NC}"
    echo -e "${YELLOW}   Install with: cargo install nostr-tool${NC}"
    for bot in gov dev research network; do
        if [ ! -f "governance-keys/nostr/${bot}.nsec" ]; then
            openssl rand -hex 32 > "governance-keys/nostr/${bot}.nsec"
            chmod 600 "governance-keys/nostr/${bot}.nsec"
            echo -e "${YELLOW}⚠️  Generated placeholder ${bot}.nsec (replace with real key)${NC}"
        fi
    done
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo ""
    echo "Creating .env file..."
    cat > .env << EOF
# GitHub App Configuration
GITHUB_APP_ID=123456
GITHUB_WEBHOOK_SECRET=CHANGE_THIS_SECRET

# RPC Configuration
RPC_USER=btc
RPC_PASSWORD=CHANGE_THIS_PASSWORD

# Nostr Configuration
NOSTR_ZAP_ADDRESS=donations@btcdecoded.org
EOF
    echo -e "${GREEN}✅ Created .env file${NC}"
    echo -e "${YELLOW}⚠️  Please edit .env and update secrets!${NC}"
else
    echo -e "${YELLOW}⚠️  .env file already exists, skipping${NC}"
fi

# Create node configs
echo ""
echo "Creating node configuration files..."

# Archival node config (NodeConfig; RPC via blvm --rpc-addr in compose/command)
cat > archival-config/config.toml << 'EOF'
listen_addr = "0.0.0.0:8333"
protocol_version = "BitcoinV1"
max_peers = 125
transport_preference = "tcponly"
enable_self_advertisement = true

[storage]
data_dir = "/app/data"
database_backend = "auto"

[storage.pruning]
mode = { type = "disabled" }

[rpc_auth]
required = true
tokens = ["CHANGE_THIS_PASSWORD"]

[logging]
level = "info"
EOF

# UTXO commitment nodes — ports aligned with DEPLOYMENT_GUIDE (RPC / P2P)
for i in 1 2 3; do
    case $i in
        1) RPC_PORT=8335; P2P_PORT=8334 ;;
        2) RPC_PORT=8336; P2P_PORT=8337 ;;
        3) RPC_PORT=8338; P2P_PORT=8339 ;;
    esac

    cat > "utxo-${i}-config/config.toml" << EOF
listen_addr = "0.0.0.0:${P2P_PORT}"
protocol_version = "BitcoinV1"
max_peers = 100
transport_preference = "tcponly"
enable_self_advertisement = true

[storage]
data_dir = "/app/data"
database_backend = "auto"

[storage.pruning]
mode = { type = "aggressive", keep_from_height = 0, keep_commitments = true, keep_filtered_blocks = false, min_blocks = 288 }
incremental_prune_during_ibd = true
prune_window_size = 144
min_blocks_for_incremental_prune = 288
auto_prune = true
auto_prune_interval = 144
min_blocks_to_keep = 288

[rpc_auth]
required = true
tokens = ["CHANGE_THIS_PASSWORD"]

[logging]
level = "info"
EOF
done

echo -e "${GREEN}✅ Node configs created${NC}"

# Create governance app config
echo ""
echo "Creating governance app configuration..."
cat > governance-config/app.toml << 'EOF'
[server]
host = "0.0.0.0"
port = 8080

[database]
max_connections = 10
min_connections = 2

[nostr]
enabled = true
governance_config = "commons_mainnet"
relays = [
    "wss://relay.damus.io",
    "wss://nos.lol",
    "wss://relay.nostr.band"
]
publish_interval_secs = 3600

[nostr.bots.gov]
nsec_path = "/app/keys/nostr/gov.nsec"
npub = "REPLACE_WITH_NPUB"  # Get from: nostr-tool convert keys/nostr/gov.nsec
lightning_address = "donations@btcdecoded.org"
profile_name = "🏛️ @BTCCommons_Gov"
profile_about = "Official governance announcements from Bitcoin Commons. Transparent, cryptographically-signed decisions. Zaps fund decentralized development."
profile_picture = "https://btcdecoded.org/assets/bitcoin-commons-logo.png"

[nostr.bots.dev]
nsec_path = "/app/keys/nostr/dev.nsec"
npub = "REPLACE_WITH_NPUB"
lightning_address = "dev@btcdecoded.org"
profile_name = "⚙️ @BTCCommons_Dev"
profile_about = "Development updates from Bitcoin Commons. Performance benchmarks, code releases, technical achievements. Zaps fund open source work."
profile_picture = "https://btcdecoded.org/assets/bitcoin-commons-logo.png"

[nostr.bots.research]
nsec_path = "/app/keys/nostr/research.nsec"
npub = "REPLACE_WITH_NPUB"
lightning_address = "research@btcdecoded.org"
profile_name = "📚 @BTCCommons_Research"
profile_about = "Educational content and research from Bitcoin Commons. Governance analysis, Bitcoin development insights, research findings."
profile_picture = "https://btcdecoded.org/assets/bitcoin-commons-logo.png"

[nostr.bots.network]
nsec_path = "/app/keys/nostr/network.nsec"
npub = "REPLACE_WITH_NPUB"
lightning_address = "network@btcdecoded.org"
profile_name = "📊 @BTCCommons_Network"
profile_about = "Network metrics and statistics from Bitcoin Commons. Node adoption, miner participation, network health."
profile_picture = "https://btcdecoded.org/assets/bitcoin-commons-logo.png"
EOF

echo -e "${GREEN}✅ Governance app config created${NC}"

# Instructions
echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. Edit .env file and update secrets:"
echo "   - GITHUB_APP_ID"
echo "   - GITHUB_WEBHOOK_SECRET"
echo "   - RPC_PASSWORD"
echo ""
echo "2. Get npubs for governance-config/app.toml:"
echo "   nostr-tool convert governance-keys/nostr/gov.nsec"
echo "   nostr-tool convert governance-keys/nostr/dev.nsec"
echo "   (etc.)"
echo ""
echo "3. Add GitHub App private key:"
echo "   cp /path/to/github-app.pem governance-keys/github-app.pem"
echo ""
echo "4. Update node configs with your public IP:"
echo "   Edit archival-config/config.toml"
echo "   Edit utxo-*-config/config.toml"
echo ""
echo "5. Deploy:"
echo "   docker-compose up -d"
echo ""
echo "6. Check logs:"
echo "   docker-compose logs -f"
echo ""

