#!/bin/bash
set -e

echo "=== Teste Completo do BFF Codex com Protocol v1 ==="
echo ""

# Configuração
BFF_URL="http://localhost:3456"
API_KEY="${OPENAI_API_KEY:-your-api-key-here}"

echo "1. Testando Health Check..."
curl -s "$BFF_URL/health" | jq '.' || echo "Health check falhou"
echo ""

echo "2. Testando Status..."
curl -s "$BFF_URL/api/status" | jq '.' || echo "Status falhou"
echo ""

echo "3. Testando Protocol v1 - Criar Sessão..."
SESSION_RESPONSE=$(curl -s -X POST "$BFF_URL/api/v1/session" \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: $API_KEY")
echo "$SESSION_RESPONSE" | jq '.' || echo "Criar sessão falhou"
echo ""

echo "4. Testando Protocol v1 - Submit Operation (UserInput)..."
curl -s -X POST "$BFF_URL/api/v1/submit" \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: $API_KEY" \
  -d '{
    "sub_id": "test-001",
    "op": {
      "UserInput": {
        "items": [{
          "Text": {
            "text": "What is 2+2?"
          }
        }]
      }
    }
  }' | jq '.' || echo "Submit operation falhou"
echo ""

echo "5. Testando Execução de Comando Simples..."
curl -s -X POST "$BFF_URL/api/exec" \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: $API_KEY" \
  -d '{"prompt": "What is the capital of France?", "timeout_seconds": 30}' \
  | jq '.' || echo "Exec falhou"
echo ""

echo "6. Testando Criação de Arquivo com Python..."
curl -s -X POST "$BFF_URL/api/exec" \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: $API_KEY" \
  -d '{"prompt": "Create a Python file in /tmp called bff-test.py with a function that returns Hello BFF", "timeout_seconds": 30}' \
  | jq '.' || echo "Criação de arquivo falhou"
echo ""

echo "7. Testando WebSocket (verificando handshake)..."
WS_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  "$BFF_URL/ws")
echo "WebSocket response code: $WS_CODE"
echo ""

echo "8. Testando lista de conexões WebSocket..."
curl -s "$BFF_URL/ws/connections" | jq '.' || echo "Lista de conexões falhou"
echo ""

echo "9. Testando broadcast para WebSockets..."
curl -s -X POST "$BFF_URL/ws/broadcast" \
  -H "Content-Type: application/json" \
  -d '{"message": "System broadcast test"}' | jq '.' || echo "Broadcast falhou"
echo ""

echo "10. Verificando Stream de Eventos SSE (timeout esperado)..."
timeout 2 curl -s -N "$BFF_URL/api/v1/events" || echo "SSE timeout (normal)"
echo ""

echo "=== Teste Concluído ==="

# Se o container estiver rodando, mostrar últimas linhas do log
if docker ps | grep -q codex-bff-test; then
    echo ""
    echo "Últimas 10 linhas do log do container:"
    docker logs --tail 10 codex-bff-test
fi