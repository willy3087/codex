#!/bin/bash
set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

WRAPPER_URL="https://wrapper-467992722695.us-central1.run.app"
MCP_URL="https://mcp-pipedrive-467992722695.us-central1.run.app"
GATEWAY_API_KEY="IxF3WoAB6IBrNJKrC/Jsr5yjt2bXHZkBSHFDBhcIVvc="

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Teste de Integração Wrapper + MCP Pipedrive${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Wrapper URL:${NC} $WRAPPER_URL"
echo -e "${YELLOW}MCP URL:${NC} $MCP_URL"
echo ""

# Verificar se os serviços estão online
echo -e "${BLUE}[1/5] Verificando se os serviços estão online...${NC}"

echo -n "  - Wrapper: "
if curl -s --max-time 5 "$WRAPPER_URL/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Online${NC}"
else
    echo -e "${RED}✗ Offline ou sem resposta${NC}"
    exit 1
fi

echo -n "  - MCP Pipedrive: "
if curl -s --max-time 5 "$MCP_URL/health" > /dev/null 2>&1 || curl -s --max-time 5 "$MCP_URL" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Online${NC}"
else
    echo -e "${YELLOW}⚠ Sem resposta (pode ser normal para MCP)${NC}"
fi

echo ""

# Criar payload de teste
echo -e "${BLUE}[2/5] Criando payload de teste...${NC}"

TEMP_FILE=$(mktemp)
cat > "$TEMP_FILE" << 'EOF'
{
  "mode": "mcp",
  "mcp_config": {
    "server_url": "https://mcp-pipedrive-467992722695.us-central1.run.app",
    "transport": "sse",
    "command": "list_tools"
  },
  "task": "List all available tools from Pipedrive MCP server",
  "timeout": 30
}
EOF

echo -e "  ${GREEN}✓${NC} Payload criado em: $TEMP_FILE"
echo ""
echo -e "${YELLOW}Conteúdo do payload:${NC}"
cat "$TEMP_FILE" | jq '.'
echo ""

# Enviar requisição para o wrapper
echo -e "${BLUE}[3/5] Enviando requisição para o wrapper...${NC}"

RESPONSE_FILE=$(mktemp)
HTTP_CODE=$(curl -s -w "%{http_code}" -o "$RESPONSE_FILE" \
  -X POST "$WRAPPER_URL/api/execute" \
  -H "Content-Type: application/json" \
  -H "X-Gateway-Key: $GATEWAY_API_KEY" \
  -d @"$TEMP_FILE" \
  --max-time 60)

echo -e "  HTTP Status Code: ${YELLOW}$HTTP_CODE${NC}"
echo ""

# Analisar resposta
echo -e "${BLUE}[4/5] Analisando resposta...${NC}"

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo -e "${GREEN}✓ Requisição bem-sucedida${NC}"
    echo ""
    echo -e "${YELLOW}Resposta completa:${NC}"
    cat "$RESPONSE_FILE" | jq '.' 2>/dev/null || cat "$RESPONSE_FILE"

    # Verificar se contém informações de tools do MCP
    if grep -q "tools\|list_tools\|capabilities" "$RESPONSE_FILE"; then
        echo ""
        echo -e "${GREEN}✓ Resposta contém informações de tools/capabilities do MCP${NC}"
        MCP_SUCCESS=true
    else
        echo ""
        echo -e "${YELLOW}⚠ Resposta não contém informações esperadas do MCP${NC}"
        MCP_SUCCESS=false
    fi
else
    echo -e "${RED}✗ Requisição falhou${NC}"
    echo ""
    echo -e "${YELLOW}Resposta de erro:${NC}"
    cat "$RESPONSE_FILE"
    MCP_SUCCESS=false
fi

echo ""

# Diagnóstico
echo -e "${BLUE}[5/5] Diagnóstico...${NC}"
echo ""

if [ "$MCP_SUCCESS" = true ]; then
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ SUCESSO: Wrapper conseguiu usar o MCP${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Por quê funcionou:${NC}"
    echo "  1. ✓ Wrapper está online e acessível"
    echo "  2. ✓ MCP Pipedrive está respondendo"
    echo "  3. ✓ Comunicação entre wrapper e MCP estabelecida"
    echo "  4. ✓ Protocolo MCP implementado corretamente"
    echo "  5. ✓ Wrapper consegue listar tools/capabilities do MCP"
    EXIT_CODE=0
else
    echo -e "${RED}═══════════════════════════════════════${NC}"
    echo -e "${RED}✗ FALHA: Wrapper NÃO conseguiu usar o MCP${NC}"
    echo -e "${RED}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Possíveis causas:${NC}"
    echo ""

    if [ "$HTTP_CODE" = "404" ]; then
        echo "  ${RED}✗${NC} Endpoint /api/execute não encontrado"
        echo "    → Verificar se o wrapper implementa este endpoint"
        echo "    → Verificar roteamento no wrapper"
    elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
        echo "  ${RED}✗${NC} Problema de autenticação/autorização"
        echo "    → Verificar token de autenticação"
        echo "    → Verificar políticas de acesso"
    elif [ "$HTTP_CODE" = "500" ]; then
        echo "  ${RED}✗${NC} Erro interno no wrapper"
        echo "    → Verificar logs do wrapper"
        echo "    → Verificar se MCP mode está implementado"
    elif [ "$HTTP_CODE" = "000" ]; then
        echo "  ${RED}✗${NC} Timeout ou falha de conexão"
        echo "    → Verificar se wrapper está realmente online"
        echo "    → Verificar firewall/networking"
    else
        echo "  ${YELLOW}⚠${NC} Código HTTP inesperado: $HTTP_CODE"
    fi

    echo ""
    echo "  ${YELLOW}⚠${NC} Wrapper pode não ter implementação do modo MCP"
    echo "    → Verificar se wrapper-cloud-run/src/main.rs tem handler MCP"
    echo "    → Verificar se mcp_connection_manager está sendo usado"
    echo ""
    echo "  ${YELLOW}⚠${NC} URL do MCP pode estar incorreta ou inacessível"
    echo "    → Testar acesso direto: curl $MCP_URL"
    echo "    → Verificar se MCP aceita conexões do wrapper"
    echo ""
    echo "  ${YELLOW}⚠${NC} Protocolo de comunicação pode estar incorreto"
    echo "    → MCP pode esperar WebSocket ao invés de SSE"
    echo "    → Verificar formato esperado pelo MCP"

    EXIT_CODE=1
fi

echo ""
echo -e "${BLUE}Arquivos temporários:${NC}"
echo "  - Request: $TEMP_FILE"
echo "  - Response: $RESPONSE_FILE"
echo ""
echo -e "${YELLOW}Para debugar mais, execute:${NC}"
echo "  cat $RESPONSE_FILE | jq '.'"
echo ""

# Cleanup opcional
# rm -f "$TEMP_FILE" "$RESPONSE_FILE"

exit $EXIT_CODE
