#!/bin/bash

echo "🔍 Verificando logs do wrapper Cloud Run..."
echo ""
echo "Como o gcloud local tem problemas, acesse os logs via Console Web:"
echo ""
echo "📋 URL dos Logs:"
echo "https://console.cloud.google.com/run/detail/us-central1/codex-wrapper/logs?project=elaihub-prod"
echo ""
echo "🔍 O que procurar nos logs:"
echo "  - Erros de 'config.toml not found'"
echo "  - Erros de conexão MCP"
echo "  - Erros de autenticação"
echo "  - Stack traces de Rust"
echo ""
echo "⚠️ Possíveis causas do erro 500:"
echo "  1. config.toml não está sendo copiado para a imagem Docker"
echo "  2. MCP Pipedrive não acessível (403)"
echo "  3. Variáveis de ambiente incorretas"
echo "  4. Erro ao carregar secrets"
echo ""
echo "🔧 Teste rápido sem MCP:"
echo ""

TOKEN=$(gcloud auth print-identity-token)

echo "Testando prompt simples (sem MCP)..."
curl -X POST https://codex-wrapper-467992722695.us-central1.run.app/api/v1/exec/stream \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Gateway-Key: IxF3WoAB6IBrNJKrC/Jsr5yjt2bXHZkBSHFDBhcIVvc=" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Qual é 2+2?", "model": "gpt-4o-mini"}' \
  --max-time 30 2>&1 | head -50

echo ""
echo ""
echo "📝 Se o teste acima falhar, o problema é na inicialização do wrapper."
echo "📝 Se funcionar, o problema é específico do MCP Pipedrive."
