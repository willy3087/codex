#!/bin/bash

# Script de Deploy Manual do Wrapper
# Execute este script para fazer o deploy do wrapper atualizado

echo "🚀 Iniciando deploy do Codex Wrapper..."

# Verificar autenticação
if ! gcloud auth print-identity-token > /dev/null 2>&1; then
    echo "❌ Não autenticado. Execute: gcloud auth login adm@nexcode.live"
    exit 1
fi

echo "✅ Autenticado com sucesso"

# Fazer deploy
echo "📦 Fazendo deploy da imagem: us-central1-docker.pkg.dev/elaihub-prod/codex-wrapper/wrapper:latest"

gcloud run deploy codex-wrapper \
  --image us-central1-docker.pkg.dev/elaihub-prod/codex-wrapper/wrapper:latest \
  --region us-central1 \
  --platform managed \
  --memory 2Gi \
  --cpu 2 \
  --timeout 300 \
  --max-instances 10 \
  --set-env-vars "RUST_LOG=info,CODEX_CONFIG_PATH=/app/config.toml,CODEX_UNSAFE_ALLOW_NO_SANDBOX=true,GCS_SESSION_BUCKET=elaistore,GCS_FILES_BUCKET=elaistore" \
  --set-secrets "GATEWAY_API_KEY=gateway-api-key-codex:latest,OPENAI_API_KEY=openai-api-key:latest,PIPEDRIVE_API_TOKEN=pipedrive-api-token-codex:latest" \
  --project elaihub-prod

if [ $? -eq 0 ]; then
    echo "✅ Deploy concluído com sucesso!"
    echo ""
    echo "🧪 Testar agora:"
    echo "cd /Users/williamduarte/NCMproduto/codex/codex-rs"
    echo "./target/release/codex-cloud exec \"Liste os últimos 5 negócios do Pipedrive\""
else
    echo "❌ Erro no deploy"
    echo ""
    echo "📝 Alternativa: Deploy via Console Web"
    echo "1. Acesse: https://console.cloud.google.com/run/detail/us-central1/codex-wrapper?project=elaihub-prod"
    echo "2. Clique em 'EDIT & DEPLOY NEW REVISION'"
    echo "3. Selecione a imagem: us-central1-docker.pkg.dev/elaihub-prod/codex-wrapper/wrapper:latest"
    echo "4. Clique em 'DEPLOY'"
    exit 1
fi
