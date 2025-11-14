#!/bin/bash
# Script para executar no Cloud Shell (tem mais permissões)
# Ou execute estes comandos diretamente se você tem Owner/IAM Admin

PROJECT_ID="elaihub-prod"
SERVICE_ACCOUNT="467992722695-compute@developer.gserviceaccount.com"

echo "Adicionando permissões para Cloud Build..."

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/iam.serviceAccountUser"

echo "Permissões adicionadas com sucesso!"
