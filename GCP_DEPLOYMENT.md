# Codex Gateway - Arquitetura GCP e Guia de Deployment

## 🎯 Visão Geral

O Codex Gateway é uma implementação cloud-native em Rust que atua como gateway completo para todos os serviços CLI do Codex, com arquitetura escalável, performática e de baixo custo no Google Cloud Platform.

## 📊 Arquitetura GCP

```
┌────────────────────────────────────────────────────────────────┐
│                        Internet / Client                        │
│              (Frontend, CLI, API Consumers)                     │
└────────────────────────┬───────────────────────────────────────┘
                         │ HTTPS/WSS
                         ▼
┌────────────────────────────────────────────────────────────────┐
│              Cloud Load Balancer (Global)                       │
│               - SSL Termination                                 │
│               - DDoS Protection                                 │
└────────────────────────┬───────────────────────────────────────┘
                         │
                         ▼
┌────────────────────────────────────────────────────────────────┐
│                   Cloud Run Service                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Codex Gateway (Rust + Axum)                             │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │  • API Key Auth Middleware                         │  │  │
│  │  │  • Rate Limiting                                    │  │  │
│  │  │  • Request Routing                                  │  │  │
│  │  │    - /health (Health Check)                        │  │  │
│  │  │    - /jsonrpc (JSON-RPC API)                      │  │  │
│  │  │    - /ws (WebSocket)                               │  │  │
│  │  │    - /webhook (Webhooks)                           │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  │                                                            │  │
│  │  Config:                                                   │  │
│  │  - Auto-scaling: 0-20 instances                           │  │
│  │  - CPU: 2 vCPU                                             │  │
│  │  - Memory: 4 GB                                            │  │
│  │  - Timeout: 300s                                           │  │
│  │  - Concurrency: 80 requests/instance                      │  │
│  └──────────────────────────────────────────────────────────┘  │
└───────┬──────────────────┬───────────────────┬─────────────────┘
        │                  │                   │
        ▼                  ▼                   ▼
┌───────────────┐  ┌──────────────┐  ┌─────────────────┐
│  Firestore    │  │ Secret       │  │ Cloud Storage   │
│  (Sessions &  │  │ Manager      │  │ (Artifacts)     │
│   API Keys)   │  │ (Secrets)    │  │                 │
│               │  │              │  │ - Versioning    │
│ - Native Mode │  │ - API Keys   │  │ - Lifecycle     │
│ - Optimistic  │  │ - Credentials│  │ - 30d retention │
│               │  │              │  │                 │
└───────────────┘  └──────────────┘  └─────────────────┘
        │
        ▼
┌───────────────────────────────────────────────────────┐
│            Cloud SQL (Optional)                        │
│            - PostgreSQL                                │
│            - Private IP                                │
└───────────────────────────────────────────────────────┘

        │
        ▼
┌───────────────────────────────────────────────────────┐
│          Cloud Monitoring & Logging                    │
│          - Request Metrics                             │
│          - Error Tracking                              │
│          - Performance Monitoring                      │
│          - Distributed Tracing                         │
└───────────────────────────────────────────────────────┘
```

## 🔑 Componentes Principais

### 1. Cloud Run
- **Tipo**: Serverless Container Platform
- **Características**:
  - Auto-scaling horizontal (0-20 instâncias)
  - Pay-per-use (sem custo em idle)
  - Cold start otimizado (~1-2s com Rust)
  - HTTPS nativo com certificado gerenciado

### 2. Firestore
- **Tipo**: NoSQL Document Database
- **Uso**:
  - Armazenamento de API keys
  - Cache de sessões
  - Rate limiting counters
  - User metadata
- **Características**:
  - Alta disponibilidade
  - Escalabilidade automática
  - Free tier generoso

### 3. Cloud Storage
- **Tipo**: Object Storage
- **Uso**:
  - Artefatos gerados (código, files, etc)
  - Arquivos temporários
- **Características**:
  - Signed URLs para acesso seguro
  - Lifecycle policies (auto-delete após 30 dias)
  - Versionamento habilitado

