#!/bin/bash

echo "🔄 Forçando redeploy do wrapper com versão atualizada..."

# Build nova imagem com timestamp para forçar update
TIMESTAMP=$(date +%s)
IMAGE_TAG="us-central1-docker.pkg.dev/elaihub-prod/codex-wrapper/wrapper:v${TIMESTAMP}"

echo "📦 Buildando imagem: $IMAGE_TAG"

cd /Users/williamduarte/NCMproduto/codex/codex-rs/wrapper-cloud-run

# Build e push
gcloud builds submit --tag "$IMAGE_TAG" --project=elaihub-prod

echo "🚀 Fazendo deploy..."

# Deploy com a nova imagem
gcloud run deploy codex-wrapper \
  --image "$IMAGE_TAG" \
  --region us-central1 \
  --platform managed \
  --memory 2Gi \
  --cpu 2 \
  --timeout 300 \
  --max-instances 10 \
  --set-env-vars "RUST_LOG=info,CODEX_CONFIG_PATH=/app/config.toml,CODEX_UNSAFE_ALLOW_NO_SANDBOX=true,GCS_SESSION_BUCKET=elaistore,GCS_FILES_BUCKET=elaistore" \
  --set-secrets "GATEWAY_API_KEY=gateway-api-key-codex:latest,OPENAI_API_KEY=openai-api-key:latest,PIPEDRIVE_API_TOKEN=pipedrive-api-token-codex:latest" \
  --project elaihub-prod

echo "✅ Deploy concluído!"
echo ""
echo "🧪 Testar:"
echo "./target/release/codex-cloud exec 'Qual é 2+2?'"
