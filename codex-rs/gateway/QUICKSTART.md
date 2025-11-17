# Quickstart - Codex Gateway

Guia rápido para colocar o Codex Gateway em produção em 5 minutos.

## 🚀 Deploy Rápido com Docker Compose

### 1. Configurar Environment Variables

```bash
cd codex-rs/gateway

# Copiar template
cp .env.example .env

# Editar com seus valores
nano .env
```

Preencha pelo menos:
```bash
OPENAI_API_KEY=sk-proj-your-key-here
GATEWAY_API_KEY=$(openssl rand -hex 32)
OAUTH_CLIENT_SECRET=$(openssl rand -hex 32)
```

### 2. Verificar Configuração

```bash
# Verificar config.toml
cat config/config.toml

# Deve mostrar:
# model = "gpt-4o"
# model_provider = "openai-chat-completions"
```

### 3. Deploy

```bash
# Build e start
docker-compose up -d

# Ver logs
docker-compose logs -f gateway

# Verificar saúde
curl http://localhost:3000/health
```

### 4. Testar

```bash
# Definir API key
export API_KEY="your-gateway-api-key-from-env"

# Testar JSON-RPC
curl -X POST http://localhost:3000/jsonrpc \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  -d '{"jsonrpc":"2.0","method":"conversation.prompt","params":{"prompt":"Say hello"},"id":1}'

# Testar Exec
curl -X POST http://localhost:3000/exec \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  -d '{"prompt":"Write hello function"}'

# Testar OAuth
curl "http://localhost:3000/oauth/authorize?response_type=code&client_id=codex-gateway-client&redirect_uri=http://localhost/callback&state=test"
```

## ☁️ Deploy em Cloud (Google Cloud Run)

### Pré-requisitos
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

### Deploy em 3 comandos

```bash
# 1. Build no Cloud Build
gcloud builds submit --tag gcr.io/$(gcloud config get-value project)/codex-gateway

# 2. Criar secrets
echo -n "sk-proj-your-key" | gcloud secrets create openai-api-key --data-file=-
echo -n "$(openssl rand -hex 32)" | gcloud secrets create gateway-api-key --data-file=-
echo -n "$(openssl rand -hex 32)" | gcloud secrets create oauth-client-secret --data-file=-

# 3. Deploy
gcloud run deploy codex-gateway \
  --image gcr.io/$(gcloud config get-value project)/codex-gateway \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-secrets="OPENAI_API_KEY=openai-api-key:latest,GATEWAY_API_KEY=gateway-api-key:latest,OAUTH_CLIENT_SECRET=oauth-client-secret:latest" \
  --set-env-vars="OAUTH_CLIENT_ID=codex-gateway-client,CODEX_HOME=/home/gateway/.codex" \
  --memory 1Gi \
  --cpu 2
```

### Obter URL
```bash
gcloud run services describe codex-gateway \
  --platform managed \
  --region us-central1 \
  --format 'value(status.url)'
```

## 🔧 Comandos Úteis

### Docker Compose

```bash
# Start
docker-compose up -d

# Stop
docker-compose down

# Rebuild
docker-compose up -d --build

# Ver logs
docker-compose logs -f

# Reiniciar serviço
docker-compose restart gateway

# Ver status
docker-compose ps
```

### Docker Standalone

```bash
# Ver logs
docker logs -f codex-gateway

# Entrar no container
docker exec -it codex-gateway sh

# Ver processos
docker top codex-gateway

# Ver uso de recursos
docker stats codex-gateway

# Reiniciar
docker restart codex-gateway
```

## 📊 Verificação de Saúde

```bash
# Script de verificação completa
./scripts/test_gateway.sh

# Health check
curl http://localhost:3000/health

# Verificar config carregada
docker logs codex-gateway 2>&1 | grep "model="

# Deve mostrar: model=gpt-4o
```

## 🔐 Configurar ChatGPT GPT Actions

1. Obter credenciais OAuth:
```bash
# Client ID
echo "codex-gateway-client"

# Client Secret
grep OAUTH_CLIENT_SECRET .env | cut -d= -f2
```

2. No ChatGPT GPT Builder:
   - Authentication: OAuth
   - Auth URL: `https://your-domain.com/oauth/authorize`
   - Token URL: `https://your-domain.com/oauth/token`
   - Cole Client ID e Secret

3. Testar integração

## ⚠️ Troubleshooting Rápido

### Container não inicia
```bash
# Ver logs de erro
docker logs codex-gateway

# Verificar se porta está em uso
lsof -i :3000

# Verificar env vars
docker exec codex-gateway env | grep -E "OPENAI|CODEX"
```

### Erro 401 da OpenAI
```bash
# Verificar API key
docker exec codex-gateway sh -c 'echo $OPENAI_API_KEY | head -c 20'

# Verificar config
docker exec codex-gateway cat /home/gateway/.codex/config.toml
```

### Erro "Permission denied"
```bash
# Recriar volume com permissões corretas
docker-compose down -v
docker-compose up -d
```

## 📚 Documentação Completa

- [README.md](./README.md) - Documentação completa
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Guias de deploy detalhados
- [commad.md](./commad.md) - Exemplos de comandos

## 🆘 Ajuda

Issues: https://github.com/your-repo/issues
Docs: https://docs.your-domain.com
