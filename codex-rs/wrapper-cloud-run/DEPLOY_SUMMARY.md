# 🚀 Deploy Codex Wrapper com MCP Pipedrive - Resumo

## ✅ Deploy Concluído com Sucesso!

**Data:** 2025-10-04
**Serviço:** codex-wrapper
**Região:** us-central1
**Projeto:** elaihub-prod

---

## 📊 Informações do Deployment

### URLs do Serviço

```bash
# URL Principal
https://codex-wrapper-467992722695.us-central1.run.app

# Endpoints Disponíveis
/health                     # Health check (requer autenticação GCP)
/api/v1/exec/stream        # Execução streaming (requer GATEWAY_API_KEY)
```

### Autenticação

⚠️ **IMPORTANTE:** O serviço **NÃO está público** devido a políticas organizacionais do GCP.

**Para acessar o serviço:**

```bash
# 1. Obter token de autenticação GCP
TOKEN=$(gcloud auth print-identity-token)

# 2. Fazer request com token GCP + API Key do Gateway
curl -X POST https://codex-wrapper-467992722695.us-central1.run.app/api/v1/exec/stream \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Gateway-Key: IxF3WoAB6IBrNJKrC/Jsr5yjt2bXHZkBSHFDBhcIVvc=" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Liste os últimos 5 negócios do Pipedrive", "model": "gpt-4o-mini"}'
```

---

## 🔐 Secrets Configurados

| Secret Name | Descrição | Status |
|-------------|-----------|--------|
| `gateway-api-key-codex` | Chave de autenticação do gateway | ✅ Criado |
| `openai-api-key` | API key da OpenAI | ✅ Configurado |
| `pipedrive-api-token-codex` | Token da API do Pipedrive | ✅ Criado |

**Permissões concedidas para:** `codex-wrapper-sa@elaihub-prod.iam.gserviceaccount.com`

---

## ⚙️ Configuração do Serviço

### Variáveis de Ambiente

```bash
RUST_LOG=info
CODEX_CONFIG_PATH=/app/config.toml
CODEX_UNSAFE_ALLOW_NO_SANDBOX=true
GCS_SESSION_BUCKET=elaistore
GCS_FILES_BUCKET=elaistore
```

### Secrets (via Secret Manager)

```bash
GATEWAY_API_KEY=gateway-api-key-codex:latest
OPENAI_API_KEY=openai-api-key:latest
PIPEDRIVE_API_TOKEN=pipedrive-api-token-codex:latest
```

### Recursos

- **Memória:** 2 GiB
- **CPU:** 2 vCPUs
- **Timeout:** 300s (5 minutos)
- **Max Instances:** 10

---

## 🔌 Integração MCP Pipedrive

### Configuração ([config.toml](config.toml:6))

```toml
[mcp_servers.pipedrive]
url = "https://pipedrive-mcp-467992722695.us-central1.run.app/sse"
startup_timeout_sec = 30
tool_timeout_sec = 120
```

### Modelo Padrão ([config.toml](config.toml:27))

```toml
model = "gpt-4o-mini"
```

### Ferramentas Disponíveis

**30 ferramentas Pipedrive** prontas para uso via MCP:
- Deals (listar, criar, atualizar, deletar)
- Persons (listar, criar, atualizar, deletar)
- Organizations (listar, criar, atualizar, deletar)
- Activities (listar, criar, atualizar, deletar)
- Pipelines, Stages, Users, Products, Notes, Custom Fields

---

## 🏗️ Arquitetura Deployada

```
┌─────────────────────────────────────────────┐
│   Cliente (autenticado via GCP Token)       │
└─────────────┬───────────────────────────────┘
              │ HTTPS + GCP Auth + API Key
┌─────────────▼───────────────────────────────┐
│   Cloud Run: codex-wrapper                  │
│   https://codex-wrapper-*.run.app           │
│  ┌─────────────────────────────────────┐    │
│  │  Codex App Server (Rust)            │    │
│  │  ├─ MCP Connection Manager          │    │
│  │  ├─ Protocol Router                 │    │
│  │  └─ config.toml                     │    │
│  └─────────────────────────────────────┘    │
│                                              │
│  Secrets:                                    │
│  - GATEWAY_API_KEY                           │
│  - OPENAI_API_KEY                            │
│  - PIPEDRIVE_API_TOKEN                       │
└─────────────┬────────────────────────────────┘
              │ SSE/HTTPS
┌─────────────▼────────────────────────────────┐
│   Cloud Run: pipedrive-mcp                   │
│   https://pipedrive-mcp-*.run.app/sse        │
│  ┌─────────────────────────────────────┐     │
│  │  MCP Pipedrive Server               │     │
│  │  30 ferramentas disponíveis         │     │
│  └─────────────────────────────────────┘     │
└─────────────┬────────────────────────────────┘
              │ REST API
┌─────────────▼────────────────────────────────┐
│   Pipedrive API (api.pipedrive.com)          │
└──────────────────────────────────────────────┘
```

