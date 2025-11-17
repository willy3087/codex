# Deployment Guide - Codex Gateway

Guia completo para deploy do Codex Gateway em diferentes plataformas cloud.

## 📋 Pré-requisitos

- Docker instalado
- Conta na plataforma cloud (GCP, Azure, ou AWS)
- API Keys configuradas (OpenAI)
- Domínio e SSL (para produção)

## 🚀 Deploy Rápido

### Opção 1: Docker Compose (Desenvolvimento/Staging)

```bash
# 1. Clone o repositório
cd codex/codex-rs/gateway

# 2. Configure environment variables
cp .env.example .env
# Edite .env com suas credenciais

# 3. Certifique-se que config/config.toml existe
cat config/config.toml
# Deve conter a configuração do OpenAI GPT-4o

# 4. Build e deploy
docker-compose up -d

# 5. Verifique saúde
curl http://localhost:3000/health

# 6. Teste endpoint
curl -X POST http://localhost:3000/jsonrpc \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{"jsonrpc":"2.0","method":"conversation.prompt","params":{"prompt":"Hello"},"id":1}'
```

### Opção 2: Docker Standalone

```bash
# Build
docker build -t codex-gateway -f Dockerfile ../..

# Run com todas as configurações
docker run -d \
  --name codex-gateway \
  -p 3000:8080 \
  -e OPENAI_API_KEY=sk-proj-... \
  -e GATEWAY_API_KEY=$(openssl rand -hex 32) \
  -e OAUTH_CLIENT_ID=codex-gateway-client \
  -e OAUTH_CLIENT_SECRET=$(openssl rand -hex 32) \
  -e RUST_LOG=info,codex_gateway=debug \
  -e CODEX_HOME=/home/gateway/.codex \
  -v codex-home:/home/gateway/.codex \
  -v $(pwd)/config/config.toml:/home/gateway/.codex/config.toml:ro \
  codex-gateway

# Logs
docker logs -f codex-gateway
```

## ☁️ Deploy em Cloud Providers

### Google Cloud Platform (Cloud Run)

#### 1. Preparação

```bash
# Configurar projeto
gcloud config set project YOUR_PROJECT_ID
export PROJECT_ID=$(gcloud config get-value project)

# Habilitar APIs necessárias
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  secretmanager.googleapis.com \
  containerregistry.googleapis.com
```

#### 2. Configurar Secrets

```bash
# Criar secrets no Secret Manager
echo -n "sk-proj-your-openai-key" | \
  gcloud secrets create openai-api-key --data-file=-

echo -n "$(openssl rand -hex 32)" | \
  gcloud secrets create gateway-api-key --data-file=-

echo -n "$(openssl rand -hex 32)" | \
  gcloud secrets create oauth-client-secret --data-file=-

# Dar permissão ao Cloud Run
gcloud secrets add-iam-policy-binding openai-api-key \
  --member="serviceAccount:${PROJECT_ID}@appspot.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

gcloud secrets add-iam-policy-binding gateway-api-key \
  --member="serviceAccount:${PROJECT_ID}@appspot.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

gcloud secrets add-iam-policy-binding oauth-client-secret \
  --member="serviceAccount:${PROJECT_ID}@appspot.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

#### 3. Build e Deploy

```bash
# Build no Cloud Build
gcloud builds submit --tag gcr.io/${PROJECT_ID}/codex-gateway

# Deploy no Cloud Run
gcloud run deploy codex-gateway \
  --image gcr.io/${PROJECT_ID}/codex-gateway \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-secrets="OPENAI_API_KEY=openai-api-key:latest,GATEWAY_API_KEY=gateway-api-key:latest,OAUTH_CLIENT_SECRET=oauth-client-secret:latest" \
  --set-env-vars="OAUTH_CLIENT_ID=codex-gateway-client,RUST_LOG=info,codex_gateway=debug,CODEX_HOME=/home/gateway/.codex" \
  --memory 1Gi \
  --cpu 2 \
  --min-instances 1 \
  --max-instances 10 \
  --timeout 300 \
  --concurrency 80

# Obter URL do serviço
gcloud run services describe codex-gateway \
  --platform managed \
  --region us-central1 \
  --format 'value(status.url)'
