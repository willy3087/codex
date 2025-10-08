#!/bin/bash

set -e

PROJECT_ID="elaihub-prod"
REGION="us-central1"
SQL_INSTANCE="sandbox"
SQL_CONNECTION_NAME="${PROJECT_ID}:${REGION}:${SQL_INSTANCE}"
SERVICE_NAME="codex-wrapper"
SERVICE_ACCOUNT="codex-wrapper-sa@${PROJECT_ID}.iam.gserviceaccount.com"

echo "🗄️  Configurando Cloud SQL para Codex Wrapper..."
echo ""
echo "Instância: ${SQL_CONNECTION_NAME}"
echo "Service Account: ${SERVICE_ACCOUNT}"
echo ""

# 1. Criar senha do PostgreSQL e salvar como secret
echo "🔐 Passo 1: Criar secret para senha do PostgreSQL"
read -sp "Digite a senha do PostgreSQL (ou ENTER para usar 'codex_sandbox_2025'): " SQL_PASSWORD
SQL_PASSWORD=${SQL_PASSWORD:-codex_sandbox_2025}
echo ""

echo -n "${SQL_PASSWORD}" | gcloud secrets create cloud-sql-password \
  --data-file=- \
  --project=${PROJECT_ID} 2>/dev/null || \
  echo -n "${SQL_PASSWORD}" | gcloud secrets versions add cloud-sql-password \
    --data-file=- \
    --project=${PROJECT_ID}

echo "✅ Secret 'cloud-sql-password' criado/atualizado"

# 2. Conceder permissões ao service account
echo ""
echo "🔑 Passo 2: Configurar permissões IAM"

# Cloud SQL Client (para conectar via proxy)
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/cloudsql.client" \
  --condition=None

# Secret Manager Secret Accessor
gcloud secrets add-iam-policy-binding cloud-sql-password \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/secretmanager.secretAccessor" \
  --project=${PROJECT_ID}

echo "✅ Permissões configuradas"

# 3. Criar banco de dados 'sandbox' (se não existir)
echo ""
echo "📊 Passo 3: Criar banco de dados 'sandbox'"

# Primeiro, obter a senha root do PostgreSQL
echo "Obtendo senha root do Cloud SQL..."
ROOT_PASSWORD=$(gcloud sql users list \
  --instance=${SQL_INSTANCE} \
  --project=${PROJECT_ID} \
  --format="value(name)" | grep postgres || echo "")

if [ -z "$ROOT_PASSWORD" ]; then
    echo "⚠️  Usuário postgres não encontrado. Criando..."
    gcloud sql users set-password postgres \
      --instance=${SQL_INSTANCE} \
      --password="${SQL_PASSWORD}" \
      --project=${PROJECT_ID}
fi

# Criar database
echo "Criando database 'sandbox'..."
gcloud sql databases create sandbox \
  --instance=${SQL_INSTANCE} \
  --project=${PROJECT_ID} 2>/dev/null || echo "ℹ️  Database 'sandbox' já existe"

echo "✅ Database configurado"

# 4. Mostrar informações de conexão
echo ""
echo "📋 Informações de Conexão:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Connection Name: ${SQL_CONNECTION_NAME}"
echo "Database: sandbox"
echo "User: postgres"
echo "Password: (secret: cloud-sql-password)"
echo ""
echo "Via Unix Socket (Cloud Run):"
echo "  postgresql://postgres@localhost/sandbox?host=/cloudsql/${SQL_CONNECTION_NAME}"
echo ""
echo "Via IP Público (desenvolvimento):"
echo "  postgresql://postgres:${SQL_PASSWORD}@136.112.247.204:5432/sandbox"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 5. Instruções para deploy
echo ""
echo "🚀 Próximo Passo: Deploy do Cloud Run"
echo ""
echo "Execute o seguinte comando para fazer deploy:"
echo ""
cat << 'EOF'
gcloud run deploy codex-wrapper \
  --image us-central1-docker.pkg.dev/elaihub-prod/codex-wrapper/wrapper:latest \
  --region us-central1 \
  --platform managed \
  --add-cloudsql-instances elaihub-prod:us-central1:sandbox \
  --set-env-vars "DATABASE_URL=postgresql://postgres@localhost/sandbox?host=/cloudsql/elaihub-prod:us-central1:sandbox" \
  --set-secrets "CLOUD_SQL_PASSWORD=cloud-sql-password:latest" \
  --update-secrets "GATEWAY_API_KEY=gateway-api-key-codex:latest,OPENAI_API_KEY=openai-api-key:latest,PIPEDRIVE_API_TOKEN=pipedrive-api-token-codex:latest" \
  --project elaihub-prod
EOF

echo ""
echo "✅ Setup concluído!"
