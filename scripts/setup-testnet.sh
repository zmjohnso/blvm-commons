#!/bin/bash
# Setup testnet environment for Phase 2A testing
# This script sets up a complete testnet environment with test keys

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
GOVERNANCE_APP_DIR="$PROJECT_ROOT/governance-app"

echo "🚀 Setting up testnet environment for Phase 2A..."

# Change to governance-app directory
cd "$GOVERNANCE_APP_DIR"

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p logs
mkdir -p data
mkdir -p keys
mkdir -p test-keys

# Generate test maintainer keys
echo "🔑 Generating test maintainer keys..."
"$PROJECT_ROOT/scripts/generate-test-keys.sh"

# Generate test app keys
echo "🔑 Generating test GitHub App key..."
openssl genpkey -algorithm Ed25519 -out keys/testnet-app-key.pem 2>/dev/null

echo "🔑 Generating test Nostr key..."
openssl genpkey -algorithm Ed25519 -out keys/testnet-nostr-key.pem 2>/dev/null

# Set proper permissions
chmod 600 keys/*.pem
chmod 600 test-keys/*.pem

# Initialize database
echo "🗄️ Initializing testnet database..."
sqlite3 governance-app-testnet.db < migrations/001_initial_schema.sql
sqlite3 governance-app-testnet.db < migrations/002_emergency_mode.sql
sqlite3 governance-app-testnet.db < migrations/003_audit_log.sql
sqlite3 governance-app-testnet.db < migrations/004_noop.sql
sqlite3 governance-app-testnet.db < migrations/004_emergency_tiers.sql
sqlite3 governance-app-testnet.db < migrations/005_governance_fork.sql
sqlite3 governance-app-testnet.db < migrations/006_key_metadata.sql

# Populate with test maintainers
echo "👥 Adding test maintainers to database..."
sqlite3 governance-app-testnet.db < "$PROJECT_ROOT/scripts/populate-test-maintainers.sql"

# Create authorized servers
echo "🖥️ Creating authorized servers..."
cat > data/authorized_servers.json << 'EOF'
{
  "servers": [
    {
      "id": "testnet-server-1",
      "name": "Testnet Governance Server 1",
      "operator": "Test Operator",
      "nostr_public_key": "test_nostr_pubkey_1",
      "ssh_fingerprint": "SHA256:test_ssh_fingerprint_1",
      "status": "active",
      "added_at": "2024-01-01T00:00:00Z"
    }
  ]
}
EOF

# Set environment variables for testnet
echo "🔧 Setting up environment variables..."
cat > .env.testnet << 'EOF'
# Testnet Environment Variables
RUST_LOG=info
DATABASE_URL=sqlite:governance-app-testnet.db
DRY_RUN_MODE=false
LOG_ENFORCEMENT_DECISIONS=true
ENFORCEMENT_LOG_PATH=logs/enforcement-decisions.jsonl
GITHUB_APP_ID=123456
GITHUB_PRIVATE_KEY_PATH=keys/testnet-app-key.pem
GITHUB_WEBHOOK_SECRET=testnet-webhook-secret
NOSTR_PRIVATE_KEY_PATH=keys/testnet-nostr-key.pem
AUDIT_LOG_ENABLED=true
AUDIT_LOG_PATH=logs/audit.log
SERVER_AUTHORIZATION_ENABLED=true
GOVERNANCE_FORK_ENABLED=true
EOF

echo "✅ Testnet environment setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Start the testnet server:"
echo "   cd $GOVERNANCE_APP_DIR"
echo "   source .env.testnet"
echo "   cargo run --release"
echo ""
echo "2. Test signature verification:"
echo "   cargo run --release --bin sign-pr generate --username testuser --output test-keys"
echo "   cargo run --release --bin sign-pr sign --key test-keys/testuser_private.pem --repo test/repo --pr 1"
echo ""
echo "3. Check database:"
echo "   sqlite3 governance-app-testnet.db 'SELECT * FROM maintainers;'"
echo ""
echo "⚠️  WARNING: This is a TESTNET environment with test keys only!"