```

#### 4. Configurar Domínio Customizado

```bash
# Mapear domínio
gcloud run domain-mappings create \
  --service codex-gateway \
  --domain api.your-domain.com \
  --region us-central1

# Configurar DNS conforme instruções do GCP
```

### Azure Container Apps

#### 1. Preparação

```bash
# Variáveis
RESOURCE_GROUP="codex-gateway-rg"
LOCATION="eastus"
ACR_NAME="codexgatewayacr"
APP_NAME="codex-gateway"

# Criar resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Criar Azure Container Registry
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic

# Login no ACR
az acr login --name $ACR_NAME
```

#### 2. Build e Push

```bash
# Build local e push
docker build -t codex-gateway -f Dockerfile ../..
docker tag codex-gateway ${ACR_NAME}.azurecr.io/codex-gateway:latest
docker push ${ACR_NAME}.azurecr.io/codex-gateway:latest

# Ou build direto no ACR (recomendado)
az acr build \
  --registry $ACR_NAME \
  --image codex-gateway:latest \
  --file Dockerfile \
  ../..
```

#### 3. Criar Container Apps Environment

```bash
# Criar environment
az containerapp env create \
  --name codex-gateway-env \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

# Criar Key Vault para secrets
az keyvault create \
  --name codex-gateway-kv \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

# Adicionar secrets
az keyvault secret set \
  --vault-name codex-gateway-kv \
  --name openai-api-key \
  --value "sk-proj-your-key"

az keyvault secret set \
  --vault-name codex-gateway-kv \
  --name gateway-api-key \
  --value "$(openssl rand -hex 32)"

az keyvault secret set \
  --vault-name codex-gateway-kv \
  --name oauth-client-secret \
  --value "$(openssl rand -hex 32)"
```

#### 4. Deploy Container App

```bash
az containerapp create \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment codex-gateway-env \
  --image ${ACR_NAME}.azurecr.io/codex-gateway:latest \
  --target-port 8080 \
  --ingress external \
  --registry-server ${ACR_NAME}.azurecr.io \
  --env-vars \
    OAUTH_CLIENT_ID=codex-gateway-client \
    RUST_LOG=info,codex_gateway=debug \
    CODEX_HOME=/home/gateway/.codex \
  --secrets \
    openai-api-key=keyvaultref:https://codex-gateway-kv.vault.azure.net/secrets/openai-api-key,identityref:system \
    gateway-api-key=keyvaultref:https://codex-gateway-kv.vault.azure.net/secrets/gateway-api-key,identityref:system \
    oauth-client-secret=keyvaultref:https://codex-gateway-kv.vault.azure.net/secrets/oauth-client-secret,identityref:system \
  --cpu 1.0 \
  --memory 2Gi \
  --min-replicas 1 \
  --max-replicas 10

# Obter URL
az containerapp show \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query properties.configuration.ingress.fqdn
```

### AWS (ECS Fargate)

#### 1. Preparação

```bash
# Variáveis
AWS_REGION="us-east-1"
ECR_REPO="codex-gateway"
CLUSTER_NAME="codex-gateway-cluster"
SERVICE_NAME="codex-gateway-service"

# Criar ECR repository
aws ecr create-repository \
  --repository-name $ECR_REPO \
  --region $AWS_REGION

# Login no ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com
```

#### 2. Build e Push

```bash
# Build e tag
docker build -t codex-gateway -f Dockerfile ../..
docker tag codex-gateway:latest \
  $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:latest

# Push
docker push \
  $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:latest
```

#### 3. Configurar Secrets Manager

```bash
# Criar secrets
aws secretsmanager create-secret \
  --name codex-gateway/openai-api-key \
  --secret-string "sk-proj-your-key" \
  --region $AWS_REGION

aws secretsmanager create-secret \
  --name codex-gateway/gateway-api-key \
  --secret-string "$(openssl rand -hex 32)" \
  --region $AWS_REGION

aws secretsmanager create-secret \
  --name codex-gateway/oauth-client-secret \
  --secret-string "$(openssl rand -hex 32)" \
  --region $AWS_REGION
