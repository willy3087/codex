# 🌩️ Codex Cloud CLI - Deploy Completo

## ✅ Modificações Implementadas

### 1. **cloud-cli agora executa EXCLUSIVAMENTE via Cloud Run**

**Arquivo modificado:** `cloud-cli/src/main.rs`

```rust
Some(Subcommand::Exec(mut exec_cli)) => {
    // 🌩️ CLOUD-CLI: Executar remotamente via Cloud Run
    use codex_cloud_cli::cloud_client::{CloudClient, ExecRequest};
    use futures::StreamExt;

    println!("🌩️  Conectando ao Codex Cloud...");

    let client = CloudClient::new()?;
    let prompt = exec_cli.prompt.unwrap_or_default();

    let request = ExecRequest {
        prompt,
        model: None, // Usar modelo padrão do cloud (gpt-4o-mini)
        timeout_ms: Some(120000), // 2 minutos
        session_id: None,
    };

    let mut stream = client.exec_stream(request).await?;

    while let Some(event_result) = stream.next().await {
        match event_result {
            Ok(event) => {
                // Streaming de output em tempo real
                if event.event == "agent_message_delta" {
                    if let Some(delta) = event.data.get("delta").and_then(|v| v.as_str()) {
                        print!("{}", delta);
                        std::io::stdout().flush()?;
                    }
                } else if event.event == "task_complete" {
                    println!("\n✅ Tarefa concluída!");
                    break;
                } else if event.event == "error" {
                    if let Some(error) = event.data.get("message").and_then(|v| v.as_str()) {
                        eprintln!("\n❌ Erro: {}", error);
                    }
                    break;
                }
            }
            Err(e) => {
                eprintln!("❌ Erro no stream: {}", e);
                break;
            }
        }
    }
}
```

### 2. **CloudClient usa autenticação dupla**

**Arquivo modificado:** `cloud-cli/src/cloud_client.rs`

```rust
// Gateway API Key hardcoded (poderia vir de env var)
const GATEWAY_API_KEY: &str = "IxF3WoAB6IBrNJKrC/Jsr5yjt2bXHZkBSHFDBhcIVvc=";

let response = client
    .post(&url)
    .header(CONTENT_TYPE, "application/json")
    .header(AUTHORIZATION, format!("Bearer {}", self.token))  // GCP Auth
    .header("X-Gateway-Key", GATEWAY_API_KEY)                // Gateway Auth
    .json(&request)
    .send()
    .await?;
```

### 3. **Wrapper aceita autenticação via X-Gateway-Key**

**Arquivo modificado:** `wrapper-cloud-run/src/auth.rs`

```rust
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
```

---

## 🔧 Compilação

```bash
cd /Users/williamduarte/NCMproduto/codex/codex-rs

# Compilar cloud-cli
cargo build --release -p codex-cloud-cli

# Binário gerado:
./target/release/codex-cloud
```

---

## 📦 Deploy do Wrapper (Pendente)

⚠️ **Ação necessária:** Fazer deploy manual do wrapper atualizado

### Opção 1: Via gcloud (problemas com Python)

```bash
cd /Users/williamduarte/NCMproduto/codex/codex-rs/wrapper-cloud-run

# Build da imagem
gcloud builds submit --tag us-central1-docker.pkg.dev/elaihub-prod/codex-wrapper/wrapper:latest --project=elaihub-prod

# Deploy no Cloud Run
gcloud run deploy codex-wrapper \
  --image us-central1-docker.pkg.dev/elaihub-prod/codex-wrapper/wrapper:latest \
  --region us-central1 \
  --project elaihub-prod
```

### Opção 2: Via Console (Recomendado)

1. Acessar https://console.cloud.google.com/run/detail/us-central1/codex-wrapper?project=elaihub-prod
2. Clicar em **EDIT & DEPLOY NEW REVISION**
3. Selecionar imagem: `us-central1-docker.pkg.dev/elaihub-prod/codex-wrapper/wrapper:latest`
4. Clicar em **DEPLOY**

---

## 🚀 Como Usar

### Teste Local → Cloud

```bash
# Executar comando via cloud
./target/release/codex-cloud exec "Liste os últimos 5 negócios do Pipedrive mostrando título e valor"

# Output esperado:
🌩️  Conectando ao Codex Cloud...
[streaming da resposta do agente em tempo real]
✅ Tarefa concluída!
```

### Instalar Globalmente

```bash
# Copiar para PATH
sudo cp ./target/release/codex-cloud /usr/local/bin/

# Usar de qualquer lugar
codex-cloud exec "Qual é a capital do Brasil?"
```

