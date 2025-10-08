#!/bin/bash
# Teste simplificado - verifica se MCP é mencionado nos logs

WRAPPER_URL="https://wrapper-467992722695.us-central1.run.app"
GATEWAY_API_KEY="IxF3WoAB6IBrNJKrC/Jsr5yjt2bXHZkBSHFDBhcIVvc="

echo "🧪 Teste MCP Pipedrive - Versão Simplificada"
echo "============================================"
echo ""

TEMP_FILE=$(mktemp)
cat > "$TEMP_FILE" << 'EOF'
{
  "prompt": "Use the pipedrive MCP server to list all available tools",
  "timeout_ms": 90000,
  "session_id": "test-mcp-simple",
  "allow_network": true
}
EOF

echo "📤 Enviando requisição..."
RESPONSE=$(mktemp)

curl -s -N -X POST "$WRAPPER_URL/api/v1/exec/stream" \
  -H "Content-Type: application/json" \
  -H "X-Gateway-Key: $GATEWAY_API_KEY" \
  -d @"$TEMP_FILE" \
  --max-time 100 > "$RESPONSE" 2>&1

echo ""
echo "📊 Analisando resposta..."
echo ""

# Procurar por indicadores de sucesso MCP
if grep -qi "mcp.*connected\|mcp.*server.*loaded\|mcp_servers\|pipedrive.*tools" "$RESPONSE"; then
    echo "✅ SUCESSO: MCP foi carregado e usado!"
    grep -i "mcp\|pipedrive" "$RESPONSE" | head -20
    exit 0
elif grep -qi "mcp.*not found\|no mcp\|config.toml not found" "$RESPONSE"; then
    echo "❌ FALHA: Config não foi carregado"
    echo ""
    echo "Linhas relevantes:"
    grep -i "config\|mcp" "$RESPONSE" | head -10
    exit 1
elif grep -qi "python.*not found\|node.*not found.*npm.*not found" "$RESPONSE"; then
    echo "⚠️  AINDA IMPROVISANDO: Codex ainda tentando instalar ferramentas"
    echo ""
    echo "Isso significa que o config.toml não foi encontrado."
    echo "O fix no process.rs ainda não está em produção."
    exit 1
else
    echo "❓ Resultado inconclusivo"
    echo ""
    echo "Preview da resposta:"
    head -50 "$RESPONSE"
    exit 2
fi
