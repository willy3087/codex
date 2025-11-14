#!/bin/bash
# Fix Cloud Build permissions for GitHub connection
# Error: Secret Manager permissions needed

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Corrigindo Permissões do Cloud Build"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Obter informações do projeto
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
PROJECT_NUMBER="467992722695"  # Do erro acima
CLOUD_BUILD_SA="service-${PROJECT_NUMBER}@gcp-sa-cloudbuild.iam.gserviceaccount.com"

echo "📋 Informações:"
echo "   Project ID: $PROJECT_ID"
echo "   Project Number: $PROJECT_NUMBER"
echo "   Cloud Build SA: $CLOUD_BUILD_SA"
echo ""

# 1. Habilitar Secret Manager API
echo "1️⃣  Habilitando Secret Manager API..."
gcloud services enable secretmanager.googleapis.com --quiet
echo "   ✅ API habilitada"
echo ""

# 2. Dar permissões ao Cloud Build Service Account
echo "2️⃣  Concedendo permissões ao Cloud Build..."

# Permissão para criar secrets
echo "   → secretmanager.admin role..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$CLOUD_BUILD_SA" \
    --role="roles/secretmanager.admin" \
    --condition=None \
    --quiet

echo "   ✅ Permissões concedidas"
echo ""

# 3. Verificar permissões
echo "3️⃣  Verificando permissões..."
echo ""
gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.members:$CLOUD_BUILD_SA" \
    --format="table(bindings.role)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ PERMISSÕES CORRIGIDAS!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🎯 Próximo passo:"
echo ""
echo "Agora você pode conectar o GitHub:"
echo ""
echo "Opção A - Via gcloud (tente novamente):"
echo "   gcloud alpha builds connections create github github-connection \\"
echo "     --region=us-central1"
echo ""
echo "Opção B - Via Console (mais fácil):"
echo "   https://console.cloud.google.com/cloud-build/triggers/connect"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
