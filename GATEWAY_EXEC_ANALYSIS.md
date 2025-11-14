# Análise: O que falta para usar o modo Exec pelo Gateway

## Status Atual

### Gateway Atual
O gateway implementa:
- ✅ JSON-RPC handler em `handlers/jsonrpc.rs`
- ✅ `CodexService` que integra com `ConversationManager`
- ✅ Método `conversation.prompt` que chama `execute_prompt()`
- ✅ Processamento direto via `Op::UserTurn`
- ✅ WebSocket para comunicação em tempo real
- ✅ Webhook handler
- ✅ Health check

### Codex Exec (`codex-rs/exec`)
O modo exec fornece:
- ✅ CLI completa com múltiplas opções (`exec/src/cli.rs`)
- ✅ Função `run_main()` que é o entry point
- ✅ Suporte a imagens (`--image`)
- ✅ Output schema (`--output-schema`)
- ✅ JSON mode (`--json`) para saída JSONL
- ✅ Modos de sandbox (`--sandbox`)
- ✅ Full auto mode (`--full-auto`)
- ✅ Resume de conversas
- ✅ Event processors (human e JSON)
- ✅ Leitura de stdin
- ✅ Escrita em arquivo (`--output-last-message`)

## Diferenças Críticas

### CodexService vs codex_exec

| Aspecto | CodexService (Gateway) | codex_exec |
|---------|----------------------|------------|
| **Entry Point** | `execute_prompt()` | `run_main(cli: Cli)` |
| **Input** | String (prompt apenas) | CLI struct completa |
| **Imagens** | ❌ Não suporta | ✅ Suporta via `--image` |
| **Output** | JSON estruturado | JSONL stream ou human-readable |
| **Streaming** | Interno, não exposto | Via stdout |
| **Session** | Gerenciado internamente | Pode resumir via conversation_id |
| **Sandbox** | Usa config padrão | Configurável via CLI |
| **Output Schema** | ❌ Não suporta | ✅ Suporta validação JSON |
| **Event Processing** | Custom no service | EventProcessor dedicated |

### Fluxo CodexService (Atual)
```
HTTP Request → JSON-RPC → execute_prompt() → Op::UserTurn → Events → JSON Response
```

### Fluxo codex_exec (Desejado)
```
HTTP Request → Exec Handler → run_main(Cli) → EventProcessor → JSONL Stream → Response
```

## O que está faltando

### 1. Handler Específico para Exec ❌

**Arquivo:** `codex-rs/gateway/src/handlers/exec.rs` (NÃO EXISTE)

```rust
// Necessário criar
pub async fn handle_exec(
    State(state): State<AppState>,
    Json(request): Json<ExecRequest>,
) -> GatewayResult<Response> {
    // Converter HTTP request para Cli struct
    // Chamar codex_exec::run_main()
    // Capturar stdout/stderr
    // Retornar response
}
```

### 2. Estrutura de Request/Response para Exec ❌

**Necessário em:** `codex-rs/gateway/src/handlers/exec.rs`

```rust
#[derive(Debug, Deserialize)]
pub struct ExecRequest {
    pub prompt: String,
    pub images: Option<Vec<String>>,      // base64 ou URLs
    pub model: Option<String>,
    pub sandbox_mode: Option<String>,
    pub output_schema: Option<Value>,
    pub json_mode: bool,
    pub full_auto: bool,
    pub cwd: Option<String>,
    pub session_id: Option<String>,       // Para resume
}

#[derive(Debug, Serialize)]
pub struct ExecResponse {
    pub conversation_id: String,
    pub events: Vec<Value>,               // JSONL events
    pub last_message: Option<String>,
    pub status: String,
}
```

### 3. Rota para Exec no Router ❌

**Arquivo:** `codex-rs/gateway/src/router.rs`

```rust
// Adicionar:
.route("/exec", post(handle_exec))

// OU adicionar método JSON-RPC:
"exec" => process_exec(codex_service, &request).await
```

### 4. Integração com codex_exec ❌

**Problema:** O gateway precisa chamar `codex_exec::run_main()` mas:
- ✅ `codex_exec` já está como dependência no `Cargo.toml`?
- ❌ Precisa adicionar se não estiver
- ❌ Precisa adaptação de I/O (stdin/stdout → memória)
- ❌ Precisa captura de eventos em real-time

### 5. Captura de stdout/stderr ❌

**Necessário:** Interceptar a saída de `run_main()` que normalmente vai para stdout/stderr

```rust
// Exemplo de captura necessária
use std::io::Write;
use std::sync::Arc;
use tokio::sync::Mutex;

struct CapturedOutput {
    stdout: Arc<Mutex<Vec<u8>>>,
    stderr: Arc<Mutex<Vec<u8>>>,
}

// Redirecionar stdout durante run_main()
```

### 6. Conversão de Parâmetros HTTP → CLI ❌

**Necessário:** Função para converter `ExecRequest` → `codex_exec::Cli`

```rust
fn request_to_cli(req: ExecRequest) -> codex_exec::Cli {
    codex_exec::Cli {
        command: None,
        images: req.images.unwrap_or_default()
            .into_iter()
            .map(|img| decode_image(img))
            .collect(),
        model: req.model,
        prompt: Some(req.prompt),
        json: req.json_mode,
        full_auto: req.full_auto,
        sandbox_mode: req.sandbox_mode.map(parse_sandbox),
        // ... outros campos
    }
}
```

### 7. Streaming de Eventos ❌

