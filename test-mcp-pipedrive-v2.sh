#!/bin/bash
set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

WRAPPER_URL="https://wrapper-467992722695.us-central1.run.app"
MCP_URL="https://mcp-pipedrive-467992722695.us-central1.run.app"
GATEWAY_API_KEY="IxF3WoAB6IBrNJKrC/Jsr5yjt2bXHZkBSHFDBhcIVvc="

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}Teste de Integração Wrapper + MCP Pipedrive (v2)${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""
echo -e "${YELLOW}Wrapper URL:${NC} $WRAPPER_URL"
echo -e "${YELLOW}MCP URL:${NC} $MCP_URL"
echo ""
echo -e "${CYAN}Este teste verifica se o wrapper do Codex consegue usar o MCP${NC}"
echo -e "${CYAN}Pipedrive quando solicitado via prompt natural.${NC}"
echo ""

# Verificar se os serviços estão online
echo -e "${BLUE}[1/6] Verificando se os serviços estão online...${NC}"

echo -n "  - Wrapper: "
if curl -s --max-time 5 "$WRAPPER_URL/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Online${NC}"
else
    echo -e "${RED}✗ Offline ou sem resposta${NC}"
    exit 1
fi

echo -n "  - MCP Pipedrive: "
MCP_STATUS=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" "$MCP_URL" 2>&1)
if [ "$MCP_STATUS" = "200" ] || [ "$MCP_STATUS" = "404" ] || [ "$MCP_STATUS" = "405" ]; then
    echo -e "${GREEN}✓ Online (HTTP $MCP_STATUS)${NC}"
else
    echo -e "${YELLOW}⚠ Status: $MCP_STATUS${NC}"
fi

echo ""

# Criar payload de teste
echo -e "${BLUE}[2/6] Criando payload de teste...${NC}"

TEMP_FILE=$(mktemp)
cat > "$TEMP_FILE" << EOF
{
  "prompt": "Connect to the MCP server at $MCP_URL and list all available tools. Use SSE transport. Show me what capabilities this MCP server provides.",
  "timeout_ms": 60000,
  "session_id": "test-mcp-$(date +%s)",
  "allow_network": true,
  "approval_policy": "auto"
}
EOF

echo -e "  ${GREEN}✓${NC} Payload criado"
echo ""
echo -e "${YELLOW}Conteúdo do payload:${NC}"
cat "$TEMP_FILE" | jq '.'
echo ""

# Testar acesso direto ao MCP (verificação adicional)
echo -e "${BLUE}[3/6] Testando acesso direto ao MCP...${NC}"

MCP_DIRECT_RESPONSE=$(mktemp)
MCP_DIRECT_CODE=$(curl -s -w "%{http_code}" -o "$MCP_DIRECT_RESPONSE" \
  -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' \
  --max-time 10 2>&1 || echo "000")

echo -e "  HTTP Status: ${YELLOW}$MCP_DIRECT_CODE${NC}"
if [ "$MCP_DIRECT_CODE" = "200" ] || [ "$MCP_DIRECT_CODE" = "201" ]; then
    echo -e "  ${GREEN}✓${NC} MCP respondeu diretamente"
    echo -e "  ${CYAN}Preview da resposta:${NC}"
    cat "$MCP_DIRECT_RESPONSE" | head -c 500
    echo ""
else
    echo -e "  ${YELLOW}⚠${NC} MCP pode não estar aceitando requisições diretas JSON-RPC"
    echo -e "  ${CYAN}Resposta:${NC}"
    cat "$MCP_DIRECT_RESPONSE" | head -c 200
    echo ""
fi

echo ""

# Enviar requisição para o wrapper via SSE endpoint
echo -e "${BLUE}[4/6] Enviando requisição para o wrapper (SSE endpoint)...${NC}"

RESPONSE_FILE=$(mktemp)

echo -e "  ${CYAN}Usando endpoint: POST /api/v1/exec/stream${NC}"
echo -e "  ${CYAN}Aguardando resposta (pode levar até 60s)...${NC}"
echo ""

# Capturar tanto HTTP code quanto resposta SSE
curl -s -N -X POST "$WRAPPER_URL/api/v1/exec/stream" \
  -H "Content-Type: application/json" \
  -H "X-Gateway-Key: $GATEWAY_API_KEY" \
  -d @"$TEMP_FILE" \
  --max-time 70 > "$RESPONSE_FILE" 2>&1

HTTP_CODE=$?

if [ $HTTP_CODE -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} Stream recebido com sucesso"
else
    echo -e "  ${YELLOW}⚠${NC} Curl exit code: $HTTP_CODE"
fi

echo ""

# Analisar resposta SSE
echo -e "${BLUE}[5/6] Analisando resposta SSE...${NC}"

RESPONSE_SIZE=$(wc -c < "$RESPONSE_FILE")
echo -e "  Tamanho da resposta: ${YELLOW}$RESPONSE_SIZE bytes${NC}"

if [ $RESPONSE_SIZE -lt 50 ]; then
    echo -e "  ${RED}✗${NC} Resposta muito pequena ou vazia"
    echo ""
    echo -e "${YELLOW}Conteúdo da resposta:${NC}"
    cat "$RESPONSE_FILE"
    MCP_SUCCESS=false
else
    echo -e "  ${GREEN}✓${NC} Resposta contém dados"
    echo ""
    echo -e "${YELLOW}Preview da resposta (primeiras 20 linhas):${NC}"
    head -20 "$RESPONSE_FILE"
    echo ""
    echo -e "${CYAN}[... mais conteúdo ...]${NC}"
    echo ""

    # Verificar se a resposta menciona MCP, tools, ou conexão
    if grep -qi "mcp\|tools\|capabilities\|connect\|pipedrive" "$RESPONSE_FILE"; then
        echo -e "  ${GREEN}✓${NC} Resposta menciona MCP/tools/capabilities"
        MCP_SUCCESS=true
    else
        echo -e "  ${YELLOW}⚠${NC} Resposta não menciona explicitamente MCP"
        MCP_SUCCESS=partial
    fi

    # Verificar se há erros
    if grep -qi "error\|failed\|cannot\|unable" "$RESPONSE_FILE"; then
        echo -e "  ${RED}⚠${NC} Resposta contém indicadores de erro"
        MCP_SUCCESS=error
    fi
fi

echo ""

# Diagnóstico Final
echo -e "${BLUE}[6/6] Diagnóstico Final...${NC}"
echo ""

if [ "$MCP_SUCCESS" = "true" ]; then
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ SUCESSO: Wrapper conseguiu se comunicar com MCP${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Por quê funcionou:${NC}"
    echo "  1. ✓ Wrapper está online e respondendo"
    echo "  2. ✓ API key autenticada corretamente"
    echo "  3. ✓ Endpoint SSE /api/v1/exec/stream funcionando"
    echo "  4. ✓ Codex dentro do wrapper conseguiu processar solicitação MCP"
    echo "  5. ✓ Resposta contém informações relacionadas ao MCP"
    echo ""
    echo -e "${GREEN}Conclusão:${NC}"
    echo "  O wrapper está funcionando e consegue executar comandos"
    echo "  que envolvem MCP quando solicitado via prompt natural."
    EXIT_CODE=0

elif [ "$MCP_SUCCESS" = "partial" ]; then
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}⚠ PARCIAL: Wrapper respondeu mas não há confirmação clara${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Situação:${NC}"
    echo "  - Wrapper processou a requisição"
    echo "  - Resposta foi recebida mas não contém menções claras ao MCP"
    echo "  - Pode ser que o Codex não tenha conseguido conectar ao MCP"
    echo "  - Ou o formato da resposta não seja o esperado"
    echo ""
    echo -e "${YELLOW}Possíveis causas:${NC}"
    echo "  • Codex pode não ter suporte nativo a MCP SSE"
    echo "  • MCP pode estar rejeitando conexões do wrapper"
    echo "  • Formato de requisição MCP pode estar incorreto"
    echo "  • Timeout ou latência muito alta"
    EXIT_CODE=2

elif [ "$MCP_SUCCESS" = "error" ]; then
    echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
    echo -e "${RED}✗ FALHA: Wrapper retornou erro${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${RED}Erro detectado na resposta${NC}"
    echo ""
    echo -e "${YELLOW}Possíveis causas:${NC}"
    echo "  • Codex não conseguiu conectar ao MCP"
    echo "  • MCP rejeitou a conexão"
    echo "  • Formato de requisição incorreto"
    echo "  • Timeout ou erro de rede"
    echo "  • Falta de permissões (allow_network pode não estar funcionando)"
    EXIT_CODE=1

else
    echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
    echo -e "${RED}✗ FALHA: Wrapper não conseguiu usar o MCP${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Possíveis causas:${NC}"
    echo ""
    echo "  ${RED}✗${NC} Resposta vazia ou muito pequena"
    echo "    → Wrapper pode não ter processado a requisição"
    echo "    → Timeout pode ter ocorrido"
    echo "    → Codex pode ter crashado"
    echo ""
    echo "  ${YELLOW}⚠${NC} Wrapper atual não tem suporte nativo a MCP"
    echo "    → O wrapper só executa codex em modo 'exec'"
    echo "    → Não há handler específico para MCP no código atual"
    echo "    → Ver: codex-rs/wrapper-cloud-run/src/main.rs"
    echo ""
    echo "  ${YELLOW}⚠${NC} Para integração real com MCP seria necessário:"
    echo "    → Implementar handler específico para MCP"
    echo "    → Usar mcp_connection_manager do core"
    echo "    → Adicionar rota /api/v1/mcp no router"
    echo "    → Implementar bridge entre WebSocket/SSE e MCP"
    EXIT_CODE=1
fi

echo ""
echo -e "${BLUE}Arquivos de debug:${NC}"
echo "  - Request payload: $TEMP_FILE"
echo "  - SSE Response: $RESPONSE_FILE"
echo "  - MCP Direct test: $MCP_DIRECT_RESPONSE"
echo ""
echo -e "${YELLOW}Para investigar mais:${NC}"
echo "  # Ver resposta completa do SSE:"
echo "  cat $RESPONSE_FILE"
echo ""
echo "  # Ver resposta do MCP direto:"
echo "  cat $MCP_DIRECT_RESPONSE | jq '.'"
echo ""
echo "  # Testar MCP manualmente:"
echo "  curl -X POST $MCP_URL -H 'Content-Type: application/json' \\"
echo "    -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{}}'"
echo ""

# Cleanup opcional (comentado para debug)
# rm -f "$TEMP_FILE" "$RESPONSE_FILE" "$MCP_DIRECT_RESPONSE"

exit $EXIT_CODE
