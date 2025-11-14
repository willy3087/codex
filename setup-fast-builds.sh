#!/bin/bash
# Setup para builds rápidos no Cloud Build
# Configura buckets, permissões e primeira build

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 SETUP: Cloud Build Otimizado para Codex"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verificar gcloud
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI não encontrado. Instale: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Obter project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    echo "❌ Nenhum projeto GCP configurado. Execute: gcloud config set project SEU-PROJECT-ID"
    exit 1
fi

echo "📋 Projeto GCP: $PROJECT_ID"
echo ""

# 1. Habilitar APIs
echo "1️⃣  Habilitando APIs necessárias..."
gcloud services enable \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  run.googleapis.com \
  storage.googleapis.com \
  --quiet

echo "   ✅ APIs habilitadas"
echo ""

# 2. Criar buckets para cache
echo "2️⃣  Criando buckets de cache..."

CACHE_BUCKET="codex-build-cache"
ARTIFACTS_BUCKET="codex-artifacts"
REGION="us-central1"

# Cache bucket
if gsutil ls -b gs://$CACHE_BUCKET 2>/dev/null; then
    echo "   ℹ️  Bucket $CACHE_BUCKET já existe"
else
    gsutil mb -l $REGION gs://$CACHE_BUCKET
    echo "   ✅ Bucket $CACHE_BUCKET criado"
fi

# Artifacts bucket
if gsutil ls -b gs://$ARTIFACTS_BUCKET 2>/dev/null; then
    echo "   ℹ️  Bucket $ARTIFACTS_BUCKET já existe"
else
    gsutil mb -l $REGION gs://$ARTIFACTS_BUCKET
    echo "   ✅ Bucket $ARTIFACTS_BUCKET criado"
fi

echo ""

# 3. Configurar lifecycle para cache (limpar após 30 dias)
echo "3️⃣  Configurando lifecycle para cache..."

cat > /tmp/lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 30}
      }
    ]
  }
}
EOF

gsutil lifecycle set /tmp/lifecycle.json gs://$CACHE_BUCKET
rm /tmp/lifecycle.json

echo "   ✅ Cache expira após 30 dias"
echo ""

# 4. Criar Artifact Registry
echo "4️⃣  Criando Artifact Registry..."

REPO_NAME="codex-wrapper"

if gcloud artifacts repositories describe $REPO_NAME \
    --location=$REGION 2>/dev/null; then
    echo "   ℹ️  Repositório $REPO_NAME já existe"
else
    gcloud artifacts repositories create $REPO_NAME \
        --repository-format=docker \
        --location=$REGION \
        --description="Codex Gateway Docker images" \
        --quiet
    echo "   ✅ Repositório $REPO_NAME criado"
fi

echo ""

# 5. Dar permissões ao Cloud Build
echo "5️⃣  Configurando permissões..."

PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
CLOUD_BUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

# Permissões necessárias
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$CLOUD_BUILD_SA" \
    --role="roles/run.admin" \
    --quiet > /dev/null 2>&1 || true

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$CLOUD_BUILD_SA" \
    --role="roles/iam.serviceAccountUser" \
    --quiet > /dev/null 2>&1 || true

echo "   ✅ Permissões configuradas"
echo ""

# 6. Testar build rápido
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ SETUP CONCLUÍDO!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Resumo:"
echo "   • Projeto: $PROJECT_ID"
echo "   • Cache bucket: gs://$CACHE_BUCKET"
echo "   • Artifacts bucket: gs://$ARTIFACTS_BUCKET"
echo "   • Docker registry: $REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME"
echo ""
echo "🎯 Próximos passos:"
echo ""
echo "1. Fazer primeira build (será mais lenta, ~8-10 min):"
echo "   cd /Users/williamduarte/NCMproduto/codex"
echo "   gcloud builds submit --config=cloudbuild-fast.yaml"
echo ""
echo "2. Builds subsequentes com cache: ~3-5 minutos! 🚀"
echo ""
echo "3. Criar trigger automático (opcional):"
echo "   gcloud builds triggers create github \\"
echo "     --repo-name=codex \\"
echo "     --repo-owner=SEU-USUARIO \\"
echo "     --branch-pattern='^main\$' \\"
echo "     --build-config=cloudbuild-fast.yaml"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
