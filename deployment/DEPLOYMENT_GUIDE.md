# Bitcoin Commons Deployment Guide

Complete guide for deploying and managing Bitcoin Commons infrastructure.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Unified CLI (`blvm.sh`)](#unified-cli-blvmsh)
3. [Component Installation](#component-installation)
4. [Management Commands](#management-commands)
5. [Configuration](#configuration)
6. [Multi-Machine Deployment](#multi-machine-deployment)
7. [Using Binary Commands Directly](#using-binary-commands-directly)
8. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Single Machine Setup (5 minutes)

```bash
# Clone/download deployment scripts
cd deployment
chmod +x blvm.sh

# Install BLLVM node (base build)
sudo ./blvm.sh install blvm --public-ip YOUR_IP

# Check status
./blvm.sh status

# View logs
./blvm.sh logs blvm --follow
```

### Multi-Component Setup

```bash
# Install base node
sudo ./blvm.sh install blvm --public-ip 1.2.3.4

# Install experimental node (same machine, different binary)
sudo ./blvm.sh install experimental --public-ip 1.2.3.4

# Install governance app
sudo ./blvm.sh install commons --github-app-id 123456
```

---

## Unified CLI (`blvm.sh`)

The `blvm.sh` script is the single entry point for all deployment operations.

### Commands

| Command | Description | Requires Root |
|---------|-------------|---------------|
| `install` | Install a component | ✅ |
| `update` | Update installed component | ✅ |
| `uninstall` | Remove a component | ✅ |
| `status` | Show status of all components | ❌ |
| `logs` | View service logs | ❌ |
| `restart` | Restart a service | ✅ |
| `health` | Check RPC health/connectivity | ❌ |
| `info` | Show detailed component info | ❌ |
| `config` | Show/edit config file | ❌ (edit: ✅) |

### Components

- **`blvm`** - Base BLLVM node (production build, full blockchain)
- **`experimental`** - Experimental node (UTXO commitments, dandelion, CTV, etc.)
- **`commons`** - Governance app (blvm-commons)

### Usage Pattern

```bash
./blvm.sh [command] [component] [options]
```

---

## Component Installation

### 1. BLLVM Node (Base Build)

**Purpose:** Full Bitcoin node with production optimizations only.

**Installation:**

```bash
sudo ./blvm.sh install blvm --public-ip 1.2.3.4
```

**Options:**
- `--public-ip IP` - Public IP for P2P (auto-detected if not provided)
- `--rpc-password PASSWORD` - RPC password (auto-generated if not provided)
- `--version VERSION` - Specific version (default: latest)

**What Gets Installed:**
- Binary: `/opt/blvm/blvm`
- Config: `/etc/blvm/blvm.toml`
- Data: `/var/lib/blvm`
- Service: `blvm.service` (systemd)

**Default Ports:**
- RPC: `8332`
- P2P: `8333`

---

### 2. Experimental Node

**Purpose:** Bitcoin node with experimental features (UTXO commitments, Dandelion++, CTV, Stratum V2, etc.)

**Installation (Pre-built):**

```bash
sudo ./blvm.sh install experimental --public-ip 1.2.3.4
```

**Installation (Custom Features):**

```bash
sudo ./blvm.sh install experimental \
  --public-ip 1.2.3.4 \
  --features "utxo-commitments,dandelion,ctv,stratum-v2"
```

**Installation (Build from Source):**

```bash
sudo ./blvm.sh install experimental \
  --public-ip 1.2.3.4 \
  --build-from-source \
  --source-dir /path/to/blvm \
  --features "utxo-commitments,dandelion,ctv"
```

**Installation (Custom Binary):**

```bash
sudo ./blvm.sh install experimental \
  --public-ip 1.2.3.4 \
  --custom-binary /path/to/custom-blvm
```

**Options:**
- `--public-ip IP` - Public IP for P2P
- `--rpc-password PASSWORD` - RPC password
- `--features FEATURES` - Comma-separated feature flags
- `--build-from-source` - Build from source instead of downloading
- `--source-dir DIR` - Source directory (requires `--build-from-source`)
- `--custom-binary PATH` - Use custom binary file
- `--version VERSION` - Specific version

**What Gets Installed:**
- Binary: `/opt/blvm/blvm-experimental`
- Config: `/etc/blvm/blvm.toml` (same as base node)
- Data: `/var/lib/blvm` (can share with base node)
- Service: `blvm.service` (uses experimental binary)

**Note:** Experimental and base nodes can run on the same machine but use the same service name. Only one can be active at a time unless you configure different ports.

---

### 3. Governance App (blvm-commons)

**Purpose:** GitHub App for cryptographic governance enforcement.

**Installation:**

```bash
sudo ./blvm.sh install commons \
  --github-app-id 123456 \
  --github-webhook-secret your-secret
```

**Options:**
- `--github-app-id ID` - GitHub App ID (required)
- `--github-webhook-secret SECRET` - GitHub webhook secret
- `--version VERSION` - Specific version

**What Gets Installed:**
- Binary: `/opt/blvm-commons/blvm-commons`
- Config: `/etc/blvm-commons/app.toml`
- Data: `/var/lib/blvm-commons`
- Service: `blvm-commons.service` (systemd)

**Configuration:**

After installation, configure Nostr bots and other settings:

```bash
sudo ./blvm.sh config commons --edit
```

**Nostr Configuration:**

The governance app supports multi-bot Nostr integration. Configure in `app.toml`:

```toml
[nostr]
enabled = true
governance_config = "commons_mainnet"
zap_address = "donations@your-ln-address.com"
logo_url = "https://btcdecoded.org/assets/bitcoin-commons-logo.png"

[nostr.bots.gov]
nsec_path = "env:NOSTR_NSEC_GOV"  # GitHub Secret
npub = "npub1..."
lightning_address = "gov@your-ln-address.com"

[nostr.bots.dev]
nsec_path = "env:NOSTR_NSEC_DEV"
npub = "npub1..."
lightning_address = "dev@your-ln-address.com"
```

**GitHub Secrets Required:**
- `NOSTR_NSEC_GOV` - Governance bot private key
- `NOSTR_NSEC_DEV` - Development bot private key
- `NOSTR_NSEC_RESEARCH` - Research bot private key (optional)
- `NOSTR_NSEC_NETWORK` - Network bot private key (optional)

---

## Management Commands

### Status

**View all components:**

```bash
./blvm.sh status
```

**Output:**
```
=== Bitcoin Commons Status ===

blvm: ✅ Running
  Chain: mainnet
  Blocks: 850000
  Peers: 12

experimental: ❌ Stopped

commons: ✅ Running

Use 'systemctl status blvm' or 'systemctl status blvm-commons' for details
```

---

### Health Check

**Check node health:**

```bash
./blvm.sh health blvm
```

**Output:**
```
✅ Node is healthy
```

**Note:** Uses `blvm health` command internally (no manual RPC calls needed).

---

### Info

**Detailed component information:**

```bash
./blvm.sh info blvm
```

**Output:**
```
=== blvm Info ===

Status: ✅ Running
Binary: /opt/blvm/blvm
Type: ELF 64-bit LSB executable
Version: BLLVM 0.1.0
Config: /etc/blvm/blvm.toml
RPC Port: 8332
P2P Port: 8333
Data: /var/lib/blvm (250G)
Service: blvm
Enabled: Yes

=== Node Status ===
Chain: mainnet
Blocks: 850000
Sync: Complete
Peers: 12
```

---

### Logs

**View service logs:**

```bash
# Last 50 lines
./blvm.sh logs blvm

# Follow logs
./blvm.sh logs blvm --follow

# Last 100 lines
./blvm.sh logs blvm -n 100
```

---

### Restart

**Restart a service:**

```bash
sudo ./blvm.sh restart blvm
```

**Output:**
```
✅ Restarted: blvm
```

---

### Config

**View config:**

```bash
./blvm.sh config blvm
```

**Edit config:**

```bash
sudo ./blvm.sh config blvm --edit
```

**Note:** Uses `blvm config show` internally for node components.

---

### Update

**Update a component:**

```bash
# Update to latest
sudo ./blvm.sh update blvm

# Update to specific version
sudo ./blvm.sh update experimental --version v1.0.0
```

**What happens:**
1. Downloads new binary
2. Stops service
3. Replaces binary
4. Restarts service
5. Verifies health

---

### Uninstall

**Remove a component:**

```bash
sudo ./blvm.sh uninstall blvm
```

**What gets removed:**
- Systemd service
- Binary (`/opt/blvm/blvm`)
- Config (`/etc/blvm/blvm.toml`)
- Data directory (`/var/lib/blvm`) - **WARNING: This deletes blockchain data!**

**To keep data:**

```bash
# Uninstall but keep data
sudo ./blvm.sh uninstall blvm
# Data remains at /var/lib/blvm
```

---

## Configuration

### Node Configuration (`blvm.toml`)

**Location:** `/etc/blvm/blvm.toml`

**Key Settings:**

```toml
network = "mainnet"  # mainnet, testnet, regtest

[server]
listen_address = "0.0.0.0:8333"  # P2P
rpc_listen_address = "127.0.0.1:8332"  # RPC

[rpc]
user = "btc"
password = "your-secure-password"

[storage]
data_dir = "/var/lib/blvm"
```

**View config:**

```bash
./blvm.sh config blvm
```

**Edit config:**

```bash
sudo ./blvm.sh config blvm --edit
```

---

### Governance App Configuration (`app.toml`)

**Location:** `/etc/blvm-commons/app.toml`

**Key Settings:**

```toml
[github]
app_id = 123456
webhook_secret = "your-secret"

[nostr]
enabled = true
governance_config = "commons_mainnet"
relays = ["wss://relay.damus.io", "wss://nos.lol"]

[database]
path = "/var/lib/blvm-commons/db.sqlite"
```

---

## Multi-Machine Deployment

### Scenario: 3 Separate Machines

**Machine 1 (ArchLinux - Innovation Hub):**
- Base BLLVM node (archival)

**Machine 2 (Ubuntu - Linode):**
- Experimental node (UTXO commitments)

**Machine 3 (Ubuntu - Innovation Hub):**
- Experimental node (UTXO commitments)

**Machine 4 (Optional - Any):**
- Governance app (blvm-commons)

---

### Deployment Steps

**1. On Machine 1 (ArchLinux):**

```bash
cd deployment
chmod +x blvm.sh
sudo ./blvm.sh install blvm --public-ip MACHINE1_IP
./blvm.sh status
```

**2. On Machine 2 (Ubuntu - Linode):**

```bash
cd deployment
chmod +x blvm.sh
sudo ./blvm.sh install experimental --public-ip MACHINE2_IP
./blvm.sh status
```

**3. On Machine 3 (Ubuntu - Innovation Hub):**

```bash
cd deployment
chmod +x blvm.sh
sudo ./blvm.sh install experimental --public-ip MACHINE3_IP
./blvm.sh status
```

**4. On Machine 4 (Governance App):**

```bash
cd deployment
chmod +x blvm.sh
sudo ./blvm.sh install commons --github-app-id 123456
./blvm.sh status
```

---

### Verification

**Check all nodes:**

```bash
# On each machine
./blvm.sh health blvm  # or experimental
./blvm.sh info blvm
```

**From a central location:**

```bash
# Test RPC connectivity
curl -u btc:password http://MACHINE1_IP:8332 \
  -d '{"method":"getblockchaininfo","params":[]}'
```

---

## Using Binary Commands Directly

The `blvm` binary includes native subcommands that can be used directly:

### Available Commands

```bash
# Version
/opt/blvm/blvm version

# Status
/opt/blvm/blvm status

# Health
/opt/blvm/blvm health

# Chain info
/opt/blvm/blvm chain

# Peers
/opt/blvm/blvm peers

# Network info
/opt/blvm/blvm network

# Sync status
/opt/blvm/blvm sync

# Config
/opt/blvm/blvm config show
/opt/blvm/blvm config validate
/opt/blvm/blvm config path

# RPC (generic)
/opt/blvm/blvm rpc getblockchaininfo
/opt/blvm/blvm rpc getpeerinfo '[]'
```

### With Custom RPC Address

```bash
/opt/blvm/blvm --rpc-addr 127.0.0.1:8332 status
```

### Integration

The deployment scripts (`health.sh`, `info.sh`, `config.sh`, `status.sh`) use these binary commands internally, so you get the same functionality whether you use the scripts or the binary directly.

---

## Troubleshooting

### Service Won't Start

**Check logs:**

```bash
./blvm.sh logs blvm
journalctl -u blvm -n 100
```

**Check config:**

```bash
./blvm.sh config blvm
/opt/blvm/blvm config validate
```

**Check permissions:**

```bash
ls -la /opt/blvm/blvm
ls -la /var/lib/blvm
ls -la /etc/blvm/blvm.toml
```

---

### RPC Not Responding

**Check if service is running:**

```bash
./blvm.sh status
systemctl status blvm
```

**Test health:**

```bash
./blvm.sh health blvm
```

**Check firewall:**

```bash
sudo ufw status
sudo firewall-cmd --list-all
```

**Check RPC address in config:**

```bash
./blvm.sh config blvm | grep rpc_listen_address
```

---

### Binary Commands Fail

**Check binary exists:**

```bash
ls -la /opt/blvm/blvm
file /opt/blvm/blvm
```

**Check binary permissions:**

```bash
chmod +x /opt/blvm/blvm
```

**Test binary directly:**

```bash
/opt/blvm/blvm version
/opt/blvm/blvm --help
```

**Note:** Scripts fall back gracefully if binary commands fail.

---

### Experimental Node Issues

**Check feature flags:**

```bash
/opt/blvm/blvm-experimental version
```

**Rebuild with different features:**

```bash
sudo ./blvm.sh uninstall experimental
sudo ./blvm.sh install experimental \
  --build-from-source \
  --features "utxo-commitments,dandelion"
```

---

### Governance App Issues

**Check Nostr configuration:**

```bash
./blvm.sh config commons | grep -A 20 nostr
```

**Check GitHub App credentials:**

```bash
./blvm.sh config commons | grep -A 10 github
```

**View logs:**

```bash
./blvm.sh logs commons --follow
```

---

## Best Practices

### Security

1. **Use strong RPC passwords:**
   ```bash
   openssl rand -hex 32
   ```

2. **Restrict RPC access:**
   ```toml
   rpc_listen_address = "127.0.0.1:8332"  # Localhost only
   ```

3. **Use firewall:**
   ```bash
   sudo ufw allow 8333/tcp  # P2P only
   sudo ufw deny 8332/tcp   # RPC (if exposed)
   ```

4. **Protect Nostr keys:**
   - Use GitHub Secrets for `NOSTR_NSEC_*`
   - Never commit keys to repository

---

### Monitoring

1. **Regular health checks:**
   ```bash
   ./blvm.sh health blvm
   ```

2. **Monitor logs:**
   ```bash
   ./blvm.sh logs blvm --follow
   ```

3. **Check disk space:**
   ```bash
   df -h /var/lib/blvm
   ```

4. **Monitor sync status:**
   ```bash
   ./blvm.sh info blvm | grep Sync
   ```

---

### Updates

1. **Test updates on non-production first**

2. **Backup data before updates:**
   ```bash
   sudo systemctl stop blvm
   sudo cp -r /var/lib/blvm /var/lib/blvm.backup
   sudo ./blvm.sh update blvm
   ```

3. **Verify after update:**
   ```bash
   ./blvm.sh health blvm
   ./blvm.sh info blvm
   ```

---

## Summary

- **Single Entry Point:** `blvm.sh` for all operations
- **Three Components:** `blvm`, `experimental`, `commons`
- **Native Commands:** Binary subcommands integrated into scripts
- **Multi-Machine:** Deploy across separate machines easily
- **Production Ready:** Full Bitcoin node with governance

**Quick Reference:**

```bash
# Install
sudo ./blvm.sh install [blvm|experimental|commons] [options]

# Manage
./blvm.sh [status|health|info|logs|config|restart] [component]

# Update/Remove
sudo ./blvm.sh [update|uninstall] [component]
```

---

**Status:** Production Ready  
**Last Updated:** 2024  
**Maintained By:** Bitcoin Commons Team

