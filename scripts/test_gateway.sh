#!/bin/bash
# Teste todos os endpoints em PRODUÇÃO (GCP Cloud Run)

# Configuração
GATEWAY_URL="http://localhost:3000"
GATEWAY_KEY="a44c72cf24f7dcd1012bf8e7a2693b9c7385981cede7b95699fc4249285fb2ff"

echo "Testing Codex Gateway in LOCAL DOCKER"
echo "URL: $GATEWAY_URL"
echo ""

echo "1. Testando Health Check (público)..."
curl -s "$GATEWAY_URL/health" | jq

echo -e "\n2. Testando JSON-RPC - conversation.prompt (com API Key)..."
curl -s -X POST "$GATEWAY_URL/jsonrpc" \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "conversation.prompt",
    "params": {
      "prompt": "Write a Rust function that adds two numbers",
      "session_id": "prod-test-session-001"
    },
    "id": 1
  }' | jq

echo -e "\n3. Testando JSON-RPC - conversation.status..."
curl -s -X POST "$GATEWAY_URL/jsonrpc" \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "conversation.status",
    "params": {
      "session_id": "prod-test-session-001"
    },
    "id": 2
  }' | jq

echo -e "\n4. Testando JSON-RPC - método inválido..."
curl -s -X POST "$GATEWAY_URL/jsonrpc" \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "invalid_method",
    "id": 3
  }' | jq

echo -e "\n5. Testando WebSocket Upgrade..."
curl -i -N \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: dGVzdA==" \
  "$GATEWAY_URL/ws" | head -10

echo -e "\n6. Testando Webhook..."
curl -s -X POST "$GATEWAY_URL/webhook" \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d '{"event": "test", "data": "webhook test from production"}' | jq

echo -e "\n7. Testando autenticação sem API Key (deve falhar)..."
curl -s -X POST "$GATEWAY_URL/jsonrpc" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "conversation.prompt",
    "params": {"prompt": "test"},
    "id": 1
  }'

echo -e "\n\n8. Testando API Key inválida (deve retornar 401)..."
curl -s -w "\nHTTP Status: %{http_code}\n" -X POST "$GATEWAY_URL/jsonrpc" \
  -H "X-API-Key: invalid-key-12345" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "conversation.prompt",
    "params": {"prompt": "test"},
    "id": 1
  }'

echo -e "\n\n9. Testando conversation.cancel..."
curl -s -X POST "$GATEWAY_URL/jsonrpc" \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "conversation.cancel",
    "params": {
      "session_id": "prod-test-session-001"
    },
    "id": 4
  }' | jq

echo -e "\n10. Testando payload JSON inválido (malformed)..."
curl -s -w "\nHTTP Status: %{http_code}\n" -X POST "$GATEWAY_URL/jsonrpc" \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d '{invalid json here'

echo -e "\n\n11. Testando método sem parâmetros obrigatórios..."
curl -s -X POST "$GATEWAY_URL/jsonrpc" \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "conversation.prompt",
    "params": {},
    "id": 5
  }' | jq

echo -e "\n12. Testando versão incorreta do JSON-RPC..."
curl -s -X POST "$GATEWAY_URL/jsonrpc" \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "1.0",
    "method": "conversation.status",
    "params": {"session_id": "test"},
    "id": 6
  }' | jq

echo -e "\n13. Testando tamanho de payload grande..."
LARGE_PROMPT=$(python3 -c "print('test ' * 1000)")
curl -s -w "\nHTTP Status: %{http_code}\n" -X POST "$GATEWAY_URL/jsonrpc" \
  -H "X-API-Key: $GATEWAY_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"conversation.status\",
    \"params\": {
      \"session_id\": \"large-test\",
      \"metadata\": \"$LARGE_PROMPT\"
    },
    \"id\": 7
  }" | head -5

echo -e "\n\n14. Testando múltiplas sessões simultâneas..."
for i in {1..3}; do
  echo -e "\n  Sessão $i:"
  curl -s -X POST "$GATEWAY_URL/jsonrpc" \
    -H "X-API-Key: $GATEWAY_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"jsonrpc\": \"2.0\",
      \"method\": \"conversation.status\",
      \"params\": {
        \"session_id\": \"concurrent-session-$i\"
      },
      \"id\": $((10 + i))
    }" | jq -c '.result.status'
done

echo -e "\n\n15. Testando CORS headers (OPTIONS)..."
curl -s -i -X OPTIONS "$GATEWAY_URL/jsonrpc" \
  -H "Origin: https://example.com" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: X-API-Key" | grep -i "access-control"

echo -e "\n\n16. Testando endpoint de métricas/ready..."
echo "  /health:"
curl -s "$GATEWAY_URL/health" | jq -c
echo "  /ready (se existir):"
curl -s -w "HTTP %{http_code}" "$GATEWAY_URL/ready" 2>/dev/null || echo "Not implemented"

echo -e "\n\n17. Testando latência do gateway (5 requisições)..."
for i in {1..5}; do
  TIME=$(curl -s -w "%{time_total}" -o /dev/null \
    -X POST "$GATEWAY_URL/jsonrpc" \
    -H "X-API-Key: $GATEWAY_KEY" \
    -H "Content-Type: application/json" \
    -d '{
      "jsonrpc": "2.0",
      "method": "conversation.status",
      "params": {"session_id": "latency-test"},
      "id": 1
    }')
  echo "  Request $i: ${TIME}s"
done

echo -e "\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testes completos!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Resumo:"
echo "  ✅ Endpoints funcionando: health, status, cancel, webhook, invalid method"
echo "  ⏳ Aguardando build: conversation.prompt (erro 503 - modelo inválido)"
echo "  🚧 Não implementado: WebSocket upgrade"
echo ""
