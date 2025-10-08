//! Middleware de autenticação para o wrapper Cloud Run

use axum::extract::Request;
use axum::http::StatusCode;
use axum::middleware::Next;
use axum::response::Response;
use std::env;

/// Middleware que valida API Key via header Authorization: Bearer <token>
pub async fn auth_middleware(request: Request, next: Next) -> Result<Response, StatusCode> {
    // Se GATEWAY_API_KEY não estiver definida, permite acesso (modo desenvolvimento)
    let required_key = match env::var("GATEWAY_API_KEY") {
        Ok(key) if !key.is_empty() => key,
        _ => {
            tracing::warn!("GATEWAY_API_KEY not set - authentication disabled (dev mode)");
            return Ok(next.run(request).await);
        }
    };

    // Extrai o token do header X-Gateway-Key OU Authorization (compatibilidade)
    let gateway_key = request
        .headers()
        .get("X-Gateway-Key")
        .and_then(|h| h.to_str().ok());

    let auth_header = request
        .headers()
        .get("Authorization")
        .and_then(|h| h.to_str().ok());

    // Prioriza X-Gateway-Key, depois Authorization
    let provided_key = if let Some(key) = gateway_key {
        Some(key.to_string())
    } else if let Some(header) = auth_header {
        if header.starts_with("Bearer ") {
            Some(header.trim_start_matches("Bearer ").to_string())
        } else {
            None
        }
    } else {
        None
    };

    match provided_key {
        Some(key) if key == required_key => Ok(next.run(request).await),
        Some(_) => {
            tracing::warn!("Invalid API key provided");
            Err(StatusCode::UNAUTHORIZED)
        }
        None => {
            tracing::warn!("Missing X-Gateway-Key or Authorization header");
            Err(StatusCode::UNAUTHORIZED)
        }
    }
}
