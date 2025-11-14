# ☁️ Codex - Cloud Build & Cloud Run (100% GCP)

Arquitetura **totalmente no Google Cloud Platform** com builds otimizados em 5 minutos.

## 🏗️ Arquitetura GCP

```
┌─────────────────────────────────────────────────┐
│  Developer Push (Git)                           │
└────────────┬────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────┐
│  Cloud Build (Build Pipeline)                   │
│  • Restaura cache (sccache + cargo)             │
│  • Compila Rust (5 min com cache)               │
│  • Cria Docker image                            │
│  • Push para Artifact Registry                  │
│  • Deploy para Cloud Run                        │
└────────────┬────────────────────────────────────┘
             │
    ┌────────┴────────┐
    ▼                 ▼
┌──────────┐    ┌──────────────┐
│Cloud     │    │ Artifact     │
│Storage   │    │ Registry     │
│(Cache)   │    │(Docker imgs) │
└──────────┘    └──────┬───────┘
                       │
                       ▼
              ┌──────────────────┐
              │   Cloud Run      │
              │ (Auto-scaling)   │
              │  • Gateway       │
              │  • Workers       │
              └──────────────────┘
```

## 💰 Custos Estimados (100% GCP)

### Cloud Build

| Componente | Uso | Custo/Mês |
|------------|-----|-----------|
| **E2_HIGHCPU_32** | 100 builds × 5 min | ~$48 |
| **Cloud Storage** (cache) | 50GB | ~$1 |
| **Artifact Registry** | 10GB imagens | ~$1 |
| **Total Build** | - | **~$50/mês** |

### Cloud Run (Produção)

| Componente | Uso | Custo/Mês |
|------------|-----|-----------|
| **CPU** | 2 vCPU × 1M req | ~$24 |
| **Memory** | 4GB × 1M req | ~$10 |
| **Requests** | 1M requests | ~$0.40 |
| **Total Runtime** | - | **~$35/mês** |

**Total GCP**: ~$85/mês (dev + produção)

## 🚀 Quick Start

### 1. Setup Inicial (1x)

```bash
cd /Users/williamduarte/NCMproduto/codex

# Executar setup
./setup-fast-builds.sh

# Isso configura:
# ✅ Cloud Build API
# ✅ Artifact Registry
# ✅ Cloud Run
# ✅ Buckets de cache
# ✅ Permissões
```

### 2. Primeira Build

```bash
# Build manual (primeira vez: ~8-10 min)
gcloud builds submit --config=cloudbuild-fast.yaml

# Vai:
# 1. Compilar Rust (popula cache)
# 2. Criar Docker image
# 3. Deploy no Cloud Run
# 4. Retornar URL do serviço
```

### 3. Builds Subsequentes

```bash
# Builds com cache: 3-5 min! 🚀
gcloud builds submit --config=cloudbuild-fast.yaml
```

### 4. Acessar Serviço

```bash
# Obter URL do Cloud Run
gcloud run services describe wrapper \
  --region=us-central1 \
  --format='value(status.url)'

# Testar
curl https://wrapper-xxxxx-uc.a.run.app/health
```

## 🔄 CI/CD Automático

### Trigger para Main Branch

```bash
gcloud builds triggers create github \
  --name="codex-main" \
  --repo-name=codex \
  --repo-owner=SEU-USUARIO \
  --branch-pattern="^main$" \
  --build-config=cloudbuild-fast.yaml

# Agora cada push para main:
# → Cloud Build automático
# → Deploy no Cloud Run
# → Tudo em ~5 minutos
```

### Trigger para Pull Requests

```bash
gcloud builds triggers create github \
  --name="codex-pr" \
  --repo-name=codex \
  --repo-owner=SEU-USUARIO \
  --pull-request-pattern="^.*$" \
  --build-config=cloudbuild-fast.yaml

# PRs são testados antes de merge
```

## 📊 Monitoramento

### Cloud Build

```bash
# Listar builds
gcloud builds list --limit=10

# Ver log específico
gcloud builds log <BUILD_ID> --stream

# Dashboard web
open "https://console.cloud.google.com/cloud-build/builds"
```

### Cloud Run

```bash
# Logs em tempo real
gcloud run services logs read wrapper \
  --region=us-central1 \
  --limit=50 \
  --format=json

# Métricas
gcloud run services describe wrapper \
  --region=us-central1 \
  --format=json | jq '.status.traffic'

# Dashboard web
open "https://console.cloud.google.com/run"
```

## 🎯 Workflows Comuns

### Deploy de Hotfix

```bash
# 1. Fix local
git checkout -b hotfix/critical-bug
# ... fazer mudanças ...

# 2. Build + deploy manual
gcloud builds submit --config=cloudbuild-fast.yaml

# 3. Se OK, fazer merge
git push origin hotfix/critical-bug
# ... abrir PR e merge ...
```

### Rollback para Versão Anterior

```bash
# Listar revisões
gcloud run revisions list \
  --service=wrapper \
  --region=us-central1

# Redirecionar tráfego para revisão anterior
gcloud run services update-traffic wrapper \
  --region=us-central1 \
  --to-revisions=wrapper-00042-abc=100
```

