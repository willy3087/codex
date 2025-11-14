#!/bin/bash
# Método SIMPLES: Conectar GitHub e criar trigger via Console

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔗 Conectar GitHub ao Cloud Build - MÉTODO SIMPLES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

echo "📋 Projeto: $PROJECT_ID"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🎯 PASSO A PASSO:"
echo ""
echo "1️⃣  Abrir página de triggers no navegador..."
echo ""

# Abrir navegador
URL="https://console.cloud.google.com/cloud-build/triggers/connect?project=$PROJECT_ID"
open "$URL" 2>/dev/null || xdg-open "$URL" 2>/dev/null || echo "   Abra manualmente: $URL"

echo ""
echo "2️⃣  No navegador que abriu:"
echo ""
echo "   a) Clique em 'CREATE TRIGGER' (se aparecer) ou 'CONNECT REPOSITORY'"
echo "   b) Selecione 'GitHub (Cloud Build GitHub App)'"
echo "   c) Clique 'CONTINUE'"
echo "   d) Autentique no GitHub (se pedido)"
echo "   e) Autorize o Cloud Build a acessar seus repos"
echo "   f) Selecione o repositório: nextlw/elai_codex"
echo "   g) Clique 'CONNECT'"
echo ""
echo "3️⃣  Depois de conectar, CRIAR O TRIGGER:"
echo ""
echo "   • Nome: elai-codex-auto-build"
echo "   • Event: Push to a branch"
echo "   • Branch: ^main\$"
echo "   • Configuration: Cloud Build configuration file (yaml or json)"
echo "   • Location: Repository (cloudbuild-fast.yaml)"
echo "   • Clique 'CREATE'"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "OU execute este comando manualmente após conectar o repo:"
echo ""
echo "gcloud builds triggers create github \\"
echo "  --name=\"elai-codex-auto-build\" \\"
echo "  --repo-name=elai_codex \\"
echo "  --repo-owner=nextlw \\"
echo "  --branch-pattern=\"^main\$\" \\"
echo "  --build-config=cloudbuild-fast.yaml"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
