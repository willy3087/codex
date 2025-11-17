//! OAuth 2.0 handlers for GPT Actions
//!
//! This module implements OAuth 2.0 authorization code flow for ChatGPT GPT Actions.

use axum::Json;
use axum::extract::Request;
use axum::extract::State;
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::response::Redirect;
use axum::response::Response;
use serde::Deserialize;
use serde::Serialize;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use uuid::Uuid;

use crate::state::AppState;

/// In-memory storage for OAuth tokens (in production, use Redis or database)
#[derive(Debug, Clone)]
pub struct OAuthStore {
    /// Maps authorization code -> access token
    codes: Arc<RwLock<HashMap<String, String>>>,
    /// Maps access token -> user info
    tokens: Arc<RwLock<HashMap<String, UserInfo>>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserInfo {
    pub user_id: String,
    pub email: Option<String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

impl OAuthStore {
    pub fn new() -> Self {
        Self {
            codes: Arc::new(RwLock::new(HashMap::new())),
            tokens: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    pub async fn create_authorization_code(&self, user_info: UserInfo) -> String {
        let code = Uuid::new_v4().to_string();
        let token = Uuid::new_v4().to_string();

        let mut codes = self.codes.write().await;
        let mut tokens = self.tokens.write().await;

        codes.insert(code.clone(), token.clone());
        tokens.insert(token, user_info);

        code
    }

    pub async fn exchange_code(&self, code: &str) -> Option<String> {
        let mut codes = self.codes.write().await;
        codes.remove(code)
    }

    pub async fn validate_token(&self, token: &str) -> Option<UserInfo> {
        let tokens = self.tokens.read().await;
        tokens.get(token).cloned()
    }
}

impl Default for OAuthStore {
    fn default() -> Self {
        Self::new()
    }
}

/// Query parameters for OAuth authorization endpoint
#[derive(Debug, Deserialize)]
pub struct AuthorizeQuery {
    pub client_id: String,
    pub redirect_uri: String,
    pub state: String,
    pub response_type: String,
}

/// Request body for token exchange
#[derive(Debug, Deserialize)]
pub struct TokenRequest {
    pub grant_type: String,
    pub client_id: String,
    pub client_secret: String,
    pub code: String,
    pub redirect_uri: String,
}

/// Response for token endpoint
#[derive(Debug, Serialize)]
pub struct TokenResponse {
    pub access_token: String,
    pub token_type: String,
    pub expires_in: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub refresh_token: Option<String>,
}

/// OAuth authorization endpoint
/// GET /oauth/authorize
pub async fn handle_oauth_authorize(State(_state): State<AppState>, req: Request) -> Response {
    // Extract query parameters manually
    let query = req.uri().query().unwrap_or("");
    let params: HashMap<String, String> = url::form_urlencoded::parse(query.as_bytes())
        .into_owned()
        .collect();

    // Validate parameters
    let response_type = params.get("response_type");
    let redirect_uri = params.get("redirect_uri");
    let state = params.get("state");
    let client_id = params.get("client_id");

    if response_type != Some(&"code".to_string()) {
        return (
            StatusCode::BAD_REQUEST,
            "Invalid response_type. Must be 'code'",
        )
            .into_response();
    }

    let redirect_uri = match redirect_uri {
        Some(uri) => uri,
        None => return (StatusCode::BAD_REQUEST, "Missing redirect_uri").into_response(),
    };

    let state = match state {
        Some(s) => s,
        None => return (StatusCode::BAD_REQUEST, "Missing state").into_response(),
    };

    // Validate client_id (optional but recommended)
    if client_id.is_none() {
        return (StatusCode::BAD_REQUEST, "Missing client_id").into_response();
    }

    // In a real implementation, you would:
    // 1. Show a login page
    // 2. Authenticate the user
    // 3. Ask for consent
    // 4. Generate authorization code

    // For this example, we'll auto-approve and create a dummy user
    let oauth_store = OAuthStore::new();
    let user_info = UserInfo {
        user_id: Uuid::new_v4().to_string(),
        email: Some("user@example.com".to_string()),
        created_at: chrono::Utc::now(),
    };

    let code = oauth_store.create_authorization_code(user_info).await;

    // Redirect back to ChatGPT with the code
    let redirect_url = format!("{redirect_uri}?code={code}&state={state}");

    Redirect::to(&redirect_url).into_response()
}

/// OAuth token endpoint
/// POST /oauth/token
pub async fn handle_oauth_token(
    State(_state): State<AppState>,
    Json(request): Json<TokenRequest>,
) -> Response {
    // Validate grant type
    if request.grant_type != "authorization_code" {
        return (
            StatusCode::BAD_REQUEST,
            Json(serde_json::json!({
                "error": "unsupported_grant_type",
                "error_description": "Only authorization_code is supported"
            })),
        )
            .into_response();
    }

    // Validate client credentials
    // In production, verify client_id and client_secret against your database
    let valid_client_id =
        std::env::var("OAUTH_CLIENT_ID").unwrap_or_else(|_| "codex-gateway-client".to_string());
    let valid_client_secret =
        std::env::var("OAUTH_CLIENT_SECRET").unwrap_or_else(|_| "secret-key-here".to_string());

    if request.client_id != valid_client_id || request.client_secret != valid_client_secret {
        return (
            StatusCode::UNAUTHORIZED,
            Json(serde_json::json!({
                "error": "invalid_client",
                "error_description": "Invalid client credentials"
            })),
        )
            .into_response();
    }

    // Exchange code for token
    let oauth_store = OAuthStore::new();
    let access_token = match oauth_store.exchange_code(&request.code).await {
        Some(token) => token,
        None => {
            return (
                StatusCode::BAD_REQUEST,
                Json(serde_json::json!({
                    "error": "invalid_grant",
                    "error_description": "Invalid or expired authorization code"
                })),
            )
                .into_response();
        }
    };

    // Return token response
    let response = TokenResponse {
        access_token,
        token_type: "bearer".to_string(),
        expires_in: 3600, // 1 hour
        refresh_token: None,
    };

    (StatusCode::OK, Json(response)).into_response()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_oauth_store() {
        let store = OAuthStore::new();

        let user_info = UserInfo {
            user_id: "test-user".to_string(),
            email: Some("test@example.com".to_string()),
            created_at: chrono::Utc::now(),
        };

        let code = store.create_authorization_code(user_info.clone()).await;
        let token = store.exchange_code(&code).await.unwrap();

        let retrieved = store.validate_token(&token).await.unwrap();
        assert_eq!(retrieved.user_id, "test-user");
    }
}
