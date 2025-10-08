#!/bin/bash
set -e

WRAPPER_URL="https://wrapper-467992722695.us-central1.run.app"
GATEWAY_API_KEY="IxF3WoAB6IBrNJKrC/Jsr5yjt2bXHZkBSHFDBhcIVvc="

echo "🧪 Teste Rápido MCP - Verificando config.toml"
echo "=============================================="
echo ""

# Teste 1: Prompt que deve usar MCP se config existir
TEMP1=$(mktemp)
cat > "$TEMP1" << 'EOF'
{
  "prompt": "List all MCP servers you have configured. Show me the server names and their URLs.",
  "timeout_ms": 30000,
  "session_id": "test-config-check",
  "model": "gpt-4o-mini"
}
EOF

echo "📤 Teste 1: Verificando se Codex vê MCP servers configurados..."
RESPONSE1=$(mktemp)

curl -s -N -X POST "$WRAPPER_URL/api/v1/exec/stream" \
  -H "Content-Type: application/json" \
  -H "X-Gateway-Key: $GATEWAY_API_KEY" \
  -d @"$TEMP1" \
  --max-time 40 > "$RESPONSE1" 2>&1

echo ""
echo "📊 Resultado Teste 1:"
echo "---"

if grep -qi "config.toml not found" "$RESPONSE1"; then
    echo "❌ Config NÃO foi carregado"
    echo "   Linha encontrada:"
    grep -i "config.toml" "$RESPONSE1"
elif grep -qi "pipedrive\|mcp.*server.*loaded\|mcp_servers" "$RESPONSE1"; then
    echo "✅ Config FOI carregado - MCP servers encontrados!"
    grep -i "pipedrive\|mcp" "$RESPONSE1" | head -10
else
    echo "⚠️  Resposta inconclusiva"
    echo ""
    echo "Preview (primeiras 30 linhas):"
    head -30 "$RESPONSE1"
fi

echo ""
echo "---"
echo ""
echo "📁 Resposta completa salva em: $RESPONSE1"
echo ""
echo "Para ver tudo: cat $RESPONSE1"