### 4. Secret Manager
- **Tipo**: Secrets Management
- **Uso**:
  - API keys (Anthropic, OpenAI, etc)
  - Tokens de integração
  - Credenciais de banco
- **Características**:
  - Criptografia em repouso
  - Auditoria de acessos
  - Rotação de secrets

### 5. Cloud Monitoring
- **Tipo**: Observability Platform
- **Uso**:
  - Métricas de requests
  - Error tracking
  - Performance monitoring
  - Alertas
- **Características**:
  - Dashboards customizados
  - Log-based metrics
  - SLI/SLO tracking

## 💰 Estimativa de Custos

### Configuração Base (uso médio)

| Serviço | Configuração | Custo Mensal Estimado |
|---------|--------------|----------------------|
| Cloud Run | 2 vCPU, 4GB RAM, ~1M requests | $10 - $30 |
| Firestore | ~100K reads, ~50K writes | $0 - $5 |
| Cloud Storage | 10GB storage, 1K operations | $1 - $3 |
| Secret Manager | 4 secrets, ~10K accesses | $0.60 |
| Cloud Monitoring | Logs + metrics | Incluído |
| Cloud Build | 120 builds/dia | Grátis |
| **TOTAL** | | **$12 - $39/mês** |

### Free Tiers Aproveitados
- **Cloud Run**: 2M requests/mês
- **Firestore**: 50K reads, 20K writes, 1GB storage/dia
- **Cloud Storage**: 5GB standard storage
- **Cloud Build**: 120 builds/dia
- **Secret Manager**: 6 secrets ativos

### Otimizações de Custo
1. **Auto-scaling para zero** quando não há tráfego
2. **Lifecycle policies** no Cloud Storage (30 dias)
3. **Request batching** para Firestore
4. **Caching agressivo** de API responses
5. **Compression** de payloads

## 🚀 Guia de Deployment

### ✅ Status da Produção Atual

```
🟢 Cloud Run: https://wrapper-467992722695.us-central1.run.app
🟢 Imagem: us-central1-docker.pkg.dev/elaihub-prod/codex-wrapper/wrapper:486a13c9
🟢 Firestore: (default) - FIRESTORE_NATIVE
🟢 Storage: elaihub-prod-codex-artifacts
🟢 Secrets: gateway-api-key, anthropic-api-key, openai-api-key, pipedrive-api-token
```

### Pré-requisitos

```bash
# 1. Install gcloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# 2. Authenticate (usar adm@nexcode.live)
gcloud auth login
gcloud config set account adm@nexcode.live

# 3. Set project
gcloud config set project elaihub-prod

# 4. Enable required APIs (JÁ HABILITADAS)
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  firestore.googleapis.com \
  secretmanager.googleapis.com \
  storage.googleapis.com
```

### Opção 1: Deploy via Cloud Build (Recomendado para Produção)

```bash
# 1. Trigger build e deploy automatizado
gcloud builds submit --config=cloudbuild.yaml

# Acompanhar logs
gcloud builds log $(gcloud builds list --limit=1 --format="value(id)")
```

**Configuração do Cloud Build**:
- Machine: E2_HIGHCPU_32 (32 vCPUs, 32GB RAM)
- Timeout: 40 minutos
- Steps: Build Docker → Push → Deploy → Health Check

### Opção 2: Deploy Manual com Docker Local

```bash
# 1. Build imagem Docker localmente (apenas para testing local ARM64)
cd codex-rs
docker build -t us-central1-docker.pkg.dev/elaihub-prod/codex-wrapper/wrapper:latest .

# 2. Push para Artifact Registry
gcloud auth configure-docker us-central1-docker.pkg.dev
docker push us-central1-docker.pkg.dev/elaihub-prod/codex-wrapper/wrapper:latest

# 3. Deploy para Cloud Run
gcloud run deploy wrapper \
  --image=us-central1-docker.pkg.dev/elaihub-prod/codex-wrapper/wrapper:latest \
  --region=us-central1 \
  --platform=managed \
  --service-account=467992722695-compute@developer.gserviceaccount.com \
  --max-instances=20 \
  --cpu=2 \
  --memory=4Gi \
  --timeout=300s \
  --concurrency=80 \
  --port=8080 \
  --set-env-vars="RUST_LOG=info,codex_gateway=debug,GCP_PROJECT=elaihub-prod,FIRESTORE_DATABASE=(default),STORAGE_BUCKET=elaihub-prod-codex-artifacts,GATEWAY_API_KEY_SECRET=projects/467992722695/secrets/gateway-api-key/versions/latest"
```

