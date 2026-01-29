//! Governance Metrics Reporting
//!
//! Generates transparent metrics about governance activity. These metrics
//! enable users to verify governance is working and make informed decisions.
//! They are **transparent**, not **enforcement mechanisms**.

use crate::error::GovernanceError;
use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GovernanceReport {
    pub period_start: DateTime<Utc>,
    pub period_end: DateTime<Utc>,
    pub merge_distribution: MergeDistribution,
    pub pr_statistics: PRStatistics,
    pub challenge_statistics: ChallengeStatistics,
    pub review_statistics: ReviewStatistics,
    pub maintainer_activity: Vec<MaintainerActivity>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MergeDistribution {
    pub total_merges: u32,
    pub by_maintainer: Vec<MaintainerMergeCount>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MaintainerMergeCount {
    pub username: String,
    pub count: u32,
    pub percentage: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PRStatistics {
    pub total_prs: u32,
    pub merged: u32,
    pub pending: u32,
    pub rejected: u32,
    pub by_tier: Vec<TierCount>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TierCount {
    pub tier: u32,
    pub count: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChallengeStatistics {
    pub total_challenges: u32,
    pub pending: u32,
    pub resolved: u32,
    pub rejected: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReviewStatistics {
    pub total_reviews: u32,
    pub reviews_by_type: Vec<ReviewTypeCount>,
    pub signatures_without_review: u32,
    pub signatures_with_review: u32,
    pub average_review_comments: f64,
    pub prs_without_reviews: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReviewTypeCount {
    pub state: String,
    pub count: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MaintainerActivity {
    pub username: String,
    pub prs_merged: u32,
    pub signatures_given: u32,
    pub reviews_given: u32,
    pub challenges_created: u32,
    pub challenges_resolved: u32,
}

pub struct MetricsReporter {
    pool: SqlitePool,
}

impl MetricsReporter {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    /// Generate monthly governance report
    pub async fn generate_monthly_report(
        &self,
        month: DateTime<Utc>,
    ) -> Result<GovernanceReport, GovernanceError> {
        let period_start = month.with_day(1).unwrap();
        let next_month = if month.month() == 12 {
            period_start.with_year(month.year() + 1).unwrap().with_month(1).unwrap()
        } else {
            period_start.with_month(month.month() + 1).unwrap()
        };
        let period_end = next_month - Duration::seconds(1);

        // Query merge distribution
        let merge_distribution = self.get_merge_distribution(period_start, period_end).await?;
        
        // Query PR statistics
        let pr_statistics = self.get_pr_statistics(period_start, period_end).await?;
        
        // Query challenge statistics
        let challenge_statistics = self.get_challenge_statistics(period_start, period_end).await?;
        
        // Query maintainer activity
        let maintainer_activity = self.get_maintainer_activity(period_start, period_end).await?;

        // Query review statistics
        let review_statistics = self.get_review_statistics(period_start, period_end).await?;

        Ok(GovernanceReport {
            period_start,
            period_end,
            merge_distribution,
            pr_statistics,
            challenge_statistics,
            review_statistics,
            maintainer_activity,
        })
    }

    async fn get_merge_distribution(
        &self,
        start: DateTime<Utc>,
        end: DateTime<Utc>,
    ) -> Result<MergeDistribution, GovernanceError> {
        // Query merges from governance_events
        let rows = sqlx::query!(
            r#"
            SELECT maintainer, COUNT(*) as count
            FROM governance_events
            WHERE event_type = 'merge_approved'
            AND timestamp >= ? AND timestamp <= ?
            AND maintainer IS NOT NULL
            GROUP BY maintainer
            ORDER BY count DESC
            "#,
            start.to_rfc3339(),
            end.to_rfc3339()
        )
        .fetch_all(&self.pool)
        .await?;

        let total: u32 = rows.iter().map(|r| r.count as u32).sum();
        
        let by_maintainer: Vec<MaintainerMergeCount> = rows
            .into_iter()
            .map(|row| {
                let percentage = if total > 0 {
                    (row.count as f64 / total as f64) * 100.0
                } else {
                    0.0
                };
                MaintainerMergeCount {
                    username: row.maintainer.unwrap_or_default(),
                    count: row.count as u32,
                    percentage,
                }
            })
            .collect();

        Ok(MergeDistribution {
            total_merges: total,
            by_maintainer,
        })
    }

    async fn get_pr_statistics(
        &self,
        start: DateTime<Utc>,
        end: DateTime<Utc>,
    ) -> Result<PRStatistics, GovernanceError> {
        // Query PRs opened in period
        let total_prs: i64 = sqlx::query_scalar!(
            r#"
            SELECT COUNT(*) as count
            FROM pull_requests
            WHERE opened_at >= ? AND opened_at <= ?
            "#,
            start.to_rfc3339(),
            end.to_rfc3339()
        )
        .fetch_one(&self.pool)
        .await?
        .unwrap_or(0);

        // Query merged PRs
        let merged: i64 = sqlx::query_scalar!(
            r#"
            SELECT COUNT(*) as count
            FROM governance_events
            WHERE event_type = 'merge_approved'
            AND timestamp >= ? AND timestamp <= ?
            "#,
            start.to_rfc3339(),
            end.to_rfc3339()
        )
        .fetch_one(&self.pool)
        .await?
        .unwrap_or(0);

        // Query pending PRs (opened but not merged)
        let pending: i64 = sqlx::query_scalar!(
            r#"
            SELECT COUNT(*) as count
            FROM pull_requests
            WHERE opened_at >= ? AND opened_at <= ?
            AND governance_status != 'merged'
            "#,
            start.to_rfc3339(),
            end.to_rfc3339()
        )
        .fetch_one(&self.pool)
        .await?
        .unwrap_or(0);

        // Query rejected PRs (blocked merges)
        let rejected: i64 = sqlx::query_scalar!(
            r#"
            SELECT COUNT(*) as count
            FROM governance_events
            WHERE event_type = 'merge_blocked'
            AND timestamp >= ? AND timestamp <= ?
            "#,
            start.to_rfc3339(),
            end.to_rfc3339()
        )
        .fetch_one(&self.pool)
        .await?
        .unwrap_or(0);

        // Query PRs by tier (from tier_overrides or default classification)
        let tier_rows = sqlx::query!(
            r#"
            SELECT 
                COALESCE(to.override_tier, 1) as tier,
                COUNT(*) as count
            FROM pull_requests pr
            LEFT JOIN tier_overrides to ON pr.repo_name = to.repo_name AND pr.pr_number = to.pr_number
            WHERE pr.opened_at >= ? AND pr.opened_at <= ?
            GROUP BY tier
            ORDER BY tier
            "#,
            start.to_rfc3339(),
            end.to_rfc3339()
        )
        .fetch_all(&self.pool)
        .await?;

        let by_tier: Vec<TierCount> = tier_rows
            .into_iter()
            .map(|row| TierCount {
                tier: row.tier as u32,
                count: row.count as u32,
            })
            .collect();

        Ok(PRStatistics {
            total_prs: total_prs as u32,
            merged: merged as u32,
            pending: pending as u32,
            rejected: rejected as u32,
            by_tier,
        })
    }

    async fn get_challenge_statistics(
        &self,
        start: DateTime<Utc>,
        end: DateTime<Utc>,
    ) -> Result<ChallengeStatistics, GovernanceError> {
        // Query total challenges
        let total: i64 = sqlx::query_scalar!(
            r#"
            SELECT COUNT(*) as count
            FROM challenges
            WHERE created_at >= ? AND created_at <= ?
            "#,
            start.to_rfc3339(),
            end.to_rfc3339()
        )
        .fetch_one(&self.pool)
        .await?
        .unwrap_or(0);

        // Query pending challenges
        let pending: i64 = sqlx::query_scalar!(
            r#"
            SELECT COUNT(*) as count
            FROM challenges
            WHERE created_at >= ? AND created_at <= ?
            AND status IN ('pending', 'under_review')
            "#,
            start.to_rfc3339(),
            end.to_rfc3339()
        )
        .fetch_one(&self.pool)
        .await?
        .unwrap_or(0);

        // Query resolved challenges
        let resolved: i64 = sqlx::query_scalar!(
            r#"
            SELECT COUNT(*) as count
            FROM challenges
            WHERE created_at >= ? AND created_at <= ?
            AND status = 'resolved'
            "#,
            start.to_rfc3339(),
            end.to_rfc3339()
        )
        .fetch_one(&self.pool)
        .await?
        .unwrap_or(0);

        // Query rejected challenges
        let rejected: i64 = sqlx::query_scalar!(
            r#"
            SELECT COUNT(*) as count
            FROM challenges
            WHERE created_at >= ? AND created_at <= ?
            AND status = 'rejected'
            "#,
            start.to_rfc3339(),
            end.to_rfc3339()
        )
        .fetch_one(&self.pool)
        .await?
        .unwrap_or(0);

        Ok(ChallengeStatistics {
            total_challenges: total as u32,
            pending: pending as u32,
            resolved: resolved as u32,
            rejected: rejected as u32,
        })
    }

    async fn get_maintainer_activity(
        &self,
        start: DateTime<Utc>,
        end: DateTime<Utc>,
    ) -> Result<Vec<MaintainerActivity>, GovernanceError> {
        // Get all active maintainers
        let maintainers = sqlx::query!(
            r#"
            SELECT github_username
            FROM maintainers
            WHERE active = true
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        let mut activity = Vec::new();

        for maintainer in maintainers {
            let username = maintainer.github_username;

            // Count PRs merged by this maintainer
            let prs_merged: i64 = sqlx::query_scalar!(
                r#"
                SELECT COUNT(*) as count
                FROM governance_events
                WHERE event_type = 'merge_approved'
                AND maintainer = ?
                AND timestamp >= ? AND timestamp <= ?
                "#,
                username,
                start.to_rfc3339(),
                end.to_rfc3339()
            )
            .fetch_one(&self.pool)
            .await?
            .unwrap_or(0);

            // Count signatures given (extract from JSON in pull_requests.signatures)
            // SQLite JSON functions: json_each extracts array elements
            let signatures_given: i64 = sqlx::query_scalar!(
                r#"
                SELECT COUNT(*) as count
                FROM pull_requests pr,
                json_each(pr.signatures) sig
                WHERE json_extract(sig.value, '$.signer') = ?
                AND json_extract(sig.value, '$.timestamp') >= ? 
                AND json_extract(sig.value, '$.timestamp') <= ?
                "#,
                username,
                start.to_rfc3339(),
                end.to_rfc3339()
            )
            .fetch_one(&self.pool)
            .await?
            .unwrap_or(0);

            // Count challenges created
            let challenges_created: i64 = sqlx::query_scalar!(
                r#"
                SELECT COUNT(*) as count
                FROM challenges
                WHERE challenger = ?
                AND created_at >= ? AND created_at <= ?
                "#,
                username,
                start.to_rfc3339(),
                end.to_rfc3339()
            )
            .fetch_one(&self.pool)
            .await?
            .unwrap_or(0);

            // Count challenges resolved
            let challenges_resolved: i64 = sqlx::query_scalar!(
                r#"
                SELECT COUNT(*) as count
                FROM challenges
                WHERE resolver = ?
                AND resolved_at >= ? AND resolved_at <= ?
                "#,
                username,
                start.to_rfc3339(),
                end.to_rfc3339()
            )
            .fetch_one(&self.pool)
            .await?
            .unwrap_or(0);

            // Count reviews given
            let reviews_given: i64 = sqlx::query_scalar!(
                r#"
                SELECT COUNT(*) as count
                FROM reviews
                WHERE reviewer = ?
                AND submitted_at >= ? AND submitted_at <= ?
                "#,
                username,
                start.to_rfc3339(),
                end.to_rfc3339()
            )
            .fetch_one(&self.pool)
            .await?
            .unwrap_or(0);

            activity.push(MaintainerActivity {
                username,
                prs_merged: prs_merged as u32,
                signatures_given: signatures_given as u32,
                reviews_given: reviews_given as u32,
                challenges_created: challenges_created as u32,
                challenges_resolved: challenges_resolved as u32,
            });
        }

        // Sort by total activity (signatures + merges + reviews + challenges)
        activity.sort_by(|a, b| {
            let a_total = a.signatures_given + a.prs_merged + a.reviews_given + a.challenges_created + a.challenges_resolved;
            let b_total = b.signatures_given + b.prs_merged + b.reviews_given + b.challenges_created + b.challenges_resolved;
            b_total.cmp(&a_total)
        });

        Ok(activity)
    }

    async fn get_review_statistics(
        &self,
        start: DateTime<Utc>,
        end: DateTime<Utc>,
    ) -> Result<ReviewStatistics, GovernanceError> {
        // Query total reviews
        let total_reviews: i64 = sqlx::query_scalar!(
            r#"
            SELECT COUNT(*) as count
            FROM reviews
            WHERE submitted_at >= ? AND submitted_at <= ?
            "#,
            start.to_rfc3339(),
            end.to_rfc3339()
        )
        .fetch_one(&self.pool)
        .await?
        .unwrap_or(0);

        // Query reviews by type
        let review_type_rows = sqlx::query!(
            r#"
            SELECT state, COUNT(*) as count
            FROM reviews
            WHERE submitted_at >= ? AND submitted_at <= ?
            GROUP BY state
            ORDER BY count DESC
            "#,
            start.to_rfc3339(),
            end.to_rfc3339()
        )
        .fetch_all(&self.pool)
        .await?;

        let reviews_by_type: Vec<ReviewTypeCount> = review_type_rows
            .into_iter()
            .map(|row| ReviewTypeCount {
                state: row.state,
                count: row.count as u32,
            })
            .collect();

        // Count signatures with/without reviews
        // Signatures are in JSON, reviews are in separate table
        // We need to check if each signature has a corresponding review
        let signatures_with_review: i64 = sqlx::query_scalar!(
            r#"
            SELECT COUNT(DISTINCT pr.repo_name || '-' || pr.pr_number || '-' || json_extract(sig.value, '$.signer')) as count
            FROM pull_requests pr,
            json_each(pr.signatures) sig,
            reviews r
            WHERE pr.opened_at >= ? AND pr.opened_at <= ?
            AND r.repo_name = pr.repo_name
            AND r.pr_number = pr.pr_number
            AND r.reviewer = json_extract(sig.value, '$.signer')
            AND r.submitted_at <= json_extract(sig.value, '$.timestamp')
            "#,
            start.to_rfc3339(),
            end.to_rfc3339()
        )
        .fetch_one(&self.pool)
        .await?
        .unwrap_or(0);

        // Total signatures in period
        let total_signatures: i64 = sqlx::query_scalar!(
            r#"
            SELECT COUNT(*) as count
            FROM pull_requests pr,
            json_each(pr.signatures) sig
            WHERE pr.opened_at >= ? AND pr.opened_at <= ?
            AND json_extract(sig.value, '$.timestamp') >= ? 
            AND json_extract(sig.value, '$.timestamp') <= ?
            "#,
            start.to_rfc3339(),
            end.to_rfc3339(),
            start.to_rfc3339(),
            end.to_rfc3339()
        )
        .fetch_one(&self.pool)
        .await?
        .unwrap_or(0);

        let signatures_without_review = (total_signatures - signatures_with_review).max(0) as u32;

        // Average review comments (reviews with non-empty comments)
        let reviews_with_comments: i64 = sqlx::query_scalar!(
            r#"
            SELECT COUNT(*) as count
            FROM reviews
            WHERE submitted_at >= ? AND submitted_at <= ?
            AND review_comment IS NOT NULL
            AND review_comment != ''
            "#,
            start.to_rfc3339(),
            end.to_rfc3339()
        )
        .fetch_one(&self.pool)
        .await?
        .unwrap_or(0);

        let average_review_comments = if total_reviews > 0 {
            (reviews_with_comments as f64 / total_reviews as f64) * 100.0
        } else {
            0.0
        };

        // PRs without any reviews
        let prs_without_reviews: i64 = sqlx::query_scalar!(
            r#"
            SELECT COUNT(*) as count
            FROM pull_requests pr
            LEFT JOIN reviews r ON pr.repo_name = r.repo_name AND pr.pr_number = r.pr_number
            WHERE pr.opened_at >= ? AND pr.opened_at <= ?
            AND r.id IS NULL
            "#,
            start.to_rfc3339(),
            end.to_rfc3339()
        )
        .fetch_one(&self.pool)
        .await?
        .unwrap_or(0);

        Ok(ReviewStatistics {
            total_reviews: total_reviews as u32,
            reviews_by_type,
            signatures_without_review,
            signatures_with_review: signatures_with_review as u32,
            average_review_comments,
            prs_without_reviews: prs_without_reviews as u32,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_governance_report_serialization() {
        let report = GovernanceReport {
            period_start: Utc::now(),
            period_end: Utc::now(),
            merge_distribution: MergeDistribution {
                total_merges: 10,
                by_maintainer: vec![
                    MaintainerMergeCount {
                        username: "alice".to_string(),
                        count: 6,
                        percentage: 60.0,
                    },
                    MaintainerMergeCount {
                        username: "bob".to_string(),
                        count: 4,
                        percentage: 40.0,
                    },
                ],
            },
            pr_statistics: PRStatistics {
                total_prs: 20,
                merged: 15,
                pending: 3,
                rejected: 2,
                by_tier: vec![
                    TierCount { tier: 1, count: 10 },
                    TierCount { tier: 2, count: 5 },
                ],
            },
            challenge_statistics: ChallengeStatistics {
                total_challenges: 5,
                pending: 2,
                resolved: 2,
                rejected: 1,
            },
            maintainer_activity: vec![
                MaintainerActivity {
                    username: "alice".to_string(),
                    prs_merged: 6,
                    signatures_given: 20,
                    reviews_given: 15,
                    challenges_created: 1,
                    challenges_resolved: 2,
                },
            ],
            review_statistics: ReviewStatistics {
                total_reviews: 25,
                reviews_by_type: vec![
                    ReviewTypeCount {
                        state: "approved".to_string(),
                        count: 20,
                    },
                    ReviewTypeCount {
                        state: "commented".to_string(),
                        count: 5,
                    },
                ],
                signatures_without_review: 2,
                signatures_with_review: 18,
                average_review_comments: 80.0,
                prs_without_reviews: 1,
            },
        };

        let json = serde_json::to_string_pretty(&report).unwrap();
        assert!(json.contains("alice"));
        assert!(json.contains("merge_distribution"));
    }
}

