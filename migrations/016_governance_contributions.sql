-- Migration 016: Governance Contributions (unified_contributions, participation_weights)
-- Creates tables for tracking zap contributions and participation weights
-- Required by migration 017

CREATE TABLE IF NOT EXISTS unified_contributions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    contributor_id TEXT NOT NULL,
    contributor_type TEXT NOT NULL,
    contribution_type TEXT NOT NULL,
    amount_btc REAL NOT NULL,
    timestamp DATETIME NOT NULL,
    contribution_age_days INTEGER DEFAULT 0,
    period_type TEXT NOT NULL,
    verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_contributor ON unified_contributions(contributor_id);
CREATE INDEX IF NOT EXISTS idx_contributor_type ON unified_contributions(contributor_type);
CREATE INDEX IF NOT EXISTS idx_timestamp ON unified_contributions(timestamp);

CREATE TABLE IF NOT EXISTS participation_weights (
    contributor_id TEXT PRIMARY KEY,
    contributor_type TEXT NOT NULL,
    merge_mining_btc REAL DEFAULT 0.0,
    fee_forwarding_btc REAL DEFAULT 0.0,
    cumulative_zaps_btc REAL DEFAULT 0.0,
    total_contribution_btc REAL NOT NULL,
    base_weight REAL NOT NULL,
    capped_weight REAL NOT NULL,
    total_system_weight REAL NOT NULL,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