---

## 🔐 Autenticação

### Fluxo de Autenticação

```
┌─────────────────────────────────────────┐
│  codex-cloud exec "prompt"              │
└─────────────┬───────────────────────────┘
              │
              ▼
    ┌─────────────────────────┐
    │  CloudClient::new()      │
    │  - gcloud auth print-... │
    └─────────┬────────────────┘
              │
              ▼
    ┌──────────────────────────────────────┐
    │  POST /api/v1/exec/stream            │
    │  Authorization: Bearer <GCP_TOKEN>   │
    │  X-Gateway-Key: <GATEWAY_KEY>        │
    └─────────┬────────────────────────────┘
              │
              ▼
    ┌──────────────────────────────────────┐
    │  Cloud Run: codex-wrapper            │
    │  - Valida GCP Token (Cloud Run)      │
    │  - Valida Gateway Key (auth.rs)      │
    └─────────┬────────────────────────────┘
              │
              ▼
    ┌──────────────────────────────────────┐
    │  codex-app-server (Rust)             │
    │  - Carrega config.toml               │
    │  - Conecta MCP Pipedrive via SSE     │
    │  - Executa modelo gpt-4o-mini        │
    │  - Retorna stream SSE                │
    └──────────────────────────────────────┘
```

### Requisitos

1. **Autenticação GCP**
   ```bash
   gcloud auth login adm@nexcode.live
   ```

2. **Gateway API Key** (hardcoded no cliente)
   ```
   IxF3WoAB6IBrNJKrC/Jsr5yjt2bXHZkBSHFDBhcIVvc=
   ```

---

## 🔍 Troubleshooting

### Erro: "401 Unauthorized"

**Causa:** Wrapper ainda está com versão antiga sem suporte a `X-Gateway-Key`

**Solução:** Fazer deploy manual do wrapper atualizado via Console

### Erro: "gcloud: command not found"

**Solução:**
```bash
# macOS
brew install --cask google-cloud-sdk

# Verificar
which gcloud
```

### Erro: "Falha ao obter token do gcloud"

**Solução:**
```bash
gcloud auth login adm@nexcode.live
gcloud config set project elaihub-prod
```

---

## 📊 Integração MCP Pipedrive

### Configuração Automática

O `codex-cloud` usa o `config.toml` deployado no wrapper:

```toml
[mcp_servers.pipedrive]
url = "https://pipedrive-mcp-467992722695.us-central1.run.app/sse"
startup_timeout_sec = 30
tool_timeout_sec = 120

model = "gpt-4o-mini"
```

### 30 Ferramentas Disponíveis

- ✅ Deals (listar, criar, atualizar, deletar)
- ✅ Persons (listar, criar, atualizar, deletar)
- ✅ Organizations (listar, criar, atualizar, deletar)
- ✅ Activities (listar, criar, atualizar, deletar)
- ✅ Pipelines, Stages, Users, Products, Notes, Custom Fields

### Exemplo de Uso

```bash
codex-cloud exec "Crie um negócio no Pipedrive para a empresa ACME Corp com valor de R$ 50.000"

codex-cloud exec "Liste os últimos 10 negócios fechados este mês"

codex-cloud exec "Quantas atividades abertas eu tenho?"
```

---

## 📝 Arquivos Modificados

| Arquivo | Alteração |
|---------|-----------|
| `cloud-cli/src/main.rs` | Intercepta `Exec` e redireciona para CloudClient |
| `cloud-cli/src/lib.rs` | Adiciona módulo `cloud_client` |
| `cloud-cli/src/cloud_client.rs` | Adiciona header `X-Gateway-Key` |
| `cloud-cli/Cargo.toml` | Adiciona dependências `serde`, `reqwest`, `futures` |
| `wrapper-cloud-run/src/auth.rs` | Suporta `X-Gateway-Key` além de `Authorization` |
| `Cargo.toml` (root) | Adiciona `cloud-cli` ao workspace |

---

## 🎯 Próximos Passos

- [ ] **Fazer deploy manual do wrapper via Console** ⚠️ URGENTE
- [ ] Testar `codex-cloud exec` após deploy
- [ ] Adicionar modo interativo cloud (`codex-cloud` sem args)
- [ ] Suportar `proto` mode via cloud
- [ ] Implementar cache local de sessões
- [ ] Adicionar comando `codex-cloud status` para verificar conectividade

---

**Status:** ✅ Código pronto, aguardando deploy do wrapper
**Última atualização:** 2025-10-05
