//! Reporting Module
//!
//! Provides transparent metrics and reporting for governance activity.
//! These metrics enable users to verify governance is working and make
//! informed decisions. They are **transparent**, not **enforcement mechanisms**.

pub mod governance_metrics;

pub use governance_metrics::{
    ChallengeStatistics, GovernanceReport, MaintainerActivity, MaintainerMergeCount,
    MergeDistribution, MetricsReporter, PRStatistics, ReviewStatistics, ReviewTypeCount, TierCount,
};
