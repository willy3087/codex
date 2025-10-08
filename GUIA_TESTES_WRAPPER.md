# 🧪 Guia de Testes - Codex Cloud Wrapper

## ✅ Pré-requisitos

Certifique-se de estar autenticado:
```bash
gcloud auth login adm@nexcode.live
gcloud config set project elaihub-prod
```

## 🔍 1. Teste de Health Check

Verifica se o serviço está respondendo:

```bash
curl -s https://wrapper-elai-467992722695.southamerica-east1.run.app/health
```

**Resultado esperado:**
```
OK
```

---

## 🧮 2. Teste Básico - "What is 2+2?"

Teste simples para verificar se o wrapper está funcionando:

```bash
curl -X POST https://wrapper-elai-467992722695.southamerica-east1.run.app/api/v1/exec/stream \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "X-Gateway-Key: IxF3WoAB6IBrNJKrC/Jsr5yjt2bXHZkBSHFDBhcIVvc=" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "What is 2+2?", "model": "gpt-4o-mini"}' \
  --no-buffer
```

**Resultado esperado:**
- Stream de eventos SSE
- Resposta final: `4`
- Status: `tokens used: XXXX`

---

## 🏢 3. Teste com Pipedrive MCP

Teste de integração com o MCP do Pipedrive:

```bash
curl -X POST https://wrapper-elai-467992722695.southamerica-east1.run.app/api/v1/exec/stream \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "X-Gateway-Key: IxF3WoAB6IBrNJKrC/Jsr5yjt2bXHZkBSHFDBhcIVvc=" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Liste os últimos 5 negócios do Pipedrive mostrando título e valor",
    "model": "gpt-4o-mini"
  }' \
  --no-buffer
```

**Resultado esperado:**
- Conexão com MCP Pipedrive
- Lista de negócios com títulos e valores
- Status de sucesso

---

## 🖥️ 4. Teste via CLI Local (codex-cloud)

### 4.1. Teste simples

```bash
cd /Users/williamduarte/NCMproduto/codex/codex-rs
./target/release/codex-cloud exec "What is 2+2?"
```

### 4.2. Teste com Pipedrive

```bash
./target/release/codex-cloud exec "Liste os últimos 5 negócios do Pipedrive mostrando título e valor"
```

### 4.3. Teste de criação de negócio

```bash
./target/release/codex-cloud exec "Crie um negócio no Pipedrive com título 'Teste Cloud Wrapper' e valor R$ 10.000"
```

---

## 📊 5. Teste de Performance

Teste com timeout maior para operações complexas:

```bash
curl -X POST https://wrapper-elai-467992722695.southamerica-east1.run.app/api/v1/exec/stream \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "X-Gateway-Key: IxF3WoAB6IBrNJKrC/Jsr5yjt2bXHZkBSHFDBhcIVvc=" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Analise os últimos 10 negócios do Pipedrive e me dê um resumo do valor total e média",
    "model": "gpt-4o-mini",
    "timeout_ms": 120000
  }' \
  --no-buffer
```

---

## 🔐 6. Teste de Autenticação

### 6.1. Sem token (deve falhar)

```bash
curl -X POST https://wrapper-elai-467992722695.southamerica-east1.run.app/api/v1/exec/stream \
  -H "Content-Type: application/json" \
  -d '{"prompt": "test"}' \
  --no-buffer
```

**Resultado esperado:** `401 Unauthorized`

### 6.2. Com token mas sem Gateway Key (deve falhar)

```bash
curl -X POST https://wrapper-elai-467992722695.southamerica-east1.run.app/api/v1/exec/stream \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "test"}' \
  --no-buffer
```

**Resultado esperado:** `401 Unauthorized` ou `403 Forbidden`

---

## 📝 7. Script de Teste Completo

Crie um arquivo `test-all.sh`:

