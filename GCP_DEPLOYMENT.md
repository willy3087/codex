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

### Pré-requisitos

```bash
# 1. Install gcloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# 2. Authenticate
gcloud auth login
gcloud auth application-default login

# 3. Set project
gcloud config set project elaihub-prod

# 4. Enable required APIs
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  firestore.googleapis.com \
  secretmanager.googleapis.com \
  storage.googleapis.com
```

### Opção 1: Deploy Manual

```bash
# 1. Build imagem Docker localmente
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
  --allow-unauthenticated \
  --max-instances=20 \
  --cpu=2 \
  --memory=4Gi
```

### Opção 2: Deploy Automatizado (Recomendado)

```bash
# Usar script de deploy
./scripts/deploy.sh prod latest
```

### Opção 3: CI/CD com Cloud Build

```bash
# Trigger manual
gcloud builds submit --config=cloudbuild.yaml

# Ou configurar trigger automático no GitHub
gcloud builds triggers create github \
  --repo-name=codex \
  --repo-owner=your-org \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml
```

## 🔧 Configuração da Infraestrutura

### 1. Provisionar com Terraform

```bash
cd terraform

# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply

# Configure secrets
echo -n "your-api-key" | \
  gcloud secrets versions add anthropic-api-key --data-file=-
```

### 2. Configurar API Keys

```bash
# Generate API key
openssl rand -base64 32

# Add to Secret Manager
echo -n "generated-key" | \
  gcloud secrets versions add gateway-api-key --data-file=-
```

### 3. Testar o Deploy

```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe wrapper \
  --region=us-central1 \
  --format='value(status.url)')

# Health check
curl $SERVICE_URL/health

# Test API (with API key)
curl -H "X-API-Key: your-api-key" \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"conversation.prompt","params":{"prompt":"Hello"},"id":1}' \
     $SERVICE_URL/jsonrpc
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

- [ ] Habilitar APIs necessárias
- [ ] Criar Artifact Registry repository
- [ ] Provisionar infraestrutura com Terraform
- [ ] Configurar secrets no Secret Manager
- [ ] Build e push da imagem Docker
- [ ] Deploy do Cloud Run service
- [ ] Testar health check
- [ ] Testar API endpoints
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

**Última Atualização**: 2025-01-13
**Versão**: 1.0.0
**Maintainer**: DevOps Team
