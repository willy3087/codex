# Como MCP Funciona de Verdade no Codex

## ❌ O que o teste mostrou (INCORRETO)

No teste, o Codex **improvisou** e tentou usar `curl` para conectar ao MCP:

```bash
curl -sS -N -H 'Accept: text/event-stream' \
  https://mcp-pipedrive-467992722695.us-central1.run.app/sse
```

**Isso NÃO é a forma correta!** O Codex fez isso porque:
1. Não tinha ferramentas Python/Node instaladas no container
2. Tentou improvisar com curl
3. Mas MCP não é um endpoint SSE simples que você acessa com curl

---

## ✅ Como MCP Funciona REALMENTE

### 1. **MCP é um Protocolo JSON-RPC 2.0**

MCP (Model Context Protocol) usa JSON-RPC 2.0 sobre diferentes transportes:

```json
// Requisição MCP típica
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list",
  "params": {}
}

// Resposta MCP típica
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "tools": [
      {
        "name": "get_deals",
        "description": "Get deals from Pipedrive",
        "inputSchema": {...}
      }
    ]
  }
}
```

### 2. **Transportes Suportados pelo Codex**

#### A. **stdio** (Local - Padrão)
```toml
[mcp_servers.pipedrive-local]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-pipedrive"]
env = { PIPEDRIVE_API_TOKEN = "xxx" }
```

O Codex:
1. Spawna o processo MCP server
2. Envia JSON-RPC via stdin
3. Lê respostas via stdout

#### B. **WebSocket** (Remoto)
```toml
[mcp_servers.pipedrive-ws]
url = "wss://mcp-pipedrive.example.com/ws"
bearer_token = "optional-token"
```

#### C. **HTTP/SSE** (Remoto - Cloud Run)
```toml
[mcp_servers.pipedrive]
session_url = "https://mcp-pipedrive-467992722695.us-central1.run.app/sessions"
url = "https://mcp-pipedrive-467992722695.us-central1.run.app/messages/"
```

**Fluxo:**
1. **POST** `/sessions` → obtém `session_id`
2. **POST** `/messages/{session_id}` → envia JSON-RPC
3. **GET** `/messages/{session_id}` (SSE) → recebe eventos

---

## 🔧 Como o Wrapper Deveria Usar MCP

### Situação Atual

O wrapper **JÁ TEM** suporte a MCP configurado:

1. **Config existe:** [config.toml](codex-rs/wrapper-cloud-run/config.toml)
```toml
[mcp_servers.pipedrive]
session_url = "https://mcp-pipedrive-467992722695.us-central1.run.app/sessions"
url = "https://mcp-pipedrive-467992722695.us-central1.run.app/messages/"
startup_timeout_sec = 30
tool_timeout_sec = 120
```

2. **Codex tem client MCP nativo:** `rmcp-client` (Rust MCP Client)
   - [rmcp_client.rs](codex-rs/wrapper-cloud-run/rmcp-client/src/rmcp_client.rs)
   - Suporta stdio, WebSocket, HTTP/SSE
   - Implementa JSON-RPC 2.0
   - Gerencia sessões automaticamente

3. **Wrapper executa codex em modo `exec`:**
```rust
// wrapper-cloud-run/src/process.rs:273
cmd.arg("exec");
cmd.arg(&prompt);
```

---

## 🎯 Por Que Não Funcionou no Teste?

### Problema 1: Config não foi carregada

O wrapper executa:
```bash
codex exec "prompt..." --skip-git-repo-check -c sandbox_mode=danger-full-access
```

**MAS** não passa o `config.toml`!

**Solução:**
```rust
// Adicionar em process.rs:306-308
if let Ok(config_path) = env::var("CODEX_CONFIG_PATH") {
    cmd.env("CODEX_CONFIG_PATH", config_path);
}
```

E definir na implantação:
```bash
CODEX_CONFIG_PATH=/app/config.toml
```

### Problema 2: Container não tem as ferramentas