```bash
#!/bin/bash

echo "🧪 Iniciando testes do Codex Cloud Wrapper..."
echo ""

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# URL do serviço
SERVICE_URL="https://wrapper-elai-467992722695.southamerica-east1.run.app"

# Obtém token
echo "📝 Obtendo token de autenticação..."
TOKEN=$(gcloud auth print-identity-token)
if [ -z "$TOKEN" ]; then
  echo -e "${RED}❌ Erro ao obter token${NC}"
  exit 1
fi
echo -e "${GREEN}✅ Token obtido${NC}"
echo ""

# Teste 1: Health Check
echo "🔍 Teste 1: Health Check"
HEALTH=$(curl -s "$SERVICE_URL/health")
if [ "$HEALTH" = "OK" ]; then
  echo -e "${GREEN}✅ Health check passou${NC}"
else
  echo -e "${RED}❌ Health check falhou: $HEALTH${NC}"
fi
echo ""

# Teste 2: Teste básico
echo "🧮 Teste 2: What is 2+2?"
RESULT=$(curl -s -X POST "$SERVICE_URL/api/v1/exec/stream" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Gateway-Key: IxF3WoAB6IBrNJKrC/Jsr5yjt2bXHZkBSHFDBhcIVvc=" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "What is 2+2?", "model": "gpt-4o-mini"}' \
  --no-buffer 2>&1 | grep -o "data: 4" | head -1)

if [[ $RESULT == *"4"* ]]; then
  echo -e "${GREEN}✅ Teste básico passou (resposta: 4)${NC}"
else
  echo -e "${YELLOW}⚠️  Teste básico inconclusivo${NC}"
fi
echo ""

# Teste 3: Pipedrive
echo "🏢 Teste 3: Integração Pipedrive"
echo "   Enviando requisição..."
curl -s -X POST "$SERVICE_URL/api/v1/exec/stream" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Gateway-Key: IxF3WoAB6IBrNJKrC/Jsr5yjt2bXHZkBSHFDBhcIVvc=" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Liste os últimos 3 negócios do Pipedrive", "model": "gpt-4o-mini"}' \
  --no-buffer 2>&1 | head -50
echo ""
echo -e "${GREEN}✅ Teste Pipedrive executado${NC}"
echo ""

# Resumo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Resumo dos Testes"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Serviço: $SERVICE_URL"
echo "   Todos os testes concluídos!"
echo ""
```

Torne executável e rode:

```bash
chmod +x test-all.sh
./test-all.sh
```

---

## 🐛 8. Troubleshooting

### Ver logs em tempo real

```bash
gcloud run services logs read wrapper-elai \
  --region=southamerica-east1 \
  --project=elaihub-prod \
  --limit=50
```

### Ver últimos erros

```bash
gcloud run services logs read wrapper-elai \
  --region=southamerica-east1 \
  --project=elaihub-prod \
  --filter="severity>=ERROR" \
  --limit=20
```

### Verificar variáveis de ambiente

```bash
gcloud run services describe wrapper-elai \
  --region=southamerica-east1 \
  --project=elaihub-prod \
  --format="yaml(spec.template.spec.containers[0].env)"
```

---

## 📈 9. Métricas

Ver métricas no console:
```
https://console.cloud.google.com/run/detail/southamerica-east1/wrapper-elai/metrics?project=elaihub-prod
```

---

## ✅ Checklist de Sucesso

- [ ] Health check retorna `OK`
- [ ] Teste básico (2+2) retorna `4`
- [ ] Integração Pipedrive funciona
- [ ] CLI local (`codex-cloud`) conecta com sucesso
- [ ] Logs não mostram erros críticos
- [ ] Latência < 2 segundos para respostas simples
- [ ] Timeout configurado funciona corretamente

---

**Data de criação:** 2025-10-06
**Versão do Wrapper:** v3-final
**Imagem:** `us-central1-docker.pkg.dev/elaihub-prod/codex-wrapper/wrapper:latest`
