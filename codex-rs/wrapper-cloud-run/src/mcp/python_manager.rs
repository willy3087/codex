//! Gerenciamento do pool de processos Python MCP embutidos

use anyhow::Context;
use anyhow::Result;
use futures::stream::Stream;
use futures::stream::StreamExt;
use std::io::BufRead;
use std::io::BufReader;
use std::io::Write;
use std::pin::Pin;
use std::process::Child;
use std::process::Command;
use std::process::Stdio;
use std::sync::Arc;
use std::sync::Mutex;
use tokio::sync::mpsc::channel;
use tokio::sync::mpsc::Receiver;
use tokio::sync::mpsc::Sender;
use tokio::task;
use tokio::time::sleep;
use tokio::time::Duration;

/// Representa um processo Python MCP embutido
pub struct PythonMcpProcess {
    child: Child,
    stdin: Arc<Mutex<std::process::ChildStdin>>,
    stdout: Arc<Mutex<BufReader<std::process::ChildStdout>>>,
}

impl PythonMcpProcess {
    /// Inicializa um novo processo Python MCP
    pub fn new(python_path: &str, script_path: &str) -> Result<Self> {
        let mut child = Command::new(python_path)
            .arg(script_path)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()
            .context("Falha ao iniciar processo Python MCP")?;

        let stdin = child
            .stdin
            .take()
            .context("Falha ao abrir stdin do processo")?;
        let stdout = child
            .stdout
            .take()
            .context("Falha ao abrir stdout do processo")?;

        Ok(Self {
            child,
            stdin: Arc::new(Mutex::new(stdin)),
            stdout: Arc::new(Mutex::new(BufReader::new(stdout))),
        })
    }

    /// Envia uma requisição MCP para o processo Python e retorna um stream de respostas
    pub async fn send_request(
        &self,
        request: String,
    ) -> Result<Pin<Box<dyn Stream<Item = Result<String>> + Send>>> {
        // Envia a requisição via stdin
        {
            let mut stdin = self.stdin.lock().unwrap();
            stdin.write_all(request.as_bytes())?;
            stdin.write_all(b"\n")?;
            stdin.flush()?;
        }

        // Cria um canal para enviar as linhas do stdout
        let (tx, rx): (Sender<Result<String>>, Receiver<Result<String>>) = channel(100);
        let stdout = self.stdout.clone();

        // Spawn uma task para ler as linhas do stdout e enviar pelo canal
        task::spawn_blocking(move || {
            let mut stdout = stdout.lock().unwrap();
            let mut line = String::new();
            loop {
                line.clear();
                match stdout.read_line(&mut line) {
                    Ok(0) => break, // EOF
                    Ok(_) => {
                        let send_res = tx.blocking_send(Ok(line.trim_end().to_string()));
                        if send_res.is_err() {
                            break;
                        }
                    }
                    Err(e) => {
                        let _ = tx.blocking_send(Err(anyhow::anyhow!(e)));
                        break;
                    }
                }
            }
        });

        Ok(Box::pin(tokio_stream::wrappers::ReceiverStream::new(rx)))
    }

    /// Verifica se o processo está vivo
    pub fn is_alive(&mut self) -> bool {
        match self.child.try_wait() {
            Ok(Some(_)) => false,
            Ok(None) => true,
            Err(_) => false,
        }
    }

    /// Reinicia o processo Python MCP
    pub fn restart(&mut self, python_path: &str, script_path: &str) -> Result<()> {
        // Mata o processo atual
        let _ = self.child.kill();
        // Espera o processo terminar
        let _ = self.child.wait();
        // Cria novo processo
        let new_process = PythonMcpProcess::new(python_path, script_path)?;
        *self = new_process;
        Ok(())
    }
}

/// Gerenciador do pool de processos Python MCP
pub struct PythonMcpManager {
    processes: Vec<PythonMcpProcess>,
    python_path: String,
    script_path: String,
}

impl PythonMcpManager {
    pub fn new(python_path: String, script_path: String, pool_size: usize) -> Result<Self> {
        let mut processes = Vec::with_capacity(pool_size);
        for _ in 0..pool_size {
            let proc = PythonMcpProcess::new(&python_path, &script_path)?;
            processes.push(proc);
        }
        Ok(Self {
            processes,
            python_path,
            script_path,
        })
    }

    /// Obtém um processo disponível (round-robin simples)
    pub fn get_process(&mut self) -> Option<&mut PythonMcpProcess> {
        // Para simplicidade, retorna o primeiro vivo
        self.processes.iter_mut().find(|p| p.is_alive())
    }

    /// Realiza health check e reinicia processos mortos
    pub fn health_check(&mut self) -> Result<()> {
        for proc in &mut self.processes {
            if !proc.is_alive() {
                proc.restart(&self.python_path, &self.script_path)?;
            }
        }
        Ok(())
    }
}
