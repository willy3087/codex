//! Gateway MCP com estratégia multi-tier fallback, circuit breaker e cache Redis

use crate::mcp::circuit_breaker::CircuitBreaker;
use crate::mcp::python_manager::PythonMcpManager;
use anyhow::Result;
use futures::stream::StreamExt;
use redis::AsyncCommands;
use std::sync::Arc;
use tokio::sync::Mutex;

pub struct McpGateway {
    python_manager: Arc<Mutex<PythonMcpManager>>,
    circuit_breaker: Arc<Mutex<CircuitBreaker>>,
    redis_client: redis::Client,
}

impl McpGateway {
    pub fn new(python_manager: PythonMcpManager, redis_url: &str) -> Result<Self> {
        let redis_client = redis::Client::open(redis_url)?;
        Ok(Self {
            python_manager: Arc::new(Mutex::new(python_manager)),
            circuit_breaker: Arc::new(Mutex::new(CircuitBreaker::new())),
            redis_client,
        })
    }

    /// Executa a requisição MCP com fallback multi-tier
    pub async fn execute(&self, request: String) -> Result<String> {
        let mut circuit = self.circuit_breaker.lock().await;

        if circuit.is_open() {
            // Circuito aberto, retorna erro ou cache
            let mut con = self.redis_client.get_async_connection().await?;
            if let Ok(cached) = con.get::<_, String>(&request).await {
                return Ok(cached);
            } else {
                anyhow::bail!("Circuit breaker aberto e cache vazio");
            }
        }

        let mut python_manager = self.python_manager.lock().await;
        if let Some(proc) = python_manager.get_process() {
            match proc.send_request(request.clone()).await {
                Ok(mut stream) => {
                    // Para simplicidade, coleta tudo do stream
                    let mut result = String::new();
                    while let Some(line) = stream.next().await {
                        match line {
                            Ok(l) => result.push_str(&l),
                            Err(e) => {
                                circuit.record_failure();
                                return Err(e);
                            }
                        }
                    }
                    circuit.record_success();

                    // Armazena no cache Redis
                    let mut con = self.redis_client.get_async_connection().await?;
                    let _: () = con.set_ex(&request, &result, 300).await?;

                    Ok(result)
                }
                Err(e) => {
                    circuit.record_failure();
                    Err(e)
                }
            }
        } else {
            circuit.record_failure();
            anyhow::bail!("Nenhum processo Python MCP disponível");
        }
    }
}