### Testar Branch Específico

```bash
# Build de branch de feature
git checkout feature/nova-funcionalidade
gcloud builds submit --config=cloudbuild-fast.yaml

# Deploy em serviço separado (staging)
gcloud run deploy wrapper-staging \
  --image=us-central1-docker.pkg.dev/PROJECT/codex-wrapper/wrapper:latest \
  --region=us-central1
```

## 🔧 Configurações Avançadas

### Ajustar Recursos do Cloud Run

Editar `cloudbuild-fast.yaml`:

```yaml
- '--cpu=4'              # 2 → 4 vCPUs (mais rápido)
- '--memory=8Gi'         # 4 → 8 GB (mais memória)
- '--max-instances=50'   # 20 → 50 (mais scaling)
- '--min-instances=1'    # Manter 1 instância warm
```

### Adicionar Secrets

```bash
# Criar secret no Secret Manager
echo -n "sua-api-key" | gcloud secrets create API_KEY --data-file=-

# Dar permissão ao Cloud Run
gcloud secrets add-iam-policy-binding API_KEY \
  --member="serviceAccount:SERVICE_ACCOUNT" \
  --role="roles/secretmanager.secretAccessor"

# Usar no Cloud Run (adicionar no cloudbuild-fast.yaml)
- '--set-secrets=API_KEY=API_KEY:latest'
```

### Custom Domain

```bash
# Mapear domínio customizado
gcloud run domain-mappings create \
  --service=wrapper \
  --domain=api.codex.com \
  --region=us-central1

# Configurar DNS (seguir instruções do output)
```

## 🧪 Testes

### Teste Local do Binário

```bash
# Baixar binário do último build
gsutil cp gs://codex-artifacts/latest/codex-gateway ./

# Rodar localmente
chmod +x codex-gateway
RUST_LOG=debug ./codex-gateway
```

### Teste da Imagem Docker

```bash
# Baixar última imagem
docker pull us-central1-docker.pkg.dev/PROJECT/codex-wrapper/wrapper:latest

# Rodar localmente
docker run -p 8080:8080 \
  -e RUST_LOG=info \
  us-central1-docker.pkg.dev/PROJECT/codex-wrapper/wrapper:latest

# Testar
curl http://localhost:8080/health
```

## 📈 Otimizações de Performance

### 1. Warm Instances (Reduzir Cold Start)

```bash
gcloud run services update wrapper \
  --region=us-central1 \
  --min-instances=1
```

**Custo**: ~$10/mês adicional, mas **zero cold starts**.

### 2. CPU Always Allocated

```bash
gcloud run services update wrapper \
  --region=us-central1 \
  --cpu-throttling=false
```

Para workloads que processam em background.

### 3. Aumentar Timeout

```bash
gcloud run services update wrapper \
  --region=us-central1 \
  --timeout=600s  # 10 minutos
```

Para operações longas.

## 🛡️ Segurança

### Autenticação Obrigatória

Remover `--allow-unauthenticated` do cloudbuild-fast.yaml:

```yaml
# Comentar ou remover esta linha:
# - '--allow-unauthenticated'
```

Agora requer autenticação:

```bash
# Obter token
TOKEN=$(gcloud auth print-identity-token)

# Fazer request
curl -H "Authorization: Bearer $TOKEN" \
  https://wrapper-xxxxx-uc.a.run.app/
```

### VPC Connector (Acesso a Recursos Privados)

```bash
# Criar VPC connector
gcloud compute networks vpc-access connectors create codex-connector \
  --region=us-central1 \
  --range=10.8.0.0/28

# Usar no Cloud Run
gcloud run services update wrapper \
  --region=us-central1 \
  --vpc-connector=codex-connector
```

## 📚 Estrutura de Arquivos

```
codex/
├── cloudbuild-fast.yaml       # Build otimizado (5 min)
├── cloudbuild.yaml            # Build antigo (40 min, deprecated)
├── setup-fast-builds.sh       # Setup inicial GCP
├── FAST-BUILD-GUIDE.md        # Guia detalhado
├── README-CLOUD-BUILD.md      # Este arquivo
└── codex-rs/
    ├── Cargo.toml             # Com profile release-fast
    ├── Dockerfile.fast        # Dockerfile otimizado
    └── Dockerfile             # Dockerfile antigo
```

## 🎓 Resumo

| Item | Valor |
|------|-------|
| **Plataforma** | 100% Google Cloud Platform |
| **Build Time** | 3-5 min (com cache) |
| **Deploy Time** | ~1-2 min |
| **Total Time** | **~5-7 min** (commit → produção) |
| **Custo Build** | ~$0.48 por build |
| **Custo Runtime** | ~$35/mês (1M requests) |
| **Scaling** | 0 → 50 instâncias (automático) |

---

**Pronto para começar?** Execute:

```bash
./setup-fast-builds.sh
gcloud builds submit --config=cloudbuild-fast.yaml
```

🚀 **5 minutos depois**: seu serviço estará no ar!