---

## 📝 Arquivos Criados/Modificados

| Arquivo | Descrição |
|---------|-----------|
| [config.toml](config.toml) | Configuração do Codex com MCP Pipedrive |
| [.env](.env:16) | Variáveis de ambiente (incluindo PIPEDRIVE_API_TOKEN) |
| [MCP_INTEGRATION.md](MCP_INTEGRATION.md) | Documentação completa da integração MCP |
| [Dockerfile](Dockerfile) | Container multi-stage com Rust 1.90 |

---

## 🧪 Como Testar

### 1. Health Check

```bash
TOKEN=$(gcloud auth print-identity-token)
curl https://codex-wrapper-467992722695.us-central1.run.app/health \
  -H "Authorization: Bearer $TOKEN"

# Resposta esperada: OK
```

### 2. Teste MCP Pipedrive

```bash
TOKEN=$(gcloud auth print-identity-token)

curl -X POST https://codex-wrapper-467992722695.us-central1.run.app/api/v1/exec/stream \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Gateway-Key: IxF3WoAB6IBrNJKrC/Jsr5yjt2bXHZkBSHFDBhcIVvc=" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Liste os últimos 5 negócios do Pipedrive com seus valores",
    "model": "gpt-4o-mini"
  }' \
  --no-buffer
```

### 3. Teste via Cliente Python

```python
import requests
import subprocess

# Obter token GCP
token = subprocess.check_output(["gcloud", "auth", "print-identity-token"]).decode().strip()

response = requests.post(
    "https://codex-wrapper-467992722695.us-central1.run.app/api/v1/exec/stream",
    headers={
        "Authorization": f"Bearer {token}",
        "X-Gateway-Key": "IxF3WoAB6IBrNJKrC/Jsr5yjt2bXHZkBSHFDBhcIVvc=",
        "Content-Type": "application/json"
    },
    json={
        "prompt": "Crie um negócio no Pipedrive para Acme Corp com valor R$ 10.000",
        "model": "gpt-4o-mini"
    },
    stream=True
)

for line in response.iter_lines():
    if line:
        print(line.decode('utf-8'))
```

---

## 🔍 Monitoramento e Logs

### Visualizar Logs

```bash
# Logs em tempo real
gcloud run services logs tail codex-wrapper \
  --region us-central1 \
  --project elaihub-prod

# Logs das últimas 2 horas
gcloud run services logs read codex-wrapper \
  --region us-central1 \
  --project elaihub-prod \
  --limit 100
```

### Métricas no Console

```
https://console.cloud.google.com/run/detail/us-central1/codex-wrapper/metrics?project=elaihub-prod
```

---

## 🐛 Troubleshooting

### Problema: 403 Forbidden

**Causa:** Políticas organizacionais do GCP bloqueiam acesso público (`allUsers`)

**Solução:** Usar autenticação GCP via `gcloud auth print-identity-token`

### Problema: Secret permission denied

**Causa:** Service account não tem permissão de acessar o secret

**Solução:**
```bash
gcloud secrets add-iam-policy-binding <secret-name> \
  --member="serviceAccount:codex-wrapper-sa@elaihub-prod.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=elaihub-prod
```

### Problema: MCP Server timeout

**Causa:** Timeout muito baixo para operações demoradas

**Solução:** Aumentar `tool_timeout_sec` no [config.toml](config.toml:15)

---

## 📚 Documentação Relacionada

- [Guia Completo de Uso](GUIA_COMPLETO_USO.md)
- [Quick Start](QUICK_START.md)
- [Integração MCP](MCP_INTEGRATION.md)
- [MCP Pipedrive Cloud Run](../../packages/mcp/CLOUD_RUN_DEPLOY.md)

---

## 🎯 Próximos Passos

- [ ] Configurar CI/CD para deploys automáticos
- [ ] Adicionar mais MCP servers (Slack, GitHub, etc)
- [ ] Implementar cache de ferramentas MCP
- [ ] Dashboard de métricas personalizado
- [ ] Configurar alertas de SLA

---

**Deploy realizado com sucesso! 🎉**
**Codex Wrapper está pronto para uso com integração MCP Pipedrive completa.**
