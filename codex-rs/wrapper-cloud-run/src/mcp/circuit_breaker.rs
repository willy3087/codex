//! Circuit breaker simples para MCP Gateway

use std::time::{Instant, Duration};

pub struct CircuitBreaker {
    failure_count: usize,
    last_failure_time: Option<Instant>,
    state: CircuitState,
}

#[derive(PartialEq, Eq)]
enum CircuitState {
    Closed,
    Open,
    HalfOpen,
}

impl CircuitBreaker {
    pub fn new() -> Self {
        Self {
            failure_count: 0,
            last_failure_time: None,
            state: CircuitState::Closed,
        }
    }

    pub fn is_open(&self) -> bool {
        match self.state {
            CircuitState::Open => {
                if let Some(last) = self.last_failure_time {
                    if last.elapsed() > Duration::from_secs(30) {
                        // Tenta fechar o circuito após 30s
                        false
                    } else {
                        true
                    }
                } else {
                    false
                }
            }
            _ => false,
        }
    }

    pub fn record_failure(&mut self) {
        self.failure_count += 1;
        self.last_failure_time = Some(Instant::now());
        if self.failure_count >= 3 {
            self.state = CircuitState::Open;
        }
    }

    pub fn record_success(&mut self) {
        self.failure_count = 0;
        self.state = CircuitState::Closed;
    }
}