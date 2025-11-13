//! API Key Authentication Middleware
//!
//! This middleware validates API keys from the X-API-Key header
//! and implements rate limiting per key.

use axum::extract::Request;
use axum::http::StatusCode;
use axum::middleware::Next;
use axum::response::IntoResponse;
use axum::response::Response;
use serde::Deserialize;
use serde::Serialize;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::debug;
use tracing::warn;

/// API Key validation result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiKeyInfo {
    /// The API key identifier
    pub key_id: String,
    /// User/account associated with this key
    pub user_id: String,
    /// Rate limit (requests per minute)
    pub rate_limit: u32,
    /// Whether the key is active
    pub active: bool,
}

/// Simple in-memory API key store
/// In production, this would be backed by Firestore or another database
#[derive(Debug, Clone)]
pub struct ApiKeyStore {
    keys: Arc<RwLock<HashMap<String, ApiKeyInfo>>>,
}

impl ApiKeyStore {
    /// Create a new API key store
    pub fn new() -> Self {
        Self {
            keys: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Add an API key to the store
    pub async fn add_key(&self, api_key: String, info: ApiKeyInfo) {
        let mut keys = self.keys.write().await;
        keys.insert(api_key, info);
    }

    /// Validate an API key
    pub async fn validate_key(&self, api_key: &str) -> Option<ApiKeyInfo> {
        let keys = self.keys.read().await;
        keys.get(api_key).cloned()
    }

    /// Initialize with default keys for testing
    /// In production, keys would be loaded from Firestore
    pub async fn with_default_keys() -> Self {
        let store = Self::new();

        // Add a default test key
        store
            .add_key(
                "test-key-12345".to_string(),
                ApiKeyInfo {
                    key_id: "key_001".to_string(),
                    user_id: "user_test".to_string(),
                    rate_limit: 100,
                    active: true,
                },
            )
            .await;

        // Add production keys from environment if available
        if let Ok(gateway_key) = std::env::var("GATEWAY_API_KEY") {
            store
                .add_key(
                    gateway_key,
                    ApiKeyInfo {
                        key_id: "key_gateway".to_string(),
                        user_id: "gateway_internal".to_string(),
                        rate_limit: 10000, // Higher limit for internal use
                        active: true,
                    },
                )
                .await;
        }

        store
    }
}

impl Default for ApiKeyStore {
    fn default() -> Self {
        Self::new()
    }
}

/// API Key Authentication middleware
#[derive(Debug, Clone)]
pub struct ApiKeyAuth {
    store: ApiKeyStore,
    /// Paths that don't require authentication
    pub exempt_paths: Vec<String>,
}

impl ApiKeyAuth {
    /// Create a new API key auth middleware
    pub fn new(store: ApiKeyStore) -> Self {
        Self {
            store,
            exempt_paths: vec![
                "/health".to_string(),
                "/metrics".to_string(),
                "/ready".to_string(),
            ],
        }
    }

    /// Create with default configuration
    pub async fn default_config() -> Self {
        Self::new(ApiKeyStore::with_default_keys().await)
    }

    /// Check if a path is exempt from authentication
    fn is_exempt_path(&self, path: &str) -> bool {
        self.exempt_paths.iter().any(|p| path.starts_with(p))
    }
}

/// Middleware function for API key authentication
pub async fn api_key_middleware(
    auth: Arc<ApiKeyAuth>,
    request: Request,
    next: Next,
) -> Result<Response, impl IntoResponse> {
    let path = request.uri().path();

    // Skip authentication for exempt paths
    if auth.is_exempt_path(path) {
        debug!("Path {} is exempt from authentication", path);
        return Ok(next.run(request).await);
    }

    // Extract API key from X-API-Key header
    let api_key = request
        .headers()
        .get("X-API-Key")
        .and_then(|h| h.to_str().ok());

    let api_key = match api_key {
        Some(key) => key,
        None => {
            warn!("Missing X-API-Key header for path: {}", path);
            return Err((
                StatusCode::UNAUTHORIZED,
                "Missing X-API-Key header. Please provide a valid API key.",
            ));
        }
    };

    // Validate the API key
    match auth.store.validate_key(api_key).await {
        Some(key_info) if key_info.active => {
            debug!(
                "API key validated: key_id={}, user_id={}, path={}",
                key_info.key_id, key_info.user_id, path
            );

            // TODO: Implement rate limiting here
            // For now, we just validate the key exists and is active

            // Continue with the request
            Ok(next.run(request).await)
        }
        Some(key_info) => {
            warn!(
                "Inactive API key attempted: key_id={}, user_id={}",
                key_info.key_id, key_info.user_id
            );
            Err((StatusCode::FORBIDDEN, "API key is inactive"))
        }
        None => {
            warn!("Invalid API key attempted for path: {}", path);
            Err((StatusCode::UNAUTHORIZED, "Invalid API key"))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_api_key_store() {
        let store = ApiKeyStore::new();

        // Add a test key
        store
            .add_key(
                "test-key".to_string(),
                ApiKeyInfo {
                    key_id: "key_001".to_string(),
                    user_id: "user_test".to_string(),
                    rate_limit: 100,
                    active: true,
                },
            )
            .await;

        // Validate the key
        let info = store.validate_key("test-key").await;
        assert!(info.is_some());
        assert_eq!(info.unwrap().key_id, "key_001");

        // Invalid key
        let info = store.validate_key("invalid-key").await;
        assert!(info.is_none());
    }

    #[tokio::test]
    async fn test_exempt_paths() {
        let auth = ApiKeyAuth::default_config().await;

        assert!(auth.is_exempt_path("/health"));
        assert!(auth.is_exempt_path("/health/ready"));
        assert!(auth.is_exempt_path("/metrics"));
        assert!(!auth.is_exempt_path("/jsonrpc"));
        assert!(!auth.is_exempt_path("/ws"));
    }
}