**Desejado:** Retornar eventos em tempo real via WebSocket

```rust
// Possível implementação
pub async fn handle_exec_stream(
    ws: WebSocketUpgrade,
    State(state): State<AppState>,
) -> impl IntoResponse {
    ws.on_upgrade(|socket| exec_stream_handler(socket, state))
}

async fn exec_stream_handler(
    mut socket: WebSocket,
    state: AppState,
) {
    // Processar exec e enviar eventos via WebSocket
    // socket.send(Message::Text(event_json)).await
}
```

### 8. Suporte a Imagens ❌

**Necessário:**
- Endpoint para upload de imagens
- Armazenamento temporário (blob storage ou memória)
- Conversão base64 → PathBuf para CLI

### 9. Output Schema Validation ❌

**Necessário:**
- Receber JSON Schema no request
- Passar para `run_main()`
- Validar resposta final

### 10. Resume de Sessões ❌

**Parcialmente implementado:**
- ✅ Gateway tem mapeamento session_id → conversation_id
- ❌ Falta integração com `Command::Resume` do exec

## Dependências a Adicionar

### Cargo.toml do Gateway
```toml
[dependencies]
codex_exec = { path = "../exec" }
base64 = "0.21"
tempfile = "3.8"  # Para armazenar imagens temporárias
```

## Proposta de Implementação

### Fase 1: Handler Básico
1. Criar `handlers/exec.rs`
2. Implementar `ExecRequest` e `ExecResponse`
3. Adicionar rota `/exec`
4. Implementar conversão básica para CLI

### Fase 2: Captura de Output
1. Implementar captura de stdout/stderr
2. Processar JSONL events
3. Retornar response estruturado

### Fase 3: Features Avançadas
1. Suporte a imagens (upload + storage)
2. Output schema validation
3. Resume de sessões
4. Streaming via WebSocket

### Fase 4: JSON-RPC Integration
1. Adicionar método `exec` ao JSON-RPC
2. Manter compatibilidade com `conversation.prompt`
3. Documentar diferenças

## Comparação de Endpoints

### Endpoint `/jsonrpc` (Atual)
```json
{
  "jsonrpc": "2.0",
  "method": "conversation.prompt",
  "params": {
    "prompt": "create hello world",
    "session_id": "test"
  },
  "id": 1
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "type": "ai_response",
    "conversation_id": "conv_123",
    "content": "I'll create a hello world script...",
    "events": [...]
  },
  "id": 1
}
```

### Endpoint `/exec` (Proposto)
```json
{
  "prompt": "create hello world",
  "images": ["data:image/png;base64,..."],
  "model": "claude-3-sonnet",
  "json_mode": true,
  "full_auto": true,
  "output_schema": {
    "type": "object",
    "properties": {
      "script": { "type": "string" }
    }
  }
}
```

**Response (JSON mode):**
```json
{
  "conversation_id": "conv_123",
  "events": [
    {"type": "agent_message", "message": "Creating script..."},
    {"type": "tool_use", "tool": "write_file", "args": {...}},
    {"type": "task_complete", "last_message": "Done!"}
  ],
  "last_message": "I've created the hello world script",
  "status": "completed"
}
```

## Arquitetura Proposta

```
┌─────────────────────────────────────────────┐
│           Gateway (Port 8080)               │
├─────────────────────────────────────────────┤
│                                             │
│  /health      ─→ health_check()            │
│  /jsonrpc     ─→ handle_jsonrpc()          │
│  /ws          ─→ handle_websocket()        │
│  /webhook     ─→ handle_webhook()          │
│  /exec        ─→ handle_exec()       ⬅ NOVO│
│  /exec/stream ─→ handle_exec_stream() ⬅ NOVO│
│                                             │
└────────────┬────────────────────────────────┘
             │
    ┌────────┴────────┐
    │                 │
    ▼                 ▼
┌──────────┐    ┌────────────┐
│CodexService   │ExecService │ ⬅ NOVO
│             │  │            │
│Op::UserTurn│  │run_main()  │
└──────────┘    └────────────┘
```

## Próximos Passos

### Imediato (enquanto builda no GCP)
1. ✅ Análise completa (este documento)
2. ⏳ Criar `handlers/exec.rs` skeleton
3. ⏳ Adicionar `codex_exec` como dependência
4. ⏳ Implementar conversão básica `ExecRequest` → `Cli`

### Curto Prazo
5. ⏳ Implementar captura de stdout
6. ⏳ Testar handler básico
7. ⏳ Adicionar rota ao router

### Médio Prazo
8. ⏳ Suporte a imagens
9. ⏳ Output schema
10. ⏳ Streaming WebSocket

## Notas Importantes

1. **Isolamento**: O `CodexService` atual deve continuar funcionando para compatibilidade
2. **Streaming**: O exec precisa de streaming real-time, diferente do batch atual
3. **Segurança**: Validar todos os inputs, especialmente imagens e schemas
4. **Performance**: Captura de stdout pode ter overhead, considerar buffering
5. **Estado**: Resume requer persistência do conversation_id

## Conclusão

**Status:** ❌ Modo exec NÃO está disponível no gateway

**Esforço Estimado:**
- Handler básico: 2-4 horas
- Captura de output: 2-3 horas
- Features completas: 1-2 dias
- Testes + docs: 4-8 horas

**Bloqueadores:**
- Nenhum bloqueador técnico
- Apenas implementação necessária

**Recomendação:**
Implementar em fases, começando com handler básico e expandindo gradualmente.
