# Configuração OAuth para ChatGPT GPT Actions

## 📋 Visão Geral

O gateway Codex agora suporta autenticação OAuth 2.0 para integração com ChatGPT GPT Actions.

## 🔧 Endpoints OAuth

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/oauth/authorize` | GET | Autorização do usuário |
| `/oauth/token` | POST | Troca de código por token |

## 🚀 Configuração no ChatGPT GPT Builder

### 1. Configurar Authentication

No GPT Builder, selecione:

```
Authentication Type: OAuth
OAuth Type: Authorization Code
```

### 2. Configurar Client Credentials

```yaml
Client ID: codex-gateway-client
Client Secret: secret-key-here
```

**IMPORTANTE**: Configure estas variáveis de ambiente no container:
```bash
OAUTH_CLIENT_ID=codex-gateway-client
OAUTH_CLIENT_SECRET=seu-secret-aqui
```

### 3. Configurar OAuth Endpoints

```yaml
Authorization URL: https://SEU-SERVIDOR/oauth/authorize
Token URL: https://SEU-SERVIDOR/oauth/token
Scope: (deixe vazio ou use: read write)
```

### 4. Callback URLs

O ChatGPT usará automaticamente estas URLs de callback:
```
https://chat.openai.com/aip/g-YOUR-GPT-ID/oauth/callback
https://chatgpt.com/aip/g-YOUR-GPT-ID/oauth/callback
```

**Não é necessário configurar no servidor** - o gateway aceita qualquer callback.

## 📝 Exemplo de Fluxo OAuth

### Passo 1: Autorização

O usuário clica em "Sign in" no ChatGPT:

```http
GET /oauth/authorize?
  response_type=code&
  client_id=codex-gateway-client&
  redirect_uri=https://chatgpt.com/aip/g-XXX/oauth/callback&
  state=oauth_s_abc123
```

### Passo 2: Gateway Retorna Código

```http
HTTP/1.1 302 Found
Location: https://chatgpt.com/aip/g-XXX/oauth/callback?
  code=0cfb8e8a409583396db8&
  state=oauth_s_abc123
```

### Passo 3: ChatGPT Troca Código por Token

```http
POST /oauth/token
Content-Type: application/json

{
  "grant_type": "authorization_code",
  "client_id": "codex-gateway-client",
  "client_secret": "secret-key-here",
  "code": "0cfb8e8a409583396db8",
  "redirect_uri": "https://chatgpt.com/aip/g-XXX/oauth/callback"
}
```

### Passo 4: Gateway Retorna Token

```json
{
  "access_token": "uuid-token-here",
  "token_type": "bearer",
  "expires_in": 3600
}
```

## 🔒 Segurança

### Variáveis de Ambiente Obrigatórias

```bash
# OAuth Credentials
OAUTH_CLIENT_ID=codex-gateway-client
OAUTH_CLIENT_SECRET=<gere-um-secret-forte>

# Gateway API Key (para endpoints não-OAuth)
GATEWAY_API_KEY=a44c72cf24f7dcd1012bf8e7a2693b9c7385981cede7b95699fc4249285fb2ff

# OpenAI API Key (para Codex funcionar)
OPENAI_API_KEY=sk-...
```

### Gerar Secret Forte

```bash
# Opção 1: OpenSSL
openssl rand -hex 32

# Opção 2: Python
python3 -c "import secrets; print(secrets.token_hex(32))"

# Opção 3: Node.js
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

## 🐳 Docker Run com OAuth

```bash
docker run -d \
  --name codex-gateway \
  -p 3000:8080 \
  --env-file /path/to/.env \
  -e RUST_LOG=info \
  -e PORT=8080 \
  -e OAUTH_CLIENT_ID=codex-gateway-client \
  -e OAUTH_CLIENT_SECRET=$(openssl rand -hex 32) \
  getway_elai
```

## 🧪 Testar OAuth Localmente

### 1. Simular Autorização

```bash
curl -v "http://localhost:3000/oauth/authorize?\
response_type=code&\
client_id=codex-gateway-client&\
redirect_uri=http://localhost:3000/callback&\
state=test123"
```

### 2. Trocar Código por Token

```bash
# Pegue o código do redirect anterior
CODE="codigo-do-passo-anterior"

curl -X POST http://localhost:3000/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "grant_type": "authorization_code",
    "client_id": "codex-gateway-client",
    "client_secret": "secret-key-here",
    "code": "'$CODE'",
    "redirect_uri": "http://localhost:3000/callback"
  }' | jq .
```

## 📊 Monitoramento

### Verificar Logs OAuth

```bash
docker logs -f codex-gateway | grep -i oauth
```

### Endpoints de Debug

```bash
# Health Check (sem auth)
curl http://localhost:3000/health

# Status (com API Key)
curl -X POST http://localhost:3000/jsonrpc \
  -H "X-API-Key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"conversation.status","params":{"session_id":"test"},"id":1}'
```

## ⚠️ Limitações Atuais

1. **Tokens em memória**: Tokens são armazenados em memória. Se o container reiniciar, todos os tokens são perdidos.
   - **Solução futura**: Redis ou banco de dados

2. **Auto-aprovação**: Atualmente auto-aprova todas as autorizações sem UI de login.
   - **Solução futura**: Implementar UI de login e consentimento

3. **Sem refresh tokens**: Tokens não podem ser renovados automaticamente.
   - **Solução futura**: Implementar refresh token flow

## 🚀 Deploy em Produção

### GCP Cloud Run

```bash
# Build e push
gcloud builds submit --tag gcr.io/PROJECT_ID/codex-gateway

# Deploy com OAuth
gcloud run deploy codex-gateway \
  --image gcr.io/PROJECT_ID/codex-gateway \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars OAUTH_CLIENT_ID=codex-gateway-client \
  --set-env-vars OAUTH_CLIENT_SECRET=$(gcloud secrets versions access latest --secret=oauth-secret)
```

### Azure Container Apps

```bash
az containerapp create \
  --name codex-gateway \
  --resource-group YOUR_RG \
  --environment YOUR_ENV \
  --image YOUR_ACR.azurecr.io/codex-gateway \
  --target-port 8080 \
  --ingress external \
  --env-vars \
    OAUTH_CLIENT_ID=codex-gateway-client \
    OAUTH_CLIENT_SECRET=secretref:oauth-secret
```

## 📚 Recursos

- [OAuth 2.0 RFC 6749](https://tools.ietf.org/html/rfc6749)
- [ChatGPT GPT Actions](https://platform.openai.com/docs/actions)
- [Axum OAuth Example](https://github.com/tokio-rs/axum/tree/main/examples/oauth)

---

**Última atualização**: 2025-01-17
**Versão**: 1.0.0
