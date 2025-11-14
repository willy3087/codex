#!/bin/bash
# Script para criar trigger automático de build no Cloud Build
# Faz deploy automático quando houver push na branch main

set -e

PROJECT_ID="elaihub-prod"
TRIGGER_NAME="codex-gateway-main-deploy"
REPO_NAME="codex"  # Nome do seu repositório
BRANCH_PATTERN="^main$"

echo "Criando trigger de build automático para branch main..."
echo ""

# Criar trigger
gcloud builds triggers create github \
  --project=$PROJECT_ID \
  --name=$TRIGGER_NAME \
  --repo-name=$REPO_NAME \
  --repo-owner="williamduarte" \
  --branch-pattern=$BRANCH_PATTERN \
  --build-config=cloudbuild.yaml \
  --substitutions=_COMMIT_SHA='$COMMIT_SHA' \
  --description="Deploy automático do Codex Gateway quando houver push na main"

echo ""
echo "✅ Trigger criado com sucesso!"
echo ""
echo "Configuração:"
echo "  - Nome: $TRIGGER_NAME"
echo "  - Repositório: $REPO_NAME"
echo "  - Branch: main"
echo "  - Config: cloudbuild.yaml"
echo ""
echo "Agora qualquer push na branch main vai disparar o build automaticamente!"