Quando Codex tenta usar MCP mas não encontra na config, ele improvisa:
1. Tenta instalar Python → **falha** (sem sudo)
2. Tenta instalar Node → **falha** (não existe)
3. Usa curl como último recurso → **não funciona** (não é assim que MCP funciona)

---

## 🚀 Como Fazer Funcionar Corretamente

### Opção 1: Passar Config Path (Mais Simples)

**1. Modificar `process.rs`:**

```rust
// Linha 306 - adicionar antes de RUST_LOG
// Passa path do config.toml para o codex encontrar MCP servers
cmd.env("CODEX_CONFIG_PATH", "/app/config.toml");
```

**2. Garantir que `config.toml` está no container:**

```dockerfile
# Dockerfile
COPY config.toml /app/config.toml
```

**3. Testar:**
```bash
# Prompt que usa MCP
curl -X POST https://wrapper-467992722695.us-central1.run.app/api/v1/exec/stream \
  -H "X-Gateway-Key: xxx" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Use the pipedrive server to list all available tools"
  }'
```

Com o config carregado, o Codex:
1. ✅ Vê que existe `mcp_servers.pipedrive` configurado
2. ✅ Usa o `rmcp_client` nativo (Rust)
3. ✅ Faz POST `/sessions` → obtém session_id
4. ✅ Faz POST `/messages/{session_id}` com JSON-RPC
5. ✅ Retorna os tools disponíveis

---

### Opção 2: Handler MCP Dedicado (Mais Robusto)

Implementar endpoint específico no wrapper:

```rust
// main.rs - adicionar rota
.route("/api/v1/mcp/list", get(mcp_list_tools_handler))
.route("/api/v1/mcp/call", post(mcp_call_tool_handler))

// mcp_handler.rs - novo arquivo
use codex_core::mcp_connection_manager::McpConnectionManager;

pub async fn mcp_list_tools_handler() -> Json<ToolsResponse> {
    let config = load_config();
    let manager = McpConnectionManager::new(&config);

    // Conecta ao pipedrive
    let client = manager.connect("pipedrive").await?;
    let tools = client.list_tools().await?;

    Json(ToolsResponse { tools })
}
```

---

## 📊 Comparação: Curl vs Codex MCP Client

| Aspecto | Curl (Errado) | Codex MCP Client (Correto) |
|---------|---------------|----------------------------|
| **Protocolo** | HTTP puro | JSON-RPC 2.0 |
| **Transporte** | Apenas HTTP | stdio/WebSocket/HTTP |
| **Sessões** | Manual | Automático |
| **Formato** | SSE simples | JSON-RPC + SSE |
| **Autenticação** | Headers | Bearer token + session |
| **Multiplexing** | ❌ | ✅ |
| **Type-safe** | ❌ | ✅ (Rust) |

---

## 🎯 Conclusão

### O teste original falhou porque:

1. ❌ **Config não foi carregado** → Codex não sabia que MCP existia
2. ❌ **Codex improvisou com curl** → Não é assim que MCP funciona
3. ❌ **MCP não respondeu ao curl** → Esperado, curl não fala JSON-RPC

### Para funcionar de verdade:

1. ✅ **Passar `CODEX_CONFIG_PATH=/app/config.toml`** no wrapper
2. ✅ **Garantir `config.toml` no container**
3. ✅ **Codex vai usar `rmcp_client` nativo** (Rust)
4. ✅ **MCP vai responder corretamente** via JSON-RPC

### Modificação necessária:

```rust
// codex-rs/wrapper-cloud-run/src/process.rs
// Linha 306, adicionar:
cmd.env("CODEX_CONFIG_PATH", "/app/config.toml");
```

Só isso resolve o problema! 🎉

---

## 📝 Próximos Passos

1. [ ] Aplicar fix no `process.rs`
2. [ ] Rebuild e redeploy do wrapper
3. [ ] Executar teste novamente
4. [ ] Verificar nos logs: `INFO codex_core::mcp_connection_manager: Connected to MCP server: pipedrive`
5. [ ] Sucesso! 🎉
