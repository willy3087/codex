# Codex Gateway

Gateway HTTP/WebSocket completo para o Codex-RS com suporte a múltiplos protocolos e autenticação OAuth 2.0.

## 📋 Índice

- [Recursos](#recursos)
- [Arquitetura](#arquitetura)
- [Configuração](#configuração)
- [Deployment](#deployment)
- [Endpoints](#endpoints)
- [Autenticação](#autenticação)
- [Desenvolvimento](#desenvolvimento)

## 🚀 Recursos

- **Integração OpenAI GPT-4o**: Usando Chat Completions API
- **OAuth 2.0**: Para ChatGPT GPT Actions
- **API Key Authentication**: Proteção de endpoints
- **Múltiplos Protocolos**:
  - JSON-RPC 2.0
  - WebSocket
  - Exec Mode (JSONL streaming)
  - Webhook
- **Health Checks**: Monitoramento de saúde
- **CORS**: Configurado para acesso cross-origin
- **Rate Limiting**: Controle de taxa por API key

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────┐
│   Client (Browser / CLI / ChatGPT)     │
└──────────────┬──────────────────────────┘
               │ HTTPS/WSS
┌──────────────▼──────────────────────────┐
│         Codex Gateway                   │
│  ┌────────────────────────────────┐     │
│  │   Router & Middleware          │     │
│  ├────────────────────────────────┤     │
│  │ • API Key Auth                 │     │
│  │ • OAuth 2.0                    │     │
│  │ • CORS                         │     │
│  │ • Rate Limiting                │     │
│  └────────────────────────────────┘     │
│  ┌────────────────────────────────┐     │
│  │   Handlers                     │     │
│  ├────────────────────────────────┤     │
│  │ • JSON-RPC                     │     │
│  │ • WebSocket                    │     │
│  │ • Exec Mode                    │     │
│  │ • Webhook                      │     │
│  │ • OAuth                        │     │
│  └────────────────────────────────┘     │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│      Codex Core (Rust)                  │
│   • ConversationManager                 │
│   • MessageProcessor                    │
│   • Config Loader                       │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│      OpenAI API (GPT-4o)                │
└─────────────────────────────────────────┘
```

## ⚙️ Configuração

### Variáveis de Ambiente

Crie um arquivo `.env` na raiz do projeto:

```bash
# OpenAI API Configuration
OPENAI_API_KEY=sk-proj-your-key-here

# Optional: Anthropic API (se usar Claude)
ANTHROPIC_API_KEY=sk-ant-your-key-here

# Gateway Configuration
PORT=8080
RUST_LOG=info,codex_gateway=debug

# API Key Authentication
GATEWAY_API_KEY=your-secure-api-key-here

# OAuth 2.0 Configuration
OAUTH_CLIENT_ID=codex-gateway-client
OAUTH_CLIENT_SECRET=your-oauth-secret-here

# Codex Home Directory (onde config.toml está localizado)
CODEX_HOME=/home/gateway/.codex
```

### Arquivo de Configuração (config.toml)

Crie `/home/gateway/.codex/config.toml`:

```toml
model = "gpt-4o"
model_provider = "openai-chat-completions"

[model_providers.openai-chat-completions]
name = "OpenAI using Chat Completions"
base_url = "https://api.openai.com/v1"
env_key = "OPENAI_API_KEY"
wire_api = "chat"
query_params = {}
```

## 🐳 Deployment

### Docker Local

```bash
# Build
cd codex-rs/gateway
docker build -t codex-gateway -f Dockerfile ../..

# Run com volume para config
docker run -d \
  --name codex-gateway \
  -p 3000:8080 \
  --env-file .env \
  -v $(pwd)/config:/home/gateway/.codex:ro \
  codex-gateway
```

### Docker Compose

Crie `docker-compose.yml`:

```yaml
version: '3.8'

services:
  gateway:
    build:
      context: ../..
      dockerfile: codex-rs/gateway/Dockerfile
    image: codex-gateway:latest
    container_name: codex-gateway
    ports:
      - "3000:8080"
    environment:
      - PORT=8080
      - RUST_LOG=info,codex_gateway=debug
      - CODEX_HOME=/home/gateway/.codex
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - GATEWAY_API_KEY=${GATEWAY_API_KEY}
      - OAUTH_CLIENT_ID=${OAUTH_CLIENT_ID}
      - OAUTH_CLIENT_SECRET=${OAUTH_CLIENT_SECRET}
    volumes:
      - codex-home:/home/gateway/.codex
      - ./config/config.toml:/home/gateway/.codex/config.toml:ro
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 5s
    restart: unless-stopped

volumes:
  codex-home:
    driver: local
```

### Google Cloud Run

```bash
# Build e push para GCR
gcloud builds submit --tag gcr.io/PROJECT_ID/codex-gateway

# Deploy
gcloud run deploy codex-gateway \
  --image gcr.io/PROJECT_ID/codex-gateway \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars="OPENAI_API_KEY=${OPENAI_API_KEY},OAUTH_CLIENT_ID=${OAUTH_CLIENT_ID},OAUTH_CLIENT_SECRET=${OAUTH_CLIENT_SECRET}" \
  --set-secrets="GATEWAY_API_KEY=gateway-api-key:latest" \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 10
```

### Azure Container Apps

```bash
# Build e push para ACR
az acr build --registry myregistry --image codex-gateway:latest .

# Deploy
az containerapp create \
  --name codex-gateway \
  --resource-group mygroup \
  --image myregistry.azurecr.io/codex-gateway:latest \
  --target-port 8080 \
  --ingress external \
  --env-vars OPENAI_API_KEY=${OPENAI_API_KEY} \
  --secrets gateway-api-key=${GATEWAY_API_KEY} \
  --min-replicas 1 \
  --max-replicas 10
```

## 📡 Endpoints

### Health Check
```bash
GET /health
```
Resposta:
```json
{"status": "healthy"}
```

### JSON-RPC
```bash
POST /jsonrpc
Headers:
  Content-Type: application/json
  X-API-Key: your-api-key

Body:
{
  "jsonrpc": "2.0",
  "method": "conversation.prompt",
  "params": {
    "prompt": "Hello, world!",
    "conversation_id": null
  },
  "id": 1
}
```

### Exec Mode (JSONL Streaming)
```bash
POST /exec
Headers:
  Content-Type: application/json
  X-API-Key: your-api-key

Body:
{
  "prompt": "Write a hello function"
}
```

### WebSocket
```bash
GET /ws
Headers:
  Upgrade: websocket
  X-API-Key: your-api-key
```

### Webhook
```bash
POST /webhook
Headers:
  Content-Type: application/json
  X-API-Key: your-api-key

Body:
{
  "event": "test",
  "data": {"message": "Hello"}
}
```

### OAuth 2.0

#### Authorization
```bash
GET /oauth/authorize?response_type=code&client_id=CLIENT_ID&redirect_uri=REDIRECT_URI&state=STATE
```

#### Token Exchange
```bash
POST /oauth/token
Content-Type: application/json

{
  "grant_type": "authorization_code",
  "client_id": "CLIENT_ID",
  "client_secret": "CLIENT_SECRET",
  "code": "AUTH_CODE",
  "redirect_uri": "REDIRECT_URI"
}
```

## 🔐 Autenticação

### API Key Authentication

Todos os endpoints (exceto `/health` e OAuth) requerem API key:

```bash
curl -H "X-API-Key: your-api-key" http://localhost:3000/jsonrpc
```

### OAuth 2.0 para ChatGPT GPT Actions

1. Configure no ChatGPT GPT:
   - Authorization URL: `https://your-domain.com/oauth/authorize`
   - Token URL: `https://your-domain.com/oauth/token`
   - Client ID: `codex-gateway-client`
   - Client Secret: (do `.env`)

2. O fluxo OAuth será:
   - ChatGPT redireciona usuário para `/oauth/authorize`
   - Gateway auto-aprova e gera código
   - ChatGPT troca código por token em `/oauth/token`
   - ChatGPT usa token para fazer chamadas autenticadas

Para produção, substitua o `OAuthStore` in-memory por Redis ou banco de dados.

## 🛠️ Desenvolvimento

### Build Local

```bash
cargo build --package codex-gateway
```

### Executar Localmente

```bash
# Com config.toml em ~/.codex/
export OPENAI_API_KEY=sk-proj-...
export CODEX_HOME=$HOME/.codex
cargo run --package codex-gateway

# Ou com caminho customizado
export CODEX_HOME=/custom/path/.codex
cargo run --package codex-gateway
```

### Testes

```bash
# Unit tests
cargo test --package codex-gateway

# Integration tests
cargo test --package codex-gateway --test integration

# Test específico
cargo test --package codex-gateway test_health_check
```

### Scripts de Teste

```bash
# Testar todos os endpoints
./scripts/test_gateway.sh

# Testar OAuth
./scripts/test_oauth.sh

# Deploy e testar
./scripts/deploy_oauth_gateway.sh
```

## 📊 Monitoramento

### Logs

```bash
# Docker
docker logs -f codex-gateway

# Cloud Run
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=codex-gateway" --limit 100

# Azure
az monitor log-analytics query \
  --workspace myworkspace \
  --analytics-query "ContainerAppConsoleLogs_CL | where ContainerName_s == 'codex-gateway'"
```

### Métricas

O gateway emite eventos OpenTelemetry:
- `codex.conversation_starts`
- `codex.user_prompt`
- `codex.api_request`
- `codex.sse_event`

## 🔧 Troubleshooting

### Erro: Permission denied ao criar sessão

**Problema**: `failed to initialize rollout recorder: Permission denied`

**Solução**: Certifique-se que o volume `CODEX_HOME` tem permissões de escrita:
```bash
docker run -v codex-home:/home/gateway/.codex ...
```

### Erro: 401 Unauthorized do OpenAI

**Problema**: Config não está sendo lida ou API key inválida

**Solução**:
1. Verifique se `config.toml` existe em `$CODEX_HOME`
2. Verifique se `CODEX_HOME` está definido
3. Valide API key: `echo $OPENAI_API_KEY`

### Erro: Invalid API key

**Problema**: `X-API-Key` header inválido ou ausente

**Solução**:
1. Certifique-se de incluir header: `-H "X-API-Key: your-key"`
2. Verifique se a key está em `.env` ou env vars

## 📝 Estrutura do Projeto

```
gateway/
├── Dockerfile              # Multi-stage Docker build
├── README.md              # Esta documentação
├── commad.md              # Comandos e exemplos
├── Cargo.toml             # Dependências Rust
├── src/
│   ├── main.rs            # Entry point
│   ├── config.rs          # Configuração do gateway
│   ├── error.rs           # Tipos de erro
│   ├── router.rs          # Definição de rotas
│   ├── state.rs           # Estado compartilhado
│   ├── handlers/          # Request handlers
│   │   ├── health.rs      # Health check
│   │   ├── jsonrpc.rs     # JSON-RPC handler
│   │   ├── websocket.rs   # WebSocket handler
│   │   ├── exec.rs        # Exec mode handler
│   │   ├── webhook.rs     # Webhook handler
│   │   └── oauth.rs       # OAuth 2.0 handlers
│   ├── middleware/        # Middleware
│   │   └── api_key.rs     # API key auth
│   └── services/          # Business logic
│       └── codex_service.rs  # Codex integration
└── tests/                 # Integration tests
```

## 🤝 Contribuindo

1. Fork o projeto
2. Crie uma branch: `git checkout -b feature/nova-funcionalidade`
3. Commit: `git commit -am 'Add nova funcionalidade'`
4. Push: `git push origin feature/nova-funcionalidade`
5. Abra um Pull Request

## 📄 Licença

Este projeto é parte do Codex-RS e segue a mesma licença.

## 🔗 Links

- [Documentação Codex](https://docs.openai.com/codex)
- [OpenAI API](https://platform.openai.com/docs)
- [ChatGPT GPT Actions](https://platform.openai.com/docs/actions)
- [OAuth 2.0 Spec](https://oauth.net/2/)
