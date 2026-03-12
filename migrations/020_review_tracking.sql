-- Migration 019: Review Tracking and Signature Linking
-- Implements transparent review tracking and links signatures to reviews

-- Create reviews table for GitHub PR reviews
CREATE TABLE IF NOT EXISTS reviews (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_name TEXT NOT NULL,
    pr_number INTEGER NOT NULL,
    reviewer TEXT NOT NULL,
    state TEXT NOT NULL, -- 'approved', 'changes_requested', 'commented', 'dismissed'
    review_comment TEXT,
    submitted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(repo_name, pr_number, reviewer),
    FOREIGN KEY (reviewer) REFERENCES maintainers(github_username)
);

CREATE INDEX idx_reviews_pr ON reviews(repo_name, pr_number);
CREATE INDEX idx_reviews_reviewer ON reviews(reviewer);
CREATE INDEX idx_reviews_state ON reviews(state);
CREATE INDEX idx_reviews_submitted ON reviews(submitted_at);

-- Note: Signatures are stored as JSON in pull_requests.signatures
-- We'll track review linkage through queries, not a separate table
-- This keeps the system flexible and avoids schema changes to existing signatures

