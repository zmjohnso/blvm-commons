use serde_json::Value;
use tracing::{info, warn};

use crate::database::Database;

pub async fn handle_review_event(
    database: &Database,
    payload: &Value,
) -> Result<axum::response::Json<serde_json::Value>, axum::http::StatusCode> {
    let repo_name = payload
        .get("repository")
        .and_then(|r| r.get("full_name"))
        .and_then(|n| n.as_str())
        .unwrap_or("unknown");

    let pr_number = payload
        .get("pull_request")
        .and_then(|pr| pr.get("number"))
        .and_then(|n| n.as_u64())
        .unwrap_or(0);

    let reviewer = payload
        .get("review")
        .and_then(|r| r.get("user"))
        .and_then(|u| u.get("login"))
        .and_then(|l| l.as_str())
        .unwrap_or("unknown");

    let state = payload
        .get("review")
        .and_then(|r| r.get("state"))
        .and_then(|s| s.as_str())
        .unwrap_or("unknown");

    let review_comment = payload
        .get("review")
        .and_then(|r| r.get("body"))
        .and_then(|b| b.as_str());

    info!(
        "Review {} by {} for PR #{} in {}",
        state, reviewer, pr_number, repo_name
    );

    // Store full review record with comment
    match database
        .store_review(repo_name, pr_number as i32, reviewer, state, review_comment)
        .await
    {
        Ok(_) => {
            info!("Review stored for PR #{} by {}", pr_number, reviewer);

            // Log governance event
            let _ = database
                .log_governance_event(
                    "review_submitted",
                    Some(repo_name),
                    Some(pr_number as i32),
                    Some(reviewer),
                    &serde_json::json!({
                        "state": state,
                        "has_comment": review_comment.is_some()
                    }),
                )
                .await;

            Ok(axum::response::Json(
                serde_json::json!({"status": "review_stored"}),
            ))
        }
        Err(e) => {
            warn!("Failed to store review: {}", e);
            Err(axum::http::StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

/// Check if review state is valid
pub fn is_valid_review_state(state: &str) -> bool {
    matches!(
        state,
        "approved" | "changes_requested" | "commented" | "dismissed"
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_is_valid_review_state_approved() {
        assert!(is_valid_review_state("approved"));
    }

    #[test]
    fn test_is_valid_review_state_changes_requested() {
        assert!(is_valid_review_state("changes_requested"));
    }

    #[test]
    fn test_is_valid_review_state_commented() {
        assert!(is_valid_review_state("commented"));
    }

    #[test]
    fn test_is_valid_review_state_dismissed() {
        assert!(is_valid_review_state("dismissed"));
    }

    #[test]
    fn test_is_valid_review_state_invalid() {
        assert!(!is_valid_review_state("invalid"));
        assert!(!is_valid_review_state(""));
    }
}
