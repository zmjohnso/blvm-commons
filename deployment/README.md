# Bitcoin Commons Deployment

**Unified CLI for Bitcoin Commons Infrastructure**

---

## 🚀 Quick Start

### Single Command Installation

```bash
cd deployment
chmod +x blvm.sh

# Install BLLVM node
sudo ./blvm.sh install blvm --public-ip YOUR_IP

# Check status
./blvm.sh status
```

---

## 📖 Documentation

**Full Guide:** See [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) for complete documentation.

**Quick Reference:**

```bash
# Install components
sudo ./blvm.sh install [blvm|experimental|commons] [options]

# Management
./blvm.sh [status|health|info|logs|config|restart] [component]

# Updates
sudo ./blvm.sh [update|uninstall] [component]
```

---

## 🎯 Components

- **`blvm`** - Base BLLVM node (production build)
- **`experimental`** - Experimental node (UTXO commitments, custom features)
- **`commons`** - Governance app (blvm-commons)

---

## 🔧 Features

- ✅ **Unified CLI** - Single `blvm.sh` entry point
- ✅ **Native Commands** - Uses `blvm` binary subcommands
- ✅ **Multi-Machine** - Deploy across separate machines
- ✅ **Auto-Configuration** - Automatic setup with sensible defaults
- ✅ **Health Monitoring** - Built-in health checks
- ✅ **Easy Updates** - Simple update/uninstall process

---

## 📋 What Gets Installed

### BLLVM Node
- Binary: `/opt/blvm/blvm`
- Config: `/etc/blvm/blvm.toml`
- Data: `/var/lib/blvm`
- Service: `blvm.service`

### Experimental Node
- Binary: `/opt/blvm/blvm-experimental`
- Config: `/etc/blvm/blvm.toml`
- Data: `/var/lib/blvm`
- Service: `blvm.service` (uses experimental binary)

### Governance App
- Binary: `/opt/blvm-commons/blvm-commons`
- Config: `/etc/blvm-commons/app.toml`
- Data: `/var/lib/blvm-commons`
- Service: `blvm-commons.service`

---

## 🐳 Docker Alternative

For Docker-based deployment, see `docker-compose.yml`:

```bash
docker-compose up -d
```

**Note:** Direct installation (this guide) is recommended for production deployments.

---

## 📚 More Information

- **Full Guide:** [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
- **Binary Commands:** See `blvm --help` after installation
- **Configuration:** See component config files in `/etc/blvm*/`

---

**Status:** Production Ready  
**Last Updated:** 2024