```

#### 4. Criar Task Definition e Deploy

Ver `task-definition.json` para exemplo completo.

```bash
# Criar ECS cluster
aws ecs create-cluster \
  --cluster-name $CLUSTER_NAME \
  --region $AWS_REGION

# Registrar task definition
aws ecs register-task-definition \
  --cli-input-json file://task-definition.json \
  --region $AWS_REGION

# Criar serviço
aws ecs create-service \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --task-definition codex-gateway \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}" \
  --region $AWS_REGION
```

## 🔧 Configuração Pós-Deploy

### 1. Testar Endpoints

```bash
# Substitua URL pelo seu endpoint de produção
export GATEWAY_URL="https://your-domain.com"
export API_KEY="your-gateway-api-key"

# Health check
curl $GATEWAY_URL/health

# JSON-RPC
curl -X POST $GATEWAY_URL/jsonrpc \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  -d '{"jsonrpc":"2.0","method":"conversation.prompt","params":{"prompt":"Hello"},"id":1}'

# OAuth
curl "$GATEWAY_URL/oauth/authorize?response_type=code&client_id=codex-gateway-client&redirect_uri=https://example.com/callback&state=test"
```

### 2. Configurar ChatGPT GPT Actions

No ChatGPT GPT Builder:

1. **Authentication Type**: OAuth
2. **Authorization URL**: `https://your-domain.com/oauth/authorize`
3. **Token URL**: `https://your-domain.com/oauth/token`
4. **Client ID**: `codex-gateway-client`
5. **Client Secret**: (valor do OAUTH_CLIENT_SECRET)
6. **Scope**: (deixar vazio ou usar `read write`)

### 3. Monitoramento

#### Cloud Run (GCP)

```bash
# Logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=codex-gateway" \
  --limit 100 \
  --format json

# Métricas
gcloud monitoring dashboards create --config-from-file=dashboard.json
```

#### Azure Container Apps

```bash
# Logs
az containerapp logs show \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --follow

# Métricas
az monitor metrics list \
  --resource $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --resource-type Microsoft.App/containerApps
```

## 🔐 Segurança em Produção

### 1. HTTPS/TLS

- **GCP Cloud Run**: SSL automático
- **Azure Container Apps**: SSL automático
- **AWS**: Use ALB com certificado ACM

### 2. Secrets Management

- Nunca commitar `.env` com valores reais
- Usar secrets managers nativos da cloud
- Rotacionar secrets regularmente

### 3. Rate Limiting

Configure no nível do load balancer:
- GCP: Cloud Armor
- Azure: Application Gateway
- AWS: WAF

### 4. Network Security

- Usar VPC/VNET privadas quando possível
- Configurar security groups apropriados
- Habilitar logging de acesso

## 📊 Escalabilidade

### Configurações Recomendadas

| Ambiente | CPU | Memory | Min Instances | Max Instances |
|----------|-----|--------|---------------|---------------|
| Dev | 0.5 | 512Mi | 0 | 1 |
| Staging | 1.0 | 1Gi | 1 | 3 |
| Production | 2.0 | 2Gi | 2 | 20 |

### Auto-scaling

Todas as plataformas suportam auto-scaling baseado em:
- CPU utilization (>70%)
- Memory utilization (>80%)
- Request count
- Custom metrics

## 🔄 CI/CD

### GitHub Actions Example

```yaml
name: Deploy to Cloud Run

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Cloud SDK
        uses: google-github-actions/setup-gcloud@v1
        with:
          project_id: ${{ secrets.GCP_PROJECT_ID }}
          service_account_key: ${{ secrets.GCP_SA_KEY }}
      
      - name: Build and Push
        run: |
          gcloud builds submit --tag gcr.io/${{ secrets.GCP_PROJECT_ID }}/codex-gateway
      
      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy codex-gateway \
            --image gcr.io/${{ secrets.GCP_PROJECT_ID }}/codex-gateway \
            --platform managed \
            --region us-central1
```

## 📝 Troubleshooting

Ver [README.md](./README.md#troubleshooting) para troubleshooting detalhado.

## 🆘 Suporte

- Issues: GitHub Issues
- Docs: [README.md](./README.md)
- Community: Discord/Slack