### Opção 3: Deploy com Script Automático

```bash
# Usar script de deploy (atualizado com env vars)
./scripts/deploy.sh prod latest
```

### Opção 4: CI/CD com Cloud Build Trigger

```bash
# Configurar trigger automático no GitHub (se necessário)
gcloud builds triggers create github \
  --repo-name=codex \
  --repo-owner=your-org \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml
```

## 🔧 Configuração da Infraestrutura

### 1. Infraestrutura Criada (Comandos Executados em Produção)

```bash
# 1. Habilitar APIs
gcloud services enable \
  firestore.googleapis.com \
  secretmanager.googleapis.com \
  storage.googleapis.com

# 2. Firestore Database (JÁ EXISTE)
# gcloud firestore databases create --database="(default)" \
#   --location=us-central1 --type=firestore-native

# 3. Cloud Storage Bucket
gcloud storage buckets create gs://elaihub-prod-codex-artifacts \
  --location=us-central1 \
  --uniform-bucket-level-access

# 4. Criar Secrets
echo -n "temp-gateway-key-$(openssl rand -hex 16)" | \
  gcloud secrets create gateway-api-key --data-file=- --replication-policy="automatic"

# Secrets já existentes: anthropic-api-key, openai-api-key, pipedrive-api-token

# 5. Permissões IAM para o Service Account
SERVICE_ACCOUNT="467992722695-compute@developer.gserviceaccount.com"

# Secret access
gcloud secrets add-iam-policy-binding gateway-api-key \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/secretmanager.secretAccessor"

gcloud secrets add-iam-policy-binding anthropic-api-key \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/secretmanager.secretAccessor"

# Storage access
gcloud storage buckets add-iam-policy-binding gs://elaihub-prod-codex-artifacts \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/storage.objectAdmin"
```

### 2. Configurar API Keys

```bash
# Obter a API key do gateway
gcloud secrets versions access latest --secret=gateway-api-key

# Atualizar API keys (se necessário)
echo -n "sua-chave-real" | \
  gcloud secrets versions add anthropic-api-key --data-file=-

echo -n "sua-chave-openai" | \
  gcloud secrets versions add openai-api-key --data-file=-
```

### 3. Testar o Deploy

```bash
# Service URL
SERVICE_URL="https://wrapper-467992722695.us-central1.run.app"

# 1. Health check (público, sem autenticação)
curl $SERVICE_URL/health

# Resposta esperada:
# {"status":"healthy"}

# 2. Obter API key
GATEWAY_KEY=$(gcloud secrets versions access latest --secret=gateway-api-key)

# 3. Test JSON-RPC API (requer autenticação)
curl -X POST $SERVICE_URL/jsonrpc \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "exec",
    "params": {
      "command": "echo",
      "args": ["Hello from Codex Gateway"]
    },
    "id": 1
  }'

# 4. Test WebSocket upgrade
curl -i -N \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  $SERVICE_URL/ws
```

### 4. Alternativa: Provisionar com Terraform (Opcional)

```bash
cd terraform

# Initialize
terraform init

# Plan (verá que alguns recursos já existem)
terraform plan

# Import recursos existentes para o state do Terraform
terraform import google_firestore_database.main "(default)"
terraform import google_storage_bucket.artifacts elaihub-prod-codex-artifacts
terraform import google_secret_manager_secret.gateway_api_key projects/467992722695/secrets/gateway-api-key

# Apply (criará apenas recursos faltantes)
terraform apply
```

