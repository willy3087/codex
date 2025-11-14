#!/bin/bash
# Script para criar Cloud Build trigger automático
# Repo: github.com/willy3087/codex

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Configurando Cloud Build Trigger"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verificar gcloud
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI não encontrado!"
    echo ""
    echo "Opções:"
    echo "1. Instalar: https://cloud.google.com/sdk/docs/install"
    echo "2. Adicionar ao PATH se já instalado"
    echo ""
    exit 1
fi

# Verificar autenticação
echo "🔐 Verificando autenticação GCP..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo "⚠️  Não autenticado. Execute:"
    echo "   gcloud auth login"
    exit 1
fi

ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
PROJECT=$(gcloud config get-value project 2>/dev/null)

echo "   Account: $ACCOUNT"
echo "   Project: $PROJECT"
echo ""

# Verificar se já existe trigger
echo "🔍 Verificando triggers existentes..."
EXISTING=$(gcloud builds triggers list --filter="name:codex-auto-build" --format="value(name)" 2>/dev/null)

if [ -n "$EXISTING" ]; then
    echo "⚠️  Trigger 'codex-auto-build' já existe!"
    echo ""
    read -p "Deseja deletar e recriar? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Deletando trigger existente..."
        gcloud builds triggers delete codex-auto-build --quiet
        echo "   ✅ Deletado"
    else
        echo "❌ Cancelado"
        exit 0
    fi
fi

echo ""
echo "📋 Configuração do Trigger:"
echo "   Nome: elai-codex-auto-build"
echo "   Repo: nextlw/elai_codex"
echo "   Branch: main"
echo "   Config: cloudbuild-fast.yaml"
echo ""

# Verificar se o repo está conectado ao Cloud Build
echo "🔗 Verificando conexão com GitHub..."
echo ""

# Primeiro, verificar se a API está habilitada
echo "1️⃣  Habilitando APIs necessárias..."
gcloud services enable cloudbuild.googleapis.com --quiet 2>/dev/null || true
gcloud services enable cloudresourcemanager.googleapis.com --quiet 2>/dev/null || true
echo ""

# Listar repositórios conectados (2nd gen)
echo "2️⃣  Listando repositórios GitHub conectados..."
REPOS=$(gcloud builds repositories list 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ] || [ -z "$REPOS" ]; then
    echo "⚠️  Nenhum repositório GitHub conectado ainda."
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔧 SOLUÇÃO: Conectar GitHub ao Cloud Build"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Método 1 - Via Console (Mais Fácil):"
    echo "   1. Abra: https://console.cloud.google.com/cloud-build/triggers/connect"
    echo "   2. Clique 'SELECT SOURCE'"
    echo "   3. Escolha 'GitHub (Cloud Build GitHub App)'"
    echo "   4. Clique 'CONTINUE'"
    echo "   5. Autentique no GitHub"
    echo "   6. Selecione o repositório: nextlw/elai_codex"
    echo "   7. Clique 'CONNECT'"
    echo "   8. Execute este script novamente"
    echo ""
    echo "Método 2 - Via gcloud (Manual):"
    echo ""
    echo "   # Criar conexão com GitHub (primeira vez)"
    echo "   gcloud alpha builds connections create github github-connection \\"
    echo "     --region=us-central1"
    echo ""
    echo "   # Link do repositório"
    echo "   gcloud alpha builds repositories create elai-codex \\"
    echo "     --remote-uri=https://github.com/nextlw/elai_codex.git \\"
    echo "     --connection=github-connection \\"
    echo "     --region=us-central1"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi

echo "$REPOS"
echo ""

# Tentar criar o trigger (1st gen - Legacy, mais compatível)
echo "3️⃣  Criando trigger..."
echo ""

gcloud builds triggers create github \
  --name="elai-codex-auto-build" \
  --repo-name=elai_codex \
  --repo-owner=nextlw \
  --branch-pattern="^main$" \
  --build-config=cloudbuild-fast.yaml \
  --description="Auto build on push to main (5 min fast build)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ TRIGGER CRIADO COM SUCESSO!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🎯 Próximos passos:"
echo ""
echo "1. Faça um push para testar:"
echo "   git push origin main"
echo ""
echo "2. Acompanhe o build:"
echo "   gcloud builds list --limit=1"
echo "   ou: https://console.cloud.google.com/cloud-build/builds"
echo ""
echo "3. Cada push para 'main' vai:"
echo "   → Compilar Rust em ~5 min"
echo "   → Deploy automático no Cloud Run"
echo "   → URL: https://wrapper-PROJECT.run.app"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
