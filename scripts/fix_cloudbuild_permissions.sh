#!/bin/bash
# Script para adicionar permissões necessárias para Cloud Build fazer deploy no Cloud Run

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Configurando Permissões Cloud Build → Cloud Run${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Configurações
PROJECT_ID="elaihub-prod"
PROJECT_NUMBER="467992722695"
SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

echo "📋 Configurações:"
echo "  Project ID: $PROJECT_ID"
echo "  Project Number: $PROJECT_NUMBER"
echo "  Service Account: $SERVICE_ACCOUNT"
echo ""

# Verificar se gcloud está autenticado
echo -e "${YELLOW}🔍 Verificando autenticação...${NC}"
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo -e "${RED}❌ Você não está autenticado no gcloud${NC}"
    echo ""
    echo "Execute primeiro:"
    echo "  gcloud auth login"
    exit 1
fi

ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
echo -e "${GREEN}✅ Autenticado como: $ACTIVE_ACCOUNT${NC}"
echo ""

# Verificar projeto ativo
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ "$CURRENT_PROJECT" != "$PROJECT_ID" ]; then
    echo -e "${YELLOW}⚠️  Projeto atual: $CURRENT_PROJECT${NC}"
    echo -e "${YELLOW}   Mudando para: $PROJECT_ID${NC}"
    gcloud config set project $PROJECT_ID
fi
echo ""

# Adicionar permissão 1: Cloud Run Admin
echo -e "${YELLOW}📝 Adicionando permissão: Cloud Run Admin...${NC}"
if gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/run.admin" \
    --condition=None \
    > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Cloud Run Admin adicionado${NC}"
else
    echo -e "${RED}❌ Erro ao adicionar Cloud Run Admin${NC}"
    echo "   Você pode não ter permissão de Owner/IAM Admin no projeto"
fi
echo ""

# Adicionar permissão 2: Service Account User
echo -e "${YELLOW}📝 Adicionando permissão: Service Account User...${NC}"
if gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/iam.serviceAccountUser" \
    --condition=None \
    > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Service Account User adicionado${NC}"
else
    echo -e "${RED}❌ Erro ao adicionar Service Account User${NC}"
    echo "   Você pode não ter permissão de Owner/IAM Admin no projeto"
fi
echo ""

# Verificar permissões adicionadas
echo -e "${YELLOW}🔍 Verificando permissões da service account...${NC}"
ROLES=$(gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --format="table(bindings.role)" \
    --filter="bindings.members:serviceAccount:$SERVICE_ACCOUNT" 2>/dev/null | tail -n +2)

if echo "$ROLES" | grep -q "roles/run.admin"; then
    echo -e "${GREEN}✅ roles/run.admin${NC}"
else
    echo -e "${RED}❌ roles/run.admin (faltando)${NC}"
fi

if echo "$ROLES" | grep -q "roles/iam.serviceAccountUser"; then
    echo -e "${GREEN}✅ roles/iam.serviceAccountUser${NC}"
else
    echo -e "${RED}❌ roles/iam.serviceAccountUser (faltando)${NC}"
fi
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Configuração concluída!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Agora você pode fazer o deploy:"
echo "  cd /Users/williamduarte/NCMproduto/codex"
echo "  COMMIT_SHA=\$(git rev-parse --short HEAD)"
echo "  gcloud builds submit --config=cloudbuild.yaml --substitutions=COMMIT_SHA=\$COMMIT_SHA --timeout=40m"
echo ""
