-- Migration 018: Challenge Mechanism
-- Implements cryptographically signed challenges for governance decisions

CREATE TABLE IF NOT EXISTS challenges (
    id TEXT PRIMARY KEY,
    target_type TEXT NOT NULL, -- 'pull_request', 'governance_decision', 'maintainer_action', 'insufficient_review'
    target_id TEXT NOT NULL,
    challenger TEXT NOT NULL,
    reason TEXT NOT NULL,
    signature TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'under_review', 'resolved', 'rejected'
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP,
    resolution TEXT,
    resolver TEXT,
    
    FOREIGN KEY (challenger) REFERENCES maintainers(github_username)
);

CREATE INDEX idx_challenges_target ON challenges(target_type, target_id);
CREATE INDEX idx_challenges_status ON challenges(status);
CREATE INDEX idx_challenges_created ON challenges(created_at);
CREATE INDEX idx_challenges_challenger ON challenges(challenger);