## 📈 Monitoramento e Observabilidade

### Dashboards

Acesse o Cloud Console:
- **Logs**: https://console.cloud.google.com/run/detail/us-central1/wrapper/logs
- **Metrics**: https://console.cloud.google.com/run/detail/us-central1/wrapper/metrics
- **Traces**: https://console.cloud.google.com/traces

### Métricas Importantes

1. **Request Latency** (p50, p95, p99)
2. **Error Rate** (5xx errors)
3. **Instance Count** (auto-scaling)
4. **CPU/Memory Usage**
5. **Cold Start Duration**

### Alertas Recomendados

```bash
# Alert on high error rate
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="High Error Rate" \
  --condition-display-name="Error rate > 5%" \
  --condition-threshold-value=5 \
  --condition-threshold-duration=300s
```

## 🔐 Segurança

### Boas Práticas Implementadas

1. **Autenticação**: API Key via header `X-API-Key`
2. **Rate Limiting**: 100 req/min por key
3. **HTTPS Only**: Certificado gerenciado automaticamente
4. **Secrets**: Armazenados no Secret Manager
5. **IAM**: Service account com permissões mínimas
6. **Network**: VPC connector para Cloud SQL

### Auditoria

```bash
# Ver logs de acesso a secrets
gcloud logging read \
  "resource.type=secretmanager.googleapis.com/Secret" \
  --limit=50

# Ver logs de API requests
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=wrapper" \
  --limit=100
```

## 🐛 Troubleshooting

### Logs

```bash
# Real-time logs
gcloud run services logs tail wrapper --region=us-central1

# Search logs
gcloud logging read "resource.labels.service_name=wrapper AND severity>=ERROR"
```

### Problemas Comuns

**1. Cold Start Lento**
- Solução: Aumentar `min-instances` ou implementar warming

**2. Out of Memory**
- Solução: Aumentar `--memory` ou otimizar uso de memória

**3. Timeout**
- Solução: Aumentar `--timeout` ou otimizar processamento

**4. Permission Denied**
- Solução: Verificar IAM roles do service account

## 📚 Recursos Adicionais

- [Cloud Run Docs](https://cloud.google.com/run/docs)
- [Firestore Docs](https://cloud.google.com/firestore/docs)
- [Secret Manager Docs](https://cloud.google.com/secret-manager/docs)
- [Cloud Build Docs](https://cloud.google.com/build/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

## 📝 Checklist de Deploy

- [x] Habilitar APIs necessárias ✅
- [x] Criar Artifact Registry repository ✅
- [x] Provisionar infraestrutura (Firestore, Storage, Secrets) ✅
- [x] Configurar secrets no Secret Manager ✅
- [x] Build e push da imagem Docker ✅
- [x] Deploy do Cloud Run service ✅
- [x] Testar health check ✅
- [x] Configurar variáveis de ambiente ✅
- [x] Permissões IAM configuradas ✅
- [ ] Testar todos os API endpoints (JSON-RPC, WebSocket, Webhook)
- [ ] Atualizar secrets com valores de produção reais
- [ ] Configurar domínio customizado (opcional)
- [ ] Configurar alertas de monitoring
- [ ] Documentar API keys para o time

## 🎉 Conclusão

A arquitetura GCP do Codex Gateway oferece:

✅ **Escalabilidade**: Auto-scaling 0-20 instâncias
✅ **Performance**: Rust + async I/O + Cloud Run
✅ **Custo-benefício**: ~$12-39/mês com free tiers
✅ **Segurança**: API keys + Secret Manager + IAM
✅ **Observabilidade**: Logging + Monitoring + Tracing
✅ **Facilidade**: Deploy automatizado + IaC com Terraform

---

**Última Atualização**: 2025-01-13 (Deploy Produção Completo)
**Versão**: 1.1.0
**Status**: 🟢 Em Produção
**Maintainer**: DevOps Team
**Service URL**: https://wrapper-467992722695.us-central1.run.app
